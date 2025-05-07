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
            
            // Top status bar
            VStack {
                Spacer().frame(height: 50) // For safe area
                
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(height: 50)
                    
                    HStack {
                        Text(viewModel.scanSession.state == .scanning ? "Scanning in progress" : "Tap to place spheres")
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
                
                // Mesh Anchors counter
                if viewModel.scanSession.state == .scanning {
                    Text("Mesh Anchors: \(viewModel.scanSession.meshAnchorsCount)")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Bottom control bar
                HStack(spacing: 30) {
                    // Scan button
                    Button(action: {
                        if viewModel.scanSession.state == .scanning {
                            viewModel.stopScanning()
                        } else {
                            viewModel.startScanning()
                        }
                    }) {
                        Circle()
                            .fill(viewModel.scanSession.state == .scanning ? Color.red : Color.blue)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: viewModel.scanSession.state == .scanning ? "stop.fill" : "record.circle")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Place Spheres button
                    Button(action: {
                        viewModel.toggleSphereMode()
                    }) {
                        VStack {
                            Image(systemName: "circle.grid.3x3.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .foregroundColor(.yellow)
                            Text("Place Spheres")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Save button
                    Button(action: {
                        showSaveDialog = true
                    }) {
                        Image(systemName: "arrow.down.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(15)
                .padding(.bottom, 20)
            }
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

struct SaveScanView: View {
    @EnvironmentObject var viewModel: ScanningViewModel
    @Binding var isPresented: Bool
    @Binding var scanName: String
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter scan name")) {
                    TextField("Scan name", text: $scanName)
                }
                
                Section {
                    Button("Save Scan") {
                        if viewModel.saveScan(withName: scanName) {
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("Save Scan")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    ScanningView()
        .environmentObject(ScanningViewModel())
} 