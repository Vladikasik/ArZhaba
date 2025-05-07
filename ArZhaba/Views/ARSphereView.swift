import SwiftUI
import ARKit
import RealityKit

struct ARSphereView: UIViewRepresentable {
    @EnvironmentObject var viewModel: SphereAnchorViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        
        // Configure scene to use less memory
        let scene = SCNScene()
        // Use lower quality rendering to reduce memory usage
        scene.background.contents = UIColor.black
        arView.scene = scene
        arView.antialiasingMode = .none
        
        // Reduce scene complexity to save memory
        arView.preferredFramesPerSecond = 30
        arView.rendersContinuously = false
        arView.automaticallyUpdatesLighting = false
        
        // Reduce texture memory usage
        SCNTransaction.animationDuration = 0
        
        // Set delegate to handle rendering
        arView.delegate = context.coordinator
        
        // Set session
        arView.session = viewModel.getARSession()
        
        // Setup tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        // Setup long press gesture for removal
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        arView.addGestureRecognizer(longPressGesture)
        
        // Store reference to view
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Only update the session if needed to avoid "Attempting to enable an already-enabled session"
        if uiView.session !== viewModel.getARSession() {
            // Pause previous session if any to prevent multiple active sessions
            uiView.session.pause()
            
            // Set the new session
            uiView.session = viewModel.getARSession()
        }
        
        // Update rendering options based on session state
        switch viewModel.sessionState {
        case .idle:
            // Use minimal rendering in idle state
            uiView.rendersContinuously = false
            uiView.autoenablesDefaultLighting = false
            uiView.automaticallyUpdatesLighting = false
            uiView.preferredFramesPerSecond = 15 // Lower FPS for idle
        case .recording, .viewing:
            // Better quality for active use
            uiView.rendersContinuously = true
            uiView.autoenablesDefaultLighting = true
            uiView.automaticallyUpdatesLighting = true
            uiView.preferredFramesPerSecond = 30
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARSphereView
        weak var arView: ARSCNView?
        // Cache for node lookup to avoid repeated searches
        var nodeCache = [UUID: SCNNode]()
        // Shared sphere geometry to reduce memory usage
        var sharedSphereGeometries = [Float: SCNSphere]()
        
        init(_ parent: ARSphereView) {
            self.parent = parent
            super.init()
        }
        
        // Clean up resources when coordinator is deallocated
        deinit {
            clearNodeCache()
        }
        
        // Clear the node cache to avoid memory leaks
        func clearNodeCache() {
            for (_, node) in nodeCache {
                node.removeFromParentNode()
            }
            nodeCache.removeAll()
            sharedSphereGeometries.removeAll()
        }
        
        // Handle tap gestures to add spheres
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Only process taps if in recording mode
            guard parent.viewModel.sessionState == .recording,
                  let arView = gesture.view as? ARSCNView,
                  let frame = arView.session.currentFrame else { return }
            
            // Get tap location in the AR view
            let tapLocation = gesture.location(in: arView)
            
            // Perform hit test to see if user tapped on a plane
            let hitTestResults = arView.hitTest(tapLocation, types: .existingPlaneUsingGeometry)
            
            if let hitResult = hitTestResults.first {
                // Add a sphere anchor at the hit position
                parent.viewModel.addSphere(at: hitResult.worldTransform)
            } else {
                // If no plane was hit, add sphere in front of camera as fallback
                parent.viewModel.addSphereInFrontOfCamera(frame: frame)
            }
        }
        
        // Handle long press gestures to remove spheres
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            // Only remove spheres if in recording mode
            guard parent.viewModel.sessionState == .recording,
                  gesture.state == .began,
                  let arView = gesture.view as? ARSCNView else { return }
            
            // Get press location in the AR view
            let pressLocation = gesture.location(in: arView)
            
            // Perform hit test to see if user pressed on a node
            let hitTestResults = arView.hitTest(pressLocation, options: nil)
            
            if let hitResult = hitTestResults.first,
               let node = hitResult.node.parent, // Parent node is the actual sphere node
               let identifier = node.name,
               let uuidString = identifier.isEmpty ? nil : identifier,
               let uuid = UUID(uuidString: uuidString),
               let anchor = parent.viewModel.sphereAnchors.first(where: { $0.identifier == uuid }) {
                // Remove the anchor
                parent.viewModel.removeSphere(anchor)
                
                // Remove from cache
                nodeCache.removeValue(forKey: uuid)
            }
        }
        
        // MARK: - ARSCNViewDelegate
        
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            // Check if the anchor is a sphere anchor
            guard let sphereAnchor = anchor as? SphereAnchor else { return nil }
            
            // Check if we already have a node for this anchor in the cache
            if let existingNode = nodeCache[sphereAnchor.identifier] {
                return existingNode
            }
            
            // Reuse sphere geometry if we already have one with this radius
            let sphere = sharedSphereGeometries[sphereAnchor.radius] ?? {
                // Create a sphere geometry with the specified radius - use lower polygon count
                let newSphere = SCNSphere(radius: CGFloat(sphereAnchor.radius))
                newSphere.segmentCount = 8  // Reduce from default 48 to 8 to save memory
                
                // Cache for reuse
                sharedSphereGeometries[sphereAnchor.radius] = newSphere
                return newSphere
            }()
            
            // Set the material properties
            let material = SCNMaterial()
            material.diffuse.contents = sphereAnchor.color
            material.transparency = 0.8
            material.lightingModel = .constant // Simpler lighting model to save memory
            
            // Only use a single material to save memory
            sphere.firstMaterial = material
            
            // Create a node with the sphere geometry
            let node = SCNNode(geometry: sphere)
            
            // Create a parent node to manage the sphere node
            let parentNode = SCNNode()
            parentNode.addChildNode(node)
            
            // Set the name to match anchor identifier for later reference
            parentNode.name = sphereAnchor.identifier.uuidString
            
            // Add to cache
            nodeCache[sphereAnchor.identifier] = parentNode
            
            return parentNode
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            // Update node properties if needed based on updated anchor
            guard let sphereAnchor = anchor as? SphereAnchor,
                  let sphereNode = node.childNodes.first,
                  let sphere = sphereNode.geometry as? SCNSphere else { return }
            
            // Update radius if changed
            if abs(sphere.radius - CGFloat(sphereAnchor.radius)) > 0.001 {
                // Use shared geometry if already created
                if let sharedSphere = sharedSphereGeometries[sphereAnchor.radius] {
                    sphereNode.geometry = sharedSphere
                } else {
                    sphere.radius = CGFloat(sphereAnchor.radius)
                    sharedSphereGeometries[sphereAnchor.radius] = sphere
                }
            }
            
            // Update material if changed - only update when necessary
            if let material = sphere.firstMaterial, 
               let currentColor = material.diffuse.contents as? UIColor,
               currentColor != sphereAnchor.color {
                material.diffuse.contents = sphereAnchor.color
            }
            
            // Update cache
            nodeCache[sphereAnchor.identifier] = node
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
            // Remove from cache when node is removed
            if let sphereAnchor = anchor as? SphereAnchor {
                nodeCache.removeValue(forKey: sphereAnchor.identifier)
            }
        }
        
        // Optimize scene rendering
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            // Only render when needed based on app state
            if let arView = self.arView {
                switch parent.viewModel.sessionState {
                case .idle:
                    // Minimal rendering in idle state
                    arView.isPlaying = false
                case .recording, .viewing:
                    // Active rendering in recording/viewing states
                    arView.isPlaying = true
                }
            }
        }
    }
} 