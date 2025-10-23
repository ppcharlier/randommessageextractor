// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "era-vapor",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
            ],
            path: "Sources/App"
        ),
    ]
)
