import XCTest

@testable import ArtifactCore

/// The overlay's homography and the explication's (gnorium-python's
/// `layout_measure.homography`, which lays the scan as the overlay does
/// to compare it with the render, user, 2026-10-14) are one math: both
/// are held to this fixed example, a skewed text block's corners on the
/// scan taken onto the rendered text block's, and give the same nine
/// entries (`test_the_registration_is_the_overlays_homography`).
final class HomographyTests: XCTestCase {
  static let source: [Double] = [100, 50, 900, 70, 880, 950, 90, 930]
  static let destination: [Double] = [40, 30, 600, 30, 600, 800, 40, 800]
  static let entries: [Double] = [
    0.6995846944803589, 0.0073823289640093485, -30.353089493822786,
    -0.02156040076828865, 0.8628471620559897, -11.005445724160449,
    7.137590247723512e-07, -1.4179316842768415e-05, 1.0,
  ]

  func testTheFixedExampleGivesTheSharedEntries() throws {
    let homography = try XCTUnwrap(Homography(from: Self.source, to: Self.destination))
    for (value, expected) in zip(homography.values, Self.entries) {
      XCTAssertEqual(value, expected, accuracy: 1e-9 * max(1, abs(expected)))
    }
  }

  func testTheCornersLandOnTheRenderedTextBlocks() throws {
    let homography = try XCTUnwrap(Homography(from: Self.source, to: Self.destination))
    for corner in 0..<4 {
      let point = homography.apply(x: Self.source[2 * corner], y: Self.source[2 * corner + 1])
      XCTAssertEqual(point.x, Self.destination[2 * corner], accuracy: 1e-9)
      XCTAssertEqual(point.y, Self.destination[2 * corner + 1], accuracy: 1e-9)
    }
    let center = homography.apply(x: 500, y: 500)
    XCTAssertEqual(center.x, 325.32073481035223, accuracy: 1e-9)
    XCTAssertEqual(center.y, 412.4146314520929, accuracy: 1e-9)
  }

  func testThreeCornersOnOneLineHaveNoHomography() {
    XCTAssertNil(Homography(from: [0, 0, 1, 1, 2, 2, 0, 5], to: Self.destination))
  }
}
