import Foundation
import BackgroundTasks
import UserNotifications

@MainActor
class AutoExportService: ObservableObject {
    static let shared = AutoExportService()
    
    private let backgroundTaskIdentifier = "com.healthexporter.auto-export"
    
    @Published var isAutoExportInProgress = false
    @Published var lastAutoExportDate: Date?
    @Published var lastAutoExportError: Error?
    
    private init() {
        registerBackgroundTasks()
        requestNotificationPermissions()
    }
    
    // MARK: - Background Task Registration
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: DispatchQueue.global(qos: .background)
        ) { [weak self] task in
            self?.handleAutoExport(task: task as! BGProcessingTask)
        }
    }
    
    // MARK: - Scheduling
    
    func scheduleNextAutoExport() {
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
    
    private func calculateNextRunDate(for settings: AutoExportSettings) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        // Get today's target time
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        var targetComponents = todayComponents
        targetComponents.hour = settings.timeOfDay.hour
        targetComponents.minute = settings.timeOfDay.minute
        targetComponents.second = 0
        
        guard let todayTarget = calendar.date(from: targetComponents) else {
            return nil
        }
        
        // If today's time has passed, calculate next occurrence
        let baseDate = todayTarget > now ? todayTarget : todayTarget
        
        switch settings.frequency {
        case .daily:
            if baseDate > now {
                return baseDate
            } else {
                return calendar.date(byAdding: .day, value: 1, to: baseDate)
            }
            
        case .weekly:
            // Schedule for next Sunday at the specified time
            let nextSunday = calendar.nextDate(
                after: now,
                matching: DateComponents(weekday: 1, hour: settings.timeOfDay.hour, minute: settings.timeOfDay.minute),
                matchingPolicy: .nextTime
            )
            return nextSunday
            
        case .monthly:
            // Schedule for first day of next month
            let nextMonth = calendar.nextDate(
                after: now,
                matching: DateComponents(day: 1, hour: settings.timeOfDay.hour, minute: settings.timeOfDay.minute),
                matchingPolicy: .nextTime
            )
            return nextMonth
        }
    }
    
    // MARK: - Export Execution
    
    private func handleAutoExport(task: BGProcessingTask) {
        print("🚀 Starting background auto-export")
        
        task.expirationHandler = {
            print("⏰ Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // For now, just complete the task
        // TODO: Implement actual export logic
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("✅ Auto-export background task completed (placeholder)")
            task.setTaskCompleted(success: true)
        }
        
        // Schedule the next export
        Task { @MainActor in
            scheduleNextAutoExport()
        }
    }
    
    // MARK: - Manual Trigger (for testing)
    
    func triggerAutoExportNow() {
        print("🚀 Manual auto-export triggered (placeholder)")
        isAutoExportInProgress = true
        
        // Simulate export process
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.isAutoExportInProgress = false
            self.lastAutoExportDate = Date()
            print("✅ Manual auto-export completed (placeholder)")
        }
    }
    
    // MARK: - Utilities
    
    private func loadConfiguration() -> ExportConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "ExportConfiguration"),
              let config = try? JSONDecoder().decode(ExportConfiguration.self, from: data) else {
            return nil
        }
        return config
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("📱 Notification permissions granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }
}

// MARK: - Errors

enum AutoExportError: LocalizedError {
    case exportFailed
    case noExportFound
    case destinationNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "Failed to export health data"
        case .noExportFound:
            return "No export file found to move to destination"
        case .destinationNotAvailable:
            return "Auto-export destination is not available"
        }
    }
}