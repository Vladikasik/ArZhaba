import Foundation
import ARKit
import Combine
import RealityKit
import UIKit

/// Service for managing AR anchors and AR session
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
    private var pendingAnchors: [SphereAnchor]? // Anchors waiting to be added after successful localization
    
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
    private var isLocalized = false
    
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
        Logger.shared.info("ARAnchorService initialized")
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
            // Use different mesh detail levels for different session states
            if sessionState == .recording {
                configuration.sceneReconstruction = .mesh
            } else {
                configuration.sceneReconstruction = .mesh
            }
            
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
        Logger.shared.info("Starting to load room: \(room.name)", destination: "Room Loading")
        
        // Ensure we have a clean session state
        if isSessionActive {
            arSession?.pause()
            isSessionActive = false
            Logger.shared.debug("Paused existing AR session", destination: "Room Loading")
        }
        
        // Make sure we have a session
        if arSession == nil {
            arSession = ARSession()
            arSession?.delegate = self
            Logger.shared.debug("Created new AR session", destination: "Room Loading")
        }
        
        // Update state to loading
        sessionState = .loading
        stateSubject.send(sessionState)
        statusSubject.send("Loading room: \(room.name)...")
        
        // Reset localization flag
        isLocalized = false
        
        // Initialize loading progress
        RoomService.shared.updateLoadingProgress(0.1, message: "Starting to load room...")
        
        // Verify the room directory exists
        let roomDir = room.worldMapURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: roomDir.path) {
            let errorMsg = "Room directory not found: \(roomDir.path)"
            Logger.shared.error(errorMsg, destination: "Room Loading")
            statusSubject.send(errorMsg)
            sessionState = .idle
            stateSubject.send(sessionState)
            return false
        }
        
        // Verify both required files exist
        if !FileManager.default.fileExists(atPath: room.worldMapURL.path) {
            let errorMsg = "World map file not found at: \(room.worldMapURL.path)"
            Logger.shared.error(errorMsg, destination: "Room Loading")
            statusSubject.send(errorMsg)
            sessionState = .idle
            stateSubject.send(sessionState)
            return false
        }
        
        // Try to load the world map with better error handling
        var worldMap: ARWorldMap?
        do {
            // Load data with better error handling
            statusSubject.send("Loading world map....")
            RoomService.shared.updateLoadingProgress(0.3, message: "Loading world map data...")
            
            let data = try Data(contentsOf: room.worldMapURL)
            Logger.shared.info("Successfully loaded \(data.count) bytes of world map data", destination: "Room Loading")
            
            // Update progress
            RoomService.shared.updateLoadingProgress(0.4, message: "Parsing world map data...")
            
            // Try multiple approaches to decode the world map
            do {
                // First try with secure coding
                worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
                Logger.shared.debug("World map decoded with secure coding", destination: "Room Loading")
            } catch {
                Logger.shared.warning("Failed to unarchive with secure coding, trying alternative method: \(error)", destination: "Room Loading")
                // If secure coding fails, try alternative approach
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.requiresSecureCoding = false
                worldMap = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? ARWorldMap
                Logger.shared.debug("World map decoded with alternative method", destination: "Room Loading")
            }
            
        } catch {
            sessionState = .idle
            stateSubject.send(sessionState)
            let errorMsg = "Failed to load world map: \(error.localizedDescription)"
            Logger.shared.error(errorMsg, source: "WorldMap Loading", destination: "Room Loading")
            statusSubject.send(errorMsg)
            RoomService.shared.updateLoadingProgress(0.0, message: "Failed to load world map")
            return false
        }
        
        guard let validWorldMap = worldMap else {
            sessionState = .idle
            stateSubject.send(sessionState)
            let errorMsg = "World map data is corrupted for room: \(room.name)"
            Logger.shared.error(errorMsg, destination: "Room Loading")
            statusSubject.send(errorMsg)
            RoomService.shared.updateLoadingProgress(0.0, message: "World map data is corrupted")
            return false
        }
        
        // Update progress
        RoomService.shared.updateLoadingProgress(0.5, message: "World map loaded, preparing environment...")
        
        // Clear existing anchors
        clearAllSphereAnchors()
        Logger.shared.debug("Cleared all existing sphere anchors", destination: "Room Loading")
        
        // First start the AR session with the world map (without anchors)
        Logger.shared.info("Starting AR session with world map (no anchors yet)", destination: "Room Loading")
        
        // Start loading process by initializing the AR environment
        initializeAREnvironment(room, withWorldMap: validWorldMap)
        
        // Load anchors from the room asynchronously but don't add them to the scene yet
        Logger.shared.info("Loading anchors asynchronously (will add after localization)", destination: "Room Loading")
        statusSubject.send("Loading anchors asynchronously...")
        RoomService.shared.updateLoadingProgress(0.6, message: "Loading anchors...")
        
        RoomService.shared.loadAnchors(from: room) { [weak self] loadedAnchors in
            guard let self = self else {
                Logger.shared.error("Self reference lost during anchor loading", destination: "Room Loading")
                return
            }
            
            // Store the anchors but don't add them to the scene yet
            if let anchors = loadedAnchors, !anchors.isEmpty {
                self.statusSubject.send("Loaded \(anchors.count) anchors")
                Logger.shared.info("Successfully loaded \(anchors.count) anchors, storing for later placement", destination: "Room Loading")
                
                // Store the anchors to add them after localization
                self.pendingAnchors = anchors
                
                // Update progress
                RoomService.shared.updateLoadingProgress(0.8, message: "Anchors loaded, waiting for localization...")
            } else if let anchors = loadedAnchors, anchors.isEmpty {
                // Successfully loaded but no anchors
                self.statusSubject.send("No anchors found in this room. Continuing with empty scene.")
                Logger.shared.info("No anchors found in this room", destination: "Room Loading")
                self.pendingAnchors = []
                RoomService.shared.updateLoadingProgress(0.8, message: "No anchors found, waiting for localization...")
            } else {
                // Failed to load anchors, but we can still try to load the room without them
                self.statusSubject.send("Warning: Could not load anchors, continuing with empty room")
                Logger.shared.warning("Failed to load anchors, continuing with empty room", destination: "Room Loading") 
                self.pendingAnchors = []
                RoomService.shared.updateLoadingProgress(0.7, message: "Warning: Failed to load anchors. Waiting for localization...")
            }
        }
        
        // Return true to indicate that loading has started (though it may not complete successfully)
        return true
    }
    
    /// Initializes the AR environment with a world map but without anchors
    private func initializeAREnvironment(_ room: RoomModel, withWorldMap worldMap: ARWorldMap) {
        Logger.shared.info("Initializing AR environment for room: \(room.name)", destination: "Room Loading")
        
        // Create configuration with the world map
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.initialWorldMap = worldMap
        
        // Enable basic features (keep it simpler for viewing mode)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            Logger.shared.debug("Enabled mesh reconstruction", destination: "Room Loading")
        }
        
        // Be more explicit about run options
        let runOptions: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction]
        
        // Make sure session gets set up properly
        arSession?.pause()
        
        // Add a small delay to ensure pause completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else {
                Logger.shared.error("Self reference lost when starting AR session", destination: "Room Loading")
                return
            }
            
            // Run session with this configuration
            self.arSession?.run(configuration, options: runOptions)
            self.isSessionActive = true
            
            // Keep loading state until localization completes
            // Don't update state yet - wait for localization
            self.currentRoom = room
            self.currentRoomSubject.send(self.currentRoom)
            
            self.statusSubject.send("Room initializing: \(room.name). Move the device around to relocalize...")
            Logger.shared.info("AR session started, waiting for localization", destination: "Room Loading")
        }
    }
    
    /// Adds the pending anchors to the scene after localization is complete
    private func addPendingAnchorsToScene() {
        guard let anchors = pendingAnchors, isLocalized else {
            Logger.shared.warning("Cannot add pending anchors - either no anchors available or not localized",
                         destination: "Anchor Placement")
            return
        }
        
        Logger.shared.info("Adding \(anchors.count) pending anchors to scene after localization",
                  destination: "Anchor Placement")
        
        if anchors.isEmpty {
            // If we have no anchors, just update the state
            sphereAnchors = []
            anchorsSubject.send(sphereAnchors)
            Logger.shared.info("No anchors to add, scene is empty", destination: "Anchor Placement")
        } else {
            // Add anchors to the session
            for anchor in anchors {
                arSession?.add(anchor: anchor)
            }
            
            // Update our collection
            sphereAnchors = anchors
            anchorsSubject.send(sphereAnchors)
            Logger.shared.info("Successfully added \(anchors.count) anchors to AR scene", 
                      destination: "Anchor Placement")
        }
        
        // Clear pending anchors since they've been added
        pendingAnchors = nil
        
        // Update status
        statusSubject.send("Added \(anchors.count) anchors to the scene")
        RoomService.shared.updateLoadingProgress(1.0, message: "Room fully loaded with \(anchors.count) anchors")
        
        // Short delay before hiding loading indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            RoomService.shared.updateLoadingProgress(1.0, message: "")
        }
    }
    
    /// Returns to idle state, clearing the scene
    func returnToIdle() {
        // Pause the session
        arSession?.pause()
        
        // Wait a moment for pause to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Clear all anchors
            self.clearAllSphereAnchors()
            
            // Update state
            self.isSessionActive = false
            self.sessionState = .idle
            self.currentRoom = nil
            self.stateSubject.send(self.sessionState)
            self.currentRoomSubject.send(self.currentRoom)
            
            self.statusSubject.send("Returned to idle state")
        }
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
    
    func session(_ renderer: ARSession, didUpdate frame: ARFrame) {
        // Update tracking state and relocalization progress
        if sessionState == .loading || sessionState == .viewing {
            let currentMappingStatus = frame.worldMappingStatus
            var progress: Double = 0.0
            
            switch currentMappingStatus {
            case .notAvailable:
                progress = 0.1
                RoomService.shared.updateLoadingProgress(progress, message: "Starting relocalization...")
            case .limited:
                // Calculate progress based on tracking state
                if case .limited(let reason) = frame.camera.trackingState {
                    switch reason {
                    case .initializing:
                        progress = 0.3
                        RoomService.shared.updateLoadingProgress(progress, message: "Initializing tracking...")
                    case .relocalizing:
                        // Gradual increase based on time - get current progress and increment it
                        progress = min(0.7, 0.5 + Double(Date().timeIntervalSince1970).truncatingRemainder(dividingBy: 0.1))
                        RoomService.shared.updateLoadingProgress(progress, message: "Relocalizing in environment...")
                    case .excessiveMotion:
                        RoomService.shared.updateLoadingProgress(0.4, message: "Too much motion, please hold still...")
                    case .insufficientFeatures:
                        RoomService.shared.updateLoadingProgress(0.4, message: "Looking for visual features...")
                    @unknown default:
                        progress = 0.5
                        RoomService.shared.updateLoadingProgress(progress, message: "Processing environment...")
                    }
                } else {
                    progress = 0.8
                    RoomService.shared.updateLoadingProgress(progress, message: "Connecting to anchors...")
                }
            case .extending:
                progress = 0.9
                RoomService.shared.updateLoadingProgress(progress, message: "Extending map...")
            case .mapped:
                if sessionState == .loading {
                    // Successfully relocalized, mark as localized and change state to viewing
                    isLocalized = true
                    sessionState = .viewing
                    stateSubject.send(sessionState)
                    Logger.shared.info("Successfully relocalized to environment, adding anchors", 
                              destination: "Room Loading")
                    RoomService.shared.updateLoadingProgress(1.0, message: "Successfully relocalized!")
                    
                    // Now add the pending anchors if available
                    addPendingAnchorsToScene()
                    
                    // Give a short delay to show the success message before hiding the loading screen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        RoomService.shared.updateLoadingProgress(1.0, message: "")
                    }
                }
            @unknown default:
                progress = 0.5
                RoomService.shared.updateLoadingProgress(progress, message: "Processing...")
            }
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        if sessionState == .loading || sessionState == .viewing {
            switch camera.trackingState {
            case .notAvailable:
                Logger.shared.warning("Tracking not available", destination: "AR Session")
                statusSubject.send("Tracking not available")
                RoomService.shared.updateLoadingProgress(0.2, message: "Tracking not available")
                
            case .limited(let reason):
                switch reason {
                case .initializing:
                    Logger.shared.info("Initializing AR session", destination: "AR Session")
                    statusSubject.send("Initializing AR session")
                    RoomService.shared.updateLoadingProgress(0.3, message: "Initializing AR session...")
                    
                case .relocalizing:
                    Logger.shared.info("Relocalizing - please move device slowly", destination: "AR Session")
                    statusSubject.send("Relocalizing - please move device slowly around the space")
                    RoomService.shared.updateLoadingProgress(0.5, message: "Relocalizing - move slowly around...")
                    
                case .excessiveMotion:
                    Logger.shared.warning("Too much motion detected", destination: "AR Session")
                    statusSubject.send("Too much motion - please slow down")
                    RoomService.shared.updateLoadingProgress(0.4, message: "Too much motion - please slow down")
                    
                case .insufficientFeatures:
                    Logger.shared.warning("Insufficient visual features", destination: "AR Session")
                    statusSubject.send("Not enough visual features - try to point at detailed surfaces")
                    RoomService.shared.updateLoadingProgress(0.4, message: "Not enough visual features")
                    
                @unknown default:
                    Logger.shared.warning("Unknown limited tracking reason", destination: "AR Session")
                    statusSubject.send("Limited tracking quality")
                    RoomService.shared.updateLoadingProgress(0.5, message: "Limited tracking quality")
                }
                
            case .normal:
                if sessionState == .loading {
                    // Successfully relocalized to the environment
                    isLocalized = true
                    sessionState = .viewing
                    stateSubject.send(sessionState)
                    Logger.shared.info("Normal tracking achieved, session relocalized", destination: "AR Session")
                    statusSubject.send("Successfully relocalized to room environment")
                    RoomService.shared.updateLoadingProgress(1.0, message: "Successfully relocalized!")
                    
                    // Now add the pending anchors if available
                    addPendingAnchorsToScene()
                    
                    // Give a short delay to show the success message before hiding loading screen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        RoomService.shared.updateLoadingProgress(1.0, message: "")
                    }
                } else if sessionState == .viewing {
                    Logger.shared.debug("Normal tracking maintained in viewing mode", destination: "AR Session")
                    statusSubject.send("Normal tracking - room loaded")
                }
            }
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Handle actual SphereAnchors
        let newSphereAnchors = anchors.compactMap { $0 as? SphereAnchor }
        
        if !newSphereAnchors.isEmpty {
            // Add new anchors that aren't already in our collection
            var added = false
            for anchor in newSphereAnchors {
                if !sphereAnchors.contains(where: { $0.identifier == anchor.identifier }) {
                    sphereAnchors.append(anchor)
                    added = true
                }
            }
            
            // Only notify subscribers if we actually added something
            if added {
                anchorsSubject.send(sphereAnchors)
            }
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
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        statusSubject.send("Session failed: \(errorMessage)")
        
        // Handle specific errors
        if let arError = error as? ARError {
            switch arError.code {
            case .worldTrackingFailed:
                RoomService.shared.updateLoadingProgress(0.3, message: "World tracking failed - resetting")
                
                // Reset the session after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self else { return }
                    
                    if self.sessionState == .loading || self.sessionState == .viewing {
                        // Try to restart the session with reset tracking
                        if let configuration = self.arSession?.configuration {
                            self.arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                            self.statusSubject.send("Resetting AR session...")
                            RoomService.shared.updateLoadingProgress(0.1, message: "Resetting AR session...")
                        }
                    }
                }
                
            default:
                RoomService.shared.updateLoadingProgress(0.2, message: "AR Session error: \(arError.code.rawValue)")
            }
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        statusSubject.send("AR Session interrupted")
        if sessionState == .loading || sessionState == .viewing {
            RoomService.shared.updateLoadingProgress(0.3, message: "AR Session interrupted")
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        statusSubject.send("AR Session resumed")
        if sessionState == .loading || sessionState == .viewing {
            // Try to relocalize again
            RoomService.shared.updateLoadingProgress(0.4, message: "Resuming... Move around slowly to relocalize")
        }
    }
} 
