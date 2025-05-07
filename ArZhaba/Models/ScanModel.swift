import Foundation
import ModelIO

struct ScanModel: Identifiable, Equatable {
    let id: UUID
    let name: String
    let fileURL: URL
    let creationDate: Date
    let fileExtension: String
    let fileSize: Int64
    
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