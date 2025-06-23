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
    
    mutating func setLastFullExportDate(_ date: Date) {
        self.lastFullExportDate = date
    }
    
    var needsFullExport: Bool {
        guard let lastFull = lastFullExportDate else { return true }
        return Date().timeIntervalSince(lastFull) > 30 * 24 * 60 * 60
    }
}

struct ExportRecord: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let format: ExportFormat
    let recordCount: Int
    let fileSize: Int64
    let duration: TimeInterval
    let success: Bool
    let errorMessage: String?
    let isIncremental: Bool
    
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
}