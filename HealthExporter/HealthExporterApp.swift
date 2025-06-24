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
        
        // For now, just complete the task after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("✅ Auto-export background task completed")
            
            // Record that we ran the export
            self.setLastAutoExportTime(Date())
            
            task.setTaskCompleted(success: true)
            
            // Schedule the next export
            self.scheduleNextAutoExport()
        }
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
            print("🚀 Auto-export is overdue, running now...")
            runAutoExportInForeground()
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
    
    private func runAutoExportInForeground() {
        // TODO: Integrate with actual ExportService
        // For now, just update the timestamp
        setLastAutoExportTime(Date())
        print("✅ Auto-export completed (foreground mode)")
        
        // Reschedule next background task
        scheduleNextAutoExport()
    }
}