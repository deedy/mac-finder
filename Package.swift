// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Explorer",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Explorer", targets: ["Explorer"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Explorer",
            dependencies: [])
    ]
)