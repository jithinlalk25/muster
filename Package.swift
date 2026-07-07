// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Muster",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MusterCore", targets: ["MusterCore"]),
        .library(name: "MusterKit", targets: ["MusterKit"]),
        .executable(name: "muster-hook", targets: ["muster-hook"]),
        .executable(name: "Muster", targets: ["Muster"]),
    ],
    targets: [
        .target(name: "MusterCore"),
        .target(name: "MusterKit", dependencies: ["MusterCore"]),
        .executableTarget(name: "muster-hook", dependencies: ["MusterCore"]),
        .executableTarget(name: "Muster", dependencies: ["MusterKit", "MusterCore"]),
        .testTarget(name: "MusterCoreTests", dependencies: ["MusterCore"]),
        .testTarget(name: "MusterKitTests", dependencies: ["MusterKit"]),
    ]
)
