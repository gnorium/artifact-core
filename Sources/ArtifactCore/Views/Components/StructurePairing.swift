/// The edition's line structure against the scan's (user, 2026-10-14): the
/// structure overlay draws both in one scene, so their divergence is seen,
/// and the word correspondence pairs their lines. The rule is the model's
/// review image's, step for step (gnorium-python `layout_measure`'s
/// structure image): a change here is made there too.
///
/// A row is a line's ink box, left, top, right and bottom, in one frame (the
/// rendered page's, the scan's laid in it by the overlay's registration),
/// and its baseline: where its letters sit, what its place down the page
/// is judged by (user, 2026-10-17: typeface is not parity—the edition is
/// set in Noto on purpose, so how far the print's face and Noto reach above
/// the x-height or below the baseline is no difference).
struct StructureRow: Equatable {
  var left: Double
  var top: Double
  var right: Double
  var bottom: Double
  /// The edges an edition's line is set by (its block's alignment), and
  /// its type's em (its font-size, in the frame's pixels): what its edges
  /// across are judged by. A scan's line has none.
  var alignment: StructureAlignment = .none
  var em: Double = 0
  /// The block it is a line of (an id; -1 none): a justified block's last
  /// line is set from its start alone.
  var block: Int32 = -1
  /// Its baseline: an edition's line's face's alphabetic baseline (its font
  /// box's top plus the font's ascent), a scan's line's stored
  /// `<path type="baseline">`, laid as its zone is; nil where there is none
  /// (a scan line with no x-height measured), then its ink's bottom
  /// (`seated`). `baselineEm`: the em of the line it is the baseline of.
  var baseline: Double? = nil
  var baselineEm: Double = 0

  /// Where its letters sit: its baseline, else its ink's bottom
  /// (gnorium-python `layout_measure.baseline`).
  var seated: Double { baseline ?? bottom }

  /// The box around both, the first's setting kept; the baseline the
  /// larger type's (a superscript's or a small note's is not the row's),
  /// the lower of equal ones (gnorium-python `layout_preview._LINES`).
  func joined(_ other: StructureRow) -> StructureRow {
    var joined = self
    joined.left = min(left, other.left)
    joined.top = min(top, other.top)
    joined.right = max(right, other.right)
    joined.bottom = max(bottom, other.bottom)
    if let theirs = other.baseline {
      if let ours = baseline {
        if other.baselineEm > baselineEm || (other.baselineEm == baselineEm && theirs > ours) {
          joined.baseline = theirs
          joined.baselineEm = other.baselineEm
        }
      } else {
        joined.baseline = theirs
        joined.baselineEm = other.baselineEm
      }
    }
    return joined
  }
}

/// The edges a line is set by: those the print aligns.
enum StructureAlignment: Equatable {
  /// None judged: a scan's line, or a line whose setting is not known.
  case none
  case left
  case right
  case center
  /// Both edges: a justified block's line, but its last (`left`).
  case justified
}

enum StructurePairing {
  /// How a row of one structure stands to the other's.
  enum Match: Equatable {
    /// An edition row and a scan row paired, `within` the tolerance or not.
    case pair(edition: Int, scan: Int, within: Bool)
    /// An edition row the scan has no row for: extra in the edition.
    case extra(edition: Int)
    /// A scan row the edition has no row for: missing from the edition.
    case missing(scan: Int)
  }

  /// Lines side by side (columns the other structure does not split) taken
  /// as one row: boxes `beside` each other joined, top to bottom
  /// (gnorium-python `layout_measure._rows`).
  static func rows(_ boxes: [StructureRow]) -> [StructureRow] {
    var rows: [StructureRow] = []
    for box in boxes.sorted(by: { $0.top < $1.top }) {
      if let last = rows.last, beside(last, box) {
        rows[rows.count - 1] = last.joined(box)
      } else {
        rows.append(box)
      }
    }
    return rows
  }

