import XCTest

@testable import ArtifactCore

/// The overlay's registration (user, 2026-10-14) on prod madrigal dd5cc0b2's
/// canvas 3 (2026-10-17): the Etymological Dictionary's title page, a pasted
/// bookplate at its top, its title mid-page, saved before baselines were
/// kept. The edition set the title's three display lines at the body's
/// leading, the print's white between them dropped (its block 67px against
/// the scan's 566px at 0.209 a pixel): laid by the block's height, the whole
/// scan shrank to 56%, and the bookplate's lines stood in the blank between
/// the edition's bookplate (y 180–225) and its title (y 445–512).
final class OverlayRegistrationTests: XCTestCase {
  static let size = (width: 2820.0, height: 3781.0)
  /// The page's text block (`p3-textblock`), 0–1000.
  static let textBlock = [141.21, 385.12, 897.24, 386.72, 896.67, 536.41, 140.64, 534.81]
  /// The rendered title's ink box in the layer's pixels (left, top, right,
  /// bottom), the pane's 780px fitting the page's 92.28em: 8.45px an em.
  static let title = [400.0, 445.0, 1400.0, 512.0]
  /// The rendered em over the work's em on the scan (the frame declared) (40.40px: 2820 over the
  /// frame's 61.07em measure and two 4.37em margins).
  static let typeScale = 8.45 / 40.40
  /// The bookplate's block on the scan (`marginalia`), 0–1000.
  static let bookplate = [282.16, 60.9, 663.73, 61.71, 663.34, 162.74, 281.78, 161.93]

  /// The page's scan layout as `TEIView` handed it on prod (11 fields a
  /// zone: no baselines), and a line saved since with its baseline (15).
  static let layout =
    "block main - 141.21 385.12 897.24 386.72 897.16 408.67 141.13 407.07;"
    + "line - - 141.21 385.12 897.24 386.72 897.16 408.67 141.13 407.07;"
    + "word - p3-wz21 141.21 385.12 200.43 385.24 200.35 407.19 141.13 407.07;"
    + "block marginalia - 282.16 60.9 663.73 61.71 663.34 162.74 281.78 161.93;"
    + "line - - 395.99 61.14 548.48 61.46 548.43 73.1 395.95 72.78;"
    + "line - - 282.05 89.99 663.61 90.8 663.53 113.28 281.97 112.47 282.05 110 663.61 110.8"

  func testOldAndNewZonesBothParseUnshifted() {
    let zones = OverlayRegistration.scanLayout(Self.layout)
    XCTAssertEqual(zones.map(\.kind), [0, 1, 2, 0, 1, 1])
    XCTAssertEqual(zones.map(\.main), [true, true, true, false, false, false])
    XCTAssertEqual(zones.map(\.id), ["", "", "p3-wz21", "", "", ""])
    // An old zone's corners are its eight numbers, no baseline.
    XCTAssertEqual(zones[1].points, [141.21, 385.12, 897.24, 386.72, 897.16, 408.67, 141.13, 407.07])
    XCTAssertEqual(zones[4].baseline, [])
    // A new line's corners the same eight, its baseline the four after.
    XCTAssertEqual(zones[5].points, [282.05, 89.99, 663.61, 90.8, 663.53, 113.28, 281.97, 112.47])
    XCTAssertEqual(zones[5].baseline, [282.05, 110, 663.61, 110.8])
    // Anything else is no zone; none at all, none.
    XCTAssertEqual(OverlayRegistration.scanLayout("line - - 1 2 3 4 5 6 7 8 9 10;line - - 1 2 3 4 5 6 7 x").count, 0)
    XCTAssertEqual(OverlayRegistration.scanLayout("").count, 0)
  }

  func testTheWorksEmOnTheScan() {
    XCTAssertEqual(OverlayRegistration.scanEm("14.3246", width: 2820), 40.395, accuracy: 0.001)
    XCTAssertEqual(OverlayRegistration.scanEm("", width: 2820), 0)
    XCTAssertEqual(OverlayRegistration.scanEm("14.3246", width: 0), 0)
  }

