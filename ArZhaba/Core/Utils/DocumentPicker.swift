import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A UIViewControllerRepresentable that wraps UIDocumentPickerViewController to select directories
struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Configure picker to select directories
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No update needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Get permission to access the URL
            let securityScoped = url.startAccessingSecurityScopedResource()
            
            // Create a bookmark for persistent access (needed for directories)
            do {
                let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                // Store the bookmark data in user defaults for potential later use
                UserDefaults.standard.set(bookmarkData, forKey: "RoomImportBookmark")
                
                // Call the callback with the URL
                parent.onPick(url)
            } catch {
                print("Failed to create bookmark: \(error)")
                
                // Still try to use the URL directly even if bookmark creation failed
                parent.onPick(url)
            }
            
            // Release the security-scoped resource
            if securityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
} 