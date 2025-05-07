import Foundation
import ARKit
import Combine

class RoomService {
    // MARK: - Singleton
    static let shared = RoomService()
    
    // MARK: - Properties
    private let roomsURL: URL?
    private var rooms: [RoomModel] = []
    
    // Publishers
    private let roomsSubject = CurrentValueSubject<[RoomModel], Never>([])
    private let statusSubject = PassthroughSubject<String, Never>()
    
    var roomsPublisher: AnyPublisher<[RoomModel], Never> {
        roomsSubject.eraseToAnyPublisher()
    }
    
    var statusPublisher: AnyPublisher<String, Never> {
        statusSubject.eraseToAnyPublisher()
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
                } catch {
                    print("Error creating rooms directory: \(error)")
                }
            }
        } else {
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
        // Remove all files in the room's directory
        let roomDirectory = room.worldMapURL.deletingLastPathComponent()
        
        do {
            try FileManager.default.removeItem(at: roomDirectory)
            
            // Remove from rooms collection
            rooms.removeAll { $0.id == room.id }
            roomsSubject.send(rooms)
            
            // Save rooms list
            saveRoomsList()
            
            statusSubject.send("Room '\(room.name)' deleted successfully")
        } catch {
            statusSubject.send("Error deleting room: \(error.localizedDescription)")
        }
    }
    
    /// Loads the specified AR world map
    func loadWorldMap(from room: RoomModel) -> ARWorldMap? {
        do {
            let data = try Data(contentsOf: room.worldMapURL)
            let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
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
                
                // Use memory-efficient archiving
                let data = try NSKeyedArchiver.archivedData(withRootObject: optimizedWorldMap, requiringSecureCoding: true)
                try data.write(to: room.worldMapURL, options: [.atomic])
                
                DispatchQueue.main.async {
                    self.statusSubject.send("World map saved to room '\(room.name)'")
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusSubject.send("Error saving world map: \(error.localizedDescription)")
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
        
        // Keep only essential anchors
        // Remove raw image anchors which consume a lot of memory
        let essentialAnchors = optimizedMap.anchors.filter { anchor in
            // Keep only sphere anchors and plane anchors
            return (anchor is SphereAnchor) || (anchor is ARPlaneAnchor)
        }
        
        optimizedMap.anchors = essentialAnchors
        return optimizedMap
    }
    
    /// Loads sphere anchors from the specified room
    func loadAnchors(from room: RoomModel) -> [SphereAnchor]? {
        // Use async loading with a completion handler when needed
        return loadAnchorsSync(from: room)
    }
    
    /// Synchronously loads anchors - internal implementation
    private func loadAnchorsSync(from room: RoomModel) -> [SphereAnchor]? {
        do {
            let data = try Data(contentsOf: room.anchorsURL)
            
            // Set memory limits for unarchiving to prevent crashes
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.decodingFailurePolicy = .setErrorAndReturn
            
            guard let anchors = unarchiver.decodeObject(of: [NSArray.self, SphereAnchor.self], forKey: NSKeyedArchiveRootObjectKey) as? [SphereAnchor] else {
                statusSubject.send("Error decoding anchors: invalid format")
                return nil
            }
            
            return anchors
        } catch {
            statusSubject.send("Error loading anchors: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Saves sphere anchors to the specified room
    func saveAnchors(_ anchors: [SphereAnchor], to room: RoomModel) {
        // Use a background thread to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
            do {
                // Use memory-efficient archiving
                let data = try NSKeyedArchiver.archivedData(withRootObject: anchors, requiringSecureCoding: true)
                try data.write(to: room.anchorsURL, options: [.atomic])
                
                DispatchQueue.main.async {
                    self.statusSubject.send("Anchors saved to room '\(room.name)'")
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusSubject.send("Error saving anchors: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Gets all saved rooms
    func getAllRooms() -> [RoomModel] {
        return rooms
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