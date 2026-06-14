# ArtifactCore, as used in [gnorium.com](https://gnorium.com)

A Swift package for viewing and parsing artifacts — IIIF Presentation API v3 manifests, deep zoom images, and other artifact types (3D objects, audio/video, maps).

## Overview

ArtifactCore provides a general-purpose artifact viewer compiled for both server-side rendering and client-side WebAssembly. The viewer handles tile-based deep zoom with pan, zoom, and canvas navigation — all without JavaScript. Built on IIIF Presentation API v3, it is designed to extend beyond images as new artifact types are supported.

### Features
- **Presentation API v3**: Full manifest, canvas, annotation, and range model types.
- **Image API**: Tile URL construction, info.json parsing, region/size/rotation support.
- **Embedded WASM Viewer**: Zero-dependency deep zoom with CSS transforms, gesture handling (pan/zoom), keyboard navigation, and multi-canvas support.
- **Server-side Rendering**: HTMLContent view for embedding in any page.

### Model Types
- `Manifest` — Top-level manifest with label, metadata, thumbnail, provider
- `Canvas` — Individual page/view with dimensions, annotations, image services
- `ImageService` — Tile info for deep zoom
- `Region` / `TileSize` — Image API region and size selectors
- `TileURL` — URL builder for IIIF Image API tile requests
- Full support for W3C Web Annotations, Ranges (table of contents), and language maps

## Installation

### Swift Package Manager

Add ArtifactCore to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/gnorium/artifact-core.git", branch: "main")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "ArtifactCore", package: "artifact-core")
    ]
)
```

## Requirements

- Swift 6.2+

## Usage

```swift
import ArtifactCore

// Fetch and render an artifact manifest
ArtifactView(manifestURL: "https://iiif.folger.edu/manifest/First_Folio/manifest.json")
```

For client-side WASM hydration, call `ArtifactView.hydrate()` after the server renders the container.

## License

Apache License 2.0 - See [LICENSE](LICENSE) for details

## Contributing

Contributions welcome! Please open an issue or submit a pull request.

## Related Packages

- [admin-core](https://github.com/gnorium/admin-core) - Core admin functionalities for web applications
- [design-tokens](https://github.com/gnorium/design-tokens) - Universal design tokens based on Apple HIG
- [diff-engine](https://github.com/gnorium/diff-engine) - Platform-agnostic character-level diff engine
- [embedded-swift-utilities](https://github.com/gnorium/embedded-swift-utilities) - Utility functions for Embedded Swift environments
- [markdown-utilities](https://github.com/gnorium/markdown-utilities) - Markdown rendering with extended syntax
- [web-apis](https://github.com/gnorium/web-apis) - Web API implementations for Swift WebAssembly
- [web-builders](https://github.com/gnorium/web-builders) - HTML, CSS, JS, and SVG DSL builders
- [web-components](https://github.com/gnorium/web-components) - Reusable UI components for web applications
- [web-formats](https://github.com/gnorium/web-formats) - Structured data format builders
- [web-security](https://github.com/gnorium/web-security) - Portable security utilities for web applications
- [web-types](https://github.com/gnorium/web-types) - Shared web types and design tokens
