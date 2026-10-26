#if CLIENT
  import CSSBuilder
  import DOMBuilder
  import EmbeddedSwiftUtilities
  import WebAPIs
  import WebTypes

  /// The tiles of one canvas. One per canvas, like its reader: the image,
  /// its tiles and their loads belong to one viewport.
  ///
  /// The image is read as its service advertises it (`TilePyramid`): first
  /// the whole image at the size its fit shows and the size below that, kept
  /// under everything; then what the zoom asks for—the whole image at the
  /// size it shows, while it all lies in view, else the tiles the view
  /// shows at the coarsest scale no coarser than the screen, nearest its
  /// middle first. A level stays over the coarser ones until the next has
  /// every tile the view needs, so a zoom never drops to a blurred copy; a
  /// tile the view has left before it arrived is let go, its request with
  /// it.
  ///
  /// A host that goes bad does not stall it (`HostHealth`): a request is
  /// abandoned at a timeout measured from the host's own answers, a failed
  /// one is asked again only while its class of request still works, and
  /// while tiles do not, the widest whole image the host serves stands in—
  /// zoomed in past it, the image is that image, larger, never a blank tile.
  final class TileCompositor: @unchecked Sendable {
    /// One image on the surface: a tile, the whole image at a width, or
    /// a plain image (a copy of what was sent).
    private final class Tile: @unchecked Sendable {
      let key: Int
      /// Pixels across the whole image it gives; the higher, the nearer the
      /// top.
      let rank: Int
      let kind: HostHealth.Kind
      let health: HostHealth
      let url: String
      /// Its place on the image, overlap included.
      let x: Int
      let y: Int
      let width: Int
      let height: Int
      /// The width of the whole image it asks for, 0 for any other.
      let wholeWidth: Int
      /// One of the canvas's first copies (the fit's size and the one
      /// below), kept under everything until the canvas is put away.
      let isCopy: Bool
      var element: DOM.Element?
      /// Out to the host and not answered.
      var started = false
      var loaded = false
      /// Given up on; made again if a later view asks for it.
      var failed = false
      var attempts = 0
      var startedAt: Double = 0
      /// The one request that tests the host.
      var probe = false
      /// Out with as many others as a browser sends to a host at once.
      var suspect = false
      var loadListener: Int32 = -1
      var errorListener: Int32 = -1
      var timeoutTimer: Int32 = -1

      init(
        key: Int, rank: Int, kind: HostHealth.Kind, health: HostHealth, url: String, x: Int, y: Int, width: Int,
        height: Int, wholeWidth: Int, isCopy: Bool
      ) {
        self.key = key
        self.rank = rank
        self.kind = kind
        self.health = health
        self.url = url
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.wholeWidth = wholeWidth
        self.isCopy = isCopy
      }
    }

    /// Keys: a tile's by its scale factor, row and column; a whole image's
    /// by its width, above every tile's; a plain image's alone. An
    /// encoding, not a tuning: rows and columns below 10 000, scale factors
    /// below 9.
    private static let wholeKeyBase = 900_000_000
    private static let plainKey = -1

    private var pyramid = TilePyramid(width: 1, height: 1)
    private var health: HostHealth?
    private var imageFormat = ServiceInfo.defaultFormat

    /// Every image on the surface, by key.
    private var tiles: [Int: Tile] = [:]
    /// The first copies' keys (fixed once asked for, but for one that
    /// fails).
    private var copyKeys: [Int] = []
    /// The keys the view needs to be settled, and the rank they are.
    private var needed: [Int] = []
    private var neededRank = -1
    /// Whether the last view stood in a whole image for tiles the host is
    /// not answering: the finer images already shown stay over it.
    private var degraded = false
    /// The keys waiting for the host's breaker, in the order to ask.
    private var queue: [Int] = []
    /// One group a rank, finer over coarser.
    private var rankGroups: [(rank: Int, group: DOM.Element)] = []

    private var container: DOM.Element?
    private var surface: DOM.Element?
    /// The rectangle of the image in its own pixels, which the group of
    /// tiles is clipped to.
    private var clipRect: DOM.Element?
    private var spinnerEl: DOM.Element?
    private nonisolated(unsafe) static var surfaces = 0

    private var serviceID: String = ""
    /// A plain image shown whole in place of the service—the archived copy
    /// of what was sent: no tiles.
    private var plainImage: String = ""
    /// The plain images tried after it, in order, where it fails to load.
    private var laterImages: [String] = []
    /// Whether the service's own image may stand in where no plain image
    /// loads: never for a page changed at its source, whose image now is
    /// not what was sent (`ArtifactManifest.Page.live`, user, 2026-10-17).
    private var serviceAllowed = true
    /// Told when the canvas is left with no image: every plain image failed
    /// to load, and the service's own may not stand in.
    var onNoImage: (() -> Void)?
    /// Whether a canvas is shown: an answer that arrives after it was put
    /// away draws nothing.
    private var showing = false
    private var imageW: Int = 0
    private var imageH: Int = 0

    // The view as last told; whether its images have been asked for since
    // the canvas was shown; the frame the next ask waits on.
    private var flushed = false
    private var frameRequest: Int32 = -1
    private var movedThisFrame = false
    /// When the view began the move whose images are still to be asked
    /// for; negative at rest.
    private var movingSince: Double = -1
    /// When the host's next wait is over, asked again then.
    private var changeTimer: Int32 = -1
    private var changeAt: Double = -1
    private var pendingPanX: Double = 0
    private var pendingPanY: Double = 0
    private var pendingZoom: Double = 1
    private var pendingVW: Double = 0
    private var pendingVH: Double = 0
    /// Told once, the next time the view has all it needs.
    private var settledCallbacks: [() -> Void] = []
    private var spinnerShown = false

    // MARK: - Public API

    init(viewport: DOM.Element, spinner: DOM.Element) {
      spinnerEl = spinner
      let svgNamespace = "http://www.w3.org/2000/svg"
      // The viewport's own size, user units its CSS pixels (`ImageView`'s
      // styles); its one group carries the pan and zoom, and is clipped to
      // the image's rectangle in the group's own units: whatever is drawn
      // lies on the image, at any zoom, and a stale strip of an earlier
      // zoom has no place to be drawn beside it.
      let svg = document.createElementNS(svgNamespace, "svg")
      svg.setAttribute(.class, "image-tile-surface")
      Self.surfaces += 1
      let clipID = "image-tile-clip-\(intToString(Self.surfaces))"
      let defs = document.createElementNS(svgNamespace, "defs")
      let clip = document.createElementNS(svgNamespace, "clipPath")
      clip.setAttribute("id", clipID)
      let rect = document.createElementNS(svgNamespace, "rect")
      rect.setAttribute("x", "0")
      rect.setAttribute("y", "0")
      clip.appendChild(rect)
      defs.appendChild(clip)
      svg.appendChild(defs)
      let c = document.createElementNS(svgNamespace, "g")
      c.setAttribute(.class, "image-tile-compositor")
      c.setAttribute("clip-path", "url(#\(clipID))")
      svg.appendChild(c)
      viewport.insertBefore(svg, spinner)
      surface = svg
      container = c
      clipRect = rect
    }

    /// The canvas, `width` by `height`: the first of `images` that loads,
    /// shown whole in place of its service; the service's own image where
    /// there are none, or where none loads and `live` lets it stand in;
    /// else no image (`onNoImage`).
    func setCanvas(serviceID: String, width: Int, height: Int, images: [String] = [], live: Bool = true) {
      clear()
      setSpinner(true)
      self.serviceID = serviceID
      plainImage = ""
      laterImages = images
      serviceAllowed = live
      showing = true
      imageW = width
      imageH = height
      clipRect?.setAttribute("width", intToString(width))
      clipRect?.setAttribute("height", intToString(height))
      if !images.isEmpty || !live {
        showNextImage()
        return
      }
      beginService()
    }

    /// Whether the canvas reads its image service: no plain image in its
    /// place, and the service allowed to stand in.
    private var drawsService: Bool { stringIsEmpty(plainImage) && serviceAllowed }

    /// The service's own image: what it advertises, as far as this page has
    /// read it, and its `info.json` read for the rest; read, the view asks
    /// again on what it says.
    private func beginService() {
      let base = TilePyramid.base(serviceID)
      health = ImageServices.health(forURL: base)
      let known = ImageServices.info(of: base)
      imageFormat = known?.format ?? ServiceInfo.defaultFormat
      pyramid = TilePyramid(width: imageW, height: imageH, info: known)
      readInfo()
    }

    /// Whether this canvas's `info.json` is being read.
    private var readingInfo = false

    /// Reads the service's `info.json` where it is not yet read and no read
    /// is under way—again at a later view where its host's breaker held the
    /// last back.
    private func readInfo() {
      guard showing, drawsService, !readingInfo else { return }
      if case .some = pyramid.info { return }
      let base = TilePyramid.base(serviceID)
      // Read by another canvas or view already: taken as it is.
      if let known = ImageServices.info(of: base) {
        imageFormat = known.format
        pyramid = TilePyramid(width: imageW, height: imageH, info: known)
        return
      }
      readingInfo = true
      ImageServices.read(base) { [self] info in
        readingInfo = false
        guard showing, stringEquals(TilePyramid.base(self.serviceID), base), let info else { return }
        imageFormat = info.format
        pyramid = TilePyramid(width: imageW, height: imageH, info: info)
        if flushed { flush() }
      }
    }

    /// The next plain image, where its host lets it be asked for: the first
    /// one, or the one after a copy that could not be read. Past the last,
    /// the service's image in their place where it may stand in (the
    /// reader's panel says so); else none—never the image now of a page
    /// changed at its source, which is not what was sent (user, 2026-10-17).
    private func showNextImage() {
      guard showing else { return }
      dropTiles { _ in true }
      copyKeys = []
      queue = []
      while !laterImages.isEmpty {
        let image = laterImages.removeFirst()
        let host = ImageServices.health(forURL: image)
        if host.gate(.whole, now: ImageServices.now) == .closed { continue }
        plainImage = image
        let tile = Tile(
          key: Self.plainKey, rank: 0, kind: .whole, health: host, url: image, x: 0, y: 0, width: imageW,
          height: imageH, wholeWidth: 0, isCopy: true)
        tiles[Self.plainKey] = tile
        copyKeys = [Self.plainKey]
        queue = [Self.plainKey]
        pump()
        return
      }
      plainImage = ""
      guard serviceAllowed else {
        // Nothing drawn: whoever waits for the view is told it has all it
        // will, and the reader that the page has no image.
        setSpinner(false)
        settle()
        onNoImage?()
        return
      }
      flushed = false
      beginService()
      if pendingVW > 0 { flush() }
    }

    /// The view moved: the image follows at once; what it shows is asked for
    /// at the first frame the view rests in, and, while it keeps moving, each
    /// time as long as the host typically takes to answer has passed—never
    /// faster than the host can answer.
    func update(panX: Double, panY: Double, zoom: Double, viewportW: Double, viewportH: Double) {
      // The image's corner on a device pixel: its edge is one sharp line,
      // never a blurred one a repaint leaves a ghost of.
      let density = Self.devicePixelRatio
      let left = (panX * density).rounded() / density
      let top = (panY * density).rounded() / density
      container?.setAttribute(
        "transform", "translate(\(doubleToString(left)) \(doubleToString(top))) scale(\(doubleToString(zoom)))")
      pendingPanX = panX
      pendingPanY = panY
      pendingZoom = zoom
      pendingVW = viewportW
      pendingVH = viewportH
      guard showing, imageW > 0, imageH > 0, drawsService else { return }
      // A canvas just shown asks at once.
      guard flushed else {
        flush()
        return
      }
      movedThisFrame = true
      if movingSince < 0 { movingSince = ImageServices.now }
      if frameRequest < 0 { frameRequest = window.requestAnimationFrame { [self] in frameTick() } }
    }

    private func frameTick() {
      frameRequest = -1
      guard showing else { return }
      guard movedThisFrame else {
        movingSince = -1
        flush()
        return
      }
      movedThisFrame = false
      if let typical = health?.typical(.tile), ImageServices.now - movingSince >= typical {
        movingSince = ImageServices.now
        flush()
      }
      frameRequest = window.requestAnimationFrame { [self] in frameTick() }
    }

    /// `callback`, once the view has every image it needs (or has given up
    /// on those that failed); at once if it has.
    func whenSettled(_ callback: @escaping () -> Void) {
      if showing, isSettled {
        callback()
      } else {
        settledCallbacks.append(callback)
      }
    }

    /// Its viewer is gone: every image let go, as when the canvas is put
    /// away—their requests, timers and listeners, and the bridge's hold on
    /// their elements.
    func detach() {
      clear()
    }

    /// Every image let go, their requests with them: the canvas is put away.
    /// Shown again, it starts over from `setCanvas`.
    func clear() {
      showing = false
      if frameRequest >= 0 {
        window.cancelAnimationFrame(frameRequest)
        frameRequest = -1
      }
      if changeTimer >= 0 {
        window.clearTimeout(changeTimer)
        changeTimer = -1
      }
      changeAt = -1
      movedThisFrame = false
      movingSince = -1
      readingInfo = false
      dropTiles { _ in true }
      for entry in rankGroups { container?.removeChild(entry.group); entry.group.forgetIfDetached() }
      rankGroups = []
      copyKeys = []
      queue = []
      needed = []
      neededRank = -1
      degraded = false
      flushed = false
      settledCallbacks = []
      setSpinner(false)
    }

    /// The URLs showing a canvas asks for first: its first copies, at the
    /// fit of a viewport `viewportW` by `viewportH`—fetched ahead for the
    /// canvases beside the one on screen. The same URLs the canvas then asks
    /// for, so they come from the browser's cache; none while its host is not
    /// answering whole images.
    static func openingURLs(serviceID: String, width: Int, height: Int, viewportW: Double, viewportH: Double)
      -> [String]
    {
      guard width > 0, height > 0, viewportW > 0, viewportH > 0 else { return [] }
      let base = TilePyramid.base(serviceID)
      let health = ImageServices.health(forURL: base)
      let now = ImageServices.now
      guard health.gate(.whole, now: now) == .open else { return [] }
      let info = ImageServices.info(of: base)
      let pyramid = TilePyramid(width: width, height: height, info: info)
      let format = info?.format ?? ServiceInfo.defaultFormat
      var urls: [String] = []
      for copy in copyWidths(pyramid: pyramid, viewportW: viewportW, viewportH: viewportH, health: health, now: now) {
        urls.append(pyramid.wholeURL(service: base, width: copy, format: format))
      }
      return urls
    }

    /// How long a neighbor's preload may wait for the host of `serviceID`:
    /// its whole images' timeout; nil for the browser's own.
    static func preloadTimeout(serviceID: String) -> Double? {
      ImageServices.health(forURL: TilePyramid.base(serviceID)).timeout(.whole)
    }

    // MARK: - Private

    private static var devicePixelRatio: Double {
      window.devicePixelRatio > 0 ? window.devicePixelRatio : 1
    }

    /// The first copies' widths, the one to show first first: the size
    /// below the fit's, then the fit's—the narrowest the host serves at
    /// least as wide as the fit shows on this screen.
    private static func copyWidths(
      pyramid: TilePyramid, viewportW: Double, viewportH: Double, health: HostHealth, now: Double
    ) -> [Int] {
      let fit = min(viewportW / Double(pyramid.width), viewportH / Double(pyramid.height))
      let fitNeeded = Int((fit * devicePixelRatio * Double(pyramid.width)).rounded(.up))
      guard let fitWidth = pyramid.wholeWidth(atLeast: fitNeeded, unusable: { health.isBad(width: $0, now: now) })
      else { return [] }
      var widths = [fitWidth]
      if let below = pyramid.wholeWidth(
        atLeast: Int.max, below: fitWidth, unusable: { health.isBad(width: $0, now: now) })
      {
        widths.insert(below, at: 0)
      }
      return widths
    }

    private func setSpinner(_ shown: Bool) {
      guard shown != spinnerShown else { return }
      spinnerShown = shown
      spinnerEl?.setAttribute(data("visible"), shown ? "true" : "false")
    }

    /// A tile's key: its scale factor, row and column.
    private func tileKey(scale: Int, column: Int, row: Int) -> Int {
      scale * 100_000_000 + (row + 1) * 10_000 + (column + 1)
    }

    /// Asks for what the view needs now and lets go of the requests it no
    /// longer needs.
    private func flush() {
      guard showing, drawsService, imageW > 0, imageH > 0, pendingZoom > 0, pendingVW > 0,
        pendingVH > 0, let health
      else { return }
      flushed = true
      readInfo()
      let now = ImageServices.now
      let zoom = pendingZoom
      let unusable: (Int) -> Bool = { health.isBad(width: $0, now: now) }
      // The first copies, once; again where one failed.
      var copiesHeld = false
      for key in copyKeys where !(tiles[key]?.failed ?? true) { copiesHeld = true }
      if !copiesHeld {
        copyKeys = []
        for width in Self.copyWidths(pyramid: pyramid, viewportW: pendingVW, viewportH: pendingVH, health: health, now: now) {
          copyKeys.append(requestWhole(width: width, health: health, isCopy: true))
        }
      }
      let neededWidth = Int((zoom * Self.devicePixelRatio * Double(imageW)).rounded(.up))
      let inView =
        (Double(imageW) * zoom).rounded() <= pendingVW.rounded()
        && (Double(imageH) * zoom).rounded() <= pendingVH.rounded()
      let tileGate = health.gate(.tile, now: now)
      var wanted: [Int] = []
      var alongside: [Int] = []
      var rank = 0
      degraded = false
      let whole = pyramid.wholeWidth(atLeast: neededWidth, unusable: unusable)
      let wholeEnough = whole.map { $0 >= neededWidth } ?? false
      if (inView && wholeEnough) || !pyramid.hasTiles {
        // The whole image, at the size the view shows (or the widest the
        // host serves, where it advertises no tiles).
        if let whole {
          wanted.append(requestWhole(width: whole, health: health, isCopy: false))
          rank = whole
        }
      } else if tileGate == .open {
        let scale = pyramid.tileScale(needed: neededWidth)
        rank = TilePyramid.scaled(imageW, by: scale)
        for tile in pyramid.visibleTiles(
          scale: scale, panX: pendingPanX, panY: pendingPanY, zoom: zoom, viewportWidth: pendingVW,
          viewportHeight: pendingVH)
        {
          wanted.append(requestTile(scale: scale, column: tile.column, row: tile.row, health: health))
        }
      } else {
        // Tiles are not answered (or not yet proven): the whole image the
        // host serves that comes nearest the view, and, when the host may
        // be tested, the tile nearest the view's middle.
        degraded = true
        if let whole, health.gate(.whole, now: now) != .closed {
          wanted.append(requestWhole(width: whole, health: health, isCopy: false))
          rank = whole
        }
        if tileGate == .probe {
          let scale = pyramid.tileScale(needed: neededWidth)
          if let first = pyramid.visibleTiles(
            scale: scale, panX: pendingPanX, panY: pendingPanY, zoom: zoom, viewportWidth: pendingVW,
            viewportHeight: pendingVH
          ).first {
            alongside.append(requestTile(scale: scale, column: first.column, row: first.row, health: health))
          }
        }
      }
      needed = wanted
      neededRank = rank
      // A request testing the host runs to its end, wherever the view has
      // gone: its answer is what the host is learned by.
      for (key, tile) in tiles where tile.probe && tile.started && !contains(alongside, key) { alongside.append(key) }
      // Requests the view has left, not yet answered, go.
      let keep = copyKeys + wanted + alongside
      dropTiles { [self] tile in !tile.loaded && !contains(keep, tile.key) }
      // Asked for in the order the view needs them.
      queue = keep.filter { key in
        guard let tile = tiles[key] else { return false }
        return !tile.started && !tile.loaded && !tile.failed
      }
      pump()
      settle()
    }

    private func contains(_ keys: [Int], _ key: Int) -> Bool {
      for candidate in keys where candidate == key { return true }
      return false
    }

    private func requestWhole(width: Int, health: HostHealth, isCopy: Bool) -> Int {
      let key = Self.wholeKeyBase + width
      ensure(
        Tile(
          key: key, rank: width, kind: .whole, health: health,
          url: pyramid.wholeURL(service: serviceID, width: width, format: imageFormat), x: 0, y: 0, width: imageW,
          height: imageH, wholeWidth: width, isCopy: isCopy))
      return key
    }

    private func requestTile(scale: Int, column: Int, row: Int, health: HostHealth) -> Int {
      let key = tileKey(scale: scale, column: column, row: row)
      let box = pyramid.region(scale: scale, column: column, row: row)
      // One pixel of its scale over the next tile's edge, where there is a
      // next tile: no seam of the copy beneath between them.
      let overlapX = column + 1 < pyramid.columns(scale: scale) ? scale : 0
      let overlapY = row + 1 < pyramid.rows(scale: scale) ? scale : 0
      ensure(
        Tile(
          key: key, rank: TilePyramid.scaled(imageW, by: scale), kind: .tile, health: health,
          url: pyramid.tileURL(service: serviceID, scale: scale, column: column, row: row, format: imageFormat),
          x: box.x, y: box.y, width: box.width + overlapX, height: box.height + overlapY, wholeWidth: 0,
          isCopy: false))
      return key
    }

    /// An image held, or made to be asked for; one that failed is made
    /// again (whether to ask again is the host's breaker's to say).
    private func ensure(_ tile: Tile) {
      if let held = tiles[tile.key] {
        guard held.failed else { return }
        release(held)
        tiles.removeValue(forKey: tile.key)
      }
      tiles[tile.key] = tile
    }

    /// Starts what is queued where its host's breaker lets that class of
    /// request through; the rest wait. The browser keeps its own queue per
    /// host: this page keeps none.
    private func pump() {
      guard showing else { return }
      let now = ImageServices.now
      var waiting: [Int] = []
      for key in queue {
        guard let tile = tiles[key], !tile.started, !tile.loaded, !tile.failed else { continue }
        switch tile.health.gate(tile.kind, now: now) {
        case .open: start(tile, probe: false)
        case .probe: start(tile, probe: true)
        case .closed: waiting.append(key)
        }
      }
      queue = waiting
      scheduleChange()
    }

    /// The request goes out, abandoned if it is not answered by the host's
    /// fence (a probe never is).
    private func start(_ tile: Tile, probe: Bool) {
      tile.started = true
      tile.probe = probe
      tile.startedAt = ImageServices.now
      tile.suspect = tile.health.began(tile.kind, probe: probe)
      if tile.element == nil { tile.element = makeElement(tile) }
      guard let element = tile.element else { return }
      // Asked again: the same address is a new request only once it has gone.
      if tile.attempts > 0 { element.removeAttribute("href") }
      tile.loadListener = element.addEventListener(.load) { [self] _ in answered(tile) }
      tile.errorListener = element.addEventListener(.error) { [self] _ in failed(tile, timedOut: false) }
      if !probe, let limit = tile.health.timeout(tile.kind) {
        tile.timeoutTimer = window.setTimeout(limit) { [self] in
          tile.timeoutTimer = -1
          guard tile.started else { return }
          // Cancelled, so its connection is free for what would be answered.
          element.removeAttribute("href")
          failed(tile, timedOut: true)
        }
      }
      element.setAttribute("href", tile.url)
    }

    private func answered(_ tile: Tile) {
      guard tile.started else { return }
      let now = ImageServices.now
      let latency = now - tile.startedAt
      finishRequest(tile)
      tile.loaded = true
      tile.element?.setAttribute(data("loaded"), "true")
      if tile.wholeWidth > 0 { tile.health.clearBad(width: tile.wholeWidth) }
      let changed = tile.health.finished(tile.kind, outcome: .answered(latency: latency), probe: tile.probe, now: now)
      tile.probe = false
      if changed { flush() } else { pump() }
      settle()
    }

    private func failed(_ tile: Tile, timedOut: Bool) {
      guard tile.started else { return }
      let now = ImageServices.now
      let elapsed = now - tile.startedAt
      finishRequest(tile)
      tile.attempts += 1
      if timedOut && tile.suspect && tile.attempts == 1 {
        // Out with as many others as a browser sends to a host at once, it
        // may never have been sent: not the host's failure. Let go, and
        // asked again at once.
        tile.health.cancelled(tile.kind, probe: tile.probe)
        tile.probe = false
        queue.append(tile.key)
        pump()
        return
      }
      tile.health.finished(tile.kind, outcome: .failed(after: elapsed), probe: tile.probe, now: now)
      tile.probe = false
      if tile.key == Self.plainKey {
        showNextImage()
        return
      }
      if tile.wholeWidth > 0 {
        // A width the host does not serve now: the next one is asked for.
        tile.health.markBad(width: tile.wholeWidth, now: now, after: elapsed)
      } else if tile.health.gate(tile.kind, now: now) == .open {
        // Asked again at once, while its class of request works; the
        // breaker bounds how often.
        queue.append(tile.key)
        pump()
        return
      }
      tile.failed = true
      flush()
    }

    /// A request no longer out: its timer and listeners stopped.
    private func finishRequest(_ tile: Tile) {
      tile.started = false
      if tile.timeoutTimer >= 0 {
        window.clearTimeout(tile.timeoutTimer)
        tile.timeoutTimer = -1
      }
      unlisten(tile)
    }

    private func unlisten(_ tile: Tile) {
      guard let element = tile.element else { return }
      if tile.loadListener >= 0 { element.removeEventListener(.load, tile.loadListener) }
      if tile.errorListener >= 0 { element.removeEventListener(.error, tile.errorListener) }
      tile.loadListener = -1
      tile.errorListener = -1
    }

    /// The view asked again when the host's next wait is over (a breaker's
    /// cool-down, a width left alone), so a view at rest recovers too.
    private func scheduleChange() {
      guard showing, let health else { return }
      let now = ImageServices.now
      guard let then = health.nextChange(now: now) else { return }
      if changeTimer >= 0 {
        guard then < changeAt else { return }
        window.clearTimeout(changeTimer)
      }
      changeAt = then
      changeTimer = window.setTimeout(then - now) { [self] in
        changeTimer = -1
        changeAt = -1
        flush()
      }
    }

    /// An image let go: its listeners, its timer, its request (an image
    /// whose `href` goes stops loading) and the bridge's hold on its
    /// element.
    private func release(_ tile: Tile) {
      if tile.started {
        tile.started = false
        tile.health.cancelled(tile.kind, probe: tile.probe)
        tile.probe = false
      }
      unlisten(tile)
      if tile.timeoutTimer >= 0 {
        window.clearTimeout(tile.timeoutTimer)
        tile.timeoutTimer = -1
      }
      guard let element = tile.element else { return }
      if !tile.loaded { element.removeAttribute("href") }
      element.parentElement?.removeChild(element)
      element.forgetIfDetached()
      tile.element = nil
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
      // A copy that failed and was let go is settled; a needed image is
      // always held.
      for key in copyKeys {
        guard let tile = tiles[key] else { continue }
        if !tile.loaded && !tile.failed { return false }
      }
      for key in needed {
        guard let tile = tiles[key] else { return false }
        if !tile.loaded && !tile.failed { return false }
      }
      return true
    }

    /// Once the view has what it needs: the spinner goes, the images it no
    /// longer needs go, and whoever waited is told.
    private func settle() {
      guard showing else { return }
      var copyShown = false
      for key in copyKeys where tiles[key]?.loaded ?? false { copyShown = true }
      if copyShown || isSettled { setSpinner(false) }
      guard isSettled else { return }
      // What the view does not need goes: the first copies stay; coarser
      // images than it needs, and those of its rank it does not; finer ones
      // too, but where a whole image stands in for tiles the host is not
      // answering—what was shown sharper stays over it.
      let rank = neededRank
      let wanted = needed
      let keepFiner = degraded
      dropTiles { [self] tile in
        if tile.isCopy { return tile.failed }
        if contains(wanted, tile.key) || (tile.probe && tile.started) { return false }
        if tile.rank > rank && keepFiner && tile.loaded { return false }
        return true
      }
      let callbacks = settledCallbacks
      settledCallbacks = []
      for callback in callbacks { callback() }
    }

    /// The image element of a tile, in the group of its rank.
    private func makeElement(_ tile: Tile) -> DOM.Element {
      let img = document.createElementNS("http://www.w3.org/2000/svg", "image")
      img.setAttribute(.class, "image-tile-image")
      img.setAttribute(.draggable, "false")
      img.setAttribute("x", intToString(tile.x))
      img.setAttribute("y", intToString(tile.y))
      img.setAttribute("width", intToString(tile.width))
      img.setAttribute("height", intToString(tile.height))
      // Stretched to its box exactly, the overlap included: no letterbox.
      img.setAttribute("preserveAspectRatio", "none")
      // Hidden until it has loaded: what is beneath shows through until then.
      img.setAttribute(data("loaded"), "false")
      group(forRank: tile.rank)?.appendChild(img)
      return img
    }

    /// The group a rank's images go in, made the first time: above the
    /// coarser ranks' groups, below the finer ones'.
    private func group(forRank rank: Int) -> DOM.Element? {
      for entry in rankGroups where entry.rank == rank { return entry.group }
      guard let container else { return nil }
      let group = document.createElementNS("http://www.w3.org/2000/svg", "g")
      group.setAttribute(data("rank"), intToString(rank))
      var finer: DOM.Element?
      var index = rankGroups.count
      for (position, entry) in rankGroups.enumerated() where entry.rank > rank {
        finer = entry.group
        index = position
        break
      }
      if let finer {
        container.insertBefore(group, finer)
      } else {
        container.appendChild(group)
      }
      rankGroups.insert((rank, group), at: index)
      return group
    }
  }
#endif
