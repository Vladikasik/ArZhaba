//
//  ContentView.swift
//  ArZhaba
//
//  Created by Vladislav Ainshtein on 06.05.25.
//

import SwiftUI
import RealityKit
import AVFoundation

struct ContentView : View {
    // Use the global view model instance from AppDelegate
    @ObservedObject private var scanningViewModel = globalScanningViewModel
    
    var body: some View {
        TabView {
            ScanningView(viewModel: scanningViewModel)
                .tabItem {
                    Label("Scan", systemImage: "scanner")
                }
            
            SavedScansView()
                .tabItem {
                    Label("Saved Scans", systemImage: "folder")
                }
        }
    }
}

struct ScanningView: View {
    @ObservedObject var viewModel: ScanningViewModel
    
    var body: some View {
        ZStack {
            // AR view for scanning
            ARScanView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay controls
            ScanningControlsView(viewModel: viewModel)
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
    }
}

#Preview {
    ContentView()
}
