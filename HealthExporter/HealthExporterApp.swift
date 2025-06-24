import SwiftUI
import BackgroundTasks

@main
struct HealthExporterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Setup background tasks for auto-export
                    setupAutoExportBackgroundTasks()
                    print("📱 App launched - auto-export background tasks registered")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Check for overdue exports when app becomes active
                    checkAndRunOverdueExports()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Also check when app becomes fully active
                    checkAndRunOverdueExports()
                }
        }
    }
    
    private func setupAutoExportBackgroundTasks() {
        let backgroundTaskIdentifier = "com.healthexporter.auto-export"
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: DispatchQueue.global(qos: .background)
        ) { task in
            handleAutoExportBackgroundTask(task: task as! BGProcessingTask)
        }
        
        // Schedule initial export if auto-export is enabled
        scheduleNextAutoExport()
    }
    
    private func handleAutoExportBackgroundTask(task: BGProcessingTask) {
        print("🚀 Starting background auto-export")
        
        task.expirationHandler = {
            print("⏰ Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // HealthKit background execution is severely limited by iOS
        // iOS restricts background HealthKit queries for privacy
        // This is why we primarily rely on foreground fallback
        print("⚠️ Background HealthKit access limited - marking for foreground fallback")
        
        // Just mark that we attempted and reschedule
        // Real export will happen via foreground fallback
        task.setTaskCompleted(success: true)
        scheduleNextAutoExport()
    }
    
    private func scheduleNextAutoExport() {
        guard let configuration = loadAutoExportConfiguration(),
              configuration.autoExportEnabled else {
            print("📅 Auto-export is disabled, not scheduling")
            return
        }
        
        let settings = configuration.autoExportSettings
        guard let nextRunDate = calculateNextRunDate(for: settings) else {
            print("❌ Could not calculate next run date")
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: "com.healthexporter.auto-export")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = nextRunDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled next auto-export for: \(nextRunDate)")
        } catch {
            print("❌ Failed to schedule auto-export: \(error)")
        }
    }
    
    private func calculateNextRunDate(for settings: AutoExportSettings) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        var targetComponents = todayComponents
        targetComponents.hour = settings.timeOfDay.hour
        targetComponents.minute = settings.timeOfDay.minute
        targetComponents.second = 0
        
        guard let todayTarget = calendar.date(from: targetComponents) else {
            return nil
        }
        
        switch settings.frequency {
        case .daily:
            if todayTarget > now {
                return todayTarget
            } else {
                return calendar.date(byAdding: .day, value: 1, to: todayTarget)
            }
            
        case .weekly:
            let nextSunday = calendar.nextDate(
                after: now,
                matching: DateComponents(hour: settings.timeOfDay.hour, minute: settings.timeOfDay.minute, weekday: 1),
                matchingPolicy: .nextTime
            )
            return nextSunday
            
        case .monthly:
            let nextMonth = calendar.nextDate(
                after: now,
                matching: DateComponents(day: 1, hour: settings.timeOfDay.hour, minute: settings.timeOfDay.minute),
                matchingPolicy: .nextTime
            )
            return nextMonth
        }
    }
    
    private func loadAutoExportConfiguration() -> ExportConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "ExportConfiguration"),
              let config = try? JSONDecoder().decode(ExportConfiguration.self, from: data) else {
            return nil
        }
        return config
    }
    
    private func checkAndRunOverdueExports() {
        guard let configuration = loadAutoExportConfiguration(),
              configuration.autoExportEnabled else {
            return
        }
        
        let settings = configuration.autoExportSettings
        
        // Check if we're past due for an export
        if shouldRunExportNow(settings: settings) {
            let scheduledTime = getLastScheduledExportTime(settings: settings, relativeTo: Date())
            print("🚀 Auto-export is overdue, running now...")
            print("⏰ Should have run at: \(scheduledTime)")
            runAutoExportInForeground(scheduledTime: scheduledTime)
        }
    }
    
    private func shouldRunExportNow(settings: AutoExportSettings) -> Bool {
        let now = Date()
        
        // Get the last time we should have run an export
        let lastScheduledTime = getLastScheduledExportTime(settings: settings, relativeTo: now)
        
        // Check if we have a record of the last actual export
        if let lastExportTime = getLastAutoExportTime() {
            // If our last export was before the last scheduled time, we're overdue
            return lastExportTime < lastScheduledTime
        } else {
            // No previous export record, so we should run if we're past the scheduled time
            return now > lastScheduledTime
        }
    }
    
    private func getLastScheduledExportTime(settings: AutoExportSettings, relativeTo date: Date) -> Date {
        let calendar = Calendar.current
        
        switch settings.frequency {
        case .daily:
            // Find today's scheduled time, or yesterday's if today hasn't happened yet
            let todayComponents = calendar.dateComponents([.year, .month, .day], from: date)
            var targetComponents = todayComponents
            targetComponents.hour = settings.timeOfDay.hour
            targetComponents.minute = settings.timeOfDay.minute
            targetComponents.second = 0
            
            if let todayTarget = calendar.date(from: targetComponents) {
                if todayTarget <= date {
                    return todayTarget // Today's scheduled time has passed
                } else {
                    // Today's time hasn't come yet, check yesterday
                    return calendar.date(byAdding: .day, value: -1, to: todayTarget) ?? todayTarget
                }
            }
            
        case .weekly:
            // Find the most recent Sunday at the scheduled time
            let weekday = calendar.component(.weekday, from: date)
            let daysSinceSunday = (weekday - 1) % 7
            
            let lastSundayComponents = calendar.dateComponents([.year, .month, .day], from: date)
            var sundayComponents = lastSundayComponents
            sundayComponents.hour = settings.timeOfDay.hour
            sundayComponents.minute = settings.timeOfDay.minute
            sundayComponents.second = 0
            
            if let baseDate = calendar.date(from: sundayComponents),
               let lastSunday = calendar.date(byAdding: .day, value: -daysSinceSunday, to: baseDate) {
                return lastSunday
            }
            
        case .monthly:
            // Find the most recent 1st of the month at scheduled time
            let currentComponents = calendar.dateComponents([.year, .month], from: date)
            var firstOfMonthComponents = currentComponents
            firstOfMonthComponents.day = 1
            firstOfMonthComponents.hour = settings.timeOfDay.hour
            firstOfMonthComponents.minute = settings.timeOfDay.minute
            firstOfMonthComponents.second = 0
            
            if let firstOfMonth = calendar.date(from: firstOfMonthComponents) {
                if firstOfMonth <= date {
                    return firstOfMonth // This month's scheduled time has passed
                } else {
                    // This month's time hasn't come yet, check last month
                    return calendar.date(byAdding: .month, value: -1, to: firstOfMonth) ?? firstOfMonth
                }
            }
        }
        
        // Fallback: return yesterday to trigger an export
        return calendar.date(byAdding: .day, value: -1, to: date) ?? date
    }
    
    private func getLastAutoExportTime() -> Date? {
        return UserDefaults.standard.object(forKey: "LastAutoExportTime") as? Date
    }
    
    private func setLastAutoExportTime(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "LastAutoExportTime")
    }
    
    private func runAutoExportInForeground(scheduledTime: Date) {
        guard let configuration = loadAutoExportConfiguration(),
              configuration.autoExportEnabled else {
            print("❌ Auto-export configuration not found or disabled")
            return
        }
        
        print("🚀 Starting real auto-export in foreground...")
        
        Task { @MainActor in
            do {
                // Create services for auto-export
                let fileService = FileService()
                let encryptionService = EncryptionService()
                let healthKitService = HealthKitService()
                
                // Ensure HealthKit is authorized
                guard healthKitService.isAuthorized else {
                    print("❌ HealthKit not authorized for auto-export")
                    return
                }
                
                // Create auto-export configuration
                let autoExportConfig = createAutoExportConfiguration(from: configuration, scheduledTime: scheduledTime)
                
                print("🚀 Auto-export starting with format: \(autoExportConfig.exportFormat.rawValue)")
                
                // Create export service and run export
                let exportService = ExportService(
                    healthKitService: healthKitService,
                    fileService: fileService,
                    encryptionService: encryptionService
                )
                
                // Wait for export to complete by monitoring the service state
                var isCompleted = false
                var attempts = 0
                let maxAttempts = 300 // 5 minutes max wait time
                
                exportService.startExport(
                    configuration: autoExportConfig,
                    password: configuration.autoExportSettings.encryptionEnabled ? nil : nil
                )
                
                // Poll for completion instead of using notifications
                while !isCompleted && attempts < maxAttempts {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    attempts += 1
                    
                    if exportService.exportProgress.stage == .completed {
                        print("✅ Auto-export completed successfully")
                        setLastAutoExportTime(Date())
                        
                        // Handle destination if configured
                        if let bookmark = configuration.autoExportSettings.destinationBookmark {
                            await moveLatestExportToDestination(bookmark: bookmark, fileService: fileService)
                        }
                        
                        isCompleted = true
                    } else if exportService.lastError != nil {
                        print("❌ Auto-export failed: \(exportService.lastError?.localizedDescription ?? "Unknown error")")
                        isCompleted = true
                    } else if exportService.exportProgress.stage == .failed {
                        print("❌ Auto-export failed with stage: failed")
                        isCompleted = true
                    }
                }
                
                if !isCompleted {
                    print("⏰ Auto-export timed out after 5 minutes")
                }
                
                // Always reschedule next export
                scheduleNextAutoExport()
                
            } catch {
                print("❌ Auto-export error: \(error)")
                scheduleNextAutoExport()
            }
        }
    }
    
    private func createAutoExportConfiguration(from config: ExportConfiguration, scheduledTime: Date) -> ExportConfiguration {
        var autoConfig = config
        
        // Override with auto-export specific settings
        autoConfig.exportFormat = config.autoExportSettings.format
        autoConfig.encryptionEnabled = config.autoExportSettings.encryptionEnabled
        
        // Set date range based on auto-export data range setting
        // IMPORTANT: Use scheduledTime as the end date, not current time
        switch config.autoExportSettings.dataRange {
        case .sinceLast:
            // Use incremental since last export
            autoConfig.dateRange = nil // This will trigger incremental export
            
        case .last24Hours:
            let endDate = scheduledTime // Use scheduled time, not current time
            let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
            autoConfig.dateRange = ExportConfiguration.DateRange(start: startDate, end: endDate)
            print("📅 Export range: \(startDate) to \(endDate) (24 hours ending at scheduled time)")
            
        case .lastWeek:
            let endDate = scheduledTime // Use scheduled time, not current time
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            autoConfig.dateRange = ExportConfiguration.DateRange(start: startDate, end: endDate)
            print("📅 Export range: \(startDate) to \(endDate) (7 days ending at scheduled time)")
            
        case .lastMonth:
            let endDate = scheduledTime // Use scheduled time, not current time
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            autoConfig.dateRange = ExportConfiguration.DateRange(start: startDate, end: endDate)
            print("📅 Export range: \(startDate) to \(endDate) (30 days ending at scheduled time)")
            
        case .allData:
            autoConfig.dateRange = nil
            print("📅 Export range: All data (no date restriction)")
        }
        
        return autoConfig
    }
    
    private func moveLatestExportToDestination(bookmark: Data, fileService: FileService) async {
        do {
            // Get the latest export file
            let exportFiles = fileService.listExportFiles()
            guard let latestExport = exportFiles.first else {
                print("❌ No export file found to move to destination")
                return
            }
            
            // Read the export data
            let exportData = try Data(contentsOf: latestExport)
            
            // Write to auto-export destination
            let destinationURL = try await fileService.writeFileToAutoExportDestination(
                data: exportData,
                filename: latestExport.lastPathComponent,
                bookmark: bookmark
            )
            
            print("📁 Auto-export saved to destination: \(destinationURL.path)")
        } catch {
            print("❌ Failed to move export to destination: \(error)")
        }
    }
}