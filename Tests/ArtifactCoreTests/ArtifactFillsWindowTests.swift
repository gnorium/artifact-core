import DOMBuilder
import HTMLBuilder
import WebTypes
import XCTest

@testable import ArtifactCore

/// The reader filling the window where full screen is refused (user,
/// 2026-10-30) stands on the theme's background, as in full screen, and
/// holds the page behind it still while it does: the lock is the
/// attribute's, so it goes when the attribute does.
final class ArtifactFillsWindowTests: XCTestCase {
  func testFillingTheWindowIsOnTheThemesBackgroundAndLocksThePagesScroll() throws {
    let css = HTMLGlobalStyle.collecting {
      _ = ArtifactView {
        div { "Page" }.data("service-id", "https://h/i1")
      } canvas: {
        div {}.data("service-id", "https://h/i1")
      }.build()
    }.currentStyleSheets().map(\.css).joined(separator: "\n")
    let rules = css.components(separatedBy: "}")
    let ground = try XCTUnwrap(rules.first { $0.contains(".artifact-view[data-fills-window='true'], .artifact-view:fullscreen") })
    XCTAssertTrue(ground.contains("background-color: var(--background-color-base) !important"))
    let lock = try XCTUnwrap(rules.first { $0.contains(":root:has(.artifact-view[data-fills-window='true'])") })
    XCTAssertTrue(lock.contains(":root:has(.artifact-view[data-fills-window='true']) body"))
    XCTAssertTrue(lock.contains("overflow: hidden"))
  }
}
