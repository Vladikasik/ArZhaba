# ArZhaba - iOS LiDAR 3D Scanner

ArZhaba is an iOS application that leverages the LiDAR sensor on modern iPhones and iPads to create 3D scans of real-world spaces and objects. The app allows users to save these scans as 3D models and view them within the app.

## Features

- Real-time 3D scanning using the LiDAR sensor
- Live preview of the scanning process with mesh visualization
- Saving scans in OBJ or USDZ format to device storage
- Viewing saved scans in 3D
- Scan progress tracking and timing information
- Intuitive user interface for controlling the scanning process

## System Requirements

- iPhone 12 Pro/Pro Max or later (any device with LiDAR sensor)
- iPad Pro 2020 or later with LiDAR sensor
- iOS 14.0 or later

## Technology Stack

- Swift and SwiftUI for UI components
- ARKit for LiDAR scanning and AR capabilities
- RealityKit and SceneKit for 3D visualization
- ModelIO for 3D model handling and export
- Metal for low-level graphics operations

## App Structure

The app is organized around these key components:

- **LiDARScanningUtility:** Core scanning functionality using ARKit and ModelIO
- **ScanFileManager:** Handles saving and retrieving 3D scan files
- **ScanningViewModel:** Business logic for the scanning process
- **ARScanView:** SwiftUI view for displaying the AR scanning preview
- **ScanningControlsView:** User interface for controlling the scanning process
- **SavedScansView:** Interface for managing saved scans

## Future Enhancements

- Support for scan texturing using the device camera
- Cloud storage integration for sharing scans
- Mesh optimization for better file size and performance
- Object classification within scans
- Basic mesh editing capabilities

## Development Note

This app is designed as a demonstration of LiDAR scanning capabilities on iOS devices. The code structure follows MVVM architecture to separate concerns and improve maintainability.

## License

This project is licensed under MIT License. 