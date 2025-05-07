import Foundation
import ARKit
import Combine

/// Service for managing AR rooms, including saving and loading world maps and anchors
class RoomService {
    // MARK: - Singleton
    static let shared = RoomService()
    
    // MARK: - Properties
    private let roomsURL: URL?
    private(set) var rooms: [RoomModel] = []
    
    // Publishers
    private let roomsSubject = CurrentValueSubject<[RoomModel], Never>([])
    private let statusSubject = PassthroughSubject<String, Never>()
    private let loadingProgressSubject = CurrentValueSubject<Double, Never>(0.0)
    
    // Configure batch size for anchor loading
    private let anchorBatchSize = 50
    
    var roomsPublisher: AnyPublisher<[RoomModel], Never> {
        roomsSubject.eraseToAnyPublisher()
    }
    
    var statusPublisher: AnyPublisher<String, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    var loadingProgressPublisher: AnyPublisher<Double, Never> {
        loadingProgressSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    private init() {
        // Get the rooms directory URL
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.roomsURL = documentsDirectory.appendingPathComponent("Rooms", isDirectory: true)
            
            // Create rooms directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: roomsURL!.path) {
                do {
                    try FileManager.default.createDirectory(at: roomsURL!, withIntermediateDirectories: true)
                    Logger.shared.info("Created rooms directory at: \(roomsURL!.path)", 
                              destination: "RoomService")
                } catch {
                    Logger.shared.error("Error creating rooms directory: \(error)", 
                               destination: "RoomService")
                }
            }
        } else {
            Logger.shared.error("Could not access documents directory", destination: "RoomService")
            self.roomsURL = nil
        }
        
