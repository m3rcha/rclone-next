// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RcloneNext",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "RcloneNext",
            path: "Sources/RcloneNext",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "RcloneNextTests",
            dependencies: ["RcloneNext"],
            path: "Tests/RcloneNextTests"
        ),
    ]
)
