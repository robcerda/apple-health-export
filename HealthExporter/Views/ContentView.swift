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
    @State private var exportedFileURL: URL?
    
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
        NavigationView {
            VStack(spacing: 30) {
                headerSection
                
                authorizationSection
                
                if healthKitService.isAuthorized {
                    exportSection
                    
                    permissionsDebugSection
                    
                    configurationSection
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Health Exporter")
            .navigationBarTitleDisplayMode(.large)
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
                Button("Open Files App") {
                    openFilesApp()
                }
                Button("Share") {
                    shareExportedFile()
                }
                Button("OK") { }
            } message: {
                if let fileURL = exportedFileURL {
                    let fileManager = FileManager.default
                    let fileSize = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
                    let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                    Text("Your health data has been exported successfully!\n\nFile: \(fileURL.lastPathComponent)\nSize: \(formattedSize)\n\nYou can find it in the Files app under 'On My iPhone > Health Exporter'.")
                } else {
                    Text("Your health data has been exported successfully!")
                }
            }
        }
        .onChange(of: exportService.isExporting) { isExporting in
            showingProgress = isExporting
        }
        .onChange(of: exportService.lastError != nil) { hasError in
            if hasError {
                showingErrorAlert = true
            }
        }
        .onChange(of: exportService.exportProgress.stage) { stage in
            if stage == .completed && exportService.lastError == nil {
                // Export completed successfully
                exportedFileURL = getLatestExportFile()
                showingSuccessAlert = true
            }
        }
        .onAppear {
            loadConfiguration()
            print("📱 ContentView appeared - HealthKit authorized: \(healthKitService.isAuthorized)")
            
            // Reset authorization to request the new FOCUSED set of permissions
            UserDefaults.standard.set(false, forKey: "HasRequestedHealthKitAuth")
            print("🔄 Reset authorization to request FOCUSED core health data types")
            
            // Force recheck authorization status
            Task {
                await MainActor.run {
                    healthKitService.checkAuthorizationStatus()
                }
            }
        }
        .onChange(of: healthKitService.isAuthorized) { isAuthorized in
            print("📱 HealthKit authorization changed to: \(isAuthorized)")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Export Your Health Data")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Privacy-focused, open-source health data export. No data leaves your device without your explicit action.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
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
                Text("✅ Health access granted - \(healthKitService.authorizationStatus)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var exportSection: some View {
        VStack(spacing: 16) {
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
            .font(.headline)
            
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
            
            let fileService = FileService()
            let exportFiles = fileService.listExportFiles()
            
            if exportFiles.isEmpty {
                Text("No exports yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(exportFiles.prefix(2).enumerated()), id: \.offset) { index, fileURL in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileURL.lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                            
                            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                               let fileSize = attributes[.size] as? Int64,
                               let creationDate = attributes[.creationDate] as? Date {
                                Text("\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)) • \(creationDate.relativeString)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Share") {
                            shareFile(fileURL)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
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
            
            if let syncState = loadSyncState() {
                exportHistorySection(syncState: syncState)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func exportHistorySection(syncState: SyncState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Exports")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if syncState.exportHistory.isEmpty {
                Text("No exports yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(syncState.exportHistory.prefix(3)) { record in
                    HStack {
                        Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(record.success ? .green : .red)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.date.exportDisplayString)
                                .font(.caption)
                            
                            if record.success {
                                Text("\(record.recordCount) records • \(record.formattedFileSize)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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
    
    private func getLatestExportFile() -> URL? {
        let fileService = FileService()
        return fileService.listExportFiles().first
    }
    
    private func openFilesApp() {
        if let url = URL(string: "shareddocuments://") {
            UIApplication.shared.open(url)
        }
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
