// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AgentOffice",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentOfficeCore", targets: ["AgentOfficeCore"]),
        .executable(name: "AgentOffice", targets: ["AgentOffice"]),
    ],
    targets: [
        .target(name: "AgentOfficeCore"),
        .executableTarget(
            name: "AgentOffice",
            dependencies: ["AgentOfficeCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AgentOfficeCoreTests",
            dependencies: ["AgentOfficeCore"]
        ),
    ]
)

