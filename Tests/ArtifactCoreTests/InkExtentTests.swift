import XCTest

@testable import ArtifactCore

/// The overlay's target is the rendered page's ink, as the scan's zone is
/// the scan's (user, 2026-10-14): a line's font box less the font's ascent
/// and descent plus its glyphs', as the page is zoomed, and a glyph's ink
/// across without its advance or the letter-spacing after it.
final class InkExtentTests: XCTestCase {
  /// A face of ascent 16 and descent 4 in its own pixels, its line's
  /// glyphs inked 11 above the baseline and 3 below it.
  static let fontAscent = 16.0
  static let fontDescent = 4.0
  static let inkAscent = 11.0
  static let inkDescent = 3.0

  func testALinesInkIsItsFontBoxLessTheFontsAscentAndDescentPlusTheGlyphs() throws {
    let scale = try XCTUnwrap(
      InkExtent.scale(drawnHeight: 20, fontAscent: Self.fontAscent, fontDescent: Self.fontDescent))
    XCTAssertEqual(scale, 1)
    let rows = InkExtent.vertical(
      drawnTop: 100, drawnBottom: 120, fontAscent: Self.fontAscent, fontDescent: Self.fontDescent,
      inkAscent: Self.inkAscent, inkDescent: Self.inkDescent, scale: scale)
    XCTAssertEqual(rows.top, 105)
    XCTAssertEqual(rows.bottom, 119)
  }

  func testTheFontsMetricsScaleWithThePagesZoom() throws {
    // Zoomed to twice its size: the drawn box is twice the font box.
    let scale = try XCTUnwrap(
      InkExtent.scale(drawnHeight: 40, fontAscent: Self.fontAscent, fontDescent: Self.fontDescent))
    XCTAssertEqual(scale, 2)
    let rows = InkExtent.vertical(
      drawnTop: 200, drawnBottom: 240, fontAscent: Self.fontAscent, fontDescent: Self.fontDescent,
      inkAscent: Self.inkAscent, inkDescent: Self.inkDescent, scale: scale)
    XCTAssertEqual(rows.top, 210)
    XCTAssertEqual(rows.bottom, 238)
    XCTAssertNil(InkExtent.scale(drawnHeight: 0, fontAscent: Self.fontAscent, fontDescent: Self.fontDescent))
  }

  func testAGlyphsInkLeavesOutItsAdvanceAndTheLetterSpacingAfterIt() {
    // The last glyph's range runs from 300 for its advance of 9 and a
    // letter-spacing of 6, to 315; its ink is 1 in from its start to 8.
    let across = InkExtent.horizontal(drawnLeft: 300, inkLeft: -1, inkRight: 8, scale: 1)
    XCTAssertEqual(across.left, 301)
    XCTAssertEqual(across.right, 308)
    // An overhang (an italic's tail) runs left of the start.
    XCTAssertEqual(InkExtent.horizontal(drawnLeft: 300, inkLeft: 2, inkRight: 8, scale: 2).left, 296)
  }

  func testTheBoxIsAroundAllTakenAndNilForNothing() {
    var ink = InkExtent()
    XCTAssertNil(ink.box)
    ink.take(left: 10, top: 20, right: 30, bottom: 40)
    ink.take(left: 5, top: 25, right: 15, bottom: 50)
    ink.take(left: 0, top: 0, right: 0, bottom: 100)  // nothing drawn
    XCTAssertEqual(ink.box, [5, 20, 30, 50])
  }
}
