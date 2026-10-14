/// The edition's line structure against the scan's (user, 2026-10-14): the
/// structure overlay draws both in one scene, so their divergence is seen,
/// and the word correspondence pairs their lines. The rule is the model's
/// review image's, step for step (gnorium-python `layout_measure`'s
/// structure image): a change here is made there too.
///
/// A row is a line's ink box, left, top, right and bottom, in one frame (the
/// rendered page's, the scan's laid in it by the overlay's registration).
struct StructureRow: Equatable {
  var left: Double
  var top: Double
  var right: Double
  var bottom: Double

  /// The box around both.
  func joined(_ other: StructureRow) -> StructureRow {
    StructureRow(
      left: min(left, other.left), top: min(top, other.top), right: max(right, other.right),
      bottom: max(bottom, other.bottom))
  }
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
  /// as one row: boxes that overlap down the page joined, top to bottom
  /// (gnorium-python `layout_measure._rows`).
  static func rows(_ boxes: [StructureRow]) -> [StructureRow] {
    var rows: [StructureRow] = []
    for box in boxes.sorted(by: { $0.top < $1.top }) {
      if let last = rows.last, box.top < last.bottom {
        rows[rows.count - 1] = last.joined(box)
      } else {
        rows.append(box)
      }
    }
    return rows
  }

  /// Whether a pair is within the tolerance: its tops and its bottoms each
  /// within a quarter of the body's leading (`leading`), half a half-line,
  /// where the gap grid's rounding (gnorium-python `type_scale`: a gap is a
  /// whole number of half-lines) puts a gap on another step.
  static func within(_ edition: StructureRow, _ scan: StructureRow, leading: Double) -> Bool {
    abs(edition.top - scan.top) <= leading / 4 && abs(edition.bottom - scan.bottom) <= leading / 4
  }

  /// The two structures' rows paired in order by dynamic programming
  /// (Needleman–Wunsch): a pair costs its tops' and its bottoms' distance,
  /// a row left unpaired the body's leading (`leading`)—a row off by a whole
  /// line is no pair of it. The matches top to bottom.
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
          best = cost[i - 1][j - 1] + abs(a.top - b.top) + abs(a.bottom - b.bottom)
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
