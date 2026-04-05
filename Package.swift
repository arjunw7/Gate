// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Boop",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Boop",
            path: "Sources/Boop",
            linkerSettings: [
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
