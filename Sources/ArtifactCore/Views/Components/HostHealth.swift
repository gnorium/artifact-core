#if CLIENT
  import WebAPIs
#else
  import Foundation
#endif

/// What this page has learned of one image host from the requests it has
/// made it, so that a host that has gone bad (the Internet Archive's IIIF
/// answering every region request with a 504 a minute on, or hanging a size)
/// costs what its own answers say a request takes, not a minute a request.
///
/// A request is of one of three classes (`Kind`): a **tile** (a region of the
/// image), a **whole** image (a size of it, the reader's first copy, an
/// archived copy) or the service's **info** (`info.json`). A host can fail one
/// class and serve another.
///
/// Every value is measured or a named convention—no tuned constant:
///
/// - **Timeout** (`timeout`): a request still unanswered past Tukey's upper
///   fence over the class's answer times—the third quartile plus 1.5
///   interquartile ranges (`fenceReach`, the convention `type_scale.fence`
///   uses), taken on their logarithms, since answer times are positive and
///   skewed right—is abandoned (cancelled, so its connection is free). The
///   quartiles are linear between order statistics (Hyndman and Fan's type
///   7, R's and NumPy's default) and need a point in each quartile
///   (`fenceSamples`, 4); a class with fewer borrows the host's answers of
///   every class, and with fewer still no request is timed out by this page
///   (the browser's and the host's own limits stand). A fence is never
///   taken under one second (`minimumTimeout`, RFC 6298 §2.4's floor for a
///   measured timeout), so a host whose answers barely vary is not cut off
///   by its own jitter. A request that tests the host (a probe) is never
///   timed out: it runs to its end, so a slow but living host is learned,
///   not cut off.
/// - **Breaker** (`gate`): it opens after `tolerance` failures in a row—the
///   smallest run whose chance under the class's success rate is below the
///   conventional 5% (`significance`): `ceil(log 0.05 / log(1 − p))`, with `p`
///   by Laplace's rule of succession, `(answers + 1) / (requests + 2)`, over
///   the class's requests before the run. Open, no request of the class is
///   made for the **cool-down**: the class's fence (or, without one, the time
///   the failure took), doubled each time it opens again (binary exponential
///   backoff), with no cap but what that gives. Then one request is let
///   through to test the host (`.probe`): answered, the breaker closes;
///   failed, it opens again. A class with a fallback that has never been
///   answered (tiles, which whole images stand in for; the info, without
///   which whole images are asked for at the powers of two) starts as if its
///   cool-down were over: one request at a time until one is answered. Whole
///   images have nothing to fall back to and start closed.
/// - **Retries**: a failed request is asked again at once while its class's
///   breaker is closed; the breaker bounds them.
/// - **Concurrency**: none of this page's own—the browser keeps its own queue
///   per host. A request that goes out while `browserConnections` (6, what
///   Chrome, Safari and Firefox send to one host at once over HTTP/1.1) or
///   more are out may wait in that queue, not at the host: it is `suspect`,
///   and its first timeout is not counted as a failure.
/// - **Sizes** (`isBad`): a whole-image width that failed is not asked for
///   again for the whole images' fence (or the time the failure took),
///   doubled each time that width fails again.
///
/// Pure arithmetic over `now` (milliseconds): the client's compositor and the
/// tests share it.
final class HostHealth: @unchecked Sendable {
  enum Kind: Int {
    /// A region of the image.
    case tile = 0
    /// The whole image at a width.
    case whole = 1
    /// The service's `info.json`.
    case info = 2
  }

  enum Gate {
    /// Requests go out.
    case open
    /// One request may go out to test the host: the breaker's cool-down is
    /// over, or the class has never been answered.
    case probe
    /// None.
    case closed
  }

  enum Outcome {
    case answered(latency: Double)
    /// Failed (an error, or abandoned at the timeout) after `after`
    /// milliseconds.
    case failed(after: Double)
  }

