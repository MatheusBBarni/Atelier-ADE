// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NativeMacADE",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "NativeMacADE", targets: ["NativeMacADE"]),
        .library(name: "GhosttyKit", targets: ["GhosttyKit"]),
        .library(name: "NativeMacADECore", targets: ["NativeMacADECore"])
    ],
    dependencies: [
        .package(url: "https://github.com/mchakravarty/CodeEditorView.git", from: "0.15.4"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0")
    ],
    targets: [
        .executableTarget(
            name: "NativeMacADE",
            dependencies: [
                "NativeMacADECore",
                .product(name: "CodeEditorView", package: "CodeEditorView"),
                .product(name: "LanguageSupport", package: "CodeEditorView")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "CGhostty",
            publicHeadersPath: "include"
        ),
        .target(
            name: "GhosttyKit",
            dependencies: ["CGhostty"]
        ),
        .target(
            name: "NativeMacADECore",
            dependencies: [
                "GhosttyKit",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]
        ),
        .testTarget(
            name: "GhosttyKitTests",
            dependencies: ["GhosttyKit"]
        ),
        .testTarget(
            name: "NativeMacADECoreTests",
            dependencies: ["NativeMacADECore", "GhosttyKit"]
        ),
        .testTarget(
            name: "NativeMacADEIntegrationTests",
            dependencies: ["NativeMacADE", "NativeMacADECore", "GhosttyKit"]
        )
    ]
)
