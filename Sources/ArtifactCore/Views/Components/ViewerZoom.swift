import EmbeddedSwiftUtilities

/// How a reader's views zoom, the image's and the text's alike (user,
/// 2026-10-12): from the fit of the whole page to its actual size, the
/// wheel zooming in proportion to its travel. A double-click is the
/// browser's own (it selects, and Live Text reads it): no zoom.
///
/// One model for every image that is panned and zoomed where it stands (user,
/// 2026-10-17): the artifact's canvases and the images a session shows as
/// the model received them. ``Surface`` is its state and arithmetic, ``Input``
/// the wheel and Safari's pinch that drive it, ``command(forKey:)`` its keys.
public enum ViewerZoom {
  /// The actual size: one pixel of the image (its full resolution), or
  /// of the text, to one CSS pixel. The most a view zooms in, unless its
  /// fit is larger still.
  public static let actualSize = 1.0
  /// The session's image zoom: "fit", or a zoom.
  static let imageKey = "gnorium:artifact-zoom:image"

  /// What a view shows of its page (pane sync, a dev experiment, user
  /// 2026-10-12): the point at the view's middle as fractions of the
  /// page's width and height, and its zoom over its fit—so two views of
  /// one page, the image and its text, show the same part of it, each by
  /// its own fit.
  struct Region {
    let centerX: Double
    let centerY: Double
    let scale: Double
    /// The most its zoom over its fit can be (the image's actual size
    /// over its fit), which the text mirrors while matched.
    let maxScale: Double
  }
  /// A wheel's travel counted in one event, at most, so a mouse wheel's
  /// notch is not too fast.
  public static let wheelTravel = 40.0
  /// The zoom one unit of the wheel's travel makes.
  public static let wheelStep = 0.005

  /// What one wheel event multiplies the zoom by: in proportion to its
  /// travel (`deltaY`), capped.
  public static func wheelFactor(_ deltaY: Double) -> Double {
    1.0 - max(-wheelTravel, min(wheelTravel, deltaY)) * wheelStep
  }

  /// What a key does to a focused view: + and − zoom by a wheel's step about
  /// the middle, 0 fits it again, the arrows pan by a wheel's travel.
  public enum Command: Sendable {
    case zoomIn
    case zoomOut
    case fit
    /// The image moved by this much in the view (the arrow's opposite, as
    /// the image follows the view's scrolling).
    case pan(x: Double, y: Double)

    /// What the command multiplies the zoom by, for the two that zoom.
    public var factor: Double {
      switch self {
      case .zoomIn: return ViewerZoom.wheelFactor(-ViewerZoom.wheelTravel)
      case .zoomOut: return ViewerZoom.wheelFactor(ViewerZoom.wheelTravel)
      case .fit, .pan: return 1
      }
    }
  }

  /// The command `key` (a `KeyboardEvent.key`) gives; nil for any other.
  public static func command(forKey key: String) -> Command? {
    if stringEquals(key, "+") || stringEquals(key, "=") { return .zoomIn }
    if stringEquals(key, "-") { return .zoomOut }
    if stringEquals(key, "0") { return .fit }
    if stringEquals(key, "ArrowLeft") { return .pan(x: wheelTravel, y: 0) }
    if stringEquals(key, "ArrowRight") { return .pan(x: -wheelTravel, y: 0) }
    if stringEquals(key, "ArrowUp") { return .pan(x: 0, y: wheelTravel) }
    if stringEquals(key, "ArrowDown") { return .pan(x: 0, y: -wheelTravel) }
    return nil
  }

  /// One image on a surface (a viewport) it is zoomed and panned on, and the
  /// arithmetic of it, with no DOM: zoom is the surface's pixels (CSS
  /// pixels) to a pixel of the image, from the image's fit in the surface up
  /// to its actual size (one image pixel to one CSS pixel) and no further,
  /// unless the fit is larger. A zoom at the fit follows the surface as it
  /// changes size (`atFit`); any other is kept, clamped. The image is never
  /// panned fully out of the surface: larger than it, it covers it; smaller,
  /// it stands centered.
  public struct Surface: Sendable {
    /// The image's own pixels (0: not read yet).
    public var imageWidth = 0.0
    public var imageHeight = 0.0
    public var viewportWidth = 0.0
    public var viewportHeight = 0.0
    public var zoom = 1.0
    /// The fit: the zoom that shows the whole image in the surface.
    public var minZoom = 0.01
    /// Whether the image is at its fit, which it follows as the surface
    /// changes size; any other zoom is clamped.
    public var atFit = true
    /// Where the image's top left stands in the surface.
    public var panX = 0.0
    public var panY = 0.0

