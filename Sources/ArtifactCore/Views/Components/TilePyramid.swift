import EmbeddedSwiftUtilities

/// An image service's tiles as IIIF lays them out (Image API 2 and 3): level
/// `k` is the image at `1/2^k` of its full size, cut into tiles of
/// `tileSize` of its own pixels, so a tile at level `k` covers
/// `tileSize << k` pixels of the full image and is asked for at
/// `ceil(width / 2^k)` wide. Every URL it makes is the one the service's
/// `info.json` describes (its `tiles` and `sizes`), so a tile asked for
/// twice—while preloading, after a zoom, by the next reader—is one cached
/// response, not a fresh crop the server renders again.
///
/// Pure arithmetic, shared by the client's compositor and its tests.
struct TilePyramid {
  /// The full image, in pixels.
  let width: Int
  let height: Int
  /// A tile's side, in its level's pixels (`info.json`'s `tiles[0].width`).
  let tileSize: Int

  /// The side a service's tiles have when its `info.json` is not yet read.
  static let defaultTileSize = 512
  /// How far a level may be stretched past one of its pixels a device
  /// pixel before the next finer one is asked for: a fit 2% short of a
  /// level's size shows that level, not four times its tiles.
  static let stretchAllowance = 1.15
  /// The widest a low-resolution copy needs to be: it is seen only while
  /// the detail loads.
  static let backdropWidth = 256
  /// The longest side a whole level is asked for in one image; past it,
  /// tiles (servers cap a request's size).
  static let wholeLimit = 4096

  init(width: Int, height: Int, tileSize: Int = TilePyramid.defaultTileSize) {
    self.width = max(1, width)
    self.height = max(1, height)
    self.tileSize = max(1, tileSize)
  }

  /// `ceil(value / 2^level)`.
  static func scaled(_ value: Int, _ level: Int) -> Int {
    let scale = 1 << level
    return (value + scale - 1) / scale
  }

  /// The coarsest level: the whole image in one tile.
  var coarsestLevel: Int {
    var level = 0
    while Self.scaled(width, level) > tileSize || Self.scaled(height, level) > tileSize { level += 1 }
    return level
  }

  /// The coarsest level whose pixels are no larger than a device pixel,
  /// give or take `stretchAllowance`, at `devicePixels` device pixels to
  /// one image pixel (the zoom times the device pixel ratio).
  func level(devicePixels: Double) -> Int {
    guard devicePixels > 0 else { return coarsestLevel }
    let reach = Self.stretchAllowance / devicePixels
    var level = 0
    while level < coarsestLevel, Double(1 << (level + 1)) <= reach { level += 1 }
    return level
  }

  /// The level the low-resolution copy is: the coarsest at least
  /// `backdropWidth` wide (or the whole image, if it is narrower).
  var backdropLevel: Int {
    let wanted = min(Self.backdropWidth, width)
    var level = 0
    while Self.scaled(width, level + 1) >= wanted, level + 1 <= coarsestLevel { level += 1 }
    return level
  }

  /// A level's image size, in its own pixels.
  func size(atLevel level: Int) -> (width: Int, height: Int) {
    (Self.scaled(width, level), Self.scaled(height, level))
  }

  /// A level's tile grid.
  func columns(atLevel level: Int) -> Int {
    let span = tileSize << level
    return (width + span - 1) / span
  }

  func rows(atLevel level: Int) -> Int {
    let span = tileSize << level
    return (height + span - 1) / span
  }

  /// A tile's region of the full image (the last row and column are cut
  /// at its edge).
  func region(level: Int, column: Int, row: Int) -> (x: Int, y: Int, width: Int, height: Int) {
    let span = tileSize << level
    let x = column * span
    let y = row * span
    return (x, y, min(span, width - x), min(span, height - y))
  }

