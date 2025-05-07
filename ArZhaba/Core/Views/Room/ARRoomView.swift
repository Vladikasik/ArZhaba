import SwiftUI
import ARKit

struct ARRoomView: View {
    @EnvironmentObject var viewModel: RoomViewModel
    @State private var fileSize: Double = 0
    @State private var isFileSizeWarning: Bool = false
    
    var body: some View {
        ZStack {
            // AR View
            ARSphereView()
                .edgesIgnoringSafeArea(.all)
            
            // Status message and file size
            VStack {
                VStack(spacing: 4) {
                    Text(viewModel.statusMessage)
                        .font(.footnote)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    
                    // File size indicator
                    if viewModel.sessionState == .recording {
                        HStack {
                            Text("File size: \(formatFileSize(fileSize))")
                                .font(.footnote)
                            
                            if isFileSizeWarning {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(5)
                        .background(isFileSizeWarning ? Color.orange.opacity(0.6) : Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Control buttons
                HStack {
                    if viewModel.sessionState == .recording {
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
            
            // Loading overlay
            if viewModel.isLoading || viewModel.sessionState == .loading {
                LoadingOverlayView(progress: viewModel.loadingProgress, message: viewModel.loadingMessage)
            }
        }
        .onAppear {
            // Start monitoring file size
            startMonitoringFileSize()
        }
    }
    
    // MARK: - Private Methods
    
    private func startMonitoringFileSize() {
        // Check file size periodically
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            if let room = viewModel.currentRoom,
               FileManager.default.fileExists(atPath: room.worldMapURL.path) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: room.worldMapURL.path)
                    if let size = attributes[.size] as? NSNumber {
                        self.fileSize = size.doubleValue
                        
                        // Warn if file size gets too large
                        self.isFileSizeWarning = self.fileSize > 10_000_000 // 10MB warning
                    }
                } catch {
                    print("Error getting file size: \(error)")
                }
            }
        }
    }
    
    /// Format the file size for display
    private func formatFileSize(_ size: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

struct LoadingOverlayView: View {
    let progress: Double
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text(message.isEmpty ? "Loading room..." : message)
                    .font(.title2)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Improved progress bar
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 15)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .cyan]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(20, 200 * CGFloat(progress)), height: 15)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
                .frame(width: 200)
                
                // Progress percentage
                Text("\(Int(progress * 100))%")
                    .foregroundColor(.white)
                    .font(.headline)
                
                // Instructions based on loading stage
                if progress < 0.8 {
                    Text("Move your device around slowly to help relocalize in the environment")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Almost done! Finalizing room setup...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(UIColor.darkGray).opacity(0.8))
                    .shadow(radius: 10)
            )
        }
        .transition(.opacity)
        .animation(.easeInOut, value: progress)
    }
} 