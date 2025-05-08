import SwiftUI

struct SwipeableRoomListView: View {
    @ObservedObject var viewModel: RoomViewModel
    @State private var showDeleteConfirmation = false
    @State private var roomToDelete: RoomModel? = nil
    @State private var showDocumentPicker = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Rooms")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
            
            if viewModel.availableRooms.isEmpty {
                Text("No rooms available")
                    .foregroundColor(.white)
                    .padding()
            } else {
                List {
                    ForEach(viewModel.availableRooms) { room in
                        RoomSwipeableCell(room: room, viewModel: viewModel, dismiss: {
                            presentationMode.wrappedValue.dismiss()
                        })
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                if let url = RoomService.shared.getFileURL(for: room) {
                                    viewModel.shareRoomSwipe(url: url)
                                    // Dismiss this view to allow share sheet to appear
                                    presentationMode.wrappedValue.dismiss()
                                }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                roomToDelete = room
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            
            HStack {
                Button("Load Room") {
                    showDocumentPicker = true
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.green)
                .cornerRadius(10)
                
                Spacer()
                
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Room"),
                message: Text("Are you sure you want to delete \(roomToDelete?.name ?? "this room")? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let room = roomToDelete {
                        viewModel.deleteRoomSwipe(room)
                    }
                    roomToDelete = nil
                },
                secondaryButton: .cancel {
                    roomToDelete = nil
                }
            )
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                viewModel.importRoomFromDirectory(url: url)
                // Dismiss this view to allow AR view to be presented
                presentationMode.wrappedValue.dismiss()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct RoomSwipeableCell: View {
    let room: RoomModel
    let viewModel: RoomViewModel
    let dismiss: () -> Void
    
    var body: some View {
        Button(action: {
            // First dismiss this view so AR view can be presented
            dismiss()
            
            // Then trigger AR view with a slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.loadAndShowRoomSwipe(room)
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(room.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(room.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    SwipeableRoomListView(viewModel: RoomViewModel())
} 