    public init() {}

    /// The most it zooms in: its actual size, or its fit where that is
    /// larger.
    public var maxZoom: Double { max(minZoom, ViewerZoom.actualSize) }

    /// Whether the image has a size and any zoom to give: one shown at its
    /// actual size (or larger) has none to zoom in to.
    public var canZoom: Bool {
      imageWidth > 0 && imageHeight > 0 && maxZoom - minZoom > Self.room
    }

    /// The least zoom a fit may fall short of the actual size by and still
    /// have zoom to give (layout rounds a shown size by a hair).
    static let room = 0.005

    /// The zoom that shows the whole image in a viewport of this size.
    public static func fit(
      imageWidth: Double, imageHeight: Double, viewportWidth: Double, viewportHeight: Double
    ) -> Double {
      min(viewportWidth / imageWidth, viewportHeight / imageHeight)
    }

    /// What the surface shows now, nil until the image has a size.
    var region: Region? {
      guard imageWidth > 0, imageHeight > 0, minZoom > 0 else { return nil }
      let width = imageWidth * zoom
      let height = imageHeight * zoom
      return Region(
        centerX: (viewportWidth / 2 - panX) / width, centerY: (viewportHeight / 2 - panY) / height,
        scale: zoom / minZoom, maxScale: maxZoom / minZoom)
    }

    /// The image at `region`: its zoom over its fit, clamped, the point at
    /// its middle.
    mutating func show(region: Region) {
      guard imageWidth > 0, imageHeight > 0 else { return }
      zoom = max(minZoom, min(maxZoom, minZoom * region.scale))
      atFit = zoom <= minZoom
      panX = viewportWidth / 2 - region.centerX * imageWidth * zoom
      panY = viewportHeight / 2 - region.centerY * imageHeight * zoom
      clampPan()
    }

    /// Laid out afresh in a viewport of this size, whose fit is `fit`: at
    /// `start` (clamped) where given, else at the fit; centered.
    public mutating func lay(
      viewportWidth width: Double, viewportHeight height: Double, fit: Double, zoom start: Double? = nil
    ) {
      viewportWidth = width
      viewportHeight = height
      minZoom = fit
      zoom = start.map { max(minZoom, min(maxZoom, $0)) } ?? minZoom
      atFit = zoom <= minZoom
      panX = (viewportWidth - imageWidth * zoom) / 2
      panY = (viewportHeight - imageHeight * zoom) / 2
    }

    /// The viewport changed size to `width` by `height`, whose fit is now
    /// `fit`: the image keeps what it shows—the same point at the
    /// viewport's middle and the same zoom over its fit, found again—so it
    /// scales with its surface, at its fit or zoomed in alike; at its fit,
    /// it follows the fit.
    public mutating func resize(viewportWidth width: Double, viewportHeight height: Double, fit: Double) {
      let kept = region
      viewportWidth = width
      viewportHeight = height
      guard imageWidth > 0, imageHeight > 0 else { return }
      minZoom = fit
      if let kept, !atFit {
        zoom = max(minZoom, min(maxZoom, minZoom * kept.scale))
        atFit = zoom <= minZoom
        panX = viewportWidth / 2 - kept.centerX * imageWidth * zoom
        panY = viewportHeight / 2 - kept.centerY * imageHeight * zoom
      } else {
        zoom = minZoom
        panX = (viewportWidth - imageWidth * zoom) / 2
        panY = (viewportHeight - imageHeight * zoom) / 2
      }
      clampPan()
    }

    /// `value`, clamped to the fit and the actual size, about a point of
    /// the viewport (which stays where it is under the pointer).
    public mutating func zoom(to value: Double, aboutX cx: Double, y cy: Double) {
      let newZoom = max(minZoom, min(maxZoom, value))
      panX = cx - (cx - panX) * (newZoom / zoom)
      panY = cy - (cy - panY) * (newZoom / zoom)
      zoom = newZoom
      atFit = zoom <= minZoom
      clampPan()
    }

    // MARK: - Framing a region

