import XCTest

@testable import ArtifactCore

/// The image is read as its service advertises it: the scale factor a zoom
/// shows, the tiles a view needs (nearest its middle first), the sizes the
/// whole image is asked for at, and the URLs the service's `info.json`
/// describes, so a tile asked for twice is one cached response.
final class TilePyramidTests: XCTestCase {
  /// An Internet Archive page's `info.json` (512 tiles, scale factors 1–32,
  /// its sizes, its largest request).
  static let archive =
    #"{"@context":"http://iiif.io/api/image/3/context.json","id":"x","type":"ImageService3","protocol":"http://iiif.io/api/image","profile":"level2","width":2346,"height":3140,"maxArea":7366440,"sizes":[{"width":73,"height":98},{"width":147,"height":196},{"width":293,"height":393},{"width":587,"height":785},{"width":1173,"height":1570},{"width":2346,"height":3140}],"tiles":[{"width":512,"height":512,"scaleFactors":[1,2,4,8,16,32]}],"extraQualities":["bitonal","color","gray"],"extraFormats":["tif","gif"]}"#
  let service = "https://iiif.archive.org/image/iiif/3/item%2Fpage.jp2"

  var page: TilePyramid {
    TilePyramid(width: 2346, height: 3140, info: ServiceInfo.parse(Self.archive))
  }

