#if CLIENT
  import CSSBuilder
  import DOMBuilder
  import EmbeddedSwiftUtilities
  import WebAPIs
  import WebTypes

  /// The tiles of one canvas. One per canvas, like its reader: the image,
  /// its tiles and their loads belong to one viewport.
  ///
  /// The image is read as its service's tile pyramid (`TilePyramid`): a
  /// low-resolution copy at once, then the level the zoom asks for—the
  /// whole image in one request while it all lies in view, else the tiles
  /// the view shows, nearest its middle first. A level stays over the
  /// coarser ones until the next has every tile the view needs, so a zoom
  /// never drops to the blurred copy; a tile the view has left before it
  /// arrived is let go, its request with it; one that fails is asked for
  /// again.
  final class TileCompositor: @unchecked Sendable {
    /// What a reader asks for before the probe has answered.
    static let defaultFormat = "jpg"

    /// What a service's host was found to serve (its `info.json`, read once
    /// a host): the format, and the side of its tiles.
    private struct HostInfo {
      let host: String
      let format: String
      let tileSize: Int
    }
    private nonisolated(unsafe) static var hostInfo: [HostInfo] = []
    /// Hosts whose `info.json` is being read, so a second canvas does not
    /// read it again.
    private nonisolated(unsafe) static var probing: [String] = []

    /// One image on the surface: a tile, the whole image at a level, or the
    /// low-resolution copy.
    private final class Tile: @unchecked Sendable {
      let element: DOM.Element
      let key: Int
      let level: Int
      let url: String
      var loaded = false
      /// Given up on, after its retries; asked for again only if a later
      /// view needs it.
      var failed = false
      var attempts = 0
      var loadListener: Int32 = -1
      var errorListener: Int32 = -1
      var retryTimer: Int32 = -1

      init(element: DOM.Element, key: Int, level: Int, url: String) {
        self.element = element
        self.key = key
        self.level = level
        self.url = url
      }
    }

    /// The waits before a failed tile is asked for again (a busy server's
    /// 429 or 503, a dropped connection): three tries more, then it waits
    /// for the view to need it again.
    private static let retryDelays: [Double] = [1000, 3000, 8000]
    /// How long the view rests before its tiles are asked for, and the
    /// longest a moving view goes without.
    private static let restDelay = 80.0
    private static let maxDelay = 300.0
    /// The most tiles held: past it, those the view has left go first.
    private static let maxTiles = 192

    private var imageFormat: String = TileCompositor.defaultFormat
    private var pyramid = TilePyramid(width: 1, height: 1)

    private var backdrop: Tile?
    /// Every tile and whole-level image, by `key(level:column:row:)`.
    private var tiles: [Int: Tile] = [:]
    /// The keys the last view needs, nearest its middle first.
    private var needed: [Int] = []
    private var neededLevel = -1
    /// One group a level, coarser ones under finer ones, all above the
    /// low-resolution copy.
    private var levelGroups: [(level: Int, group: DOM.Element)] = []

    private var container: DOM.Element?
    private var surface: DOM.Element?
    private var spinnerEl: DOM.Element?

    private var serviceID: String = ""
    /// A plain image shown whole in place of the service: no tiles, no probe.
    private var plainImage: String = ""
    /// Whether a canvas is shown: a probe or a tile that answers after it
    /// was put away draws nothing.
    private var showing = false
    private var imageW: Int = 0
    private var imageH: Int = 0

    // The view as last told, and whether its tiles have been asked for
    // since the canvas was shown.
    private var flushTimer: Int32 = -1
    private var flushed = false
    /// When the view began the move whose tiles are still to be asked for.
    private var movingSince: Double = 0
    private var pendingPanX: Double = 0
    private var pendingPanY: Double = 0
    private var pendingZoom: Double = 1
    private var pendingVW: Double = 0
    private var pendingVH: Double = 0
    /// Told once, the next time the view has all it needs.
    private var settledCallbacks: [() -> Void] = []

    // MARK: - Public API

    init(viewport: DOM.Element, spinner: DOM.Element) {
      spinnerEl = spinner
      let svgNamespace = "http://www.w3.org/2000/svg"
      let svg = document.createElementNS(svgNamespace, "svg")
      svg.setAttribute(.class, "canvas-tile-surface")
      let c = document.createElementNS(svgNamespace, "g")
      c.setAttribute(.class, "canvas-tile-compositor")
      svg.appendChild(c)
      viewport.insertBefore(svg, spinner)
      surface = svg
      container = c
    }

    func setCanvas(serviceID: String, width: Int, height: Int, image: String = "") {
      clear()
      setSpinner(true)
      self.serviceID = serviceID
      plainImage = image
      showing = true
      imageW = width
      imageH = height
      surface?.setAttribute("width", intToString(width))
      surface?.setAttribute("height", intToString(height))
      surface?.setAttribute("viewBox", "0 0 \(intToString(width)) \(intToString(height))")
      if !stringIsEmpty(image) {
        loadBackdrop()
        return
      }
      let base = TilePyramid.base(serviceID)
      let known = Self.info(forService: base)
      imageFormat = known?.format ?? Self.defaultFormat
      pyramid = TilePyramid(width: width, height: height, tileSize: known?.tileSize ?? TilePyramid.defaultTileSize)
      // The low-resolution copy at once: the probe it once waited for is
      // read beside it, and changes only what is asked for after.
      loadBackdrop()
      if case .none = known {
        Self.probe(base: base) { [self] format, tileSize in
          guard showing, stringEquals(TilePyramid.base(self.serviceID), base) else { return }
          imageFormat = format
          guard tileSize != pyramid.tileSize else { return }
          // Another grid: the tiles asked for on the guessed one go, the
          // view asks again on the service's own.
          dropTiles { _ in true }
          pyramid = TilePyramid(width: imageW, height: imageH, tileSize: tileSize)
          flush()
        }
      }
    }

    /// The format and tile side a host was found to serve, nil before any
    /// canvas of it has been probed.
    private static func info(forService base: String) -> HostInfo? {
      let host = host(of: base)
      for info in hostInfo where stringEquals(info.host, host) { return info }
      return nil
    }

    private static func probe(base: String, completion: @escaping @Sendable (String, Int) -> Void) {
      let host = host(of: base)
      for pending in probing where stringEquals(pending, host) { return }
      probing.append(host)
      window.fetch(TileURL.infoURL(from: base)) { response in
        let json = response.jsonString
        let format = TilePyramid.format(infoJSON: json)
        let tileSize = TilePyramid.tileSize(infoJSON: json) ?? TilePyramid.defaultTileSize
        probing = probing.filter { !stringEquals($0, host) }
        // An unread `info.json` (a refusal, a network error) settles
        // nothing: the next canvas asks again.
        if stringContains(json, "\"width\":") {
          hostInfo.append(HostInfo(host: host, format: format, tileSize: tileSize))
        }
        completion(format, tileSize)
      }
    }

    /// The host of a service URL, which keys what a host serves.
    private static func host(of base: String) -> String {
      guard let slashSlashIdx = stringIndexOf(base, "//") else { return base }
      let remaining = stringSubstring(base, from: slashSlashIdx + 2, to: base.utf8.count)
      guard let nextSlash = stringIndexOf(remaining, "/") else { return remaining }
      return stringSubstring(remaining, from: 0, to: nextSlash)
    }

    /// The view moved: the image follows at once; its tiles are asked for
    /// once it has rested 80 ms, or every 300 ms while it keeps moving (a
    /// long drag), at its latest place each time—never at each step of a
    /// gesture, whose next steps would leave those tiles at once.
    func update(panX: Double, panY: Double, zoom: Double, viewportW: Double, viewportH: Double) {
      container?.setAttribute(
        "transform", "translate(\(doubleToString(panX)) \(doubleToString(panY))) scale(\(doubleToString(zoom)))")
      pendingPanX = panX
      pendingPanY = panY
      pendingZoom = zoom
      pendingVW = viewportW
      pendingVH = viewportH
      guard showing, imageW > 0, imageH > 0, stringIsEmpty(plainImage) else { return }
      // A canvas just shown asks at once.
      guard flushed else {
        flush()
        return
      }
      let now = window.performance.now()
      if flushTimer >= 0 {
        window.clearTimeout(flushTimer)
      } else {
        movingSince = now
      }
      let due = min(now + Self.restDelay, movingSince + Self.maxDelay)
      flushTimer = window.setTimeout(max(0, due - now)) { [self] in
        flushTimer = -1
        flush()
      }
    }

    /// Whether the spinner is shown, so a tile's arrival writes nothing.
    private var spinnerShown = false

    private func setSpinner(_ shown: Bool) {
      guard shown != spinnerShown else { return }
      spinnerShown = shown
      spinnerEl?.setAttribute(data("visible"), shown ? "true" : "false")
    }

    /// `callback`, once the view has every tile it needs (or has given up
    /// on those that failed); at once if it has.
    func whenSettled(_ callback: @escaping () -> Void) {
      if showing, isSettled {
        callback()
      } else {
        settledCallbacks.append(callback)
      }
    }

    /// Its viewer is gone: every tile let go, as when the canvas is put
    /// away—their requests, retries and listeners, and the bridge's hold on
    /// their elements (a detached viewer's tiles were kept for the page's
    /// life, and a failed one's retry would have asked again).
    func detach() {
      clear()
    }

    /// Every tile let go, the low-resolution copy too, their requests with
    /// them: the canvas is put away. Shown again, it starts over from
    /// `setCanvas`.
    func clear() {
      showing = false
      cancelFlush()
      dropTiles { _ in true }
      if let backdrop { release(backdrop) }
      backdrop = nil
      for entry in levelGroups { container?.removeChild(entry.group); entry.group.forgetIfDetached() }
      levelGroups = []
      needed = []
      neededLevel = -1
      flushed = false
      settledCallbacks = []
      setSpinner(false)
    }

    /// The URLs showing a canvas asks for first, at the zoom it opens at:
    /// its low-resolution copy and, where the whole image is in view, that
    /// image at its level—fetched ahead for the canvases beside the one on
    /// screen. The same URLs the canvas then asks for, so they come from the
    /// browser's cache.
    static func openingURLs(
      serviceID: String, width: Int, height: Int, zoom: Double, viewportW: Double, viewportH: Double
    ) -> [String] {
      guard width > 0, height > 0 else { return [] }
      let base = TilePyramid.base(serviceID)
      let known = info(forService: base)
      let format = known?.format ?? defaultFormat
      let pyramid = TilePyramid(
        width: width, height: height, tileSize: known?.tileSize ?? TilePyramid.defaultTileSize)
      var urls = [pyramid.wholeURL(service: base, level: pyramid.backdropLevel, format: format)]
      let level = pyramid.level(devicePixels: zoom * devicePixelRatio)
      if level < pyramid.backdropLevel,
        pyramid.drawsWhole(level: level, zoom: zoom, viewportWidth: viewportW, viewportHeight: viewportH)
      {
        urls.insert(pyramid.wholeURL(service: base, level: level, format: format), at: 0)
      }
      return urls
    }

    private static var devicePixelRatio: Double {
      window.devicePixelRatio > 0 ? window.devicePixelRatio : 1
    }

    // MARK: - Private

    private func cancelFlush() {
      if flushTimer >= 0 {
        window.clearTimeout(flushTimer)
        flushTimer = -1
      }
    }

    /// A tile's key: its level, row and column; a level's whole image is
    /// its column -1.
    private func key(level: Int, column: Int, row: Int) -> Int {
      level * 100_000_000 + (row + 1) * 10_000 + (column + 1)
    }

    /// Asks for what the view needs now: the level its zoom wants, whole or
    /// the tiles it shows; lets go of the requests it no longer needs.
    private func flush() {
      guard showing, stringIsEmpty(plainImage), imageW > 0, imageH > 0, pendingZoom > 0 else { return }
      flushed = true
      let zoom = pendingZoom
      let level = pyramid.level(devicePixels: zoom * Self.devicePixelRatio)
      var wanted: [Int] = []
      // The low-resolution copy is fine enough: nothing more to ask for.
      if level < pyramid.backdropLevel {
        if pyramid.drawsWhole(level: level, zoom: zoom, viewportWidth: pendingVW, viewportHeight: pendingVH) {
          let key = key(level: level, column: -1, row: -1)
          request(
            key: key, level: level, url: pyramid.wholeURL(service: serviceID, level: level, format: imageFormat),
            x: 0, y: 0, width: imageW, height: imageH, overlapX: 0, overlapY: 0)
          wanted.append(key)
        } else {
          let columns = pyramid.columns(atLevel: level)
          let rows = pyramid.rows(atLevel: level)
          for tile in pyramid.visibleTiles(
            level: level, panX: pendingPanX, panY: pendingPanY, zoom: zoom, viewportWidth: pendingVW,
            viewportHeight: pendingVH)
          {
            let key = key(level: level, column: tile.column, row: tile.row)
            let box = pyramid.region(level: level, column: tile.column, row: tile.row)
            // One pixel of its level over the next tile's edge, where
            // there is a next tile: no seam of the copy beneath between
            // them.
            let overlap = 1 << level
            request(
              key: key, level: level,
              url: pyramid.tileURL(
                service: serviceID, level: level, column: tile.column, row: tile.row, format: imageFormat),
              x: box.x, y: box.y, width: box.width, height: box.height,
              overlapX: tile.column + 1 < columns ? overlap : 0, overlapY: tile.row + 1 < rows ? overlap : 0)
            wanted.append(key)
          }
        }
      }
      needed = wanted
      neededLevel = level
      // Requests the view has left, not yet answered, go; so do tiles past
      // the most held, those it has left first.
      dropTiles { [self] tile in
        !tile.loaded && !contains(wanted, tile.key)
      }
      if tiles.count > Self.maxTiles {
        dropTiles { [self] tile in !contains(wanted, tile.key) }
      }
      settle()
    }

    private func contains(_ keys: [Int], _ key: Int) -> Bool {
      for candidate in keys where candidate == key { return true }
      return false
    }

    /// A tile asked for, unless it is held already (a failed one is asked
    /// for again).
    private func request(
      key: Int, level: Int, url: String, x: Int, y: Int, width: Int, height: Int, overlapX: Int, overlapY: Int
    ) {
      if let held = tiles[key] {
        guard held.failed else { return }
        release(held)
        tiles.removeValue(forKey: key)
      }
      let img = image(x: x, y: y, width: width + overlapX, height: height + overlapY)
      group(forLevel: level)?.appendChild(img)
      let tile = Tile(element: img, key: key, level: level, url: url)
      tiles[key] = tile
      load(tile)
    }

    /// The image's request, and what it does when answered.
    private func load(_ tile: Tile) {
      tile.loadListener = tile.element.addEventListener(.load) { [self] _ in
        unlisten(tile)
        tile.loaded = true
        tile.element.setAttribute(data("loaded"), "true")
        settle()
      }
      tile.errorListener = tile.element.addEventListener(.error) { [self] _ in
        unlisten(tile)
        tile.attempts += 1
        guard tile.attempts <= Self.retryDelays.count else {
          tile.failed = true
          settle()
          return
        }
        tile.retryTimer = window.setTimeout(Self.retryDelays[tile.attempts - 1]) { [self] in
          tile.retryTimer = -1
          guard showing, let held = tiles[tile.key], held === tile else { return }
          tile.element.removeAttribute("href")
          load(tile)
        }
      }
      tile.element.setAttribute("href", tile.url)
    }

    private func unlisten(_ tile: Tile) {
      if tile.loadListener >= 0 { tile.element.removeEventListener(.load, tile.loadListener) }
      if tile.errorListener >= 0 { tile.element.removeEventListener(.error, tile.errorListener) }
      tile.loadListener = -1
      tile.errorListener = -1
    }

    /// A tile let go: its listeners, its retry, its request (an image whose
    /// `href` goes stops loading) and the bridge's hold on its element.
    private func release(_ tile: Tile) {
      unlisten(tile)
      if tile.retryTimer >= 0 {
        window.clearTimeout(tile.retryTimer)
        tile.retryTimer = -1
      }
      if !tile.loaded { tile.element.removeAttribute("href") }
      tile.element.parentElement?.removeChild(tile.element)
      tile.element.forgetIfDetached()
    }

    private func dropTiles(where shouldDrop: (Tile) -> Bool) {
      var dropped: [Int] = []
      for (key, tile) in tiles where shouldDrop(tile) {
        release(tile)
        dropped.append(key)
      }
      for key in dropped { tiles.removeValue(forKey: key) }
    }

    private var isSettled: Bool {
      if let backdrop, !backdrop.loaded, !backdrop.failed { return false }
      for key in needed {
        guard let tile = tiles[key] else { return false }
        if !tile.loaded && !tile.failed { return false }
      }
      return true
    }

    /// Once the view has what it needs: the spinner goes, other levels'
    /// tiles (kept beneath until now) go, and whoever waited is told.
    private func settle() {
      guard showing else { return }
      var copyShown = false
      if let backdrop { copyShown = backdrop.loaded }
      if copyShown || isSettled { setSpinner(false) }
      guard isSettled else { return }
      let level = neededLevel
      let wanted = needed
      dropTiles { [self] tile in tile.level != level || !contains(wanted, tile.key) && !tile.loaded }
      let callbacks = settledCallbacks
      settledCallbacks = []
      for callback in callbacks { callback() }
    }

    /// The low-resolution copy, or the plain image: under everything, kept
    /// until the canvas is put away.
    private func loadBackdrop() {
      guard imageW > 0, imageH > 0 else { return }
      let url =
        stringIsEmpty(plainImage)
        ? pyramid.wholeURL(service: serviceID, level: pyramid.backdropLevel, format: imageFormat) : plainImage
      let img = image(x: 0, y: 0, width: imageW, height: imageH)
      if let first = container?.firstChild {
        container?.insertBefore(img, first)
      } else {
        container?.appendChild(img)
      }
      let tile = Tile(element: img, key: -1, level: Int.max, url: url)
      backdrop = tile
      load(tile)
    }

    /// The group a level's images go in, made the first time: above the
    /// coarser levels' groups, below the finer ones'.
    private func group(forLevel level: Int) -> DOM.Element? {
      for entry in levelGroups where entry.level == level { return entry.group }
      guard let container else { return nil }
      let group = document.createElementNS("http://www.w3.org/2000/svg", "g")
      group.setAttribute(data("level"), intToString(level))
      // The first finer level's group, if any, is the one it goes under.
      var finer: DOM.Element?
      var index = levelGroups.count
      for (position, entry) in levelGroups.enumerated() where entry.level < level {
        finer = entry.group
        index = position
        break
      }
      if let finer {
        container.insertBefore(group, finer)
      } else {
        container.appendChild(group)
      }
      levelGroups.insert((level, group), at: index)
      return group
    }

    /// An image element over a stretch of the image (its pixels), hidden
    /// until it has loaded—what is beneath shows through until then.
    private func image(x: Int, y: Int, width: Int, height: Int) -> DOM.Element {
      let img = document.createElementNS("http://www.w3.org/2000/svg", "image")
      img.setAttribute(.class, "canvas-tile-image")
      img.setAttribute(.draggable, "false")
      img.setAttribute("x", intToString(x))
      img.setAttribute("y", intToString(y))
      img.setAttribute("width", intToString(width))
      img.setAttribute("height", intToString(height))
      // Stretched to its box exactly, the overlap included: no letterbox.
      img.setAttribute("preserveAspectRatio", "none")
      img.setAttribute(data("loaded"), "false")
      return img
    }
  }
#endif
