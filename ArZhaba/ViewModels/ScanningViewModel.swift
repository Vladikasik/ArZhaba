import Foundation
import Combine
import ARKit
import ModelIO
import SwiftUI
import ArZhaba  // Add import for the app module to ensure ScanModel is visible

class ScanningViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var scanSession: ScanSession = ScanSession.new()
    @Published var isScanningAvailable: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var lastSavedURL: URL? = nil
    @Published var isSaving: Bool = false
    @Published var isSharing: Bool = false
    @Published var isMeshVisible: Bool = true
    
    // AR Sphere placement properties
    @Published var sphereAnchors: [SphereAnchor] = []
    @Published var isSphereMode: Bool = false
    @Published var selectedColorIndex: Int = 0
    @Published var sphereRadius: Float = 0.025
    
    // Color options for sphere anchors
    let colorOptions: [UIColor] = [
        .red, .blue, .green, .yellow, .purple, .orange, .cyan, .magenta
    ]
    
    // MARK: - Room Recording Methods
    
    // Add a property to track if we're showing the room dialog
    @Published var isShowingNewRoomDialog: Bool = false
    @Published var newRoomName: String = ""
    
    // MARK: - Services
    private let arScanService = ARScanService()
    private let anchorService = ARAnchorService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
        checkLiDARAvailability()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Subscribe to scan session updates
        arScanService.scanSessionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self = self else { return }
                self.scanSession = session
                
                // Update mesh visibility
                if session.meshAnchorsCount > 0 && !self.isMeshVisible {
                    self.isMeshVisible = true
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to alert messages
        arScanService.alertPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showAlert(withMessage: message)
            }
            .store(in: &cancellables)
            
        // Subscribe to sphere anchor updates
        anchorService.anchorsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] anchors in
                self?.sphereAnchors = anchors
            }
            .store(in: &cancellables)
            
        // Subscribe to anchor service status messages
        anchorService.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                // Show important messages as alerts
                if message.contains("Error") || message.contains("success") {
                    self?.showAlert(withMessage: message)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Checks if the device supports LiDAR scanning
    func checkLiDARAvailability() {
        isScanningAvailable = ARScanService.deviceSupportsLiDAR()
    }
    
    /// Starts a new scan session
    func startScanning() {
        // Disable sphere mode when starting a scan
        if isSphereMode {
            isSphereMode = false
        }
        
        arScanService.startScanning()
    }
    
    /// Stops the current scan session
    func stopScanning() {
        arScanService.stopScanning()
        
        // When stopping scanning, we might want to enter sphere mode
        // but only show the alert if we have mesh data
        if scanSession.meshAnchorsCount > 0 {
            showAlert(withMessage: "Scanning completed. You can now place spheres by tapping the 'Place Spheres' button.")
        }
    }
    
    /// Returns the current AR session for AR view
    func getARSession() -> ARSession? {
        return arScanService.getARSession()
    }
    
    /// Toggle between scanning mode and sphere placement mode
    func toggleSphereMode() {
        isSphereMode = !isSphereMode
        
        // Update status message without showing an alert
        if isSphereMode {
            // Instead of sharing the AR session, we'll use the anchorService directly
            // Note: In the new implementation, the anchorService manages its own session
            
            // Just update the status message without showing an alert
            alertMessage = "Sphere placement mode active. Tap to place spheres."
            // No need to call showAlert
        }
    }
    
    /// Saves the current scan with the given name
    func saveScan(withName name: String) -> Bool {
        // Make sure we have scan data
        if scanSession.meshAnchorsCount == 0 {
            showAlert(withMessage: "No scan data to save")
            return false
        }
        
        isSaving = true
        
        // Create asset from mesh anchors
        guard let asset = arScanService.createMDLAsset() else {
            isSaving = false
            showAlert(withMessage: "Failed to create 3D asset from scan data")
            return false
        }
        
        // Save asset
        if let url = ScanFileService.shared.saveScan(asset: asset, withName: name) {
            lastSavedURL = url
            isSaving = false
            showAlert(withMessage: "Scan saved successfully")
            return true
        } else {
            isSaving = false
            showAlert(withMessage: "Failed to save scan")
            return false
        }
    }
    
    /// Shares the last saved scan
    func shareScan(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let url = lastSavedURL else {
            showAlert(withMessage: "No saved scan to share")
            completion(false)
            return
        }
        
        isSharing = true
        ScanFileService.shared.shareScan(url: url, from: viewController) { [weak self] success in
            DispatchQueue.main.async {
                self?.isSharing = false
                completion(success)
            }
        }
    }
    
    // MARK: - Sphere Anchor Methods
    
    /// Adds a sphere at the given position
    func addSphere(at transform: simd_float4x4) {
        // Ensure we're in sphere mode
        if !isSphereMode {
            toggleSphereMode()
        }
        
        // Make sure we're recording before adding a sphere
        if !ensureRecordingStarted() {
            return
        }
        
        // Use the selected color
        let color = colorOptions[selectedColorIndex]
        anchorService.addSphereAnchor(at: transform, radius: sphereRadius, color: color)
    }
    
    /// Adds a sphere in front of the camera
    func addSphereInFrontOfCamera(frame: ARFrame) {
        // Ensure we're in sphere mode
        if !isSphereMode {
            toggleSphereMode()
        }
        
        // Make sure we're recording before adding a sphere
        if !ensureRecordingStarted() {
            return
        }
        
        // Create a position 0.5 meters in front of the camera
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.5
        
        let transform = simd_mul(frame.camera.transform, translation)
        
        // Add sphere with the current color and radius
        let color = colorOptions[selectedColorIndex]
        anchorService.addSphereAnchor(at: transform, radius: sphereRadius, color: color)
    }
    
    /// Adds a sphere at the current camera position
    func addSphereAtCameraPosition() {
        // Ensure we're in sphere mode
        if !isSphereMode {
            toggleSphereMode()
        }
        
        // Make sure we're recording before adding a sphere
        if !ensureRecordingStarted() {
            return
        }
        
        guard let session = arScanService.getARSession(),
              let frame = session.currentFrame else {
            showAlert(withMessage: "Cannot access camera position")
            return
        }
        
        // Get the current camera transform
        let cameraTransform = frame.camera.transform
        
        // Create the sphere at the camera position
        let color = colorOptions[selectedColorIndex]
        anchorService.addSphereAnchor(at: cameraTransform, radius: sphereRadius, color: color)
        
        // Update status message without showing an alert
        alertMessage = "Sphere placed at camera position"
    }
    
    /// Saves the current AR world map with all sphere anchors
    func saveARWorldMap() {
        // Check if we have any sphere anchors
        if sphereAnchors.isEmpty {
            showAlert(withMessage: "No dots placed in this recording. Place at least one dot to save.")
            return
        }
        
        // In our new implementation, saving is handled by the ARAnchorService
        // We should check if we're already recording
        if anchorService.sessionState == .recording {
            // If we're recording, stop recording to save
            if anchorService.stopRecording() {
                showAlert(withMessage: "Room saved with \(sphereAnchors.count) dots.")
            } else {
                showAlert(withMessage: "Failed to save room.")
            }
        } else {
            // If we're not recording, we need to start a recording first
            // Show a dialog to enter room name
            showAlert(withMessage: "Please start recording a room first using the AR Rooms tab.")
        }
    }
    
    /// Removes a sphere
    func removeSphere(_ anchor: SphereAnchor) {
        anchorService.removeSphereAnchor(anchor)
    }
    
    /// Clears all sphere anchors
    func clearAllSpheres() {
        anchorService.clearAllSphereAnchors()
    }
    
    /// Get the color for display in SwiftUI
    func getSwiftUIColor(for index: Int) -> Color {
        guard index < colorOptions.count else { return Color.red }
        
        let uiColor = colorOptions[index]
        return Color(uiColor)
    }
    
    /// Get the currently selected SwiftUI color
    var selectedSwiftUIColor: Color {
        guard selectedColorIndex < colorOptions.count else { return Color.red }
        return Color(colorOptions[selectedColorIndex])
    }
    
    // MARK: - Room Recording Methods
    
    /// Start recording a new room
    func startRecordingRoom() {
        if !newRoomName.isEmpty {
            if anchorService.startRecording(roomName: newRoomName) {
                newRoomName = ""
                isShowingNewRoomDialog = false
                
                // Also enable sphere mode automatically
                if !isSphereMode {
                    toggleSphereMode()
                }
                
                // Update status message
                alertMessage = "Recording started for room: \(newRoomName). Tap to place spheres."
            }
        } else {
            showAlert(withMessage: "Please enter a room name first")
        }
    }
    
    /// Check and start recording if needed
    func ensureRecordingStarted() -> Bool {
        if anchorService.sessionState != .recording {
            // Need to start a recording session
            isShowingNewRoomDialog = true
            return false
        }
        return true
    }
    
    // MARK: - Private Methods
    
    private func showAlert(withMessage message: String) {
        DispatchQueue.main.async {
            self.alertMessage = message
            self.showAlert = true
        }
    }
} 