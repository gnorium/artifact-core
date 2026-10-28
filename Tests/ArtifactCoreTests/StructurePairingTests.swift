import XCTest

@testable import ArtifactCore

/// The structure overlay's pairing (user, 2026-10-14): the edition's rows and
/// the scan's paired in order, a row off by a whole leading left unpaired, a
/// pair within a quarter of the leading quiet.
final class StructurePairingTests: XCTestCase {
  static let leading = 20.0

  static func row(_ top: Double, _ bottom: Double) -> StructureRow {
    StructureRow(left: 0, top: top, right: 100, bottom: bottom)
  }

  func testLinesWhoseInkTouchesAcrossTightLeadingStayRowsApart() {
    // Each line's box 33 tall at a pitch of 20 (a tilted line's upright
    // box): they overlap by 13, under half a line, so none is beside the
    // next (Hamlet Q1 p. 4 chained 37 lines into 2 rows).
    let lines = (0..<5).map { Self.row(Double($0) * 20, Double($0) * 20 + 33) }
    XCTAssertEqual(StructurePairing.rows(lines).count, 5)
    // Two columns of one row overlap by most of their height.
    let columns = [StructureRow(left: 0, top: 0, right: 40, bottom: 12), StructureRow(left: 60, top: 2, right: 100, bottom: 13)]
    XCTAssertEqual(StructurePairing.rows(columns).count, 1)
  }

  func testInkOfItsOwnOnALinesBaselineIsThatLinesRow() {
    // A comma measured as ink of its own (its own text node): a box 5 tall
    // at the line's foot, on the line's baseline, overlapping the line by
    // under half its own height. One row, never two.
    var line = Self.row(0, 12)
    line.baseline = 10
    var comma = Self.row(10, 15)
    comma.baseline = 10
    var next = Self.row(20, 32)
    next.baseline = 30
    XCTAssertEqual(StructurePairing.rows([line, comma, next]).count, 2)
  }

  func testRowsInPlaceArePairedWithinTheTolerance() {
    let edition = [Self.row(0, 12), Self.row(20, 32), Self.row(40, 52)]
    let scan = [Self.row(1, 13), Self.row(21, 31), Self.row(39, 52)]
    XCTAssertEqual(
      StructurePairing.pair(edition: edition, scan: scan, leading: Self.leading),
      [.pair(edition: 0, scan: 0, within: true), .pair(edition: 1, scan: 1, within: true), .pair(edition: 2, scan: 2, within: true)])
  }

  func testAPairPastAQuarterOfTheLeadingIsOff() {
    // 6 > 20 / 4: a gap on another half-line step.
    let matches = StructurePairing.pair(edition: [Self.row(0, 12), Self.row(26, 38)], scan: [Self.row(0, 12), Self.row(20, 32)], leading: Self.leading)
    XCTAssertEqual(matches, [.pair(edition: 0, scan: 0, within: true), .pair(edition: 1, scan: 1, within: false)])
  }

  func testALineThePrintHasAndTheEditionLacksIsMissing() {
    let edition = [Self.row(0, 12), Self.row(40, 52)]
    let scan = [Self.row(0, 12), Self.row(20, 32), Self.row(40, 52)]
    XCTAssertEqual(
      StructurePairing.pair(edition: edition, scan: scan, leading: Self.leading),
      [.pair(edition: 0, scan: 0, within: true), .missing(scan: 1), .pair(edition: 1, scan: 2, within: true)])
  }

  func testALineTheEditionAddsIsExtra() {
    let edition = [Self.row(0, 12), Self.row(20, 32), Self.row(40, 52)]
    let scan = [Self.row(0, 12), Self.row(40, 52)]
    XCTAssertEqual(
      StructurePairing.pair(edition: edition, scan: scan, leading: Self.leading),
      [.pair(edition: 0, scan: 0, within: true), .extra(edition: 1), .pair(edition: 2, scan: 1, within: true)])
  }