  func testInfoJSONIsReadAsAdvertised() throws {
    let info = try XCTUnwrap(ServiceInfo.parse(Self.archive))
    XCTAssertEqual(info.width, 2346)
    XCTAssertEqual(info.height, 3140)
    XCTAssertEqual(info.tileWidth, 512)
    XCTAssertEqual(info.scaleFactors, [1, 2, 4, 8, 16, 32])
    XCTAssertEqual(info.sizes, [73, 147, 293, 587, 1173, 2346])
    XCTAssertEqual(info.maxArea, 7_366_440)
    XCTAssertNil(info.maxWidth)
    XCTAssertEqual(info.format, "jpg")
    // Its keys read from the top level, whatever the order: the sizes' and
    // tiles' widths are theirs.
    let reordered = try XCTUnwrap(
      ServiceInfo.parse(#"{"tiles":[{"width":256,"scaleFactors":[1,2]}],"sizes":[{"width":50,"height":60}],"width":1000,"height":1200,"extraFormats":["webp"]}"#))
    XCTAssertEqual(reordered.width, 1000)
    XCTAssertEqual(reordered.tileWidth, 256)
    XCTAssertEqual(reordered.sizes, [50])
    XCTAssertEqual(reordered.format, "webp")
    // An id that merely contains the letters is no format.
    XCTAssertEqual(ServiceInfo.parse(#"{"id":"https://x/webpage.jp2","width":1,"height":1}"#)?.format, "jpg")
    // Not an info.json: nothing.
    XCTAssertNil(ServiceInfo.parse(#"{"error":"Network error"}"#))
  }

  func testTheWholeImageIsAskedForAtTheSizesTheServiceLists() {
    XCTAssertEqual(page.wholeLadder, [2346, 1173, 587, 293, 147, 73])
    // The narrowest at least as wide as needed: a retina fit's 1195 is the
    // full size, never 1173 (never coarser than the screen).
    XCTAssertEqual(page.wholeWidth(atLeast: 1195) { _ in false }, 2346)
    XCTAssertEqual(page.wholeWidth(atLeast: 1100) { _ in false }, 1173)
    // Wider than any: the widest; one that fails: the next.
    XCTAssertEqual(page.wholeWidth(atLeast: 5000) { _ in false }, 2346)
    XCTAssertEqual(page.wholeWidth(atLeast: 5000) { $0 == 2346 }, 1173)
    // Only under a width: the size below it.
    XCTAssertEqual(page.wholeWidth(atLeast: Int.max, below: 1173) { _ in false }, 587)
    XCTAssertNil(page.wholeWidth(atLeast: 1) { _ in true })
  }

  func testWithoutItsInfoTheWholeImageIsAskedForAtThePowersOfTwo() {
    let unread = TilePyramid(width: 2820, height: 3781)
    XCTAssertFalse(unread.hasTiles)
    XCTAssertEqual(Array(unread.wholeLadder.prefix(4)), [2820, 1410, 705, 353])
    XCTAssertEqual(unread.wholeLadder.last, 1)
  }

  func testTheServicesLimitsAreKept() throws {
    let limited = TilePyramid(
      width: 4000, height: 3000,
      info: try XCTUnwrap(ServiceInfo.parse(#"{"width":4000,"height":3000,"maxWidth":2500,"tiles":[{"width":512,"scaleFactors":[1,2,4,8]}]}"#)))
    XCTAssertEqual(limited.wholeLadder, [2000, 1000, 500])
    XCTAssertFalse(limited.serves(width: 4000))
    let area = TilePyramid(width: 2346, height: 3140, info: ServiceInfo.parse(#"{"width":2346,"height":3140,"maxArea":2000000}"#))
    XCTAssertFalse(area.serves(width: 2346))
    XCTAssertTrue(area.serves(width: 1173))
  }

  func testTheTileScaleIsTheCoarsestNoCoarserThanTheScreen() {
    // At its actual size, or larger: the full resolution.
    XCTAssertEqual(page.tileScale(needed: 2346), 1)
    XCTAssertEqual(page.tileScale(needed: 4692), 1)
    // Half of it, exactly: scale 2; a pixel more: scale 1.
    XCTAssertEqual(page.tileScale(needed: 1173), 2)
    XCTAssertEqual(page.tileScale(needed: 1174), 1)
    XCTAssertEqual(page.tileScale(needed: 300), 4)
    XCTAssertEqual(page.tileScale(needed: 1), 32)
  }

  func testTilesCoverTheImageAndStopAtItsEdge() {
    XCTAssertEqual(page.columns(scale: 1), 5)
    XCTAssertEqual(page.rows(scale: 1), 7)
    XCTAssertEqual(page.columns(scale: 2), 3)
    let last = page.region(scale: 1, column: 4, row: 6)
    XCTAssertEqual(last.x, 2048)
    XCTAssertEqual(last.width, 298)
    XCTAssertEqual(last.y, 3072)
    XCTAssertEqual(last.height, 68)
    XCTAssertEqual(
      page.tileURL(service: service, scale: 2, column: 1, row: 2, format: "jpg"),
      service + "/1024,2048,1024,1024/512,/0/default.jpg")
    XCTAssertEqual(
      page.tileURL(service: service, scale: 2, column: 2, row: 0, format: "jpg"),
      service + "/2048,0,298,1024/149,/0/default.jpg")
    XCTAssertEqual(
      page.tileURL(service: service, scale: 1, column: 4, row: 6, format: "webp"),
      service + "/2048,3072,298,68/298,/0/default.webp")
    XCTAssertEqual(page.wholeURL(service: service + "/", width: 1173, format: "jpg"), service + "/full/1173,/0/default.jpg")
    // No tiles advertised: none.
    XCTAssertEqual(TilePyramid(width: 2346, height: 3140).columns(scale: 1), 0)
  }

  func testTheViewsTilesNearestItsMiddleFirst() {
    // Actual size, the image's corner at the viewport's: 1000 by 800 shows
    // columns 0–1, rows 0–1.
    let tiles = page.visibleTiles(scale: 1, panX: 0, panY: 0, zoom: 1, viewportWidth: 1000, viewportHeight: 800)
    XCTAssertEqual(tiles.count, 4)
    XCTAssertEqual(tiles[0].column, 0)
    XCTAssertEqual(tiles[0].row, 0)
    // Panned so a tile's edge meets the viewport's: that tile is not shown.
    let panned = page.visibleTiles(scale: 1, panX: -512, panY: -1024, zoom: 1, viewportWidth: 1024, viewportHeight: 512)
    XCTAssertEqual(panned.map(\.column).sorted(), [1, 2])
    XCTAssertEqual(Set(panned.map(\.row)), [2])
    // Beyond the image: none.
    XCTAssertTrue(page.visibleTiles(scale: 1, panX: 3000, panY: 0, zoom: 1, viewportWidth: 1000, viewportHeight: 800).isEmpty)
    // Centered and zoomed, every tile around the middle, the farthest last.
    let middle = page.visibleTiles(
      scale: 1, panX: 500 - 1173, panY: 400 - 1570, zoom: 1, viewportWidth: 1000, viewportHeight: 800)
    XCTAssertEqual(middle.first?.column, 2)
    XCTAssertEqual(middle.first?.row, 3)
  }

  func testBestTileAsksForTheTileAtItsLevel() {
    let url = TileURL.bestTile(
      serviceID: service, tileWidth: 512, scaleFactor: 2, x: 2, y: 0, imageWidth: 2346, imageHeight: 3140)
    XCTAssertEqual(url, service + "/2048,0,298,1024/149,/0/default.jpg")
  }
}
