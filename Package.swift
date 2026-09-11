// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacBookDuo",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MacBookDuoCore", targets: ["MacBookDuoCore"]),
        .executable(name: "MacBookDuo", targets: ["MacBookDuo"])
    ],
    targets: [
        .target(name: "MacBookDuoCore"),
        .executableTarget(
            name: "MacBookDuo",
            dependencies: ["MacBookDuoCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("MetalKit"),
                .linkedFramework("ScreenCaptureKit")
            ]
        ),
        .testTarget(name: "MacBookDuoCoreTests", dependencies: ["MacBookDuoCore"])
    ]
)
