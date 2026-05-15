// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GhDashboard",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "GhDashboard",
            dependencies: ["Core"],
            path: "Sources/GhDashboard",
            exclude: ["Resources"]
        ),
        .target(
            name: "Core",
            dependencies: ["Yams"],
            path: "Sources/Core"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests"
        ),
    ]
)
