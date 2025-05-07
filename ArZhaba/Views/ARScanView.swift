import SwiftUI
import ARKit
import RealityKit
import SceneKit

struct ARScanView: UIViewRepresentable {
    @EnvironmentObject var viewModel: ScanningViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        
        // Configure AR view settings
        // ARSCNView doesn't have automaticallyConfigureSession property
        
        // Set delegate to handle rendering
        arView.delegate = context.coordinator
        
        // Set session
        if let session = viewModel.getARSession() {
            arView.session = session
        }
        
        // Configure debugging options to visualize features
        arView.debugOptions = [.showFeaturePoints]
        
        // Setup tap gesture recognizer for sphere placement
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        // Setup long press gesture for sphere removal
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        arView.addGestureRecognizer(longPressGesture)
        
        // Store reference to arView
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Make sure we have the latest AR session
        if let session = viewModel.getARSession() {
            if uiView.session !== session {
                uiView.session = session
            }
        }
        
        // Update debug visualization based on scanning state
        switch viewModel.scanSession.state {
        case .scanning:
            uiView.debugOptions = [.showFeaturePoints]
        case .initializing:
            uiView.debugOptions = [.showFeaturePoints]
        default:
            // Don't show mesh when not scanning
            if viewModel.isMeshVisible {
                uiView.debugOptions = [.showFeaturePoints]
            } else {
                uiView.debugOptions = []
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARScanView
        var arView: ARSCNView?
        
        init(_ parent: ARScanView) {
            self.parent = parent
            super.init()
        }
        
        // Handle tap gestures to add spheres
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Only handle taps when in sphere mode
            guard parent.viewModel.isSphereMode,
                  let arView = gesture.view as? ARSCNView,
                  let frame = arView.session.currentFrame else { return }
            
            // When in sphere mode, place the sphere directly at the camera position
            parent.viewModel.addSphereAtCameraPosition()
        }
        
        // Handle long press gestures to remove spheres
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            // Only handle long press when in sphere mode
            guard parent.viewModel.isSphereMode,
                  gesture.state == .began,
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
        
        // MARK: - ARSCNViewDelegate Methods
        
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            // Check if the anchor is a sphere anchor
            if let sphereAnchor = anchor as? SphereAnchor {
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
            // Handle mesh anchors for visualization
            else if let meshAnchor = anchor as? ARMeshAnchor {
                let node = SCNNode()
                
                // Only create visualization when mesh visibility is enabled
                if parent.viewModel.isMeshVisible {
                    // Create geometry from mesh anchor
                    let geometry = createGeometryFromMeshAnchor(meshAnchor)
                    
                    // Create a material for the mesh
                    let material = SCNMaterial()
                    material.diffuse.contents = UIColor.cyan.withAlphaComponent(0.15)
                    material.fillMode = .lines
                    material.isDoubleSided = true
                    material.lightingModel = .constant // Ensure consistent visibility
                    
                    // Create a second material for faces
                    let faceMaterial = SCNMaterial()
                    faceMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.05)
                    faceMaterial.isDoubleSided = true
                    faceMaterial.lightingModel = .constant
                    
                    // Apply materials to geometry
                    geometry.materials = [material, faceMaterial]
                    
                    // Create a node with the geometry
                    let meshNode = SCNNode(geometry: geometry)
                    node.addChildNode(meshNode)
                }
                
                return node
            }
            
            return nil
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            // Update node properties if needed based on updated anchor
            if let sphereAnchor = anchor as? SphereAnchor,
               let sphereNode = node.childNodes.first,
               let sphere = sphereNode.geometry as? SCNSphere {
                
                // Update radius if changed
                sphere.radius = CGFloat(sphereAnchor.radius)
                
                // Update material if changed
                if let material = sphere.materials.first {
                    material.diffuse.contents = sphereAnchor.color
                }
            }
            // Update mesh anchors when they change
            else if let meshAnchor = anchor as? ARMeshAnchor {
                // Remove all child nodes
                node.childNodes.forEach { $0.removeFromParentNode() }
                
                // Only create visualization when mesh visibility is enabled
                if parent.viewModel.isMeshVisible {
                    // Create updated geometry from mesh anchor
                    let geometry = createGeometryFromMeshAnchor(meshAnchor)
                    
                    // Create a material for the mesh
                    let material = SCNMaterial()
                    material.diffuse.contents = UIColor.cyan.withAlphaComponent(0.15)
                    material.fillMode = .lines
                    material.isDoubleSided = true
                    material.lightingModel = .constant // Ensure consistent visibility
                    
                    // Create a second material for faces
                    let faceMaterial = SCNMaterial()
                    faceMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.05)
                    faceMaterial.isDoubleSided = true
                    faceMaterial.lightingModel = .constant
                    
                    // Apply materials to geometry
                    geometry.materials = [material, faceMaterial]
                    
                    // Create a node with the geometry
                    let meshNode = SCNNode(geometry: geometry)
                    node.addChildNode(meshNode)
                }
            }
        }
        
        // Helper to create SceneKit geometry from ARMeshAnchor
        private func createGeometryFromMeshAnchor(_ meshAnchor: ARMeshAnchor) -> SCNGeometry {
            let geometry = meshAnchor.geometry
            
            // Get vertex buffer
            let vertices = geometry.vertices
            let vertexBuffer = geometry.vertices.buffer.contents()
            let vertexCount = geometry.vertices.count
            
            // Get face buffer
            let faces = geometry.faces
            let faceBuffer = geometry.faces.buffer.contents()
            let faceCount = geometry.faces.count
            
            // Create vertex source from vertex buffer
            let vertexSource = SCNGeometrySource(
                buffer: geometry.vertices.buffer,
                vertexFormat: geometry.vertices.format,
                semantic: .vertex,
                vertexCount: vertexCount,
                dataOffset: geometry.vertices.offset,
                dataStride: geometry.vertices.stride
            )
            
            // Add normal source for better lighting
            let normalSource = SCNGeometrySource(
                buffer: geometry.normals.buffer,
                vertexFormat: geometry.normals.format,
                semantic: .normal,
                vertexCount: geometry.normals.count,
                dataOffset: geometry.normals.offset,
                dataStride: geometry.normals.stride
            )
            
            // Create element for mesh faces
            let element = SCNGeometryElement(
                buffer: geometry.faces.buffer,
                primitiveType: .triangles,
                primitiveCount: faceCount / 3,
                bytesPerIndex: MemoryLayout<UInt32>.size
            )
            
            // Create SCNGeometry with vertex and element data
            let scnGeometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
            
            return scnGeometry
        }
    }
} 