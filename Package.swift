// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PolishBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "polishbar", targets: ["polishbar"]),
        .executable(name: "PolishBar", targets: ["PolishBarApp"]),
        .library(name: "PolishBarCore", targets: ["PolishBarCore"]),
        .library(name: "PolishBarMac", targets: ["PolishBarMac"]),
    ],
    targets: [
        // Logic + wire codec. No AppKit/Carbon; unit-tested by PolishBarTests.
        .target(name: "PolishBarCore"),

        // Shared macOS integration "kernel" (AX, hotkey, pasteboard, LLM client,
        // config/keychain, PolishBarService). Used by both front-ends.
        .target(name: "PolishBarMac", dependencies: ["PolishBarCore"]),

        // CLI front-end (dev): daemon, doctor, exec, stop.
        .executableTarget(name: "polishbar", dependencies: ["PolishBarCore", "PolishBarMac"]),

        // Menu-bar app front-end (users): start/stop + settings.
        .executableTarget(name: "PolishBarApp", dependencies: ["PolishBarCore", "PolishBarMac"]),

        // Dependency-free test harness (runs with `swift run PolishBarTests`).
        .executableTarget(name: "PolishBarTests", dependencies: ["PolishBarCore"], path: "Tests/PolishBarTests"),
    ],
    swiftLanguageModes: [.v5]
)
