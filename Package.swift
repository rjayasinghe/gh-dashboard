// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GhDashboard",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "GhDashboard",
            dependencies: ["Core"],
            path: "Sources/GhDashboard",
            exclude: ["Resources", "Resources/Info.plist.template"]
        ),
        .target(
            name: "Core",
            dependencies: ["Yams"],
            path: "Sources/Core"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: [
                "Core",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/CoreTests"
        ),
    ]
)