  /// The scan's bookplate laid through the registration: its top and
  /// bottom in the layer's pixels.
  private func bookplate(typeScale: Double) throws -> (top: Double, bottom: Double) {
    let box = OverlayRegistration.laid(Self.title, zone: Self.textBlock, size: Self.size, spans: false, typeScale: typeScale)
    let target = [box[0], box[1], box[2], box[1], box[2], box[3], box[0], box[3]]
    let corners = (0..<8).map { Self.textBlock[$0] / 1000 * ($0 % 2 == 0 ? Self.size.width : Self.size.height) }
    let map = try XCTUnwrap(Homography(from: corners, to: target))
    let ys = (0..<4).map {
      map.apply(x: Self.bookplate[2 * $0] / 1000 * Self.size.width, y: Self.bookplate[2 * $0 + 1] / 1000 * Self.size.height).y
    }
    return (ys.min() ?? 0, ys.max() ?? 0)
  }

  func testATitlePageSetTighterThanItsPrintIsLaidAtTheTypesScale() throws {
    // The block's height says 0.118 a pixel, the type 0.209: the type's.
    let box = OverlayRegistration.laid(Self.title, zone: Self.textBlock, size: Self.size, spans: false, typeScale: Self.typeScale)
    XCTAssertEqual(box[1], 445)
    XCTAssertEqual(box[3], 445 + 565.98 * Self.typeScale, accuracy: 0.01)
    XCTAssertEqual((box[0] + box[2]) / 2, 900, accuracy: 1e-9)
    XCTAssertEqual(box[2] - box[0], 2132.01 * Self.typeScale, accuracy: 0.01)
    // Its bookplate where the edition's starts (y 180), never in the blank.
    let laid = try bookplate(typeScale: Self.typeScale)
    XCTAssertEqual(laid.top, 188.4, accuracy: 0.5)
    XCTAssertEqual(laid.bottom, 268.3, accuracy: 0.5)
  }

  func testWithNoTypeScaleTheBlocksHeightLaysItAsBefore() throws {
    // The prod bug's picture: the bookplate at y 300–345.
    let box = OverlayRegistration.laid(Self.title, zone: Self.textBlock, size: Self.size, spans: false, typeScale: 0)
    XCTAssertEqual(box[1], 445)
    XCTAssertEqual(box[3], 512, accuracy: 1e-9)
    let laid = try bookplate(typeScale: 0)
    XCTAssertEqual(laid.top, 299.7, accuracy: 0.5)
    XCTAssertEqual(laid.bottom, 345.0, accuracy: 0.5)
  }

  /// A body page's block 2.1% taller than the type's scale gives (a
  /// scanner's stretch, a scale's rounding) is still laid at the type's
  /// scale: its height never sets it, so the difference shows.
  func testABodyPagesStretchIsLaidAtTheTypesScale() {
    let height = 565.98 * Self.typeScale * 1.021
    let box = [400.0, 445.0, 1400.0, 445 + height]
    let laid = OverlayRegistration.laid(box, zone: Self.textBlock, size: Self.size, spans: false, typeScale: Self.typeScale)
    XCTAssertEqual(laid[1], 445)
    XCTAssertEqual(laid[3], 445 + 565.98 * Self.typeScale, accuracy: 0.01)
    XCTAssertEqual(laid[2] - laid[0], 2132.01 * Self.typeScale, accuracy: 0.01)
  }

  /// A block spanning the frame's measure, its frame declared: at the
  /// type's scale too, from its top, centered—its width no more a measure
  /// of the scale than its height.
  func testASpanningBlockIsLaidAtTheTypesScale() {
    let width = 2132.01 * Self.typeScale * 1.021
    let box = [100.0, 50.0, 100 + width, 50 + 565.98 * Self.typeScale * 1.021]
    let laid = OverlayRegistration.laid(box, zone: Self.textBlock, size: Self.size, spans: true, typeScale: Self.typeScale)
    XCTAssertEqual(laid[1], 50)
    XCTAssertEqual(laid[3], 50 + 565.98 * Self.typeScale, accuracy: 0.01)
    XCTAssertEqual((laid[0] + laid[2]) / 2, 100 + width / 2, accuracy: 1e-9)
    XCTAssertEqual(laid[2] - laid[0], 2132.01 * Self.typeScale, accuracy: 0.01)
  }

