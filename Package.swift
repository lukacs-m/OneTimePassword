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
//        .package(url: "https://github.com/mattrubin/Bases.git",
//                 revision: "6b9531b044cbf0262265b3c6b4581bf97b4372b6"),
    ],
    targets: [
        .target(
            name: "OneTimePassword",
            dependencies: [
//               .product(name: "Base32", package: "Bases"),
            ],
            path: "Sources"),
        .testTarget(
            name: "OneTimePasswordTests",
            dependencies: ["OneTimePassword"],
            path: "Tests",
            exclude: ["App", "KeychainTests.swift"]),
    ]
)
