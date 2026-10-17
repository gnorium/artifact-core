import XCTest

@testable import ArtifactCore

/// The one model every image zoomed where it stands shares (user,
/// 2026-10-17): the artifact's canvases and the images a session shows as the
/// model received them. From the image's fit to its actual size, the wheel in
/// proportion to its travel, a zoom at the fit following its surface.
final class ViewerZoomTests: XCTestCase {
  /// 1000 by 800 pixels in a 500 by 400 surface: a fit of 0.5.
  private func surface(
    image: (Double, Double) = (1000, 800), viewport: (Double, Double) = (500, 400)
  ) -> ViewerZoom.Surface {
    var surface = ViewerZoom.Surface()
    surface.imageWidth = image.0
    surface.imageHeight = image.1
    surface.lay(
      viewportWidth: viewport.0, viewportHeight: viewport.1,
      fit: ViewerZoom.Surface.fit(
        imageWidth: image.0, imageHeight: image.1, viewportWidth: viewport.0, viewportHeight: viewport.1))
    return surface
  }

  func testTheWheelZoomsInProportionToItsTravelAndIsCapped() {
    XCTAssertEqual(ViewerZoom.wheelFactor(0), 1, accuracy: 1e-12)
    XCTAssertEqual(ViewerZoom.wheelFactor(-10), 1.05, accuracy: 1e-12)
    XCTAssertEqual(ViewerZoom.wheelFactor(10), 0.95, accuracy: 1e-12)
    // A notch of any size counts as 40 at most: 20% a step.
    XCTAssertEqual(ViewerZoom.wheelFactor(-40), 1.2, accuracy: 1e-12)
    XCTAssertEqual(ViewerZoom.wheelFactor(-4000), 1.2, accuracy: 1e-12)
    XCTAssertEqual(ViewerZoom.wheelFactor(4000), 0.8, accuracy: 1e-12)
  }

  func testTheKeysAreTheWheelsStepAndTravel() {
    XCTAssertEqual(ViewerZoom.command(forKey: "+")?.factor ?? 0, 1.2, accuracy: 1e-12)
    XCTAssertEqual(ViewerZoom.command(forKey: "=")?.factor ?? 0, 1.2, accuracy: 1e-12)
    XCTAssertEqual(ViewerZoom.command(forKey: "-")?.factor ?? 0, 0.8, accuracy: 1e-12)
    guard case .fit? = ViewerZoom.command(forKey: "0") else { return XCTFail("0 fits the image") }
    guard case .pan(let x, let y)? = ViewerZoom.command(forKey: "ArrowLeft") else {
      return XCTFail("the arrows pan")
    }
    XCTAssertEqual(x, 40)
    XCTAssertEqual(y, 0)
    guard case .pan(_, let down)? = ViewerZoom.command(forKey: "ArrowDown") else {
      return XCTFail("the arrows pan")
    }
    XCTAssertEqual(down, -40)
    XCTAssertNil(ViewerZoom.command(forKey: "Escape"))
    XCTAssertNil(ViewerZoom.command(forKey: "a"))
  }

  func testItZoomsFromTheFitToTheActualSizeAndNoFurther() {
    var surface = surface()
    XCTAssertEqual(surface.minZoom, 0.5, accuracy: 1e-12)
    XCTAssertEqual(surface.zoom, 0.5, accuracy: 1e-12)
    XCTAssertTrue(surface.atFit)
    XCTAssertTrue(surface.canZoom)
    surface.zoom(to: 40, aboutX: 250, y: 200)
    XCTAssertEqual(surface.zoom, 1, accuracy: 1e-12, "one image pixel to one CSS pixel")
    XCTAssertFalse(surface.atFit)
    surface.zoom(to: 0.01, aboutX: 250, y: 200)
    XCTAssertEqual(surface.zoom, 0.5, accuracy: 1e-12)
    XCTAssertTrue(surface.atFit)
  }

  func testAnImageAlreadyAtItsActualSizeHasNoZoomIn() {
    var surface = surface(image: (400, 300), viewport: (500, 400))
    // 400 wide in 500: its fit is 1.
    XCTAssertEqual(surface.minZoom, 1.25, accuracy: 1e-12, "the fit is the surface's, not the page's")
    var exact = ViewerZoom.Surface()
    exact.imageWidth = 400
    exact.imageHeight = 300
    exact.lay(viewportWidth: 400, viewportHeight: 300, fit: 1)
    XCTAssertFalse(exact.canZoom)
    exact.zoom(to: 3, aboutX: 200, y: 150)
    XCTAssertEqual(exact.zoom, 1, accuracy: 1e-12)
    // A fit larger than the actual size is the most it zooms to, too.
    XCTAssertFalse(surface.canZoom)
    surface.zoom(to: 9, aboutX: 250, y: 200)
    XCTAssertEqual(surface.zoom, 1.25, accuracy: 1e-12)
  }

