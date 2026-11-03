// swift-tools-version:5.9
// Swift 5 language mode keeps the C-convention event tap callback and its
// shared state free of strict-concurrency errors.
import PackageDescription

let package = Package(
    name: "DockStayPutter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DockStayPutter",
            path: "Sources/DockStayPutter"
        )
    ]
)
