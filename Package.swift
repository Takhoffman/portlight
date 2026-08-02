// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Portlight",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Portlight", targets: ["Portlight"])
    ],
    targets: [
        .executableTarget(
            name: "Portlight",
            path: "Sources/Portlight"
        )
    ]
)
