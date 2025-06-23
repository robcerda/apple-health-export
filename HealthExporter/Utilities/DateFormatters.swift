import Foundation

struct DateFormatters {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    static let userFriendly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let filename: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    static let exportDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter
    }()
    
    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

extension Date {
    var iso8601String: String {
        return DateFormatters.iso8601.string(from: self)
    }
    
    var userFriendlyString: String {
        return DateFormatters.userFriendly.string(from: self)
    }
    
    var filenameString: String {
        return DateFormatters.filename.string(from: self)
    }
    
    var exportDisplayString: String {
        return DateFormatters.exportDisplay.string(from: self)
    }
    
    var relativeString: String {
        return DateFormatters.relativeDateFormatter.localizedString(for: self, relativeTo: Date())
    }
}