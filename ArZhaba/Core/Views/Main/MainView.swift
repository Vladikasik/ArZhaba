import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = RoomViewModel()
    @State private var showARRoom = false
    @State private var roomToDelete: RoomModel? = nil
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    // Logo/title
                    Text("ArZhaba")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Main actions
                    VStack(spacing: 20) {
                        // Create room button
                        Button(action: {
                            viewModel.isShowingNewRoomDialog = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .font(.title2)
                                Text("Create New Room")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // Load room button
                        Button(action: {
                            viewModel.isShowingRoomSelector = true
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                    .font(.title2)
                                Text("Rooms List")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Available rooms section
                    if !viewModel.availableRooms.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Recent Rooms")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.bottom, 5)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(viewModel.availableRooms.prefix(5)) { room in
                                        RoomCardView(room: room, viewModel: viewModel, roomToDelete: $roomToDelete, showDeleteConfirmation: $showDeleteConfirmation)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingNewRoomDialog) {
                NewRoomDialogView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingRoomSelector) {
                RoomSelectorView(viewModel: viewModel, roomToDelete: $roomToDelete, showDeleteConfirmation: $showDeleteConfirmation)
            }
            // Separate delete confirmation alert sheet
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Room"),
                    message: Text("Are you sure you want to delete \(roomToDelete?.name ?? "this room")? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let room = roomToDelete {
                            // First dismiss the room selector to avoid presentation conflicts
                            viewModel.isShowingRoomSelector = false
                            
                            // Then delete after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.deleteRoom(room)
                            }
                        }
                        roomToDelete = nil
                    },
                    secondaryButton: .cancel {
                        roomToDelete = nil
                    }
                )
            }
            // Separate share sheet
            .sheet(isPresented: $viewModel.isSharing) {
                if let url = viewModel.shareURL {
                    ShareSheet(items: [url])
                }
            }
            .fullScreenCover(isPresented: $showARRoom) {
                ARRoomContainerView(viewModel: viewModel, isPresented: $showARRoom)
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("Notice"),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationBarHidden(true)
            .onChange(of: viewModel.shouldShowARRoom) { newValue in
                if newValue {
                    showARRoom = true
                    // Reset the flag after navigation
                    viewModel.shouldShowARRoom = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct RoomCardView: View {
    let room: RoomModel
    let viewModel: RoomViewModel
    @Binding var roomToDelete: RoomModel?
    @Binding var showDeleteConfirmation: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(room.name)
                .font(.headline)
                .foregroundColor(.white)
            Text(room.formattedDate)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(spacing: 20) {
                // Load button
                ActionButtonView(color: .blue, icon: "arrow.right.circle", label: "Load") {
                    viewModel.loadAndShowRoom(room)
                }
                
                // Share button
                ActionButtonView(color: .green, icon: "square.and.arrow.up", label: "Share") {
                    if let url = RoomService.shared.getFileURL(for: room) {
                        viewModel.shareRoom(url: url)
                    }
                }
                
                // Delete button
                ActionButtonView(color: .red, icon: "trash", label: "Delete") {
                    roomToDelete = room
                    showDeleteConfirmation = true
                }
            }
            .padding(.top, 5)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.2))
                .contentShape(Rectangle())
        )
        .frame(width: 150, height: 150)
    }
}

struct ActionButtonView: View {
    let color: Color
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 36, height: 50)
            
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

struct NewRoomDialogView: View {
    @ObservedObject var viewModel: RoomViewModel
    
    var body: some View {
        VStack {
            Text("Create New Room")
                .font(.headline)
                .padding()
            
            TextField("Room Name", text: $viewModel.newRoomName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            HStack {
                Button("Cancel") {
                    viewModel.isShowingNewRoomDialog = false
                }
                .padding()
                
                Spacer()
                
                Button("Start Recording") {
                    viewModel.startRecordingAndShowAR()
                }
                .padding()
                .disabled(viewModel.newRoomName.isEmpty)
            }
        }
        .padding()
    }
}

struct RoomSelectorView: View {
    @ObservedObject var viewModel: RoomViewModel
    @Binding var roomToDelete: RoomModel?
    @Binding var showDeleteConfirmation: Bool
    
    var body: some View {
        VStack {
            Text("Select Room")
                .font(.headline)
                .padding()
            
            if viewModel.availableRooms.isEmpty {
                Text("No rooms available")
                    .padding()
            } else {
                List {
                    ForEach(viewModel.availableRooms) { room in
                        RoomListItemView(room: room, viewModel: viewModel, roomToDelete: $roomToDelete, showDeleteConfirmation: $showDeleteConfirmation)
                    }
                }
            }
            
            Button("Cancel") {
                viewModel.isShowingRoomSelector = false
            }
            .padding()
        }
        .padding()
    }
}

struct RoomListItemView: View {
    let room: RoomModel
    let viewModel: RoomViewModel
    @Binding var roomToDelete: RoomModel?
    @Binding var showDeleteConfirmation: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(room.name)
                .font(.headline)
            Text(room.formattedDate)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                // Load button
                ListActionButtonView(color: .blue, icon: "arrow.right.circle", label: "Load") {
                    viewModel.loadAndShowRoom(room)
                    viewModel.isShowingRoomSelector = false
                }
                
                // Share button
                ListActionButtonView(color: .green, icon: "square.and.arrow.up", label: "Share") {
                    if let url = RoomService.shared.getFileURL(for: room) {
                        viewModel.shareRoom(url: url)
                    }
                }
                
                Spacer()
                
                // Delete button
                ListActionButtonView(color: .red, icon: "trash", label: "Delete") {
                    roomToDelete = room
                    showDeleteConfirmation = true
                }
            }
            .padding(.top, 5)
        }
        .padding(.vertical, 5)
    }
}

struct ListActionButtonView: View {
    let color: Color
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 30)
            
            HStack {
                Image(systemName: icon)
                Text(label)
            }
            .foregroundColor(.white)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .frame(maxWidth: 80)
    }
}

struct ARRoomContainerView: View {
    @ObservedObject var viewModel: RoomViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            ARRoomView()
                .environmentObject(viewModel)
            
            // Back button to return to main screen
            VStack {
                HStack {
                    Button(action: {
                        viewModel.exitCurrentMode()
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    MainView()
} 