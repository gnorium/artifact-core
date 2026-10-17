import EmbeddedSwiftUtilities

/// What an image service's `info.json` advertises (IIIF Image API 2 and
/// 3): the image's size, its tiles' side and the scale factors they are cut
/// at, the whole-image sizes it lists, the largest request it serves, and
/// whether it serves WebP.
struct ServiceInfo {
  let width: Int
  let height: Int
  /// Its tiles' side; nil where it advertises none (whole images only).
  let tileWidth: Int?
  /// The scale factors its tiles are cut at (`tiles[0].scaleFactors`).
  let scaleFactors: [Int]
  /// The widths of the sizes it lists (`sizes`).
  let sizes: [Int]
  /// The largest request it serves (`maxWidth`, `maxHeight`, `maxArea`).
  let maxWidth: Int?
  let maxHeight: Int?
  let maxArea: Int?
  let format: String

  /// The format every IIIF image service serves (the API requires `jpg`
  /// at every compliance level).
  static let defaultFormat = "jpg"

  /// What `json` advertises; nil where it is not an `info.json` (a refusal,
  /// a network error the fetch bridge answers with an error object).
  static func parse(_ json: String) -> ServiceInfo? {
    // Its arrays are read apart and taken out, so the top level's own
    // keys are read from what is left.
    let sizes = array(json, key: "sizes")
    let afterSizes = sizes?.rest ?? json
    let tiles = array(afterSizes, key: "tiles")
    let top = tiles?.rest ?? afterSizes
    guard let width = extractJSONInt(top, key: "width"), let height = extractJSONInt(top, key: "height"),
      width > 0, height > 0
    else { return nil }
    var sizeWidths: [Int] = []
    if let sizes {
      let pieces = stringSplit(sizes.content, separator: "\"width\":")
      for (index, piece) in pieces.enumerated() where index > 0 {
        if let value = leadingInt(piece), value > 0 { sizeWidths.append(value) }
      }
    }
    var tileWidth: Int?
    var factors: [Int] = []
    if let tiles {
      if let side = extractJSONInt(tiles.content, key: "width"), side > 0 { tileWidth = side }
      if let scale = array(tiles.content, key: "scaleFactors") {
        for piece in stringSplit(scale.content, separator: ",") {
          if let value = leadingInt(piece), value > 0 { factors.append(value) }
        }
      }
    }
    return ServiceInfo(
      width: width, height: height, tileWidth: tileWidth, scaleFactors: factors, sizes: sizeWidths,
      maxWidth: extractJSONInt(top, key: "maxWidth"), maxHeight: extractJSONInt(top, key: "maxHeight"),
      maxArea: extractJSONInt(top, key: "maxArea"),
      format: stringContains(json, "\"webp\"") ? "webp" : defaultFormat)
  }

  /// The array `key` holds (the text between its brackets), and the JSON
  /// without it; nil where there is none.
  static func array(_ json: String, key: String) -> (content: String, rest: String)? {
    let bytes = Array(json.utf8)
    let pattern = Array("\"\(key)\":".utf8)
    guard bytes.count > pattern.count else { return nil }
    var start = -1
    var at = 0
    while at + pattern.count <= bytes.count {
      var match = true
      for offset in 0..<pattern.count where bytes[at + offset] != pattern[offset] {
        match = false
        break
      }
      if match {
        start = at
        break
      }
      at += 1
    }
    guard start >= 0 else { return nil }
    var open = start + pattern.count
    while open < bytes.count, bytes[open] == 32 { open += 1 }
    // `[` opens it.
    guard open < bytes.count, bytes[open] == 91 else { return nil }
    var depth = 0
    var close = open
    while close < bytes.count {
      if bytes[close] == 91 { depth += 1 }
      if bytes[close] == 93 {
        depth -= 1
        if depth == 0 { break }
      }
      close += 1
    }
    guard close < bytes.count else { return nil }
    let content = String(decoding: bytes[(open + 1)..<close], as: UTF8.self)
    var rest = Array(bytes[0..<start])
    if close + 1 < bytes.count { rest.append(contentsOf: bytes[(close + 1)...]) }
    return (content, String(decoding: rest, as: UTF8.self))
  }

  /// The whole number `text` begins with, spaces before it skipped.
  static func leadingInt(_ text: String) -> Int? {
    var value = 0
    var digits = 0
    for byte in text.utf8 {
      if byte == 32 && digits == 0 { continue }
      guard byte >= 48 && byte <= 57 else { break }
      value = value * 10 + Int(byte - 48)
      digits += 1
    }
    return digits > 0 ? value : nil
  }
}

/// An image service's image as IIIF lays it out: tiles cut at the scale
/// factors the service advertises (a tile at scale factor `s` covers
/// `tileWidth · s` pixels of the full image and is asked for at
/// `ceil(width / s)` wide), and whole images at the sizes it lists. Every
/// URL it makes is one the service's `info.json` describes, so a tile asked
/// for twice—while preloading, after a zoom, by the next reader—is one
/// cached response, not a fresh crop the server renders again.
///
/// Nothing here is a tuned constant: the levels, the sizes and the limits
/// are the service's own, and where its `info.json` is not read, the whole
/// image is asked for at the powers of two of its width (the convention
/// IIIF pyramids are cut by), with no tiles.
///
/// Pure arithmetic, shared by the client's compositor and its tests.
struct TilePyramid {
  /// The full image, in pixels.
  let width: Int
  let height: Int
  /// What its service advertises; nil before (or without) its `info.json`.
  let info: ServiceInfo?

