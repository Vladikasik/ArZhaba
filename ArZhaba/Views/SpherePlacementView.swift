import SwiftUI
import ARKit

struct SpherePlacementView: View {
    @StateObject private var viewModel = SphereAnchorViewModel()
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // AR View to display the world and sphere anchors
            ARSphereView()
                .environmentObject(viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // Status overlay at the top
            VStack {
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 20)
                
                Spacer()
                
                // Bottom control panel
                VStack(spacing: 15) {
                    // Selected color indicator
                    Circle()
                        .fill(viewModel.selectedSwiftUIColor)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 2)
                    
                    // User instructions
                    Text("Tap anywhere to place a sphere")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Text("Long press on a sphere to remove it")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        // Save world map button
                        Button(action: {
                            viewModel.saveWorldMap()
                        }) {
                            VStack {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 22))
                                Text("Save")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        
                        // Settings button
                        Button(action: {
                            showSettings.toggle()
                        }) {
                            VStack {
                                Image(systemName: "gear")
                                    .font(.system(size: 22))
                                Text("Settings")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(10)
                        }
                        
                        // Clear all button
                        Button(action: {
                            viewModel.clearAllSpheres()
                        }) {
                            VStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 22))
                                Text("Clear")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
                .padding(.bottom, 20)
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("AR Sphere Placement"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SphereAnchorViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var sliderValue: Float = 0.025
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sphere Size")) {
                    VStack {
                        HStack {
                            Text("Radius: \(viewModel.sphereRadius, specifier: "%.3f") m")
                            Spacer()
                            Text("\(Int(viewModel.sphereRadius * 100))cm")
                        }
                        
                        Slider(value: $viewModel.sphereRadius, in: 0.01...0.1, step: 0.005) {
                            Text("Sphere Radius")
                        }
                    }
                }
                
                Section(header: Text("Sphere Color")) {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 60))
                    ], spacing: 10) {
                        ForEach(0..<viewModel.colorOptions.count, id: \.self) { index in
                            ColorButton(
                                color: viewModel.getSwiftUIColor(for: index),
                                isSelected: index == viewModel.selectedColorIndex
                            )
                            .onTapGesture {
                                viewModel.selectedColorIndex = index
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 50, height: 50)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 3 : 1)
            )
            .shadow(radius: isSelected ? 3 : 1)
    }
}

struct SpherePlacementView_Previews: PreviewProvider {
    static var previews: some View {
        SpherePlacementView()
    }
} 