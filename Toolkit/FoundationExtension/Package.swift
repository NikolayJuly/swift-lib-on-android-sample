// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "foundation-extension",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "FoundationExtension",
            targets: [
                "FileSystemKit",
                "FoundationExtension",
                "LoggingExtension",
                "ObjectStorage",
                "PersistenceKit",
                "RunningEnvironment",
            ]
        ),
        .library(
            name: "FoundationExtensionTestsSupport",
            targets: [
                "FileSystemKitTestsSupport",
                "PersistenceKitTestsSupport",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.11.0"),
    ],
    targets: [

        // MARK: FileSystemService

        .target(name: "FileSystemKit",
                dependencies: [
                    "FoundationExtension",
                    "LoggingExtension",
                    "ObjectStorage",
                    "RunningEnvironment",
                    .product(name: "Logging", package: "swift-log"),
                ]),
        .target(name: "FileSystemKitTestsSupport",
                dependencies: [
                    "FileSystemKit",
                ]),

        // MARK: FoundationExtension

        .target(name: "FoundationExtension",
                dependencies: [
                    "LoggingExtension",
                    "RunningEnvironment",
                    .product(name: "Logging", package: "swift-log"),
                ]),

        // MARK: LoggingExtension

        .target(name: "LoggingExtension",
                dependencies: [
                    .product(name: "Logging", package: "swift-log"),
                ]),

        // MARK: ObjectStorage

        .target(name: "ObjectStorage",
                dependencies: [
                    "FoundationExtension",
                    "LoggingExtension",
                    "RunningEnvironment",
                ]),

        // MARK: RunningEnvironment

        .target(name: "RunningEnvironment",
                dependencies: []),

        // MARK: PersistenceKit

        .target(name: "PersistenceKit",
                dependencies: [
                    "FoundationExtension",
                    "FileSystemKit",
                    "LoggingExtension",
                    "ObjectStorage",
                    .product(name: "Logging", package: "swift-log"),
                ]),
        .target(name: "PersistenceKitTestsSupport",
                dependencies: [
                    "FoundationExtension",
                    "PersistenceKit",
                ]),

    ]
)
