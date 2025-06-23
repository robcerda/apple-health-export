import SwiftUI

struct ProgressView: View {
    @ObservedObject var exportService: ExportService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                headerSection
                
                progressSection
                
                currentOperationSection
                
                Spacer()
                
                if !exportService.exportProgress.isCompleted && !exportService.exportProgress.isFailed {
                    cancelButton
                }
            }
            .padding()
            .navigationTitle("Exporting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if exportService.exportProgress.isCompleted || exportService.exportProgress.isFailed {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(!exportService.exportProgress.isCompleted && !exportService.exportProgress.isFailed)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: exportService.exportProgress.progressPercentage)
                    .stroke(
                        exportService.exportProgress.isFailed ? Color.red :
                        exportService.exportProgress.isCompleted ? Color.green :
                        Color.blue,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: exportService.exportProgress.progressPercentage)
                
                Group {
                    if exportService.exportProgress.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.title)
                            .foregroundColor(.green)
                    } else if exportService.exportProgress.isFailed {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.red)
                    } else {
                        Text("\(Int(exportService.exportProgress.progressPercentage * 100))%")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            Text(exportService.exportProgress.stage.description)
                .font(.title2)
                .fontWeight(.medium)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(exportService.exportProgress.currentStep) of \(exportService.exportProgress.totalSteps)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: exportService.exportProgress.progressPercentage)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(y: 2)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var currentOperationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Operation")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(exportService.exportProgress.currentOperation.isEmpty ? "Preparing..." : exportService.exportProgress.currentOperation)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            if exportService.exportProgress.isCompleted {
                successMessage
            } else if exportService.exportProgress.isFailed {
                errorMessage
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var successMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Export completed successfully!")
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            .padding(.top, 8)
            
            Text("Your health data has been exported and saved to your device. You can now share or backup the file as needed.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var errorMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Export failed")
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            }
            .padding(.top, 8)
            
            if let error = exportService.lastError {
                Text(error.userFriendlyMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var cancelButton: some View {
        Button("Cancel Export") {
            exportService.cancelExport()
            dismiss()
        }
        .buttonStyle(.bordered)
        .foregroundColor(.red)
    }
}

#Preview {
    let exportService = ExportService(
        healthKitService: HealthKitService(),
        fileService: FileService(),
        encryptionService: EncryptionService()
    )
    
    return ProgressView(exportService: exportService)
}