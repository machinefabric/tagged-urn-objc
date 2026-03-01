// swift-tools-version: 5.8
// version: 0.20.4914
import PackageDescription

let package = Package(
    name: "tagged-urn-objc",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "TaggedUrn",
            targets: ["TaggedUrn"]),
    ],
    targets: [
        .target(
            name: "TaggedUrn",
            dependencies: [],
            path: "Sources/TaggedUrn",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Foundation")
            ]
        ),
        .testTarget(
            name: "TaggedUrnTests",
            dependencies: ["TaggedUrn"]),
    ]
)
