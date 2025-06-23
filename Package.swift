// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HealthExporter",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "HealthExporter",
            targets: ["HealthExporter"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HealthExporter",
            dependencies: [],
            path: "HealthExporter",
            sources: [
                "App/HealthExporterApp.swift",
                "Models/HealthData.swift",
                "Models/ExportConfiguration.swift", 
                "Models/SyncState.swift",
                "Services/HealthKitService.swift",
                "Services/ExportService.swift",
                "Services/EncryptionService.swift",
                "Services/FileService.swift",
                "Views/ContentView.swift",
                "Views/ProgressView.swift",
                "Views/SettingsView.swift",
                "Utilities/DateFormatters.swift",
                "Utilities/ErrorHandling.swift"
            ]
        )
    ]
)