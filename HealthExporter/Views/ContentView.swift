import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthKitService = HealthKitService()
    @StateObject private var exportService: ExportService
    
    @State private var configuration = ExportConfiguration.default
    @State private var showingSettings = false
    @State private var showingProgress = false
    @State private var password = ""
    @State private var showingPasswordAlert = false
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var showingExportDetails = false
    @State private var exportedFileURL: URL?
    @State private var refreshID = UUID()
    
    init() {
        let fileService = FileService()
        let encryptionService = EncryptionService()
        let healthKit = HealthKitService()
        
        self._exportService = StateObject(wrappedValue: ExportService(
            healthKitService: healthKit,
            fileService: fileService,
            encryptionService: encryptionService
        ))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    headerSection
                        .padding(.top, 20)
                    
                    authorizationSection
                    
                    if healthKitService.isAuthorized {
                        exportSection
                        
                        HStack(alignment: .top, spacing: 16) {
                            permissionsDebugSection
                                .frame(maxWidth: .infinity)
                            
                            configurationSection
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .refreshable {
                await refreshAllData()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                    .disabled(!healthKitService.isAuthorized)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(configuration: $configuration)
            }
            .sheet(isPresented: $showingProgress) {
                ProgressView(exportService: exportService)
            }
            .alert("Enter Password", isPresented: $showingPasswordAlert) {
                SecureField("Password", text: $password)
                Button("Export") {
                    startExport()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter a password to encrypt your health data export.")
            }
            .alert("Export Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                if let error = exportService.lastError {
                    Text(error.userFriendlyMessage)
                }
            }
            .alert("Export Complete!", isPresented: $showingSuccessAlert) {
                Button("Share") {
                    shareExportedFile()
                }
                Button("OK") { }
            } message: {
                if let fileURL = exportedFileURL {
                    let fileService = FileService()
                    let fileSize = fileService.getFileSize(for: fileURL)
                    let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                    Text("Export completed successfully!\n\nFile: \(fileURL.lastPathComponent)\nSize: \(formattedSize)")
                } else {
                    Text("Export completed successfully!")
                }
            }
        }
        .onChange(of: exportService.isExporting) {
            showingProgress = exportService.isExporting
        }
        .onChange(of: exportService.lastError != nil) {
            if exportService.lastError != nil {
                showingErrorAlert = true
            }
        }
        .onChange(of: exportService.exportProgress.stage) {
            if exportService.exportProgress.stage == .completed && exportService.lastError == nil {
                // Export completed successfully
                exportedFileURL = getLatestExportFile()
                showingSuccessAlert = true
            }
        }
        .onAppear {
            loadConfiguration()
            print("📱 ContentView appeared - HealthKit authorized: \(healthKitService.isAuthorized)")
            
            // Check authorization status on app launch
            Task {
                await MainActor.run {
                    healthKitService.checkAuthorizationStatus()
                }
            }
            
            // Clean up old exports (keep last 10)
            let fileService = FileService()
            fileService.cleanupOldExports()
            
            // Force refresh of relative time displays
            refreshID = UUID()
        }
        .onChange(of: healthKitService.isAuthorized) {
            print("📱 HealthKit authorization changed to: \(healthKitService.isAuthorized)")
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
    
    // MARK: - Pull-to-Refresh
    
    @MainActor
    private func refreshAllData() async {
        print("🔄 Pull-to-refresh triggered")
        
        // Update relative time displays by generating new refresh ID
        refreshID = UUID()
        
        // Check authorization status
        healthKitService.checkAuthorizationStatus()
        
        // Clean up old exports to ensure fresh file list
        let fileService = FileService()
        fileService.cleanupOldExports()
        
        // Check for pending auto-exports if auto-export is enabled
        await checkForPendingAutoExports()
        
        // Small delay to ensure smooth animation
        try? await Task.sleep(for: .milliseconds(300))
        
        print("✅ Pull-to-refresh completed")
    }
    
    private func checkForPendingAutoExports() async {
        guard let configData = UserDefaults.standard.data(forKey: "ExportConfiguration"),
              let config = try? JSONDecoder().decode(ExportConfiguration.self, from: configData),
              config.autoExportEnabled else {
            return
        }
        
        print("🔍 Checking for pending auto-exports...")
        
        // Check if auto-export is overdue
        if let lastAutoExport = UserDefaults.standard.object(forKey: "LastAutoExportTime") as? Date {
            let timeSinceLastExport = Date().timeIntervalSince(lastAutoExport)
            let daysSinceLastExport = timeSinceLastExport / (24 * 60 * 60)
            
            // Check if we're overdue based on frequency
            let isOverdue: Bool
            switch config.autoExportSettings.frequency {
            case .daily:
                isOverdue = daysSinceLastExport > 1.1 // 10% buffer
            case .weekly:
                isOverdue = daysSinceLastExport > 7.7 // 10% buffer
            case .monthly:
                isOverdue = daysSinceLastExport > 31.0 // About a month
            }
            
            if isOverdue {
                print("⏰ Auto-export appears overdue - triggering fallback check")
                // Note: In a real implementation, this would trigger the auto-export logic
                // For now, we just log the detection
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 80))
                .foregroundStyle(.red.gradient)
                .symbolEffect(.pulse.byLayer, options: .speed(0.5).repeating)
            
            VStack(spacing: 8) {
                Text("Health Data Exporter")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Privacy-focused, open-source health data export")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Text("Your health data stays on your device. Export to analyze, backup, or share on your terms.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 20)
    }
    
    private var authorizationSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: healthKitService.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(healthKitService.isAuthorized ? .green : .orange)
                
                Text(healthKitService.isAuthorized ? "Health Access Granted" : "Health Access Required")
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            if !healthKitService.isAuthorized {
                VStack(spacing: 12) {
                    Button("Request Health Access") {
                        Task {
                            do {
                                try await healthKitService.requestAuthorization()
                                print("✅ Health authorization completed successfully")
                            } catch {
                                print("❌ Health authorization failed: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Open Health Settings") {
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Text("If permissions aren't working, go to Settings → Privacy & Security → Health → HealthExporter to manually enable permissions.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Ready to export your health data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var exportSection: some View {
        VStack(spacing: 20) {
            Button(exportButtonTitle) {
                if exportService.isExporting {
                    showingProgress = true
                } else if configuration.encryptionEnabled {
                    showingPasswordAlert = true
                } else {
                    startExport()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.title2)
            .fontWeight(.semibold)
            
            if exportService.isExporting {
                VStack(spacing: 8) {
                    HStack {
                        SwiftUI.ProgressView()
                            .scaleEffect(0.8)
                        Text(exportService.exportProgress.currentOperation.isEmpty ? 
                             "Preparing export..." : 
                             exportService.exportProgress.currentOperation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if exportService.exportProgress.totalSteps > 0 {
                        SwiftUI.ProgressView(value: exportService.exportProgress.progressPercentage, total: 1.0)
                            .frame(height: 4)
                        
                        Text("Step \(exportService.exportProgress.currentStep) of \(exportService.exportProgress.totalSteps)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("View Progress") {
                        showingProgress = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // View Previous Exports Section
            viewExportsSection
        }
    }
    
    private var exportButtonTitle: String {
        if exportService.isExporting {
            return "Export in Progress"
        } else {
            return "Export All Health Data"
        }
    }
    
    private var permissionsDebugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Health Permissions Status")
                .font(.subheadline)
                .fontWeight(.medium)
            
            let commonTypes: [(String, HKSampleType)] = [
                ("Steps", HKQuantityType.quantityType(forIdentifier: .stepCount)!),
                ("Heart Rate", HKQuantityType.quantityType(forIdentifier: .heartRate)!),
                ("Active Energy", HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!),
                ("Distance", HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!),
                ("Sleep", HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!),
                ("Workouts", HKWorkoutType.workoutType())
            ]
            
            ForEach(0..<commonTypes.count, id: \.self) { index in
                let (name, type) = commonTypes[index]
                let status = HKHealthStore().authorizationStatus(for: type)
                
                HStack {
                    Text(name)
                        .font(.caption)
                    Spacer()
                    // Due to HealthKit privacy, show "Granted" if we've made a request
                    let hasRequested = UserDefaults.standard.bool(forKey: "HasRequestedHealthKitAuth")
                    Text(hasRequested ? "Granted" : statusText(for: status))
                        .font(.caption)
                        .foregroundColor(hasRequested ? .green : (status == .sharingAuthorized ? .green : .red))
                }
            }
            
            Button("Open Health Settings") {
                if let url = URL(string: "x-apple-health://") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    private func statusText(for status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Requested"
        case .sharingDenied: return "Denied"
        case .sharingAuthorized: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
    
    private var viewExportsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Previous Exports")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button("View All") {
                    // TODO: Show exports list
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            let unifiedHistory = getUnifiedExportHistory()
            
            if unifiedHistory.isEmpty {
                Text("No exports yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(unifiedHistory.prefix(2).enumerated()), id: \.offset) { index, record in
                    HStack {
                        Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(record.success ? .green : .red)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.fileName ?? "Unknown File")
                                .font(.caption)
                                .lineLimit(1)
                            
                            if record.success {
                                if record.recordCount > 0 {
                                    Text("\(record.recordCount) records • \(record.formattedFileSize) • \(record.date.relativeString)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(record.formattedFileSize) • \(record.date.relativeString)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("\(record.errorMessage ?? "Export failed") • \(record.date.relativeString)")
                                    .font(.caption2)
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
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
        .id(refreshID) // Force refresh when refreshID changes
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Settings")
                .font(.headline)
            
            HStack {
                Text("Format:")
                Spacer()
                Picker("Format", selection: $configuration.exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            Toggle("Encrypt Export", isOn: $configuration.encryptionEnabled)
            
            recentExportsSection
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var recentExportsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Exports")
                .font(.subheadline)
                .fontWeight(.medium)
            
            let unifiedHistory = getUnifiedExportHistory()
            
            if unifiedHistory.isEmpty {
                Text("No exports yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(unifiedHistory.prefix(3)) { record in
                    HStack {
                        Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(record.success ? .green : .red)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.date.exportDisplayString)
                                .font(.caption)
                            
                            if record.success {
                                if record.recordCount > 0 {
                                    Text("\(record.recordCount) records • \(record.formattedFileSize)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(record.formattedFileSize)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text(record.errorMessage ?? "Export failed")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Spacer()
                        
                        Text(record.date.relativeString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .id(refreshID) // Force refresh when refreshID changes
    }
    
    private func startExport() {
        exportService.startExport(
            configuration: configuration,
            password: configuration.encryptionEnabled ? password : nil
        )
        password = ""
    }
    
    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "ExportConfiguration"),
           let savedConfig = try? JSONDecoder().decode(ExportConfiguration.self, from: data) {
            configuration = savedConfig
        }
    }
    
    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "ExportConfiguration")
        }
    }
    
    private func loadSyncState() -> SyncState? {
        return SyncState.load()
    }
    
    private func getUnifiedExportHistory() -> [UnifiedExportRecord] {
        let syncState = SyncState.load()
        let fileService = FileService()
        return syncState.getUnifiedExportHistory(fileService: fileService)
    }
    
    private func getLatestExportFile() -> URL? {
        let fileService = FileService()
        return fileService.listExportFiles().first
    }
    
    
    private func shareExportedFile() {
        guard let fileURL = exportedFileURL else { return }
        shareFile(fileURL)
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
}

#Preview {
    ContentView()
}