        loadRooms()
    }
    
    // MARK: - Public Methods
    
    /// Creates a new room with the provided name
    func createRoom(name: String) -> RoomModel? {
        // Check if a room with this name already exists
        if rooms.contains(where: { $0.name == name }) {
            statusSubject.send("A room with this name already exists")
            return nil
        }
        
        // Create file URLs for the new room
        guard let urls = RoomModel.createFileURLs(for: name) else {
            statusSubject.send("Failed to create room file URLs")
            return nil
        }
        
        // Create the room model
        let room = RoomModel(name: name, worldMapURL: urls.worldMapURL, anchorsURL: urls.anchorsURL)
        
        // Add to rooms collection
        rooms.append(room)
        roomsSubject.send(rooms)
        
        // Save rooms list
        saveRoomsList()
        
        statusSubject.send("Room '\(name)' created successfully")
        return room
    }
    
    /// Deletes a room
    func deleteRoom(_ room: RoomModel) {
        // Get the room directory
        let roomDirectory = room.worldMapURL.deletingLastPathComponent()
        
        do {
            // Check if directory exists before attempting removal
            if FileManager.default.fileExists(atPath: roomDirectory.path) {
                // Try to remove the directory and all its contents
                try FileManager.default.removeItem(at: roomDirectory)
                statusSubject.send("Room '\(room.name)' deleted successfully")
            } else {
                // Directory doesn't exist, but we can still remove it from the list
                statusSubject.send("Room directory not found, removing from list only")
            }
            
            // Remove from rooms collection
            let previousCount = rooms.count
            rooms.removeAll { $0.id == room.id }
            
            // Check if removal was successful
            if rooms.count < previousCount {
                // Save rooms list to persist the change
                saveRoomsList()
                roomsSubject.send(rooms)
            } else {
                statusSubject.send("Warning: Room was not found in the rooms list")
            }
        } catch {
            statusSubject.send("Error deleting room: \(error.localizedDescription)")
            print("Delete error details: \(error)")
            
            // Despite the error, try to remove from list if that's still possible
            let previousCount = rooms.count
            rooms.removeAll { $0.id == room.id }
            
            if rooms.count < previousCount {
                saveRoomsList()
                roomsSubject.send(rooms)
                statusSubject.send("Room removed from list, but files may remain")
            }
        }
    }
    
    /// Loads the specified AR world map
    func loadWorldMap(from room: RoomModel) -> ARWorldMap? {
        do {
            // Update progress to 10%
            loadingProgressSubject.send(0.1)
            
            // Load data in background for better UI responsiveness
            let data = try Data(contentsOf: room.worldMapURL)
            
            // Update progress to 50%
            loadingProgressSubject.send(0.5)
            
            let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
            
            // Update progress to 80%
            loadingProgressSubject.send(0.8)
            
            return worldMap
        } catch {
            statusSubject.send("Error loading world map: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Saves an AR world map to the specified room
    func saveWorldMap(_ worldMap: ARWorldMap, to room: RoomModel) {
        // Use a background thread to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
            do {
                // Try to optimize the world map before saving
                let optimizedWorldMap = self.optimizeWorldMap(worldMap)
                
                // Update status
                DispatchQueue.main.async {
                    self.statusSubject.send("Optimizing and saving world map...")
                }
                
                // Create directory if it doesn't exist
                let directory = room.worldMapURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                }
                
                // Use memory-efficient archiving
                let data = try NSKeyedArchiver.archivedData(withRootObject: optimizedWorldMap, requiringSecureCoding: true)
                
                // Create a temporary file and then move it to final location for atomic write
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try data.write(to: tempURL, options: [.atomic])
                
                // Only remove old file AFTER successful write to temp file
                if FileManager.default.fileExists(atPath: room.worldMapURL.path) {
                    // Use a backup approach to avoid complete data loss
                    let backupURL = room.worldMapURL.deletingPathExtension().appendingPathExtension("backup.arworldmap")
                    try? FileManager.default.copyItem(at: room.worldMapURL, to: backupURL)
                    
                    // Now remove the original
                    try FileManager.default.removeItem(at: room.worldMapURL)
                }
                
                // Move temp file to final destination
                try FileManager.default.moveItem(at: tempURL, to: room.worldMapURL)
                
                // Remove backup if it exists and move completed successfully
                let backupURL = room.worldMapURL.deletingPathExtension().appendingPathExtension("backup.arworldmap")
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try? FileManager.default.removeItem(at: backupURL)
                }
                
                DispatchQueue.main.async {
                    self.statusSubject.send("World map saved to room '\(room.name)'")
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusSubject.send("Error saving world map: \(error.localizedDescription)")
                    print("Details: \(error)")
                }
                
                // Try to restore from backup if it exists
                let backupURL = room.worldMapURL.deletingPathExtension().appendingPathExtension("backup.arworldmap")
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    do {
                        try FileManager.default.copyItem(at: backupURL, to: room.worldMapURL)
                        try FileManager.default.removeItem(at: backupURL)
                        
                        DispatchQueue.main.async {
                            self.statusSubject.send("Restored previous world map from backup")
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.statusSubject.send("Failed to restore from backup: \(error.localizedDescription)")
                            print("Backup restore error: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    /// Optimizes a world map to reduce its memory footprint
    private func optimizeWorldMap(_ worldMap: ARWorldMap) -> ARWorldMap {
        // Create a copy to avoid modifying the original
        guard let worldMapCopy = try? NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true),
              let optimizedMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worldMapCopy) else {
            return worldMap
        }
        
        // Keep track of how many anchors we filtered
        let originalAnchorCount = optimizedMap.anchors.count
        
        // Filter anchors to keep only essential ones
        let essentialAnchors = optimizedMap.anchors.filter { anchor in
            // Keep these types of anchors:
            // 1. SphereAnchors - our primary data
            // 2. ARPlaneAnchors - important for accurate placement
            if anchor is SphereAnchor || anchor is ARPlaneAnchor {
                return true
            }
            
            // Filter out all other types of anchors
            return false
        }
        
        // Log optimization results
        let reducedBy = originalAnchorCount - essentialAnchors.count
        if reducedBy > 0 {
            print("Optimized world map: removed \(reducedBy) of \(originalAnchorCount) anchors")
        }
        
        // Apply our filtered anchors
        optimizedMap.anchors = essentialAnchors
        return optimizedMap
    }
    
    /// Loads sphere anchors from the specified room asynchronously with batching
    func loadAnchors(from room: RoomModel, completion: @escaping ([SphereAnchor]?) -> Void) {
        // Load anchors asynchronously to avoid blocking the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                Logger.shared.error("Self reference lost during anchor loading", destination: "RoomService.loadAnchors")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            do {
                // Reset progress
                DispatchQueue.main.async {
                    self.loadingProgressSubject.send(0.0)
                    self.statusSubject.send("Loading anchors...")
                }
                
                // Verify room directory exists
                let roomDir = room.worldMapURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: roomDir.path) {
                    Logger.shared.error("Room directory missing: \(roomDir.path)",
                              destination: "RoomService.loadAnchors")
                    
                    DispatchQueue.main.async {
                        self.statusSubject.send("Room directory not found: \(roomDir.path)")
                        completion(nil)
                    }
                    return
                }
                
                // Check if file exists
                if !FileManager.default.fileExists(atPath: room.anchorsURL.path) {
                    Logger.shared.info("No anchors file found, creating empty room at: \(room.anchorsURL.path)",
                             destination: "RoomService.loadAnchors")
                    
                    DispatchQueue.main.async {
                        self.statusSubject.send("No anchors file found, creating empty room")
                        completion([])
                    }
                    return
                }
                
                // Log file info for debugging
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: room.anchorsURL.path)
                    if let fileSize = attributes[.size] as? NSNumber {
                        Logger.shared.info("Loading anchors file, size: \(fileSize.intValue) bytes",
                                 destination: "RoomService.loadAnchors")
                    }
                } catch {
                    Logger.shared.warning("Error getting anchor file attributes: \(error)",
                                destination: "RoomService.loadAnchors")
                }
                
                // Load data
                let data = try Data(contentsOf: room.anchorsURL)
                Logger.shared.info("Successfully loaded \(data.count) bytes of anchor data",
                         destination: "RoomService.loadAnchors")
                
                // Update progress to 30%
                DispatchQueue.main.async {
                    self.loadingProgressSubject.send(0.3)
                }
                
                // Set memory limits for unarchiving to prevent crashes
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.decodingFailurePolicy = .setErrorAndReturn
                
                // Explicitly set allowed classes to prevent unarchiving errors
                let allowedClasses = [NSArray.self, SphereAnchor.self, ARAnchor.self, NSUUID.self, 
                                      NSNumber.self, NSString.self, UIColor.self]
                allowedClasses.forEach { unarchiver.setClass($0, forClassName: NSStringFromClass($0)) }
                
                guard let anchors = unarchiver.decodeObject(of: allowedClasses, forKey: NSKeyedArchiveRootObjectKey) as? [SphereAnchor] else {
                    Logger.shared.error("Anchor decoding failed, data may be corrupted",
                               destination: "RoomService.loadAnchors")
                    
                    DispatchQueue.main.async {
                        self.statusSubject.send("Error decoding anchors: invalid format")
                        completion(nil)
                    }
                    return
                }
                
                // Update progress to 60%
                DispatchQueue.main.async {
                    self.loadingProgressSubject.send(0.6)
                }
                
                // Process anchors in batches for smoother UI
                var loadedAnchors: [SphereAnchor] = []
                let totalBatches = max(1, Int(ceil(Double(anchors.count) / Double(self.anchorBatchSize))))
                
                Logger.shared.info("Processing \(anchors.count) anchors in \(totalBatches) batches",
                         destination: "RoomService.loadAnchors")
                
                for batchIndex in 0..<totalBatches {
                    let startIndex = batchIndex * self.anchorBatchSize
                    let endIndex = min(startIndex + self.anchorBatchSize, anchors.count)
                    let batch = Array(anchors[startIndex..<endIndex])
                    
                    loadedAnchors.append(contentsOf: batch)
                    
                    // Update progress based on batch completion
                    let progress = 0.6 + (0.4 * Double(batchIndex + 1) / Double(totalBatches))
                    DispatchQueue.main.async {
                        self.loadingProgressSubject.send(progress)
                        self.statusSubject.send("Loading anchors: \(loadedAnchors.count)/\(anchors.count)")
                    }
                    
                    Logger.shared.debug("Processed batch \(batchIndex+1)/\(totalBatches), total anchors: \(loadedAnchors.count)",
                              destination: "RoomService.loadAnchors")
                    
                    // Add a small delay between batches to avoid UI freezing
                    if batchIndex < totalBatches - 1 {
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                }
                
                // Final progress update to 100%
                DispatchQueue.main.async {
                    self.loadingProgressSubject.send(1.0)
                    self.statusSubject.send("Loaded \(loadedAnchors.count) anchors successfully")
                    Logger.shared.info("Successfully completed loading \(loadedAnchors.count) anchors",
                             source: "Anchor Loading",
                             destination: "RoomService.loadAnchors")
                    completion(loadedAnchors)
                }
            } catch {
                Logger.shared.error("Detailed anchor loading error: \(error)",
                           destination: "RoomService.loadAnchors")
                
                DispatchQueue.main.async {
                    self.statusSubject.send("Error loading anchors: \(error.localizedDescription)")
                    self.loadingProgressSubject.send(0.0)
                    completion(nil)
                }
            }
        }
    }
    
    /// Saves sphere anchors to the specified room
    func saveAnchors(_ anchors: [SphereAnchor], to room: RoomModel) {
        // Use a background thread to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
            do {
                // Update status
                DispatchQueue.main.async {
                    self.statusSubject.send("Saving \(anchors.count) anchors...")
                }
                
                // Create directory if it doesn't exist
                let directory = room.anchorsURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                }
                
                // Configure archiver with proper security settings
                let archiver = NSKeyedArchiver(requiringSecureCoding: true)
                let allowedClasses = [NSArray.self, SphereAnchor.self, ARAnchor.self, NSUUID.self,
                                      NSNumber.self, NSString.self, UIColor.self]
                allowedClasses.forEach { archiver.setClassName(NSStringFromClass($0), for: $0) }
                
                // Archive with custom settings
                archiver.encode(anchors, forKey: NSKeyedArchiveRootObjectKey)
                let data = archiver.encodedData
                
                // Create a temporary file and then move it for atomicity
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try data.write(to: tempURL)
                
                // Create backup before removing the existing file
                if FileManager.default.fileExists(atPath: room.anchorsURL.path) {
                    let backupURL = room.anchorsURL.deletingPathExtension().appendingPathExtension("backup.data")
                    try? FileManager.default.copyItem(at: room.anchorsURL, to: backupURL)
                    
                    // Only remove after backup is created
                    try FileManager.default.removeItem(at: room.anchorsURL)
                }
                
                // Move temp file to final destination
                try FileManager.default.moveItem(at: tempURL, to: room.anchorsURL)
                
                // Remove backup if the move succeeded
                let backupURL = room.anchorsURL.deletingPathExtension().appendingPathExtension("backup.data")
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try? FileManager.default.removeItem(at: backupURL)
                }
                
                DispatchQueue.main.async {
                    self.statusSubject.send("Anchors saved to room '\(room.name)'")
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusSubject.send("Error saving anchors: \(error.localizedDescription)")
                    print("Detailed save error: \(error)")
                }
                
                // Try to restore from backup if it exists
                let backupURL = room.anchorsURL.deletingPathExtension().appendingPathExtension("backup.data")
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    do {
                        try FileManager.default.copyItem(at: backupURL, to: room.anchorsURL)
                        try FileManager.default.removeItem(at: backupURL)
                        
                        DispatchQueue.main.async {
                            self.statusSubject.send("Restored previous anchors from backup")
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.statusSubject.send("Failed to restore anchors from backup")
                            print("Backup restore error: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    /// Gets all saved rooms
    func getAllRooms() -> [RoomModel] {
        return rooms
    }
    
    /// Updates the loading progress and associated message
    func updateLoadingProgress(_ progress: Double, message: String = "") {
        DispatchQueue.main.async {
            self.loadingProgressSubject.send(progress)
            if !message.isEmpty {
                self.statusSubject.send(message)
                Logger.shared.debug("Progress update: \(Int(progress * 100))% - \(message)",
                          destination: "Loading Progress")
            }
        }
    }
    
    /// Gets the file URL for a room (for sharing)
    func getFileURL(for room: RoomModel) -> URL? {
        // Check that both files exist
        guard FileManager.default.fileExists(atPath: room.worldMapURL.path),
              FileManager.default.fileExists(atPath: room.anchorsURL.path) else {
            statusSubject.send("Cannot share room - files missing")
            return nil
        }
        
        // For sharing, we should package both the worldMap and anchors
        let tempDir = FileManager.default.temporaryDirectory
        let packageDir = tempDir.appendingPathComponent("SharedRoom_\(room.name)_\(UUID().uuidString)", isDirectory: true)
        
        do {
            // Create the package directory
            try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true, attributes: nil)
            
            // Copy the files
            let packageWorldMapURL = packageDir.appendingPathComponent("worldMap.arworldmap")
            let packageAnchorsURL = packageDir.appendingPathComponent("anchors.data")
            
            try FileManager.default.copyItem(at: room.worldMapURL, to: packageWorldMapURL)
            try FileManager.default.copyItem(at: room.anchorsURL, to: packageAnchorsURL)
            
            // Create a readme file to explain the contents
            let readmeURL = packageDir.appendingPathComponent("README.txt")
            let readmeContent = """
            ArZhaba Room: \(room.name)
            Created: \(room.formattedDate)
            
            This package contains:
            - worldMap.arworldmap: AR World Map for spatial alignment
            - anchors.data: Sphere anchor points
            
            Import this entire folder to restore the room.
            """
            
            try readmeContent.write(to: readmeURL, atomically: true, encoding: .utf8)
            
            // Return the directory URL for sharing
            return packageDir
        } catch {
            statusSubject.send("Error preparing room for sharing: \(error.localizedDescription)")
            print("Sharing preparation error: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Loads the list of rooms from the rooms directory
    private func loadRooms() {
        guard let roomsURL = roomsURL else { return }
        
        // Create the rooms.json file URL
        let roomsListURL = roomsURL.appendingPathComponent("rooms.json")
        
        // Load rooms from the JSON file if it exists
        if FileManager.default.fileExists(atPath: roomsListURL.path) {
            do {
                let data = try Data(contentsOf: roomsListURL)
                let decoder = JSONDecoder()
                rooms = try decoder.decode([RoomModel].self, from: data)
                roomsSubject.send(rooms)
            } catch {
                statusSubject.send("Error loading rooms list: \(error.localizedDescription)")
            }
        }
    }
    
    /// Saves the list of rooms to the rooms directory
    private func saveRoomsList() {
        guard let roomsURL = roomsURL else { return }
        
        // Create the rooms.json file URL
        let roomsListURL = roomsURL.appendingPathComponent("rooms.json")
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(rooms)
            try data.write(to: roomsListURL, options: [.atomic])
        } catch {
            statusSubject.send("Error saving rooms list: \(error.localizedDescription)")
        }
    }
} 