import Foundation
import ARKit
import Combine
import SwiftUI

class SphereAnchorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sphereAnchors: [SphereAnchor] = []
    @Published var statusMessage: String = "Ready to place anchors"
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    
    // Color options for sphere anchors
    let colorOptions: [UIColor] = [
        .red, .blue, .green, .yellow, .purple, .orange, .cyan, .magenta
    ]
    
    // Current selected color
    @Published var selectedColorIndex: Int = 0
    
    // Current selected radius
    @Published var sphereRadius: Float = 0.025
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let anchorService = ARAnchorService.shared
    
    // MARK: - Initialization
    init() {
        setupSubscriptions()
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        // Subscribe to anchor updates
        anchorService.anchorsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] anchors in
                self?.sphereAnchors = anchors
            }
            .store(in: &cancellables)
        
        // Subscribe to status messages
        anchorService.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.statusMessage = message
                
                // Show important messages as alerts
                if message.contains("Error") || message.contains("success") {
                    self?.showAlert(message: message)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Setup and get the AR session
    func getARSession() -> ARSession {
        return anchorService.setupARSession()
    }
    
    /// Add a sphere at the given position
    func addSphere(at transform: simd_float4x4) {
        let color = colorOptions[selectedColorIndex]
        anchorService.addSphereAnchor(at: transform, radius: sphereRadius, color: color)
    }
    
    /// Add a sphere in front of the camera
    func addSphereInFrontOfCamera(frame: ARFrame) {
        // Create a position 0.5 meters in front of the camera
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.5
        
        let transform = simd_mul(frame.camera.transform, translation)
        
        addSphere(at: transform)
    }
    
    /// Remove a sphere anchor
    func removeSphere(_ anchor: SphereAnchor) {
        anchorService.removeSphereAnchor(anchor)
    }
    
    /// Clear all sphere anchors
    func clearAllSpheres() {
        anchorService.clearAllSphereAnchors()
    }
    
    /// Save the current world map
    func saveWorldMap() {
        anchorService.saveWorldMap()
    }
    
    /// Show an alert with the given message
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    /// Get the color for display in SwiftUI
    func getSwiftUIColor(for index: Int) -> Color {
        guard index < colorOptions.count else { return Color.red }
        
        let uiColor = colorOptions[index]
        return Color(uiColor)
    }
    
    /// Get the currently selected color
    var selectedColor: UIColor {
        colorOptions[selectedColorIndex]
    }
    
    /// Get the currently selected SwiftUI color
    var selectedSwiftUIColor: Color {
        Color(selectedColor)
    }
} 