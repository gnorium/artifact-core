import XCTest

@testable import ArtifactCore

/// The overlay's motion runs on CSS's `ease-in-out`, so the client's frames
/// and the panes' transition arrive together; its framing holds the
/// edition's page between its fit and the most zoom, centered where it is
/// smaller than the view and covering the view where it is larger (user,
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
    let framing = OverlayFraming(page: (400, 800), width: 1000, height: 400, most: 4)
    // Its height binds: 400 of view for 800 of page.
    XCTAssertEqual(framing.fit, 0.5, accuracy: 1e-9)
    let view = framing.fitted
    XCTAssertEqual(view.y, 0, accuracy: 1e-9)
    // Centered across: its 200 wide in the 1000.
    XCTAssertEqual(view.x, 400, accuracy: 1e-9)
  }

  func testZoomAndPanStayWithinThePage() {
    let framing = OverlayFraming(page: (400, 800), width: 1000, height: 400, most: 4)
    // No zoom out past the whole page, nor in past the most.
    XCTAssertEqual(framing.clamp(zoom: 0.1, x: 0, y: 0).zoom, framing.fit, accuracy: 1e-9)
    XCTAssertEqual(framing.clamp(zoom: 9, x: 0, y: 0).zoom, 4, accuracy: 1e-9)
    // Zoomed in, a pan far past an edge stops at the page's edge.
    let zoomed = framing.clamp(zoom: 4, x: 10_000, y: -10_000)
    XCTAssertEqual(zoomed.x, 0, accuracy: 1e-9)
    XCTAssertEqual(zoomed.y + 800 * 4, 400, accuracy: 1e-9)
  }
}
