import Foundation
import HealthKit

struct ExportConfiguration: Codable {
    let exportFormat: ExportFormat
    let dateRange: DateRange?
    let enabledDataTypes: Set<String>
    let encryptionEnabled: Bool
    let autoExportEnabled: Bool
    let autoExportFrequency: AutoExportFrequency
    let batchSize: Int
    
    static let `default` = ExportConfiguration(
        exportFormat: .json,
        dateRange: nil,
        enabledDataTypes: Set(SupportedHealthDataTypes.allTypes.map(\.identifier)),
        encryptionEnabled: false,
        autoExportEnabled: false,
        autoExportFrequency: .weekly,
        batchSize: 10_000
    )
    
    struct DateRange: Codable {
        let start: Date
        let end: Date
    }
}

enum ExportFormat: String, Codable, CaseIterable {
    case json = "JSON"
    case sqlite = "SQLite"
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .sqlite: return "db"
        }
    }
}

enum AutoExportFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    
    var timeInterval: TimeInterval {
        switch self {
        case .daily: return 24 * 60 * 60
        case .weekly: return 7 * 24 * 60 * 60
        case .monthly: return 30 * 24 * 60 * 60
        }
    }
}

struct SupportedHealthDataTypes {
    static let quantityTypes: [HKQuantityTypeIdentifier] = [
        .heartRate,
        .restingHeartRate,
        .heartRateVariabilitySDNN,
        .stepCount,
        .distanceWalkingRunning,
        .activeEnergyBurned,
        .basalEnergyBurned,
        .bodyMass,
        .bodyFatPercentage,
        .bodyMassIndex,
        .leanBodyMass,
        .bloodGlucose,
        .bloodPressureSystolic,
        .bloodPressureDiastolic,
        .respiratoryRate,
        .bodyTemperature,
        .oxygenSaturation,
        .vo2Max,
        .flightsClimbed,
        .nikeFuel,
        .appleExerciseTime,
        .appleStandTime,
        .waistCircumference,
        .height
    ]
    
    static let categoryTypes: [HKCategoryTypeIdentifier] = [
        .sleepAnalysis,
        .mindfulSession,
        .menstrualFlow,
        .intermenstrualBleeding,
        .sexualActivity,
        .cervicalMucusQuality,
        .ovulationTestResult,
        .pregnancyTestResult,
        .progesteroneTestResult,
        .appleStandHour,
        .toothbrushingEvent,
        .lowHeartRateEvent,
        .highHeartRateEvent,
        .irregularHeartRhythmEvent
    ]
    
    static let workoutType = HKWorkoutType.workoutType()
    
    static let clinicalTypes: [HKClinicalTypeIdentifier] = [
        .allergyRecord,
        .conditionRecord,
        .immunizationRecord,
        .labResultRecord,
        .medicationRecord,
        .procedureRecord,
        .vitalSignRecord
    ]
    
    static let allTypes: [HKSampleType] = {
        var types: [HKSampleType] = []
        
        for identifier in quantityTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.append(type)
            }
        }
        
        for identifier in categoryTypes {
            if let type = HKCategoryType.categoryType(forIdentifier: identifier) {
                types.append(type)
            }
        }
        
        types.append(workoutType)
        
        for identifier in clinicalTypes {
            if let type = HKClinicalType.clinicalType(forIdentifier: identifier) {
                types.append(type)
            }
        }
        
        return types
    }()
    
    static func displayName(for type: HKSampleType) -> String {
        switch type {
        case is HKQuantityType:
            return quantityDisplayNames[type.identifier] ?? type.identifier
        case is HKCategoryType:
            return categoryDisplayNames[type.identifier] ?? type.identifier
        case is HKWorkoutType:
            return "Workouts"
        case is HKClinicalType:
            return clinicalDisplayNames[type.identifier] ?? type.identifier
        default:
            return type.identifier
        }
    }
    
    private static let quantityDisplayNames: [String: String] = [
        HKQuantityTypeIdentifier.heartRate.rawValue: "Heart Rate",
        HKQuantityTypeIdentifier.restingHeartRate.rawValue: "Resting Heart Rate",
        HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: "Heart Rate Variability",
        HKQuantityTypeIdentifier.stepCount.rawValue: "Steps",
        HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue: "Walking + Running Distance",
        HKQuantityTypeIdentifier.activeEnergyBurned.rawValue: "Active Energy",
        HKQuantityTypeIdentifier.basalEnergyBurned.rawValue: "Resting Energy",
        HKQuantityTypeIdentifier.bodyMass.rawValue: "Weight",
        HKQuantityTypeIdentifier.bodyFatPercentage.rawValue: "Body Fat Percentage",
        HKQuantityTypeIdentifier.bloodGlucose.rawValue: "Blood Glucose",
        HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue: "Blood Pressure Systolic",
        HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue: "Blood Pressure Diastolic",
        HKQuantityTypeIdentifier.respiratoryRate.rawValue: "Respiratory Rate",
        HKQuantityTypeIdentifier.bodyTemperature.rawValue: "Body Temperature",
        HKQuantityTypeIdentifier.oxygenSaturation.rawValue: "Blood Oxygen"
    ]
    
    private static let categoryDisplayNames: [String: String] = [
        HKCategoryTypeIdentifier.sleepAnalysis.rawValue: "Sleep Analysis",
        HKCategoryTypeIdentifier.mindfulSession.rawValue: "Mindfulness",
        HKCategoryTypeIdentifier.menstrualFlow.rawValue: "Menstrual Flow"
    ]
    
    private static let clinicalDisplayNames: [String: String] = [
        HKClinicalTypeIdentifier.allergyRecord.rawValue: "Allergies",
        HKClinicalTypeIdentifier.conditionRecord.rawValue: "Conditions",
        HKClinicalTypeIdentifier.immunizationRecord.rawValue: "Immunizations",
        HKClinicalTypeIdentifier.labResultRecord.rawValue: "Lab Results",
        HKClinicalTypeIdentifier.medicationRecord.rawValue: "Medications",
        HKClinicalTypeIdentifier.procedureRecord.rawValue: "Procedures",
        HKClinicalTypeIdentifier.vitalSignRecord.rawValue: "Vital Signs"
    ]
}