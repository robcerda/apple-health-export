import Foundation
import HealthKit

struct ExportConfiguration: Codable {
    var exportFormat: ExportFormat
    var dateRange: DateRange?
    var enabledDataTypes: Set<String>
    var encryptionEnabled: Bool
    var autoExportEnabled: Bool
    var autoExportSettings: AutoExportSettings
    var batchSize: Int
    
    static let `default` = ExportConfiguration(
        exportFormat: .json,
        dateRange: nil,
        enabledDataTypes: Set(SupportedHealthDataTypes.allTypes.map(\.identifier)),
        encryptionEnabled: false,
        autoExportEnabled: false,
        autoExportSettings: AutoExportSettings.default,
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

struct AutoExportSettings: Codable {
    var frequency: AutoExportFrequency
    var timeOfDay: TimeOfDay // When to run the export
    var dataRange: AutoExportDataRange // What time period to export
    var format: ExportFormat // Can be different from manual export
    var encryptionEnabled: Bool // Independent encryption setting
    
    static let `default` = AutoExportSettings(
        frequency: .weekly,
        timeOfDay: TimeOfDay(hour: 2, minute: 0), // 2:00 AM
        dataRange: .sinceLast,
        format: .json,
        encryptionEnabled: false
    )
}

struct TimeOfDay: Codable {
    var hour: Int // 0-23
    var minute: Int // 0-59
    
    var displayString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return formatter.string(from: date)
    }
}

enum AutoExportFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    
    var displayName: String {
        return rawValue
    }
    
    var nextRunDescription: String {
        switch self {
        case .daily: return "Every day"
        case .weekly: return "Every Sunday"
        case .monthly: return "First of each month"
        }
    }
}

enum AutoExportDataRange: String, Codable, CaseIterable {
    case sinceLast = "Since Last Export"
    case last24Hours = "Last 24 Hours"
    case lastWeek = "Last 7 Days"
    case lastMonth = "Last 30 Days"
    case allData = "All Available Data"
    
    var description: String {
        switch self {
        case .sinceLast: return "Export only new data since the last auto-export"
        case .last24Hours: return "Export the previous 24 hours of data"
        case .lastWeek: return "Export the previous 7 days of data"
        case .lastMonth: return "Export the previous 30 days of data"
        case .allData: return "Export all available health data (large files)"
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
        var allTypes: [HKSampleType] = []
        
        // EXPANDED REQUEST: Common data types users actually have
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            // Activity & Fitness (most common)
            .stepCount, .distanceWalkingRunning, .distanceCycling, .activeEnergyBurned, .basalEnergyBurned, 
            .flightsClimbed, .appleExerciseTime, .appleStandTime,
            
            // Heart Health (very common with Apple Watch)
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN, .walkingHeartRateAverage,
            
            // Body Measurements (common)
            .bodyMass, .height, .bodyMassIndex, .bodyFatPercentage, .leanBodyMass,
            
            // Health Vitals (if available)
            .bloodGlucose, .oxygenSaturation, .bodyTemperature, .bloodPressureSystolic, .bloodPressureDiastolic,
            .respiratoryRate,
            
            // Fitness & Performance
            .vo2Max,
            
            // Audio/Environmental
            .environmentalAudioExposure, .headphoneAudioExposure
        ]
        
        // Category types - common tracking
        let categoryIdentifiers: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis, .appleStandHour, .mindfulSession, .toothbrushingEvent, .handwashingEvent,
            .lowHeartRateEvent, .highHeartRateEvent, .irregularHeartRhythmEvent,
            
            // Reproductive health (if applicable)
            .menstrualFlow, .sexualActivity, .cervicalMucusQuality, .ovulationTestResult,
            .intermenstrualBleeding,
            
            // Audio events
            .environmentalAudioExposureEvent
        ]
        
        // iOS 14.0+ types (all available since we require iOS 17.0+)
        let ios14AndLaterQuantity: [HKQuantityTypeIdentifier] = [
            .walkingSpeed, .walkingStepLength, .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage,
            .stairAscentSpeed, .stairDescentSpeed, .sixMinuteWalkTestDistance, .appleWalkingSteadiness,
            .appleMoveTime
        ]
        allTypes += ios14AndLaterQuantity.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
        
        let ios14AndLaterCategory: [HKCategoryTypeIdentifier] = [
            .headphoneAudioExposureEvent, .contraceptive, .pregnancy, .lactation,
            .pregnancyTestResult, .progesteroneTestResult, .appleWalkingSteadinessEvent
        ]
        allTypes += ios14AndLaterCategory.compactMap { HKCategoryType.categoryType(forIdentifier: $0) }
        
        // Convert main types to actual types
        allTypes += quantityIdentifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
        allTypes += categoryIdentifiers.compactMap { HKCategoryType.categoryType(forIdentifier: $0) }
        
        // Add workout types (very important)
        allTypes.append(HKWorkoutType.workoutType())
        
        // Add electrocardiogram (available since iOS 14.0, we require 17.0+)
        allTypes.append(HKElectrocardiogramType.electrocardiogramType())
        
        // Add clinical data (working separately)
        let clinicalIdentifiers: [HKClinicalTypeIdentifier] = [
            .allergyRecord, .conditionRecord, .immunizationRecord, .labResultRecord, .medicationRecord,
            .procedureRecord, .vitalSignRecord
        ]
        allTypes += clinicalIdentifiers.compactMap { HKClinicalType.clinicalType(forIdentifier: $0) }
        
        print("📱 Expanded request: asking for \(allTypes.count) health data types")
        print("📱 Includes: activity, heart, sleep, workouts, glucose, body measurements, reproductive health")
        return allTypes
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
