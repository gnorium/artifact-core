import XCTest

@testable import ArtifactCore

/// The overlay's motion runs on CSS's `ease-in-out`, so the client's frames
/// and the panes' transition arrive together; its framing holds the
/// edition's whole page at its fit, centered, and still (user,
/// 2026-10-14).
final class OverlayMotionTests: XCTestCase {
  func testTheCurveIsEaseInOut() {
    XCTAssertEqual(OverlayMotion.eased(0), 0, accuracy: 1e-6)
    XCTAssertEqual(OverlayMotion.eased(1), 1, accuracy: 1e-6)
    XCTAssertEqual(OverlayMotion.eased(0.5), 0.5, accuracy: 1e-6)
    // Symmetric about its middle, slow at its ends.
    XCTAssertEqual(OverlayMotion.eased(0.25) + OverlayMotion.eased(0.75), 1, accuracy: 1e-6)
    XCTAssertLessThan(OverlayMotion.eased(0.1), 0.1)
    // The browser's ease-in-out at a quarter of its time.
    XCTAssertEqual(OverlayMotion.eased(0.25), 0.1292, accuracy: 1e-3)
  }

  func testThePageFitsTheViewCentered() {
    let framing = OverlayFraming(content: (0, 0, 400, 800), width: 1000, height: 400, actual: 1)
    // Its height binds: 400 of view for 800 of page.
    XCTAssertEqual(framing.fit, 0.5, accuracy: 1e-9)
    let view = framing.fitted
    XCTAssertEqual(view.y, 0, accuracy: 1e-9)
    // Centered across: its 200 wide in the 1000.
    XCTAssertEqual(view.x, 400, accuracy: 1e-9)
  }

  /// The scan reaching past the page is framed with it: the full image
  /// shows (user, 2026-10-14).
  func testTheScansReachIsFramedWithThePage() {
    let framing = OverlayFraming(content: (-100, -50, 500, 750), width: 600, height: 400, actual: 2)
    XCTAssertEqual(framing.fit, 0.5, accuracy: 1e-9)
    let view = framing.fitted
    // The content's left edge (−100 × 0.5) at 150: centered in 600.
    XCTAssertEqual(view.x - 100 * 0.5, 150, accuracy: 1e-9)
    XCTAssertEqual(view.y, 25, accuracy: 1e-9)
  }

  /// The reader's zoom and pan are held: never below the fit or past the
  /// actual size, and no edge of the content pulled in past the view's.
  func testTheReadersZoomAndPanAreHeldToTheContent() {
    let framing = OverlayFraming(content: (0, 0, 400, 800), width: 1000, height: 400, actual: 1.5)
    XCTAssertEqual(framing.held((0.1, 0, 0)).zoom, 0.5, accuracy: 1e-9)
    XCTAssertEqual(framing.held((9, 0, 0)).zoom, 1.5, accuracy: 1e-9)
    // At 1.5 the page is 600 × 1200: centered across, pinned down.
    let low = framing.held((1.5, 0, 500))
    XCTAssertEqual(low.x, 200, accuracy: 1e-9)
    XCTAssertEqual(low.y, 0, accuracy: 1e-9)
    XCTAssertEqual(framing.held((1.5, 0, -5000)).y, 400 - 1200, accuracy: 1e-9)
  }
}
