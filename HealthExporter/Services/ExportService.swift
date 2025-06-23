import Foundation
import HealthKit
import Combine

@MainActor
class ExportService: ObservableObject {
    @Published var isExporting = false
    @Published var exportProgress: ExportProgress = ExportProgress()
    @Published var lastError: Error?
    
    private let healthKitService: HealthKitService
    private let fileService: FileService
    private let encryptionService: EncryptionService
    private var exportTask: Task<Void, Never>?
    
    init(
        healthKitService: HealthKitService,
        fileService: FileService,
        encryptionService: EncryptionService
    ) {
        self.healthKitService = healthKitService
        self.fileService = fileService
        self.encryptionService = encryptionService
    }
    
    func startExport(configuration: ExportConfiguration, password: String? = nil) {
        guard !isExporting else { return }
        
        exportTask = Task { [weak self] in
            await self?.performExport(configuration: configuration, password: password)
        }
    }
    
    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        
        Task { @MainActor in
            isExporting = false
            exportProgress = ExportProgress()
        }
    }
    
    private func performExport(configuration: ExportConfiguration, password: String?) async {
        await MainActor.run {
            isExporting = true
            exportProgress = ExportProgress()
            lastError = nil
        }
        
        let startTime = Date()
        var syncState = SyncState.load()
        
        do {
            let isIncremental = configuration.dateRange == nil && syncState.lastExportDate != nil
            let dateRange = determineDateRange(configuration: configuration, syncState: syncState)
            
            await updateProgress(stage: .initializing, message: "Preparing export...")
            
            var healthData = HealthDataCollection()
            var totalRecords = 0
            
            let enabledTypes = getEnabledHealthTypes(configuration: configuration)
            await updateProgress(totalSteps: enabledTypes.count)
            
            for (index, type) in enabledTypes.enumerated() {
                if Task.isCancelled {
                    throw HealthKitError.exportCancelled
                }
                
                let typeName = SupportedHealthDataTypes.displayName(for: type)
                await updateProgress(
                    stage: .exportingData,
                    message: "Exporting \(typeName)...",
                    currentStep: index
                )
                
                let records = try await exportHealthType(
                    type: type,
                    dateRange: dateRange,
                    configuration: configuration,
                    syncState: &syncState,
                    isIncremental: isIncremental
                )
                
                print("📊 Fetched \(records.count) records for \(type.identifier)")
                
                switch type {
                case _ as HKQuantityType:
                    healthData.quantityData[type.identifier] = records.compactMap { $0 as? QuantitySample }
                case _ as HKCategoryType:
                    healthData.categoryData[type.identifier] = records.compactMap { $0 as? CategorySample }
                case is HKWorkoutType:
                    healthData.workoutData = records.compactMap { $0 as? WorkoutSample }
                default:
                    break
                }
                
                totalRecords += records.count
            }
            
            await updateProgress(stage: .writingFile, message: "Writing export file...")
            
            let exportData = HealthDataExport(
                metadata: ExportMetadata(
                    exportDate: Date(),
                    dataDateRange: ExportMetadata.DateRange(
                        start: dateRange.start,
                        end: dateRange.end
                    ),
                    version: "1.0",
                    recordCount: totalRecords,
                    encrypted: configuration.encryptionEnabled
                ),
                healthData: healthData
            )
            
            let fileURL = try await writeExportFile(
                exportData: exportData,
                configuration: configuration,
                password: password
            )
            
            let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
            let duration = Date().timeIntervalSince(startTime)
            
            syncState.updateLastExportDate(Date())
            if !isIncremental {
                syncState.setLastFullExportDate(Date())
            }
            
            let exportRecord = ExportRecord(
                date: Date(),
                format: configuration.exportFormat,
                recordCount: totalRecords,
                fileSize: fileSize,
                duration: duration,
                success: true,
                errorMessage: nil,
                isIncremental: isIncremental
            )
            
            syncState.addExportRecord(exportRecord)
            syncState.save()
            
            await updateProgress(stage: .completed, message: "Export completed successfully!")
            
        } catch {
            print("❌ Export failed with error: \(error)")
            print("❌ Error type: \(type(of: error))")
            if let localizedError = error as? LocalizedError {
                print("❌ Error description: \(localizedError.errorDescription ?? "No description")")
            }
            
            await MainActor.run {
                lastError = error
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let exportRecord = ExportRecord(
                date: Date(),
                format: configuration.exportFormat,
                recordCount: 0,
                fileSize: 0,
                duration: duration,
                success: false,
                errorMessage: error.localizedDescription,
                isIncremental: false
            )
            
            syncState.addExportRecord(exportRecord)
            syncState.save()
            
            await updateProgress(stage: .failed, message: "Export failed: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isExporting = false
        }
    }
    
    private func determineDateRange(configuration: ExportConfiguration, syncState: SyncState) -> (start: Date, end: Date) {
        if let configRange = configuration.dateRange {
            return (start: configRange.start, end: configRange.end)
        }
        
        let endDate = Date()
        
        if let lastExport = syncState.lastExportDate {
            return (start: lastExport, end: endDate)
        }
        
        let startDate = Calendar.current.date(byAdding: .year, value: -5, to: endDate) ?? Date.distantPast
        return (start: startDate, end: endDate)
    }
    
    private func getEnabledHealthTypes(configuration: ExportConfiguration) -> [HKSampleType] {
        return SupportedHealthDataTypes.allTypes.filter { type in
            configuration.enabledDataTypes.contains(type.identifier)
        }
    }
    
    private func exportHealthType(
        type: HKSampleType,
        dateRange: (start: Date, end: Date),
        configuration: ExportConfiguration,
        syncState: inout SyncState,
        isIncremental: Bool
    ) async throws -> [Any] {
        
        let anchor = isIncremental ? syncState.getAnchor(for: type.identifier) : nil
        
        switch type {
        case let quantityType as HKQuantityType:
            let result = try await healthKitService.fetchQuantityData(
                for: quantityType,
                from: dateRange.start,
                to: dateRange.end,
                limit: configuration.batchSize,
                anchor: anchor
            )
            
            if let newAnchor = result.newAnchor {
                syncState.updateAnchor(for: type.identifier, anchor: newAnchor)
            }
            
            return result.samples.map { $0.toQuantitySample() }
            
        case let categoryType as HKCategoryType:
            let result = try await healthKitService.fetchCategoryData(
                for: categoryType,
                from: dateRange.start,
                to: dateRange.end,
                limit: configuration.batchSize,
                anchor: anchor
            )
            
            if let newAnchor = result.newAnchor {
                syncState.updateAnchor(for: type.identifier, anchor: newAnchor)
            }
            
            return result.samples.map { $0.toCategorySample() }
            
        case is HKWorkoutType:
            let result = try await healthKitService.fetchWorkoutData(
                from: dateRange.start,
                to: dateRange.end,
                limit: configuration.batchSize,
                anchor: anchor
            )
            
            if let newAnchor = result.newAnchor {
                syncState.updateAnchor(for: type.identifier, anchor: newAnchor)
            }
            
            var workoutSamples: [WorkoutSample] = []
            
            for workout in result.workouts {
                let heartRateData = try await healthKitService.fetchWorkoutHeartRateData(for: workout)
                let heartRateSamples = heartRateData.map { $0.toQuantitySample() }
                let workoutSample = workout.toWorkoutSample(heartRateData: heartRateSamples)
                workoutSamples.append(workoutSample)
            }
            
            return workoutSamples
            
        case let clinicalType as HKClinicalType:
            let records = try await healthKitService.fetchClinicalData(
                for: clinicalType,
                limit: configuration.batchSize
            )
            
            return records.map { record in
                ClinicalSample(
                    uuid: record.uuid.uuidString,
                    startDate: record.startDate,
                    endDate: record.endDate,
                    clinicalType: record.clinicalType.identifier,
                    displayName: record.displayName,
                    fhirResource: record.fhirResource?.data,
                    sourceRevision: record.sourceRevision.toSourceRevision()
                )
            }
            
        default:
            return []
        }
    }
    
    private func writeExportFile(
        exportData: HealthDataExport,
        configuration: ExportConfiguration,
        password: String?
    ) async throws -> URL {
        
        switch configuration.exportFormat {
        case .json:
            let jsonData = try JSONEncoder().encode(exportData)
            
            let finalData: Data
            if configuration.encryptionEnabled, let password = password {
                finalData = try encryptionService.encrypt(data: jsonData, password: password)
            } else {
                finalData = jsonData
            }
            
            let filename = generateFilename(format: .json, encrypted: configuration.encryptionEnabled)
            return try await fileService.writeFile(data: finalData, filename: filename)
            
        case .sqlite:
            let fileURL = try await fileService.createSQLiteDatabase(
                exportData: exportData,
                encrypted: configuration.encryptionEnabled,
                password: password
            )
            return fileURL
        }
    }
    
    private func generateFilename(format: ExportFormat, encrypted: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let encryptedSuffix = encrypted ? "_encrypted" : ""
        return "health_export_\(timestamp)\(encryptedSuffix).\(format.fileExtension)"
    }
    
    private func updateProgress(
        stage: ExportStage? = nil,
        message: String? = nil,
        currentStep: Int? = nil,
        totalSteps: Int? = nil
    ) async {
        await MainActor.run {
            if let stage = stage {
                exportProgress.stage = stage
            }
            if let message = message {
                exportProgress.currentOperation = message
            }
            if let currentStep = currentStep {
                exportProgress.currentStep = currentStep
            }
            if let totalSteps = totalSteps {
                exportProgress.totalSteps = totalSteps
            }
        }
    }
}

struct ExportProgress {
    var stage: ExportStage = .initializing
    var currentOperation: String = ""
    var currentStep: Int = 0
    var totalSteps: Int = 1
    
    var progressPercentage: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }
    
    var isCompleted: Bool {
        stage == .completed
    }
    
    var isFailed: Bool {
        stage == .failed
    }
}

enum ExportStage {
    case initializing
    case exportingData
    case writingFile
    case completed
    case failed
    
    var description: String {
        switch self {
        case .initializing:
            return "Initializing"
        case .exportingData:
            return "Exporting Data"
        case .writingFile:
            return "Writing File"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}
