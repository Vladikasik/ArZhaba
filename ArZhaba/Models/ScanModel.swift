import Foundation
import ModelIO

struct ScanModel: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let fileURL: URL
    let creationDate: Date
    let fileExtension: String
    let fileSize: Int64
    
    // Custom CodingKeys to handle URL encoding
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fileURLString = "fileURL"
        case creationDate
        case fileExtension
        case fileSize
    }
    
    // Custom encode to handle URL
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(fileURL.path, forKey: .fileURLString)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(fileExtension, forKey: .fileExtension)
        try container.encode(fileSize, forKey: .fileSize)
    }
    
    // Custom init decoder to handle URL
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let path = try container.decode(String.self, forKey: .fileURLString)
        fileURL = URL(fileURLWithPath: path)
        creationDate = try container.decode(Date.self, forKey: .creationDate)
        fileExtension = try container.decode(String.self, forKey: .fileExtension)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
    }
    
    // Regular initializer
    init(id: UUID, name: String, fileURL: URL, creationDate: Date, fileExtension: String, fileSize: Int64) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.creationDate = creationDate
        self.fileExtension = fileExtension
        self.fileSize = fileSize
    }
    
    var displayName: String {
        return name
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    static func == (lhs: ScanModel, rhs: ScanModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func from(url: URL) -> ScanModel? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            let creationDate = resourceValues.creationDate ?? Date()
            let fileSize = resourceValues.fileSize ?? 0
            
            let filename = url.deletingPathExtension().lastPathComponent
            
            return ScanModel(
                id: UUID(),
                name: filename,
                fileURL: url,
                creationDate: creationDate,
                fileExtension: url.pathExtension,
                fileSize: Int64(fileSize)
            )
        } catch {
            print("Error getting file attributes: \(error)")
            return nil
        }
    }
} 