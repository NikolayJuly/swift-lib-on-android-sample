// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "pokemon-kit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "PokemonKit", targets: ["PokemonKit"]),
        // Dynamic variant for Android — `.so` produced via swift-android-bundler in Scripts/build-android-so.sh.
        .library(name: "PokemonKitAndroid", type: .dynamic, targets: ["PokemonKit"]),
    ],
    dependencies: [
        .package(path: "../../Toolkit/CacheKit"),
        .package(path: "../../Toolkit/FoundationExtension"),
        .package(path: "../../Toolkit/NetworkKit"),

        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.27.0"),
        // Minimal fork of swiftlang/swift-java — strips heavy targets that require JAVA_HOME at build time.
        // Full rationale in the fork's README.
        .package(url: "https://github.com/NikolayJuly/swift-java.git", branch: "minimal"),
    ],
    targets: [
        .target(name: "PokemonKit",
                dependencies: [
                    .product(name: "JsonCacheKit", package: "CacheKit"),
                    .product(name: "FoundationExtension", package: "FoundationExtension"),
                    .product(name: "NetworkKit", package: "NetworkKit"),
                    .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                    .product(name: "SwiftJava", package: "swift-java", condition: .when(platforms: [.android])),
                ],
                exclude: ["pokemon.proto"]),
        .testTarget(name: "PokemonKitTests",
                    dependencies: [
                        "PokemonKit",
                        .product(name: "JsonCacheKit", package: "CacheKit"),
                        .product(name: "FoundationExtension", package: "FoundationExtension"),
                        .product(name: "FoundationExtensionTestsSupport", package: "FoundationExtension"),
                        .product(name: "NetworkKit", package: "NetworkKit"),
                        .product(name: "NetworkKitTestsSupport", package: "NetworkKit"),
                    ],
                    resources: [
                        .process("Resources"),
                    ]),
    ]
)
