// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "network-kit",
    platforms: [
        .iOS(.v16),
        .macOS(.v15),
    ],
    products: [
        .library(name: "NetworkKit", targets: ["NetworkKit"]),
        .library(name: "NetworkKitDynamic", type: .dynamic, targets: ["NetworkKit"]),
        .library(name: "NetworkKitTestsSupport", targets: ["NetworkKitTestsSupport"]),
    ],
    dependencies: [
        .package(path: "../FoundationExtension"),

        .package(url: "https://github.com/apple/swift-log.git", from: "1.11.0"),
        // Minimal fork of swiftlang/swift-java — strips heavy targets that require JAVA_HOME at build time.
        // Full rationale in the fork's README.
        .package(url: "https://github.com/NikolayJuly/swift-java.git", branch: "minimal"),
    ],
    targets: [
        // MARK: General networking

        .target(name: "NetworkKitAPI",
                dependencies: [
                    .product(name: "FoundationExtension", package: "FoundationExtension"),
                    .product(name: "Logging", package: "swift-log"),
                ]),

        .target(name: "NetworkKitFoundation",
                dependencies: [
                    "NetworkKitAPI",
                    .product(name: "FoundationExtension", package: "FoundationExtension"),
                    .product(name: "Logging", package: "swift-log"),
                ]),

        .target(name: "NetworkKit",
                dependencies: [
                    "NetworkKitAPI",
                    .target(name: "NetworkKitFoundation", condition: .when(platforms: [.iOS, .macCatalyst, .macOS, .tvOS, .linux])),
                    .target(name: "NetworkKitAndroid", condition: .when(platforms: [.android])),
                    .product(name: "FoundationExtension", package: "FoundationExtension"),
                    .product(name: "Logging", package: "swift-log"),
                ]),

        .target(name: "NetworkKitTestsSupport",
                dependencies: [
                    .byName(name: "NetworkKit"),
                ]),

        // MARK: Android

        .target(name: "NetworkKitAndroid",
                dependencies: [
                    "NetworkKitAPI",
                    .product(name: "FoundationExtension", package: "FoundationExtension"),
                    .product(name: "SwiftJava", package: "swift-java", condition: .when(platforms: [.android])),
                    .product(name: "JavaNet", package: "swift-java", condition: .when(platforms: [.android])),
                    .product(name: "JavaIO", package: "swift-java", condition: .when(platforms: [.android])),
                    .product(name: "Logging", package: "swift-log"),
                ]),
    ]
)