  /// The conventional significance level a run of failures is judged at.
  static let significance = 0.05
  /// Tukey's fence: the third quartile plus this many interquartile ranges.
  static let fenceReach = 1.5
  /// The answers a fence needs: one in each quartile.
  static let fenceSamples = 4
  /// What a browser sends to one host at once over HTTP/1.1.
  static let browserConnections = 6
  /// The least a measured timeout is, in milliseconds: RFC 6298's (§2.4)
  /// rounding of a computed retransmission timeout up to one second, so a
  /// host whose answers barely vary is not cut off by its own jitter.
  static let minimumTimeout = 1000.0

  let name: String
  /// Requests out now, of every class.
  private(set) var inflight = 0

  private var latencies: [[Double]] = [[], [], []]
  private var answered = [0, 0, 0]
  private var failures = [0, 0, 0]
  private var streak = [0, 0, 0]
  private var openedAt = [-1.0, -1.0, -1.0]
  private var coolDowns = [0.0, 0.0, 0.0]
  private var opens = [0, 0, 0]
  private var probing = [false, false, false]
  private var badWidths: [(width: Int, until: Double, failures: Int)] = []

  init(name: String) {
    self.name = name
  }

  /// Whether the class has another to fall back to while it is unproven.
  private static func hasFallback(_ kind: Kind) -> Bool {
    kind != .whole
  }

  // MARK: - Measured

  /// The answer times a statistic of the class is taken over: its own, or,
  /// with fewer than `minimum`, the host's of every class; empty if those
  /// are fewer too.
  private func samples(_ kind: Kind, minimum: Int) -> [Double] {
    let own = latencies[kind.rawValue]
    if own.count >= minimum { return own }
    let pooled = latencies[0] + latencies[1] + latencies[2]
    return pooled.count >= minimum ? pooled : []
  }

  /// The quantile `p` of `sorted`, linear between order statistics (Hyndman
  /// and Fan's type 7).
  static func quantile(_ sorted: [Double], _ p: Double) -> Double {
    let position = Double(sorted.count - 1) * p
    let lower = Int(position)
    let upper = min(lower + 1, sorted.count - 1)
    return sorted[lower] + (position - Double(lower)) * (sorted[upper] - sorted[lower])
  }

  /// Tukey's upper fence over the class's answer times (on their
  /// logarithms), in milliseconds; nil without enough answers.
  func fence(_ kind: Kind) -> Double? {
    let times = samples(kind, minimum: Self.fenceSamples)
    guard !times.isEmpty else { return nil }
    var logs: [Double] = []
    for time in times { logs.append(log(max(time, 1))) }
    logs.sort()
    let first = Self.quantile(logs, 0.25)
    let third = Self.quantile(logs, 0.75)
    return exp(third + Self.fenceReach * (third - first))
  }

  /// How long a request of the class may go unanswered: its fence, never
  /// under `minimumTimeout`; nil for no limit of this page's.
  func timeout(_ kind: Kind) -> Double? {
    guard let fence = fence(kind) else { return nil }
    return max(fence, Self.minimumTimeout)
  }

  /// The class's median answer time (the host's, where the class has none);
  /// nil before any answer.
  func typical(_ kind: Kind) -> Double? {
    var times = samples(kind, minimum: 1)
    guard !times.isEmpty else { return nil }
    times.sort()
    return Self.quantile(times, 0.5)
  }

  /// Failures in a row that open the breaker: the smallest run whose chance
  /// is below `significance` at the class's success rate before the run.
  func tolerance(_ kind: Kind) -> Int {
    let index = kind.rawValue
    let answers = Double(answered[index])
    let earlierFailures = Double(failures[index] - streak[index])
    let success = (answers + 1) / (answers + earlierFailures + 2)
    let run = ceil(log(Self.significance) / log(1 - success))
    return max(1, Int(run))
  }

  /// Whether the class has ever been answered by the host.
  func isProven(_ kind: Kind) -> Bool {
    answered[kind.rawValue] > 0
  }

  // MARK: - The breaker

  func gate(_ kind: Kind, now: Double) -> Gate {
    let index = kind.rawValue
    if openedAt[index] >= 0 {
      return now < openedAt[index] + coolDowns[index] || probing[index] ? .closed : .probe
    }
    if Self.hasFallback(kind) && answered[index] == 0 { return probing[index] ? .closed : .probe }
    return .open
  }

