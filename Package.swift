// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DialKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "DialKit",
            targets: ["DialKit"]
        )
    ],
    targets: [
        .target(
            name: "DialKitCore"
        ),
        .target(
            name: "DialKit",
            dependencies: ["DialKitCore"]
        ),
        .testTarget(
            name: "DialKitCoreTests",
            dependencies: ["DialKitCore"]
        ),
        .testTarget(
            name: "DialKitTests",
            dependencies: ["DialKit"]
        )
    ]
)
