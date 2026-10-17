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
    /// Plain images shown for the canvas in place of its image service,
    /// tried in order, the next where one does not load: for a page changed
    /// at its source, the archived copy of the image a run was sent—Gnorium
    /// keeps no copy of a source's image (`"imgs"`, user 2026-10-11,
    /// 2026-10-17); empty for the live service.
    var images: [String] = []
    /// Whether the image service may stand in where no plain image loads
    /// (`"live":false` where it may not): never for a page changed at its
    /// source, whose image now is not what was sent (user, 2026-10-17)—it
    /// shows a copy of what was sent or none.
    var live = true
    /// Whether the canvas is shown with no image (`"blank":true`): a page
    /// changed at its source with no copy of what a run was sent kept, whose
    /// image now is not what was sent (user, 2026-10-17). Its size stays, for
    /// the text's page frame.
    var blank = false
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
    // The fetch bridge returns an error-only object on network or JSON
    // failure. Only an actual canvases array can settle "no images".
    guard parts.count > 1 else {
      manifest.error = extractJSONString(json, key: "error")
      manifest.unread = true
      return manifest
    }
    if parts.count > 1 {
      for entry in stringSplit(parts[1], separator: "},{") {
        guard let id = extractJSONString(entry, key: "id") else { continue }
        guard stringStartsWith(id, "http") || stringStartsWith(id, "/") else { continue }
        guard let width = extractJSONInt(entry, key: "w") else { continue }
        guard let height = extractJSONInt(entry, key: "h") else { continue }
        manifest.pages.append(
          Page(
            serviceID: id, width: width, height: height, label: extractJSONString(entry, key: "l") ?? "",
            images: images(of: entry), live: !stringContains(entry, "\"live\":false"),
            blank: stringContains(entry, "\"blank\":true")))
      }
    }
    if manifest.pages.isEmpty {
      manifest.error = extractJSONString(json, key: "error")
      manifest.unread = stringContains(json, "\"unread\":true")
    }
    return manifest
  }

  /// The strings of a canvas's `"imgs"`, in order; none where it names none.
  private static func images(of entry: String) -> [String] {
    let parts = stringSplit(entry, separator: "\"imgs\":")
    guard parts.count > 1 else { return [] }
    var images: [String] = []
    for element in jsonArrayElements(parts[1]) {
      if let image = jsonStringLiteral(element), !stringIsEmpty(image) { images.append(image) }
    }
    return images
  }

  var canvasSwitch: CanvasSwitch {
    for page in pages where page.width > 0 && page.height > 0 { return .confirmed }
    return unread ? .pending : .none
  }

  /// The waits, in milliseconds, before each read again of an unread
  /// Back off to 30 seconds, then keep trying while the reader is attached.
  static let retryDelays: [Double] = [4000, 8000, 16000, 30000]

  static func retryDelay(after attempts: Int) -> Double {
    retryDelays[min(max(0, attempts), retryDelays.count - 1)]
  }
}
