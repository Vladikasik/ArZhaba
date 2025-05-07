# ArZhaba

ArZhaba is an iOS app for 3D scanning using LiDAR sensors available on compatible iPhone and iPad devices. The app allows users to create, save, preview, and share 3D models of real-world objects and spaces.

## Features

- **LiDAR Scanning**: Capture detailed 3D meshes of your surroundings
- **Real-time Visualization**: See the mesh being built in real-time
- **Save & Manage Scans**: Save your scans and browse them in a dedicated view
- **Share Functionality**: Share scans as OBJ or USDZ files
- **3D Preview**: Preview your scans in 3D before sharing

## Requirements

- iPhone or iPad with LiDAR sensor (iPhone 12 Pro, iPad Pro 2020, or newer)
- iOS 14.0 or later
- Xcode 13.0 or later (for development)

## Installation

### From Source

1. Clone this repository
2. Open the project in Xcode
3. Set your development team in the Signing & Capabilities tab
4. Build and run on a compatible device

## Architecture

The app follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: Data structures for scans and scanning sessions
- **Views**: SwiftUI views for the user interface
- **ViewModels**: Business logic and state management
- **Services**: Core functionality for AR scanning and file management

## Usage Guide

### Scanning

1. Open the app and go to the "Scan" tab
2. Point your device at the object or space you want to scan
3. Tap the green play button to start scanning
4. Move around the object/space slowly to capture all angles
5. The progress bar shows how much of the mesh has been captured
6. Tap the red stop button when finished

### Saving Scans

1. After scanning, tap the save button (down arrow)
2. Enter a name for your scan
3. Tap "Save Scan"
4. The scan will be saved to your device

### Viewing and Sharing Scans

1. Go to the "Saved Scans" tab
2. Browse your saved scans
3. Tap the eye icon to preview a scan in 3D
4. Tap the share icon to export the scan via AirDrop, Messages, Mail, etc.
5. Tap the trash icon to delete a scan

## Technical Details

- Built with SwiftUI and ARKit
- Uses RealityKit for 3D rendering
- Leverages the LiDAR scanner for accurate depth measurement
- Exports models in OBJ format (with potential for USDZ)

## Project Structure

```
├── ArZhaba/
│   ├── Models/
│   │   ├── ScanModel.swift         # Data model for saved scans
│   │   └── ScanSession.swift       # Model for active scanning sessions
│   ├── Views/
│   │   ├── MainView.swift          # Main tab view
│   │   ├── ScanningView.swift      # Scanning UI
│   │   ├── ARScanView.swift        # AR camera view
│   │   └── SavedScansView.swift    # Saved scans listing
│   ├── ViewModels/
│   │   ├── ScanningViewModel.swift # Controls scanning process
│   │   └── SavedScansViewModel.swift # Manages saved scans
│   ├── Services/
│   │   ├── ARScanService.swift     # LiDAR scanning core functionality
│   │   └── ScanFileService.swift   # File operations for scans
│   ├── AppDelegate.swift           # App initialization
│   ├── Assets.xcassets/            # App assets
│   └── Preview Content/            # SwiftUI previews
```

## License

This project is open source, available under the MIT license.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 