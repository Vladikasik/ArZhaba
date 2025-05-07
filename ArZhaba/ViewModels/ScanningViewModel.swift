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
        
        // Display appropriate message
        if isSphereMode {
            // Share the AR session with the anchor service
            if let session = arScanService.getARSession() {
                anchorService.setARSession(session)
            }
            showAlert(withMessage: "Sphere placement mode active. Tap to place spheres.")
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
        // Ensure AR session is properly set
        if !isSphereMode {
            toggleSphereMode()
        }
        
        // Use the selected color
        let color = colorOptions[selectedColorIndex]
        anchorService.addSphereAnchor(at: transform, radius: sphereRadius, color: color)
    }
    
    /// Adds a sphere in front of the camera
    func addSphereInFrontOfCamera(frame: ARFrame) {
        // Ensure AR session is properly set
        if !isSphereMode {
            toggleSphereMode()
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
        
        showAlert(withMessage: "Sphere placed at camera position")
    }
    
    /// Saves the current AR world map with all sphere anchors
    func saveARWorldMap() {
        guard let session = arScanService.getARSession() else {
            showAlert(withMessage: "Cannot access AR session")
            return
        }
        
        // Make sure we're in sphere mode
        if !isSphereMode {
            toggleSphereMode()
        }
        
        // Request current world map from the session
        isSaving = true
        session.getCurrentWorldMap { [weak self] (worldMap, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isSaving = false
                
                if let error = error {
                    self.showAlert(withMessage: "Failed to get world map: \(error.localizedDescription)")
                    return
                }
                
                guard let worldMap = worldMap else {
                    self.showAlert(withMessage: "World map is empty")
                    return
                }
                
                // Check if we have any sphere anchors
                let sphereAnchors = self.sphereAnchors
                if sphereAnchors.isEmpty {
                    self.showAlert(withMessage: "No dots placed in this recording. Place at least one dot to save.")
                    return
                }
                
                // Save the world map
                do {
                    // Archive the world map
                    let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
                    
                    // Create directory for the scan
                    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let arScansDirectory = documentsDirectory.appendingPathComponent("ARScans")
                    
                    // Make sure the ARScans directory exists
                    if !FileManager.default.fileExists(atPath: arScansDirectory.path) {
                        try FileManager.default.createDirectory(at: arScansDirectory, withIntermediateDirectories: true, attributes: nil)
                    }
                    
                    // Create a unique directory for this scan
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                    let timestamp = dateFormatter.string(from: Date())
                    let scanDirName = "Scan_\(timestamp)"
                    let scanDirectory = arScansDirectory.appendingPathComponent(scanDirName)
                    
                    try FileManager.default.createDirectory(at: scanDirectory, withIntermediateDirectories: true, attributes: nil)
                    
                    // Save the world map to the scan directory
                    let worldMapURL = scanDirectory.appendingPathComponent("worldmap.arworldmap")
                    try data.write(to: worldMapURL)
                    
                    // Create a scan model and save it
                    let scanName = "AR Scan \(timestamp)"
                    let currentDate = Date()
                    let scanModel = ScanModel(
                        id: UUID(),
                        name: scanName,
                        fileURL: scanDirectory,
                        creationDate: currentDate,
                        fileExtension: "arworldmap",
                        fileSize: Int64(data.count)
                    )
                    
                    // Save scan info
                    if let infoData = try? JSONEncoder().encode(scanModel) {
                        let infoURL = scanDirectory.appendingPathComponent("info.json")
                        try infoData.write(to: infoURL)
                    }
                    
                    self.lastSavedURL = scanDirectory
                    self.showAlert(withMessage: "Saved AR world map with \(self.sphereAnchors.count) dots. You can now view it in Saved Scans.")
                    
                } catch {
                    self.showAlert(withMessage: "Failed to save world map: \(error.localizedDescription)")
                }
            }
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
    
    // MARK: - Private Methods
    
    private func showAlert(withMessage message: String) {
        DispatchQueue.main.async {
            self.alertMessage = message
            self.showAlert = true
        }
    }
} 