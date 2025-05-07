import Foundation
import ARKit
import RealityKit
import Metal
import ModelIO
import MetalKit
import Combine

class ARScanService: NSObject {
    // MARK: - Properties
    private var arSession: ARSession?
    private var meshAnchors: [ARMeshAnchor] = []
    private let device: MTLDevice
    private var allocator: MTKMeshBufferAllocator!
    
    // States and subjects for publishers
    private var scanSessionSubject = CurrentValueSubject<ScanSession, Never>(ScanSession.new())
    private var alertSubject = PassthroughSubject<String, Never>()
    
    // MARK: - Publishers
    var scanSessionPublisher: AnyPublisher<ScanSession, Never> {
        scanSessionSubject.eraseToAnyPublisher()
    }
    
    var alertPublisher: AnyPublisher<String, Never> {
        alertSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    override init() {
        // Initialize Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to create MTL device")
        }
        self.device = device
        self.allocator = MTKMeshBufferAllocator(device: device)
        
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Checks if the device supports LiDAR scanning
    static func deviceSupportsLiDAR() -> Bool {
        return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
    
    /// Starts a new scanning session
    func startScanning() {
        // Reset current session
        stopScanning()
        
        // Check if LiDAR is available
        guard ARScanService.deviceSupportsLiDAR() else {
            updateSession { session in
                session.with(
                    state: .failed(NSError(domain: "ARScanService", code: 1, userInfo: [NSLocalizedDescriptionKey: "LiDAR not supported on this device"])),
                    statusMessage: "LiDAR scanning not available on this device"
                )
            }
            alertSubject.send("LiDAR scanning is not available on this device")
            return
        }
        
        // Update session state to initializing
        updateSession { session in
            session.with(
                state: .initializing,
                startTime: nil,
                endTime: nil,
                meshAnchorsCount: 0,
                scanProgress: 0.0,
                meshAnchors: [],
                statusMessage: "Initializing camera..."
            )
        }
        
        // Create and configure new AR session
        arSession = ARSession()
        arSession?.delegate = self
        
        // Configure session
        guard let configuration = createScanningConfiguration() else {
            updateSession { session in
                session.with(
                    state: .failed(NSError(domain: "ARScanService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create scanning configuration"])),
                    statusMessage: "Failed to create scanning configuration"
                )
            }
            alertSubject.send("Failed to create scanning configuration")
            return
        }
        
        // Run the session
        arSession?.run(configuration)
    }
    
    /// Stops the current scanning session
    func stopScanning() {
        // Pause the AR session
        arSession?.pause()
        
        // Update session state
        let currentSession = scanSessionSubject.value
        if case .scanning = currentSession.state {
            updateSession { session in
                session.with(
                    state: .completed,
                    endTime: Date(),
                    statusMessage: "Scanning completed"
                )
            }
        }
    }
    
    /// Creates a configuration for LiDAR scanning
    func createScanningConfiguration() -> ARWorldTrackingConfiguration? {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            return nil
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.environmentTexturing = .automatic
        
        // Enable more features for better tracking
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Set better world alignment for stability
        configuration.worldAlignment = .gravity
        
        // Enable smooth depth
        if #available(iOS 13.0, *) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }
        
        return configuration
    }
    
    /// Returns the current AR session
    func getARSession() -> ARSession? {
        return arSession
    }
    
    /// Returns the current scan session
    func getCurrentScanSession() -> ScanSession {
        return scanSessionSubject.value
    }
    
    /// Gets the mesh asset for export - public alias for createMDLAsset
    func getMeshAsset() -> MDLAsset? {
        return createMDLAsset()
    }
    
    /// Converts the current set of mesh anchors to an MDLAsset for export
    func createMDLAsset() -> MDLAsset? {
        let currentMeshAnchors = scanSessionSubject.value.meshAnchors
        
        guard !currentMeshAnchors.isEmpty else {
            alertSubject.send("No mesh anchors to export")
            return nil
        }
        
        // Create an asset with our allocator
        let asset = MDLAsset(bufferAllocator: allocator)
        
        // Process mesh anchors
        for anchor in currentMeshAnchors {
            if let mesh = createMDLMesh(from: anchor) {
                asset.add(mesh)
            }
        }
        
        return asset
    }
    
    // MARK: - Private Methods
    
    /// Updates the current scan session with the provided changes
    private func updateSession(_ changes: (ScanSession) -> ScanSession) {
        let updatedSession = changes(scanSessionSubject.value)
        scanSessionSubject.send(updatedSession)
    }
    
    /// Updates internal storage with new mesh anchors from AR frame
    private func updateMeshAnchors(frame: ARFrame) {
        let newMeshAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        
        // Update session with new mesh anchors
        updateSession { session in
            // Calculate progress (simplified version)
            let maxExpectedMeshes = 100 // This value may need adjustment
            let progress = min(Float(newMeshAnchors.count) / Float(maxExpectedMeshes), 1.0)
            
            // Update status message based on progress
            var statusMessage = session.statusMessage
            if case .scanning = session.state {
                if progress < 0.3 {
                    statusMessage = "Scanning in progress (Early stage)"
                } else if progress < 0.7 {
                    statusMessage = "Scanning in progress (Building mesh)"
                } else {
                    statusMessage = "Scanning in progress (Refining details)"
                }
            }
            
            return session.with(
                meshAnchorsCount: newMeshAnchors.count,
                scanProgress: progress,
                meshAnchors: newMeshAnchors,
                statusMessage: statusMessage
            )
        }
    }
    
    /// Creates an MDLMesh from an ARMeshAnchor
    private func createMDLMesh(from meshAnchor: ARMeshAnchor) -> MDLMesh? {
        let geometry = meshAnchor.geometry
        
        // Get vertex data
        let vertices = geometry.vertices
        let vertexCount = vertices.count
        let vertexStride = vertices.stride
        
        // Skip empty meshes
        if vertexCount == 0 {
            return nil
        }
        
        // Create vertex buffer with raw data
        let vertexBufferPointer = vertices.buffer.contents()
        
        let vertexData = Data(bytesNoCopy: vertexBufferPointer,
                             count: vertexCount * vertexStride,
                             deallocator: .none)
        
        let vertexBuffer = allocator.newBuffer(with: vertexData, type: .vertex)
        
        // Get index data
        let faces = geometry.faces
        let faceCount = faces.count / 3
        let indexCount = faceCount * 3
        
        // Skip meshes with no faces
        if indexCount == 0 {
            return nil
        }
        
        // Create index buffer with raw data
        let indexBufferPointer = faces.buffer.contents()
        
        let indexData = Data(bytesNoCopy: indexBufferPointer,
                            count: indexCount * MemoryLayout<UInt32>.size,
                            deallocator: .none)
        
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)
        
        // Create MDLMesh
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, 
                                                           format: .float3,
                                                           offset: 0,
                                                           bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: vertexStride)
        