  init(width: Int, height: Int, info: ServiceInfo? = nil) {
    self.width = max(1, width)
    self.height = max(1, height)
    self.info = info
  }

  /// `ceil(value / factor)`.
  static func scaled(_ value: Int, by factor: Int) -> Int {
    let factor = max(1, factor)
    return (value + factor - 1) / factor
  }

  /// The side of its tiles; 0 where the service advertises none.
  var tileWidth: Int { info?.tileWidth ?? 0 }

  /// Whether the service advertises tiles.
  var hasTiles: Bool { tileWidth > 0 }

  /// Its scale factors, finest first: the service's own, else the powers of
  /// two down to a level one pixel wide.
  var scaleFactors: [Int] {
    if let info, !info.scaleFactors.isEmpty { return info.scaleFactors.sorted() }
    var factors = [1]
    while Self.scaled(width, by: factors[factors.count - 1]) > 1 { factors.append(factors[factors.count - 1] * 2) }
    return factors
  }

  /// The height of the image shown `w` wide.
  func height(atWidth w: Int) -> Int {
    (height * w + width - 1) / width
  }

  /// Whether the service serves the whole image `w` wide: no wider than the
  /// image (no upscaling) and within the largest request it advertises.
  func serves(width w: Int) -> Bool {
    guard w > 0, w <= width else { return false }
    let h = height(atWidth: w)
    if let most = info?.maxWidth, w > most { return false }
    if let most = info?.maxHeight, h > most { return false }
    if let most = info?.maxArea, w * h > most { return false }
    return true
  }

  /// The widths the whole image is asked for at, widest first: the sizes
  /// the service lists, else its levels' widths; only those it serves.
  var wholeLadder: [Int] {
    var widths: [Int] = []
    if let info, !info.sizes.isEmpty {
      widths = info.sizes
    } else {
      for factor in scaleFactors { widths.append(Self.scaled(width, by: factor)) }
    }
    var ladder: [Int] = []
    for candidate in widths.sorted(by: >) where serves(width: candidate) {
      var seen = false
      for held in ladder where held == candidate { seen = true }
      if !seen { ladder.append(candidate) }
    }
    return ladder
  }

  /// The width to ask for to show `needed` pixels across: the narrowest
  /// the service serves that is at least that wide and is not `unusable`,
  /// else the widest that is not; nil if every one is. Only widths under
  /// `below` when it is given.
  func wholeWidth(atLeast needed: Int, below: Int = Int.max, unusable: (Int) -> Bool) -> Int? {
    var enough: Int?
    var widest: Int?
    for rung in wholeLadder where rung < below && !unusable(rung) {
      if widest == nil { widest = rung }
      if rung >= needed { enough = rung }
    }
    return enough ?? widest
  }

  /// The scale factor the tiles are asked for at to show `needed` pixels
  /// across: the coarsest at which the image is at least that wide—never
  /// coarser than the screen—else the finest.
  func tileScale(needed: Int) -> Int {
    let factors = scaleFactors
    var chosen = factors.first ?? 1
    for factor in factors where Self.scaled(width, by: factor) >= needed && factor > chosen { chosen = factor }
    return chosen
  }

  /// The tile grid at a scale factor.
  func columns(scale: Int) -> Int {
    guard hasTiles else { return 0 }
    let span = tileWidth * scale
    return (width + span - 1) / span
  }

  func rows(scale: Int) -> Int {
    guard hasTiles else { return 0 }
    let span = tileWidth * scale
    return (height + span - 1) / span
  }

  /// A tile's region of the full image (the last row and column are cut
  /// at its edge).
  func region(scale: Int, column: Int, row: Int) -> (x: Int, y: Int, width: Int, height: Int) {
    let span = tileWidth * scale
    let x = column * span
    let y = row * span
    return (x, y, min(span, width - x), min(span, height - y))
  }

  /// A tile's URL: its region in full-image pixels, its width at its scale.
  func tileURL(service: String, scale: Int, column: Int, row: Int, format: String) -> String {
    let box = region(scale: scale, column: column, row: row)
    return stringJoin(
      [
        Self.base(service), "/", intToString(box.x), ",", intToString(box.y), ",", intToString(box.width), ",",
        intToString(box.height), "/", intToString(Self.scaled(box.width, by: scale)), ",/0/default.", format,
      ], separator: "")
  }

  /// The whole image at a width, in one request.
  func wholeURL(service: String, width: Int, format: String) -> String {
    stringJoin([Self.base(service), "/full/", intToString(width), ",/0/default.", format], separator: "")
  }

  /// The tiles at a scale factor the view shows (`panX`, `panY`: where the
  /// image's corner is in the viewport; `zoom`: viewport pixels to one image
  /// pixel), nearest its middle first: the order they are asked for, so
  /// what the reader looks at arrives first.
  func visibleTiles(
    scale: Int, panX: Double, panY: Double, zoom: Double, viewportWidth: Double, viewportHeight: Double
  ) -> [(column: Int, row: Int)] {
    guard hasTiles, zoom > 0, viewportWidth > 0, viewportHeight > 0 else { return [] }
    let span = Double(tileWidth * scale) * zoom
    let columns = columns(scale: scale)
    let rows = rows(scale: scale)
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
        let box = region(scale: scale, column: column, row: row)
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
}
