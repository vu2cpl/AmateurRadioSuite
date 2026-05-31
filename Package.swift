// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RadioSuite",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RadioSuite", targets: ["RadioSuite"]),
    ],
    dependencies: [
        .package(path: "../RadioPluginKit"),
        .package(path: "../LP-700-App"),
        .package(path: "../LP-100A-App"),
        .package(path: "../BandPassFilterControllerApp"),
    ],
    targets: [
        .executableTarget(
            name: "RadioSuite",
            dependencies: [
                .product(name: "RadioPluginKit", package: "RadioPluginKit"),
                .product(name: "LP700App", package: "LP-700-App"),
                .product(name: "LP100AApp", package: "LP-100A-App"),
                .product(name: "BandPassFilterControllerKit", package: "BandPassFilterControllerApp"),
            ],
            path: "Sources/RadioSuite"
        ),
    ]
)
