# ArZhaba Migration Guide

This guide describes the process of migrating the ArZhaba app from its original architecture to the new MVVM (Model-View-ViewModel) architecture.

## Architecture Changes

### Previous Architecture

The previous version of ArZhaba had a mixed architecture with elements of MVC and some MVVM patterns:

- `ScanningViewModel`: Served as both controller and view model
- `LiDARScanningUtility`: Core scanning functionality
- `ScanFileManager`: File operations
- UI components were mixed with business logic

### New MVVM Architecture

The refactored app follows a clean MVVM architecture:

1. **Models**: Pure data structures
   - `ScanModel`: Represents a saved scan
   - `ScanSession`: Represents an active scanning session

2. **Views**: UI components built with SwiftUI
   - `MainView`: Tab-based main view
   - `ScanningView`: Camera view with recording controls
   - `ARScanView`: AR view for visualization
   - `SavedScansView`: List of saved scans

3. **ViewModels**: Business logic and state management
   - `ScanningViewModel`: Manages scanning process
   - `SavedScansViewModel`: Manages saved scans list

4. **Services**: Core functionality
   - `ARScanService`: Handles AR session and scanning
   - `ScanFileService`: Manages file operations

## Major Changes

### 1. Reactive Programming with Combine

The new architecture uses Combine for reactive programming:

- Publishers and subscribers for data flow
- State is propagated through published properties
- SwiftUI's `@EnvironmentObject` for dependency injection

### 2. Clear Separation of Concerns

- Services focus on a single responsibility
- ViewModels handle business logic without UI concerns
- Views focus exclusively on presentation

### 3. Immutable Data Structures

- Models are immutable where possible
- `ScanSession` uses a functional update approach with `with()` method

## Migration Steps

### For Developers

If you're working with the existing codebase and want to migrate:

1. **Create the new directory structure**:
   ```
   mkdir -p ArZhaba/Models
   mkdir -p ArZhaba/Views
   mkdir -p ArZhaba/ViewModels
   mkdir -p ArZhaba/Services
   ```

2. **Move and refactor files**:
   - Move scanning logic from `LiDARScanningUtility` to `ARScanService`
   - Move file operations from `ScanFileManager` to `ScanFileService`
   - Extract model classes and put them in the Models directory
   - Create new ViewModels with clean interfaces

3. **Update UI components**:
   - Replace old views with new SwiftUI views
   - Use `@EnvironmentObject` for accessing ViewModels

4. **Update AppDelegate**:
   - Remove global variables
   - Use `MainView` as the root view

### For Users

This migration is transparent to end users. The app functionality remains the same with improved reliability and performance.

## Key Benefits of the New Architecture

1. **Testability**: Clear separation makes unit testing easier
2. **Maintainability**: Code is better organized and follows single responsibility principle
3. **Scalability**: New features can be added with minimal changes to existing code
4. **Reactive UI**: UI automatically updates when data changes
5. **Performance**: More efficient memory usage and resource management

## Comparing Old vs. New Implementation

### Old Implementation

```swift
// Mixed responsibilities in ScanningViewModel
class ScanningViewModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published var isScanningAvailable: Bool = false
    // Many other properties
    
    let scanningUtility = LiDARScanningUtility()
    var arSession: ARSession?
    
    func startScanning() {
        // Implementation with mixed concerns
    }
    
    // ARSessionDelegate methods mixed with view model logic
}
```

### New Implementation

```swift
// Clean ViewModel with clear responsibilities
class ScanningViewModel: ObservableObject {
    @Published var scanSession: ScanSession = ScanSession.new()
    // Other published properties
    
    private let arScanService = ARScanService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Subscribe to service events
        arScanService.scanSessionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.scanSession = session
            }
            .store(in: &cancellables)
    }
    
    func startScanning() {
        arScanService.startScanning()
    }
}
```

## Conclusion

The migration to MVVM architecture positions ArZhaba for more maintainable future development while improving code quality, testability, and developer experience. 