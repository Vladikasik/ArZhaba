import Foundation
import ARKit
import RealityKit
import Metal
import ModelIO
import MetalKit

// Enum definition moved to ScanFileManager.swift
// enum ExportFileType {
//     case obj
//     case usd
//     case usda
//     case usdc
// }

class LiDARScanningUtility {
    
    // MARK: - Properties
    private var arSession: ARSession?
    private var meshAnchors: [ARMeshAnchor] = []
    private let device: MTLDevice
    private var allocator: MTKMeshBufferAllocator!
    
    // MARK: - Initialization
    init() {
        // Initialize Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to create MTL device")
        }
        self.device = device
        self.allocator = MTKMeshBufferAllocator(device: device)
    }
    
    // MARK: - Public Methods
    
    /// Checks if the device supports LiDAR scanning
    static func deviceSupportsLiDAR() -> Bool {
        return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
    
    /// Creates and configures an AR session for LiDAR scanning
    func createARSession() -> ARSession {
        let session = ARSession()
        self.arSession = session
        return session
    }
    
    /// Creates a configuration for LiDAR scanning
    func createScanningConfiguration() -> ARWorldTrackingConfiguration? {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            print("LiDAR not supported on this device")
            return nil
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.environmentTexturing = .automatic
        
        // Set the frame rate to optimize for better scanning
        if #available(iOS 13.0, *) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }
        
        return configuration
    }
    
    /// Updates internal storage with new mesh anchors
    func updateMeshAnchors(frame: ARFrame) {
        meshAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
    }
    
    /// Returns the current number of mesh anchors
    func getMeshAnchorsCount() -> Int {
        return meshAnchors.count
    }
    
    /// Converts the current set of mesh anchors to an MDLAsset for export
    func createMDLAsset() -> MDLAsset? {
        guard !meshAnchors.isEmpty else {
            print("No mesh anchors to export")
            return nil
        }
        
        // Create an asset with our allocator
        let asset = MDLAsset(bufferAllocator: allocator)
        
        // Process mesh anchors
        for anchor in meshAnchors {
            if let mesh = createMDLMesh(from: anchor) {
                asset.add(mesh)
            } else {
                print("Error processing mesh anchor")
            }
        }
        
        return asset
    }
    
    /// Exports the scan to a file at the specified URL
    func exportScan(to url: URL, fileType: ExportFileType = .obj) -> Bool {
        guard let asset = createMDLAsset() else {
            return false
        }
        
        do {
            try asset.export(to: url)
            return true
        } catch {
            print("Failed to export asset: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
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