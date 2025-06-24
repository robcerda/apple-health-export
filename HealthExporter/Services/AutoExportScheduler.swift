import Foundation
import BackgroundTasks

// Simple functional approach to auto-export scheduling
class AutoExportScheduler {
    static let backgroundTaskIdentifier = "com.healthexporter.auto-export"
    
    public static func setupBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: DispatchQueue.global(qos: .background)
        ) { task in
            handleBackgroundExport(task: task as! BGProcessingTask)
        }
        
        print("📅 Background task registration completed")
    }
    
    public static func scheduleNextExport() {
        guard let configuration = loadConfiguration(),
              configuration.autoExportEnabled else {
            print("📅 Auto-export is disabled, not scheduling")
            return
        }
        
        let settings = configuration.autoExportSettings
        guard let nextRunDate = calculateNextRunDate(for: settings) else {
            print("❌ Could not calculate next run date")
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
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
    
    private static func handleBackgroundExport(task: BGProcessingTask) {
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
        scheduleNextExport()
    }
    
    private static func calculateNextRunDate(for settings: AutoExportSettings) -> Date? {
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
                matching: DateComponents(weekday: 1, hour: settings.timeOfDay.hour, minute: settings.timeOfDay.minute),
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
    
    private static func loadConfiguration() -> ExportConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "ExportConfiguration"),
              let config = try? JSONDecoder().decode(ExportConfiguration.self, from: data) else {
            return nil
        }
        return config
    }
}