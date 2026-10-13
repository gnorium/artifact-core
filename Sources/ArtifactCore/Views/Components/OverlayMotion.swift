/// The overlay's one motion (user, 2026-10-14): the panes' move (their CSS
/// transition) and the text's zoom, the scan's warp and its margins' fade
/// (the client's frames) on one clock and one curve, so that they arrive
/// together.
enum OverlayMotion {
  /// Its length.
  static let milliseconds = 400.0

  /// Its curve, CSS's `ease-in-out`: a cubic Bézier from (0, 0) to (1, 1)
  /// by these two control points.
  static let x1 = 0.42
  static let y1 = 0.0
  static let x2 = 0.58
  static let y2 = 1.0

  #if SERVER
    /// As a CSS transition takes it, after the property it moves.
    static var timing: String {
      "\(Int(milliseconds))ms cubic-bezier(\(x1), \(y1), \(x2), \(y2))"
    }
  #endif

  /// The curve at `fraction` of its time, as the browser draws it: the
  /// Bézier's parameter whose x is the fraction (Newton's method, halving
  /// where it stalls), then its y.
  static func eased(_ fraction: Double) -> Double {
    let x = min(1, max(0, fraction))
    var t = x
    for _ in 0..<newtonSteps {
      let error = bezier(t, x1, x2) - x
      if abs(error) < tolerance { return bezier(t, y1, y2) }
      let slope = slope(t, x1, x2)
      if abs(slope) < tolerance { break }
      t -= error / slope
    }
    var low = 0.0
    var high = 1.0
    t = x
    while high - low > tolerance {
      if bezier(t, x1, x2) < x { low = t } else { high = t }
      t = (low + high) / 2
    }
    return bezier(t, y1, y2)
  }

  /// One coordinate of the curve at its parameter `t`.
  private static func bezier(_ t: Double, _ first: Double, _ second: Double) -> Double {
    let rest = 1 - t
    return 3 * rest * rest * t * first + 3 * rest * t * t * second + t * t * t
  }

  /// Its slope by the parameter.
  private static func slope(_ t: Double, _ first: Double, _ second: Double) -> Double {
    let rest = 1 - t
    return 3 * rest * rest * first + 6 * rest * t * (second - first) + 3 * t * t * (1 - second)
  }

  private static let newtonSteps = 8
  /// Closer than this the curve's x is the fraction.
  private static let tolerance = 1e-7
}

/// Where the overlay holds the edition's page (user, 2026-10-14): its
/// text frame, onto which the scan's text block is laid, with the page's
/// own equal margins around it, as the render draws it. Never smaller than
/// the view in both axes (its fit), centered in an axis it is narrower in,
/// else the view kept within it: the scan's margins are trimmed, and the
/// edition's show the page's ground alone.
struct OverlayFraming {
  /// The page's size in its layer's own pixels, unzoomed.
  let page: (width: Double, height: Double)
  /// The view: its width and height.
  let width: Double
  let height: Double
  /// The most the layer zooms in, unless the fit is more.
  let most: Double

  /// The zoom at which the whole page fits the view.
  var fit: Double {
    guard page.width > 0, page.height > 0 else { return 1 }
    return max(0, min(width / page.width, height / page.height))
  }

  /// A view of the layer (its zoom, and its origin in the view) bounded to
  /// the page: the zoom between the fit and the most, and the page
  /// centered or covering the view in each axis.
  func clamp(zoom: Double, x: Double, y: Double) -> (zoom: Double, x: Double, y: Double) {
    let zoom = max(fit, min(max(fit, most), zoom))
    return (zoom, Self.bound(x, length: page.width * zoom, view: width), Self.bound(y, length: page.height * zoom, view: height))
  }

  /// The page fitted and centered.
  var fitted: (zoom: Double, x: Double, y: Double) { clamp(zoom: fit, x: 0, y: 0) }

  /// The layer's origin in one axis: the page (`length` long, zoomed)
  /// centered where it is no longer than the view, else covering it.
  private static func bound(_ origin: Double, length: Double, view: Double) -> Double {
    if length <= view { return (view - length) / 2 }
    return min(0, max(view - length, origin))
  }
}
