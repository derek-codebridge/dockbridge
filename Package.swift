// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DockBridge",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "DockBridgeCore",
            path: "Sources",
            exclude: ["main.swift"]
        ),
        .testTarget(
            name: "DockBridgeTests",
            dependencies: ["DockBridgeCore"],
            path: "tests/DockBridgeTests"
        ),
    ]
)
