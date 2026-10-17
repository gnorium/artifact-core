import XCTest

@testable import ArtifactCore

/// What the viewer learns of an image host from its answers—how long to
/// wait, when to stop asking for a class of request, which widths it
/// serves—every value measured or a named convention.
final class HostHealthTests: XCTestCase {
  private func answer(_ host: HostHealth, _ kind: HostHealth.Kind, _ latencies: [Double], now: Double = 0) {
    for latency in latencies {
      host.began(kind, probe: false)
      host.finished(kind, outcome: .answered(latency: latency), probe: false, now: now)
    }
  }

  private func fail(_ host: HostHealth, _ kind: HostHealth.Kind, times: Int, after: Double, now: Double, probe: Bool = false)
    -> Bool
  {
    var changed = false
    for _ in 0..<times {
      host.began(kind, probe: probe)
      changed = host.finished(kind, outcome: .failed(after: after), probe: probe, now: now) || changed
    }
    return changed
  }

  func testTheTimeoutIsTukeysFenceOverTheAnswerTimes() throws {
    let host = HostHealth(name: "iiif.example")
    // Before a point in each quartile: no timeout of the page's own.
    answer(host, .whole, [900, 1000, 1100])
    XCTAssertNil(host.timeout(.whole))
    answer(host, .whole, [1200, 1000, 950, 1050, 3000])
    // Past every ordinary answer, short of the one far out: the 3 s answer
    // is beyond the fence.
    let fence = try XCTUnwrap(host.timeout(.whole))
    XCTAssertGreaterThan(fence, 1200)
    XCTAssertLessThan(fence, 3000)
    // On their logarithms: Q3 + 1.5 IQR, quartiles linear between order
    // statistics.
    let logs = [900.0, 950, 1000, 1000, 1050, 1100, 1200, 3000].map { log($0) }.sorted()
    let q1 = HostHealth.quantile(logs, 0.25)
    let q3 = HostHealth.quantile(logs, 0.75)
    XCTAssertEqual(fence, exp(q3 + 1.5 * (q3 - q1)), accuracy: 1e-6)
    // Tiles, with no answers of their own, borrow the host's.
    XCTAssertEqual(try XCTUnwrap(host.timeout(.tile)), fence, accuracy: 1e-6)
  }

  func testAMeasuredTimeoutIsNeverUnderASecond() {
    // A host whose answers barely vary (a cache, a stub): RFC 6298's floor.
    let host = HostHealth(name: "steady")
    answer(host, .tile, [50, 51, 50, 52, 50])
    XCTAssertEqual(host.timeout(.tile), 1000)
    XCTAssertLessThan(host.fence(.tile) ?? 0, 1000)
  }

  func testTheMedianIsTheTypicalAnswer() {
    let host = HostHealth(name: "median")
    XCTAssertNil(host.typical(.tile))
    answer(host, .whole, [100, 300, 200])
    XCTAssertEqual(host.typical(.tile), 200)
  }

  func testTheRunThatOpensTheBreakerIsTheSmallestUnlikelyOne() {
    // Nothing known: p = 1/2 by Laplace's rule, and 0.5^5 < 0.05 < 0.5^4.
    XCTAssertEqual(HostHealth(name: "new").tolerance(.whole), 5)
    let one = HostHealth(name: "one")
    answer(one, .whole, [1000])
    // p = 2/3: (1/3)^3 < 0.05.
    XCTAssertEqual(one.tolerance(.whole), 3)
    let ten = HostHealth(name: "ten")
    answer(ten, .whole, Array(repeating: 1000, count: 10))
    // p = 11/12: (1/12)^2 < 0.05.
    XCTAssertEqual(ten.tolerance(.whole), 2)
    let thirty = HostHealth(name: "thirty")
    answer(thirty, .whole, Array(repeating: 1000, count: 30))
    // p = 31/32: a single failure is already unlikely.
    XCTAssertEqual(thirty.tolerance(.whole), 1)
  }

