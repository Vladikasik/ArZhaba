import SwiftUI
import ARKit

struct ARRoomView: View {
    @EnvironmentObject var viewModel: SphereAnchorViewModel
    
    var body: some View {
        ZStack {
            // AR View
            ARSphereView()
                .edgesIgnoringSafeArea(.all)
            
            // Status message
            VStack {
                Text(viewModel.statusMessage)
                    .font(.footnote)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 20)
                
                Spacer()
                
                // Control buttons
                HStack {
                    if viewModel.sessionState == .recording {
                        // Stop recording button
                        Button(action: {
                            viewModel.stopRecording()
                        }) {
                            VStack {
                                Image(systemName: "stop.circle")
                                    .font(.system(size: 30))
                                Text("Stop")
                                    .font(.caption)
                            }
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(15)
                        }
                        
                        Spacer()
                        
                        // Current room indicator
                        if let roomName = viewModel.currentRoom?.name {
                            VStack {
                                Image(systemName: "building.2")
                                    .font(.system(size: 24))
                                Text("Room: \(roomName)")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(15)
                        }
                    } else if viewModel.sessionState == .viewing {
                        // Current room indicator
                        if let roomName = viewModel.currentRoom?.name {
                            VStack {
                                Image(systemName: "eye")
                                    .font(.system(size: 24))
                                Text("Viewing: \(roomName)")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(15)
                        }
                    }
                }
                .padding()
            }
            .padding()
            
            // Color selector for recording mode
            if viewModel.sessionState == .recording {
                VStack {
                    Spacer()
                    
                    HStack {
                        ForEach(0..<viewModel.colorOptions.count, id: \.self) { index in
                            Button(action: {
                                viewModel.selectedColorIndex = index
                            }) {
                                Circle()
                                    .fill(viewModel.getSwiftUIColor(for: index))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                viewModel.selectedColorIndex == index ? Color.white : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .padding(3)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(15)
                    .padding(.bottom, 100)
                }
            }
        }
    }
} 