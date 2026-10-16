import XCTest

@testable import ArtifactCore

/// The image is read as its service's tile pyramid: the level a zoom shows,
/// the tiles a view needs (nearest its middle first) and the URLs the
/// service's `info.json` describes, so a tile asked for twice is one cached
/// response.
final class TilePyramidTests: XCTestCase {
  /// An Internet Archive page (its `info.json`: 512 tiles, scale factors
  /// 1–32).
  let page = TilePyramid(width: 2346, height: 3140)
  let service = "https://iiif.archive.org/image/iiif/3/item%2Fpage.jp2"

  func testLevelsHalveRoundingUp() {
    XCTAssertEqual(page.size(atLevel: 0).width, 2346)
    XCTAssertEqual(page.size(atLevel: 1).width, 1173)
    XCTAssertEqual(page.size(atLevel: 2).width, 587)
    XCTAssertEqual(page.size(atLevel: 2).height, 785)
    // 3140 at 1/8 is 392.5: the level is 393 tall.
    XCTAssertEqual(page.size(atLevel: 3).height, 393)
    // Whole in one tile at 1/8: 294 by 393.
    XCTAssertEqual(page.coarsestLevel, 3)
  }

  func testTheLevelIsTheCoarsestNoBlurrierThanTheScreen() {
    // At its actual size, or larger: the full resolution.
    XCTAssertEqual(page.level(devicePixels: 1), 0)
    XCTAssertEqual(page.level(devicePixels: 2), 0)
    // A retina fit (0.2548 zoom, 2 device pixels a CSS pixel): the half
    // level, 1173 wide for 1195 device pixels—not the full image's tiles.
    XCTAssertEqual(page.level(devicePixels: 0.5096), 1)
    // Zoomed a little past it: the full resolution, never stretched.
    XCTAssertEqual(page.level(devicePixels: 0.7), 0)
    // A 1x fit: the quarter level.
    XCTAssertEqual(page.level(devicePixels: 0.2548), 2)
    // Never coarser than one tile.
    XCTAssertEqual(page.level(devicePixels: 0.001), page.coarsestLevel)
  }

  func testTheBackdropIsTheCoarsestAtLeast256Wide() {
    XCTAssertEqual(page.backdropLevel, 3)
    XCTAssertEqual(page.size(atLevel: page.backdropLevel).width, 294)
    // A small image: itself.
    XCTAssertEqual(TilePyramid(width: 200, height: 300).backdropLevel, 0)
  }

  func testTilesCoverTheImageAndStopAtItsEdge() {
    XCTAssertEqual(page.columns(atLevel: 0), 5)
    XCTAssertEqual(page.rows(atLevel: 0), 7)
    XCTAssertEqual(page.columns(atLevel: 1), 3)
    let last = page.region(level: 0, column: 4, row: 6)
    XCTAssertEqual(last.x, 2048)
    XCTAssertEqual(last.width, 298)
    XCTAssertEqual(last.y, 3072)
    XCTAssertEqual(last.height, 68)
    // A level-1 tile covers 1024 of the image, asked for 512 wide; its last
    // column 298 wide, 149 at its level.
    XCTAssertEqual(
      page.tileURL(service: service, level: 1, column: 1, row: 2, format: "jpg"),
      service + "/1024,2048,1024,1024/512,/0/default.jpg")
    XCTAssertEqual(
      page.tileURL(service: service, level: 1, column: 2, row: 0, format: "jpg"),
      service + "/2048,0,298,1024/149,/0/default.jpg")
    XCTAssertEqual(
      page.tileURL(service: service, level: 0, column: 4, row: 6, format: "webp"),
      service + "/2048,3072,298,68/298,/0/default.webp")
    XCTAssertEqual(page.wholeURL(service: service + "/", level: 1, format: "jpg"), service + "/full/1173,/0/default.jpg")
  }

  func testTheViewsTilesNearestItsMiddleFirst() {
    // Actual size, the image's corner at the viewport's: 1000 by 800 shows
    // columns 0–1, rows 0–1.
    let tiles = page.visibleTiles(level: 0, panX: 0, panY: 0, zoom: 1, viewportWidth: 1000, viewportHeight: 800)
    XCTAssertEqual(tiles.count, 4)
    // The middle (500, 400) is in tile (0, 0).
    XCTAssertEqual(tiles[0].column, 0)
    XCTAssertEqual(tiles[0].row, 0)
    // Panned so a tile's edge meets the viewport's: that tile is not shown.
    let panned = page.visibleTiles(level: 0, panX: -512, panY: -1024, zoom: 1, viewportWidth: 1024, viewportHeight: 512)
    XCTAssertEqual(panned.map(\.column).sorted(), [1, 2])
    XCTAssertEqual(Set(panned.map(\.row)), [2])
    // Beyond the image: none.
    XCTAssertTrue(page.visibleTiles(level: 0, panX: 3000, panY: 0, zoom: 1, viewportWidth: 1000, viewportHeight: 800).isEmpty)
    // Centered and zoomed, every tile around the middle, the farthest last.
    let middle = page.visibleTiles(
      level: 0, panX: 500 - 1173, panY: 400 - 1570, zoom: 1, viewportWidth: 1000, viewportHeight: 800)
    XCTAssertEqual(middle.first?.column, 2)
    XCTAssertEqual(middle.first?.row, 3)
  }

  func testTheWholeImageInViewIsOneRequest() {
    // At its fit: whole.
    XCTAssertTrue(page.drawsWhole(level: 1, zoom: 0.2548, viewportWidth: 1000, viewportHeight: 800))
    // Zoomed past it, part of it out of view: tiles.
    XCTAssertFalse(page.drawsWhole(level: 0, zoom: 0.5, viewportWidth: 1000, viewportHeight: 800))
    // One tile: whole, whatever the view.
    XCTAssertTrue(page.drawsWhole(level: 3, zoom: 0.5, viewportWidth: 100, viewportHeight: 100))
  }

  func testInfoJSONTileSideAndFormat() {
    let archive = #"{"width":2346,"height":3140,"sizes":[{"width":73,"height":98}],"tiles":[{"width":512,"height":512,"scaleFactors":[1,2,4]}],"extraFormats":["tif","gif"]}"#
    XCTAssertEqual(TilePyramid.tileSize(infoJSON: archive), 512)
    XCTAssertEqual(TilePyramid.format(infoJSON: archive), "jpg")
    let webp = #"{"width":100,"tiles":[{"width":256,"scaleFactors":[1]}],"extraFormats":["webp"]}"#
    XCTAssertEqual(TilePyramid.tileSize(infoJSON: webp), 256)
    XCTAssertEqual(TilePyramid.format(infoJSON: webp), "webp")
    // An id that merely contains the letters is no format.
    XCTAssertEqual(TilePyramid.format(infoJSON: #"{"id":"https://x/webpage.jp2","width":1}"#), "jpg")
    XCTAssertNil(TilePyramid.tileSize(infoJSON: #"{"error":"Network error"}"#))
  }

  func testBestTileAsksForTheTileAtItsLevel() {
    let url = TileURL.bestTile(
      serviceID: service, tileWidth: 512, scaleFactor: 2, x: 2, y: 0, imageWidth: 2346, imageHeight: 3140)
    XCTAssertEqual(url, service + "/2048,0,298,1024/149,/0/default.jpg")
  }
}