  /// Whether a line stands beside a row: they overlap down the page by more
  /// than half the shorter's height. Lines one above the other overlap
  /// only by their ascenders and descenders where the leading is tight (a
  /// scan line's box, all of its ink, is as tall as the line pitch), and
  /// more so where a tilted line's box is upright (user, 2026-10-26: Hamlet
  /// Q1's p. 4 chained 37 lines into 2 rows).
  static func beside(_ row: StructureRow, _ line: StructureRow) -> Bool {
    min(row.bottom, line.bottom) - max(row.top, line.top) > min(row.bottom - row.top, line.bottom - line.top) / 2
  }

  /// Whether a pair is within the tolerance: its baselines (`seated`)
  /// within a quarter of the body's leading (`leading`), half a half-line,
  /// where the gap grid's rounding (gnorium-python `type_scale`: a gap is a
  /// whole number of half-lines) puts a gap on another step; and across,
  /// each edge the edition's line is set by (`aligned`) within an em of
  /// its type.
  static func within(_ edition: StructureRow, _ scan: StructureRow, leading: Double) -> Bool {
    abs(edition.seated - scan.seated) <= leading / 4 && aligned(edition, scan)
  }

  /// Whether an edition's line stands across where its scan line does, by
  /// the edges the print aligns (user, 2026-10-14): a left-set line's left
  /// edge, a right-set line's right, a centered line's center, a justified
  /// line's both (its block's last line its left alone); a ragged edge is
  /// never judged. Only gross misalignment counts: an edge more than one em
  /// of the line's own type from the scan's, the em being the unit the
  /// edition face's widths differ from the print's in (Noto set at the
  /// print's measured size is a little wider or narrower than its face,
  /// never an em a line off). No other constant.
  static func aligned(_ edition: StructureRow, _ scan: StructureRow) -> Bool {
    let em = edition.em
    guard em > 0 else { return true }
    let left = abs(edition.left - scan.left) <= em
    let right = abs(edition.right - scan.right) <= em
    switch edition.alignment {
    case .none: return true
    case .left: return left
    case .right: return right
    case .center: return abs((edition.left + edition.right) / 2 - (scan.left + scan.right) / 2) <= em
    case .justified: return left && right
    }
  }

  /// A justified block's last line set from its start alone (a paragraph's
  /// ragged end): each row whose block no later row is of.
  static func lastLinesLeft(_ rows: [StructureRow]) -> [StructureRow] {
    rows.enumerated().map { index, row in
      guard row.alignment == .justified, row.block >= 0,
        !rows[(index + 1)...].contains(where: { $0.block == row.block })
      else { return row }
      var last = row
      last.alignment = .left
      return last
    }
  }

  /// The two structures' rows paired in order by dynamic programming
  /// (Needleman–Wunsch): a pair costs twice its baselines' distance
  /// (`seated`), a row left unpaired the body's leading (`leading`)—a row
  /// off by a whole line is no pair of it. The matches top to bottom.
  static func pair(edition: [StructureRow], scan: [StructureRow], leading: Double) -> [Match] {
    let n = edition.count
    let m = scan.count
    var cost = [[Double]](repeating: [Double](repeating: 0, count: m + 1), count: n + 1)
    // 0: a pair, 1: an edition row alone, 2: a scan row alone.
    var step = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
    for i in 0...n {
      for j in 0...m {
        if i == 0 && j == 0 { continue }
        var best = Double.infinity
        var move = 0
        if i > 0 && j > 0 {
          let a = edition[i - 1]
          let b = scan[j - 1]
          best = cost[i - 1][j - 1] + 2 * abs(a.seated - b.seated)
        }
        if i > 0, cost[i - 1][j] + leading < best {
          best = cost[i - 1][j] + leading
          move = 1
        }
        if j > 0, cost[i][j - 1] + leading < best {
          best = cost[i][j - 1] + leading
          move = 2
        }
        cost[i][j] = best
        step[i][j] = move
      }
    }
    var matches: [Match] = []
    var i = n
    var j = m
    while i > 0 || j > 0 {
      switch step[i][j] {
      case 0:
        matches.append(.pair(edition: i - 1, scan: j - 1, within: within(edition[i - 1], scan[j - 1], leading: leading)))
        i -= 1
        j -= 1
      case 1:
        matches.append(.extra(edition: i - 1))
        i -= 1
      default:
        matches.append(.missing(scan: j - 1))
        j -= 1
      }
    }
    return matches.reversed()
  }
}
