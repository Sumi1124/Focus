// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusGuard",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FocusGuard", targets: ["FocusGuard"])],
    targets: [
        .executableTarget(name: "FocusGuard"),
        .testTarget(name: "FocusGuardTests", dependencies: ["FocusGuard"])
    ]
)
