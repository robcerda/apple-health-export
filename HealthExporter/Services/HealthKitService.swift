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
    
    func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit data not available on this device")
            authorizationStatus = .sharingDenied
            isAuthorized = false
            return
        }
        
        // Check authorization for multiple common types
        let commonTypes = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        var hasAnyAuthorization = false
        for type in commonTypes {
            let status = healthStore.authorizationStatus(for: type)
            print("📱 Status for \(type.identifier): \(status.rawValue)")
            if status == .sharingAuthorized {
                hasAnyAuthorization = true
                authorizationStatus = .sharingAuthorized
                break
            } else if status == .notDetermined {
                authorizationStatus = .notDetermined
            }
        }
        
        // If we didn't find any authorized types, check if we've made a request before
        if !hasAnyAuthorization {
            let hasRequestedBefore = UserDefaults.standard.bool(forKey: "HasRequestedHealthKitAuth")
            if hasRequestedBefore {
                // We've made a request before, so assume we have access due to HealthKit privacy
                print("📱 Assuming authorization granted - previous request made")
                isAuthorized = true
            } else {
                print("📱 No previous request made - authorization needed")
                isAuthorized = false
            }
        } else {
            isAuthorized = true
        }
        
        print("📱 HealthKit authorization status: \(authorizationStatus.rawValue)")
        print("📱 Is authorized: \(isAuthorized)")
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available - throwing error")
            throw HealthKitError.healthDataNotAvailable
        }
        
        let typesToRead = Set(SupportedHealthDataTypes.allTypes)
        print("📱 Requesting authorization for \(typesToRead.count) health data types")
        
        // Check current status before request
        print("📱 BEFORE authorization request:")
        for type in typesToRead.prefix(5) {
            let status = healthStore.authorizationStatus(for: type)
            print("📱   \(type.identifier): \(status.rawValue) (\(statusDescription(status)))")
        }
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        print("📱 Authorization request completed")
        
        // Check status immediately after request
        print("📱 AFTER authorization request:")
        var authorizedCount = 0
        var deniedCount = 0
        var notDeterminedCount = 0
        
        for type in typesToRead {
            let status = healthStore.authorizationStatus(for: type)
            switch status {
            case .sharingAuthorized:
                authorizedCount += 1
            case .sharingDenied:
                deniedCount += 1
            case .notDetermined:
                notDeterminedCount += 1
            @unknown default:
                break
            }
            
            if typesToRead.count <= 10 { // Only print details if small set
                print("📱   \(type.identifier): \(status.rawValue) (\(statusDescription(status)))")
            }
        }
        
        print("📱 Authorization Summary:")
        print("📱   Authorized: \(authorizedCount)")
        print("📱   Denied: \(deniedCount)")  
        print("📱   Not Determined: \(notDeterminedCount)")
        
        // Mark that we've made an authorization request
        UserDefaults.standard.set(true, forKey: "HasRequestedHealthKitAuth")
        
        await MainActor.run {
            checkAuthorizationStatus()
        }
        
        print("📱 Final authorization status: \(authorizationStatus.rawValue)")
        print("📱 Final isAuthorized: \(isAuthorized)")
        
        // Even if some permissions are denied, proceed if we have any authorized
        if authorizedCount == 0 && !isAuthorized {
            print("❌ No permissions granted at all")
            throw HealthKitError.authorizationDenied
        } else {
            print("✅ Proceeding with \(authorizedCount) authorized data types")
        }
    }
    
    private func statusDescription(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "not determined"
        case .sharingDenied: return "denied"
        case .sharingAuthorized: return "authorized"
        @unknown default: return "unknown"
        }
    }
    
    func fetchQuantityData(
        for type: HKQuantityType,
        from startDate: Date?,
        to endDate: Date?,
        limit: Int = 0,
        anchor: HKQueryAnchor? = nil
    ) async throws -> (samples: [HKQuantitySample], newAnchor: HKQueryAnchor?) {
        
        // Due to HealthKit privacy, status may show as denied even when access is granted
        // Only block if we've never made an authorization request AND status is notDetermined
        let hasRequestedBefore = UserDefaults.standard.bool(forKey: "HasRequestedHealthKitAuth")
        let status = healthStore.authorizationStatus(for: type)
        print("📱 Attempting to fetch \(type.identifier): status=\(status.rawValue), hasRequested=\(hasRequestedBefore)")
        
        if !hasRequestedBefore && status == .notDetermined {
            print("📱 Blocking fetch - no previous request and status is notDetermined")
            throw HealthKitError.authorizationDenied
        }
        
        print("📱 Proceeding with data fetch for \(type.identifier)")
        
        return try await withCheckedThrowingContinuation { continuation in
            var predicate: NSPredicate?
            if let startDate = startDate, let endDate = endDate {
                predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
                print("📱 Query date range: \(startDate) to \(endDate)")
            }
            
            if let anchor = anchor {
                let query = HKAnchoredObjectQuery(
                    type: type,
                    predicate: predicate,
                    anchor: anchor,
                    limit: limit
                ) { query, samples, deletedObjects, newAnchor, error in
                    if let error = error {
                        print("❌ Anchored query error for \(type.identifier): \(error)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let quantitySamples = samples?.compactMap { $0 as? HKQuantitySample } ?? []
                    print("📊 Fetched \(quantitySamples.count) samples for \(type.identifier) (anchored)")
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
                        print("❌ Sample query error for \(type.identifier): \(error)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let quantitySamples = samples?.compactMap { $0 as? HKQuantitySample } ?? []
                    print("📊 Fetched \(quantitySamples.count) samples for \(type.identifier)")
                    
                    // Log sample date range for debugging
                    if let first = quantitySamples.first, let last = quantitySamples.last {
                        print("📅 Sample range: \(first.startDate) to \(last.startDate)")
                    }
                    
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
        
        // Due to HealthKit privacy, status may show as denied even when access is granted
        // Only block if we've never made an authorization request AND status is notDetermined
        let hasRequestedBefore = UserDefaults.standard.bool(forKey: "HasRequestedHealthKitAuth")
        let status = healthStore.authorizationStatus(for: type)
        print("📱 Attempting to fetch \(type.identifier): status=\(status.rawValue), hasRequested=\(hasRequestedBefore)")
        
        if !hasRequestedBefore && status == .notDetermined {
            print("📱 Blocking fetch - no previous request and status is notDetermined")
            throw HealthKitError.authorizationDenied
        }
        
        print("📱 Proceeding with data fetch for \(type.identifier)")
        
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
        // Due to HealthKit privacy, status may show as denied even when access is granted
        // Only block if we've never made an authorization request AND status is notDetermined
        let hasRequestedBefore = UserDefaults.standard.bool(forKey: "HasRequestedHealthKitAuth")
        let status = healthStore.authorizationStatus(for: workoutType)
        print("📱 Attempting to fetch workouts: status=\(status.rawValue), hasRequested=\(hasRequestedBefore)")
        
        if !hasRequestedBefore && status == .notDetermined {
            print("📱 Blocking workout fetch - no previous request and status is notDetermined")
            throw HealthKitError.authorizationDenied
        }
        
        print("📱 Proceeding with workout data fetch")
        
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
        
        // Due to HealthKit privacy, status may show as denied even when access is granted
        // Only block if we've never made an authorization request AND status is notDetermined
        let hasRequestedBefore = UserDefaults.standard.bool(forKey: "HasRequestedHealthKitAuth")
        let status = healthStore.authorizationStatus(for: type)
        print("📱 Attempting to fetch \(type.identifier): status=\(status.rawValue), hasRequested=\(hasRequestedBefore)")
        
        if !hasRequestedBefore && status == .notDetermined {
            print("📱 Blocking fetch - no previous request and status is notDetermined")
            throw HealthKitError.authorizationDenied
        }
        
        print("📱 Proceeding with data fetch for \(type.identifier)")
        
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