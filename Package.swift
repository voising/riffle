// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AltTab",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AltTab",
            path: "Sources/AltTab"
        )
    ]
)