    /// Where the image stands on its surface: its zoom and its top left.
    public struct Framing: Sendable, Equatable {
      public var zoom: Double
      public var panX: Double
      public var panY: Double
      public init(zoom: Double, panX: Double, panY: Double) {
        self.zoom = zoom
        self.panX = panX
        self.panY = panY
      }

      /// `self` a fraction `t` (0–1) of the way to `other`.
      public func moved(toward other: Framing, by t: Double) -> Framing {
        Framing(
          zoom: zoom + (other.zoom - zoom) * t, panX: panX + (other.panX - panX) * t,
          panY: panY + (other.panY - panY) * t)
      }
    }

    /// Where the image stands now.
    public var framing: Framing { Framing(zoom: zoom, panX: panX, panY: panY) }

    /// The image put at `framing`: its zoom within the fit and the actual
    /// size, kept inside the surface.
    public mutating func apply(_ framing: Framing) {
      zoom = max(minZoom, min(maxZoom, framing.zoom))
      atFit = zoom <= minZoom
      panX = framing.panX
      panY = framing.panY
      clampPan()
    }

    /// Where the image would stand showing `region` (what `show(region:)`
    /// does), without moving it.
    public func framing(showing region: Region) -> Framing {
      var copy = self
      copy.show(region: region)
      return copy.framing
    }

    /// The margin left around a region framed, as a fraction of the
    /// surface on each side.
    public static let framingMargin = 0.1

    /// Where the image should stand to show a region of it (`x`, `y`,
    /// `width`, `height` in the 0–1000 space over the whole image), or nil
    /// to leave it where it is:
    ///
    /// - a region wholly in view is left be, whatever the zoom (a reader's
    ///   own zoom is respected);
    /// - a region larger than the surface at the zoom it has is not zoomed
    ///   into: only if its top left is out of view is the image panned to
    ///   show it, with the margin;
    /// - any other is framed: zoomed in, never out, so its longer edge fits
    ///   the surface within the margin (to the actual size at most), and
    ///   centered.
    public func framing(ofX x: Double, y: Double, width: Double, height: Double) -> Framing? {
      guard imageWidth > 0, imageHeight > 0, viewportWidth > 0, viewportHeight > 0, zoom > 0, width > 0, height > 0
      else { return nil }
      let scaleX = imageWidth / 1000 * zoom
      let scaleY = imageHeight / 1000 * zoom
      let left = panX + x * scaleX
      let top = panY + y * scaleY
      let right = left + width * scaleX
      let bottom = top + height * scaleY
      // Layout rounds a shown size by a hair.
      let slack = 0.5
      if left >= -slack && top >= -slack && right <= viewportWidth + slack && bottom <= viewportHeight + slack {
        return nil
      }
      let marginX = viewportWidth * ViewerZoom.framingMargin
      let marginY = viewportHeight * ViewerZoom.framingMargin
      var target = self
      if right - left > viewportWidth || bottom - top > viewportHeight {
        guard left < -slack || top < -slack || left >= viewportWidth || top >= viewportHeight else { return nil }
        target.panX += marginX - left
        target.panY += marginY - top
      } else {
        let fitX = (viewportWidth - 2 * marginX) / (width / 1000 * imageWidth)
        let fitY = (viewportHeight - 2 * marginY) / (height / 1000 * imageHeight)
        target.zoom = max(zoom, min(maxZoom, min(fitX, fitY)))
        target.atFit = target.zoom <= minZoom
        let centerX = (x + width / 2) / 1000 * imageWidth
        let centerY = (y + height / 2) / 1000 * imageHeight
        target.panX = viewportWidth / 2 - centerX * target.zoom
        target.panY = viewportHeight / 2 - centerY * target.zoom
      }
      target.clampPan()
      let framed = target.framing
      return framed == framing ? nil : framed
    }

    /// The image moved by `dx`, `dy`, kept inside the surface.
    public mutating func pan(by dx: Double, _ dy: Double) {
      panX += dx
      panY += dy
      clampPan()
    }

    /// Never past an edge: smaller than the viewport, an image is centered
    /// and does not pan; larger, it leaves no empty gap at any edge.
    public mutating func clampPan() {
      let iw = imageWidth * zoom
      let ih = imageHeight * zoom
      if iw <= viewportWidth {
        panX = (viewportWidth - iw) / 2
      } else {
        panX = min(0, max(viewportWidth - iw, panX))
      }
      if ih <= viewportHeight {
        panY = (viewportHeight - ih) / 2
      } else {
        panY = min(0, max(viewportHeight - ih, panY))
      }
    }
  }
}

