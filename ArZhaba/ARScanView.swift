import SwiftUI
import ARKit
import RealityKit

struct ARScanView: UIViewRepresentable {
    @ObservedObject var viewModel: ScanningViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        
        // Configure AR view settings
        arView.automaticallyConfigureSession = false
        
        // Set the delegate to receive updates
        context.coordinator.arView = arView
        
        // Set session
        if let session = viewModel.arSession {
            arView.session = session
        } else {
            // If no session is available from the view model, create one
            let session = viewModel.scanningUtility.createARSession()
            viewModel.arSession = session
            arView.session = session
        }
        
        // Configure debugging options to visualize the mesh
        arView.debugOptions = [.showSceneUnderstanding]
        
        // Set environment
        arView.environment.sceneUnderstanding.options = [.occlusion, .physics]
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update AR view based on view model state
        if viewModel.isScanning {
            // Make sure session is running with correct configuration
            if uiView.session.configuration == nil,
               let configuration = viewModel.scanningUtility.createScanningConfiguration() {
                uiView.session.run(configuration)
            }
        } else if !viewModel.isLoading {
            // Pause session if not scanning and not loading
            if !viewModel.isScanning && uiView.session.configuration != nil {
                uiView.session.pause()
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
        }
        
        // Method to handle session interruptions or rendering issues
        func checkRendering() {
            guard let arView = arView else { return }
            
            // If the session isn't running but should be, restart it
            if let session = parent.viewModel.arSession, 
               session.configuration == nil && parent.viewModel.isScanning,
               let configuration = parent.viewModel.scanningUtility.createScanningConfiguration() {
                session.run(configuration)
            }
        }
    }
} 