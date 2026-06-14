// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "artifact-core",
  platforms: [.macOS(.v15), .iOS(.v18)],
  products: [
    .library(
      name: "ArtifactCore",
      targets: ["ArtifactCore"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/gnorium/design-tokens", branch: "main"),
    .package(url: "https://github.com/gnorium/embedded-swift-utilities", branch: "main"),
    .package(url: "https://github.com/gnorium/web-apis", branch: "main"),
    .package(url: "https://github.com/gnorium/web-builders", branch: "main"),
    .package(url: "https://github.com/gnorium/web-types", branch: "main"),
    .package(url: "https://github.com/gnorium/web-formats", branch: "main"),
  ],
  targets: [
    .target(
      name: "ArtifactCore",
      dependencies: [
        .product(name: "CSSBuilder", package: "web-builders"),
        .product(name: "CSSOMBuilder", package: "web-builders"),
        .product(name: "DesignTokens", package: "design-tokens"),
        .product(name: "DOMBuilder", package: "web-builders"),
        .product(name: "EmbeddedSwiftUtilities", package: "embedded-swift-utilities"),
        .product(name: "HTMLBuilder", package: "web-builders"),
        .product(name: "JSBuilder", package: "web-builders"),
        .product(name: "JSONFormat", package: "web-formats"),
        .product(name: "SVGBuilder", package: "web-builders"),
        .product(name: "WebAPIs", package: "web-apis"),
        .product(name: "WebTypes", package: "web-types"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("Embedded", .when(platforms: [.wasi])),
        .define("CLIENT", .when(platforms: [.wasi])),
        .define("SERVER", .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),
    .testTarget(
      name: "ArtifactCoreTests",
      dependencies: ["ArtifactCore"]
    ),
  ]
)
