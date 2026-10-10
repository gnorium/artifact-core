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
