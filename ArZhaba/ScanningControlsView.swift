import SwiftUI

struct ScanningControlsView: View {
    @ObservedObject var viewModel: ScanningViewModel
    @State private var scanName: String = "Scan"
    @State private var showSaveDialog: Bool = false
    
    var body: some View {
        VStack {
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
                    .disabled(!viewModel.isScanningAvailable)
                    
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
                    .disabled(viewModel.meshAnchorsCount == 0)
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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Scan Details")) {
                    TextField("Scan Name", text: $scanName)
                }
                
                Section {
                    Button("Save Scan") {
                        if viewModel.saveScan(withName: scanName) {
                            // Close the dialog after saving
                            isPresented = false
                        }
                    }
                }
                
                Section {
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