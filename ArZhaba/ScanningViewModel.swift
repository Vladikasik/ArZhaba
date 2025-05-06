import Foundation
import ARKit
import Combine
import RealityKit

class ScanningViewModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isScanningAvailable: Bool = false
    @Published var isScanning: Bool = false
    @Published var scanProgress: Float = 0.0
    @Published var meshAnchorsCount: Int = 0
    @Published var scanningTime: TimeInterval = 0
    @Published var currentStatusMessage: String = "Ready to scan"
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    
    // MARK: - Internal Properties
    // These properties are internal so they can be accessed by ARScanView
    let scanningUtility = LiDARScanningUtility()
    var arSession: ARSession?
    
    // MARK: - Private Properties
    private var scanTimer: Timer?
    private var scanStartTime: Date?
    
    // MARK: - Initialization
    override init() {
        super.init()
        checkLiDARAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Checks if the device supports LiDAR scanning
    func checkLiDARAvailability() {
        isScanningAvailable = LiDARScanningUtility.deviceSupportsLiDAR()
        
        if !isScanningAvailable {
            currentStatusMessage = "LiDAR scanning not available on this device"
        }
    }
    
    /// Starts a new scan session
    func startScanning() {
        guard isScanningAvailable else {
            showAlert(withMessage: "LiDAR scanning is not available on this device")
            return
        }
        
        // Reset session if already running
        stopScanning()
        
        // Create a new AR session
        arSession = scanningUtility.createARSession()
        arSession?.delegate = self
        
        // Configure session for scanning
        guard let configuration = scanningUtility.createScanningConfiguration() else {
            showAlert(withMessage: "Failed to create scanning configuration")
            return
        }
        
        // Run the session
        arSession?.run(configuration)
        
        // Update state
        isScanning = true
        scanProgress = 0.0
        meshAnchorsCount = 0
        currentStatusMessage = "Scanning started"
        
        // Start the timer
        scanStartTime = Date()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.scanStartTime else { return }
            self.scanningTime = Date().timeIntervalSince(startTime)
        }
    }
    
    /// Stops the current scan session
    func stopScanning() {
        // Stop the session
        arSession?.pause()
        
        // Stop the timer
        scanTimer?.invalidate()
        scanTimer = nil
        
        // Update state if we were scanning
        if isScanning {
            isScanning = false
            currentStatusMessage = "Scanning stopped"
        }
    }
    
    /// Saves the current scan
    func saveScan(withName name: String) -> Bool {
        guard let arSession = arSession, let frame = arSession.currentFrame else {
            showAlert(withMessage: "No scan data available")
            return false
        }
        
        // Update mesh anchors with the latest frame
        scanningUtility.updateMeshAnchors(frame: frame)
        
        // Create MDLAsset from mesh anchors
        guard let asset = scanningUtility.createMDLAsset() else {
            showAlert(withMessage: "Failed to create 3D asset from scan data")
            return false
        }
        
        // Save the asset
        if let url = ScanFileManager.shared.saveScan(asset: asset, withName: name) {
            showAlert(withMessage: "Scan saved successfully")
            return true
        } else {
            showAlert(withMessage: "Failed to save scan")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    /// Shows an alert with the specified message
    private func showAlert(withMessage message: String) {
        alertMessage = message
        showAlert = true
    }
    
    /// Updates the scan progress based on the mesh anchor count
    private func updateScanProgress(withMeshCount count: Int) {
        // Simple progress calculation based on mesh anchor count
        // This is a basic implementation and could be improved
        let maxExpectedMeshes = 100 // This value may need adjustment based on testing
        let progress = min(Float(count) / Float(maxExpectedMeshes), 1.0)
        
        scanProgress = progress
        meshAnchorsCount = count
        
        // Update status message based on progress
        if progress < 0.3 {
            currentStatusMessage = "Scanning in progress (Early stage)"
        } else if progress < 0.7 {
            currentStatusMessage = "Scanning in progress (Building mesh)"
        } else {
            currentStatusMessage = "Scanning in progress (Refining details)"
        }
    }
}

// MARK: - ARSessionDelegate
extension ScanningViewModel: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let meshAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        updateScanProgress(withMeshCount: meshAnchors.count)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        stopScanning()
        currentStatusMessage = "AR session failed: \(error.localizedDescription)"
        showAlert(withMessage: "Scanning failed: \(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        currentStatusMessage = "AR session interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        currentStatusMessage = "AR session resumed"
    }
} 