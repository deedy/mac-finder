#!/usr/bin/env swift

import SwiftUI
import AppKit

// This script generates app icons for Explorer

// Icon design showing a stylized folder with speed lines
struct IconView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.5, blue: 0.9),
                    Color(red: 0.2, green: 0.3, blue: 0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(size * 0.22)
            
            // Folder shape
            ZStack {
                // Folder back
                RoundedRectangle(cornerRadius: size * 0.06)
                    .fill(Color.white.opacity(0.20))
                    .frame(width: size * 0.7, height: size * 0.6)
                    .offset(y: size * 0.05)
                
                // Folder tab
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.white.opacity(0.20))
                    .frame(width: size * 0.3, height: size * 0.08)
                    .offset(x: -size * 0.2, y: -size * 0.22)
            }
            
            // Speed lines
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: size * 0.01)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: size * 0.4, height: size * 0.025)
                    .rotationEffect(.degrees(-10))
                    .offset(x: size * 0.18, y: size * CGFloat(i) * 0.12 - size * 0.12)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.3), radius: size * 0.05, x: 0, y: size * 0.02)
    }
}

// Generate and save the icon
func generateIcon() {
    let basePath = FileManager.default.currentDirectoryPath
    let iconsetPath = "\(basePath)/AppIcon.iconset"
    
    // Create iconset directory
    try? FileManager.default.createDirectory(atPath: iconsetPath, 
                                            withIntermediateDirectories: true)
    
    // Icon sizes required for macOS
    let sizes = [16, 32, 128, 256, 512, 1024]
    
    for size in sizes {
        // Create 1x and 2x versions
        for scale in [1, 2] {
            let scaledSize = size * scale
            let suffix = scale == 2 ? "@2x" : ""
            let filename = "icon_\(size)x\(size)\(suffix).png"
            
            let iconView = IconView(size: CGFloat(scaledSize))
            let nsView = NSHostingView(rootView: iconView)
            nsView.frame = CGRect(x: 0, y: 0, width: scaledSize, height: scaledSize)
            
            // Create bitmap representation
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: scaledSize,
                pixelsHigh: scaledSize,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )!
            
            bitmap.size = NSSize(width: scaledSize, height: scaledSize)
            nsView.layer?.render(in: NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext)
            
            if let data = bitmap.representation(using: .png, properties: [:]) {
                let filepath = "\(iconsetPath)/icon_\(size)x\(size)\(suffix).png"
                try? data.write(to: URL(fileURLWithPath: filepath))
                print("Generated \(filepath)")
            }
        }
    }
    
    // Create icns file from iconset using the iconutil command
    let appIconsPath = "\(basePath)/AppIcon.icns"
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetPath]
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    
    do {
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            print("Successfully created AppIcon.icns")
            
            // Copy to Explorer Resources
            try? FileManager.default.copyItem(
                atPath: appIconsPath,
                toPath: "\(basePath)/../Explorer.app/Contents/Resources/AppIcon.icns")
            print("Copied to Explorer.app/Contents/Resources/")
        } else {
            print("Failed to create .icns file: process exited with code \(process.terminationStatus)")
        }
    } catch {
        print("Error running iconutil: \(error)")
    }
}

// Run the generator
generateIcon()