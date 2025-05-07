import SwiftUI

struct MainView: View {
    // We'll use environment objects to share view models across the app
    @StateObject private var scanningViewModel = ScanningViewModel()
    @StateObject private var savedScansViewModel = SavedScansViewModel()
    
    var body: some View {
        TabView {
            // Scanning tab
            ScanningView()
                .environmentObject(scanningViewModel)
                .tabItem {
                    Label("Scan", systemImage: "scanner")
                }
            
            // Saved scans tab
            SavedScansView()
                .environmentObject(savedScansViewModel)
                .tabItem {
                    Label("Saved Scans", systemImage: "folder")
                }
        }
    }
}

#Preview {
    MainView()
} 