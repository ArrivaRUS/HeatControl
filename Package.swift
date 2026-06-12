// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeatControl",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HeatControl",
            path: "Sources/HeatControl",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
