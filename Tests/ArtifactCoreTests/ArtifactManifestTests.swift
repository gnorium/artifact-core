import DOMBuilder
import HTMLBuilder
import WebTypes
import XCTest

@testable import ArtifactCore

/// The images switch is never offered for an image not confirmed (user,
/// 2026-10-10): drawn hidden, shown once a manifest names an image, kept
/// hidden while it is unread (and asked for again), and for good where it
/// names none.
final class ArtifactManifestTests: XCTestCase {
  func testAManifestThatNamesAnImageConfirmsTheSwitch() {
    let manifest = ArtifactManifest.parse(
      #"{"canvases":[{"h":600,"id":"https://h/i1","l":"p. 1","w":400},{"h":600,"id":"https://h/i2","l":"p. 2","w":400}],"label":"Lear"}"#)
    XCTAssertEqual(manifest.pages.map(\.serviceID), ["https://h/i1", "https://h/i2"])
    XCTAssertEqual(manifest.pages.first?.label, "p. 1")
    XCTAssertFalse(manifest.unread)
    XCTAssertEqual(manifest.canvasSwitch, .confirmed)
  }

  func testAnUnreadManifestKeepsTheSwitchPending() {
    XCTAssertEqual(ArtifactManifest.parse(nil).canvasSwitch, .pending)
    let timedOut = ArtifactManifest.parse(#"{"canvases":[],"error":"The source URL took too long.","unread":true}"#)
    XCTAssertEqual(timedOut.canvasSwitch, .pending)
    XCTAssertEqual(timedOut.error, "The source URL took too long.")
    XCTAssertFalse(ArtifactManifest.retryDelays.isEmpty)
    XCTAssertEqual(ArtifactManifest.parse(#"{"error":"Network error"}"#).canvasSwitch, .pending)
    XCTAssertEqual(ArtifactManifest.parse("null").canvasSwitch, .pending)
    XCTAssertEqual(ArtifactManifest.parse("").canvasSwitch, .pending)
    XCTAssertEqual(ArtifactManifest.retryDelay(after: 20), 30000)
  }

  /// A page changed at its source whose image that was sent isn't archived
  /// is shown with no image (user, 2026-10-17), its size kept; an archived
  /// copy is shown in place of the service; the rest read their service.
  func testAPageShownBlankKeepsItsSizeAndNamesNoImage() {
    let manifest = ArtifactManifest.parse(
      #"{"canvases":[{"h":600,"id":"https://h/i1","l":"p. 1","w":400},{"blank":true,"h":600,"id":"https://h/i2","l":"p. 2","w":400},{"h":600,"id":"https://h/i3","imgs":["https://web.archive.org/web/20261016154929id_/https://h/i3/full/max/0/default.jpg"],"l":"p. 3","live":false,"w":400}],"label":"Lear"}"#)
    XCTAssertEqual(manifest.pages.map(\.blank), [false, true, false])
    XCTAssertEqual(
      manifest.pages.map(\.images), [[], [], ["https://web.archive.org/web/20261016154929id_/https://h/i3/full/max/0/default.jpg"]])
    XCTAssertEqual(manifest.pages[1].width, 400)
    XCTAssertEqual(manifest.pages[1].height, 600)
    XCTAssertEqual(manifest.canvasSwitch, .confirmed)
  }

  /// A changed page's copies of what was sent, in the order the reader tries
  /// them—archived copies only: Gnorium keeps none of its own—and never its
  /// service where none loads (`"live":false`, user, 2026-10-17); a page
  /// unchanged, or a plain image with no such word, may fall back to its
  /// service.
  func testAChangedPageListsItsCopiesInOrderAndRefusesItsService() {
    let manifest = ArtifactManifest.parse(
      #"{"canvases":[{"h":600,"id":"https://h/i1","imgs":["https://web.archive.org/web/20261016154929id_/https://h/i1/full/max/0/default.jpg","https://web.archive.org/web/20261011000000id_/https://h/i1/full/!1300,1300/0/default.jpg"],"l":"p. 1","live":false,"w":400},{"h":600,"id":"https://h/i2","l":"p. 2","w":400},{"h":600,"id":"/scan","imgs":["/scan.svg"],"w":400}],"label":"Lear"}"#)
    XCTAssertEqual(manifest.pages.map(\.serviceID), ["https://h/i1", "https://h/i2", "/scan"])
    XCTAssertEqual(
      manifest.pages[0].images,
      [
        "https://web.archive.org/web/20261016154929id_/https://h/i1/full/max/0/default.jpg",
        "https://web.archive.org/web/20261011000000id_/https://h/i1/full/!1300,1300/0/default.jpg",
      ])
    XCTAssertEqual(manifest.pages.map(\.live), [false, true, true])
    XCTAssertEqual(manifest.pages[1].images, [])
    XCTAssertEqual(manifest.pages[2].images, ["/scan.svg"])
    XCTAssertEqual(manifest.pages.map(\.blank), [false, false, false])
  }

  func testAManifestThatNamesNoImageDropsTheSwitch() {
    XCTAssertEqual(ArtifactManifest.parse(#"{"canvases":[],"error":"The source URL can't be read."}"#).canvasSwitch, .none)
    XCTAssertEqual(ArtifactManifest.parse(#"{"canvases":[{"h":0,"id":"https://h/i1","l":"","w":0}]}"#).canvasSwitch, .none)
  }

  private func elements(in node: DOM.Node) -> [DOM.Element] {
    guard let element = node as? DOM.Element else { return [] }
    return [element] + element.children.flatMap { elements(in: $0) }
  }

  func testTheServerDrawsTheSwitchUnconfirmed() throws {
    let node = ArtifactView(manifestURL: "/testaments/manifest?url=x", canvasSwitch: true) {
      div {}.data("service-id", "https://h/i1")
    } canvas: {
      div {}.data("service-id", "https://h/i1")
    }.build()
    let root = try XCTUnwrap(node as? DOM.Element)
    XCTAssertTrue(root.attributes.contains { $0.0 == "data-canvas-confirmed" && $0.1 == "false" })
    XCTAssertTrue(
      elements(in: node).contains { element in
        element.attributes.contains { $0.0 == "class" && $0.1.split(separator: " ").contains("artifact-canvas-toggle") }
      })
  }
}

extension ArtifactManifest.CanvasSwitch: Equatable {}
