import EmbeddedSwiftUtilities

/// One zone of the scan's measured layout (`TEIView`'s `data-scan-layout`,
/// the tools' zones, never the model's).
struct ScanZone {
  /// 0 a block, 1 a line, 2 a word.
  let kind: Int
  /// Whether it is of the main text: its block's subtype.
  let main: Bool
  /// A word's id, which its `<w>`'s `@facs` names; "" for the others.
  let id: String
  /// Its four corners, x and y in turn, in the 0–1000 space.
  let points: [Double]
  /// A line's baseline's two ends, the same way; empty where it has none.
  var baseline: [Double] = []
}

/// How the reader's overlay lays the scan under the edition (user,
/// 2026-10-14): the page's measured text block (its corners on the scan)
/// onto the rendered main text block, by one homography. The rule is the
/// model's review image's (gnorium-python `layout_measure.laid_on`): a
/// change here is made there too.
enum OverlayRegistration {
  /// Where registration lays the zone (`zone`: its corners, 0–1000 over
  /// an image of `size` pixels) on the rendered main text block's box
  /// (`box`: left, top, right, bottom).
  ///
  /// Where the work's frame is declared (`typeScale` > 0: the box's units
  /// per pixel of the scan, the rendered em over the work's em on the scan,
  /// `data-scan-em`), always at the type's scale: the scan at its own size
  /// from the block's top, centered across it. Only the scan's global
  /// alignment is noise; its typesetting is signal to match (user,
  /// 2026-10-17), so the block's height—the edition's typesetting—never
  /// sets the scale: a title page whose edition sets its display lines
  /// closer than the print shows them closer, its bookplate where the print
  /// has it, never the whole scan shrunk onto the edition's block; a
  /// scanner's stretch across a justified page shows as a difference.
  ///
  /// With no frame declared (0), by the block itself: its height, centered
  /// across it, the scan's own proportions kept (a line's width is the
  /// face's, so a centered block's width is no measure of the scan's); a
  /// block spanning the frame's measure (`spans`: its lines justified to
  /// it) on its box both ways.
  static func laid(
    _ box: [Double], zone: [Double], size: (width: Double, height: Double), spans: Bool, typeScale: Double
  ) -> [Double] {
    guard box.count == 4, zone.count == 8 else { return box }
    if typeScale <= 0 && spans { return box }
    let corners = (0..<8).map { zone[$0] / zoneExtent * ($0 % 2 == 0 ? size.width : size.height) }
    let across = ((corners[2] - corners[0]) * (corners[2] - corners[0]) + (corners[3] - corners[1]) * (corners[3] - corners[1])).squareRoot()
    let down = ((corners[6] - corners[0]) * (corners[6] - corners[0]) + (corners[7] - corners[1]) * (corners[7] - corners[1])).squareRoot()
    guard down > 0 else { return box }
    let typed = typeScale > 0
    let scale = typed ? typeScale : (box[3] - box[1]) / down
    let half = across * scale / 2
    let middle = (box[0] + box[2]) / 2
    return [middle - half, box[1], middle + half, typed ? box[1] + down * scale : box[3]]
  }

  /// The space a zone's corners are in, over the whole image.
  static let zoneExtent = 1000.0

  /// The page's scan layout (`data-scan-layout`, `TEIView.scanLayoutData`):
  /// its zones in reading order, a line's main-ness its block's. A zone is
  /// its type, its block's subtype, its word's id and its four corners
  /// (11 fields), and a line's baseline's two ends after them where it has
  /// one (15): a page saved before baselines were kept reads as one with
  /// none.
  static func scanLayout(_ text: String) -> [ScanZone] {
    guard !stringIsEmpty(text) else { return [] }
    var zones: [ScanZone] = []
    var main = true
    for entry in stringSplit(text, separator: ";") {
      let parts = stringSplit(entry, separator: " ")
      guard parts.count == 11 || parts.count == 15 else { continue }
      var points: [Double] = []
      for index in 3..<parts.count {
        guard let value = parseDouble(parts[index]) else { break }
        points.append(value)
      }
      guard points.count == parts.count - 3 else { continue }
      let baseline = points.count == 12 ? Array(points[8..<12]) : []
      points = Array(points[0..<8])
      let kind = stringEquals(parts[0], "block") ? 0 : stringEquals(parts[0], "line") ? 1 : 2
      if kind == 0 { main = !stringEquals(parts[1], "marginalia") }
      zones.append(
        ScanZone(
          kind: kind, main: main, id: stringEquals(parts[2], "-") ? "" : parts[2], points: points, baseline: baseline))
    }
    return zones
  }

  /// The work's em on the page's scan (`data-scan-em`,
  /// `TEIView.scanEmData`) in the scan's pixels, its image `width` pixels
  /// wide; 0 where it is not given.
  static func scanEm(_ text: String, width: Double) -> Double {
    guard !stringIsEmpty(text), let fraction = parseDouble(text), fraction > 0, width > 0 else { return 0 }
    return fraction / zoneExtent * width
  }
}
