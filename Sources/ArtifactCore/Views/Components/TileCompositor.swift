#if CLIENT
  import CSSBuilder
  import DOMBuilder
  import EmbeddedSwiftUtilities
  import WebAPIs
  import WebTypes

  final class TileCompositor {
    static let tileSize: Int = 512

    // Image format: "webp" if IIIF server supports it, "jpg" otherwise — probed via info.json
    private nonisolated(unsafe) static var imageFormat: String = "jpg"
    // Cache probe result per service host so we only fetch info.json once per server
    private nonisolated(unsafe) static var formatCache: [String] = []  // even=host, odd=format

    // Backdrop: permanent low-res full image always visible — never cleared on zoom
    private nonisolated(unsafe) static var backdropImg: DOM.Element?

    // Tile key: zoomTier * 10_000_000 + ty * 10_000 + tx
    // Different zoom tiers coexist as layered placeholders until new tier is ready
    private nonisolated(unsafe) static var tiles: [Int: DOM.Element] = [:]
    private nonisolated(unsafe) static var currentTier: Int = -1

    private nonisolated(unsafe) static var container: DOM.Element?
    private nonisolated(unsafe) static var spinnerEl: DOM.Element?

    private nonisolated(unsafe) static var serviceID: String = ""
    private nonisolated(unsafe) static var imageW: Int = 0
    private nonisolated(unsafe) static var imageH: Int = 0

    // Debounce state — tile loads fire 150ms after last wheel/pan event
    private nonisolated(unsafe) static var debounceTimer: Int32 = -1
    private nonisolated(unsafe) static var pendingPanX: Double = 0
    private nonisolated(unsafe) static var pendingPanY: Double = 0
    private nonisolated(unsafe) static var pendingZoom: Double = 1
    private nonisolated(unsafe) static var pendingVW: Double = 0
    private nonisolated(unsafe) static var pendingVH: Double = 0

    // MARK: - Public API

    static var format: String { imageFormat }

    static func attach(to viewport: DOM.Element, spinner: DOM.Element) {
      spinnerEl = spinner
      let c = document.createElement("div")
      c.style.position(.absolute)
      c.style.transformOrigin(px(0), px(0))
      c.style.willChange(.transform)
      viewport.insertBefore(c, spinner)
      container = c
    }

    static func setCanvas(serviceID: String, width: Int, height: Int) {
      Self.serviceID = serviceID
      imageW = width
      imageH = height
      currentTier = -1
      cancelDebounce()
      clearAllTiles()
      backdropImg = nil
      container?.style.width(px(width))
      container?.style.height(px(height))
      probeFormat(base: baseURL(serviceID)) { fmt in
        imageFormat = fmt
        loadBackdrop()
      }
    }

    private static func probeFormat(base: String, completion: @escaping @Sendable (String) -> Void) {
      // Extract host from base URL to key the cache
      var host = base
      if let slashSlashIdx = stringIndexOf(base, "//") {
        let afterSlash = slashSlashIdx + 2
        let remaining = stringSubstring(base, from: afterSlash, to: base.utf8.count)
        if let nextSlash = stringIndexOf(remaining, "/") {
          host = stringSubstring(remaining, from: 0, to: nextSlash)
        } else {
          host = remaining
        }
      }
      // Check cache
      var i = 0
      while i + 1 < formatCache.count {
        if stringEquals(formatCache[i], host) {
          completion(formatCache[i + 1])
          return
        }
        i += 2
      }
      // Fetch info.json and look for webp in formats/extraFormats
      let infoUrl = "\(base)/info.json"
      window.fetch(infoUrl) { response in
        let json = response.jsonString ?? ""
        let supportsWebP = stringContains(json, "\"webp\"") || stringContains(json, "webp")
        let fmt = supportsWebP ? "webp" : "jpg"
        formatCache.append(host)
        formatCache.append(fmt)
        completion(fmt)
      }
    }

    static func update(panX: Double, panY: Double, zoom: Double, viewportW: Double, viewportH: Double) {
      // Transform is applied immediately — smooth pan/zoom feel
      container?.style.transform(translate(px(panX), px(panY)), scale(zoom))
      guard imageW > 0, imageH > 0 else { return }

      // Debounce: cancel previous timer and reschedule 150ms out
      pendingPanX = panX; pendingPanY = panY; pendingZoom = zoom; pendingVW = viewportW; pendingVH = viewportH
      cancelDebounce()
      debounceTimer = window.setTimeout(150) { flushTileLoad() }
    }

    static func showSpinner() {
      spinnerEl?.style.display(.flex)
    }

    // MARK: - Private

    private static func cancelDebounce() {
      if debounceTimer >= 0 { window.clearTimeout(debounceTimer); debounceTimer = -1 }
    }

    private static func flushTileLoad() {
      debounceTimer = -1
      let dpr = window.devicePixelRatio > 0 ? window.devicePixelRatio : 2.0
      let zoom = pendingZoom
      let tier = zoomTier(zoom)
      let shouldTile = Double(imageW) * zoom > Double(tileSize * 2)
                    || Double(imageH) * zoom > Double(tileSize * 2)
      if shouldTile {
        updateTiles(panX: pendingPanX, panY: pendingPanY, zoom: zoom,
                    viewportW: pendingVW, viewportH: pendingVH, dpr: dpr, tier: tier)
      } else {
        updateFullTile(zoom: zoom, dpr: dpr, tier: tier)
      }
    }

    // Low-res backdrop: full image at 256px — loads in ~200ms, always present
    private static func loadBackdrop() {
      guard imageW > 0 else { return }
      let base = baseURL(serviceID)
      let url = "\(base)/full/256,/0/default.\(imageFormat)"
      let img = document.createElement("img")
      img.setAttribute(.draggable, "false")
      img.style.position(.absolute)
      img.style.left(px(0))
      img.style.top(px(0))
      img.style.width(px(imageW))
      img.style.height(px(imageH))
      img.style.display(.block)
      img.style.opacity(0)
      img.setAttribute(.src, url)
      _ = img.addEventListener(.load) { _ in img.style.opacity(1) }
      // Insert at bottom so tiles layer on top
      if let first = container?.firstChild {
        container?.insertBefore(img, first)
      } else {
        container?.appendChild(img)
      }
      backdropImg = img
      // Hide spinner once backdrop is ready (first visible content)
      pollUntilLoaded(img) {
        spinnerEl?.style.display(.none)
      }
    }

    private static func updateFullTile(zoom: Double, dpr: Double, tier: Int) {
      let key = tier * 10_000_000 + 5_000_000
      guard tiles[key] == nil else { return }
      let base = baseURL(serviceID)
      // Exact size — no power-of-2 snap; single URL per zoom level, no cache-sharing benefit
      let reqW = min(imageW, max(64, Int(Double(imageW) * zoom * dpr)))
      let url = "\(base)/full/\(reqW),/0/default.\(imageFormat)"
      let img = addTile(x: 0, y: 0, w: imageW, h: imageH, url: url)
      tiles[key] = img
      // Once this tile loads, remove stale tiles from other tiers
      pollUntilLoaded(img) { clearTilesExcept(tier: tier) }
    }

    private static func updateTiles(
      panX: Double, panY: Double, zoom: Double,
      viewportW: Double, viewportH: Double, dpr: Double, tier: Int
    ) {
      let cols = (imageW + tileSize - 1) / tileSize
      let rows = (imageH + tileSize - 1) / tileSize
      var newTileImg: DOM.Element? = nil

      for ty in 0..<rows {
        for tx in 0..<cols {
          let key = tier * 10_000_000 + ty * 10_000 + tx
          guard tiles[key] == nil else { continue }

          let rx = tx * tileSize
          let ry = ty * tileSize
          let rw = min(tileSize, imageW - rx)
          let rh = min(tileSize, imageH - ry)

          let screenX = Double(rx) * zoom + panX
          let screenY = Double(ry) * zoom + panY
          let screenW = Double(rw) * zoom
          let screenH = Double(rh) * zoom
          let visible = screenX < viewportW && screenX + screenW > 0
                     && screenY < viewportH && screenY + screenH > 0
          guard visible else { continue }

          let needed = Int(Double(rw) * zoom * dpr)
          let reqW = min(rw, snapToPowerOfTwo(max(64, needed)))
          let base = baseURL(serviceID)
          let url = "\(base)/\(rx),\(ry),\(rw),\(rh)/\(reqW),/0/default.\(imageFormat)"
          let img = addTile(x: rx, y: ry, w: rw, h: rh, url: url)
          tiles[key] = img
          if newTileImg == nil { newTileImg = img }
        }
      }

      // When first tile of this tier is ready, remove all other-tier tiles
      if let firstNew = newTileImg, tier != currentTier {
        currentTier = tier
        pollUntilLoaded(firstNew) { clearTilesExcept(tier: tier) }
      }
    }

    // Poll until img is decoded/loaded, then call onReady
    private static func pollUntilLoaded(_ img: DOM.Element, onReady: @escaping @Sendable () -> Void) {
      _ = window.requestAnimationFrame {
        if img.isImageLoaded { onReady() } else { pollUntilLoaded(img, onReady: onReady) }
      }
    }

    // Remove all tiles not belonging to `tier` (backdrop is untouched — not in tiles dict)
    private static func clearTilesExcept(tier: Int) {
      var toRemove: [Int] = []
      for (key, el) in tiles {
        let keyTier = key / 10_000_000
        if keyTier != tier { container?.removeChild(el); toRemove.append(key) }
      }
      for k in toRemove { tiles.removeValue(forKey: k) }
    }

    private static func clearAllTiles() {
      if let c = container {
        for (_, el) in tiles { c.removeChild(el) }
        if let b = backdropImg { c.removeChild(b) }
      }
      tiles = [:]
    }

    private static func addTile(x: Int, y: Int, w: Int, h: Int, url: String) -> DOM.Element {
      let img = document.createElement("img")
      img.setAttribute(.draggable, "false")
      img.style.position(.absolute)
      img.style.left(px(x))
      img.style.top(px(y))
      // 1px overdraw on each edge eliminates sub-pixel rendering seams between adjacent tiles
      img.style.width(px(w + 1))
      img.style.height(px(h + 1))
      img.style.display(.block)
      // Hidden until loaded — backdrop shows through
      img.style.opacity(0)
      img.setAttribute(.src, url)
      _ = img.addEventListener(.load) { _ in img.style.opacity(1) }
      container?.appendChild(img)
      return img
    }

    // Discrete zoom tier: power-of-2 bucket (1, 2, 4, 8, ...) for tile cache reuse
    private static func zoomTier(_ zoom: Double) -> Int {
      var tier = 1
      var z = zoom
      while z >= 1.5 { z /= 2; tier *= 2 }
      return tier
    }

    private static func baseURL(_ sid: String) -> String {
      stringEndsWith(sid, "/") ? stringSubstring(sid, from: 0, to: sid.utf8.count - 1) : sid
    }

    private static func snapToPowerOfTwo(_ value: Int) -> Int {
      var snapped = 64
      while snapped < value { snapped *= 2 }
      return snapped
    }
  }
#endif