  func testAZoomKeepsTheImagePointUnderThePointer() {
    var surface = surface()
    // The image point under (125, 100) before and after.
    func imagePoint(_ s: ViewerZoom.Surface, _ x: Double, _ y: Double) -> (Double, Double) {
      ((x - s.panX) / s.zoom, (y - s.panY) / s.zoom)
    }
    let before = imagePoint(surface, 125, 100)
    surface.zoom(to: 0.8, aboutX: 125, y: 100)
    let after = imagePoint(surface, 125, 100)
    XCTAssertEqual(before.0, after.0, accuracy: 1e-9)
    XCTAssertEqual(before.1, after.1, accuracy: 1e-9)
  }

  func testItCanNeverBePannedFullyOutOfTheSurface() {
    var surface = surface()
    surface.zoom(to: 1, aboutX: 250, y: 200)
    // Larger than the surface: it covers it, at every extreme.
    surface.pan(by: 100_000, 100_000)
    XCTAssertEqual(surface.panX, 0, accuracy: 1e-9)
    XCTAssertEqual(surface.panY, 0, accuracy: 1e-9)
    surface.pan(by: -100_000, -100_000)
    XCTAssertEqual(surface.panX, 500 - 1000, accuracy: 1e-9)
    XCTAssertEqual(surface.panY, 400 - 800, accuracy: 1e-9)
    // Smaller than the surface across: centered, no panning there.
    var narrow = self.surface(image: (200, 800), viewport: (500, 400))
    narrow.zoom(to: 1, aboutX: 250, y: 200)
    narrow.pan(by: 300, 0)
    XCTAssertEqual(narrow.panX, (500 - 200) / 2, accuracy: 1e-9)
  }

  func testAtItsFitItFollowsTheSurfaceAndZoomedItKeepsWhatItShows() {
    var surface = surface()
    // At the fit, the new fit.
    surface.resize(viewportWidth: 250, viewportHeight: 200, fit: 0.25)
    XCTAssertEqual(surface.zoom, 0.25, accuracy: 1e-12)
    XCTAssertTrue(surface.atFit)
    XCTAssertEqual(surface.panX, 0, accuracy: 1e-9)

    // Zoomed: the same zoom over the fit and the same point at the middle.
    var zoomed = self.surface()
    zoomed.zoom(to: 0.75, aboutX: 100, y: 100)
    let kept = zoomed.region
    XCTAssertNotNil(kept)
    zoomed.resize(viewportWidth: 400, viewportHeight: 320, fit: 0.4)
    XCTAssertFalse(zoomed.atFit, "a zoom is kept, not reset to the fit")
    XCTAssertEqual(zoomed.zoom, 0.4 * 1.5, accuracy: 1e-9, "1.5 times the fit before and after")
    let now = zoomed.region
    XCTAssertEqual(now?.centerX ?? 0, kept?.centerX ?? 1, accuracy: 1e-9)
    XCTAssertEqual(now?.centerY ?? 0, kept?.centerY ?? 1, accuracy: 1e-9)
  }

  func testAKeptZoomIsClampedWhenTheFitGrowsPastIt() {
    var zoomed = surface()
    zoomed.zoom(to: 1, aboutX: 250, y: 200)
    // The surface grows until the whole image fits at its actual size.
    zoomed.resize(viewportWidth: 1000, viewportHeight: 800, fit: 1)
    XCTAssertEqual(zoomed.zoom, 1, accuracy: 1e-12)
    XCTAssertTrue(zoomed.atFit)
    XCTAssertFalse(zoomed.canZoom)
  }

  func testARegionRoundTripsThroughTheSurface() {
    var surface = surface()
    surface.zoom(to: 0.9, aboutX: 400, y: 100)
    guard let region = surface.region else { return XCTFail("a region once it has a size") }
    var other = self.surface()
    other.show(region: region)
    XCTAssertEqual(other.zoom, surface.zoom, accuracy: 1e-9)
    XCTAssertEqual(other.panX, surface.panX, accuracy: 1e-6)
    XCTAssertEqual(other.panY, surface.panY, accuracy: 1e-6)
    XCTAssertEqual(region.maxScale, 2, accuracy: 1e-12, "the actual size over a fit of 0.5")
  }

  func testWithNoImageThereIsNoRegionAndNoRoom() {
    let surface = ViewerZoom.Surface()
    XCTAssertNil(surface.region)
    XCTAssertFalse(surface.canZoom)
  }
}
