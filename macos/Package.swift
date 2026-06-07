// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "IBKRAnalyticsStudioMac",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "IBKRAnalyticsStudioMac", targets: ["IBKRAnalyticsStudioMac"])
    ],
    targets: [
        .executableTarget(
            name: "IBKRAnalyticsStudioMac",
            path: "Sources/IBKRAnalyticsStudioMac"
        )
    ]
)
