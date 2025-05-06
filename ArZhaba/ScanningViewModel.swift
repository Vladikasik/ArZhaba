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
    @Published var isLoading: Bool = false
    @Published var isMeshVisible: Bool = false
    @Published var lastSavedURL: URL? = nil
    
    // MARK: - Internal Properties
    // These properties are internal so they can be accessed by ARScanView
    let scanningUtility = LiDARScanningUtility()
    var arSession: ARSession?
    
    // MARK: - Private Properties
    private var scanTimer: Timer?
    private var scanStartTime: Date?
    private var loadingTimeout: Timer?
    
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
    
    /// Cancels loading and proceeds with scanning
    func cancelLoading() {
        isLoading = false
        loadingTimeout?.invalidate()
        startScanning()
    }
    
    /// Starts a new scan session
    func startScanning() {
        guard isScanningAvailable else {
            showAlert(withMessage: "LiDAR scanning is not available on this device")
            return
        }
        
        // Reset session if already running
        stopScanning()
        
        // Set loading state
        isLoading = true
        currentStatusMessage = "Initializing camera..."
        
        // Start a timeout timer
        loadingTimeout = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.isLoading = false
            self?.showAlert(withMessage: "Loading took too long. Please try again or restart the app.")
        }
        
        // Create a new AR session
        arSession = scanningUtility.createARSession()
        arSession?.delegate = self
        
        // Configure session for scanning
        guard let configuration = scanningUtility.createScanningConfiguration() else {
            isLoading = false
            loadingTimeout?.invalidate()
            showAlert(withMessage: "Failed to create scanning configuration")
            return
        }
        
        // Run the session
        arSession?.run(configuration)
        
        // We'll set isScanning to true once the session actually starts in session delegate
    }
    
    /// Stops the current scan session
    func stopScanning() {
        // Stop the session
        arSession?.pause()
        
        // Stop the timer
        scanTimer?.invalidate()
        scanTimer = nil
        loadingTimeout?.invalidate()
        
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
            lastSavedURL = url
            showAlert(withMessage: "Scan saved successfully. Use 'Share' button to export to Files app.")
            return true
        } else {
            showAlert(withMessage: "Failed to save scan")
            return false
        }
    }
    
    /// Exports the last saved scan to the Files app
    func exportLastSavedScan(completion: @escaping (Bool) -> Void) {
        guard let url = lastSavedURL else {
            showAlert(withMessage: "No saved scan to export")
            completion(false)
            return
        }
        
        ScanFileManager.shared.exportScanToFiles(from: url) { success in
            if !success {
                self.showAlert(withMessage: "Failed to export scan to Files app")
            }
            completion(success)
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
        // If this is the first mesh anchor, set mesh as visible and switch from loading to scanning
        if count > 0 && !isMeshVisible {
            isMeshVisible = true
            if isLoading {
                isLoading = false
                loadingTimeout?.invalidate()
                // Start recording now that the mesh is visible
                isScanning = true
                scanStartTime = Date()
                scanTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self, let startTime = self.scanStartTime else { return }
                    self.scanningTime = Date().timeIntervalSince(startTime)
                }
            }
        }
        
        // Simple progress calculation based on mesh anchor count
        // This is a basic implementation and could be improved
        let maxExpectedMeshes = 100 // This value may need adjustment based on testing
        let progress = min(Float(count) / Float(maxExpectedMeshes), 1.0)
        
        scanProgress = progress
        meshAnchorsCount = count
        
        // Update status message based on progress
        if !isMeshVisible {
            currentStatusMessage = "Initializing camera..."
        } else if progress < 0.3 {
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
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        if !meshAnchors.isEmpty {
            // When we add the first mesh anchor, stop loading state
            if isLoading && !isMeshVisible {
                isMeshVisible = true
                isLoading = false
                loadingTimeout?.invalidate()
                
                // Start recording automatically
                isScanning = true
                scanStartTime = Date()
                scanTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self, let startTime = self.scanStartTime else { return }
                    self.scanningTime = Date().timeIntervalSince(startTime)
                }
                
                currentStatusMessage = "Mesh detected - Recording started"
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        stopScanning()
        isLoading = false
        loadingTimeout?.invalidate()
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