import Foundation
import ARKit

class RoomModel: Codable, Identifiable {
    let id: UUID
    let name: String
    var creationDate: Date
    
    // URLs for the stored data
    private var worldMapURLString: String
    private var anchorsURLString: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, creationDate, worldMapURLString, anchorsURLString
    }
    
    var worldMapURL: URL {
        URL(fileURLWithPath: worldMapURLString)
    }
    
    var anchorsURL: URL {
        URL(fileURLWithPath: anchorsURLString)
    }
    
    init(id: UUID = UUID(), name: String, worldMapURL: URL, anchorsURL: URL) {
        self.id = id
        self.name = name
        self.creationDate = Date()
        self.worldMapURLString = worldMapURL.path
        self.anchorsURLString = anchorsURL.path
    }
    
    // Convenience method to create file URLs for a new room
    static func createFileURLs(for roomName: String) -> (worldMapURL: URL, anchorsURL: URL)? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let roomsDirectory = documentsDirectory.appendingPathComponent("Rooms", isDirectory: true)
        
        // Create rooms directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: roomsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: roomsDirectory, withIntermediateDirectories: true)
            } catch {
                print("Error creating rooms directory: \(error)")
                return nil
            }
        }
        
        let roomDirectory = roomsDirectory.appendingPathComponent(roomName, isDirectory: true)
        
        // Create room directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: roomDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: roomDirectory, withIntermediateDirectories: true)
            } catch {
                print("Error creating room directory: \(error)")
                return nil
            }
        }
        
        let worldMapURL = roomDirectory.appendingPathComponent("worldMap.arworldmap")
        let anchorsURL = roomDirectory.appendingPathComponent("anchors.data")
        
        return (worldMapURL, anchorsURL)
    }
    
    // Format the date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
} 