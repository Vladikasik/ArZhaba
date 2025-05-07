import Foundation
import ARKit
import Combine
import RealityKit
import UIKit

class ARAnchorService: NSObject, ARSessionDelegate {
    // MARK: - Singleton
    static let shared = ARAnchorService()
    
    // MARK: - Properties
    private var arSession: ARSession?
    private var worldMapURL: URL? {
        // Use the app's document directory to store the ARWorldMap
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documentsDirectory.appendingPathComponent("worldMap.arworldmap")
    }
    
    private var anchorsURL: URL? {
        // Store anchors in the app's documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documentsDirectory.appendingPathComponent("anchors.data")
    }
    
    private var sphereAnchors: [SphereAnchor] = []
    
    // Publishers
    private let anchorsSubject = CurrentValueSubject<[SphereAnchor], Never>([])
    private let statusSubject = PassthroughSubject<String, Never>()
    
    var anchorsPublisher: AnyPublisher<[SphereAnchor], Never> {
        anchorsSubject.eraseToAnyPublisher()
    }
    
    var statusPublisher: AnyPublisher<String, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        loadAnchors()
    }
    
    // MARK: - Public Methods
    
    /// Sets up a new AR session with a new configuration
    func setupARSession() -> ARSession {
        // Create a new ARSession
        let session = ARSession()
        arSession = session
        session.delegate = self
        
        // Create a configuration suitable for our use case
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable plane detection for better tracking
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Enable LiDAR features if available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }
        
        // Start the session with this configuration
        session.run(configuration)
        
        // Update status
        statusSubject.send("AR session initialized")
        
        return session
    }
    
    /// Sets an existing AR session to be used by the anchor service
    /// - Parameter session: The AR session to use
    func setARSession(_ session: ARSession) {
        // Set the delegate to self to handle anchor events
        session.delegate = self
        self.arSession = session
        
        // Load existing anchors into the session
        for anchor in sphereAnchors {
            session.add(anchor: anchor)
        }
        
        // Send status update
        statusSubject.send("AR session updated")
    }
    
    /// Adds a sphere anchor at the specified position
    func addSphereAnchor(at transform: simd_float4x4, radius: Float = 0.025, color: UIColor = .red) {
        let anchor = SphereAnchor(transform: transform, radius: radius, color: color)
        
        // Add anchor to AR session
        arSession?.add(anchor: anchor)
        
        // Add to local collection
        sphereAnchors.append(anchor)
        anchorsSubject.send(sphereAnchors)
        
        // Save the updated anchors
        saveAnchors()
        
        // Try to save the world map when a new anchor is added
        saveWorldMap()
    }
    
    /// Removes a sphere anchor
    func removeSphereAnchor(_ anchor: SphereAnchor) {
        // Remove from AR session
        arSession?.remove(anchor: anchor)
        
        // Remove from local collection
        sphereAnchors.removeAll { $0.identifier == anchor.identifier }
        anchorsSubject.send(sphereAnchors)
        
        // Save the updated anchors
        saveAnchors()
        
        // Try to save the world map when an anchor is removed
        saveWorldMap()
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
        
        // Save the updated anchors (empty now)
        saveAnchors()
        
        // Try to save the world map when all anchors are cleared
        saveWorldMap()
    }
    
    /// Saves the current AR world map
    func saveWorldMap() {
        guard let worldMapURL = worldMapURL else {
            statusSubject.send("Error: Could not create world map URL")
            return
        }
        
        arSession?.getCurrentWorldMap { [weak self] worldMap, error in
            guard let self = self else { return }
            
            if let error = error {
                self.statusSubject.send("Error getting world map: \(error.localizedDescription)")
                return
            }
            
            guard let map = worldMap else {
                self.statusSubject.send("Error: No world map available")
                return
            }
            
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                try data.write(to: worldMapURL, options: [.atomic])
                self.statusSubject.send("World map saved successfully")
            } catch {
                self.statusSubject.send("Error saving world map: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Loads an AR world map and applies it to the provided configuration
    private func loadWorldMap(for configuration: ARWorldTrackingConfiguration) {
        guard let worldMapURL = worldMapURL,
              FileManager.default.fileExists(atPath: worldMapURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: worldMapURL)
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                statusSubject.send("Error: Could not unarchive world map")
                return
            }
            
            // Set the world map in the configuration
            configuration.initialWorldMap = worldMap
            statusSubject.send("World map loaded successfully")
        } catch {
            statusSubject.send("Error loading world map: \(error.localizedDescription)")
        }
    }
    
    /// Saves the current anchors to a file
    private func saveAnchors() {
        guard let anchorsURL = anchorsURL else {
            statusSubject.send("Error: Could not create anchors URL")
            return
        }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: sphereAnchors, requiringSecureCoding: true)
            try data.write(to: anchorsURL, options: [.atomic])
        } catch {
            statusSubject.send("Error saving anchors: \(error.localizedDescription)")
        }
    }
    
    /// Loads anchors from file
    private func loadAnchors() {
        guard let anchorsURL = anchorsURL,
              FileManager.default.fileExists(atPath: anchorsURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: anchorsURL)
            if let loadedAnchors = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [SphereAnchor] {
                self.sphereAnchors = loadedAnchors
                self.anchorsSubject.send(loadedAnchors)
            }
        } catch {
            statusSubject.send("Error loading anchors: \(error.localizedDescription)")
        }
    }
    
    // MARK: - ARSessionDelegate Methods
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Process newly added anchors
        let newSphereAnchors = anchors.compactMap { $0 as? SphereAnchor }
        
        for anchor in newSphereAnchors {
            // Only add if not already in our collection
            if !sphereAnchors.contains(where: { $0.identifier == anchor.identifier }) {
                sphereAnchors.append(anchor)
            }
        }
        
        if !newSphereAnchors.isEmpty {
            anchorsSubject.send(sphereAnchors)
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // Process removed anchors
        let removedIds = anchors.map { $0.identifier }
        sphereAnchors.removeAll { removedIds.contains($0.identifier) }
        anchorsSubject.send(sphereAnchors)
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        // Notify about tracking state changes for relocalization feedback
        NotificationCenter.default.post(
            name: NSNotification.Name("ARTrackingStateChanged"),
            object: nil,
            userInfo: ["trackingState": camera.trackingState]
        )
        
        // Also update status message
        switch camera.trackingState {
        case .normal:
            statusSubject.send("Tracking normal - AR anchors active")
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
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        statusSubject.send("AR session was interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        statusSubject.send("AR session interruption ended")
        
        // Try to relocalize to the saved world map
        if let configuration = session.configuration as? ARWorldTrackingConfiguration {
            loadWorldMap(for: configuration)
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
    }
} 