  /// Typeface is not parity (user, 2026-10-17): a print line reaching 6px
  /// higher and 4px lower than the edition's (its capitals, its
  /// descenders), its letters on the same baseline, is within; the same
  /// boxes on baselines 6px apart are off (gnorium-python
  /// `test_the_faces_ascenders_and_descenders_are_no_difference`).
  func testTheFacesAscendersAndDescendersAreNoDifference() {
    var edition = StructureRow(left: 10, top: 10, right: 30, bottom: 22)
    edition.baseline = 20
    var print = StructureRow(left: 10, top: 4, right: 30, bottom: 26)
    print.baseline = 20
    XCTAssertTrue(StructurePairing.within(edition, print, leading: Self.leading))
    print.baseline = 26
    XCTAssertFalse(StructurePairing.within(edition, print, leading: Self.leading))
    // A row with no baseline is placed by its ink's bottom.
    XCTAssertEqual(Self.row(0, 12).seated, 12)
  }

  /// A row's baseline is its largest type's, the lower of equal ones.
  func testARowsBaselineIsItsLargestTypes() {
    let body = StructureRow(left: 0, top: 0, right: 40, bottom: 12, em: 16, baseline: 10, baselineEm: 16)
    let superscript = StructureRow(left: 40, top: -4, right: 46, bottom: 4, em: 10, baseline: 3, baselineEm: 10)
    XCTAssertEqual(superscript.joined(body).baseline, 10)
    XCTAssertEqual(body.joined(superscript).baseline, 10)
    let lower = StructureRow(left: 50, top: 0, right: 90, bottom: 13, em: 16, baseline: 11, baselineEm: 16)
    XCTAssertEqual(body.joined(lower).baseline, 11)
  }

  func testLinesSideBySideAreOneRow() {
    let rows = StructurePairing.rows([
      StructureRow(left: 50, top: 1, right: 90, bottom: 11), StructureRow(left: 0, top: 0, right: 40, bottom: 10),
      StructureRow(left: 0, top: 20, right: 40, bottom: 30),
    ])
    XCTAssertEqual(rows, [StructureRow(left: 0, top: 0, right: 90, bottom: 11), StructureRow(left: 0, top: 20, right: 40, bottom: 30)])
  }
}

/// Across, only the edges the print aligns, and only past an em of the
/// line's own type (user, 2026-10-14).
final class StructureAlignmentTests: XCTestCase {
  static func row(_ left: Double, _ right: Double, _ alignment: StructureAlignment, block: Int32 = -1) -> StructureRow {
    StructureRow(left: left, top: 0, right: right, bottom: 10, alignment: alignment, em: 16, block: block)
  }

  func testEachAlignmentJudgesItsOwnEdgesWithinAnEm() {
    let scan = StructureRow(left: 100, top: 0, right: 300, bottom: 10)
    XCTAssertTrue(StructurePairing.aligned(Self.row(110, 400, .left), scan))
    XCTAssertFalse(StructurePairing.aligned(Self.row(120, 300, .left), scan))
    XCTAssertTrue(StructurePairing.aligned(Self.row(0, 290, .right), scan))
    XCTAssertTrue(StructurePairing.aligned(Self.row(90, 330, .center), scan))
    XCTAssertFalse(StructurePairing.aligned(Self.row(120, 340, .center), scan))
    XCTAssertFalse(StructurePairing.aligned(Self.row(100, 280, .justified), scan))
    XCTAssertTrue(StructurePairing.aligned(Self.row(100, 280, .none), scan))
  }

  /// A speech and its stage direction set to the measure's right on one
  /// baseline (Hamlet Q1 p. 19, user 2026-10-28): one row, judged by the
  /// speech's start and the direction's end, never the speech's start alone.
  func testALeftSetLineBesideARightSetOneIsJudgedByBothEdges() {
    let row = Self.row(100, 300, .left, block: 1).joined(Self.row(500, 700, .right, block: 2))
    XCTAssertEqual(row.alignment, .justified)
    XCTAssertEqual(row.block, -1)
    let scan = StructureRow(left: 100, top: 0, right: 640, bottom: 10)
    XCTAssertFalse(StructurePairing.aligned(row, scan), "the direction set 60px (almost four ems) past the print's end")
    XCTAssertTrue(StructurePairing.aligned(row, StructureRow(left: 100, top: 0, right: 690, bottom: 10)))
    XCTAssertEqual(StructurePairing.lastLinesLeft([row]).first?.alignment, .justified)
  }

  func testAJustifiedBlocksLastLineIsSetFromItsStartAlone() {
    let rows = StructurePairing.lastLinesLeft([
      Self.row(0, 100, .justified, block: 1), Self.row(0, 60, .justified, block: 1), Self.row(0, 100, .justified, block: 2),
    ])
    XCTAssertEqual(rows.map(\.alignment), [.justified, .left, .left])
  }
}
