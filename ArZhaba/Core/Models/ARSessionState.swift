import Foundation

/// Represents the current state of the AR session
enum ARSessionState {
    case idle       // Not recording or viewing, just tracking
    case recording  // Recording anchors in current session
    case viewing    // Viewing anchors from a loaded room
    case loading    // Loading a room (transitional state)
} 