// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoicenotesNative",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/raycast/extensions-swift-tools.git", exact: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "VoicenotesNative",
            dependencies: [
                .product(name: "RaycastSwiftMacros", package: "extensions-swift-tools"),
                .product(name: "RaycastSwiftPlugin", package: "extensions-swift-tools"),
                .product(name: "RaycastTypeScriptPlugin", package: "extensions-swift-tools")
            ],
            path: ".",
            swiftSettings: [.define("RAYCAST_BRIDGE")]
        )
    ]
)
