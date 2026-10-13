/// The projective transform of the plane that takes four points to four
/// others (a homography): what lays a scan's measured text block, a
/// quadrilateral carrying the page's skew, onto the rectangle its text is
/// rendered in (the reader's overlay, user, 2026-10-13).
///
/// Its nine entries row by row, the last 1: a point (x, y) goes to
/// ((a·x + b·y + c) / w, (d·x + e·y + f) / w), w = g·x + h·y + 1.
struct Homography {
  let values: [Double]

  /// No transform.
  static let identity = Homography(values: [1, 0, 0, 0, 1, 0, 0, 0, 1])

  init(values: [Double]) {
    self.values = values
  }

  /// The one that takes `source`'s four points to `destination`'s, each
  /// x and y in turn: the eight unknowns' linear system (two rows a
  /// point), solved by Gaussian elimination with partial pivoting. Nil
  /// where three of the points are on one line.
  init?(from source: [Double], to destination: [Double]) {
    guard source.count == 8, destination.count == 8 else { return nil }
    var rows: [[Double]] = []
    for corner in 0..<4 {
      let x = source[2 * corner]
      let y = source[2 * corner + 1]
      let u = destination[2 * corner]
      let v = destination[2 * corner + 1]
      rows.append([x, y, 1, 0, 0, 0, -u * x, -u * y, u])
      rows.append([0, 0, 0, x, y, 1, -v * x, -v * y, v])
    }
    let unknowns = 8
    for column in 0..<unknowns {
      var pivot = column
      for row in (column + 1)..<unknowns where abs(rows[row][column]) > abs(rows[pivot][column]) {
        pivot = row
      }
      guard abs(rows[pivot][column]) > Self.singular else { return nil }
      rows.swapAt(column, pivot)
      for row in 0..<unknowns where row != column {
        let factor = rows[row][column] / rows[column][column]
        if factor == 0 { continue }
        for entry in column...unknowns {
          rows[row][entry] -= factor * rows[column][entry]
        }
      }
    }
    var solved: [Double] = []
    for row in 0..<unknowns {
      solved.append(rows[row][unknowns] / rows[row][row])
    }
    values = solved + [1]
  }

  /// Below this a pivot is no pivot: the points do not span the plane.
  private static let singular = 1e-12

  /// Where it takes a point.
  func apply(x: Double, y: Double) -> (x: Double, y: Double) {
    let w = values[6] * x + values[7] * y + values[8]
    return ((values[0] * x + values[1] * y + values[2]) / w, (values[3] * x + values[4] * y + values[5]) / w)
  }

  /// `fraction` of the way from no transform to this one, entry by entry:
  /// the overlay's motion in and out.
  func eased(_ fraction: Double) -> Homography {
    var eased: [Double] = []
    for index in 0..<9 {
      eased.append(Self.identity.values[index] * (1 - fraction) + values[index] * fraction)
    }
    return Homography(values: eased)
  }

  /// As CSS's `matrix3d()` takes it, column by column: the plane's x, y
  /// and w in the 4×4's first, second and fourth rows and columns, z left
  /// alone.
  var cssMatrix3D: [Double] {
    [
      values[0], values[3], 0, values[6],
      values[1], values[4], 0, values[7],
      0, 0, 1, 0,
      values[2], values[5], 0, values[8],
    ]
  }
}
