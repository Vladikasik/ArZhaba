import Foundation
import ARKit
import Combine
import RealityKit
import UIKit

/// Represents the current state of the AR session
enum ARSessionState {
    case idle       // Not recording or viewing, just tracking
    case recording  // Recording anchors in current session
    case viewing    // Viewing anchors from a loaded room
}

class ARAnchorService: NSObject, ARSessionDelegate {
    // MARK: - Singleton
    static let shared = ARAnchorService()
    
    // MARK: - Properties
    private var arSession: ARSession?
    
    // Session state
    private(set) var sessionState: ARSessionState = .idle
    private var currentRoom: RoomModel?
    
    // Sphere anchors collection
    private var sphereAnchors: [SphereAnchor] = []
    
    // Publishers
    private let anchorsSubject = CurrentValueSubject<[SphereAnchor], Never>([])
    private let statusSubject = PassthroughSubject<String, Never>()
    private let stateSubject = CurrentValueSubject<ARSessionState, Never>(.idle)
    private let currentRoomSubject = CurrentValueSubject<RoomModel?, Never>(nil)
    
    // World map save throttling
    private var lastWorldMapSaveTime: Date = Date(timeIntervalSince1970: 0)
    private let worldMapSaveInterval: TimeInterval = 5.0 // Save at most every 5 seconds
    
    // Track if session is active to prevent redundant calls
    private var isSessionActive = false
    
    var anchorsPublisher: AnyPublisher<[SphereAnchor], Never> {
        anchorsSubject.eraseToAnyPublisher()
    }
    
    var statusPublisher: AnyPublisher<String, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    var statePublisher: AnyPublisher<ARSessionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    var currentRoomPublisher: AnyPublisher<RoomModel?, Never> {
        currentRoomSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Sets up a new AR session with a new configuration
    func setupARSession() -> ARSession {
        // Create a new ARSession if needed
        if arSession == nil {
            arSession = ARSession()
            arSession?.delegate = self
        }
        
        // Return existing session if already active to avoid "already-enabled session" errors
        guard !isSessionActive else {
            return arSession!
        }
        
        // Create a configuration suitable for our use case
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable plane detection for better tracking
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Enable LiDAR features if available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            // Only use depth when needed to save memory
            if sessionState == .recording {
                configuration.frameSemantics.insert(.smoothedSceneDepth)
            }
        }
        
        // Start the session with this configuration
        arSession?.run(configuration)
        isSessionActive = true
        
        // Update status
        statusSubject.send("AR session initialized")
        
        return arSession!
    }
    
    /// Starts recording a new room
    func startRecording(roomName: String) -> Bool {
        // Check if we're already recording
        if sessionState == .recording {
            statusSubject.send("Already recording")
            return false
        }
        
        // Create a new room
        guard let room = RoomService.shared.createRoom(name: roomName) else {
            statusSubject.send("Failed to create room")
            return false
        }
        
        // Update state
        sessionState = .recording
        currentRoom = room
        stateSubject.send(sessionState)
        currentRoomSubject.send(currentRoom)
        
        // Clear all existing anchors
        clearAllSphereAnchors()
        
        // Ensure we have a valid session
        if arSession == nil {
            arSession = ARSession()
            arSession?.delegate = self
        }
        
        // Restart session with recording configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }
        
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionActive = true
        
        statusSubject.send("Started recording in room: \(roomName)")
        return true
    }
    
    /// Stops recording and saves the current session
    func stopRecording() -> Bool {
        // Check if we're currently recording
        guard sessionState == .recording, let room = currentRoom else {
            statusSubject.send("Not currently recording")
            return false
        }
        
        // Save the current world map to the room
        saveCurrentWorldMapToRoom(room)
        
        // Save anchors to the room
        RoomService.shared.saveAnchors(sphereAnchors, to: room)
        
        // Update state to idle
        sessionState = .idle
        stateSubject.send(sessionState)
        
        // Pause session to save power and memory
        arSession?.pause()
        isSessionActive = false
        
        // Clear all anchors from the scene
        clearAllSphereAnchors()
        
        statusSubject.send("Recording stopped and saved")
        return true
    }
    
    /// Loads a room for viewing
    func loadRoom(_ room: RoomModel) -> Bool {
        // Make sure we have a session
        if arSession == nil {
            arSession = ARSession()
            arSession?.delegate = self
        }
        
        // Try to load the world map
        guard let worldMap = RoomService.shared.loadWorldMap(from: room) else {
            statusSubject.send("Failed to load world map from room: \(room.name)")
            return false
        }
        
        // Clear existing anchors
        clearAllSphereAnchors()
        
        // Load anchors from the room
        if let loadedAnchors = RoomService.shared.loadAnchors(from: room) {
            // Store anchors but don't add them to the session yet - they'll be added when the world map is localized
            sphereAnchors = loadedAnchors
            anchorsSubject.send(sphereAnchors)
        }
        
        // Create configuration with the world map
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.initialWorldMap = worldMap
        
        // Enable LiDAR features if available but be more conservative
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            // Don't use depth sensing to save memory
        }
        
        // Run session with this configuration
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionActive = true
        
        // Update state
        sessionState = .viewing
        currentRoom = room
        stateSubject.send(sessionState)
        currentRoomSubject.send(currentRoom)
        