#if CLIENT
  import DOMBuilder
  import WebAPIs
  import WebTypes

  extension ViewerZoom {
    /// The inputs that zoom a surface wherever it is, bound to its element:
    /// the wheel, zooming in proportion to its travel about the pointer (a
    /// trackpad's pinch in most browsers is the wheel with ctrl held, so it
    /// is the same), and Safari's pinch, which WebKit sends as gesture
    /// events, not as a wheel. The viewer owns the rest: its drag, its keys,
    /// its touches.
    ///
    /// Both are taken with `preventDefault`, so the page neither scrolls nor
    /// zooms while the pointer is over the surface (`takes`): the wheel is
    /// the surface's.
    public final class Input: @unchecked Sendable {
      private let element: DOM.Element
      private let takes: @Sendable () -> Bool
      private let current: @Sendable () -> Double
      private let zoomTo: @Sendable (Double, Double, Double) -> Void
      /// The zoom a Safari pinch began at (WebKit's `gesturestart`).
      private var gestureStartZoom = 1.0
      private var wheelListener: Int32 = -1
      private var gestureListeners: [Int32] = []

      /// - Parameters:
      ///   - takes: whether the surface takes the input now (false: the
      ///     browser's own happens).
      ///   - current: the surface's zoom now.
      ///   - zoomTo: the zoom wanted, and the point of the element it is
      ///     about (the element's own coordinates).
      public init(
        on element: DOM.Element,
        takes: @escaping @Sendable () -> Bool,
        current: @escaping @Sendable () -> Double,
        zoomTo: @escaping @Sendable (_ zoom: Double, _ x: Double, _ y: Double) -> Void
      ) {
        self.element = element
        self.takes = takes
        self.current = current
        self.zoomTo = zoomTo
        bind()
      }

      private func bind() {
        // Not passive: a wheel the surface takes must keep the page still.
        wheelListener = element.addEventListener(
          .wheel,
          { [self] e in
            guard takes() else { return }
            e.preventDefault()
            let box = element.getBoundingClientRect()
            zoomTo(
              current() * ViewerZoom.wheelFactor(e.deltaY), e.clientX - (box?.x ?? 0), e.clientY - (box?.y ?? 0))
          }, capture: false, passive: false)

        // Safari's trackpad pinch: WebKit's gesture events, not the ctrl+wheel
        // other browsers send (which the wheel above zooms by). Zoomed about
        // the gesture's point from the zoom it began at, by its scale; the
        // page itself never zoomed. Other browsers never send them.
        let start = element.addEventListener(
          "gesturestart",
          { [self] e in
            guard takes() else { return }
            e.preventDefault()
            gestureStartZoom = current()
          }, capture: false, passive: false)
        let change = element.addEventListener(
          "gesturechange",
          { [self] e in
            guard takes() else { return }
            e.preventDefault()
            let box = element.getBoundingClientRect()
            // A gesture with no pointer (a touch screen's) pinches about the
            // surface's middle.
            let x = e.clientX == e.clientX ? e.clientX - (box?.x ?? 0) : (box?.width ?? 0) / 2
            let y = e.clientY == e.clientY ? e.clientY - (box?.y ?? 0) : (box?.height ?? 0) / 2
            zoomTo(gestureStartZoom * e.webKitGestureScale, x, y)
          }, capture: false, passive: false)
        let end = element.addEventListener(
          "gestureend",
          { [self] e in
            guard takes() else { return }
            e.preventDefault()
          }, capture: false, passive: false)
        gestureListeners = [start, change, end]
      }

      /// Lets go of the listeners (and their callbacks): the surface left
      /// the page.
      public func unbind() {
        if wheelListener >= 0 { element.removeEventListener(.wheel, wheelListener) }
        wheelListener = -1
        if gestureListeners.count == 3 {
          element.removeEventListener("gesturestart", gestureListeners[0])
          element.removeEventListener("gesturechange", gestureListeners[1])
          element.removeEventListener("gestureend", gestureListeners[2])
        }
        gestureListeners = []
      }
    }
  }
#endif