  /// A tile's URL: its region in full-image pixels, its width at its level.
  func tileURL(service: String, level: Int, column: Int, row: Int, format: String) -> String {
    let box = region(level: level, column: column, row: row)
    return stringJoin(
      [
        Self.base(service), "/", intToString(box.x), ",", intToString(box.y), ",", intToString(box.width), ",",
        intToString(box.height), "/", intToString(Self.scaled(box.width, level)), ",/0/default.", format,
      ], separator: "")
  }

  /// The whole image at a level, in one request.
  func wholeURL(service: String, level: Int, format: String) -> String {
    stringJoin(
      [Self.base(service), "/full/", intToString(Self.scaled(width, level)), ",/0/default.", format], separator: "")
  }

  /// Whether a level is drawn whole rather than in tiles: the image lies
  /// entirely in the view (each of its tiles would be asked for anyway) and
  /// the level is small enough for one request, or it is one tile.
  func drawsWhole(level: Int, zoom: Double, viewportWidth: Double, viewportHeight: Double) -> Bool {
    if level >= coarsestLevel { return true }
    let size = size(atLevel: level)
    guard size.width <= Self.wholeLimit, size.height <= Self.wholeLimit else { return false }
    return Double(width) * zoom <= viewportWidth + 1 && Double(height) * zoom <= viewportHeight + 1
  }

  /// The tiles of a level the view shows (`panX`, `panY`: where the
  /// image's corner is in the viewport; `zoom`: viewport pixels to one
  /// image pixel), nearest its middle first: the order they are asked for,
  /// so what the reader looks at arrives first.
  func visibleTiles(
    level: Int, panX: Double, panY: Double, zoom: Double, viewportWidth: Double, viewportHeight: Double
  ) -> [(column: Int, row: Int)] {
    guard zoom > 0, viewportWidth > 0, viewportHeight > 0 else { return [] }
    let span = Double(tileSize << level) * zoom
    let columns = columns(atLevel: level)
    let rows = rows(atLevel: level)
    let firstColumn = max(0, Int(((0 - panX) / span).rounded(.down)))
    let lastColumn = min(columns - 1, Int(((viewportWidth - panX) / span).rounded(.up)) - 1)
    let firstRow = max(0, Int(((0 - panY) / span).rounded(.down)))
    let lastRow = min(rows - 1, Int(((viewportHeight - panY) / span).rounded(.up)) - 1)
    guard firstColumn <= lastColumn, firstRow <= lastRow else { return [] }
    let middleX = viewportWidth / 2 - panX
    let middleY = viewportHeight / 2 - panY
    var found: [(column: Int, row: Int, distance: Double)] = []
    for row in firstRow...lastRow {
      for column in firstColumn...lastColumn {
        let box = region(level: level, column: column, row: row)
        let dx = (Double(box.x) + Double(box.width) / 2) * zoom - middleX
        let dy = (Double(box.y) + Double(box.height) / 2) * zoom - middleY
        found.append((column, row, dx * dx + dy * dy))
      }
    }
    found.sort { $0.distance < $1.distance }
    return found.map { ($0.column, $0.row) }
  }

  /// The service's base: its id without a trailing slash.
  static func base(_ service: String) -> String {
    stringEndsWith(service, "/") ? stringSubstring(service, from: 0, to: service.utf8.count - 1) : service
  }

  /// The tile side an `info.json` gives (`tiles[0].width`), if any.
  static func tileSize(infoJSON json: String) -> Int? {
    let parts = stringSplit(json, separator: "\"tiles\":")
    guard parts.count > 1, let side = extractJSONInt(parts[1], key: "width"), side >= 64 else { return nil }
    return side
  }

  /// The format a service is read in: WebP where its `info.json` lists it
  /// among its formats (`formats`, `extraFormats`, or a level 2 profile's
  /// `formats`), JPEG otherwise.
  static func format(infoJSON json: String) -> String {
    stringContains(json, "\"webp\"") ? "webp" : "jpg"
  }
}