        statusSubject.send("Loading room: \(room.name). Please move the device to localize...")
        return true
    }
    
    /// Returns to idle state, clearing the scene
    func returnToIdle() {
        // Pause the session to save resources
        arSession?.pause()
        isSessionActive = false
        
        // Clear all anchors
        clearAllSphereAnchors()
        
        // Update state
        sessionState = .idle
        currentRoom = nil
        stateSubject.send(sessionState)
        currentRoomSubject.send(currentRoom)
        
        statusSubject.send("Returned to idle state")
    }
    
    /// Adds a sphere anchor at the specified position
    func addSphereAnchor(at transform: simd_float4x4, radius: Float = 0.025, color: UIColor = .red) {
        // Only allow adding anchors in recording mode
        guard sessionState == .recording else {
            statusSubject.send("Can only add anchors in recording mode")
            return
        }
        
        let anchor = SphereAnchor(transform: transform, radius: radius, color: color)
        
        // Add anchor to AR session
        arSession?.add(anchor: anchor)
        
        // Add to local collection
        sphereAnchors.append(anchor)
        anchorsSubject.send(sphereAnchors)
        
        // Notify of success
        statusSubject.send("Added sphere anchor")
        
        // Save the world map periodically with throttling to avoid memory pressure
        if Date().timeIntervalSince(lastWorldMapSaveTime) >= worldMapSaveInterval,
           let room = currentRoom {
            saveCurrentWorldMapToRoom(room)
            lastWorldMapSaveTime = Date()
        }
    }
    
    /// Removes a sphere anchor
    func removeSphereAnchor(_ anchor: SphereAnchor) {
        // Only allow removing anchors in recording mode
        guard sessionState == .recording else {
            statusSubject.send("Can only remove anchors in recording mode")
            return
        }
        
        // Remove from AR session
        arSession?.remove(anchor: anchor)
        
        // Remove from local collection
        sphereAnchors.removeAll { $0.identifier == anchor.identifier }
        anchorsSubject.send(sphereAnchors)
        
        // Save the world map with throttling to reduce memory pressure
        if Date().timeIntervalSince(lastWorldMapSaveTime) >= worldMapSaveInterval,
           let room = currentRoom {
            saveCurrentWorldMapToRoom(room)
            lastWorldMapSaveTime = Date()
        }
    }
    
    /// Clears all sphere anchors
    func clearAllSphereAnchors() {
        // Remove all anchors from AR session
        for anchor in sphereAnchors {
            arSession?.remove(anchor: anchor)
        }
        
        // Clear local collection
        sphereAnchors.removeAll()
        anchorsSubject.send(sphereAnchors)
    }
    
    // MARK: - Private Methods
    
    /// Saves the current world map to the specified room
    private func saveCurrentWorldMapToRoom(_ room: RoomModel) {
        // Make sure we have an active session before trying to save the world map
        guard isSessionActive else {
            statusSubject.send("Cannot save world map - AR session not active")
            return
        }
        
        // Use a low priority queue to reduce UI impact
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            self.arSession?.getCurrentWorldMap { [weak self] worldMap, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.statusSubject.send("Error getting world map: \(error.localizedDescription)")
                    return
                }
                
                guard let map = worldMap else {
                    self.statusSubject.send("No world map available")
                    return
                }
                
                // Save to the room
                RoomService.shared.saveWorldMap(map, to: room)
                
                // Update timestamp
                self.lastWorldMapSaveTime = Date()
            }
        }
    }
    
    // MARK: - ARSessionDelegate Methods
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Track only sphere anchors to save memory
        let newSphereAnchors = anchors.compactMap { $0 as? SphereAnchor }
        
        if !newSphereAnchors.isEmpty {
            // Only add if not already in our collection
            for anchor in newSphereAnchors {
                if !sphereAnchors.contains(where: { $0.identifier == anchor.identifier }) {
                    sphereAnchors.append(anchor)
                }
            }
            
            // Notify subscribers of the change
            anchorsSubject.send(sphereAnchors)
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // Process removed anchors
        let removedIds = anchors.map { $0.identifier }
        let hadSpheres = !sphereAnchors.filter { removedIds.contains($0.identifier) }.isEmpty
        
        sphereAnchors.removeAll { removedIds.contains($0.identifier) }
        
        if hadSpheres {
            anchorsSubject.send(sphereAnchors)
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        // If we're in viewing mode and tracking becomes normal,
        // add all the sphere anchors to the session
        if sessionState == .viewing && camera.trackingState == .normal {
            for anchor in sphereAnchors {
                if !session.currentFrame!.anchors.contains(where: { $0.identifier == anchor.identifier }) {
                    session.add(anchor: anchor)
                }
            }
        }
        
        // Update status message
        switch camera.trackingState {
        case .normal:
            switch sessionState {
            case .idle:
                statusSubject.send("Ready to record or load a room")
            case .recording:
                statusSubject.send("Recording - Add sphere anchors by tapping")
            case .viewing:
                statusSubject.send("Viewing room - Spheres will appear when anchors are found")
            }
        case .limited(let reason):
            var message = "Limited tracking: "
            switch reason {
            case .excessiveMotion:
                message += "Move more slowly"
            case .insufficientFeatures:
                message += "Not enough features in view"
            case .initializing:
                message += "Initializing..."
            case .relocalizing:
                message += "Relocalizing..."
            @unknown default:
                message += "Unknown limitation"
            }
            statusSubject.send(message)
        case .notAvailable:
            statusSubject.send("Tracking not available")
        @unknown default:
            statusSubject.send("Unknown tracking state")
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        statusSubject.send("AR session failed: \(error.localizedDescription)")
        isSessionActive = false
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        statusSubject.send("AR session was interrupted")
        isSessionActive = false
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        statusSubject.send("AR session interruption ended")
        isSessionActive = true
        
        // If we're in viewing mode, try to relocalize
        if sessionState == .viewing, let room = currentRoom {
            loadRoom(room)
        }
    }
    
    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {
        // This would be used for multi-user experiences, but we're not implementing that yet
    }
} 