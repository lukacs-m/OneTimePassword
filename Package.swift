// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "OneTimePassword",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "OneTimePassword",
            targets: ["OneTimePassword"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "OneTimePassword",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                SwiftSetting.unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"])
            ]),
        .testTarget(
            name: "OneTimePasswordTests",
            dependencies: ["OneTimePassword"],
            path: "Tests",
            exclude: ["KeychainTests.swift"]),
    ]
)
