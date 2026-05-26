# IIIFCore, as used in [gnorium.com](https://gnorium.com)

A Swift package for IIIF Presentation API v3 manifest parsing and deep zoom image viewing.

## Overview

IIIFCore provides a complete IIIF Image API client and Presentation API v3 model types compiled for both server-side rendering and client-side WebAssembly. The IIIF viewer handles tile-based deep zoom with pan, zoom, and canvas navigation — all without JavaScript.

### Features
- **Presentation API v3**: Full manifest, canvas, annotation, and range model types.
- **Image API**: Tile URL construction, info.json parsing, region/size/rotation support.
- **Embedded WASM Viewer**: Zero-dependency deep zoom with CSS transforms, gesture handling (pan/zoom), keyboard navigation, and multi-canvas support.
- **Server-side Rendering**: HTMLContent view for embedding in any page.

### IIIF Model Types
- `IIIFManifest` — Top-level manifest with label, metadata, thumbnail, provider
- `IIIFCanvas` — Individual page/view with dimensions, annotations, image services
- `IIIFImageService` — Tile info for deep zoom
- `IIIFRegion` / `IIIFTileSize` — Image API region and size selectors
- `IIIFTileURL` — URL builder for IIIF Image API tile requests
- Full support for W3C Web Annotations, Ranges (table of contents), and language maps

## Installation

### Swift Package Manager

Add IIIFCore to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/gnorium/iiif-core.git", branch: "main")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "IIIFCore", package: "iiif-core")
    ]
)
```

## Requirements

- Swift 6.2+

## Usage

```swift
import IIIFCore

// Fetch and render a IIIF manifest
IIIFView(manifestURL: "https://iiif.folger.edu/manifest/First_Folio/manifest.json")
```

For client-side WASM hydation, call `IIIFView.hydrate()` after the server renders the container.

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
