import SwiftUI

struct BackgroundTaskInfoView: View {
    @State private var showingInfo = false
    
    var body: some View {
        Button(action: { showingInfo = true }) {
            HStack {
                Image(systemName: "info.circle")
                Text("Background Export Info")
                    .font(.caption)
            }
            .foregroundColor(.blue)
        }
        .sheet(isPresented: $showingInfo) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        realitySection
                        optimizationSection
                        troubleshootingSection
                    }
                    .padding()
                }
                .navigationTitle("Background Export Info")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showingInfo = false }
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📱 iOS Background Task Reality")
                .font(.headline)
            
            Text("iOS severely limits background app execution to preserve battery life. Even properly configured background tasks may not run when expected.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var realitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚠️ What to Expect")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Background exports may only run when iOS decides", systemImage: "clock.badge.exclamationmark")
                Label("Frequency depends on your app usage patterns", systemImage: "chart.line.uptrend.xyaxis")
                Label("iOS learns from when you typically use the app", systemImage: "brain.head.profile")
                Label("System load and battery level affect execution", systemImage: "battery.25")
            }
            .font(.caption)
        }
    }
    
    private var optimizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🚀 Improve Background Execution")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Use the app regularly at consistent times", systemImage: "clock.arrow.circlepath")
                Label("Keep Background App Refresh enabled for this app", systemImage: "arrow.clockwise")
                Label("Avoid force-quitting the app (swipe up to close)", systemImage: "hand.raised.slash")
                Label("Charge your device regularly", systemImage: "battery.100.bolt")
                Label("Use Low Power Mode sparingly", systemImage: "battery.0")
            }
            .font(.caption)
        }
    }
    
    private var troubleshootingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔧 Troubleshooting")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("If background exports aren't working:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Label("Check Settings > General > Background App Refresh", systemImage: "gearshape")
                Label("Ensure this app is enabled in Background App Refresh", systemImage: "checkmark.circle")
                Label("Try using the app at the same time daily", systemImage: "calendar")
                Label("Manually open the app periodically to trigger foreground fallback", systemImage: "hand.tap")
            }
            .font(.caption)
            
            Text("💡 Reliability Tip")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.top)
            
            Text("The most reliable approach is to open the app periodically (daily/weekly) to ensure exports happen via our foreground fallback system.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading)
        }
    }
}

#Preview {
    BackgroundTaskInfoView()
}