  /// When the breaker's cool-down is over; nil if it is not open.
  func reopensAt(_ kind: Kind) -> Double? {
    let index = kind.rawValue
    return openedAt[index] >= 0 ? openedAt[index] + coolDowns[index] : nil
  }

  // MARK: - Requests

  /// A request goes out; `probe` when it is the one that tests the host.
  /// Returns whether it is `suspect`: out with as many others as a browser
  /// sends to one host at once, it may be waiting in the browser's queue.
  @discardableResult
  func began(_ kind: Kind, probe: Bool) -> Bool {
    let suspect = inflight >= Self.browserConnections
    inflight += 1
    if probe { probing[kind.rawValue] = true }
    return suspect
  }

  /// A request is let go, cancelled, with no answer to learn from.
  func cancelled(_ kind: Kind, probe: Bool) {
    inflight = max(0, inflight - 1)
    if probe { probing[kind.rawValue] = false }
  }

  /// A request answered or failed. Returns whether the breaker opened or
  /// closed with it (what to ask for has changed).
  @discardableResult
  func finished(_ kind: Kind, outcome: Outcome, probe: Bool, now: Double) -> Bool {
    let index = kind.rawValue
    inflight = max(0, inflight - 1)
    if probe { probing[index] = false }
    switch outcome {
    case let .answered(latency):
      let first = answered[index] == 0
      answered[index] += 1
      streak[index] = 0
      if openedAt[index] >= 0 {
        // The host answers again: what was measured while it failed is
        // let go.
        openedAt[index] = -1
        opens[index] = 0
        latencies[index] = [latency]
        return true
      }
      latencies[index].append(latency)
      return first && Self.hasFallback(kind)
    case let .failed(after):
      failures[index] += 1
      streak[index] += 1
      if openedAt[index] >= 0 {
        // A late failure from before it opened changes nothing; the probe's
        // own opens it again.
        guard probe else { return false }
        open(kind, now: now, after: after)
        return true
      }
      if probe || streak[index] >= tolerance(kind) {
        open(kind, now: now, after: after)
        return true
      }
      return false
    }
  }

  private func open(_ kind: Kind, now: Double, after: Double) {
    let index = kind.rawValue
    opens[index] += 1
    var coolDown = fence(kind) ?? max(after, 1)
    var doublings = opens[index] - 1
    while doublings > 0 {
      coolDown *= 2
      doublings -= 1
    }
    coolDowns[index] = coolDown
    openedAt[index] = now
  }

  // MARK: - Sizes

  /// A whole-image width that failed after `after` milliseconds: not asked
  /// for again for the whole images' fence (or that time), doubled each time
  /// it fails again.
  func markBad(width: Int, now: Double, after: Double) {
    let base = fence(.whole) ?? max(after, 1)
    for index in badWidths.indices where badWidths[index].width == width {
      let failures = badWidths[index].failures + 1
      var wait = base
      var doublings = failures - 1
      while doublings > 0 {
        wait *= 2
        doublings -= 1
      }
      badWidths[index].failures = failures
      badWidths[index].until = now + wait
      return
    }
    badWidths.append((width, now + base, 1))
  }

  func isBad(width: Int, now: Double) -> Bool {
    for entry in badWidths where entry.width == width && entry.until > now { return true }
    return false
  }

  /// A width the host served after all.
  func clearBad(width: Int) {
    badWidths.removeAll { $0.width == width }
  }

  /// When the next of its waits is over—a breaker's cool-down, a width
  /// left alone—nil if none is under way: when to ask again.
  func nextChange(now: Double) -> Double? {
    var soonest: Double?
    func consider(_ time: Double) {
      guard time > now else { return }
      if let current = soonest, current <= time { return }
      soonest = time
    }
    for index in 0..<3 where openedAt[index] >= 0 { consider(openedAt[index] + coolDowns[index]) }
    for entry in badWidths { consider(entry.until) }
    return soonest
  }
}
