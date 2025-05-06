# ArZhaba - Essential Project Guide

## Project Overview
ArZhaba is an iOS app utilizing LiDAR sensors to create, save, and view 3D scans of real-world spaces and objects.

## Quick Start
1. Open `ArZhaba.xcworkspace` (not the .xcodeproj file)
3. Run on a LiDAR-equipped device (iPhone 12 Pro+ or iPad Pro 2020+)

## Current Status

| Component | Status | Details |
|-----------|--------|---------|
| Core Scanning | ✅ 100% | LiDAR scanning with real-time visualization |
| Local Storage | ✅ 100% | OBJ/USDZ format storage with file management |
| UI Interface | ✅ 90% | Complete scanning and gallery UI |
| App Lifecycle | ✅ 100% | Proper AR session lifecycle management |
| Advanced Features | ❌ 0% | None yet implemented |


## Critical Issues
2. **Memory Management**: Optimize for large mesh scans
3. **Thread Safety**: Update AR session data on main thread
4. **Error Handling**: Implement proper Swift error types

## Libraries
- **Current**: All core functionality uses iOS SDK built-in frameworks
- **Added**: SwiftLint (via CocoaPods) for code quality
- **Future**: Firebase (cloud storage), Open3D (mesh optimization)

## Project Structure
```
ArZhaba/
├── Core Utilities
│   ├── LiDARScanningUtility.swift - LiDAR scanning and mesh processing
│   └── ScanFileManager.swift - Local file storage management
├── View Models
│   └── ScanningViewModel.swift - Scanning business logic
├── Views
│   ├── ContentView.swift - Main tab view
│   ├── ARScanView.swift - AR scene visualization 
│   ├── ScanningControlsView.swift - Scanning UI controls
│   └── SavedScansView.swift - Gallery of saved scans
└── App Support
    └── AppDelegate.swift - App lifecycle management
```

## Development Roadmap

### Phase 1: Build Stability (Immediate)
- [ ] Add thread safety with `DispatchQueue.main.async`
- [ ] Implement proper Swift error handling
- [ ] Optimize mesh anchor memory usage

### Phase 2: Core Enhancements (Next Sprint)
- [ ] Add mesh optimization algorithm
- [ ] Implement scan quality indicator
- [ ] Add basic texture mapping from camera
- [ ] Enable scan sharing via AirDrop

### Phase 3: Advanced Features (Future)
- [ ] Texture mapping from device camera
- [ ] Object classification (floor, walls, furniture)
- [ ] Cloud storage and sharing via Firebase
- [ ] Basic mesh editing tools
- [ ] Additional export formats

## Build Issue Fix
To fix the "Multiple commands produce Info.plist" error:

1. Select your project in the Project Navigator
2. Select the ArZhaba target → "Info" tab
3. Add the following entries:
   - Privacy - Camera Usage Description: "This app requires camera access to scan objects using LiDAR."
   - Required Device Capabilities: "arkit", "armv7"
   - Application supports iTunes file sharing: YES
   - Supports opening documents in place: YES
4. Clean build folder (Option+Cmd+Shift+K) and rebuild

## Testing Requirements
- Physical device with LiDAR sensor required
- Test in various environments (indoor/outdoor)
- Monitor memory usage during large scans 