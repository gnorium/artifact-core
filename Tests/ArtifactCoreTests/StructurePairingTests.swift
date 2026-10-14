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

  func testAJustifiedBlocksLastLineIsSetFromItsStartAlone() {
    let rows = StructurePairing.lastLinesLeft([
      Self.row(0, 100, .justified, block: 1), Self.row(0, 60, .justified, block: 1), Self.row(0, 100, .justified, block: 2),
    ])
    XCTAssertEqual(rows.map(\.alignment), [.justified, .left, .left])
  }
}
