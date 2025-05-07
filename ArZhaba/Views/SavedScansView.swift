import SwiftUI
import QuickLook
import SceneKit

struct SavedScansView: View {
    @EnvironmentObject var viewModel: SavedScansViewModel
    @State private var showDeleteConfirmation = false
    @State private var scanToDelete: ScanModel? = nil
    @State private var showPreview = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading scans...")
                } else if viewModel.scans.isEmpty {
                    ContentUnavailableView(
                        "No Saved Scans",
                        systemImage: "cube.transparent",
                        description: Text("Your saved scans will appear here.")
                    )
                } else {
                    List {
                        ForEach(viewModel.scans) { scan in
                            ScanRowView(
                                scan: scan,
                                onPreview: {
                                    viewModel.selectedScan = scan
                                    showPreview = true
                                },
                                onDelete: {
                                    scanToDelete = scan
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    }
                }
            }
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
            .onAppear {
                viewModel.loadScans()
            }
            .sheet(isPresented: $showPreview) {
                if let scan = viewModel.selectedScan {
                    ScanPreviewView(url: scan.fileURL)
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("ArZhaba"),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .confirmationDialog(
                "Delete Scan",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let scan = scanToDelete {
                        _ = viewModel.deleteScan(scan)
                    }
                }
                Button("Cancel", role: .cancel) {
                    scanToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this scan?")
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