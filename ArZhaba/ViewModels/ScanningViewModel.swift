import Foundation
import Combine
import ARKit
import ModelIO
import SwiftUI

class ScanningViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var scanSession: ScanSession = ScanSession.new()
    @Published var isScanningAvailable: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var lastSavedURL: URL? = nil
    @Published var isSaving: Bool = false
    @Published var isSharing: Bool = false
    @Published var isMeshVisible: Bool = false
    
    // MARK: - Services
    private let arScanService = ARScanService()
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
    }
    
    // MARK: - Public Methods
    
    /// Checks if the device supports LiDAR scanning
    func checkLiDARAvailability() {
        isScanningAvailable = ARScanService.deviceSupportsLiDAR()
    }
    
    /// Starts a new scan session
    func startScanning() {
        arScanService.startScanning()
    }
    
    /// Stops the current scan session
    func stopScanning() {
        arScanService.stopScanning()
    }
    
    /// Returns the current AR session for AR view
    func getARSession() -> ARSession? {
        return arScanService.getARSession()
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
    
    // MARK: - Private Methods
    
    private func showAlert(withMessage message: String) {
        DispatchQueue.main.async {
            self.alertMessage = message
            self.showAlert = true
        }
    }
} 