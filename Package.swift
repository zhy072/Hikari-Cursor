// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CursorSwap",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "CursorKit",
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "mousecur", dependencies: ["CursorKit"],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "CursorSwapApp", dependencies: ["CursorKit"],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