  /// A left-set block is laid from its left edge, a right-set one from its
  /// right, whatever the edition face's widths ran its lines to (user,
  /// 2026-10-27: Hamlet Q1's verse, its lines 11% wider than the print's
  /// before the fit, stood every start half the overrun right, centered).
  func testALeftSetBlockIsLaidFromItsLeftEdge() {
    let width = 2132.01 * Self.typeScale
    let box = [100.0, 50.0, 100 + width * 1.11, 200.0]
    let left = OverlayRegistration.laid(
      box, zone: Self.textBlock, size: Self.size, spans: false, typeScale: Self.typeScale, anchor: .left)
    XCTAssertEqual(left[0], 100)
    XCTAssertEqual(left[2] - left[0], width, accuracy: 0.01)
    let right = OverlayRegistration.laid(
      box, zone: Self.textBlock, size: Self.size, spans: false, typeScale: Self.typeScale, anchor: .right)
    XCTAssertEqual(right[2], box[2])
    XCTAssertEqual(OverlayRegistration.anchor([.left, .left, .center, .justified, .left]), .left)
    XCTAssertEqual(OverlayRegistration.anchor([.right, .right, .center]), .right)
    XCTAssertEqual(OverlayRegistration.anchor([.left, .center, .center, .justified]), .center)
  }

  /// With no frame declared, a spanning block is laid by its width, from
  /// its left, at one scale both ways: the image never stretched (user,
  /// 2026-10-28).
  func testWithNoFrameASpanningBlockIsLaidByItsWidth() {
    let box = [100.0, 50.0, 526.4, 163.2]
    let laid = OverlayRegistration.laid(box, zone: Self.textBlock, size: Self.size, spans: true, typeScale: 0)
    XCTAssertEqual(Array(laid[0..<3]), Array(box[0..<3]))
    XCTAssertEqual(laid[3], 163.2, accuracy: 0.01)
  }

  /// The title's "OF THE" on prod madrigal dd5cc0b2's page 3 (2026-10-18),
  /// letter-spaced, a zone a letter: its `<w>`s name `p3-wz27 p3-wz28
  /// p3-wz29` and `p3-wz30`–`p3-wz33`, on one scan line; and a word broken
  /// over two lines (`p3-wz26`, the line before, and `p3-wz34`).
  static let titleLayout =
    "block main - 141.21 385.12 897.24 386.72 897.16 408.67 141.13 407.07;"
    + "line - - 141.21 385.12 897.24 386.72 897.16 408.67 141.13 407.07 141.13 406.49 897.16 408.09;"
    + "word - p3-wz26 746.18 386.4 897.24 386.72 897.16 408.67 746.1 408.35;"
    + "block main - 484.57 455.14 553.36 455.28 553.33 463.22 484.54 463.07;"
    + "line - - 484.57 455.14 553.36 455.28 553.33 463.22 484.54 463.07 484.54 462.96 553.33 463.11;"
    + "word - p3-wz27 484.57 455.14 488.47 455.15 488.44 463.08 484.54 463.07;"
    + "word - p3-wz28 492.01 455.15 494.5 455.16 494.47 463.09 491.98 463.09;"
    + "word - p3-wz29 496.98 455.16 505.49 455.18 505.46 463.12 496.95 463.1;"
    + "word - p3-wz30 519.67 455.21 529.25 455.23 529.22 463.17 519.64 463.15;"
    + "word - p3-wz31 531.73 455.24 534.92 455.24 534.89 463.18 531.7 463.17;"
    + "word - p3-wz32 538.47 455.25 541.66 455.26 541.63 463.19 538.44 463.19;"
    + "word - p3-wz33 544.85 455.27 553.36 455.28 553.33 463.22 544.82 463.2;"
    + "block main - 283.28 513.43 755.27 514.43 755.18 536.11 283.2 535.11;"
    + "line - - 283.28 513.43 755.27 514.43 755.18 536.11 283.2 535.11 283.2 534.66 755.19 535.66;"
    + "word - p3-wz34 283.28 513.43 418.39 513.71 418.3 535.4 283.2 535.11"

