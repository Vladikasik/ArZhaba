import SwiftUI
import ARKit
import RealityKit

struct ARSphereView: UIViewRepresentable {
    @EnvironmentObject var viewModel: SphereAnchorViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        
        // Configure AR view settings
        // arView.automaticallyConfigureSession = false
        
        // Set delegate to handle rendering
        arView.delegate = context.coordinator
        
        // Set session
        arView.session = viewModel.getARSession()
        
        // Set debug options for visual debugging if needed
        // arView.debugOptions = [.showFeaturePoints]
        
        // Configure scene
        arView.scene.lightingEnvironment.contents = UIColor.white
        arView.scene.lightingEnvironment.intensity = 1.0
        
        // Setup tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        // Setup long press gesture for removal
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        arView.addGestureRecognizer(longPressGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Ensure we have the latest AR session
        if uiView.session !== viewModel.getARSession() {
            uiView.session = viewModel.getARSession()
        }
        
        // Update existing nodes if needed based on viewModel changes
        // This is handled by the ARSCNViewDelegate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARSphereView
        var arView: ARSCNView?
        
        init(_ parent: ARSphereView) {
            self.parent = parent
            super.init()
        }
        
        // Handle tap gestures to add spheres
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = gesture.view as? ARSCNView,
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
            guard gesture.state == .began,
                  let arView = gesture.view as? ARSCNView else { return }
            
            // Get press location in the AR view
            let pressLocation = gesture.location(in: arView)
            
            // Perform hit test to see if user pressed on a node
            let hitTestResults = arView.hitTest(pressLocation, options: nil)
            
            if let hitResult = hitTestResults.first,
               let node = hitResult.node.parent, // Parent node is the actual sphere node
               let identifier = node.name,
               let anchor = parent.viewModel.sphereAnchors.first(where: { $0.identifier.uuidString == identifier }) {
                // Remove the anchor
                parent.viewModel.removeSphere(anchor)
            }
        }
        
        // MARK: - ARSCNViewDelegate
        
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            // Check if the anchor is a sphere anchor
            guard let sphereAnchor = anchor as? SphereAnchor else { return nil }
            
            // Create a sphere geometry with the specified radius
            let sphere = SCNSphere(radius: CGFloat(sphereAnchor.radius))
            
            // Set the material properties
            let material = SCNMaterial()
            material.diffuse.contents = sphereAnchor.color
            // Add some transparency to make it look better
            material.transparency = 0.8
            
            // Apply materials to sphere
            sphere.materials = [material]
            
            // Create a node with the sphere geometry
            let node = SCNNode(geometry: sphere)
            
            // Create a parent node to manage the sphere node
            let parentNode = SCNNode()
            parentNode.addChildNode(node)
            
            // Set the name to match anchor identifier for later reference
            parentNode.name = sphereAnchor.identifier.uuidString
            
            return parentNode
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            // Update node properties if needed based on updated anchor
            guard let sphereAnchor = anchor as? SphereAnchor,
                  let sphereNode = node.childNodes.first,
                  let sphere = sphereNode.geometry as? SCNSphere else { return }
            
            // Update radius if changed
            sphere.radius = CGFloat(sphereAnchor.radius)
            
            // Update material if changed
            if let material = sphere.materials.first {
                material.diffuse.contents = sphereAnchor.color
            }
        }
    }
} 