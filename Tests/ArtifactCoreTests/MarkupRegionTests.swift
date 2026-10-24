import XCTest

@testable import ArtifactCore

/// What the caret names on the scan, and how it is edited there: a `<zone>`
/// that writes `points` (a polygon), or only points elsewhere (a `facs`, a
/// `sameAs`, its own id among the facsimile's zones).
final class MarkupRegionTests: XCTestCase {
  private func region(_ text: String, caretAt needle: String, zones: String = "") -> MarkupRegion? {
    let bytes = Array(text.utf8)
    let caret = text.range(of: needle).map { text.utf8.distance(from: text.utf8.startIndex, to: $0.lowerBound) } ?? 0
    return MarkupRegion.at(bytes, caret: caret, zones: zones)
  }

  private func slice(_ text: String, _ region: MarkupRegion) -> String {
    String(decoding: Array(text.utf8)[region.valueStart..<region.valueEnd], as: UTF8.self)
  }

  private let polygon = #"<zone xml:id="z" points="100,100 300,100 300,200 100,200"/>"#

  func testAPolygonZoneNamesTheBoxAroundItsPointsAndIsEditable() throws {
    let found = try XCTUnwrap(region(polygon, caretAt: "xml:id"))
    XCTAssertEqual([found.x, found.y, found.width, found.height], [100, 100, 200, 100])
    XCTAssertTrue(found.editable)
    XCTAssertEqual(found.points, [100, 100, 300, 100, 300, 200, 100, 200])
    XCTAssertEqual(slice(polygon, found), "100,100 300,100 300,200 100,200")
  }

  func testAPolygonsBoxHandlesScaleAllItsPoints() throws {
    let found = try XCTUnwrap(region(polygon, caretAt: "xml:id"))
    // Moved and doubled: every point keeps its place in the box.
    XCTAssertEqual(
      found.writing(x: 200, y: 300, width: 400, height: 200), "200,300 600,300 600,500 200,500")
    // Halved in place.
    XCTAssertEqual(found.writing(x: 100, y: 100, width: 100, height: 50), "100,100 200,100 200,150 100,150")
    // Unmoved, unchanged.
    XCTAssertEqual(found.writing(x: 100, y: 100, width: 200, height: 100), "100,100 300,100 300,200 100,200")
  }

  func testAVertexMovesAloneAndTheBoxFollowsIt() throws {
    let found = try XCTUnwrap(region(polygon, caretAt: "xml:id"))
    XCTAssertEqual(found.writing(vertex: 1, toX: 350, y: 120), "100,100 350,120 300,200 100,200")
    // Kept inside the image.
    XCTAssertEqual(found.writing(vertex: 2, toX: 1200, y: -5), "100,100 300,100 1000,0 100,200")
    let moved = try XCTUnwrap(MarkupRegion.box(around: [100, 100, 350, 120, 300, 200, 100, 200]))
    XCTAssertEqual([moved.x, moved.y, moved.width, moved.height], [100, 100, 250, 100])
    XCTAssertNil(MarkupRegion.box(around: [1, 1, 2, 2]))
  }

  func testACornersZoneIsStillEditedAsFourCorners() throws {
    let text = #"<zone xml:id="z" ulx="10" uly="20" lrx="110" lry="70"/>"#
    let found = try XCTUnwrap(region(text, caretAt: "xml:id"))
    XCTAssertTrue(found.points.isEmpty)
    XCTAssertEqual(slice(text, found), #"10" uly="20" lrx="110" lry="70"#)
    XCTAssertEqual(found.writing(x: 30, y: 40, width: 100, height: 50), #"30" uly="40" lrx="130" lry="90"#)
  }

  func testAFacsReferenceIsEditedWhereTheZoneLives() throws {
    let text =
      #"<facsimile><surface><zone xml:id="a" ulx="10" uly="20" lrx="110" lry="70"/></surface></facsimile>"#
      + #"<text><p facs="#a">Hello</p></text>"#
    let found = try XCTUnwrap(region(text, caretAt: "Hello"))
    XCTAssertEqual([found.x, found.y, found.width, found.height], [10, 20, 100, 50])
    XCTAssertTrue(found.editable, "the zone is in the code")
    XCTAssertEqual(slice(text, found), #"10" uly="20" lrx="110" lry="70"#)
    let tag = Array(text.utf8).count - Array(#"<text><p facs="#a">Hello</p></text>"#.utf8).count
    XCTAssertLessThan(found.valueStart, tag, "the value stands in the facsimile, not at the caret")
  }

  func testAReferencedPolygonIsEditedWhereItLivesToo() throws {
    let text = #"<zone xml:id="a" points="10,10 60,10 60,60"/><p facs="#a">Hello</p>"#
    let found = try XCTUnwrap(region(text, caretAt: "Hello"))
    XCTAssertEqual(found.points, [10, 10, 60, 10, 60, 60])
    XCTAssertEqual(slice(text, found), "10,10 60,10 60,60")
  }

  func testAZoneWithOnlyAnIdIsShownFromThePagesZonesAndNotEdited() throws {
    let found = try XCTUnwrap(region(#"<zone xml:id="b"/>"#, caretAt: "xml:id", zones: "b 1 2 3 4"))
    XCTAssertEqual([found.x, found.y, found.width, found.height], [1, 2, 3, 4])
    XCTAssertFalse(found.editable, "its geometry is not in this code")
    let unknown = region(#"<zone xml:id="c"/>"#, caretAt: "xml:id", zones: "b 1 2 3 4")
    XCTAssertNil(unknown)
  }

  func testAZoneThatPointsAtAnotherIsEditedWhereTheOtherLives() throws {
    let text = #"<zone xml:id="a" ulx="10" uly="20" lrx="110" lry="70"/><zone xml:id="b" sameAs="#a"/>"#
    let found = try XCTUnwrap(region(text, caretAt: #"sameAs"#))
    XCTAssertEqual([found.x, found.y, found.width, found.height], [10, 20, 100, 50])
    XCTAssertTrue(found.editable)
  }

  func testAPolygonOutsideTheImageNamesNothing() {
    XCTAssertNil(region(#"<zone points="900,900 1100,900 1100,950"/>"#, caretAt: "points"))
  }
}
