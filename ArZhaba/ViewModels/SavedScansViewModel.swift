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
        // Setup a new AR session from the anchor service instead of getting an existing one
        let session = anchorService.setupARSession()
        
        do {
            // Attempt to load the saved AR world map
            let config = ARWorldTrackingConfiguration()
            
            // Try to load world map data from file
            let worldMapURL = scan.fileURL.appendingPathComponent("worldmap.arworldmap")
            if let data = try? Data(contentsOf: worldMapURL),
               let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                
                // Use the loaded world map
                config.initialWorldMap = worldMap
                showAlert(withMessage: "Loading saved anchors. Please align your device with the environment.")
            } else {
                showAlert(withMessage: "No world map found for this scan")
                return
            }
            
            // Run the session with the configuration
            session.run(config)
        } catch {
            showAlert(withMessage: "Failed to load scan: \(error.localizedDescription)")
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