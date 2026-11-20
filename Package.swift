// swift-tools-version: 6.0

import PackageDescription

let linuxPlatforms: [Platform] = [.linux, .openbsd]

let package = Package(
    name: "MachOKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(
            name: "MachOKit",
            targets: ["MachOKit"]
        ),
        .library(
            name: "MachOArchiveKit",
            targets: ["MachOArchiveKit"]
        ),
        .library(
            name: "MachOKitC",
            targets: ["MachOKitC"]
        ),
        .library(
            name: "MachOKitReadable",
            targets: ["MachOKitReadable"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/p-x9/swift-fileio.git",
            from: "0.13.0"
        ),
        .package(
            url: "https://github.com/p-x9/swift-fileio-extra.git",
            from: "0.2.2"
        ),
        .package(
            url: "https://github.com/p-x9/ObjectArchiveKit.git",
            from: "0.5.0"
        ),
        // Swift Crypto 4.4 and Swift ASN.1 1.7 require Swift 6.1. Keep the latest
        // releases that support the Swift 6.0 Linux toolchain while allowing
        // downstream packages to resolve Swift Crypto 4.
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            "1.0.0" ..< "4.4.0"
        ),
        .package(
            url: "https://github.com/apple/swift-asn1.git",
            "1.2.0" ..< "1.7.0"
        ),
    ],
    targets: [
        .target(
            name: "MachOKit",
            dependencies: [
                "MachOKitC",
                .product(name: "FileIO", package: "swift-fileio"),
                .product(name: "FileIOBinary", package: "swift-fileio-extra"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: linuxPlatforms)
                ),
                .product(
                    name: "SwiftASN1",
                    package: "swift-asn1",
                    condition: .when(platforms: linuxPlatforms)
                )
            ],
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "MachOArchiveKit",
            dependencies: [
                "MachOKit",
                .product(name: "ObjectArchiveKit", package: "ObjectArchiveKit"),
            ]
        ),
        .target(
            name: "MachOKitReadable",
            dependencies: [
                "MachOKit"
            ]
        ),
        .target(
            name: "MachOKitC",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "MachOKitTests",
            dependencies: [
                "MachOKit",
                "MachOArchiveKit",
                "MachOKitReadable",
                // Builds file-backed readers from synthetic bytes.
                .product(name: "FileIO", package: "swift-fileio"),
            ]
        )
    ]
)

let machOKit = package.targets.first(where: { $0.name == "MachOKit" })

// MARK: - Binary Parse Support

let isForBinaryKitFramework = Context.environment["BUILD_BINARY_KIT_FW"] != nil

if isForBinaryKitFramework {
    package.dependencies += [
        .package(
            url: "https://github.com/p-x9/swift-binary-parse-support-bin.git",
            from: "0.2.1"
        ),
    ]
    machOKit?.dependencies += [
        .product(
            name: "BinaryParseSupport",
            package: "swift-binary-parse-support-bin"
        )
    ]
} else {
    package.dependencies += [
        .package(
            url: "https://github.com/p-x9/swift-binary-parse-support.git",
            from: "0.2.1"
        ),
    ]
    machOKit?.dependencies += [
        .product(
            name: "BinaryParseSupport",
            package: "swift-binary-parse-support"
        )
    ]
}

// MARK: - Upcoming Features

// Swift 6 language mode (the default for swift-tools-version 6.0) already
// turns on every upcoming feature of the Swift 5 era. These three are the
// Swift 7 ones the MachO packages adopt, on every Swift target. A compiler
// that does not know a feature name (MemberImportVisibility needs 6.1,
// InferIsolatedConformances 6.2) ignores it, so Swift 6.0 still builds.
let upcomingFeatureSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + upcomingFeatureSettings
}
