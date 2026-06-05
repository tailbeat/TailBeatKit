// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TailBeatKit",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // The whole kit is the `tb` module: a Logger that writes to OSLog and
        // `exportRecentLogs`, which reads the process's entries back out.
        .library(
            name: "tb",
            targets: ["tb"]
        ),
    ],
    targets: [
        .target(
            name: "tb"
        ),
        .testTarget(
            name: "tbTests",
            dependencies: ["tb"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
