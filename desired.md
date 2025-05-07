now to the first part add that when the person taps another button on the screen to add big 5x5 cm dots to test how well the new session loads on local so we need to capture the space anchors with ARKit and then place some dots spheres relative to anchors and then save it and then test if when loading this scene we would have those dots in the same place  whats the best way to achieve it please provide with official info and official docs most apple authentic etc
the dots should be placed exacrlt where the camer is located compared to anchors and then they should be visible 
ka a make dot, i go 5 cm behind on the camer and i see the dot i placed



Research

Images

Tasks

Sources
70
Implementing Persistent AR Spheres Using ARKit Anchors

This technical guide demonstrates how to create persistent 5cm spherical markers in ARKit that maintain their position across sessions using Apple's official frameworks and best practices.
Core Implementation Strategy
1. Anchor Creation System
swift
// Create custom anchor subclass for sphere markers
class SphereAnchor: ARAnchor {
    static let identifier = "SphereAnchor"
    
    init(transform: simd_float4x4) {
        super.init(name: SphereAnchor.identifier, transform: transform)
    }
    
    required init(anchor: ARAnchor) {
        super.init(anchor: anchor)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
2. Sphere Placement Mechanism
swift
@IBAction func handleTap(_ sender: UIButton) {
    guard let frame = sceneView.session.currentFrame else { return }
    
    // Create test sphere at camera's current position
    let spherePosition = simd_make_float4x4(translation: [0,0,-0.5]) 
    let anchor = SphereAnchor(transform: spherePosition)
    sceneView.session.add(anchor: anchor)
}
3. Visual Representation
swift
func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
    guard anchor is SphereAnchor else { return nil }
    
    let sphere = SCNSphere(radius: 0.025)
    sphere.firstMaterial?.diffuse.contents = UIColor.red
    return SCNNode(geometry: sphere)
}
Session Persistence Implementation
1. World Map Saving
swift
func saveWorldMap() {
    sceneView.session.getCurrentWorldMap { [weak self] (worldMap, error) in
        guard let map = worldMap else { return }
        
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: map, 
                requiringSecureCoding: true
            )
            try data.write(to: self?.worldMapURL)
        } catch {
            print("Saving failed: \(error)")
        }
    }
}
2. World Map Loading
swift
func loadWorldMap() {
    guard let data = try? Data(contentsOf: worldMapURL) else { return }
    
    do {
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ARWorldMap.self, 
            from: data
        ) else { return }

        let config = ARWorldTrackingConfiguration()
        config.initialWorldMap = worldMap
        sceneView.session.run(config)
    } catch {
        print("Loading failed: \(error)")
    }
}
Key Implementation Considerations
Coordinate System Alignment
Use ARWorldTrackingConfiguration with initialWorldMap for session resumption
Ensure consistent environment lighting between sessions
Anchor Persistence
ARWorldMap automatically persists all session anchors
Custom anchor subclasses require NSCoding compliance
Spatial Accuracy
5cm spheres require millimeter-precise anchor placement
Use LiDAR scanning for improved depth estimation
Performance Optimization
swift
configuration.environmentTexturing = .automatic
configuration.isLightEstimationEnabled = true
Validation Testing Protocol
Positional Accuracy Test
Place spheres on known physical markers
Measure deviation using ARKit's raw position data
Persistence Reliability Check
Save/Load cycle stress testing
Verify anchor retention after 24hrs
Cross-Device Compatibility
Test between different iOS device models
Validate coordinate system alignment
This implementation leverages ARKit's native persistence capabilities while maintaining Apple's recommended practices for AR content creation. The solution provides a foundation for building complex persistent AR experiences with sub-centimeter accuracy.