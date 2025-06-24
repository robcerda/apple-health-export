HealthKit Data Exporter Development Guide

## Current Status: ✅ WORKING APP WITH AUTO-EXPORT
This is a **fully functional**, privacy-focused iOS app that successfully exports comprehensive Apple Health data. The app has been tested and verified to work with real health data (83.8 MB exports confirmed). **Now includes reliable auto-export functionality with user-selected destinations.**

## Project Context
You are building a privacy-focused, open-source iOS app that exports Apple Health data for personal analysis. The app makes zero network requests and gives users complete control over their health data.
Core Principles

Privacy First: No data leaves the device without explicit user action
No Dependencies: Use only Apple frameworks - no third-party SDKs
Security: Optional encryption, no analytics, no tracking
Performance: Handle years of minute-by-minute data without crashing
Transparency: Open source, auditable, clear about what it does

Technical Constraints

Minimum iOS Version: 17.0 (for latest HealthKit features and modern UI capabilities)
Swift Version: 5.9+
No External Dependencies: Only use Foundation, HealthKit, CryptoKit, SwiftUI
Memory Management: Stream data to disk, batch operations, never load all data in memory

Code Style Guidelines

Use Swift Concurrency (async/await) throughout
Prefer value types (structs) over reference types where possible
Clear, self-documenting variable names
Group related functionality into extensions
Handle all HealthKit permission states explicitly

## Modern UI Patterns (iOS 17.0+)

**Navigation Structure:**
- Use NavigationStack (not NavigationView) for full-screen layout
- Avoid sidebar layouts that leave main content area blank
- Clean, focused header without redundant navigation titles

**SwiftUI Best Practices:**
- Use modern onChange syntax: `.onChange(of: value) { ... }`
- Implement symbol effects with gradient and animation
- LazyVStack with ScrollView for performance with large content
- Responsive layouts with HStack for side-by-side sections

**User Experience:**
- Remember authorization state - don't ask for permissions repeatedly
- Show user-friendly status messages, not debug values
- Prominent export button as primary action
- Progressive disclosure - show advanced options after authorization

HealthKit Best Practices

**Authorization Reality:**
```swift
// IMPORTANT: HealthKit authorization status is privacy-protective
// Status may show "denied" even when access is granted
// Always check if request was made previously:
let hasRequestedBefore = UserDefaults.standard.bool(forKey: "HasRequestedHealthKitAuth")

// Don't rely solely on authorizationStatus() - it's intentionally misleading for privacy
// Real test: Try to fetch data - if you get results, you have access
```

**Focused Permission Requests:**
```swift
// Request ~50-60 core data types, not 100+ types
// iOS permissions dialog works better with focused requests
// Include: steps, heart rate, sleep, workouts, glucose, body measurements
```

**Query Patterns:**
```swift
// Batch large queries
let batchSize = 10_000

// Use anchored queries for incremental updates
// Store anchors securely in UserDefaults

// Handle all HealthKit errors explicitly
// HealthKit can return partial results with errors
```
Data Handling Rules

Never assume data exists - users may have no data for certain types
Handle duplicates - HealthKit can return duplicate samples
Respect source priority - Apple Watch > iPhone > third-party apps
Date handling - always use ISO8601 format in exports
Units - store both value and unit string for clarity

Security Implementation
swift// Encryption: AES-256-GCM using CryptoKit
// Key derivation: PBKDF2 with min 100,000 iterations
// Never store passwords, only derive keys as needed
// Include salt and nonce with encrypted data
File System Guidelines

Use app's Documents directory for exports
Set appropriate file protection attributes
Clean up incomplete exports on app launch
Respect available disk space

Error Messages
Write user-friendly error messages:

❌ "HKErrorDomain error 5"
✅ "Health access denied. Please enable in Settings > Privacy > Health"

Testing Approach

Create mock HealthKit data generators for testing
Test with empty data, single sample, and millions of samples
Verify memory usage stays under 100MB during export
Test interruption scenarios (app backgrounded, device locked)

Progress Reporting

Report progress by data type, not individual samples
Update UI maximum once per second
Show current operation ("Exporting heart rate data...")
Accurate time estimates based on processed vs remaining

## Auto-Export System Implementation

**Architecture Overview:**
The app implements a hybrid auto-export system that ensures reliable scheduled exports regardless of iOS background task limitations.

**Key Components:**
- Background task registration with `BGTaskScheduler`
- Foreground fallback system for missed exports
- User-configurable destinations with security-scoped bookmarks
- Silent operation without notifications

