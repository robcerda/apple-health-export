import SwiftUI
import HealthKit
import UniformTypeIdentifiers
import BackgroundTasks
import UIKit

struct SettingsView: View {
    @Binding var configuration: ExportConfiguration
    @Environment(\.dismiss) private var dismiss
    
    @State private var customDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var syncState = SyncState.load()
    @State private var showingDocumentPicker = false
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationView {
            Form {
                exportFormatSection
                
                dataTypesSection
                
                dateRangeSection
                
                securitySection
                
                autoExportSection
                
                exportHistorySection
                
                advancedSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveConfiguration()
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPickerView(onFolderSelected: handleDestinationSelected)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Force refresh of relative time displays when app becomes active
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Force refresh of relative time displays when app becomes fully active
            refreshID = UUID()
        }
    }
    
    private var exportFormatSection: some View {
        Section("Export Format") {
            Picker("Format", selection: $configuration.exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    VStack(alignment: .leading) {
                        Text(format.rawValue)
                        Text(format == .json ? "Human-readable, widely compatible" : "Structured database, efficient queries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.automatic)
        }
    }
    
    private var dataTypesSection: some View {
        Section("Data Types to Export") {
            ForEach(SupportedHealthDataTypes.allTypes, id: \.identifier) { type in
                let isEnabled = configuration.enabledDataTypes.contains(type.identifier)
                
                HStack {
                    Image(systemName: iconName(for: type))
                        .foregroundColor(isEnabled ? .blue : .gray)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading) {
                        Text(SupportedHealthDataTypes.displayName(for: type))
                        Text(type.identifier)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { configuration.enabledDataTypes.contains(type.identifier) },
                        set: { enabled in
                            if enabled {
                                configuration.enabledDataTypes.insert(type.identifier)
                            } else {
                                configuration.enabledDataTypes.remove(type.identifier)
                            }
                        }
                    ))
                }
            }
            
            Button("Select All") {
                configuration.enabledDataTypes = Set(SupportedHealthDataTypes.allTypes.map(\.identifier))
            }
            
            Button("Deselect All") {
                configuration.enabledDataTypes.removeAll()
            }
            .foregroundColor(.red)
        }
    }
    
    private var dateRangeSection: some View {
        Section("Date Range") {
            Toggle("Use Custom Date Range", isOn: $customDateRange)
            
            if customDateRange {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
            } else {
                Text("Export all available data")
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: customDateRange) {
            if customDateRange {
                configuration.dateRange = ExportConfiguration.DateRange(start: startDate, end: endDate)
            } else {
                configuration.dateRange = nil
            }
        }
        .onChange(of: startDate) {
            if customDateRange {
                configuration.dateRange = ExportConfiguration.DateRange(start: startDate, end: endDate)
            }
        }
        .onChange(of: endDate) {
            if customDateRange {
                configuration.dateRange = ExportConfiguration.DateRange(start: startDate, end: endDate)
            }
        }
    }
    
    private var securitySection: some View {
        Section("Security") {
            Toggle("Encrypt Export", isOn: $configuration.encryptionEnabled)
            
            if configuration.encryptionEnabled {
                Label("AES-256-GCM encryption will be used", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var autoExportSection: some View {
        Section("Automatic Export") {
            Toggle("Enable Auto Export", isOn: $configuration.autoExportEnabled)
                .onChange(of: configuration.autoExportEnabled) {
                    // Auto-schedule when toggle changes
                    if configuration.autoExportEnabled {
                        scheduleAutoExport()
                    }
                }
            
            if configuration.autoExportEnabled {
                // Frequency Selection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Frequency")
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    Picker("Frequency", selection: $configuration.autoExportSettings.frequency) {
                        ForEach(AutoExportFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(configuration.autoExportSettings.frequency.nextRunDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Time Selection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Export Time")
                            .font(.subheadline)
                        Spacer()
                        Text(configuration.autoExportSettings.timeOfDay.displayString)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Hour:")
                        Picker("Hour", selection: $configuration.autoExportSettings.timeOfDay.hour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxHeight: 80)
                        
                        Text("Minute:")
                        Picker("Minute", selection: $configuration.autoExportSettings.timeOfDay.minute) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxHeight: 80)
                    }
                }
                
                // Data Range Selection  
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data Range to Export")
                        .font(.subheadline)
                    
                    Picker("Data Range", selection: $configuration.autoExportSettings.dataRange) {
                        ForEach(AutoExportDataRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.automatic)
                    
                    Text(configuration.autoExportSettings.dataRange.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Auto Export Settings (independent from manual export)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto Export Format")
                        .font(.subheadline)
                    
                    Picker("Format", selection: $configuration.autoExportSettings.format) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Encrypt Auto Exports", isOn: $configuration.autoExportSettings.encryptionEnabled)
                }
                
                // Destination Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Destination")
                        .font(.subheadline)
                    
                    Button {
                        print("🔄 Choose Destination button tapped")
                        showingDocumentPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(configuration.autoExportSettings.destinationDisplayName ?? "Choose Destination")
                                    .foregroundColor(.primary)
                                
                                Text(configuration.autoExportSettings.destinationDisplayName != nil ? 
                                     "Tap to change destination" : 
                                     "Select where auto-exports will be saved")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                
                // Summary
                Label {
                    let destination = configuration.autoExportSettings.destinationDisplayName ?? "app's Documents folder"
                    Text("Will export \(configuration.autoExportSettings.dataRange.rawValue.lowercased()) \(configuration.autoExportSettings.frequency.nextRunDescription.lowercased()) at \(configuration.autoExportSettings.timeOfDay.displayString) to \(destination) in \(configuration.autoExportSettings.format.rawValue) format")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                }
                
                // Auto-export status
                if configuration.autoExportEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Label {
                            Text("Auto-export is enabled and scheduled")
                                .font(.caption)
                                .foregroundColor(.green)
                        } icon: {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundColor(.green)
                        }
                        
                        // Show background task status
                        VStack(alignment: .leading, spacing: 4) {
                            if let lastAutoExport = UserDefaults.standard.object(forKey: "LastAutoExportTime") as? Date {
                                Text("Last auto-export: \(lastAutoExport.relativeString)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .id(refreshID) // Force refresh when refreshID changes
                            } else {
                                Text("No auto-exports yet - will run when due or when app is opened")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Show next scheduled time if available
                            if let nextScheduled = UserDefaults.standard.object(forKey: "NextScheduledAutoExport") as? Date {
                                let isOverdue = nextScheduled < Date()
                                Text("Next scheduled: \(nextScheduled.relativeString) \(isOverdue ? "(overdue - will run when app opens)" : "")")
                                    .font(.caption2)
                                    .foregroundColor(isOverdue ? .orange : .secondary)
                            }
                            
                            // Show background task reality hint
                            Text("Note: iOS may not run background tasks reliably - see info below")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    Label {
                        Text("Enable auto-export above to schedule automatic exports")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "clock.badge.xmark")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Background task info
            BackgroundTaskInfoView()
                .padding(.top, 8)
        }
    }
    
    private var exportHistorySection: some View {
        Section("Export History") {
            let unifiedHistory = getUnifiedExportHistory()
            
            if unifiedHistory.isEmpty {
                Text("No exports yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(unifiedHistory) { record in
                    HStack {
                        Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(record.success ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.date.exportDisplayString)
                                .font(.subheadline)
                            
                            HStack {
                                Text(record.format.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                                
                                if record.isIncremental {
                                    Text("Incremental")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                if !record.fileExists {
                                    Text("File Missing")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                            
                            if record.success {
                                if record.recordCount > 0 {
                                    Text("\(record.recordCount) records • \(record.formattedFileSize) • \(record.formattedDuration)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(record.formattedFileSize)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text(record.errorMessage ?? "Export failed")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Spacer()
                        
                        if record.fileExists, let fileURL = record.fileURL {
                            Button("Share") {
                                shareFile(fileURL)
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                Button("Clear History") {
                    syncState.clearExportHistory()
                    syncState.save()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private var advancedSection: some View {
        Section("Advanced") {
            HStack {
                Text("Batch Size")
                Spacer()
                Text("\(configuration.batchSize)")
                    .foregroundColor(.secondary)
            }
            
            if let lastExport = syncState.lastExportDate {
                HStack {
                    Text("Last Export")
                    Spacer()
                    Text(lastExport.relativeString)
                        .foregroundColor(.secondary)
                }
                .id(refreshID) // Force refresh when refreshID changes
            }
            
            if let lastFull = syncState.lastFullExportDate {
                HStack {
                    Text("Last Full Export")
                    Spacer()
                    Text(lastFull.relativeString)
                        .foregroundColor(.secondary)
                }
                .id(refreshID) // Force refresh when refreshID changes
            }
            
            Button("Reset Sync State") {
                SyncState.clear()
                syncState = SyncState()
            }
            .foregroundColor(.red)
        }
    }
    
    private func iconName(for type: HKSampleType) -> String {
        switch type.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue,
             HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            return "heart.fill"
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return "figure.walk"
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            return "location.fill"
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return "flame.fill"
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return "scalemass.fill"
        case HKQuantityTypeIdentifier.bloodGlucose.rawValue:
            return "drop.fill"
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return "lungs.fill"
        case HKCategoryTypeIdentifier.sleepAnalysis.rawValue:
            return "bed.double.fill"
        case HKCategoryTypeIdentifier.mindfulSession.rawValue:
            return "brain.head.profile"
        case HKWorkoutType.workoutType().identifier:
            return "figure.run"
        default:
            return "chart.line.uptrend.xyaxis"
        }
    }
    
    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "ExportConfiguration")
            
            // Automatically schedule auto-export if enabled
            if configuration.autoExportEnabled {
                scheduleAutoExport()
            }
        }
    }
    
    private func scheduleAutoExport() {
        guard configuration.autoExportEnabled else {
            print("📅 Auto-export is disabled, not scheduling")
            return
        }
        
        let settings = configuration.autoExportSettings
        guard let nextRunDate = calculateNextRunDate(for: settings) else {
            print("❌ Could not calculate next run date")
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: "com.healthexporter.auto-export")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = nextRunDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled next auto-export for: \(nextRunDate)")
        } catch {
            print("❌ Failed to schedule auto-export: \(error)")
        }
    }
    
    private func calculateNextRunDate(for settings: AutoExportSettings) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        var targetComponents = todayComponents
        targetComponents.hour = settings.timeOfDay.hour
        targetComponents.minute = settings.timeOfDay.minute
        targetComponents.second = 0
        
        guard let todayTarget = calendar.date(from: targetComponents) else {
            return nil
        }
        
        switch settings.frequency {
        case .daily:
            if todayTarget > now {
                return todayTarget
            } else {
                return calendar.date(byAdding: .day, value: 1, to: todayTarget)
            }
            
        case .weekly:
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
    
    
    private func getUnifiedExportHistory() -> [UnifiedExportRecord] {
        let fileService = FileService()
        return syncState.getUnifiedExportHistory(fileService: fileService)
    }
    
    private func shareFile(_ fileURL: URL) {
        let activityController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // For iPad support
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityController, animated: true)
        }
    }
    
    private func handleDestinationSelected(_ url: URL) {
        print("📁 Attempting to set destination: \(url.path)")
        print("📁 URL exists: \(url.hasDirectoryPath)")
        print("📁 URL security-scoped: \(url.isFileURL)")
        
        do {
            let fileService = FileService()
            let bookmark = try fileService.createDestinationBookmark(for: url)
            
            configuration.autoExportSettings.destinationBookmark = bookmark
            configuration.autoExportSettings.destinationDisplayName = url.lastPathComponent
            
            print("✅ Auto-export destination selected: \(url.lastPathComponent)")
            print("✅ Bookmark created successfully")
            
            // Save configuration immediately
            saveConfiguration()
        } catch {
            print("❌ Failed to create bookmark for destination: \(error)")
            print("❌ URL: \(url)")
            print("❌ Error details: \(error.localizedDescription)")
            
            // Reset destination on failure
            configuration.autoExportSettings.destinationBookmark = nil
            configuration.autoExportSettings.destinationDisplayName = nil
        }
    }
    
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let onFolderSelected: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> DocumentPickerCoordinator {
        DocumentPickerCoordinator(
            onFolderSelected: onFolderSelected,
            onDismiss: { dismiss() }
        )
    }
}


class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    let onFolderSelected: (URL) -> Void
    let onDismiss: () -> Void
    
    init(onFolderSelected: @escaping (URL) -> Void, onDismiss: @escaping () -> Void) {
        self.onFolderSelected = onFolderSelected
        self.onDismiss = onDismiss
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        print("📁 Folder selected: \(url.lastPathComponent)")
        onFolderSelected(url)
        onDismiss()
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("📁 Folder picker cancelled")
        onDismiss()
    }
}

#Preview {
    SettingsView(configuration: .constant(ExportConfiguration.default))
}