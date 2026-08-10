// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SageGraphiteTokens",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Graphite",
            targets: ["Graphite"]
        )
    ],
    targets: [
        .target(
            name: "Graphite",
            path: "Sources/Graphite",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
