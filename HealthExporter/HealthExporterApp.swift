import SwiftUI
import BackgroundTasks
import Foundation

@main
struct HealthExporterApp: App {
    
    init() {
        // Initialize AutoExportService early to register background tasks
        // This must happen before the app finishes launching
        print("📅 Initializing auto-export service during app launch...")
        AutoExportService.initialize()
        print("📅 Auto-export service initialized and background tasks registered")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Schedule auto-export if enabled
                    Task { @MainActor in
                        AutoExportService.shared.scheduleNextAutoExport()
                    }
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
    
    private func checkAndRunOverdueExports() {
        Task { @MainActor in
            // Use the improved AutoExportService for foreground fallback
            let autoExportService = AutoExportService.shared
            
            // Check if auto-export is enabled
            guard let data = UserDefaults.standard.data(forKey: "ExportConfiguration"),
                  let config = try? JSONDecoder().decode(ExportConfiguration.self, from: data),
                  config.autoExportEnabled else {
                return
            }
            
            // Check if we need to run an overdue export
            let settings = config.autoExportSettings
            let now = Date()
            
            // Calculate the last time an export should have run
            let lastScheduledTime = getLastScheduledExportTime(settings: settings, relativeTo: now)
            
            // Check when we last actually exported
            let lastExportTime = autoExportService.lastAutoExportDate
            
            let shouldRun: Bool
            if let lastExport = lastExportTime {
                // If our last export was before the last scheduled time, we're overdue
                shouldRun = lastExport < lastScheduledTime
            } else {
                // No previous export record, so we should run if we're past the scheduled time
                shouldRun = now > lastScheduledTime
            }
            
            if shouldRun {
                print("🚀 Auto-export is overdue, triggering foreground fallback...")
                print("⏰ Should have run at: \(lastScheduledTime)")
                print("📅 Last export: \(lastExportTime?.description ?? "Never")")
                
                // Trigger the auto-export using the service
                autoExportService.triggerAutoExportNow()
            }
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
}