# ArZhaba

ArZhaba is an AR iOS application for creating, viewing, and sharing spatial anchors in augmented reality. The app leverages ARKit and LiDAR sensors to enable users to create rooms with persistent AR content.

## Features

- **Room Creation**: Create and manage AR rooms with spatial anchors
- **Sphere Anchors**: Place colored spheres in the AR environment
- **Persistent AR**: Save and restore AR content across sessions
- **Real-time Visualization**: See anchors in real-time
- **Save & Manage Rooms**: Create, load, and delete AR rooms
- **Share Functionality**: Share rooms with others

## Requirements

- iPhone or iPad with ARKit support (iPhone X or newer)
- iOS 14.0 or later
- LiDAR sensor recommended for best experience (iPhone 12 Pro, iPad Pro 2020, or newer)
- Xcode 14.0 or later (for development)

## Installation

### From Source

1. Clone this repository
2. Open ArZhaba.xcworkspace in Xcode
3. Set your development team in the Signing & Capabilities tab
4. Build and run on a compatible device

## Architecture

The app has been restructured to follow a clean MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: Data structures for rooms and AR anchors
- **Views**: SwiftUI views for the user interface
- **ViewModels**: Business logic and state management
- **Services**: Core functionality for AR session and room management
- **Utils**: Helper utilities like sharing functionality

## Project Structure

```
├── ArZhaba/
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── RoomModel.swift        # Data model for saved AR rooms
│   │   │   ├── SphereAnchor.swift     # Custom AR anchor for spheres
│   │   │   └── ARSessionState.swift   # AR session state enum
│   │   ├── Services/
│   │   │   ├── RoomService.swift      # Room management functionality
│   │   │   └── ARAnchorService.swift  # AR anchor and session management
│   │   ├── ViewModels/
│   │   │   └── RoomViewModel.swift    # Coordinates room and AR functionality
│   │   ├── Views/
│   │   │   ├── Components/
│   │   │   │   └── ARSphereView.swift # AR sphere rendering component
│   │   │   ├── Main/
│   │   │   │   └── MainView.swift     # Main app interface
│   │   │   └── Room/
│   │   │       └── ARRoomView.swift   # AR room visualization
│   │   └── Utils/
│   │       └── ShareSheet.swift       # Sharing functionality
│   ├── Assets.xcassets/               # App assets
│   ├── AppDelegate.swift              # App initialization
│   └── Preview Content/               # SwiftUI previews
├── Documentation/
│   ├── Archive/                       # Project documentation
│   └── Trash/                         # Legacy code for reference
├── Pods/                              # CocoaPods dependencies
├── Podfile                            # CocoaPods configuration
└── ArZhaba.xcworkspace                # Xcode workspace
```

## Usage Guide

### Creating a Room

1. Open the app and tap "Create New Room"
2. Enter a name for your room
3. Tap "Start Recording"
4. The AR session will begin, allowing you to place spheres

### Placing Spheres

1. In recording mode, tap anywhere in the AR view to place a sphere
2. Use the color selector at the bottom to change sphere colors
3. Long press on a sphere to remove it

### Managing Rooms

1. Tap "Rooms List" to see all saved rooms
2. Tap "Load" on a room to restore its AR content
3. Tap "Share" to share a room with others
4. Tap "Delete" to remove a room

## Architectural Components

### Models

- **RoomModel**: Represents a saved AR room with world map and anchors
- **SphereAnchor**: Custom AR anchor for spheres with color and radius properties
- **ARSessionState**: Enum representing different states of the AR session

### Services

- **RoomService**: Manages room creation, loading, saving, and deletion
- **ARAnchorService**: Handles AR session management and anchor placement

### ViewModels

- **RoomViewModel**: Coordinates between views and services, managing room and AR state

### Views

- **MainView**: Main interface with room creation and selection
- **ARRoomView**: AR interface for room visualization and interaction
- **ARSphereView**: Renders spheres in the AR environment

### Utils

- **ShareSheet**: Enables sharing of room data with others

## License

This project is open source, available under the MIT license.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 