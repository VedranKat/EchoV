// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "EchoV",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "EchoV", targets: ["EchoV"])
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.12.4")
    ],
    targets: [
        .executableTarget(
            name: "EchoV",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "EchoV"
        ),
        .testTarget(
            name: "EchoVTests",
            dependencies: ["EchoV"],
            path: "Tests/EchoVTests"
        )
    ]
)
