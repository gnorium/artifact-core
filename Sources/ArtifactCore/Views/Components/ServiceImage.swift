#if CLIENT
  import DOMBuilder
  import EmbeddedSwiftUtilities
  import WebAPIs
  import WebTypes

  /// What this page knows of the image services and the hosts it reads:
  /// each host's measured health (`HostHealth`) and each service's
  /// `info.json`, read once and shared by every canvas, thumbnail and
  /// lightbox that shows it.
  enum ImageServices {
    private nonisolated(unsafe) static var healths: [HostHealth] = []
    private nonisolated(unsafe) static var infos: [(service: String, info: ServiceInfo)] = []
    /// Services whose `info.json` is being read, and who waits for it.
    private nonisolated(unsafe) static var reading: [(service: String, waiting: [@Sendable (ServiceInfo?) -> Void])] =
      []

    static var now: Double { window.performance.now() }

    /// The host of a URL, which keys what a host serves.
    static func host(of url: String) -> String {
      // A relative address (the copy Gnorium kept, under the page's own
      // origin) is the page's own host, one for all of them.
      guard let slashSlash = stringIndexOf(url, "//") else { return "" }
      let remaining = stringSubstring(url, from: slashSlash + 2, to: url.utf8.count)
      guard let nextSlash = stringIndexOf(remaining, "/") else { return remaining }
      return stringSubstring(remaining, from: 0, to: nextSlash)
    }

    /// What this page knows of the host of `url`.
    static func health(forURL url: String) -> HostHealth {
      let name = host(of: url)
      for health in healths where stringEquals(health.name, name) { return health }
      let health = HostHealth(name: name)
      healths.append(health)
      return health
    }

    /// What a service advertises, if its `info.json` has been read.
    static func info(of service: String) -> ServiceInfo? {
      let base = TilePyramid.base(service)
      for entry in infos where stringEquals(entry.service, base) { return entry.info }
      return nil
    }

    /// Reads a service's `info.json` once, as its host's breaker for that
    /// class lets it, and tells `completion` what it advertises—nil where it
    /// is not read (refused, failed, or held back by the breaker).
    static func read(_ service: String, completion: @escaping @Sendable (ServiceInfo?) -> Void) {
      let base = TilePyramid.base(service)
      if let known = info(of: base) {
        completion(known)
        return
      }
      for index in reading.indices where stringEquals(reading[index].service, base) {
        reading[index].waiting.append(completion)
        return
      }
      let health = health(forURL: base)
      let gate = health.gate(.info, now: now)
      guard gate != .closed else {
        completion(nil)
        return
      }
      let probe = gate == .probe
      health.began(.info, probe: probe)
      reading.append((base, [completion]))
      let started = now
      window.fetch(TileURL.infoURL(from: base)) { response in
        let parsed = ServiceInfo.parse(response.jsonString)
        let elapsed = now - started
        if let parsed {
          infos.append((base, parsed))
          health.finished(.info, outcome: .answered(latency: elapsed), probe: probe, now: now)
        } else {
          health.finished(.info, outcome: .failed(after: elapsed), probe: probe, now: now)
        }
        var waiting: [@Sendable (ServiceInfo?) -> Void] = []
        var kept: [(service: String, waiting: [@Sendable (ServiceInfo?) -> Void])] = []
        for entry in reading {
          if stringEquals(entry.service, base) {
            waiting = entry.waiting
          } else {
            kept.append(entry)
          }
        }
        reading = kept
        for callback in waiting { callback(parsed) }
      }
    }
  }

  /// An `<img>` showing an image service's image whole, at a size the
  /// service advertises, through its host's health (`HostHealth`): never a
  /// region and never `max`, which a host such as the Internet Archive hangs
  /// on. A width that fails is let go for the next.
  public final class ServiceImage: @unchecked Sendable {
    private let image: DOM.Element
    private let base: String
    /// Whether its requests are timed and counted against the host: not a
    /// thumbnail's, which the browser may hold back until it is seen
    /// (`loading="lazy"`).
    private let measured: Bool
    private var candidates: [Int] = []
    private var index = 0
    private var started: Double = 0
    private var probe = false
    private var loadListener: Int32 = -1
    private var errorListener: Int32 = -1
    private var timer: Int32 = -1

    private init(image: DOM.Element, service: String, measured: Bool) {
      self.image = image
      self.base = TilePyramid.base(service)
      self.measured = measured
    }

    /// A thumbnail `deviceWidth` device pixels wide: the narrowest size the
    /// service advertises at least that wide, where the page has read what
    /// it advertises (the reader reads it for the page on screen); else that
    /// width itself, which any service past IIIF's level 0 answers.
    @discardableResult
    public static func showThumbnail(_ image: DOM.Element, service: String, deviceWidth: Int) -> ServiceImage {
      let shown = ServiceImage(image: image, service: service, measured: false)
      let wanted = max(1, deviceWidth)
      if let info = ImageServices.info(of: service) {
        let ladder = TilePyramid(width: info.width, height: info.height, info: info).wholeLadder
        var wide: [Int] = []
        for width in ladder.reversed() where width >= wanted { wide.append(width) }
        shown.candidates = wide.isEmpty ? Array(ladder.prefix(1)) : wide
      } else {
        shown.candidates = [wanted]
      }
      shown.next()
      return shown
    }

    /// The widest size the service advertises that answers, a narrower one
    /// each time one fails; where what it advertises cannot be read,
    /// `fallbackWidth` (the device pixels it is shown across) and its halves.
    @discardableResult
    public static func showLargest(_ image: DOM.Element, service: String, fallbackWidth: Int) -> ServiceImage {
      let shown = ServiceImage(image: image, service: service, measured: true)
      ImageServices.read(service) { info in
        if let info {
          shown.candidates = TilePyramid(width: info.width, height: info.height, info: info).wholeLadder
        } else {
          var widths: [Int] = []
          var width = max(1, fallbackWidth)
          while width >= 1 {
            widths.append(width)
            width /= 2
          }
          shown.candidates = widths
        }
        shown.next()
      }
      return shown
    }

    /// Lets go of its request, its listeners and its timer.
    public func stop() {
      unlisten()
      if timer >= 0 {
        window.clearTimeout(timer)
        timer = -1
      }
    }

    private func next() {
      let health = ImageServices.health(forURL: base)
      let now = ImageServices.now
      while index < candidates.count, health.isBad(width: candidates[index], now: now) { index += 1 }
      guard index < candidates.count else {
        // None left to try now: asked again when the host's next wait is
        // over (a thumbnail, not measured, is left empty).
        if measured, let then = health.nextChange(now: now) {
          index = 0
          timer = window.setTimeout(then - now) { [self] in
            timer = -1
            next()
          }
        }
        return
      }
      if measured {
        switch health.gate(.whole, now: now) {
        case .closed:
          if let then = health.nextChange(now: now) {
            timer = window.setTimeout(then - now) { [self] in
              timer = -1
              next()
            }
          }
          return
        case .probe: probe = true
        case .open: probe = false
        }
        started = now
        health.began(.whole, probe: probe)
        if !probe, let limit = health.timeout(.whole) {
          timer = window.setTimeout(limit) { [self] in
            timer = -1
            image.removeAttribute("src")
            finish(answered: false)
          }
        }
      }
      loadListener = image.addEventListener(.load) { [self] _ in finish(answered: true) }
      errorListener = image.addEventListener(.error) { [self] _ in finish(answered: false) }
      let format = ImageServices.info(of: base)?.format ?? ServiceInfo.defaultFormat
      image.setAttribute(
        "src",
        stringJoin([base, "/full/", intToString(candidates[index]), ",/0/default.", format], separator: ""))
    }

    private func unlisten() {
      if loadListener >= 0 { image.removeEventListener(.load, loadListener) }
      if errorListener >= 0 { image.removeEventListener(.error, errorListener) }
      loadListener = -1
      errorListener = -1
    }

    private func finish(answered: Bool) {
      guard loadListener >= 0 else { return }
      unlisten()
      if timer >= 0 {
        window.clearTimeout(timer)
        timer = -1
      }
      let health = ImageServices.health(forURL: base)
      let now = ImageServices.now
      let width = candidates[index]
      if answered {
        health.clearBad(width: width)
        if measured { health.finished(.whole, outcome: .answered(latency: now - started), probe: probe, now: now) }
        return
      }
      if measured {
        let elapsed = now - started
        health.finished(.whole, outcome: .failed(after: elapsed), probe: probe, now: now)
        health.markBad(width: width, now: now, after: elapsed)
      }
      index += 1
      next()
    }
  }
#endif
