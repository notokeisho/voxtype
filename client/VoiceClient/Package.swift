// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoxType",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VoxType", targets: ["VoxType"])
    ],
    targets: [
        .executableTarget(
            name: "VoxType",
            path: "VoxType",
            exclude: [
                "Info.plist",
                "VoxType.entitlements"
            ]
        )
    ]
)
