import SwiftUI
import QuickLook
import SceneKit

struct SavedScansView: View {
    @EnvironmentObject var viewModel: SavedScansViewModel
    
    var body: some View {
        NavigationView {
            List {
                // Display loading indicator
                if viewModel.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Loading saved scans...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                
                // Display empty state message
                if !viewModel.isLoading && viewModel.scans.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                Text("No Saved Scans")
                                    .font(.headline)
                                Text("Use the 'Scan' tab to create and save scans")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            Spacer()
                        }
                    }
                }
                
                // List of saved scans
                ForEach(viewModel.scans) { scan in
                    Section {
                        VStack(alignment: .leading) {
                            Text(scan.name)
                                .font(.headline)
                            
                            HStack {
                                Text("Created: \(scan.formattedDate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // Load button
                                Button(action: {
                                    viewModel.loadScan(scan)
                                }) {
                                    Text("Load")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                
                                // Delete button
                                Button(action: {
                                    withAnimation {
                                        _ = viewModel.deleteScan(scan)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .padding(.leading, 10)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Saved Scans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.loadScans()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                viewModel.loadScans()
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("Saved Scans"),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct ScanRowView: View {
    let scan: ScanModel
    let onPreview: () -> Void
    let onDelete: () -> Void
    @State private var isSharing = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(scan.displayName)
                    .font(.headline)
                
                Text("Type: \(scan.fileExtension.uppercased())")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Created: \(scan.formattedDate)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Size: \(scan.formattedSize)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                // Share button
                Button(action: {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        isSharing = true
                        ScanFileService.shared.shareScan(url: scan.fileURL, from: rootViewController) { _ in
                            isSharing = false
                        }
                    }
                }) {
                    if isSharing {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .imageScale(.large)
                            .foregroundColor(.blue)
                    }
                }
                .disabled(isSharing)
                
                // Preview button
                Button(action: onPreview) {
                    Image(systemName: "eye")
                        .imageScale(.large)
                        .foregroundColor(.blue)
                }
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .imageScale(.large)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ScanPreviewView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        
        init(url: URL) {
            self.url = url
            super.init()
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
    }
}

#Preview {
    SavedScansView()
        .environmentObject(SavedScansViewModel())
} 