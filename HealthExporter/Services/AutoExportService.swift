import Foundation
import BackgroundTasks
import UserNotifications

class AutoExportService: ObservableObject {
    static let shared = AutoExportService()
    
    // Static initializer to ensure background tasks are registered early
    static func initialize() {
        _ = shared
    }
    
    private let backgroundTaskIdentifier = "com.healthexporter.auto-export"
    
    @Published var isAutoExportInProgress = false
    @Published var lastAutoExportDate: Date?
    @Published var lastAutoExportError: Error?
    @Published var backgroundTaskAttempts: Int = 0
    @Published var consecutiveFailures: Int = 0
    
    private init() {
        // Register background tasks first, before MainActor isolation
        registerBackgroundTasks()
        // Request notification permissions asynchronously
        Task { @MainActor in
            requestNotificationPermissions()
        }
    }
    
    // MARK: - Background Task Registration
    
    private nonisolated func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: DispatchQueue.global(qos: .background)
        ) { [weak self] task in
            Task {
                await self?.handleAutoExport(task: task as! BGProcessingTask)
            }
        }
    }
    
    // MARK: - Scheduling
    
    @MainActor func scheduleNextAutoExport() {
        guard let configuration = loadConfiguration(),
              configuration.autoExportEnabled else {
            print("📅 Auto-export is disabled, not scheduling")
            return
        }
        
        let settings = configuration.autoExportSettings
        guard let nextRunDate = calculateNextRunDate(for: settings) else {
            print("❌ Could not calculate next run date")
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = nextRunDate
        
        // Optimization hints to improve background execution chances
        // Set a reasonable time window (not too far in future)
        let maxDelay = Calendar.current.date(byAdding: .hour, value: 2, to: nextRunDate) ?? nextRunDate
        request.earliestBeginDate = nextRunDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled next auto-export for: \(nextRunDate)")
            
            // Store scheduling info for user visibility
            UserDefaults.standard.set(nextRunDate, forKey: "NextScheduledAutoExport")
            UserDefaults.standard.set(Date(), forKey: "LastAutoExportScheduleTime")
            
            // Track scheduling attempts for diagnostics
            let attempts = UserDefaults.standard.integer(forKey: "AutoExportScheduleAttempts") + 1
            UserDefaults.standard.set(attempts, forKey: "AutoExportScheduleAttempts")
            
        } catch {
            print("❌ Failed to schedule auto-export: \(error)")
            UserDefaults.standard.set(error.localizedDescription, forKey: "LastAutoExportScheduleError")
        }
    }
    
    private func calculateNextRunDate(for settings: AutoExportSettings) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        // Get today's target time
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        var targetComponents = todayComponents
        targetComponents.hour = settings.timeOfDay.hour
        targetComponents.minute = settings.timeOfDay.minute
        targetComponents.second = 0
        
        guard let todayTarget = calendar.date(from: targetComponents) else {
            return nil
        }
        
        // If today's time has passed, calculate next occurrence
        let baseDate = todayTarget > now ? todayTarget : todayTarget
        
        switch settings.frequency {
        case .daily:
            if baseDate > now {
                return baseDate
            } else {
                return calendar.date(byAdding: .day, value: 1, to: baseDate)
            }
            
        case .weekly:
            // Schedule for next Sunday at the specified time
            var weeklyComponents = DateComponents()
            weeklyComponents.weekday = 1
            weeklyComponents.hour = settings.timeOfDay.hour
            weeklyComponents.minute = settings.timeOfDay.minute
            
            let nextSunday = calendar.nextDate(
                after: now,
                matching: weeklyComponents,
                matchingPolicy: .nextTime
            )
            return nextSunday
            
        case .monthly:
            // Schedule for first day of next month
            var monthlyComponents = DateComponents()
            monthlyComponents.day = 1
            monthlyComponents.hour = settings.timeOfDay.hour
            monthlyComponents.minute = settings.timeOfDay.minute
            
            let nextMonth = calendar.nextDate(
                after: now,
                matching: monthlyComponents,
                matchingPolicy: .nextTime
            )
            return nextMonth
        }
    }
    
    // MARK: - Export Execution
    
    private func handleAutoExport(task: BGProcessingTask) async {
        print("🚀 Starting background auto-export task")
        
        var exportCompleted = false
        
        task.expirationHandler = {
            print("⏰ Background task expired - will complete via foreground fallback")
            if !exportCompleted {
                // Mark that background task was attempted but not completed
                UserDefaults.standard.set(Date(), forKey: "LastBackgroundTaskAttempt")
                task.setTaskCompleted(success: false)
            }
        }
        
        // Attempt background export with time limit
        Task {
            do {
                // Try background export with reduced scope due to iOS limitations
                let success = try await performBackgroundExport()
                exportCompleted = success
                
                await MainActor.run {
                    if success {
                        lastAutoExportDate = Date()
                        consecutiveFailures = 0
                        print("✅ Background auto-export completed successfully")
                    } else {
                        consecutiveFailures += 1
                        print("⚠️ Background export had limited success - foreground fallback will handle")
                    }
                    backgroundTaskAttempts += 1
                }
                
                task.setTaskCompleted(success: success)
                
            } catch {
                print("❌ Background auto-export failed: \(error)")
                await MainActor.run {
                    lastAutoExportError = error
                    consecutiveFailures += 1
                    backgroundTaskAttempts += 1
                }
                exportCompleted = true
                task.setTaskCompleted(success: false)
            }
            
            // Always schedule next export
            await MainActor.run {
                scheduleNextAutoExport()
            }
        }
    }
    
    private func performBackgroundExport() async throws -> Bool {
        guard let configuration = loadConfiguration(),
              configuration.autoExportEnabled else {
            print("❌ Auto-export configuration not found or disabled")
            return false
        }
        
        print("🚀 Attempting background export with limited scope...")
        
        // Create services
        let fileService = FileService()
        let encryptionService = EncryptionService()
        let healthKitService = await MainActor.run { HealthKitService() }
        
        // Check HealthKit authorization in background
        let hasAuthorization = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let isAuthorized = healthKitService.isAuthorized
                continuation.resume(returning: isAuthorized)
            }
        }
        
        guard hasAuthorization else {
            print("❌ HealthKit not authorized for background export")
            return false
        }
        
        // Create auto-export configuration with current time as end date
        let scheduledTime = Date() // Use current time for background exports
        let autoExportConfig = createAutoExportConfiguration(from: configuration, scheduledTime: scheduledTime)
        
        print("🚀 Background export starting with format: \(autoExportConfig.exportFormat.rawValue)")
        
        // Create export service and run export
        let exportService = await MainActor.run {
            ExportService(
                healthKitService: healthKitService,
                fileService: fileService,
                encryptionService: encryptionService
            )
        }
        
        // Start export on main actor
        await MainActor.run {
            exportService.startExport(
                configuration: autoExportConfig,
                password: configuration.autoExportSettings.encryptionEnabled ? nil : nil
            )
        }
        
        // Wait for completion with timeout (background tasks have limited time)
        let timeout = 25.0 // 25 seconds timeout for background task
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let progress = await MainActor.run { exportService.exportProgress }
            
            if progress.stage == .completed {
                print("✅ Background auto-export completed successfully")
                
                // Validate export data completeness
                let isValid = await validateExportCompleteness(fileService: fileService, expectedFormat: autoExportConfig.exportFormat)
                
                if isValid {
                    await MainActor.run {
                        lastAutoExportDate = Date()
                    }
                    
                    // Handle destination if configured
                    if let bookmark = configuration.autoExportSettings.destinationBookmark {
                        await moveLatestExportToDestination(bookmark: bookmark, fileService: fileService)
                    }
                    
                    return true
                } else {
                    print("⚠️ Export validation failed - data may be incomplete")
                    return false
                }
            } else if progress.stage == .failed {
                let error = await MainActor.run { exportService.lastError }
                print("❌ Background auto-export failed: \(error?.localizedDescription ?? "Unknown error")")
                return false
            }
            
            // Sleep briefly before checking again
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        print("⏰ Background export timed out - will be completed by foreground fallback")
        return false
    }
    
    private func createAutoExportConfiguration(from config: ExportConfiguration, scheduledTime: Date) -> ExportConfiguration {
        var autoConfig = config
        
        // Override with auto-export specific settings
        autoConfig.exportFormat = config.autoExportSettings.format
        autoConfig.encryptionEnabled = config.autoExportSettings.encryptionEnabled
        
        // Set date range based on auto-export data range setting
        // Use current time as end date for background exports to capture latest data
        switch config.autoExportSettings.dataRange {
        case .sinceLast:
            // Use incremental since last export
            autoConfig.dateRange = nil // This will trigger incremental export
            
        case .last24Hours:
            let endDate = scheduledTime // Use current time for background exports
            let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
            autoConfig.dateRange = ExportConfiguration.DateRange(start: startDate, end: endDate)
            print("📅 Export range: \(startDate) to \(endDate) (24 hours ending now)")
            
        case .lastWeek:
            let endDate = scheduledTime // Use current time for background exports
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            autoConfig.dateRange = ExportConfiguration.DateRange(start: startDate, end: endDate)
            print("📅 Export range: \(startDate) to \(endDate) (7 days ending now)")
            
        case .lastMonth:
            let endDate = scheduledTime // Use current time for background exports
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            autoConfig.dateRange = ExportConfiguration.DateRange(start: startDate, end: endDate)
            print("📅 Export range: \(startDate) to \(endDate) (30 days ending now)")
            
        case .allData:
            autoConfig.dateRange = nil
            print("📅 Export range: All data (no date restriction)")
        }
        
        return autoConfig
    }
    
    private func validateExportCompleteness(fileService: FileService, expectedFormat: ExportFormat) async -> Bool {
        do {
            // Get the latest export file
            let exportFiles = fileService.listExportFiles()
            guard let latestExport = exportFiles.first else {
                print("❌ No export file found for validation")
                return false
            }
            
            // Check file size (should be > 1KB for any meaningful data)
            let fileSize = try FileManager.default.attributesOfItem(atPath: latestExport.path)[.size] as? Int64 ?? 0
            print("📊 Export file size: \(fileSize) bytes")
            
            if fileSize < 1024 {
                print("⚠️ Export file suspiciously small: \(fileSize) bytes")
                return false
            }
            
            // For JSON exports, try to parse and validate structure
            if expectedFormat == .json {
                let data = try Data(contentsOf: latestExport)
                
                // If encrypted, we can't easily validate content, but size check should suffice
                if latestExport.lastPathComponent.contains("encrypted") {
                    print("🔒 Encrypted export - relying on file size validation")
                    return fileSize > 10240 // At least 10KB for encrypted data
                }
                
                // Try to parse JSON structure
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let hasMetadata = json["metadata"] != nil
                    let hasHealthData = json["healthData"] != nil
                    
                    print("📋 JSON validation - metadata: \(hasMetadata), healthData: \(hasHealthData)")
                    
                    if hasMetadata && hasHealthData {
                        // Check if health data contains actual records
                        if let healthData = json["healthData"] as? [String: Any] {
                            let quantityCount = (healthData["quantityData"] as? [String: Any])?.count ?? 0
                            let categoryCount = (healthData["categoryData"] as? [String: Any])?.count ?? 0
                            let workoutCount = (healthData["workoutData"] as? [Any])?.count ?? 0
                            
                            let totalDataTypes = quantityCount + categoryCount + (workoutCount > 0 ? 1 : 0)
                            print("📊 Export contains \(totalDataTypes) data types")
                            
                            return totalDataTypes > 0
                        }
                    }
                    
                    return hasMetadata && hasHealthData
                } else {
                    print("❌ Invalid JSON format in export")
                    return false
                }
            }
            
            // For SQLite, just check file size (detailed validation would require opening DB)
            return fileSize > 10240 // At least 10KB
            
        } catch {
            print("❌ Export validation error: \(error)")
            return false
        }
    }
    
    private func moveLatestExportToDestination(bookmark: Data, fileService: FileService) async {
        do {
            // Get the latest export file
            let exportFiles = fileService.listExportFiles()
            guard let latestExport = exportFiles.first else {
                print("❌ No export file found to move to destination")
                return
            }
            
            // Read the export data
            let exportData = try Data(contentsOf: latestExport)
            
            // Write to auto-export destination
            let destinationURL = try await fileService.writeFileToAutoExportDestination(
                data: exportData,
                filename: latestExport.lastPathComponent,
                bookmark: bookmark
            )
            
            print("📁 Background auto-export saved to destination: \(destinationURL.path)")
        } catch {
            print("❌ Failed to move background export to destination: \(error)")
        }
    }
    
    // MARK: - Manual Trigger (for testing)
    
    @MainActor func triggerAutoExportNow() {
        guard !isAutoExportInProgress else {
            print("⚠️ Auto-export already in progress")
            return
        }
        
        print("🚀 Manual auto-export triggered")
        
        Task {
            await MainActor.run {
                isAutoExportInProgress = true
                lastAutoExportError = nil
            }
            
            do {
                let success = try await performBackgroundExport()
                await MainActor.run {
                    isAutoExportInProgress = false
                    if success {
                        lastAutoExportDate = Date()
                        print("✅ Manual auto-export completed successfully")
                    } else {
                        print("⚠️ Manual auto-export had partial success")
                    }
                }
            } catch {
                await MainActor.run {
                    isAutoExportInProgress = false
                    lastAutoExportError = error
                    print("❌ Manual auto-export failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Utilities
    
    private func loadConfiguration() -> ExportConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "ExportConfiguration"),
              let config = try? JSONDecoder().decode(ExportConfiguration.self, from: data) else {
            return nil
        }
        return config
    }
    
    @MainActor private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("📱 Notification permissions granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }
}

// MARK: - Errors

enum AutoExportError: LocalizedError {
    case exportFailed
    case noExportFound
    case destinationNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "Failed to export health data"
        case .noExportFound:
            return "No export file found to move to destination"
        case .destinationNotAvailable:
            return "Auto-export destination is not available"
        }
    }
}