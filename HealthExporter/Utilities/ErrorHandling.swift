import Foundation
import HealthKit

struct ErrorHandler {
    static func userFriendlyMessage(for error: Error) -> String {
        switch error {
        case let healthKitError as HealthKitError:
            return healthKitError.localizedDescription
            
        case let encryptionError as EncryptionError:
            return encryptionError.localizedDescription
            
        case let fileError as FileServiceError:
            return fileError.localizedDescription
            
        case let hkError as HKError:
            return handleHealthKitError(hkError)
            
        case let nsError as NSError:
            return handleNSError(nsError)
            
        default:
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    private static func handleHealthKitError(_ error: HKError) -> String {
        switch error.code {
        case .errorHealthDataUnavailable:
            return "Health data is not available on this device."
        case .errorHealthDataRestricted:
            return "Health data access is restricted on this device."
        case .errorInvalidArgument:
            return "Invalid request to HealthKit."
        case .errorAuthorizationDenied:
            return "Health access denied. Please enable in Settings > Privacy & Security > Health."
        case .errorAuthorizationNotDetermined:
            return "Health access not yet requested. Please grant permission."
        case .errorDatabaseInaccessible:
            return "HealthKit database is temporarily unavailable."
        case .errorUserCanceled:
            return "Operation cancelled by user."
        case .errorAnotherWorkoutSessionStarted:
            return "Another workout session is already active."
        case .errorUserExitedWorkoutSession:
            return "User exited the workout session."
        case .errorRequiredAuthorizationDenied:
            return "Required health permissions were denied."
        case .errorNoWorkoutSession:
            return "No active workout session found."
        default:
            return "HealthKit error: \(error.localizedDescription)"
        }
    }
    
    private static func handleNSError(_ error: NSError) -> String {
        switch error.domain {
        case NSCocoaErrorDomain:
            switch error.code {
            case NSFileReadNoSuchFileError:
                return "File not found."
            case NSFileReadNoPermissionError:
                return "Permission denied when reading file."
            case NSFileWriteNoPermissionError:
                return "Permission denied when writing file."
            case NSFileWriteFileExistsError:
                return "File already exists."
            case NSFileWriteVolumeReadOnlyError:
                return "Cannot write to read-only volume."
            case NSFileWriteOutOfSpaceError:
                return "Not enough storage space available."
            default:
                return "File system error: \(error.localizedDescription)"
            }
        default:
            return error.localizedDescription
        }
    }
    
    static func logError(_ error: Error, context: String = "") {
        let errorMessage = userFriendlyMessage(for: error)
        print("🔴 ERROR [\(context)]: \(errorMessage)")
        
        #if DEBUG
        print("🔍 DEBUG INFO: \(error)")
        #endif
    }
    
    static func shouldRetry(_ error: Error) -> Bool {
        switch error {
        case let hkError as HKError:
            switch hkError.code {
            case .errorDatabaseInaccessible:
                return true
            case .errorAuthorizationDenied, .errorHealthDataRestricted, .errorHealthDataUnavailable:
                return false
            default:
                return false
            }
        case let nsError as NSError:
            switch nsError.domain {
            case NSURLErrorDomain:
                return nsError.code == NSURLErrorTimedOut || nsError.code == NSURLErrorNetworkConnectionLost
            case NSCocoaErrorDomain:
                return nsError.code == NSFileReadNoSuchFileError
            default:
                return false
            }
        default:
            return false
        }
    }
}

extension Error {
    var userFriendlyMessage: String {
        return ErrorHandler.userFriendlyMessage(for: self)
    }
    
    var shouldRetry: Bool {
        return ErrorHandler.shouldRetry(self)
    }
    
    func log(context: String = "") {
        ErrorHandler.logError(self, context: context)
    }
}