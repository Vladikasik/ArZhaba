import SwiftUI
import ARKit
import RealityKit

struct ARScanView: UIViewRepresentable {
    @ObservedObject var viewModel: ScanningViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR view settings
        arView.automaticallyConfigureSession = false
        
        // Set session
        if let session = viewModel.arSession {
            arView.session = session
        } else {
            // If no session is available from the view model, create one
            let session = viewModel.scanningUtility.createARSession()
            arView.session = session
        }
        
        // Configure debugging options to visualize the mesh
        #if DEBUG
        arView.debugOptions = [.showSceneUnderstanding]
        #endif
        
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
        } else {
            // Pause session if not scanning
            if !viewModel.isScanning && uiView.session.configuration != nil {
                uiView.session.pause()
            }
        }
    }
} 