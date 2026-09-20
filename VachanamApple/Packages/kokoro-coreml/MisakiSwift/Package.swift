// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MisakiSwift",
  platforms: [
    .iOS("18.0"), .macOS("15.0")
  ],
  products: [
    .library(
      name: "MisakiSwift",
      type: .dynamic,
      targets: ["MisakiSwift"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.31.4"),
    .package(name: "MLXUtilsLibrary", path: "../MLXUtilsLibrary")
  ],
  targets: [
    .target(
      name: "MisakiSwift",
      dependencies: [
        .product(name: "MLX", package: "mlx-swift"),
        .product(name: "MLXNN", package: "mlx-swift"),
        .product(name: "MLXUtilsLibrary", package: "MLXUtilsLibrary")
     ],
      resources: [
       .copy("MisakiData")
      ]
     ),
    .testTarget(
      name: "MisakiSwiftTests",
      dependencies: ["MisakiSwift"]
    ),
  ]
)
