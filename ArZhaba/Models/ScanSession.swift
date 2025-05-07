import Foundation
import ARKit
import RealityKit

enum ScanningState: Equatable {
    case notStarted
    case initializing
    case scanning
    case paused
    case completed
    case failed(Error)
    
    static func == (lhs: ScanningState, rhs: ScanningState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted),
             (.initializing, .initializing),
             (.scanning, .scanning),
             (.paused, .paused),
             (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

struct ScanSession {
    let id: UUID
    var state: ScanningState
    var startTime: Date?
    var endTime: Date?
    var meshAnchorsCount: Int
    var scanProgress: Float
    var meshAnchors: [ARMeshAnchor]
    var statusMessage: String
    
    var duration: TimeInterval {
        guard let start = startTime else { return 0 }
        let end = endTime ?? Date()
        return end.timeIntervalSince(start)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    static func new() -> ScanSession {
        return ScanSession(
            id: UUID(),
            state: .notStarted,
            startTime: nil,
            endTime: nil,
            meshAnchorsCount: 0,
            scanProgress: 0.0,
            meshAnchors: [],
            statusMessage: "Ready to scan"
        )
    }
    
    func with(
        state: ScanningState? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        meshAnchorsCount: Int? = nil,
        scanProgress: Float? = nil,
        meshAnchors: [ARMeshAnchor]? = nil,
        statusMessage: String? = nil
    ) -> ScanSession {
        return ScanSession(
            id: self.id,
            state: state ?? self.state,
            startTime: startTime ?? self.startTime,
            endTime: endTime ?? self.endTime,
            meshAnchorsCount: meshAnchorsCount ?? self.meshAnchorsCount,
            scanProgress: scanProgress ?? self.scanProgress,
            meshAnchors: meshAnchors ?? self.meshAnchors,
            statusMessage: statusMessage ?? self.statusMessage
        )
    }
} 