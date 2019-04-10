// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "CocoaAsyncSocket",
    products: [
        .library(name: "CocoaAsyncSocket", targets: ["CocoaAsyncSocket"])
    ],
    targets: [
        .target(
            name: "CocoaAsyncSocket",
            path: "Source/GCD"
        )
    ]
)
