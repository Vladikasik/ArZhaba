import SwiftUI

struct ScanningControlsView: View {
    @ObservedObject var viewModel: ScanningViewModel
    @State private var scanName: String = "Scan"
    @State private var showSaveDialog: Bool = false
    @State private var isExporting: Bool = false
    
    var body: some View {
        ZStack {
            // Status bar at the top
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.7))
                    .frame(height: 50)
                
                HStack {
                    Text(viewModel.currentStatusMessage)
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(.leading)
                    
                    Spacer()
                    
                    if viewModel.isScanning {
                        Text(timeString(from: viewModel.scanningTime))
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .monospacedDigit()
                            .padding(.trailing)
                    }
                }
            }
            
            Spacer()
            
            // Loading indicator
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                        .padding()
                    
                    Text("Initializing camera...")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding()
                    
                    Button("Continue") {
                        viewModel.cancelLoading()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(40)
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
            }
            
            // Progress bar
            if viewModel.isScanning {
                VStack {
                    ProgressView(value: viewModel.scanProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal)
                    
                    Text("Mesh Anchors: \(viewModel.meshAnchorsCount)")
                        .foregroundColor(.white)
                        .font(.caption)
                        .padding(.top, 5)
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
            }
            
            // Bottom control bar
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.7))
                    .frame(height: 80)
                
                HStack(spacing: 30) {
                    // Start/Stop Button
                    Button(action: {
                        if viewModel.isScanning {
                            viewModel.stopScanning()
                        } else {
                            viewModel.startScanning()
                        }
                    }) {
                        Image(systemName: viewModel.isScanning ? "stop.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(viewModel.isScanning ? .red : .green)
                    }
                    .disabled(!viewModel.isScanningAvailable || viewModel.isLoading)
                    
                    // Save Button
                    Button(action: {
                        // Only show save dialog if we have scan data
                        if viewModel.meshAnchorsCount > 0 {
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
                    .disabled(viewModel.meshAnchorsCount == 0 || viewModel.isLoading)
                    
                    // Export to Files app button (only visible after saving)
                    if viewModel.lastSavedURL != nil {
                        Button(action: {
                            isExporting = true
                            viewModel.exportLastSavedScan { success in
                                isExporting = false
                            }
                        }) {
                            if isExporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("ArZhaba"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showSaveDialog) {
            SaveScanView(viewModel: viewModel, scanName: $scanName, isPresented: $showSaveDialog)
        }
    }
    
    // Helper function to format scanning time
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

// View for saving a scan
struct SaveScanView: View {
    @ObservedObject var viewModel: ScanningViewModel
    @Binding var scanName: String
    @Binding var isPresented: Bool
    @State private var isSaving: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Scan Details")) {
                    TextField("Scan Name", text: $scanName)
                }
                
                Section {
                    Button(action: {
                        isSaving = true
                        if viewModel.saveScan(withName: scanName) {
                            // Close the dialog after saving
                            isPresented = false
                        }
                        isSaving = false
                    }) {
                        if isSaving {
                            HStack {
                                Text("Saving...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Text("Save Scan")
                        }
                    }
                    .disabled(scanName.isEmpty || isSaving)
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