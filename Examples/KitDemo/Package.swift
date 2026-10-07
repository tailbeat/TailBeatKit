// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "KitDemo",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(name: "TailBeatKit", path: "../.."),
    ],
    targets: [
        // Log calls written as for `os.Logger`, in files that import only `tb`.
        .executableTarget(
            name: "KitDemo",
            dependencies: [.product(name: "tb", package: "TailBeatKit")]
        ),
        // `EveryOption.swift` of KitDemo — the same file, through a symbolic link — compiled
        // against `os.Logger`: the flag turns its `import tb` into `import os`.
        .executableTarget(
            name: "OSLoggerReference",
            swiftSettings: [.define("REFERENCE")]
        ),
        // The kit next to `os.Logger`: the level of every method, and the cost of a call.
        .executableTarget(
            name: "KitCompare",
            dependencies: [.product(name: "tb", package: "TailBeatKit")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
