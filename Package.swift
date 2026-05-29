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
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0")
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
            dependencies: [
                "CGhostty",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]
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
