import SwiftUI
import ARKit
import RealityKit

struct ARScanView: UIViewRepresentable {
    @EnvironmentObject var viewModel: ScanningViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        
        // Configure AR view settings
        arView.automaticallyConfigureSession = false
        
        // Disable automatic texture allocation to prevent Video texture allocator errors
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableAREnvironmentLighting]
        arView.environment.lighting.intensityExponent = 0
        
        // Set the delegate to receive updates
        context.coordinator.arView = arView
        
        // Set session
        if let session = viewModel.getARSession() {
            arView.session = session
        }
        
        // Configure debugging options to visualize the mesh
        arView.debugOptions = [.showSceneUnderstanding]
        
        // Set environment (limit options to reduce errors)
        arView.environment.sceneUnderstanding.options = [.occlusion, .physics]
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update AR view based on view model state
        
        // Make sure we have the latest AR session
        if let session = viewModel.getARSession() {
            if uiView.session !== session {
                uiView.session = session
            }
        }
        
        // Update debug visualization based on scanning state
        switch viewModel.scanSession.state {
        case .scanning:
            uiView.debugOptions = [.showSceneUnderstanding]
        case .initializing:
            uiView.debugOptions = [.showSceneUnderstanding]
        default:
            // Don't show mesh when not scanning
            if viewModel.isMeshVisible {
                uiView.debugOptions = [.showSceneUnderstanding]
            } else {
                uiView.debugOptions = []
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ARScanView
        var arView: ARView?
        
        init(_ parent: ARScanView) {
            self.parent = parent
            super.init()
        }
    }
} 