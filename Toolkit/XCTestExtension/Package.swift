// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "xc-test-extension",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        .library(name: "XCTestExtension",
                 targets: ["XCTestExtension"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "XCTestExtension"),
    ]
)
