// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "CocoaAsyncSocket",
    products: [
        .library(name: "CocoaAsyncSocket", targets: ["CocoaAsyncSocket"])
    ],
    targets: [
        .target(
            name: "CocoaAsyncSocket",
            path: "Source/GCD",
            publicHeadersPath: "."
        )
    ]
)
