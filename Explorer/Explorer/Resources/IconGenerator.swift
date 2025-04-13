import SwiftUI
import AppKit

// This file is used to generate app icons
// The generated icon shows a stylized folder with fast lines to represent speed

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

// Call this function to save icons of different sizes
func generateIcons() {
    let sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    let basePath = "/Users/debarghya/dev/playground/explorer/Explorer/Explorer/Resources"
    
    for size in sizes {
        let iconView = IconView(size: CGFloat(size))
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = 1.0 // Use the actual size we want
        
        if let nsImage = renderer.nsImage {
            if let tiffData = nsImage.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                
                let url = URL(fileURLWithPath: "\(basePath)/app-icon-\(size).png")
                do {
                    try pngData.write(to: url)
                    print("Saved icon of size \(size)x\(size)")
                } catch {
                    print("Failed to save icon of size \(size): \(error)")
                }
            }
        }
    }
    
    // Create an icns file using iconutil
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    task.arguments = ["-c", "icns", "\(basePath)/AppIcon.iconset"]
    
    do {
        try task.run()
        task.waitUntilExit()
        print("Created AppIcon.icns")
    } catch {
        print("Failed to create icns file: \(error)")
    }
}