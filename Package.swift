// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RadioSuite",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RadioSuite", targets: ["RadioSuite"]),
    ],
    dependencies: [
        // The contract is consumed as a published library (same Git URL the plugin
        // repos use) so every chain resolves one identical RadioPluginKit — no
        // path-vs-URL identity conflict. The plugin apps stay local-path for dev.
        .package(url: "https://github.com/VU3ESV/RadioPluginKit.git", from: "1.1.0"),
        .package(path: "../LP-700-App"),
        .package(path: "../LP-100A-App"),
        .package(path: "../BandPassFilterControllerApp"),
    ],
    targets: [
        .executableTarget(
            name: "RadioSuite",
            dependencies: [
                .product(name: "RadioPluginKit", package: "RadioPluginKit"),
                .product(name: "RadioPluginUI", package: "RadioPluginKit"),
                .product(name: "LP700App", package: "LP-700-App"),
                .product(name: "LP100AApp", package: "LP-100A-App"),
                .product(name: "BandPassFilterControllerKit", package: "BandPassFilterControllerApp"),
            ],
            path: "Sources/RadioSuite"
        ),
    ]
)
