import EmbeddedSwiftUtilities

/// A manifest answer as the reader reads it (the viewer's shape,
/// `{"label":…,"canvases":[{"id":…,"w":…,"h":…,"l":…}]}`): its pages, why
/// there are none when the server said, and whether it was read at all.
///
/// Shared by the reader (client) and its tests (server), so the switch's
/// rule is one rule.
struct ArtifactManifest {
  struct Page {
    let serviceID: String
    let width: Int
    let height: Int
    let label: String
  }

  /// What the page-images switch does with an answer (user, 2026-10-10):
  /// never offered for an image not confirmed.
  enum CanvasSwitch {
    /// The manifest names an image: the switch shows.
    case confirmed
    /// The manifest answers with no image: the switch stays hidden for good.
    case none
    /// No answer, or the server's `"unread"` (a timeout, too many reads):
    /// the switch stays hidden while the reader asks again.
    case pending
  }

  var pages: [Page] = []
  var error: String?
  var unread = false

  /// No answer at all (`nil`) reads as unread.
  static func parse(_ json: String?) -> ArtifactManifest {
    var manifest = ArtifactManifest()
    guard let json else {
      manifest.unread = true
      return manifest
    }
    // The manifest's free-text label is shown nowhere: the reader has no
    // title (the page heads it).
    let parts = stringSplit(json, separator: "\"canvases\":")
    if parts.count > 1 {
      for entry in stringSplit(parts[1], separator: "},{") {
        guard let id = extractJSONString(entry, key: "id") else { continue }
        guard stringStartsWith(id, "http") || stringStartsWith(id, "/") else { continue }
        guard let width = extractJSONInt(entry, key: "w") else { continue }
        guard let height = extractJSONInt(entry, key: "h") else { continue }
        manifest.pages.append(
          Page(serviceID: id, width: width, height: height, label: extractJSONString(entry, key: "l") ?? ""))
      }
    }
    if manifest.pages.isEmpty {
      manifest.error = extractJSONString(json, key: "error")
      manifest.unread = stringContains(json, "\"unread\":true")
    }
    return manifest
  }

  var canvasSwitch: CanvasSwitch {
    for page in pages where page.width > 0 && page.height > 0 { return .confirmed }
    return unread ? .pending : .none
  }

  /// The waits, in milliseconds, before each read again of an unread
  /// manifest: a few, each longer, then the switch stays hidden.
  static let retryDelays: [Double] = [4000, 8000, 16000]
}
