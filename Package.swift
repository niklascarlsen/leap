// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Leap",
    platforms: [.macOS(.v27)],
    targets: [
        // Pure, testable logic with no dependency on live accessibility state.
        .target(name: "LeapCore"),
        .executableTarget(name: "Leap", dependencies: ["LeapCore"]),
        .testTarget(name: "LeapCoreTests", dependencies: ["LeapCore"]),
    ]
)
