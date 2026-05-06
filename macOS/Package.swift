// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DevDashboard",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "DevDashboard",
            dependencies: ["Core"],
            path: "Sources/DevDashboard",
            exclude: ["Resources"]
        ),
        .target(
            name: "Core",
            dependencies: ["Yams"],
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests"
        ),
    ]
)
