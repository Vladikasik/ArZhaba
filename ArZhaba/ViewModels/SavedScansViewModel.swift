import Foundation
import Combine
import SwiftUI
import ARKit

class SavedScansViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var scans: [ScanModel] = []
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var selectedScan: ScanModel? = nil
    
    // MARK: - Services
    private let scanFileService = ScanFileService.shared
    private let anchorService = ARAnchorService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadScans()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Subscribe to scans updates from scan file service
        scanFileService.scansPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scans in
                self?.scans = scans
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Loads the list of saved scans
    func loadScans() {
        isLoading = true
        scanFileService.loadSavedScans()
    }
    
    /// Loads a specific saved scan and its AR world map
    func loadScan(_ scan: ScanModel) {
        // Display loading message
        showAlert(withMessage: "Loading saved AR reference points...")
        
        // Setup a new AR session from the anchor service instead of getting an existing one
        let session = anchorService.setupARSession()
        
        do {
            // Verify that the world map file exists
            let worldMapURL = scan.fileURL.appendingPathComponent("worldmap.arworldmap")
            
            guard FileManager.default.fileExists(atPath: worldMapURL.path) else {
                showAlert(withMessage: "No world map found for this scan")
                return
            }
            
            let data = try Data(contentsOf: worldMapURL)
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                showAlert(withMessage: "Could not load world map data")
                return
            }
            
            // Create a suitable configuration
            let config = ARWorldTrackingConfiguration()
            
            // Essential for relocalization
            config.planeDetection = [.horizontal, .vertical]
            config.worldAlignment = .gravity
            
            // Set the initial world map for relocalization
            config.initialWorldMap = worldMap
            
            // Run the session with the configuration
            showAlert(withMessage: "Loading saved anchors. Please move around to help the device recognize the environment.")
            session.run(config, options: [.resetTracking, .removeExistingAnchors])
            
            // Register for notifications when tracking state changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(trackingStateChanged),
                name: NSNotification.Name("ARTrackingStateChanged"),
                object: nil
            )
            
        } catch {
            showAlert(withMessage: "Failed to load scan: \(error.localizedDescription)")
        }
    }
    
    @objc private func trackingStateChanged(_ notification: Notification) {
        if let trackingState = notification.userInfo?["trackingState"] as? ARCamera.TrackingState,
           case .normal = trackingState {
            // Tracking is normal, anchors should be visible
            showAlert(withMessage: "Environment recognized! Red dots show saved reference points.")
        }
    }
    
    /// Deletes a scan
    func deleteScan(_ scan: ScanModel) -> Bool {
        let result = scanFileService.deleteScan(at: scan.fileURL)
        
        if !result {
            showAlert(withMessage: "Failed to delete scan")
        }
        
        return result
    }
    
    /// Shares a scan using UIActivityViewController
    func shareScan(_ scan: ScanModel, from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        scanFileService.shareScan(url: scan.fileURL, from: viewController) { [weak self] success in
            if !success {
                self?.showAlert(withMessage: "Failed to share scan")
            }
            completion(success)
        }
    }
    
    // MARK: - Private Methods
    
    private func showAlert(withMessage message: String) {
        DispatchQueue.main.async {
            self.alertMessage = message
            self.showAlert = true
        }
    }
} 