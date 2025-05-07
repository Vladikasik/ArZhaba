import SwiftUI

struct MainView: View {
    @StateObject private var sphereAnchorViewModel = SphereAnchorViewModel()
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
                            sphereAnchorViewModel.isShowingNewRoomDialog = true
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
                            sphereAnchorViewModel.isShowingRoomSelector = true
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                    .font(.title2)
                                Text("Load Existing Room")
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
                    if !sphereAnchorViewModel.availableRooms.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Recent Rooms")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.bottom, 5)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(sphereAnchorViewModel.availableRooms.prefix(5)) { room in
                                        Button(action: {
                                            // Load this room
                                            sphereAnchorViewModel.loadRoom(room)
                                            showARRoom = true
                                        }) {
                                            VStack(alignment: .leading) {
                                                Text(room.name)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                Text(room.formattedDate)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            .padding()
                                            .frame(width: 150, height: 100)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(10)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                }
            }
            .sheet(isPresented: $sphereAnchorViewModel.isShowingNewRoomDialog) {
                // New room dialog
                VStack {
                    Text("Create New Room")
                        .font(.headline)
                        .padding()
                    
                    TextField("Room Name", text: $sphereAnchorViewModel.newRoomName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    HStack {
                        Button("Cancel") {
                            sphereAnchorViewModel.isShowingNewRoomDialog = false
                        }
                        .padding()
                        
                        Spacer()
                        
                        Button("Start Recording") {
                            sphereAnchorViewModel.startRecording()
                            showARRoom = true  // Navigate to AR view after creating room
                        }
                        .padding()
                        .disabled(sphereAnchorViewModel.newRoomName.isEmpty)
                    }
                }
                .padding()
            }
            .sheet(isPresented: $sphereAnchorViewModel.isShowingRoomSelector) {
                // Room selector
                VStack {
                    Text("Select Room")
                        .font(.headline)
                        .padding()
                    
                    if sphereAnchorViewModel.availableRooms.isEmpty {
                        Text("No rooms available")
                            .padding()
                    } else {
                        List {
                            ForEach(sphereAnchorViewModel.availableRooms) { room in
                                Button(action: {
                                    sphereAnchorViewModel.loadRoom(room)
                                    sphereAnchorViewModel.isShowingRoomSelector = false
                                    showARRoom = true  // Navigate to AR view after loading room
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(room.name)
                                                .font(.headline)
                                            Text(room.formattedDate)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(.blue)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Swipe to delete
                                .swipeActions {
                                    Button(role: .destructive) {
                                        sphereAnchorViewModel.deleteRoom(room)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    Button("Cancel") {
                        sphereAnchorViewModel.isShowingRoomSelector = false
                    }
                    .padding()
                }
                .padding()
            }
            .fullScreenCover(isPresented: $showARRoom) {
                // AR Room view with a way to return to main screen
                ZStack {
                    ARRoomView()
                        .environmentObject(sphereAnchorViewModel)
                    
                    // Back button to return to main screen
                    VStack {
                        HStack {
                            Button(action: {
                                // Return to idle state and go back to main view
                                if sphereAnchorViewModel.sessionState == .recording {
                                    _ = sphereAnchorViewModel.stopRecording()
                                } else if sphereAnchorViewModel.sessionState == .viewing {
                                    sphereAnchorViewModel.returnToIdle()
                                }
                                showARRoom = false
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
            .alert(isPresented: $sphereAnchorViewModel.showAlert) {
                Alert(
                    title: Text("Message"),
                    message: Text(sphereAnchorViewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    MainView()
} 