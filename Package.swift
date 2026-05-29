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
            dependencies: ["NativeMacADECore"]
        ),
        .target(name: "NativeMacADECore"),
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
