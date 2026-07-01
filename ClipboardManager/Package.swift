// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ClipboardManager",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClipboardManager",
            path: "Sources",
            exclude: ["Info.plist", "Resources"]
        ),
        .testTarget(
            name: "ClipboardManagerTests",
            dependencies: [
                "ClipboardManager",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests"
        )
    ]
)
