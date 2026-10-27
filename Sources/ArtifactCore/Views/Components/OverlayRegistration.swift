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

/// The edge registration lays the scan's text block on across
/// (`OverlayRegistration.laid`).
enum OverlayAnchor: Equatable {
  case left, center, right
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
  /// Across, by the edge the block is set from (`anchor`, user
  /// 2026-10-27): a left-set block's left edge on the rendered block's
  /// left, a right-set block's right on its right, a centered or justified
  /// one centered. A left-set page's lines start where the print's do,
  /// whatever the edition face's widths: before the fit tunes them, a
  /// face wider than the print's runs its lines past the measure, and the
  /// block centered on that wider edition stood every line's start half
  /// the overrun right (Hamlet Q1, a whole page off by its starts).
  static func laid(
    _ box: [Double], zone: [Double], size: (width: Double, height: Double), spans: Bool, typeScale: Double,
    anchor: OverlayAnchor = .center
  ) -> [Double] {
    guard box.count == 4, zone.count == 8 else { return box }
    if typeScale <= 0 && spans { return box }
    let corners = (0..<8).map { zone[$0] / zoneExtent * ($0 % 2 == 0 ? size.width : size.height) }
    let across = ((corners[2] - corners[0]) * (corners[2] - corners[0]) + (corners[3] - corners[1]) * (corners[3] - corners[1])).squareRoot()
    let down = ((corners[6] - corners[0]) * (corners[6] - corners[0]) + (corners[7] - corners[1]) * (corners[7] - corners[1])).squareRoot()
    guard down > 0 else { return box }
    let typed = typeScale > 0
    let scale = typed ? typeScale : (box[3] - box[1]) / down
    let width = across * scale
    let left: Double
    switch anchor {
    case .left: left = box[0]
    case .right: left = box[2] - width
    case .center: left = (box[0] + box[2]) / 2 - width / 2
    }
    return [left, box[1], left + width, typed ? box[1] + down * scale : box[3]]
  }

  /// The edge a block's lines are mostly set from: left or right where more
  /// than half of them are set so (`StructureAlignment`), else its center (a
  /// centered block, a justified one, a mix).
  static func anchor(_ alignments: [StructureAlignment]) -> OverlayAnchor {
    let left = alignments.filter { $0 == .left }.count
    let right = alignments.filter { $0 == .right }.count
    if left * 2 > alignments.count { return .left }
    if right * 2 > alignments.count { return .right }
    return .center
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

  /// The scan layout's word zones, each with the line it is on (the line
  /// zone before it in reading order, by its place among the lines; -1
  /// before any) and its box (left, top, right, bottom, 0–1000): what a
  /// word's `@facs` names (`wordBoxes`).
  static func wordZones(_ zones: [ScanZone]) -> [(id: String, line: Int, box: [Double])] {
    var out: [(id: String, line: Int, box: [Double])] = []
    var line = -1
    for zone in zones {
      if zone.kind == 1 { line += 1 }
      guard zone.kind == 2, !stringIsEmpty(zone.id), zone.points.count == 8 else { continue }
      let p = zone.points
      out.append(
        (zone.id, line,
         [min(p[0], p[2], p[4], p[6]), min(p[1], p[3], p[5], p[7]), max(p[0], p[2], p[4], p[6]), max(p[1], p[3], p[5], p[7])]))
    }
    return out
  }

  /// A word's boxes on the scan, as its `<w>`'s `@facs` names its zones
  /// (`ids`; the model's grouping is the authority, never a merging of
  /// ours): one box a scan line its zones are on, their union (bounding
  /// box), in reading order. A word the print letter-spaces ("O F", a
  /// zone a letter) is one box, never its letters apart (user,
  /// 2026-10-18); a word broken over lines one a line. A zone the layout
  /// does not hold is left out.
  static func wordBoxes(_ ids: [String], in zones: [(id: String, line: Int, box: [Double])]) -> [[Double]] {
    var lines: [Int] = []
    var boxes: [[Double]] = []
    for id in ids {
      guard let zone = zones.first(where: { stringEquals($0.id, id) }) else { continue }
      if let index = lines.firstIndex(of: zone.line) {
        let box = boxes[index]
        boxes[index] = [
          min(box[0], zone.box[0]), min(box[1], zone.box[1]), max(box[2], zone.box[2]), max(box[3], zone.box[3]),
        ]
      } else {
        lines.append(zone.line)
        boxes.append(zone.box)
      }
    }
    return boxes
  }

  /// The work's em on the page's scan (`data-scan-em`,
  /// `TEIView.scanEmData`) in the scan's pixels, its image `width` pixels
  /// wide; 0 where it is not given.
  static func scanEm(_ text: String, width: Double) -> Double {
    guard !stringIsEmpty(text), let fraction = parseDouble(text), fraction > 0, width > 0 else { return 0 }
    return fraction / zoneExtent * width
  }
}
