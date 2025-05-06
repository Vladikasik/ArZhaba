import Foundation
import ModelIO
import UIKit
import UniformTypeIdentifiers

enum ExportFileType {
    case obj
    case usd
    case usda
    case usdc
}

class ScanFileManager {
    
    // MARK: - Properties
    static let shared = ScanFileManager()
    
    // Folder name for storing scan files
    private let scansDirectoryName = "Scans"
    
    private var scansDirectoryURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(scansDirectoryName)
    }
    
    // MARK: - Initialization
    private init() {
        createScansDirectoryIfNeeded()
    }
    
    // MARK: - Public Methods
    
    /// Returns a new URL for a scan file with the specified name and file extension
    func getURLForNewScan(name: String, fileExtension: String) -> URL? {
        guard let scansDirectory = scansDirectoryURL else {
            return nil
        }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ",", with: "")
        
        let filename = "\(name)_\(timestamp).\(fileExtension)"
        return scansDirectory.appendingPathComponent(filename)
    }
    
    /// Saves a scan to local storage
    func saveScan(asset: MDLAsset, withName name: String, fileType: ExportFileType = .obj) -> URL? {
        // Determine file extension based on file type
        let fileExtension: String
        switch fileType {
        case .obj:
            fileExtension = "obj"
        case .usd, .usda, .usdc:
            fileExtension = "usdz"
        }
        
        guard let url = getURLForNewScan(name: name, fileExtension: fileExtension) else {
            print("Failed to create URL for scan")
            return nil
        }
        
        do {
            try asset.export(to: url)
            print("Successfully saved scan to: \(url.path)")
            return url
        } catch {
            print("Failed to save scan: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Saves the scan to iOS Files app
    func exportScanToFiles(from url: URL, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            guard let topViewController = UIApplication.shared.topMostViewController() else {
                print("Could not find top view controller")
                completion(false)
                return
            }
            
            let activityViewController = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            
            // For iPad
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = topViewController.view
                popoverController.sourceRect = CGRect(x: topViewController.view.bounds.midX, 
                                                     y: topViewController.view.bounds.midY, 
                                                     width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            topViewController.present(activityViewController, animated: true) {
                completion(true)
            }
        }
    }
    
    /// Returns a list of saved scan files
    func getSavedScans() -> [URL] {
        guard let scansDirectory = scansDirectoryURL else {
            return []
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: scansDirectory, 
                                                                       includingPropertiesForKeys: nil, 
                                                                       options: .skipsHiddenFiles)
            return fileURLs.filter { $0.pathExtension == "obj" || $0.pathExtension == "usdz" }
        } catch {
            print("Failed to retrieve saved scans: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Deletes a scan file
    func deleteScan(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("Failed to delete scan: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    /// Creates the scans directory if it doesn't exist
    private func createScansDirectoryIfNeeded() {
        guard let scansDirectory = scansDirectoryURL else {
            return
        }
        
        if !FileManager.default.fileExists(atPath: scansDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: scansDirectory, 
                                                       withIntermediateDirectories: true, 
                                                       attributes: nil)
            } catch {
                print("Failed to create scans directory: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UIApplication Extension
extension UIApplication {
    func topMostViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }.first
        
        guard var topController = keyWindow?.rootViewController else { return nil }
        
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        
        return topController
    }
} 