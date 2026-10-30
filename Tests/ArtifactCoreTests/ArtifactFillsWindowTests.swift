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
    let ground = try XCTUnwrap(rules.first { $0.contains(".artifact-view[data-fills-window], .artifact-view:fullscreen") })
    XCTAssertTrue(ground.contains("background-color: var(--background-color-base) !important"))
    let lock = try XCTUnwrap(rules.first { $0.contains(":root:has(.artifact-view[data-fills-window])") })
    XCTAssertTrue(lock.contains(":root:has(.artifact-view[data-fills-window]) body"))
    XCTAssertTrue(lock.contains("overflow: hidden"))
  }

  /// Its move in and out (user, 2026-10-30) is a FLIP transform about the
  /// window's corner, transitioned on the system's medium clock and the
  /// user-motion curve only while it moves; the theme's background fades
  /// in behind it on the root's pseudo-element, under the reader; neither
  /// moves for those who ask for reduced motion.
  func testTheMoveIsATransitionedTransformWithAFadingGroundAndNoneUnderReducedMotion() throws {
    let css = HTMLGlobalStyle.collecting {
      _ = ArtifactView {
        div { "Page" }.data("service-id", "https://h/i1")
      } canvas: {
        div {}.data("service-id", "https://h/i1")
      }.build()
    }.currentStyleSheets().map(\.css).joined(separator: "\n")
    let rules = css.components(separatedBy: "}")
    let fixed = try XCTUnwrap(rules.first { $0.contains(".artifact-view[data-fills-window] {") && $0.contains("position: fixed") })
    XCTAssertTrue(fixed.contains("transform-origin: 0 0"))
    let move = try XCTUnwrap(rules.first { $0.contains(".artifact-view[data-fills-window][data-fills-window-moving='true'] {") })
    XCTAssertTrue(
      move.contains("transition: transform var(--transition-duration-medium) var(--transition-timing-function-user)"))
    XCTAssertTrue(move.contains("will-change: transform"))
    let ground = try XCTUnwrap(rules.first { $0.contains(":root:has(.artifact-view)::after {") })
    XCTAssertTrue(ground.contains("position: fixed"))
    XCTAssertTrue(ground.contains("z-index: var(--z-index-overlay-backdrop)"))
    XCTAssertTrue(ground.contains("background-color: var(--background-color-base)"))
    XCTAssertTrue(ground.contains("opacity: 0"))
    XCTAssertTrue(ground.contains("visibility: hidden"))
    XCTAssertTrue(ground.contains("pointer-events: none"))
    XCTAssertTrue(ground.contains("opacity var(--transition-duration-medium) var(--transition-timing-function-user)"))
    let shown = try XCTUnwrap(rules.first { $0.contains(":root:has(.artifact-view[data-fills-window='true'])::after {") })
    XCTAssertTrue(shown.contains("opacity: 1"))
    XCTAssertTrue(shown.contains("visibility: visible"))
    let still = rules.filter { $0.contains("prefers-reduced-motion: reduce") }
    XCTAssertTrue(still.contains { $0.contains("[data-fills-window-moving='true']") }, "the move stands still under reduced motion")
    XCTAssertTrue(still.contains { $0.contains(":root:has(.artifact-view)::after") }, "the ground stands still under reduced motion")
  }
}
