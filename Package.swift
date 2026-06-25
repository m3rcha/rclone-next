// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RcloneNext",
    platforms: [.macOS(.v14)],          // NavigationSplitView, Table, @Observable
    targets: [
        .executableTarget(
            name: "RcloneNext",
            path: "Sources/RcloneNext"
        )
    ]
)
