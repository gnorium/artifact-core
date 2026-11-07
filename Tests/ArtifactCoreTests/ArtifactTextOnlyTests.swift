import DOMBuilder
import HTMLBuilder
import WebTypes
import XCTest

@testable import ArtifactCore

/// A viewer that holds text alone (user, 2026-11-01: a quote with no source
/// images) shows only what text alone needs, driven by what it has: XML (its
/// page's code, user 2026-11-02) and Reflow at the footer's start,
/// fullscreen at its end, no pager for its one page, no Header switch (its
/// header is the host's, written for it); a printed page number names a page
/// with no image.
final class ArtifactTextOnlyTests: XCTestCase {
  private func elements(in node: DOM.Node) -> [DOM.Element] {
    guard let element = node as? DOM.Element else { return [] }
    return [element] + element.children.flatMap { elements(in: $0) }
  }

  private func classes(_ element: DOM.Element) -> [Substring] {
    element.attributes.first { $0.0 == "class" }.map { $0.1.split(separator: " ") } ?? []
  }

  private func count(_ name: String, in node: DOM.Node) -> Int {
    elements(in: node).filter { classes($0).contains(Substring(name)) }.count
  }

  private func attribute(_ element: DOM.Element, _ name: String) -> String? {
    element.attributes.first { $0.0 == name }?.1
  }

  func testTextAloneShowsXMLReflowAndFullscreenOnly() throws {
    let node = ArtifactView(rawSwitch: true, header: "<teiHeader/>", canvasSwitch: true, pageCount: 1, printedPage: "37") {
      div { "A sentence." }.data("service-id", "")
    }.build()
    XCTAssertEqual(count("artifact-reflow-toggle", in: node), 1)
    XCTAssertEqual(count("artifact-fullscreen-button", in: node), 1)
    XCTAssertEqual(count("artifact-xml-toggle", in: node), 1)
    XCTAssertEqual(count("artifact-page-nav", in: node), 0)
    XCTAssertEqual(count("artifact-detach-toggle", in: node), 0)
    XCTAssertEqual(count("artifact-overlay-toggle", in: node), 0)
    XCTAssertEqual(count("artifact-canvas-toggle", in: node), 0)
    XCTAssertEqual(count("artifact-header-toggle", in: node), 0)
    let root = try XCTUnwrap(node as? DOM.Element)
    XCTAssertEqual(attribute(root, "data-printed-page"), "37")
  }

  func testTextOnSeveralPagesKeepsItsPager() {
    let node = ArtifactView(rawSwitch: true, pageCount: 2) {
      div { "One." }.data("service-id", "")
      div { "Two." }.data("service-id", "")
    }.build()
    XCTAssertEqual(count("artifact-page-nav", in: node), 1)
    XCTAssertEqual(count("artifact-xml-toggle", in: node), 1)
  }

  func testTextBesideFramesKeepsItsChrome() {
    let node = ArtifactView(manifestURL: "/testaments/manifest?url=x", rawSwitch: true, pageCount: 1) {
      div { "Page" }.data("service-id", "https://h/i1")
    } canvas: {
      div {}.data("service-id", "https://h/i1")
    }.build()
    XCTAssertEqual(count("artifact-xml-toggle", in: node), 1)
    XCTAssertEqual(count("artifact-page-nav", in: node), 1)
    XCTAssertEqual(count("artifact-reflow-toggle", in: node), 1)
  }

  /// Text that follows the frame on screen, a quote typed against a Source
  /// URL's frames (user, 2026-11-05), traces none of them: XML, Reflow, the
  /// pager, fullscreen and the Frame switch, never Detach or Overlay. A
  /// page's own markup beside its frame keeps both.
  func testTypedTextBesideFramesHasNoDetachOrOverlay() {
    for typed in [true, false] {
      let node = ArtifactView(
        manifestURL: "/testaments/manifest?url=x", rawSwitch: true, canvasSwitch: true, markupFollowsCanvas: true,
        typedText: typed
      ) {
        div { "Bought of Sir Henry Bunbury." }.data("service-id", "")
      }.build()
      XCTAssertEqual(count("artifact-xml-toggle", in: node), 1)
      XCTAssertEqual(count("artifact-reflow-toggle", in: node), 1)
      XCTAssertEqual(count("artifact-page-nav", in: node), 1)
      XCTAssertEqual(count("artifact-fullscreen-button", in: node), 1)
      XCTAssertEqual(count("artifact-canvas-toggle", in: node), 1)
      XCTAssertEqual(count("artifact-detach-toggle", in: node), 0, "typed: \(typed)")
      XCTAssertEqual(count("artifact-overlay-toggle", in: node), 0, "typed: \(typed)")
    }
    let traced = ArtifactView(manifestURL: "/testaments/manifest?url=x", rawSwitch: true, canvasSwitch: true, pageCount: 1) {
      div { "Page" }.data("service-id", "https://h/i1")
    } canvas: {
      div {}.data("service-id", "https://h/i1")
    }.build()
    XCTAssertEqual(count("artifact-detach-toggle", in: traced), 1)
    XCTAssertEqual(count("artifact-overlay-toggle", in: traced), 1)
  }
}
