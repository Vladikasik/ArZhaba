import Foundation
import ARKit
import Combine
import SwiftUI

/// ViewModel for managing AR room functionality
class RoomViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sphereAnchors: [SphereAnchor] = []
    @Published var statusMessage: String = "Create a new room or load an existing one"
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var sessionState: ARSessionState = .idle
    @Published var currentRoom: RoomModel?
    @Published var availableRooms: [RoomModel] = []
    
    // Controls for recording
    @Published var isRecording: Bool = false
    @Published var isShowingNewRoomDialog: Bool = false
    @Published var newRoomName: String = ""
    
    // Controls for room selection (deprecated)
    @available(*, deprecated, message: "No longer used with new swipeable UI")
    @Published var isShowingRoomSelector: Bool = false
    
    // Loading state and progress
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var loadingMessage: String = ""
    
    // Navigation control
    @Published var shouldShowARRoom: Bool = false
    
    // Color options for sphere anchors
    let colorOptions: [UIColor] = [
        .red, .blue, .green, .yellow, .purple, .orange, .cyan, .magenta
    ]
    
    // Current selected color
    @Published var selectedColorIndex: Int = 0
    
    // Current selected radius
    @Published var sphereRadius: Float = 0.025
    
    // Flag to indicate if the AR session has been initialized
    private var arSessionInitialized = false
    
    // Sharing properties
    @Published var isSharing: Bool = false
    @Published var shareURL: URL? = nil
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let anchorService = ARAnchorService.shared
    private let roomService = RoomService.shared
    
    // MARK: - Initialization
    init() {
        setupSubscriptions()
        loadAvailableRooms()
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
        
        // Subscribe to session state changes
        anchorService.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.sessionState = state
                self?.isRecording = state == .recording
                
                // Reset loading state when we're done
                if state != .idle {
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to current room updates
        anchorService.currentRoomPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] room in
                self?.currentRoom = room
            }
            .store(in: &cancellables)
        
        // Subscribe to available rooms
        roomService.roomsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rooms in
                self?.availableRooms = rooms
            }
            .store(in: &cancellables)
            
        // Subscribe to loading progress
        roomService.loadingProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.loadingProgress = progress
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Setup and get the AR session - lazy initialized only when needed
    func getARSession() -> ARSession {
        if !arSessionInitialized {
            // Just get a placeholder AR session without full initialization
            return ARSession()
        }
        return anchorService.setupARSession()
    }
    
    /// Initializes the AR session when needed (when creating/loading a room)
    private func initializeARSessionIfNeeded() {
        if !arSessionInitialized {
            arSessionInitialized = true
        }
    }
    
    /// Loads the list of available rooms
    func loadAvailableRooms() {
        availableRooms = roomService.getAllRooms()
    }
    
    /// Add a sphere at the given position
    func addSphere(at transform: simd_float4x4) {
        let color = colorOptions[selectedColorIndex]
        anchorService.addSphereAnchor(at: transform, radius: sphereRadius, color: color)
    }
    
    /// Add a sphere in front of the camera
    func addSphereInFrontOfCamera(frame: ARFrame) {
        // Only allow adding spheres in recording mode
        guard sessionState == .recording else {
            showAlert(message: "Can only add spheres in recording mode")
            return
        }
        
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
    
    /// Start recording a new room
    func startRecording() {
        guard !newRoomName.isEmpty else {
            showAlert(message: "Room name cannot be empty")
            return
        }
        
        // Initialize AR session if not done yet
        initializeARSessionIfNeeded()
        
        if anchorService.startRecording(roomName: newRoomName) {
            newRoomName = ""
            isShowingNewRoomDialog = false
        }
    }
    
    /// Start recording and show AR view
    func startRecordingAndShowAR() {
        guard !newRoomName.isEmpty else {
            showAlert(message: "Room name cannot be empty")
            return
        }
        
        // Initialize AR session if not done yet
        initializeARSessionIfNeeded()
        
        if anchorService.startRecording(roomName: newRoomName) {
            newRoomName = ""
            isShowingNewRoomDialog = false
            
            // Signal the view to show AR Room
            shouldShowARRoom = true
        }
    }
    
    /// Stop recording
    func stopRecording() -> Bool {
        return anchorService.stopRecording()
    }
    
    /// Load a room
    func loadRoom(_ room: RoomModel) {
        Logger.shared.info("Starting room load process from view model: \(room.name)",
                  destination: "RoomViewModel.loadRoom")
        
        isLoading = true
        statusMessage = "Preparing to load room: \(room.name)..."
        
        // Ensure we clear any previous loading state
        loadingProgress = 0.0
        
        // Give UI a moment to update before starting the loading process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else {
                Logger.shared.error("Self reference lost when loading room", 
                           destination: "RoomViewModel.loadRoom")
                return
            }
            
            // Start the loading process in the service
            if self.anchorService.loadRoom(room) {
                Logger.shared.info("Room loading started successfully", 
                          destination: "RoomViewModel.loadRoom")
                
                self.loadingMessage = "Loading room..."
                // No need to set isLoading = false here, the state publisher will do that
            } else {
                // Failed to start loading
                Logger.shared.error("Failed to start room loading process", 
                           destination: "RoomViewModel.loadRoom")
                
                self.isLoading = false
                self.loadingProgress = 0.0
                self.loadingMessage = ""
                self.statusMessage = "Failed to load room: \(room.name)"
            }
        }
    }
    
    /// Return to idle state
    func returnToIdle() {
        anchorService.returnToIdle()
    }
    
    /// Delete a room
    @available(*, deprecated, message: "Use deleteRoomSwipe instead")
    func deleteRoom(_ room: RoomModel) {
        // If this is the current room, return to idle first
        if currentRoom?.id == room.id {
            returnToIdle()
        }
        
        roomService.deleteRoom(room)
    }
    
    /// Delete a room from swipe action (new implementation)
    func deleteRoomSwipe(_ room: RoomModel) {
        // If this is the current room, return to idle first
        if currentRoom?.id == room.id {
            returnToIdle()
        }
        
        roomService.deleteRoom(room)
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
    
    /// Loads a room and sets showARRoom to true
    @available(*, deprecated, message: "Use loadAndShowRoomSwipe instead")
    func loadAndShowRoom(_ room: RoomModel) {
        // Clear states
        isSharing = false
        shareURL = nil
        
        // Initialize AR session if not done yet
        initializeARSessionIfNeeded()
        
        // Get a fresh session before loading the room to avoid state issues
        let _ = getARSession()
        
        // Set loading state
        isLoading = true
        loadingProgress = 0.0
        loadingMessage = "Loading room: \(room.name)"
        
        // Try to load the room
        if anchorService.loadRoom(room) {
            // Signal the view to show AR Room
            shouldShowARRoom = true
        } else {
            // Loading failed, show an error
            showAlert(message: "Failed to load room: \(room.name). Please try again.")
            isLoading = false
        }
    }
    
    /// Loads a room from swipe action (new implementation)
    func loadAndShowRoomSwipe(_ room: RoomModel) {
        // Clear states
        isSharing = false
        shareURL = nil
        
        // Initialize AR session if not done yet
        initializeARSessionIfNeeded()
        
        // Get a fresh session before loading the room to avoid state issues
        let _ = getARSession()
        
        // Set loading state
        isLoading = true
        loadingProgress = 0.0
        loadingMessage = "Loading room: \(room.name)"
        Logger.shared.info("Loading room from swipe action: \(room.name)", destination: "RoomViewModel.loadAndShowRoomSwipe")
        
        // Try to load the room and immediately trigger AR view
        if anchorService.loadRoom(room) {
            // Immediately signal the view to show AR Room
            shouldShowARRoom = true
            Logger.shared.info("Successfully triggered AR view for room: \(room.name)", destination: "RoomViewModel.loadAndShowRoomSwipe")
        } else {
            // Loading failed, show an error
            showAlert(message: "Failed to load room: \(room.name). Please try again.")
            isLoading = false
            Logger.shared.error("Failed to load room: \(room.name)", destination: "RoomViewModel.loadAndShowRoomSwipe")
        }
    }
    
    /// Exits the current mode (recording or viewing)
    func exitCurrentMode() {
        if sessionState == .recording {
            _ = stopRecording()
        } else if sessionState == .viewing {
            returnToIdle()
        }
    }
    
    /// Share a room file (deprecated)
    @available(*, deprecated, message: "Use shareRoomSwipe instead")
    func shareRoom(url: URL) {
        // Clear any pending state from previous actions
        shouldShowARRoom = false
        isShowingNewRoomDialog = false
        
        // Set sharing properties
        isSharing = true
        shareURL = url
    }
    
    /// Share a room from swipe action (new implementation)
    func shareRoomSwipe(url: URL) {
        // Clear pending states and ensure no other sheets are displayed
        shouldShowARRoom = false
        isShowingNewRoomDialog = false
        
        Logger.shared.info("Preparing to share room from URL: \(url.lastPathComponent)", destination: "RoomViewModel.shareRoomSwipe")
        
        // Small delay to ensure proper view transitions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Set sharing properties
            self.isSharing = true
            self.shareURL = url
            Logger.shared.info("Share sheet triggered for room", destination: "RoomViewModel.shareRoomSwipe")
        }
    }
    
    /// Import a room from a selected directory
    func importRoomFromDirectory(url: URL) {
        // Get the directory name as the room name
        let roomName = url.lastPathComponent
        
        // Log start of import
        Logger.shared.info("Starting room import from directory: \(roomName)",
                 destination: "RoomViewModel.importRoomFromDirectory")
        
        isLoading = true
        statusMessage = "Importing room: \(roomName)..."
        
        // Call the RoomService to handle the import
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let room = self.roomService.importRoomFromDirectory(url, roomName: roomName) {
                self.statusMessage = "Room '\(roomName)' imported successfully"
                self.isLoading = false
                
                // Refresh available rooms list
                self.loadAvailableRooms()
                
                // Don't automatically load the room, just show a success message
                self.showAlert(message: "Room '\(roomName)' imported successfully. You can now find it in your rooms list.")
            } else {
                self.showAlert(message: "Failed to import room from directory")
                self.isLoading = false
            }
        }
    }
} 