// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Muster",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MusterCore", targets: ["MusterCore"]),
        .executable(name: "muster-hook", targets: ["muster-hook"]),
    ],
    targets: [
        .target(name: "MusterCore"),
        .executableTarget(name: "muster-hook", dependencies: ["MusterCore"]),
        .testTarget(name: "MusterCoreTests", dependencies: ["MusterCore"]),
    ]
)
