import SwiftUI
import AVFoundation

struct ScanningView: View {
    @EnvironmentObject var viewModel: ScanningViewModel
    @State private var showSaveDialog = false
    @State private var scanName = "Scan"
    
    var body: some View {
        ZStack {
            // AR view for scanning
            ARScanView()
                .edgesIgnoringSafeArea(.all)
            
            // Overlay controls
            ScanningControlsView(
                showSaveDialog: $showSaveDialog,
                scanName: $scanName
            )
        }
        .onAppear {
            // Check permission for camera
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    viewModel.alertMessage = "Camera access is required for scanning"
                    viewModel.showAlert = true
                }
            }
        }
        .onDisappear {
            // Make sure scanning stops when leaving this view
            viewModel.stopScanning()
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("ArZhaba"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showSaveDialog) {
            SaveScanView(isPresented: $showSaveDialog, scanName: $scanName)
        }
    }
}

struct ScanningControlsView: View {
    @EnvironmentObject var viewModel: ScanningViewModel
    @Binding var showSaveDialog: Bool
    @Binding var scanName: String
    
    var body: some View {
        ZStack {
            // Status bar at the top
            VStack {
                Spacer().frame(height: 50) // For safe area
                
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(height: 50)
                    
                    HStack {
                        Text(viewModel.scanSession.statusMessage)
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.leading)
                        
                        Spacer()
                        
                        if viewModel.scanSession.state == .scanning {
                            Text(viewModel.scanSession.formattedDuration)
                                .foregroundColor(.white)
                                .font(.subheadline)
                                .monospacedDigit()
                                .padding(.trailing)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Loading indicator
            if viewModel.scanSession.state == .initializing {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                        .padding()
                    
                    Text("Initializing camera...")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding()
                }
                .padding(40)
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
            }
            
            // Progress bar during scanning
            if viewModel.scanSession.state == .scanning {
                VStack {
                    ProgressView(value: viewModel.scanSession.scanProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal)
                    
                    Text("Mesh Anchors: \(viewModel.scanSession.meshAnchorsCount)")
                        .foregroundColor(.white)
                        .font(.caption)
                        .padding(.top, 5)
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
                .padding(.top, 150)
            }
            
            // Bottom control bar
            VStack {
                Spacer()
                
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(height: 100)
                    
                    HStack(spacing: 30) {
                        // Start/Stop Button
                        Button(action: {
                            if viewModel.scanSession.state == .scanning {
                                viewModel.stopScanning()
                            } else {
                                viewModel.startScanning()
                            }
                        }) {
                            Image(systemName: viewModel.scanSession.state == .scanning ? "stop.circle.fill" : "play.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(viewModel.scanSession.state == .scanning ? .red : .green)
                        }
                        .disabled(!viewModel.isScanningAvailable || viewModel.scanSession.state == .initializing)
                        
                        // Save Button
                        Button(action: {
                            // Only show save dialog if we have scan data
                            if viewModel.scanSession.meshAnchorsCount > 0 {
                                showSaveDialog = true
                            } else {
                                viewModel.alertMessage = "No scan data to save"
                                viewModel.showAlert = true
                            }
                        }) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                        }
                        .disabled(viewModel.scanSession.meshAnchorsCount == 0 || viewModel.scanSession.state == .initializing)
                        
                        // Share button (only visible after saving)
                        if viewModel.lastSavedURL != nil {
                            Button(action: {
                                // Get UIViewController to present share sheet
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootViewController = windowScene.windows.first?.rootViewController {
                                    viewModel.shareScan(from: rootViewController) { _ in }
                                }
                            }) {
                                if viewModel.isSharing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "square.and.arrow.up.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(viewModel.isSharing)
                        }
                    }
                }
            }
        }
    }
}

struct SaveScanView: View {
    @EnvironmentObject var viewModel: ScanningViewModel
    @Binding var isPresented: Bool
    @Binding var scanName: String
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Scan Details")) {
                    TextField("Scan Name", text: $scanName)
                }
                
                Section {
                    Button(action: {
                        if viewModel.saveScan(withName: scanName) {
                            // Close the dialog after saving
                            isPresented = false
                        }
                    }) {
                        if viewModel.isSaving {
                            HStack {
                                Text("Saving...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Text("Save Scan")
                        }
                    }
                    .disabled(scanName.isEmpty || viewModel.isSaving)
                }
                
                Section(footer: Text("After saving, use the Share button to export to Files app")) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Save Scan")
        }
    }
}

#Preview {
    ScanningView()
        .environmentObject(ScanningViewModel())
} 