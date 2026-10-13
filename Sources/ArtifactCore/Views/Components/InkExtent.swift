/// Where a rendered line's ink is, from what its layout and its font tell of
/// it (the overlay's target, user, 2026-10-14): the scan's zone is measured
/// on its ink, so the rendered page's content is too, never its text's font
/// boxes, which stand above and below the glyphs by the font's ascent and
/// descent and run on past the last glyph by its letter-spacing.
///
/// A text node's range draws, on each line it is set on, its font box as the
/// page is zoomed; `measureText` in the node's font gives, in the font's own
/// CSS pixels, that box's ascent and descent and the ink's, and each glyph's
/// ink from its start. gnorium-python's `layout_preview` (`_TEXT_BLOCK`)
/// measures the same box, rule for rule (user, 2026-10-14).
struct InkExtent {
  var left = Double.infinity
  var top = Double.infinity
  var right = -Double.infinity
  var bottom = -Double.infinity

  /// The box around all taken, as left, top, right, bottom; nil where
  /// nothing was.
  var box: [Double]? {
    right > left && bottom > top ? [left, top, right, bottom] : nil
  }

  /// Takes a box drawn as it is: a rule's, a figure's, a printed frame's.
  mutating func take(left: Double, top: Double, right: Double, bottom: Double) {
    guard right > left, bottom > top else { return }
    self.left = min(self.left, left)
    self.top = min(self.top, top)
    self.right = max(self.right, right)
    self.bottom = max(self.bottom, bottom)
  }

  /// How many of the page's pixels a pixel of the font is: the line's
  /// drawn height against its font box's (ascent and descent). Nil where
  /// either has none.
  static func scale(drawnHeight: Double, fontAscent: Double, fontDescent: Double) -> Double? {
    let font = fontAscent + fontDescent
    guard font > 0, drawnHeight > 0 else { return nil }
    return drawnHeight / font
  }

  /// A line's ink top and bottom: its drawn font box less the font's ascent
  /// and descent, plus its glyphs' ink's, as scaled.
  static func vertical(
    drawnTop: Double, drawnBottom: Double, fontAscent: Double, fontDescent: Double, inkAscent: Double,
    inkDescent: Double, scale: Double
  ) -> (top: Double, bottom: Double) {
    (drawnTop + (fontAscent - inkAscent) * scale, drawnBottom - (fontDescent - inkDescent) * scale)
  }

  /// A glyph's ink across: from where its range starts, its ink's left
  /// edge (`actualBoundingBoxLeft`, to the left of the start) and right
  /// edge (`actualBoundingBoxRight`), as scaled. Its advance and the
  /// letter-spacing after it are no part of it.
  static func horizontal(drawnLeft: Double, inkLeft: Double, inkRight: Double, scale: Double) -> (
    left: Double, right: Double
  ) {
    (drawnLeft - inkLeft * scale, drawnLeft + inkRight * scale)
  }
}
