// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AgeKit",
    // Parts of CryptoKit require macOS 11+, iOS 14+
    platforms: [
        .macOS(.v11),
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "AgeKit",
            targets: ["AgeKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-base64.git", from: "0.7.0"),
        // TODO: Change this to a version once they've tagged a release which includes 155b8acdb2a9be1db8a195b2f6a9e6c18d9b754e
        .package(url: "https://github.com/apple/swift-asn1.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "AgeKit",
            dependencies: [
                "Bech32",
                "CryptoSwift",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "ExtrasBase64", package: "swift-extras-base64")
            ]),
        .target(name: "Bech32"),
        .testTarget(
            name: "Bech32Tests",
            dependencies: ["Bech32"]),
        .testTarget(
            name: "AgeKitTests",
            dependencies: ["AgeKit", .product(name: "SwiftASN1", package: "swift-asn1")]),
    ]
)
