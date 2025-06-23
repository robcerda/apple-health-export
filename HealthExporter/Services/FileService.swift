import Foundation
import SQLite3

class FileService {
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func writeFile(data: Data, filename: String) async throws -> URL {
        var fileURL = documentsDirectory.appendingPathComponent(filename)
        
        try data.write(to: fileURL, options: [.atomic])
        
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        try fileURL.setResourceValues(resourceValues)
        
        return fileURL
    }
    
    func createSQLiteDatabase(
        exportData: HealthDataExport,
        encrypted: Bool,
        password: String?
    ) async throws -> URL {
        
        let filename = generateSQLiteFilename(encrypted: encrypted)
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        var db: OpaquePointer?
        
        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
            throw FileServiceError.databaseCreationFailed
        }
        
        defer {
            sqlite3_close(db)
        }
        
        try createTables(db: db)
        try insertData(db: db, exportData: exportData)
        
        if encrypted, let password = password {
            try encryptDatabase(at: fileURL, password: password)
        }
        
        return fileURL
    }
    
    private func createTables(db: OpaquePointer?) throws {
        let createTablesSQL = """
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT
        );
        
        CREATE TABLE quantity_samples (
            uuid TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            value REAL NOT NULL,
            unit TEXT NOT NULL,
            source_name TEXT,
            source_bundle_id TEXT,
            device_name TEXT,
            metadata TEXT
        );
        
        CREATE TABLE category_samples (
            uuid TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            value INTEGER NOT NULL,
            source_name TEXT,
            source_bundle_id TEXT,
            device_name TEXT,
            metadata TEXT
        );
        
        CREATE TABLE workouts (
            uuid TEXT PRIMARY KEY,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            activity_type TEXT NOT NULL,
            duration REAL NOT NULL,
            energy_burned REAL,
            energy_burned_unit TEXT,
            distance REAL,
            distance_unit TEXT,
            source_name TEXT,
            source_bundle_id TEXT,
            device_name TEXT,
            metadata TEXT
        );
        
        CREATE TABLE workout_heart_rate (
            workout_uuid TEXT NOT NULL,
            sample_uuid TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            value REAL NOT NULL,
            unit TEXT NOT NULL,
            FOREIGN KEY (workout_uuid) REFERENCES workouts(uuid)
        );
        
        CREATE TABLE clinical_records (
            uuid TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            display_name TEXT,
            fhir_resource BLOB,
            source_name TEXT,
            source_bundle_id TEXT
        );
        
        CREATE INDEX idx_quantity_type ON quantity_samples(type);
        CREATE INDEX idx_quantity_date ON quantity_samples(start_date);
        CREATE INDEX idx_category_type ON category_samples(type);
        CREATE INDEX idx_category_date ON category_samples(start_date);
        CREATE INDEX idx_workout_date ON workouts(start_date);
        CREATE INDEX idx_workout_type ON workouts(activity_type);
        CREATE INDEX idx_clinical_type ON clinical_records(type);
        CREATE INDEX idx_clinical_date ON clinical_records(start_date);
        """
        
        guard sqlite3_exec(db, createTablesSQL, nil, nil, nil) == SQLITE_OK else {
            throw FileServiceError.databaseCreationFailed
        }
    }
    
    private func insertData(db: OpaquePointer?, exportData: HealthDataExport) throws {
        let dateFormatter = ISO8601DateFormatter()
        
        try insertMetadata(db: db, metadata: exportData.metadata, dateFormatter: dateFormatter)
        
        for (type, samples) in exportData.healthData.quantityData {
            for sample in samples {
                try insertQuantitySample(db: db, type: type, sample: sample, dateFormatter: dateFormatter)
            }
        }
        
        for (type, samples) in exportData.healthData.categoryData {
            for sample in samples {
                try insertCategorySample(db: db, type: type, sample: sample, dateFormatter: dateFormatter)
            }
        }
        
        for workout in exportData.healthData.workoutData {
            try insertWorkout(db: db, workout: workout, dateFormatter: dateFormatter)
            
            for heartRateSample in workout.heartRateData {
                try insertWorkoutHeartRate(db: db, workoutUUID: workout.uuid, sample: heartRateSample, dateFormatter: dateFormatter)
            }
        }
        
        for clinical in exportData.healthData.clinicalData {
            try insertClinicalRecord(db: db, clinical: clinical, dateFormatter: dateFormatter)
        }
    }
    
    private func insertMetadata(db: OpaquePointer?, metadata: ExportMetadata, dateFormatter: ISO8601DateFormatter) throws {
        let insertSQL = "INSERT INTO metadata (key, value) VALUES (?, ?)"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FileServiceError.databaseInsertFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        let metadataItems = [
            ("export_date", dateFormatter.string(from: metadata.exportDate)),
            ("start_date", dateFormatter.string(from: metadata.dataDateRange.start)),
            ("end_date", dateFormatter.string(from: metadata.dataDateRange.end)),
            ("version", metadata.version),
            ("record_count", String(metadata.recordCount)),
            ("encrypted", String(metadata.encrypted))
        ]
        
        for (key, value) in metadataItems {
            sqlite3_bind_text(statement, 1, key, -1, nil)
            sqlite3_bind_text(statement, 2, value, -1, nil)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw FileServiceError.databaseInsertFailed
            }
            
            sqlite3_reset(statement)
        }
    }
    
    private func insertQuantitySample(db: OpaquePointer?, type: String, sample: QuantitySample, dateFormatter: ISO8601DateFormatter) throws {
        let insertSQL = """
        INSERT INTO quantity_samples 
        (uuid, type, start_date, end_date, value, unit, source_name, source_bundle_id, device_name, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FileServiceError.databaseInsertFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, sample.uuid, -1, nil)
        sqlite3_bind_text(statement, 2, type, -1, nil)
        sqlite3_bind_text(statement, 3, dateFormatter.string(from: sample.startDate), -1, nil)
        sqlite3_bind_text(statement, 4, dateFormatter.string(from: sample.endDate), -1, nil)
        sqlite3_bind_double(statement, 5, sample.value)
        sqlite3_bind_text(statement, 6, sample.unit, -1, nil)
        sqlite3_bind_text(statement, 7, sample.sourceRevision.source.name, -1, nil)
        sqlite3_bind_text(statement, 8, sample.sourceRevision.source.bundleIdentifier, -1, nil)
        sqlite3_bind_text(statement, 9, sample.device?.name, -1, nil)
        
        if let metadata = sample.metadata,
           let metadataData = try? JSONSerialization.data(withJSONObject: metadata),
           let metadataString = String(data: metadataData, encoding: .utf8) {
            sqlite3_bind_text(statement, 10, metadataString, -1, nil)
        } else {
            sqlite3_bind_null(statement, 10)
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FileServiceError.databaseInsertFailed
        }
    }
    
    private func insertCategorySample(db: OpaquePointer?, type: String, sample: CategorySample, dateFormatter: ISO8601DateFormatter) throws {
        let insertSQL = """
        INSERT INTO category_samples 
        (uuid, type, start_date, end_date, value, source_name, source_bundle_id, device_name, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FileServiceError.databaseInsertFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, sample.uuid, -1, nil)
        sqlite3_bind_text(statement, 2, type, -1, nil)
        sqlite3_bind_text(statement, 3, dateFormatter.string(from: sample.startDate), -1, nil)
        sqlite3_bind_text(statement, 4, dateFormatter.string(from: sample.endDate), -1, nil)
        sqlite3_bind_int(statement, 5, Int32(sample.value))
        sqlite3_bind_text(statement, 6, sample.sourceRevision.source.name, -1, nil)
        sqlite3_bind_text(statement, 7, sample.sourceRevision.source.bundleIdentifier, -1, nil)
        sqlite3_bind_text(statement, 8, sample.device?.name, -1, nil)
        
        if let metadata = sample.metadata,
           let metadataData = try? JSONSerialization.data(withJSONObject: metadata),
           let metadataString = String(data: metadataData, encoding: .utf8) {
            sqlite3_bind_text(statement, 9, metadataString, -1, nil)
        } else {
            sqlite3_bind_null(statement, 9)
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FileServiceError.databaseInsertFailed
        }
    }
    
    private func insertWorkout(db: OpaquePointer?, workout: WorkoutSample, dateFormatter: ISO8601DateFormatter) throws {
        let insertSQL = """
        INSERT INTO workouts 
        (uuid, start_date, end_date, activity_type, duration, energy_burned, energy_burned_unit, 
         distance, distance_unit, source_name, source_bundle_id, device_name, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FileServiceError.databaseInsertFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, workout.uuid, -1, nil)
        sqlite3_bind_text(statement, 2, dateFormatter.string(from: workout.startDate), -1, nil)
        sqlite3_bind_text(statement, 3, dateFormatter.string(from: workout.endDate), -1, nil)
        sqlite3_bind_text(statement, 4, workout.workoutActivityType, -1, nil)
        sqlite3_bind_double(statement, 5, workout.duration)
        
        if let energyBurned = workout.totalEnergyBurned {
            sqlite3_bind_double(statement, 6, energyBurned)
        } else {
            sqlite3_bind_null(statement, 6)
        }
        
        sqlite3_bind_text(statement, 7, workout.totalEnergyBurnedUnit, -1, nil)
        
        if let distance = workout.totalDistance {
            sqlite3_bind_double(statement, 8, distance)
        } else {
            sqlite3_bind_null(statement, 8)
        }
        
        sqlite3_bind_text(statement, 9, workout.totalDistanceUnit, -1, nil)
        sqlite3_bind_text(statement, 10, workout.sourceRevision.source.name, -1, nil)
        sqlite3_bind_text(statement, 11, workout.sourceRevision.source.bundleIdentifier, -1, nil)
        sqlite3_bind_text(statement, 12, workout.device?.name, -1, nil)
        
        if let metadata = workout.metadata,
           let metadataData = try? JSONSerialization.data(withJSONObject: metadata),
           let metadataString = String(data: metadataData, encoding: .utf8) {
            sqlite3_bind_text(statement, 13, metadataString, -1, nil)
        } else {
            sqlite3_bind_null(statement, 13)
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FileServiceError.databaseInsertFailed
        }
    }
    
    private func insertWorkoutHeartRate(db: OpaquePointer?, workoutUUID: String, sample: QuantitySample, dateFormatter: ISO8601DateFormatter) throws {
        let insertSQL = """
        INSERT INTO workout_heart_rate 
        (workout_uuid, sample_uuid, start_date, end_date, value, unit)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FileServiceError.databaseInsertFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, workoutUUID, -1, nil)
        sqlite3_bind_text(statement, 2, sample.uuid, -1, nil)
        sqlite3_bind_text(statement, 3, dateFormatter.string(from: sample.startDate), -1, nil)
        sqlite3_bind_text(statement, 4, dateFormatter.string(from: sample.endDate), -1, nil)
        sqlite3_bind_double(statement, 5, sample.value)
        sqlite3_bind_text(statement, 6, sample.unit, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FileServiceError.databaseInsertFailed
        }
    }
    
    private func insertClinicalRecord(db: OpaquePointer?, clinical: ClinicalSample, dateFormatter: ISO8601DateFormatter) throws {
        let insertSQL = """
        INSERT INTO clinical_records 
        (uuid, type, start_date, end_date, display_name, fhir_resource, source_name, source_bundle_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw FileServiceError.databaseInsertFailed
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, clinical.uuid, -1, nil)
        sqlite3_bind_text(statement, 2, clinical.clinicalType, -1, nil)
        sqlite3_bind_text(statement, 3, dateFormatter.string(from: clinical.startDate), -1, nil)
        sqlite3_bind_text(statement, 4, dateFormatter.string(from: clinical.endDate), -1, nil)
        sqlite3_bind_text(statement, 5, clinical.displayName, -1, nil)
        
        if let fhirResource = clinical.fhirResource {
            sqlite3_bind_blob(statement, 6, fhirResource.withUnsafeBytes { $0.baseAddress }, Int32(fhirResource.count), nil)
        } else {
            sqlite3_bind_null(statement, 6)
        }
        
        sqlite3_bind_text(statement, 7, clinical.sourceRevision.source.name, -1, nil)
        sqlite3_bind_text(statement, 8, clinical.sourceRevision.source.bundleIdentifier, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FileServiceError.databaseInsertFailed
        }
    }
    
    private func encryptDatabase(at fileURL: URL, password: String) throws {
        let encryptionService = EncryptionService()
        let data = try Data(contentsOf: fileURL)
        let encryptedData = try encryptionService.encrypt(data: data, password: password)
        try encryptedData.write(to: fileURL)
    }
    
    private func generateSQLiteFilename(encrypted: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let encryptedSuffix = encrypted ? "_encrypted" : ""
        return "health_export_\(timestamp)\(encryptedSuffix).db"
    }
    
    func getExportsDirectory() -> URL {
        return documentsDirectory
    }
    
    func listExportFiles() -> [URL] {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            return contents.filter { url in
                let filename = url.lastPathComponent
                return filename.hasPrefix("health_export_")
            }.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            return []
        }
    }
}

enum FileServiceError: LocalizedError {
    case databaseCreationFailed
    case databaseInsertFailed
    case fileWriteError
    
    var errorDescription: String? {
        switch self {
        case .databaseCreationFailed:
            return "Failed to create SQLite database"
        case .databaseInsertFailed:
            return "Failed to insert data into database"
        case .fileWriteError:
            return "Failed to write file"
        }
    }
}
