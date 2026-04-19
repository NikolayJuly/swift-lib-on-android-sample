// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CacheKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v15),
    ],
    products: [
        .library(name: "JsonCacheKit", targets: ["JsonCacheKit"]),
    ],
    dependencies: [
        .package(path: "../FoundationExtension"),
        .package(path: "../NetworkKit"),

        .package(url: "https://github.com/apple/swift-log.git", from: "1.11.0"),
    ],
    targets: [
        .target(name: "JsonCacheKit",
                dependencies: [
                    .product(name: "FoundationExtension", package: "FoundationExtension"),
                    .product(name: "Logging", package: "swift-log"),
                    .product(name: "NetworkKit", package: "NetworkKit"),
                ]),
    ]
)
