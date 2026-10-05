// swift-tools-version: 5.9
// version: 1.77.0
import PackageDescription

let package = Package(
    name: "tagged-urn-objc",
    // lungo-swift's: the model runs on it.
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "TaggedUrn",
            targets: ["TaggedUrn"]),
        // The model's Swift API: a program generated from a model that builds on tagged-urn's
        // names its URN type.
        .library(
            name: "TaggedUrnFormal",
            targets: ["TaggedUrnFormal"]),
    ],
    dependencies: [
        // The runtime the code generated from ../formal runs on, at exactly the lungo release
        // that generated it.
        .package(url: "https://github.com/machinefabric/lungo-swift.git", exact: "1.86.160"),
    ],
    targets: [
        // What two URNs mean to each other is decided by the program generated from the
        // proved model in ../formal (see ../lungo.toml): its C API, which the Objective-C
        // calls, and its Swift API.
        .target(
            name: "TaggedUrnFormalProgram",
            dependencies: [.product(name: "LungoKit", package: "lungo-swift")],
            path: "Formal/TaggedUrnFormalProgram",
            cSettings: [.headerSearchPath("program")]
        ),
        .target(
            name: "TaggedUrnFormal",
            dependencies: ["TaggedUrnFormalProgram", .product(name: "LungoKit", package: "lungo-swift")],
            path: "Formal/TaggedUrnFormal"
        ),
        .target(
            name: "TaggedUrn",
            dependencies: ["TaggedUrnFormalProgram"],
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
