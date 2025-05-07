import Foundation
import ModelIO
import UIKit
import UniformTypeIdentifiers
import Combine

enum ScanFileType {
    case obj
    case usdz
    
    var fileExtension: String {
        switch self {
        case .obj:
            return "obj"
        case .usdz:
            return "usdz"
        }
    }
    
    var mimeType: String {
        switch self {
        case .obj:
            return "model/obj"
        case .usdz:
            return "model/vnd.usdz+zip"
        }
    }
}

class ScanFileService {
    // MARK: - Properties
    static let shared = ScanFileService()
    
    // Publishers
    private let scansSubject = CurrentValueSubject<[ScanModel], Never>([])
    var scansPublisher: AnyPublisher<[ScanModel], Never> {
        scansSubject.eraseToAnyPublisher()
    }
    
    // Directory name for storing scan files
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
        loadSavedScans()
    }
    
    // MARK: - Public Methods
    
    /// Saves an MDLAsset to a file with the given name
    func saveScan(asset: MDLAsset, withName name: String, fileType: ScanFileType = .obj) -> URL? {
        guard let url = getURLForNewScan(name: name, fileType: fileType) else {
            print("Failed to create URL for scan")
            return nil
        }
        
        do {
            try asset.export(to: url)
            print("Successfully saved scan to: \(url.path)")
            
            // Add metadata to make the file more accessible to other apps
            do {
                try (url as NSURL).setResourceValue(fileType.mimeType, forKey: .typeIdentifierKey)
                print("Updated type identifier for file")
            } catch {
                print("Warning: Could not set type identifier: \(error)")
            }
            
            // Make file available to Files app
            do {
                try (url as NSURL).setResourceValue(true, forKey: .isReadableKey)
                print("Made file readable")
            } catch {
                print("Warning: Could not make file readable: \(error)")
            }
            
            // Refresh scan list
            loadSavedScans()
            
            return url
        } catch {
            print("Failed to save scan: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Shares a scan file using UIActivityViewController
    func shareScan(url: URL, from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        // First make sure the file exists
        if !FileManager.default.fileExists(atPath: url.path) {
            print("Cannot share file - it doesn't exist at path: \(url.path)")
            completion(false)
            return
        }
        
        // Create a temporary copy of the file that's easier to share
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(url.lastPathComponent)
        
        do {
            // Remove any existing file at the temp path
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
            
            // Copy the file to the temp location
            try FileManager.default.copyItem(at: url, to: tempFileURL)
            
            DispatchQueue.main.async {
                let activityViewController = UIActivityViewController(
                    activityItems: [tempFileURL],
                    applicationActivities: nil
                )
                
                // For iPad
                if let popoverController = activityViewController.popoverPresentationController {
                    popoverController.sourceView = viewController.view
                    popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, 
                                                         y: viewController.view.bounds.midY, 
                                                         width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                viewController.present(activityViewController, animated: true) {
                    completion(true)
                }
            }
        } catch {
            print("Failed to prepare file for sharing: \(error)")
            completion(false)
        }
    }
    
    /// Deletes a scan file
    func deleteScan(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            
            // Refresh scan list
            loadSavedScans()
            
            return true
        } catch {
            print("Failed to delete scan: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Reload the list of saved scans
    func loadSavedScans() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Get ARScans directory
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            let arScansDirectory = documentsDirectory.appendingPathComponent("ARScans")
            
            // Make sure the ARScans directory exists
            if !FileManager.default.fileExists(atPath: arScansDirectory.path) {
                do {
                    try FileManager.default.createDirectory(at: arScansDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create ARScans directory: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.scansSubject.send([])
                    }
                    return
                }
            }
            
            do {
                // Get all subdirectories inside ARScans
                let fileURLs = try FileManager.default.contentsOfDirectory(at: arScansDirectory, 
                                                                          includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey], 
                                                                          options: .skipsHiddenFiles)
                
                // Filter to only get directories
                let directories = try fileURLs.filter { 
                    try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true 
                }
                
                // Convert URLs to ScanModel objects
                var scanModels: [ScanModel] = []
                
                for directory in directories {
                    // Check if it contains a worldmap file
                    let worldMapURL = directory.appendingPathComponent("worldmap.arworldmap")
                    if FileManager.default.fileExists(atPath: worldMapURL.path) {
                        // Check if there's a saved info.json file
                        let infoURL = directory.appendingPathComponent("info.json")
                        if let infoData = try? Data(contentsOf: infoURL),
                           let scanModel = try? JSONDecoder().decode(ScanModel.self, from: infoData) {
                            scanModels.append(scanModel)
                        } else {
                            // Create a new model from the directory
                            let dirAttrs = try FileManager.default.attributesOfItem(atPath: directory.path)
                            let creationDate = dirAttrs[.creationDate] as? Date ?? Date()
                            let fileSize = (try? Data(contentsOf: worldMapURL))?.count ?? 0
                            
                            let scanModel = ScanModel(
                                id: UUID(),
                                name: directory.lastPathComponent,
                                fileURL: directory,
                                creationDate: creationDate,
                                fileExtension: "arworldmap",
                                fileSize: Int64(fileSize)
                            )
                            scanModels.append(scanModel)
                        }
                    }
                }
                
                // Also check regular Scans directory for obj/usdz files (for compatibility)
                if let scansDirectory = self.scansDirectoryURL {
                    let scanFileURLs = try FileManager.default.contentsOfDirectory(at: scansDirectory, 
                                                              includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], 
                                                              options: .skipsHiddenFiles)
                    
                    let validFileURLs = scanFileURLs.filter { $0.pathExtension == "obj" || $0.pathExtension == "usdz" }
                    
                    for url in validFileURLs {
                        if let scanModel = ScanModel.from(url: url) {
                            scanModels.append(scanModel)
                        }
                    }
                }
                
                // Sort by creation date (newest first)
                let sortedModels = scanModels.sorted { $0.creationDate > $1.creationDate }
                
                DispatchQueue.main.async {
                    self.scansSubject.send(sortedModels)
                }
            } catch {
                print("Failed to retrieve saved scans: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.scansSubject.send([])
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Returns a new URL for a scan file with the specified name and type
    private func getURLForNewScan(name: String, fileType: ScanFileType) -> URL? {
        guard let scansDirectory = scansDirectoryURL else {
            return nil
        }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ",", with: "")
        
        let safeName = name.replacingOccurrences(of: "/", with: "-")
                           .replacingOccurrences(of: ":", with: "-")
        
        let filename = "\(safeName)_\(timestamp).\(fileType.fileExtension)"
        return scansDirectory.appendingPathComponent(filename)
    }
    
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