  /// A word whose `@facs` names several zones on one scan line is one box,
  /// their union, never its letters apart (user, 2026-10-18).
  func testALetterSpacedWordIsOneBoxTheUnionOfItsZones() {
    let zones = OverlayRegistration.wordZones(OverlayRegistration.scanLayout(Self.titleLayout))
    XCTAssertEqual(zones.map(\.line), [0, 1, 1, 1, 1, 1, 1, 1, 2])
    let of = OverlayRegistration.wordBoxes(["p3-wz27", "p3-wz28", "p3-wz29"], in: zones)
    XCTAssertEqual(of.count, 1)
    XCTAssertEqual(of[0], [484.54, 455.14, 505.49, 463.12])
    let the = OverlayRegistration.wordBoxes(["p3-wz30", "p3-wz31", "p3-wz32", "p3-wz33"], in: zones)
    XCTAssertEqual(the, [[519.64, 455.21, 553.36, 463.22]])
  }

  /// A word whose zones stand on two scan lines (broken over them) is a
  /// box a line, in reading order; a zone the layout lacks is left out.
  func testAWordBrokenOverLinesIsABoxALine() {
    let zones = OverlayRegistration.wordZones(OverlayRegistration.scanLayout(Self.titleLayout))
    XCTAssertEqual(
      OverlayRegistration.wordBoxes(["p3-wz26", "p3-wz34", "p3-wz99"], in: zones),
      [[746.1, 386.4, 897.24, 408.67], [283.2, 513.43, 418.39, 535.4]])
    XCTAssertEqual(OverlayRegistration.wordBoxes(["p3-wz99"], in: zones), [])
  }

  /// Hamlet Q1 p. 4 (user, 2026-10-28): the edition stood half a leading
  /// and more below its scan, more so down the page; one pairing's median
  /// laid the scan the wrong way and paired every line with the next. The
  /// scan is laid where its rows pair at least cost: each with its own.
  /// gnorium-python `test_the_scan_is_laid_down_where_its_lines_pair_at_least_cost_never_a_row_off`.
  func testTheScanIsLaidDownWhereItsRowsPairAtLeastCostNeverARowOff() {
    let leading = 20.0
    let scan = (0..<36).map { n in StructureRow(left: 10, top: 20 * Double(n), right: 30, bottom: 20 * Double(n) + 10) }
    let edition = (0..<36).map { n in
      StructureRow(
        left: 10, top: 20 * Double(n) + 9.4 + 0.13 * Double(n), right: 30, bottom: 20 * Double(n) + 19.4 + 0.13 * Double(n))
    }
    let first = OverlayRegistration.baselineShift(
      StructurePairing.pair(edition: edition, scan: scan, leading: leading), edition: edition, scan: scan)
    XCTAssertLessThan(first, 0, "the median of the first pairing lays the scan the wrong way")
    let laid = OverlayRegistration.registrationDown(edition: edition, scan: scan, leading: leading)
    XCTAssertGreaterThan(laid.down, 9.4)
    XCTAssertLessThan(laid.down, 14)
    var pairs: [[Int]] = []
    for match in laid.matches { if case .pair(let e, let s, _) = match { pairs.append([e, s]) } }
    XCTAssertEqual(pairs, (0..<36).map { [$0, $0] })
    XCTAssertEqual(
      OverlayRegistration.registrationDown(edition: Array(edition[0..<2]), scan: Array(scan[0..<2]), leading: leading).down, 0)
  }
}
