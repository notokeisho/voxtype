// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceClient",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VoiceClient", targets: ["VoiceClient"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceClient",
            path: "VoiceClient",
            exclude: [
                "Info.plist",
                "VoiceClient.entitlements"
            ]
        )
    ]
)
