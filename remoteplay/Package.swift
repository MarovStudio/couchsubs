// swift-tools-version: 6.2
// SPDX-License-Identifier: AGPL-3.0-only

import PackageDescription

let package = Package(
    name: "RemotePlay",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "RemotePlay", targets: ["RemotePlay"]),
    ],
    targets: [
        // scripts/build-chiaki-macos.sh ile üretilir (chiaki-ng libchiaki + statik bağımlılıklar).
        .binaryTarget(name: "CChiaki", path: "../third-party/build/CChiaki.xcframework"),
        .target(
            name: "RemotePlay",
            dependencies: ["CChiaki"],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedFramework("CoreServices"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Security"),
                .linkedFramework("SystemConfiguration"),
            ]
        ),
        .testTarget(name: "RemotePlayTests", dependencies: ["RemotePlay", "CChiaki"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
