// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "AbroadJobsParserAPI",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.3.0"),

        // SwiftSoup: Pure Swift HTML Parser, with best of DOM, CSS, and jquery (Supports Linux, iOS, Mac, tvOS, watchOS)
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.0.0"),
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "SwiftSoup", package: "SwiftSoup"),
        ]),
        .target(name: "Run", dependencies: [
            .target(name: "App"),
        ])
    ]
)
