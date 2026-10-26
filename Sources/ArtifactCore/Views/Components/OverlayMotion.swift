/// The overlay's one motion (user, 2026-10-14): the panes' move (their CSS
/// transition) and the text's zoom, the scan's warp and its margins' fade
/// (the client's frames) on one clock and one curve, so that they arrive
/// together.
enum OverlayMotion {
  /// Its length.
  static let milliseconds = 400.0

  /// A pane taking the edition's place on the scan (the XML, the header,
  /// Reflow; user, 2026-10-26): the edition fades out where it lies, then
  /// the overlay is off at once, the image and that pane fading in at
  /// rest. Each fade this long.
  static let handoffMilliseconds = 300.0

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

    /// A handoff's fade (`handoffMilliseconds`), as CSS takes it.
    static var handoffTiming: String {
      "\(Int(handoffMilliseconds))ms ease-out"
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
/// page, its text frame onto which the scan's main text block is laid, and
/// as far as the registered scan reaches beyond it (`content`, in the
/// layer's own pixels: left, top, right, bottom), so the full image shows.
/// It opens at its fit, centered; the reader zooms and pans it from there,
/// the text and the scan as one, never below the fit and never so far that
/// the content leaves the view where it could fill it (`held`).
struct OverlayFraming {
  /// What the view frames, in the layer's own pixels, unzoomed.
  let content: (left: Double, top: Double, right: Double, bottom: Double)
  /// The view: its width and height.
  let width: Double
  let height: Double
  /// The most it zooms in: the larger of the text's actual size and the
  /// scan's (its pixels one to one).
  let actual: Double

  /// The zoom at which the whole content fits the view.
  var fit: Double {
    let across = content.right - content.left
    let down = content.bottom - content.top
    guard across > 0, down > 0 else { return 1 }
    return max(0, min(width / across, height / down))
  }

  /// The content fitted and centered: its zoom, and the layer's origin in
  /// the view.
  var fitted: (zoom: Double, x: Double, y: Double) {
    held((fit, 0, 0))
  }

  /// A view held to the framing: its zoom between the fit and the actual
  /// size; the content centered on an axis where it is smaller than the
  /// view, else filling it, no edge pulled in past the view's.
  func held(_ view: (zoom: Double, x: Double, y: Double)) -> (zoom: Double, x: Double, y: Double) {
    let zoom = max(fit, min(max(fit, actual), view.zoom))
    func axis(_ value: Double, _ low: Double, _ high: Double, _ size: Double) -> Double {
      let extent = (high - low) * zoom
      if extent <= size { return (size - extent) / 2 - low * zoom }
      return min(-low * zoom, max(size - high * zoom, value))
    }
    return (zoom, axis(view.x, content.left, content.right, width), axis(view.y, content.top, content.bottom, height))
  }
}
