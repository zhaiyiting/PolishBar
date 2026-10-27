// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Polish",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "polish", targets: ["polish"]),
        .library(name: "PolishCore", targets: ["PolishCore"]),
    ],
    targets: [
        // Pure, Foundation-free logic. Unit-tested by the CoreTests harness.
        .target(name: "PolishCore"),

        // macOS integration + CLI. Depends on AppKit/Carbon/Foundation.
        .executableTarget(name: "polish", dependencies: ["PolishCore"]),

        // Dependency-free test harness (runs with `swift run CoreTests`).
        .executableTarget(name: "CoreTests", dependencies: ["PolishCore"], path: "Tests/CoreTests"),
    ],
    swiftLanguageModes: [.v5]
)
