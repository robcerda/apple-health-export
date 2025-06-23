import SwiftUI
import HealthKit

struct SettingsView: View {
    @Binding var configuration: ExportConfiguration
    @Environment(\.dismiss) private var dismiss
    
    @State private var customDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var syncState = SyncState.load()
    
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
                
                // Summary
                Label {
                    Text("Will export \(configuration.autoExportSettings.dataRange.rawValue.lowercased()) \(configuration.autoExportSettings.frequency.nextRunDescription.lowercased()) at \(configuration.autoExportSettings.timeOfDay.displayString) in \(configuration.autoExportSettings.format.rawValue) format")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var exportHistorySection: some View {
        Section("Export History") {
            if syncState.exportHistory.isEmpty {
                Text("No exports yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(syncState.exportHistory) { record in
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
                            }
                            
                            if record.success {
                                Text("\(record.recordCount) records • \(record.formattedFileSize) • \(record.formattedDuration)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(record.errorMessage ?? "Export failed")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Spacer()
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
            }
            
            if let lastFull = syncState.lastFullExportDate {
                HStack {
                    Text("Last Full Export")
                    Spacer()
                    Text(lastFull.relativeString)
                        .foregroundColor(.secondary)
                }
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
        }
    }
}

#Preview {
    SettingsView(configuration: .constant(ExportConfiguration.default))
}