**Background Task Setup:**
```swift
// Info.plist configuration:
<key>UIBackgroundModes</key>
<array>
    <string>background-app-refresh</string>
    <string>background-processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.healthexporter.auto-export</string>
</array>

// Register background task in app initialization
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.healthexporter.auto-export",
    using: DispatchQueue.global(qos: .background)
) { task in
    handleAutoExportBackgroundTask(task: task as! BGProcessingTask)
}
```

**Hybrid Execution Strategy:**
1. **Primary Path**: Background task attempts to run at scheduled time
2. **Fallback Path**: Foreground check when app becomes active
3. **Overdue Detection**: Smart logic to determine if exports were missed
4. **Silent Recovery**: Catches up on missed exports automatically

**Destination Management:**
```swift
// User selects destination folder via document picker
// Create security-scoped bookmark for persistent access
let bookmark = try url.bookmarkData(options: [.suitableForBookmarkFile])

// Write exports to user's chosen destination
func writeFileToAutoExportDestination(data: Data, filename: String, bookmark: Data) async throws -> URL {
    // Resolve bookmark and access security-scoped resource
    // Write file to chosen destination (iCloud, Google Drive, etc.)
}
```

**Configuration Structure:**
```swift
struct AutoExportSettings: Codable {
    var frequency: AutoExportFrequency      // Daily, Weekly, Monthly
    var timeOfDay: TimeOfDay               // Hour and minute
    var dataRange: AutoExportDataRange     // What data to export
    var format: ExportFormat               // JSON or SQLite
    var encryptionEnabled: Bool            // Independent encryption
    var destinationBookmark: Data?         // Security-scoped bookmark
    var destinationDisplayName: String?    // User-friendly name
}
```

**Reliability Features:**
- Works without maintaining Xcode connection
- Multiple execution opportunities (background + foreground)
- Overdue detection based on schedule vs. last export time
- Automatic rescheduling after each export
- No user notifications - completely silent operation

**Testing & Verification:**
- Check Settings for "Last auto-export: X ago" status
- Verify exports appear in "Previous Exports" section
- Confirm files are saved to chosen destination
- Monitor console logs for scheduling confirmation

Background Task Guidelines
```swift
// Register tasks in Info.plist with BGTaskSchedulerPermittedIdentifiers
// Request background processing time (iOS may grant 1-30 seconds)
// Save state before task expires and continue in next launch
// Implement foreground fallback for reliability
```
Export Format Standards
JSON Structure

Flat structure where possible
Consistent date format (ISO8601)
Include units with all measurements
Minimize nesting for easier parsing

SQLite Schema
sql-- Optimize for common queries
CREATE INDEX idx_samples_date ON samples(start_date);
CREATE INDEX idx_samples_type ON samples(type);

-- Denormalize cautiously for performance
-- Include summary statistics table
Common Pitfalls to Avoid

Loading all data at once - causes memory crashes
Ignoring authorization changes - user can revoke access anytime
Blocking main thread - all HealthKit queries should be async
Not handling duplicates - HealthKit often returns duplicate samples
Assuming data exists - check for nil/empty results
Forgetting iPad support - HealthKit limited but available on iPad

**Auto-Export Specific Pitfalls:**
- Relying solely on iOS background tasks - use hybrid approach
- Not handling security-scoped bookmark staleness
- Forgetting to reschedule after each export
- Assuming background tasks run at exact scheduled times
- Not providing fallback when background execution fails
- Using notifications for auto-export status (annoying to users)

Performance Targets

Initial authorization: < 1 second
Export 1 year of data: < 30 seconds
Export 5 years of data: < 5 minutes
Memory usage: < 100MB peak
App size: < 10MB

Debugging Tips

Use Console.app to watch for HealthKit errors
Enable HealthKit debug logging in scheme
Test on real device - simulator has limited HealthKit data
Use Instruments to profile memory and performance

Code Review Checklist

 No hardcoded strings - use constants or localization
 All errors handled and logged
 No force unwrapping of optionals
 Memory leaks checked with Instruments
 File operations have proper error handling
 Encryption keys properly derived and not stored
 Progress accurately reported to user
 Export can be cancelled cleanly

**Auto-Export Specific Checklist:**
 Background task identifier matches Info.plist
 Security-scoped bookmarks properly created and resolved
 Overdue detection logic handles edge cases (day changes, etc.)
 Auto-exports appear in export history alongside manual exports
 Settings UI shows meaningful status (last export time)
 No compilation warnings about unused DateComponents parameters
 Foreground fallback triggers when app becomes active
 Auto-scheduling happens automatically on configuration changes

When You're Stuck

Check Apple's HealthKit documentation for latest API changes
Verify permissions in Settings > Privacy > Health
Look at device logs in Console.app
Test with smaller date ranges first
Ensure device has sufficient free space

Remember
This app handles extremely sensitive personal health data. Every decision should prioritize user privacy and data security. When in doubt, choose the more private/secure option.