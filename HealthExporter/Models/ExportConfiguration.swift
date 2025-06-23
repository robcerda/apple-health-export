import Foundation
import HealthKit

struct ExportConfiguration: Codable {
    var exportFormat: ExportFormat
    var dateRange: DateRange?
    var enabledDataTypes: Set<String>
    var encryptionEnabled: Bool
    var autoExportEnabled: Bool
    var autoExportFrequency: AutoExportFrequency
    var batchSize: Int
    
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
        
        // iOS 14.0+ types
        if #available(iOS 14.0, *) {
            let ios14Quantity: [HKQuantityTypeIdentifier] = [
                .walkingSpeed, .walkingStepLength, .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage,
                .stairAscentSpeed, .stairDescentSpeed, .sixMinuteWalkTestDistance
            ]
            allTypes += ios14Quantity.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
            
            let ios14Category: [HKCategoryTypeIdentifier] = [.headphoneAudioExposureEvent]
            allTypes += ios14Category.compactMap { HKCategoryType.categoryType(forIdentifier: $0) }
        }
        
        // iOS 14.3+ reproductive health
        if #available(iOS 14.3, *) {
            let ios143Category: [HKCategoryTypeIdentifier] = [.contraceptive, .pregnancy, .lactation]
            allTypes += ios143Category.compactMap { HKCategoryType.categoryType(forIdentifier: $0) }
        }
        
        // iOS 14.5+ Apple Move Time
        if #available(iOS 14.5, *) {
            if let appleMoveTime = HKQuantityType.quantityType(forIdentifier: .appleMoveTime) {
                allTypes.append(appleMoveTime)
            }
        }
        
        // iOS 15.0+ walking steadiness
        if #available(iOS 15.0, *) {
            let ios15Quantity: [HKQuantityTypeIdentifier] = [.appleWalkingSteadiness]
            allTypes += ios15Quantity.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
            
            let ios15Category: [HKCategoryTypeIdentifier] = [.pregnancyTestResult, .progesteroneTestResult, .appleWalkingSteadinessEvent]
            allTypes += ios15Category.compactMap { HKCategoryType.categoryType(forIdentifier: $0) }
        }
        
        // Convert main types to actual types
        allTypes += quantityIdentifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
        allTypes += categoryIdentifiers.compactMap { HKCategoryType.categoryType(forIdentifier: $0) }
        
        // Add workout types (very important)
        allTypes.append(HKWorkoutType.workoutType())
        
        // Add electrocardiogram if available
        if #available(iOS 14.0, *) {
            allTypes.append(HKElectrocardiogramType.electrocardiogramType())
        }
        
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
