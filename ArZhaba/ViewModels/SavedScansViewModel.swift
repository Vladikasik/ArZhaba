import Foundation
import Combine
import SwiftUI

class SavedScansViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var scans: [ScanModel] = []
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var selectedScan: ScanModel? = nil
    
    // MARK: - Services
    private let scanFileService = ScanFileService.shared
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