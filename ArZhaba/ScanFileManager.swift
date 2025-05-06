import Foundation
import ModelIO

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