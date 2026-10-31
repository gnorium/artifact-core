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
    guard case .actualSize? = ViewerZoom.command(forKey: "0") else { return XCTFail("0 sets the actual size") }
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

  // MARK: - The zoom kept across images (user, 2026-10-30)

  func testTheScaleIsTheZoomOverTheFit() {
    var surface = surface()
    XCTAssertEqual(surface.scale, 1, accuracy: 1e-12, "at the fit")
    surface.zoom(to: 1, aboutX: 250, y: 200)
    XCTAssertEqual(surface.scale, 2, accuracy: 1e-12, "the actual size over a fit of 0.5")
    XCTAssertEqual(surface.scale, surface.region?.scale ?? 0, accuracy: 1e-12, "the same scale a region carries")
    XCTAssertEqual(ViewerZoom.Surface().scale, 1, accuracy: 1e-12, "no fit yet: at it")
  }

  func testLaidAtAScaleTheNextImageKeepsTheZoomOverItsOwnFit() {
    // A landscape page zoomed to 1.5 times its fit, then a portrait page
    // of another resolution laid at the kept scale: 1.5 times its own fit,
    // not the same pixels per image pixel.
    var landscape = surface()
    landscape.zoom(to: 0.75, aboutX: 100, y: 100)
    let kept = landscape.scale
    XCTAssertEqual(kept, 1.5, accuracy: 1e-12)
    var portrait = ViewerZoom.Surface()
    portrait.imageWidth = 800
    portrait.imageHeight = 1200
    let fit = ViewerZoom.Surface.fit(imageWidth: 800, imageHeight: 1200, viewportWidth: 500, viewportHeight: 400)
    XCTAssertEqual(fit, 400.0 / 1200.0, accuracy: 1e-12)
    portrait.lay(viewportWidth: 500, viewportHeight: 400, fit: fit, scale: kept)
    XCTAssertEqual(portrait.scale, 1.5, accuracy: 1e-9)
    XCTAssertEqual(portrait.zoom, fit * 1.5, accuracy: 1e-9)
    XCTAssertNotEqual(portrait.zoom, landscape.zoom, "a zoom over the fit, not an absolute one")
    XCTAssertFalse(portrait.atFit)
    // Centered: narrower than the surface, it stands in the middle across;
    // taller, its middle at the surface's.
    XCTAssertEqual(portrait.panX, (500 - 800 * portrait.zoom) / 2, accuracy: 1e-9)
    XCTAssertEqual(portrait.panY, (400 - 1200 * portrait.zoom) / 2, accuracy: 1e-9)
    // And where the kept pan would leave a gap, none: centered is inside.
    var clamped = portrait
    clamped.clampPan()
    XCTAssertEqual(clamped.panX, portrait.panX, accuracy: 1e-9)
    XCTAssertEqual(clamped.panY, portrait.panY, accuracy: 1e-9)
  }

  func testAScaleAtOrUnderTheFitLaysItAtTheFitAndOneTooLargeAtTheActualSize() {
    var atFit = ViewerZoom.Surface()
    atFit.imageWidth = 1000
    atFit.imageHeight = 800
    atFit.lay(viewportWidth: 500, viewportHeight: 400, fit: 0.5, scale: 0.4)
    XCTAssertEqual(atFit.zoom, 0.5, accuracy: 1e-12, "never below the fit")
    XCTAssertTrue(atFit.atFit)
    atFit.lay(viewportWidth: 500, viewportHeight: 400, fit: 0.5, scale: 1)
    XCTAssertTrue(atFit.atFit, "a scale of 1 is the fit")
    atFit.lay(viewportWidth: 500, viewportHeight: 400, fit: 0.5, scale: nil)
    XCTAssertTrue(atFit.atFit, "none kept: the fit")
    var past = ViewerZoom.Surface()
    past.imageWidth = 1000
    past.imageHeight = 800
    past.lay(viewportWidth: 500, viewportHeight: 400, fit: 0.5, scale: 10)
    XCTAssertEqual(past.zoom, 1, accuracy: 1e-12, "no further than the actual size")
    XCTAssertFalse(past.atFit)
    XCTAssertEqual(past.scale, 2, accuracy: 1e-12)
  }

  func testAFitLargerThanTheActualSizeTakesAnyScaleToTheFit() {
    // A small image in a large surface: its fit is past its actual size, so
    // the fit is all the zoom it has, whatever scale was kept.
    var small = ViewerZoom.Surface()
    small.imageWidth = 400
    small.imageHeight = 300
    small.lay(viewportWidth: 1000, viewportHeight: 750, fit: 2.5, scale: 1.5)
    XCTAssertEqual(small.zoom, 2.5, accuracy: 1e-12)
    XCTAssertTrue(small.atFit)
    XCTAssertEqual(small.scale, 1, accuracy: 1e-12)
  }

  func testASurfaceWithAnOutReachZoomsOutPastItsFitAndStopsAtTheFitOnTheWay() {
    // The scan (user, 2026-10-31): out past its fit to half of it, the
    // whole photograph in margins; it opens at its fit.
    var scan = ViewerZoom.Surface()
    scan.outReach = 0.5
    scan.imageWidth = 1000
    scan.imageHeight = 800
    scan.lay(
      viewportWidth: 500, viewportHeight: 400,
      fit: ViewerZoom.Surface.fit(imageWidth: 1000, imageHeight: 800, viewportWidth: 500, viewportHeight: 400))
    XCTAssertEqual(scan.zoom, 0.5, accuracy: 1e-12, "it opens at its fit")
    XCTAssertTrue(scan.atFit)
    scan.zoom(to: 0.8, aboutX: 250, y: 200)
    // Zoomed out from above the fit, it stops at the fit first.
    scan.zoom(to: 0.3, aboutX: 250, y: 200)
    XCTAssertEqual(scan.zoom, 0.5, accuracy: 1e-12)
    XCTAssertTrue(scan.atFit)
    scan.zoom(to: 0.01, aboutX: 250, y: 200)
    XCTAssertEqual(scan.zoom, 0.25, accuracy: 1e-12, "half its fit, no further")
    XCTAssertFalse(scan.atFit)
    XCTAssertEqual(scan.scale, 0.5, accuracy: 1e-12)
    // Smaller than its surface, it stands centered in margins.
    XCTAssertEqual(scan.panX, (500 - 250) / 2, accuracy: 1e-9)
    XCTAssertEqual(scan.panY, (400 - 200) / 2, accuracy: 1e-9)
    // Zoomed in from below, it stops at the fit again.
    scan.zoom(to: 2, aboutX: 250, y: 200)
    XCTAssertEqual(scan.zoom, 0.5, accuracy: 1e-12)
    XCTAssertTrue(scan.atFit)
    // A kept scale under 1 lays the next image under its own fit, and a
    // resize keeps it.
    scan.lay(viewportWidth: 500, viewportHeight: 400, fit: 0.5, scale: 0.6)
    XCTAssertEqual(scan.zoom, 0.3, accuracy: 1e-12)
    XCTAssertFalse(scan.atFit)
    scan.resize(viewportWidth: 1000, viewportHeight: 800, fit: 1)
    XCTAssertEqual(scan.scale, 0.6, accuracy: 1e-9)
  }

  func testASurfaceWithNoOutReachNeverGoesUnderItsFit() {
    var surface = surface()
    XCTAssertEqual(surface.leastZoom, surface.minZoom, accuracy: 1e-12)
    surface.zoom(to: 0.1, aboutX: 250, y: 200)
    XCTAssertEqual(surface.zoom, 0.5, accuracy: 1e-12)
    XCTAssertTrue(surface.atFit)
  }

  func testALayoutFloorIsNeverPastItsValueAndWithinA64th() {
    // Hamlet Q1's title page at its fit, its pane 470.719 high inside.
    let room = 470.719
    let laid = ViewerZoom.layoutFloor(room)
    XCTAssertLessThanOrEqual(laid, room)
    XCTAssertLessThan(room - laid, 1.0 / 64)
    XCTAssertEqual(laid * 64, (laid * 64).rounded(), accuracy: 1e-9, "a whole number of 64ths")
    XCTAssertEqual(ViewerZoom.layoutFloor(456), 456, accuracy: 1e-12)
  }
}