        let mdlMesh = MDLMesh(vertexBuffer: vertexBuffer,
                              vertexCount: vertexCount,
                              descriptor: vertexDescriptor,
                              submeshes: [MDLSubmesh(indexBuffer: indexBuffer,
                                                   indexCount: indexCount,
                                                   indexType: .uint32,
                                                   geometryType: .triangles,
                                                   material: nil)])
        
        // Apply mesh anchor transform
        let transform = meshAnchor.transform
        mdlMesh.transform = MDLTransform(matrix: transform)
        
        return mdlMesh
    }
}

// MARK: - ARSessionDelegate
extension ARScanService: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update mesh anchors with the latest frame
        updateMeshAnchors(frame: frame)
        
        // Check tracking state and quality
        checkTrackingStatus(frame: frame)
        
        // If we're in initializing state and we got mesh anchors, transition to scanning state
        let currentSession = scanSessionSubject.value
        if case .initializing = currentSession.state, currentSession.meshAnchorsCount > 0 {
            updateSession { session in
                session.with(
                    state: .scanning,
                    startTime: Date(),
                    statusMessage: "Mesh detected - Recording started"
                )
            }
        }
    }
    
    /// Check for tracking issues and update the session accordingly
    private func checkTrackingStatus(frame: ARFrame) {
        switch frame.camera.trackingState {
        case .normal:
            // Clear tracking error messages if we're back to normal
            if scanSessionSubject.value.statusMessage.contains("tracking") {
                updateSession { session in
                    session.with(
                        statusMessage: session.state == .scanning ? "Scanning in progress" : session.statusMessage
                    )
                }
            }
        case .limited(let reason):
            var message = "Limited tracking quality: "
            switch reason {
            case .excessiveMotion:
                message += "Move the device more slowly"
            case .insufficientFeatures:
                message += "Point at surfaces with more texture or details"
            case .initializing:
                message += "Initializing AR session, please wait"
            case .relocalizing:
                message += "Relocalizing, please wait"
            @unknown default:
                message += "Unknown issue"
            }
            
            updateSession { session in
                session.with(statusMessage: message)
            }
        case .notAvailable:
            updateSession { session in
                session.with(statusMessage: "Tracking not available")
            }
        @unknown default:
            break
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Process new anchors if needed
        let currentSession = scanSessionSubject.value
        if case .initializing = currentSession.state {
            let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
            if !meshAnchors.isEmpty {
                updateSession { session in
                    session.with(
                        state: .scanning,
                        startTime: Date(),
                        statusMessage: "Mesh detected - Recording started"
                    )
                }
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Handle session failure
        updateSession { session in
            session.with(
                state: .failed(error),
                endTime: Date(),
                statusMessage: "AR session failed: \(error.localizedDescription)"
            )
        }
        alertSubject.send("Scanning failed: \(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Handle session interruption
        updateSession { session in
            session.with(
                state: .paused,
                statusMessage: "AR session interrupted"
            )
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Handle resumption after interruption
        let currentSession = scanSessionSubject.value
        if case .paused = currentSession.state {
            updateSession { session in
                session.with(
                    state: .scanning,
                    statusMessage: "AR session resumed"
                )
            }
        }
    }
} 