import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var isAuthorized = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .sharingDenied
            return
        }
        
        let sampleType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        authorizationStatus = healthStore.authorizationStatus(for: sampleType)
        isAuthorized = authorizationStatus == .sharingAuthorized
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataNotAvailable
        }
        
        let typesToRead = Set(SupportedHealthDataTypes.allTypes)
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        
        await MainActor.run {
            checkAuthorizationStatus()
        }
        
        if authorizationStatus != .sharingAuthorized {
            throw HealthKitError.authorizationDenied
        }
    }
    
    func fetchQuantityData(
        for type: HKQuantityType,
        from startDate: Date?,
        to endDate: Date?,
        limit: Int = 0,
        anchor: HKQueryAnchor? = nil
    ) async throws -> (samples: [HKQuantitySample], newAnchor: HKQueryAnchor?) {
        
        guard healthStore.authorizationStatus(for: type) == .sharingAuthorized else {
            throw HealthKitError.authorizationDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var predicate: NSPredicate?
            if let startDate = startDate, let endDate = endDate {
                predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
            }
            
            if let anchor = anchor {
                let query = HKAnchoredObjectQuery(
                    type: type,
                    predicate: predicate,
                    anchor: anchor,
                    limit: limit
                ) { query, samples, deletedObjects, newAnchor, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let quantitySamples = samples?.compactMap { $0 as? HKQuantitySample } ?? []
                    continuation.resume(returning: (samples: quantitySamples, newAnchor: newAnchor))
                }
                
                healthStore.execute(query)
            } else {
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: limit,
                    sortDescriptors: [sortDescriptor]
                ) { query, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let quantitySamples = samples?.compactMap { $0 as? HKQuantitySample } ?? []
                    continuation.resume(returning: (samples: quantitySamples, newAnchor: nil))
                }
                
                healthStore.execute(query)
            }
        }
    }
    
    func fetchCategoryData(
        for type: HKCategoryType,
        from startDate: Date?,
        to endDate: Date?,
        limit: Int = 0,
        anchor: HKQueryAnchor? = nil
    ) async throws -> (samples: [HKCategorySample], newAnchor: HKQueryAnchor?) {
        
        guard healthStore.authorizationStatus(for: type) == .sharingAuthorized else {
            throw HealthKitError.authorizationDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var predicate: NSPredicate?
            if let startDate = startDate, let endDate = endDate {
                predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
            }
            
            if let anchor = anchor {
                let query = HKAnchoredObjectQuery(
                    type: type,
                    predicate: predicate,
                    anchor: anchor,
                    limit: limit
                ) { query, samples, deletedObjects, newAnchor, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let categorySamples = samples?.compactMap { $0 as? HKCategorySample } ?? []
                    continuation.resume(returning: (samples: categorySamples, newAnchor: newAnchor))
                }
                
                healthStore.execute(query)
            } else {
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: limit,
                    sortDescriptors: [sortDescriptor]
                ) { query, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let categorySamples = samples?.compactMap { $0 as? HKCategorySample } ?? []
                    continuation.resume(returning: (samples: categorySamples, newAnchor: nil))
                }
                
                healthStore.execute(query)
            }
        }
    }
    
    func fetchWorkoutData(
        from startDate: Date?,
        to endDate: Date?,
        limit: Int = 0,
        anchor: HKQueryAnchor? = nil
    ) async throws -> (workouts: [HKWorkout], newAnchor: HKQueryAnchor?) {
        
        let workoutType = HKWorkoutType.workoutType()
        guard healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized else {
            throw HealthKitError.authorizationDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var predicate: NSPredicate?
            if let startDate = startDate, let endDate = endDate {
                predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
            }
            
            if let anchor = anchor {
                let query = HKAnchoredObjectQuery(
                    type: workoutType,
                    predicate: predicate,
                    anchor: anchor,
                    limit: limit
                ) { query, samples, deletedObjects, newAnchor, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let workouts = samples?.compactMap { $0 as? HKWorkout } ?? []
                    continuation.resume(returning: (workouts: workouts, newAnchor: newAnchor))
                }
                
                healthStore.execute(query)
            } else {
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                let query = HKSampleQuery(
                    sampleType: workoutType,
                    predicate: predicate,
                    limit: limit,
                    sortDescriptors: [sortDescriptor]
                ) { query, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let workouts = samples?.compactMap { $0 as? HKWorkout } ?? []
                    continuation.resume(returning: (workouts: workouts, newAnchor: nil))
                }
                
                healthStore.execute(query)
            }
        }
    }
    
    func fetchWorkoutHeartRateData(for workout: HKWorkout) async throws -> [HKQuantitySample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }
        
        guard healthStore.authorizationStatus(for: heartRateType) == .sharingAuthorized else {
            return []
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: []
            )
            
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { query, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let heartRateSamples = samples?.compactMap { $0 as? HKQuantitySample } ?? []
                continuation.resume(returning: heartRateSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchClinicalData(
        for type: HKClinicalType,
        limit: Int = 0
    ) async throws -> [HKClinicalRecord] {
        
        guard healthStore.authorizationStatus(for: type) == .sharingAuthorized else {
            throw HealthKitError.authorizationDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { query, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let clinicalRecords = samples?.compactMap { $0 as? HKClinicalRecord } ?? []
                continuation.resume(returning: clinicalRecords)
            }
            
            healthStore.execute(query)
        }
    }
    
    func getEarliestSampleDate() async throws -> Date? {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { query, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples?.first?.startDate)
            }
            
            healthStore.execute(query)
        }
    }
    
    func getLatestSampleDate() async throws -> Date? {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { query, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples?.first?.startDate)
            }
            
            healthStore.execute(query)
        }
    }
}

enum HealthKitError: LocalizedError {
    case healthDataNotAvailable
    case authorizationDenied
    case exportCancelled
    case fileWriteError(Error)
    case encryptionError(Error)
    
    var errorDescription: String? {
        switch self {
        case .healthDataNotAvailable:
            return "Health data is not available on this device."
        case .authorizationDenied:
            return "Health access denied. Please enable in Settings > Privacy & Security > Health."
        case .exportCancelled:
            return "Export was cancelled."
        case .fileWriteError(let error):
            return "Failed to write export file: \(error.localizedDescription)"
        case .encryptionError(let error):
            return "Encryption failed: \(error.localizedDescription)"
        }
    }
}