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
        }
        .onChange(of: exportService.isExporting) { isExporting in
            showingProgress = isExporting
        }
        .onChange(of: exportService.lastError) { error in
            if error != nil {
                showingErrorAlert = true
            }
        }
        .onAppear {
            loadConfiguration()
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
                Button("Request Health Access") {
                    Task {
                        try? await healthKitService.requestAuthorization()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var exportSection: some View {
        VStack(spacing: 16) {
            Button("Export All Health Data") {
                if configuration.encryptionEnabled {
                    showingPasswordAlert = true
                } else {
                    startExport()
                }
            }
            .buttonStyle(.borderedProminent)
            .font(.headline)
            .disabled(exportService.isExporting)
            
            if exportService.isExporting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Exporting...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
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
}

#Preview {
    ContentView()
}