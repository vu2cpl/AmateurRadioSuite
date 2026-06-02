// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RadioSuite",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RadioSuite", targets: ["RadioSuite"]),
    ],
    dependencies: [
        // The host links ONLY the contract. Plugins are not compiled in — they are
        // discovered and installed at runtime (out-of-process ExtensionKit `.appex`),
        // so the suite builds standalone with no reference to any plugin app repo.
        .package(url: "https://github.com/VU3ESV/RadioPluginKit.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "RadioSuite",
            dependencies: [
                .product(name: "RadioPluginKit", package: "RadioPluginKit"),
                .product(name: "RadioPluginUI", package: "RadioPluginKit"),
            ],
            path: "Sources/RadioSuite"
        ),
        .testTarget(
            name: "RadioSuiteTests",
            dependencies: ["RadioSuite"],
            path: "Tests/RadioSuiteTests"
        ),
    ]
)
