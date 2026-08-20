// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "HealthFirst",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "HealthFirstCore",
            targets: ["HealthFirstCore"]
        ),
        .executable(
            name: "HealthFirst",
            targets: ["HealthFirstApp"]
        )
    ],
    targets: [
        .target(
            name: "HealthFirstCore"
        ),
        .executableTarget(
            name: "HealthFirstApp",
            dependencies: ["HealthFirstCore"],
            resources: [
                .process("../../assets/character/runtime")
            ]
        ),
        .testTarget(
            name: "HealthFirstCoreTests",
            dependencies: ["HealthFirstCore"]
        ),
        .testTarget(
            name: "HealthFirstAppTests",
            dependencies: ["HealthFirstApp"]
        )
    ]
)
