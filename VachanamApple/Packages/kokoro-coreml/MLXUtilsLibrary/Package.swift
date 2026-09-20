// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MLXUtilsLibrary",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "MLXUtilsLibrary",
            targets: ["MLXUtilsLibrary"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0")),
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.31.4")
    ],
    targets: [
        .target(
            name: "MLXUtilsLibrary",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "MLX", package: "mlx-swift")
            ],
            path: "Sources/MLXUtilsLibrary"
        ),
    ]
)
