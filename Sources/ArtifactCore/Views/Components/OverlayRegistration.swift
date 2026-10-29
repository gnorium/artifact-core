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
  /// it) by its width, from its left, its proportions kept too.
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
    let corners = (0..<8).map { zone[$0] / zoneExtent * ($0 % 2 == 0 ? size.width : size.height) }
    let across = ((corners[2] - corners[0]) * (corners[2] - corners[0]) + (corners[3] - corners[1]) * (corners[3] - corners[1])).squareRoot()
    let down = ((corners[6] - corners[0]) * (corners[6] - corners[0]) + (corners[7] - corners[1]) * (corners[7] - corners[1])).squareRoot()
    guard down > 0 else { return box }
    let typed = typeScale > 0
    // With no frame declared, by the block's height; a block spanning the
    // measure by its width, from its left: one scale both ways, the image
    // never stretched (user, 2026-10-28: the image stays as its pane shows
    // it, the edition laid on it).
    let spanning = !typed && spans && across > 0
    let scale = typed ? typeScale : spanning ? (box[2] - box[0]) / across : (box[3] - box[1]) / down
    let width = across * scale
    let left: Double
    switch spanning ? OverlayAnchor.left : anchor {
    case .left: left = box[0]
    case .right: left = box[2] - width
    case .center: left = (box[0] + box[2]) / 2 - width / 2
    }
    return [left, box[1], left + width, typed || spanning ? box[1] + down * scale : box[3]]
  }

  /// How far down the page the scan is laid after the text block's
  /// registration (user, 2026-10-28): the median distance from the scan's
  /// paired baselines (`StructureRow.seated`) to the edition's, positive
  /// where the edition's stand lower; 0 under three pairs (too few to say
  /// where the page's lines are). gnorium-python
  /// `layout_measure.baseline_shift`.
  static func baselineShift(_ matches: [StructurePairing.Match], edition: [StructureRow], scan: [StructureRow]) -> Double {
    var distances: [Double] = []
    for match in matches {
      if case .pair(let e, let s, _) = match { distances.append(edition[e].seated - scan[s].seated) }
    }
    guard distances.count >= 3 else { return 0 }
    distances.sort()
    let middle = distances.count / 2
    return distances.count % 2 == 1 ? distances[middle] : (distances[middle - 1] + distances[middle]) / 2
  }

  /// What a pairing costs as `StructurePairing.pair` weighs it: twice each
  /// pair's baselines' distance, a leading for each row left alone.
  /// gnorium-python `layout_measure.pairing_cost`.
  static func pairingCost(_ matches: [StructurePairing.Match], edition: [StructureRow], scan: [StructureRow], leading: Double)
    -> Double
  {
    var cost = 0.0
    for match in matches {
      if case .pair(let e, let s, _) = match {
        cost += 2 * abs(edition[e].seated - scan[s].seated)
      } else {
        cost += leading
      }
    }
    return cost
  }

  /// How many of a pairing's pairs stand where their print rows do, by
  /// what neither side's place across sets: their baselines (`seated`)
  /// within a quarter of the `leading` and the edition's row set at its
  /// print row's size (`StructurePairing.sized`, by the pairing's own
  /// `StructurePairing.widthRatio`). gnorium-python
  /// `layout_measure.agreeing`.
  static func agreeing(_ matches: [StructurePairing.Match], edition: [StructureRow], scan: [StructureRow], leading: Double)
    -> Int
  {
    let ratio = StructurePairing.widthRatio(matches, edition: edition, scan: scan)
    var count = 0
    for match in matches {
      guard case .pair(let e, let s, _) = match else { continue }
      if abs(edition[e].seated - scan[s].seated) <= leading / 4
        && StructurePairing.sized(edition[e], scan[s], ratio: ratio)
      {
        count += 1
      }
    }
    return count
  }

  /// How far down the scan's rows are laid on the edition's and the main
  /// text's matches there (user, 2026-10-28). The median of one pairing on
  /// the text block's registration (`baselineShift`) is not enough: where
  /// the edition stands half a leading off the scan, part of its rows pair
  /// with their neighbors, and that median locks every row one off (Hamlet
  /// Q1 p. 4: 31 rows each paired with the next). So each place one leading
  /// either side of that median is paired too, each settled at its own
  /// pairs' median, and the scan is laid where the most of its rows agree
  /// with their partners (`agreeing`: baselines and widths), the least cost
  /// (`pairingCost`) of those; not moved under three pairs. Baselines alone
  /// cannot tell a row off from the right one: on a page whose rows all
  /// stand a leading apart, every row paired with its neighbor sits on its
  /// baseline as well, and a page with a row the other lacks at each end
  /// costs the same either way (Hamlet Q1 p. 37 and p. 58: laid a row low,
  /// each row's start and end its neighbor's). gnorium-python
  /// `layout_measure.registration_down`.
  static func registrationDown(edition: [StructureRow], scan: [StructureRow], leading: Double)
    -> (down: Double, matches: [StructurePairing.Match])
  {
    func lowered(_ by: Double) -> [StructureRow] {
      scan.map { row in
        var moved = row
        moved.top += by
        moved.bottom += by
        moved.baseline = row.baseline.map { $0 + by }
        return moved
      }
    }
    let matches = StructurePairing.pair(edition: edition, scan: scan, leading: leading)
    var paired = 0
    for match in matches { if case .pair = match { paired += 1 } }
    guard paired >= 3 else { return (0, matches) }
    let first = baselineShift(matches, edition: edition, scan: scan)
    var best: (agree: Int, cost: Double, down: Double, matches: [StructurePairing.Match])?
    for start in [first, first - leading, first + leading] {
      let tried = lowered(start)
      let down = start + baselineShift(StructurePairing.pair(edition: edition, scan: tried, leading: leading), edition: edition, scan: tried)
      let laid = lowered(down)
      let found = StructurePairing.pair(edition: edition, scan: laid, leading: leading)
      let agree = agreeing(found, edition: edition, scan: laid, leading: leading)
      let cost = pairingCost(found, edition: edition, scan: laid, leading: leading)
      if best.map({ agree > $0.agree || (agree == $0.agree && cost < $0.cost - 1e-9) }) ?? true {
        best = (agree, cost, down, found)
      }
    }
    return best.map { ($0.down, $0.matches) } ?? (0, matches)
  }

  /// How far across the page the scan is laid after the text block's
  /// registration (user, 2026-10-28): the median distance from the scan's
  /// paired lines to the edition's by the edges each edition line is set
  /// by (`StructureAlignment`: a left-set line's start, a right-set one's
  /// end, a centered one's middle, a justified one's both, halved), positive
  /// where the edition's stand right; 0 under three such pairs.
  /// gnorium-python `layout_measure.edge_shift`.
  static func edgeShift(_ matches: [StructurePairing.Match], edition: [StructureRow], scan: [StructureRow]) -> Double {
    var distances: [Double] = []
    for match in matches {
      guard case .pair(let e, let s, _) = match else { continue }
      let a = edition[e]
      let b = scan[s]
      switch a.alignment {
      case .left: distances.append(a.left - b.left)
      case .right: distances.append(a.right - b.right)
      case .center: distances.append((a.left + a.right) / 2 - (b.left + b.right) / 2)
      case .justified: distances.append((a.left - b.left + a.right - b.right) / 2)
      case .none: break
      }
    }
    guard distances.count >= 3 else { return 0 }
    distances.sort()
    let middle = distances.count / 2
    return distances.count % 2 == 1 ? distances[middle] : (distances[middle - 1] + distances[middle]) / 2
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
