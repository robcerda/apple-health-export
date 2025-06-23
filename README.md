# Health Exporter

A privacy-focused, open-source iOS app that exports Apple Health data for personal analysis. The app prioritizes user privacy by making zero network requests and giving users complete control over their health data.

## Features

### 🔒 Privacy First
- **Zero network requests** - No data leaves your device without your explicit action
- **No third-party dependencies** - Uses only Apple frameworks
- **Optional AES-256-GCM encryption** for sensitive data protection
- **Open source** - Fully auditable code

### 📊 Comprehensive Data Export
- **All health data types** including heart rate, steps, workouts, sleep, and clinical records
- **Flexible export formats** - JSON and SQLite database options
- **Incremental exports** - Only export new data since the last export
- **Large dataset handling** - Efficiently processes years of health data

### ⚡ Performance Optimized
- **Streaming architecture** - Processes data in batches to prevent memory issues
- **Background processing** - Supports automated exports
- **Progress tracking** - Real-time export progress with cancellation support

## Technical Requirements

- **iOS 16.0+** (for latest Swift Concurrency features)
- **Swift 5.9+**
- **Xcode 15.0+**
- **Device with HealthKit support**

## Architecture

### Core Components

```
HealthExporter/
├── Models/
│   ├── HealthData.swift          # Data structures for health samples
│   ├── ExportConfiguration.swift # User settings and preferences
│   └── SyncState.swift          # Export history and sync anchors
├── Services/
│   ├── HealthKitService.swift   # HealthKit data access
│   ├── ExportService.swift      # Export orchestration
│   ├── EncryptionService.swift  # AES-256-GCM encryption
│   └── FileService.swift        # File system operations
├── Views/
│   ├── ContentView.swift        # Main app interface
│   ├── SettingsView.swift       # Configuration screen
│   └── ProgressView.swift       # Export progress display
└── Utilities/
    ├── DateFormatters.swift     # Date formatting utilities
    └── ErrorHandling.swift      # User-friendly error messages
```

### Key Design Principles

1. **Privacy by Design** - No data collection or network requests
2. **Memory Efficiency** - Stream processing for large datasets
3. **User Control** - Granular data type selection and export options
4. **Transparency** - Clear progress reporting and error handling
5. **Security** - Optional encryption with secure key derivation

## Export Formats

### JSON Format
```json
{
  "metadata": {
    "exportDate": "2024-12-28T10:30:00Z",
    "dataDateRange": {
      "start": "2020-01-01T00:00:00Z",
      "end": "2024-12-28T10:30:00Z"
    },
    "version": "1.0",
    "recordCount": 1234567,
    "encrypted": false
  },
  "healthData": {
    "heartRate": [...],
    "steps": [...],
    "workouts": [...]
  }
}
```

### SQLite Schema
- **Optimized indexes** for common queries
- **Normalized structure** with metadata preservation
- **Workout heart rate correlation** for detailed analysis

## Security Features

### Encryption
- **AES-256-GCM** encryption for maximum security
- **PBKDF2 key derivation** with 100,000+ iterations
- **Secure salt generation** for each export
- **No password storage** - keys derived on-demand

### Privacy Measures
- **Local processing only** - No cloud services
- **User-controlled sharing** via iOS share sheet
- **Optional data type filtering** for sensitive information
- **Audit trail** with export history

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/health-exporter.git
cd health-exporter
```

2. Open in Xcode:
```bash
open HealthExporter.xcodeproj
```

3. Configure signing and provisioning
4. Build and run on your iOS device

### Requirements
- Apple Developer account for device installation
- iOS device with Health app and data

## Usage

### First Time Setup
1. Launch the app
2. Grant Health data access permissions
3. Configure export preferences in Settings
4. Run your first export

### Export Options
- **Full Export** - All historical data
- **Incremental Export** - Only new data since last export
- **Custom Date Range** - Specific time periods
- **Data Type Selection** - Choose which health metrics to include

### Automation
- **Background exports** - Scheduled automatic updates
- **Configurable frequency** - Daily, weekly, or monthly
- **Local notifications** - Export completion alerts

## Development

### Code Style
- **Swift Concurrency** (async/await) throughout
- **Value types preferred** over reference types
- **Comprehensive error handling** with user-friendly messages
- **Memory-conscious design** for large datasets

### Testing Strategy
- **Unit tests** for data transformation logic
- **Performance tests** with large synthetic datasets
- **Memory profiling** to ensure stable operation
- **Integration tests** for HealthKit interactions

### Contributing
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Privacy Policy

This app:
- ✅ **Does NOT** collect any personal data
- ✅ **Does NOT** make network requests
- ✅ **Does NOT** use analytics or tracking
- ✅ **Does NOT** share data with third parties
- ✅ **Does** keep all data on your device
- ✅ **Does** give you complete control over exports

## Support

For issues, feature requests, or questions:
- Create an issue on GitHub
- Review the troubleshooting guide
- Check existing discussions

## Roadmap

### Planned Features
- [ ] Data visualization and charts
- [ ] Export to additional formats (CSV, XML)
- [ ] Companion macOS app
- [ ] Advanced filtering and search
- [ ] Data validation and cleanup tools

### Performance Targets
- ✅ Export 5+ years of data without crashes
- ✅ Memory usage under 100MB during export
- ✅ Export completion under 10 minutes for full datasets
- ✅ App size under 10MB

---

**Made with ❤️ for health data ownership and privacy**