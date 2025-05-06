import SwiftUI
import QuickLook
import SceneKit

struct SavedScansView: View {
    @State private var scans: [URL] = []
    @State private var refreshTrigger = false
    @State private var selectedScan: URL? = nil
    @State private var showPreview: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var scanToDelete: URL? = nil
    
    var body: some View {
        NavigationView {
            List {
                if scans.isEmpty {
                    Text("No saved scans found")
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    ForEach(scans, id: \.path) { scanURL in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(scanURL.lastPathComponent)
                                    .font(.headline)
                                
                                Text("Type: \(scanURL.pathExtension.uppercased())")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                if let creationDate = getCreationDate(for: scanURL) {
                                    Text("Created: \(dateFormatter.string(from: creationDate))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                selectedScan = scanURL
                                showPreview = true
                            }) {
                                Image(systemName: "eye.fill")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 8)
                            
                            Button(action: {
                                scanToDelete = scanURL
                                showDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Saved Scans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        refreshScans()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                refreshScans()
            }
            .onChange(of: refreshTrigger) { _, _ in
                refreshScans()
            }
            .sheet(isPresented: $showPreview) {
                if let url = selectedScan {
                    ScanPreviewController(url: url)
                }
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Scan"),
                    message: Text("Are you sure you want to delete this scan?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let scanURL = scanToDelete {
                            deleteScan(scanURL)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func refreshScans() {
        scans = ScanFileManager.shared.getSavedScans().sorted { url1, url2 in
            if let date1 = getCreationDate(for: url1), let date2 = getCreationDate(for: url2) {
                return date1 > date2
            }
            return url1.lastPathComponent > url2.lastPathComponent
        }
    }
    
    private func deleteScan(_ url: URL) {
        if ScanFileManager.shared.deleteScan(at: url) {
            refreshTrigger.toggle()
        }
    }
    
    private func getCreationDate(for url: URL) -> Date? {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.creationDate] as? Date
        } catch {
            print("Error getting file creation date: \(error.localizedDescription)")
            return nil
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

// QuickLook preview controller for 3D models
struct ScanPreviewController: UIViewControllerRepresentable {
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