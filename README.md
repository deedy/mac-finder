# Explorer

A fast, native macOS Finder alternative built with SwiftUI.

## Features

- Fast file browsing and searching
- Modern SwiftUI interface
- Sidebar with quick access locations
- Column-based file listing with sorting options
- File preview support
- Create new folders
- Double-click to open files with default applications

## Building the App

To build and run the app, use the included script:

```bash
./build_and_run.sh
```

This will:
1. Build the project in release mode
2. Create a macOS app bundle
3. Launch the app

## Requirements

- macOS 13.0 or later
- Swift 6.0 or later

## Development

This app is built using:
- Swift Package Manager for dependency management
- SwiftUI for the user interface
- Foundation and AppKit frameworks for file system operations

## Performance Optimizations

The app includes several optimizations for speed:
- Asynchronous file loading with background threads
- Efficient file enumeration using FileManager
- Lazy loading of resources
- Proper caching of file attributes