import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = RoomViewModel()
    @State private var showARRoom = false
    
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
                        
                        // Navigate to rooms list
                        NavigationLink(destination: SwipeableRoomListView(viewModel: viewModel)) {
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
                }
            }
            .sheet(isPresented: $viewModel.isShowingNewRoomDialog) {
                NewRoomDialogView(viewModel: viewModel)
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