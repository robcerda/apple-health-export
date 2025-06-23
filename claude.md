HealthKit Data Exporter Development Guide
Project Context
You are building a privacy-focused, open-source iOS app that exports Apple Health data for personal analysis. The app makes zero network requests and gives users complete control over their health data.
Core Principles

Privacy First: No data leaves the device without explicit user action
No Dependencies: Use only Apple frameworks - no third-party SDKs
Security: Optional encryption, no analytics, no tracking
Performance: Handle years of minute-by-minute data without crashing
Transparency: Open source, auditable, clear about what it does

Technical Constraints

Minimum iOS Version: 16.0 (for latest Swift Concurrency features)
Swift Version: 5.9+
No External Dependencies: Only use Foundation, HealthKit, CryptoKit, SwiftUI
Memory Management: Stream data to disk, batch operations, never load all data in memory

Code Style Guidelines

Use Swift Concurrency (async/await) throughout
Prefer value types (structs) over reference types where possible
Clear, self-documenting variable names
Group related functionality into extensions
Handle all HealthKit permission states explicitly

HealthKit Best Practices
swift// Always check authorization before queries
guard healthStore.authorizationStatus(for: type) == .sharingAuthorized else { return }

// Batch large queries
let batchSize = 10_000

// Use anchored queries for incremental updates
// Store anchors securely in UserDefaults

// Handle all HealthKit errors explicitly
// HealthKit can return partial results with errors
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

Background Task Guidelines
swift// Register tasks in Info.plist
// Request generous time (up to 30 seconds)
// Save state before task expires
// Can resume in next launch
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

When You're Stuck

Check Apple's HealthKit documentation for latest API changes
Verify permissions in Settings > Privacy > Health
Look at device logs in Console.app
Test with smaller date ranges first
Ensure device has sufficient free space

Remember
This app handles extremely sensitive personal health data. Every decision should prioritize user privacy and data security. When in doubt, choose the more private/secure option.