  func testWholeImagesOpenAfterTheirRunAndTilesAfterTheirOnlyProbe() {
    let host = HostHealth(name: "degraded")
    // Whole images have nothing to fall back to: open from the start.
    XCTAssertEqual(host.gate(.whole, now: 0), .open)
    XCTAssertFalse(fail(host, .whole, times: 4, after: 500, now: 10_000))
    XCTAssertTrue(fail(host, .whole, times: 1, after: 500, now: 10_000))
    XCTAssertEqual(host.gate(.whole, now: 10_001), .closed)
    // Tiles, never answered, go one at a time: their one request tests the
    // host, and its failure opens their breaker.
    XCTAssertEqual(host.gate(.tile, now: 0), .probe)
    host.began(.tile, probe: true)
    XCTAssertEqual(host.gate(.tile, now: 0), .closed)
    XCTAssertTrue(host.finished(.tile, outcome: .failed(after: 60_000), probe: true, now: 70_000))
    // No fence yet: its cool-down is the time the failure took.
    XCTAssertEqual(host.reopensAt(.tile) ?? 0, 70_000 + 60_000, accuracy: 1)
    // A first answer opens tiles to every request.
    let healthy = HostHealth(name: "healthy")
    healthy.began(.tile, probe: true)
    XCTAssertTrue(healthy.finished(.tile, outcome: .answered(latency: 800), probe: true, now: 0))
    XCTAssertEqual(healthy.gate(.tile, now: 1), .open)
  }

  func testTheCoolDownIsTheFenceDoubledEachTimeAndAProbeEndsIt() {
    let host = HostHealth(name: "backoff")
    answer(host, .whole, Array(repeating: 1000, count: 8))
    // p = 9/10: two in a row open it, for the fence (1 s, every answer the
    // same).
    XCTAssertFalse(fail(host, .whole, times: 1, after: 6000, now: 1000))
    XCTAssertTrue(fail(host, .whole, times: 1, after: 6000, now: 1000))
    XCTAssertEqual(host.reopensAt(.whole) ?? 0, 2000, accuracy: 1e-6)
    XCTAssertEqual(host.gate(.whole, now: 1999), .closed)
    XCTAssertEqual(host.gate(.whole, now: 2000), .probe)
    host.began(.whole, probe: true)
    XCTAssertEqual(host.gate(.whole, now: 2001), .closed)
    // The probe fails: twice as long.
    XCTAssertTrue(host.finished(.whole, outcome: .failed(after: 1000), probe: true, now: 3000))
    XCTAssertEqual(host.reopensAt(.whole) ?? 0, 3000 + 2000, accuracy: 1e-6)
    // A request out before it opened, failing late, changes nothing.
    host.began(.whole, probe: false)
    XCTAssertFalse(host.finished(.whole, outcome: .failed(after: 9000), probe: false, now: 3500))
    XCTAssertEqual(host.reopensAt(.whole) ?? 0, 5000, accuracy: 1e-6)
    // Answered: closed, and what it said while failing let go.
    host.began(.whole, probe: true)
    XCTAssertTrue(host.finished(.whole, outcome: .answered(latency: 700), probe: true, now: 5000))
    XCTAssertEqual(host.gate(.whole, now: 5001), .open)
    XCTAssertEqual(host.typical(.whole), 700)
  }

  func testARequestOutWithAsManyAsABrowserSendsIsSuspect() {
    let host = HostHealth(name: "queue")
    var suspects = 0
    for _ in 0..<10 where host.began(.tile, probe: false) { suspects += 1 }
    XCTAssertEqual(suspects, 4)
    XCTAssertEqual(host.inflight, 10)
    host.cancelled(.tile, probe: false)
    XCTAssertEqual(host.inflight, 9)
  }

  func testAWidthThatFailedIsLeftAloneDoubledEachTime() {
    let host = HostHealth(name: "sizes")
    // No fence: the time the failure took.
    host.markBad(width: 2000, now: 1000, after: 5000)
    XCTAssertTrue(host.isBad(width: 2000, now: 5999))
    XCTAssertFalse(host.isBad(width: 1500, now: 1001))
    XCTAssertFalse(host.isBad(width: 2000, now: 6001))
    host.markBad(width: 2000, now: 10_000, after: 5000)
    XCTAssertTrue(host.isBad(width: 2000, now: 19_999))
    XCTAssertFalse(host.isBad(width: 2000, now: 20_001))
    XCTAssertEqual(host.nextChange(now: 10_000) ?? 0, 20_000, accuracy: 1e-6)
    host.clearBad(width: 2000)
    XCTAssertFalse(host.isBad(width: 2000, now: 10_001))
    XCTAssertNil(host.nextChange(now: 10_001))
  }
}
