// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "CocoaAsyncSocket",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v10),
        .tvOS(.v10)
    ],
    products: [
        .library(
            name: "CocoaAsyncSocket",
            targets: ["CocoaAsyncSocket"])
    ],
    targets: [
        .target(
            name: "CocoaAsyncSocket",
            path: "Source/GCD",
            publicHeadersPath: "."
        )
    ]
)
