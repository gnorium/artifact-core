import DOMBuilder
import HTMLBuilder
import WebTypes
import XCTest

@testable import ArtifactCore

/// The Header switch is the artifact's own, never tied to its XML switch
/// (user, 2026-10-21): offered wherever there is a header, enabled, off at
/// first, after the XML switch where there is one; the header as code in a
/// pane of its own at the top of the markup's column, the markup's pane
/// apart from it; with no markup (a calibrated, not yet explicated
/// testament) there is no XML switch, and the header's column stands beside
/// the images alone.
final class ArtifactHeaderTests: XCTestCase {
  static let header = """
    <teiHeader><encodingDesc><tagsDecl>
    <rendition xml:id="size-1" scheme="css">font-size:0.8251rem</rendition>
    </tagsDecl></encodingDesc></teiHeader>
    """

  private func elements(in node: DOM.Node) -> [DOM.Element] {
    guard let element = node as? DOM.Element else { return [] }
    return [element] + element.children.flatMap { elements(in: $0) }
  }

  private func classes(_ element: DOM.Element) -> [Substring] {
    element.attributes.first { $0.0 == "class" }.map { $0.1.split(separator: " ") } ?? []
  }

  private func attribute(_ element: DOM.Element, _ name: String) -> String? {
    element.attributes.first { $0.0 == name }?.1
  }

  private func first(_ name: String, in node: DOM.Node) -> DOM.Element? {
    elements(in: node).first { classes($0).contains(Substring(name)) }
  }

  private func withMarkup(header: String?) -> DOM.Node {
    ArtifactView(rawSwitch: true, header: header) {
      div { "Page" }.data("service-id", "https://h/i1")
    } canvas: {
      div {}.data("service-id", "https://h/i1")
    }.build()
  }

  private func imagesAlone(header: String?) -> DOM.Node {
    ArtifactView(
      manifestURL: "/testaments/manifest?url=x", rawSwitch: true, header: header,
      canvas: { div {}.data("service-id", "https://h/i1") }
    ).build()
  }

  func testTheHeaderSwitchStandsAfterTheXMLSwitchEnabledAndOff() throws {
    let node = withMarkup(header: Self.header)
    let root = try XCTUnwrap(node as? DOM.Element)
    XCTAssertEqual(attribute(root, "data-header"), "false")
    let start = try XCTUnwrap(first("artifact-footer-start", in: node))
    let switches = start.children.compactMap { $0 as? DOM.Element }
    let xml = try XCTUnwrap(switches.firstIndex { classes($0).contains("artifact-xml-toggle") })
    let header = try XCTUnwrap(switches.firstIndex { classes($0).contains("artifact-header-toggle") })
    XCTAssertEqual(header, xml + 1, "the Header switch is not right after the XML switch")
    let button = try XCTUnwrap(elements(in: switches[header]).first { $0.tag == "button" })
    XCTAssertNil(attribute(button, "disabled"), "the Header switch is drawn disabled")
    XCTAssertNotEqual(attribute(button, "aria-pressed"), "true")
  }

  func testTheHeaderIsAPaneOfItsOwnOverTheMarkup() throws {
    let node = withMarkup(header: Self.header)
    let frame = try XCTUnwrap(first("artifact-markup-frame", in: node))
    XCTAssertEqual(attribute(frame, "data-header-only"), "false")
    let parts = frame.children.compactMap { $0 as? DOM.Element }
    let top = try XCTUnwrap(parts.first)
    XCTAssertTrue(classes(top).contains("artifact-document-header"), "the header is not at the column's top")
    XCTAssertTrue(parts.dropFirst().contains { classes($0).contains("artifact-markup-box") })
    let pane = try XCTUnwrap(first("artifact-document-header", in: node))
    XCTAssertTrue(pane.render().contains("teiHeader"))
    XCTAssertNotNil(first("code-view", in: pane), "the header is not code")
    XCTAssertFalse(pane.render().contains("contenteditable"), "the header can be edited")
    let markup = try XCTUnwrap(first("artifact-markup", in: node))
    XCTAssertFalse(markup.render().contains("teiHeader"), "the markup's pane holds the header")
  }

  func testWithNoMarkupTheHeaderStandsBesideTheImagesAlone() throws {
    let node = imagesAlone(header: Self.header)
    XCTAssertNil(first("artifact-xml-toggle", in: node), "an XML switch with no markup")
    XCTAssertNotNil(first("artifact-header-toggle", in: node))
    let frame = try XCTUnwrap(first("artifact-markup-frame", in: node))
    XCTAssertEqual(attribute(frame, "data-header-only"), "true")
    XCTAssertNotNil(first("artifact-document-header", in: frame))
    XCTAssertNil(first("artifact-markup", in: node), "a markup pane with no markup")
    XCTAssertNotNil(first("artifact-object", in: node))
  }

  func testNoHeaderNoSwitchNoPane() {
    for node in [withMarkup(header: nil), imagesAlone(header: nil)] {
      XCTAssertNil(first("artifact-header-toggle", in: node))
      XCTAssertNil(first("artifact-document-header", in: node))
    }
    XCTAssertNil(first("artifact-markup-frame", in: imagesAlone(header: nil)), "a column with nothing in it")
  }
}
