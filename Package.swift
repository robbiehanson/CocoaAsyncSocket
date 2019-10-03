// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CocoaAsyncSocket",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v10)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "CocoaAsyncSocket",
            targets: ["CocoaAsyncSocket"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.6.0"),
    ],
    targets: [
        .target(
            name: "CocoaAsyncSocket",
            dependencies: ["CocoaLumberjack"],
            path: "Source/GCD"),
    ]
)
