// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MACKAN",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "MACKAN", targets: ["MACKAN"]),
        .library(name: "MACKANKit", targets: ["MACKANKit"]),
    ],
    targets: [
        .target(name: "MACKANKit"),
        .executableTarget(
            name: "MACKAN",
            dependencies: ["MACKANKit"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MACKANKitTests",
            dependencies: ["MACKANKit"]
        ),
    ]
)
