import Foundation
import HealthKit

struct SyncState: Codable {
    private(set) var lastExportDate: Date?
    private(set) var anchors: [String: Data]
    private(set) var exportHistory: [ExportRecord]
    private(set) var lastFullExportDate: Date?
    
    init() {
        self.lastExportDate = nil
        self.anchors = [:]
        self.exportHistory = []
        self.lastFullExportDate = nil
    }
    
    mutating func updateLastExportDate(_ date: Date) {
        self.lastExportDate = date
    }
    
    mutating func updateAnchor(for typeIdentifier: String, anchor: HKQueryAnchor) {
        self.anchors[typeIdentifier] = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    }
    
    func getAnchor(for typeIdentifier: String) -> HKQueryAnchor? {
        guard let data = anchors[typeIdentifier] else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
    
    mutating func addExportRecord(_ record: ExportRecord) {
        exportHistory.append(record)
        if exportHistory.count > 100 {
            exportHistory = Array(exportHistory.suffix(100))
        }
    }
    
    mutating func clearExportHistory() {
        exportHistory.removeAll()
    }
    
    mutating func setLastFullExportDate(_ date: Date) {
        self.lastFullExportDate = date
    }
    
    var needsFullExport: Bool {
        guard let lastFull = lastFullExportDate else { return true }
        return Date().timeIntervalSince(lastFull) > 30 * 24 * 60 * 60
    }
}

struct ExportRecord: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let format: ExportFormat
    let recordCount: Int
    let fileSize: Int64
    let duration: TimeInterval
    let success: Bool
    let errorMessage: String?
    let isIncremental: Bool
    let fileName: String?
    let filePath: String?
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "\(Int(duration))s"
    }
}

struct UnifiedExportRecord: Identifiable {
    let id = UUID()
    let exportRecord: ExportRecord
    let fileURL: URL?
    let fileExists: Bool
    
    // Convenience properties
    var date: Date { exportRecord.date }
    var format: ExportFormat { exportRecord.format }
    var recordCount: Int { exportRecord.recordCount }
    var fileSize: Int64 { exportRecord.fileSize }
    var duration: TimeInterval { exportRecord.duration }
    var success: Bool { exportRecord.success }
    var errorMessage: String? { exportRecord.errorMessage }
    var isIncremental: Bool { exportRecord.isIncremental }
    var fileName: String? { exportRecord.fileName ?? fileURL?.lastPathComponent }
    var formattedFileSize: String { exportRecord.formattedFileSize }
    var formattedDuration: String { exportRecord.formattedDuration }
}

extension SyncState {
    private static let userDefaultsKey = "HealthExporter.SyncState"
    
    static func load() -> SyncState {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let state = try? JSONDecoder().decode(SyncState.self, from: data) else {
            return SyncState()
        }
        return state
    }
    
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    // Unified export history that combines stored records with file system info
    func getUnifiedExportHistory(fileService: FileService) -> [UnifiedExportRecord] {
        var unifiedRecords: [UnifiedExportRecord] = []
        let exportFiles = fileService.listExportFiles()
        
        // Start with stored export records
        for record in exportHistory {
            var matchingFile: URL?
            
            // Try to find matching file by looking for files created around the same time
            if let fileName = record.fileName {
                matchingFile = exportFiles.first { $0.lastPathComponent == fileName }
            } else {
                // Fallback: match by creation date (within 1 minute of export)
                matchingFile = exportFiles.first { fileURL in
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                       let creationDate = attributes[.creationDate] as? Date {
                        return abs(creationDate.timeIntervalSince(record.date)) < 60
                    }
                    return false
                }
            }
            
            unifiedRecords.append(UnifiedExportRecord(
                exportRecord: record,
                fileURL: matchingFile,
                fileExists: matchingFile != nil
            ))
        }
        
        // Add any files that don't have corresponding export records
        let recordedFileNames = Set(exportHistory.compactMap { $0.fileName })
        let unmatchedFiles = exportFiles.filter { !recordedFileNames.contains($0.lastPathComponent) }
        
        for fileURL in unmatchedFiles {
            // Create export record from file info
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               let fileSize = attributes[.size] as? Int64 {
                
                let format: ExportFormat = fileURL.pathExtension == "db" ? .sqlite : .json
                let fileName = fileURL.lastPathComponent
                
                let syntheticRecord = ExportRecord(
                    date: creationDate,
                    format: format,
                    recordCount: 0, // Unknown for files without records
                    fileSize: fileSize,
                    duration: 0, // Unknown
                    success: true, // Assume successful if file exists
                    errorMessage: nil,
                    isIncremental: false, // Unknown
                    fileName: fileName,
                    filePath: fileURL.path
                )
                
                unifiedRecords.append(UnifiedExportRecord(
                    exportRecord: syntheticRecord,
                    fileURL: fileURL,
                    fileExists: true
                ))
            }
        }
        
        // Sort by date (newest first)
        return unifiedRecords.sorted { $0.exportRecord.date > $1.exportRecord.date }
    }
}
