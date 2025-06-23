import Foundation
import HealthKit

struct HealthDataExport: Codable {
    let metadata: ExportMetadata
    let healthData: HealthDataCollection
}

struct ExportMetadata: Codable {
    let exportDate: Date
    let dataDateRange: DateRange
    let version: String
    let recordCount: Int
    let encrypted: Bool
    
    struct DateRange: Codable {
        let start: Date
        let end: Date
    }
}

struct HealthDataCollection: Codable {
    var quantityData: [String: [QuantitySample]]
    var categoryData: [String: [CategorySample]]
    var workoutData: [WorkoutSample]
    var clinicalData: [ClinicalSample]
    
    init() {
        self.quantityData = [:]
        self.categoryData = [:]
        self.workoutData = []
        self.clinicalData = []
    }
}

struct QuantitySample: Codable {
    let uuid: String
    let startDate: Date
    let endDate: Date
    let value: Double
    let unit: String
    let sourceRevision: SourceRevision
    let device: DeviceInfo?
    let metadata: [String: String]?
}

struct CategorySample: Codable {
    let uuid: String
    let startDate: Date
    let endDate: Date
    let value: Int
    let sourceRevision: SourceRevision
    let device: DeviceInfo?
    let metadata: [String: String]?
}

struct WorkoutSample: Codable {
    let uuid: String
    let startDate: Date
    let endDate: Date
    let workoutActivityType: String
    let duration: TimeInterval
    let totalEnergyBurned: Double?
    let totalEnergyBurnedUnit: String?
    let totalDistance: Double?
    let totalDistanceUnit: String?
    let sourceRevision: SourceRevision
    let device: DeviceInfo?
    let metadata: [String: String]?
    let workoutEvents: [WorkoutEvent]
    let heartRateData: [QuantitySample]
}

struct WorkoutEvent: Codable {
    let type: String
    let date: Date
    let metadata: [String: String]?
}

struct ClinicalSample: Codable {
    let uuid: String
    let startDate: Date
    let endDate: Date
    let clinicalType: String
    let displayName: String
    let fhirResource: Data?
    let sourceRevision: SourceRevision
}

struct SourceRevision: Codable {
    let source: SourceInfo
    let version: String?
    let productType: String?
    let systemVersion: String?
}

struct SourceInfo: Codable {
    let name: String
    let bundleIdentifier: String
}

struct DeviceInfo: Codable {
    let name: String?
    let manufacturer: String?
    let model: String?
    let hardwareVersion: String?
    let firmwareVersion: String?
    let softwareVersion: String?
    let localIdentifier: String?
}

extension HKQuantitySample {
    func toQuantitySample() -> QuantitySample {
        // Parse value and unit from the quantity's string description
        // This completely avoids unit conversion issues that cause crashes
        let description = quantity.description
        
        // Extract numeric value (everything before the first space or non-numeric character)
        let valueString = String(description.prefix(while: { $0.isNumber || $0 == "." || $0 == "-" }))
        let value = Double(valueString) ?? 0.0
        
        // Extract unit (everything after the value and space)
        let unitString = description.replacingOccurrences(of: valueString, with: "").trimmingCharacters(in: .whitespaces)
        
        return QuantitySample(
            uuid: uuid.uuidString,
            startDate: startDate,
            endDate: endDate,
            value: value,
            unit: unitString.isEmpty ? "count" : unitString,
            sourceRevision: sourceRevision.toSourceRevision(),
            device: device?.toDeviceInfo(),
            metadata: metadata?.compactMapValues { "\($0)" }
        )
    }
}

extension HKCategorySample {
    func toCategorySample() -> CategorySample {
        return CategorySample(
            uuid: uuid.uuidString,
            startDate: startDate,
            endDate: endDate,
            value: value,
            sourceRevision: sourceRevision.toSourceRevision(),
            device: device?.toDeviceInfo(),
            metadata: metadata?.compactMapValues { "\($0)" }
        )
    }
}

extension HKWorkout {
    func toWorkoutSample(heartRateData: [QuantitySample] = []) -> WorkoutSample {
        return WorkoutSample(
            uuid: uuid.uuidString,
            startDate: startDate,
            endDate: endDate,
            workoutActivityType: "\(workoutActivityType.rawValue)",
            duration: duration,
            totalEnergyBurned: totalEnergyBurned?.doubleValue(for: .kilocalorie()),
            totalEnergyBurnedUnit: totalEnergyBurned?.description,
            totalDistance: totalDistance?.doubleValue(for: .meter()),
            totalDistanceUnit: totalDistance?.description,
            sourceRevision: sourceRevision.toSourceRevision(),
            device: device?.toDeviceInfo(),
            metadata: metadata?.compactMapValues { "\($0)" },
            workoutEvents: workoutEvents?.map { $0.toWorkoutEvent() } ?? [],
            heartRateData: heartRateData
        )
    }
}

extension HKWorkoutEvent {
    func toWorkoutEvent() -> WorkoutEvent {
        return WorkoutEvent(
            type: "\(type.rawValue)",
            date: dateInterval.start,
            metadata: metadata?.compactMapValues { "\($0)" }
        )
    }
}

extension HKSourceRevision {
    func toSourceRevision() -> SourceRevision {
        return SourceRevision(
            source: source.toSourceInfo(),
            version: version,
            productType: productType,
            systemVersion: "\(operatingSystemVersion.majorVersion).\(operatingSystemVersion.minorVersion).\(operatingSystemVersion.patchVersion)"
        )
    }
}

extension HKSource {
    func toSourceInfo() -> SourceInfo {
        return SourceInfo(
            name: name,
            bundleIdentifier: bundleIdentifier
        )
    }
}

extension HKDevice {
    func toDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            name: name,
            manufacturer: manufacturer,
            model: model,
            hardwareVersion: hardwareVersion,
            firmwareVersion: firmwareVersion,
            softwareVersion: softwareVersion,
            localIdentifier: localIdentifier
        )
    }
}
