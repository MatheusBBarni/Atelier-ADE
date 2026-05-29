// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NativeMacADE",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "NativeMacADE", targets: ["NativeMacADE"]),
        .library(name: "NativeMacADECore", targets: ["NativeMacADECore"])
    ],
    targets: [
        .executableTarget(
            name: "NativeMacADE",
            dependencies: ["NativeMacADECore"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "CGhostty",
            publicHeadersPath: "include"
        ),
        .target(
            name: "NativeMacADECore",
            dependencies: ["CGhostty"]
        ),
        .testTarget(
            name: "NativeMacADECoreTests",
            dependencies: ["NativeMacADECore"]
        ),
        .testTarget(
            name: "NativeMacADEIntegrationTests",
            dependencies: ["NativeMacADECore"]
        )
    ]
)
