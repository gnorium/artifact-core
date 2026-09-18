#if SERVER
  import CSSBuilder
  import DesignTokens
  import DOMBuilder
  import HTMLBuilder
  import WebComponents
  import WebTypes

  public struct ArtifactView: HTMLContent {
    let manifestURL: String
    let title: String?
    let authors: [String]
    let style: CSSStyle
    /// Which canvas the viewer opens on, when the page knows better than the
    /// reader's last visit — a deep link to one page of the object.
    ///
    /// ``startService`` names it by image service, which is what a deep link
    /// should carry: a page number only means the same page if the manifest is
    /// ordered the way the page that linked to it was. ``startCanvas`` is the
    /// positional fallback.
    let startCanvas: Int?
    let startService: String?
    /// A reading of the object, shown beside it: a transcription, a
    /// translation, an apparatus. Any descendant carrying `data-service-id` is
    /// shown only while the canvas with that image service is the one on
    /// screen, so the reading pages with the object.
    let reading: [DOM.Node]
    /// Whether the footer carries a switch from the reading to the source it
    /// was made from — markup, in the usual case. The reading marks its two
    /// layers with `data-reading-layer`, `"text"` and `"source"`, and the
    /// switch swaps them in place.
    let sourceSwitch: Bool

    public init(
      manifestURL: String,
      title: String? = nil,
      authors: [String] = [],
      style: CSSStyle = .default,
      startCanvas: Int? = nil,
      startService: String? = nil,
      sourceSwitch: Bool = false,
      @HTMLBuilder reading: () -> [DOM.Node] = { [] }
    ) {
      self.manifestURL = manifestURL
      self.title = title
      self.authors = authors
      self.style = style
      self.startCanvas = startCanvas
      self.startService = startService
      self.sourceSwitch = sourceSwitch
      self.reading = reading()
    }

    private var authorsLine: String {
      switch authors.count {
      case 0: return ""
      case 1: return authors[0]
      case 2: return "\(authors[0]) and \(authors[1])"
      default:
        var result = ""
        for (i, author) in authors.enumerated() {
          if i == 0 { result = author }
          else if i == authors.count - 1 { result += ", and \(author)" }
          else { result += ", \(author)" }
        }
        return result
      }
    }

    private var headerSubtitle: String {
      authorsLine.isEmpty ? "" : "by \(authorsLine)"
    }

    public func build() -> DOM.Node {
      div {
        // ── Header ──────────────────────────────────────────────────────────
        header {
          if let t = title, !t.isEmpty {
            span {
              span { t }
                .id("artifact-title")
                .class("artifact-title-primary")
              if !headerSubtitle.isEmpty {
                span { " \(headerSubtitle)" }
                  .class("artifact-title-subtitle")
              }
            }
            .class("artifact-title-block")
          } else {
            span().id("artifact-title").class("artifact-title-empty")
          }

          // Page nav — top right (edge prev/next stay on the viewer)
          PaginationView(
            currentPage: 1,
            totalPages: 1,
            size: .mini,
            showControls: false,
            kind: "artifact",
            inputID: "artifact-page-input",
            totalID: "artifact-page-total",
            totalDisplay: "—",
            ariaLabel: "Pages",
            inputAriaLabel: "Page number",
            class: "artifact-page-nav"
          )
        }
        .class("artifact-header")

        // ── Viewer body with prev/next overlaid on edges ─────────────────────
        div {
          // The object, with its own page turns on its own edges: the arrows
          // belong to the thing being paged, not to the reading of it.
          div {
            // Prev button — left edge overlay
            button {
              PreviousIconView(width: px(16), height: px(16))
            }
            .id("artifact-prev")
            .disabled(true)
            .class("artifact-nav-button artifact-nav-prev")

            // Viewport — explicit flex(1) + height(0) forces flex to size it correctly
            div {
              // Spinner overlay — shown while image loads, hidden when done
              div {
                RotatingSectorView(ariaHidden: true)
              }
              .id("artifact-spinner")
              .class("artifact-spinner")
            }
            .id("artifact-viewport")
            .class("artifact-viewport")

            // Next button — right edge overlay
            button {
              NextIconView(width: px(16), height: px(16))
            }
            .id("artifact-next")
            .disabled(true)
            .class("artifact-nav-button artifact-nav-next")
          }
          .class("artifact-object")

          // The reading of the object, beside the object. It is a sibling of
          // the viewport rather than a block under the viewer so that the two
          // page together and fullscreen carries both.
          if !reading.isEmpty {
            div {
              reading
            }
            .id("artifact-reading")
            .class("artifact-reading")
          }
        }
        .id("artifact-viewer-container")
        .class("artifact-viewer-container")

        // ── Footer ───────────────────────────────────────────────────────────
        footer {
          span {}
            .id("artifact-canvas-label")
            .class("artifact-canvas-label")

          if sourceSwitch, !reading.isEmpty {
            ToggleButtonView(
              label: "Raw",
              icon: nil as HTML.HTMLSpanElement?,
              modelValue: false,
              weight: .static,
              buttonColor: .gray,
              fullWidth: false,
              ariaLabel: "Source of this reading",
              indicateSelection: true,
              size: .mini,
              class: "artifact-source-toggle",
              labelFontWeight: fontWeightNormal
            )
          }

          div().id("artifact-zoom-controls")
            .class("artifact-zoom-controls")

          button {
            IconView(icon: { size in [FullscreenIconView(width: size, height: size)] }, size: .small)
          }
          .id("artifact-fullscreen-btn")
          .class("artifact-fullscreen-button")
        }
        .class("artifact-footer")
      }
      .class("artifact-view")
      .data("manifest-url", manifestURL)
      .data("start-canvas", startCanvas.map { "\($0)" } ?? "")
      .data("start-service", startService ?? "")
      .data("style", style.rawValue)
      .style {
        selector("&") {
          display(.flex)
          flexDirection(.column)
          width(perc(100))
          height(perc(100))
          borderRadius(borderRadiusBase)
          overflow(.hidden)
          border(borderWidthBase, .solid, borderColorBase)
          backgroundColor(backgroundColorBase)
        }

        selector(".artifact-header", ".artifact-footer") {
          display(.flex)
          alignItems(.center)
          backgroundColor(backgroundColorBase)
        }
        selector(".artifact-header") {
          gap(spacing12)
          padding(spacing8, spacing16)
          borderBlockEnd(borderWidthBase, .solid, borderColorBase)
          minHeight(px(36))
        }
        selector(".artifact-title-block") {
          fontFamily(typographyFontSans)
          fontSize(fontSizeXSmall12)
          lineHeight(1.4)
          flex(1)
          minWidth(0)
          overflow(.hidden)
          textOverflow(.ellipsis)
          whiteSpace(.nowrap)
        }
        descendant(".artifact-title-primary") {
          fontWeight(fontWeightSemiBold)
          color(colorBase)
        }
        descendant(".artifact-title-subtitle") { color(colorSubtle) }
        descendant(".artifact-title-empty") {
          flex(1)
          minWidth(0)
        }
        descendant(".artifact-page-nav") {
          flexShrink(0)
        }
        descendant(".artifact-viewer-container") {
          flex(1)
          display(.flex)
          position(.relative)
          overflow(.hidden)
          // Side by side is a comparison; stacked is what fits. On a narrow
          // screen the object takes the top half and its reading the bottom,
          // rather than two columns too thin to read either.
          media(maxWidth(maxWidthBreakpointMobile)) {
            flexDirection(.column).important()
          }
        }
        descendant(".artifact-object") {
          flex(1, 1, perc(50))
          display(.flex)
          position(.relative)
          minWidth(0)
          minHeight(0)
          overflow(.hidden)
        }
        descendant(".artifact-nav-button") {
          position(.absolute)
          top(perc(50))
          transform(translate(px(0), perc(-50)))
          zIndex(10)
          width(px(36))
          height(px(36))
          borderRadius(borderRadiusCircle)
          border(borderWidthBase, .solid, borderColorBase)
          backgroundColor(backgroundColorBase)
          boxShadow(px(0), px(2), px(8), boxShadowColorAlphaBase)
          cursor(.pointer)
          display(.flex)
          alignItems(.center)
          justifyContent(.center)
          color(colorBase)
          opacity(0.85)
        }
        descendant(".artifact-nav-prev") { insetInlineStart(spacing8) }
        descendant(".artifact-nav-next") { insetInlineEnd(spacing8) }
        descendant(".artifact-viewport") {
          width(perc(100))
          flex(1)
          minHeight(0)
          overflow(.hidden)
          position(.relative)
          cursor(.grab)
          userSelect(.none)
        }
        descendant(".artifact-reading") {
          // Half the surface, whichever way the two are laid out. Without the
          // zero minimums a flex item never shrinks past its content, and a
          // page of verse would take two thirds of the viewer.
          flex(1, 1, perc(50))
          minWidth(0)
          minHeight(0)
          overflowY(.auto)
          padding(spacing16)
          borderInlineStart(borderWidthBase, .solid, borderColorBase)
          backgroundColor(backgroundColorBase)
          media(maxWidth(maxWidthBreakpointMobile)) {
            borderInlineStart(.none).important()
            borderBlockStart(borderWidthBase, .solid, borderColorBase).important()
          }
        }
        // The switch is in the footer and the layers are in the pane, so the
        // rule that ties them lives on the viewer, where both are in scope.
        selector("&:has(.artifact-source-toggle[aria-pressed='true']) .artifact-reading [data-reading-layer='text']") {
          display(.none)
        }
        selector("&:has(.artifact-source-toggle[aria-pressed='true']) .artifact-reading [data-reading-layer='source']") {
          display(.block)
        }
        // Only the reading of the canvas on screen. The rest stay in the
        // document so that paging is a class change, not a fetch.
        selector(".artifact-reading [data-service-id][data-active='false']") {
          display(.none)
        }
        descendant(".artifact-spinner") {
          display(.none)
          position(.absolute)
          inset(0)
          zIndex(5)
          alignItems(.center)
          justifyContent(.center)
          backgroundColor(backgroundColorBase)
        }
        descendant(".artifact-footer") {
          gap(spacing8)
          padding(spacing8, spacing16)
          borderBlockStart(borderWidthBase, .solid, borderColorBase)
        }
        descendant(".artifact-canvas-label") {
          fontSize(fontSizeXSmall12)
          color(colorSubtle)
          flex(1)
          overflow(.hidden)
          textOverflow(.ellipsis)
          whiteSpace(.nowrap)
        }
        descendant(".artifact-zoom-controls") {
          display(.flex)
          alignItems(.center)
          gap(spacing4)
        }
        selector(".artifact-fullscreen-button") {
          display(.flex)
          alignItems(.center)
          justifyContent(.center)
          width(px(20))
          height(px(20))
          borderRadius(borderRadiusBase)
          border(.none)
          backgroundColor(.transparent)
          color(colorSubtle)
          cursor(.pointer)
          flexShrink(0)
          pseudoClass(.hover) { color(colorBase) }
        }

        selector(".artifact-tile-surface") {
          position(.absolute)
          inset(0)
          overflow(.visible)
        }
        selector(".artifact-tile-compositor") {
          transformOrigin(px(0), px(0))
          willChange(.transform)
        }
        selector(".artifact-tile-image[data-loaded='false']") { opacity(0) }
        selector(".artifact-tile-image[data-loaded='true']") { opacity(1) }
        selector("#artifact-spinner[data-visible='true']") { display(.flex) }
        selector("#artifact-spinner[data-visible='false']") { display(.none) }
        selector("#artifact-viewport[data-dragging='true']") { cursor(.grabbing) }
      }
    }
  }

  extension ArtifactView {
    public enum CSSStyle: String, Sendable {
      case `default`
      case dark
      case minimal
    }
  }
#endif

#if CLIENT
  import CSSBuilder
  import CSSOMBuilder
  import DOMBuilder
  import EmbeddedSwiftUtilities
  import HTMLBuilder
  import WebAPIs
  import WebTypes

  public final class ArtifactHydration: @unchecked Sendable {
    public static nonisolated(unsafe) var instance: ArtifactHydration?

    public static func hydrateIfPresent() {
      guard document.querySelector(".artifact-view") != nil
      else { return }
      let h = ArtifactHydration()
      h.hydrate()
      instance = h
    }

    public init() {}

    public func hydrate() {
      guard let root = document.querySelector(".artifact-view") else { return }
      let manifestURL = root.dataset["manifest-url"] ?? ""
      guard !stringIsEmpty(manifestURL) else { return }
      Engine.start(
        root: root,
        manifestURL: manifestURL,
        startCanvas: parseInt(root.dataset["start-canvas"] ?? ""),
        startService: root.dataset["start-service"] ?? ""
      )
    }
  }

  private enum Engine {
    private nonisolated(unsafe) static var root: DOM.Element?
    private nonisolated(unsafe) static var viewport: DOM.Element?

    private nonisolated(unsafe) static var pageInput: DOM.Element?
    private nonisolated(unsafe) static var pageTotal: DOM.Element?
    private nonisolated(unsafe) static var canvasLabelEl: DOM.Element?
    private nonisolated(unsafe) static var prevBtn: DOM.Element?
    private nonisolated(unsafe) static var nextBtn: DOM.Element?

    private nonisolated(unsafe) static var serviceIDs: [String] = []
    private nonisolated(unsafe) static var imageWidths: [Int] = []
    private nonisolated(unsafe) static var imageHeights: [Int] = []
    private nonisolated(unsafe) static var canvasLabels: [String] = []
    private nonisolated(unsafe) static var canvasIndex: Int = 0

    private nonisolated(unsafe) static var zoom: Double = 1.0
    private nonisolated(unsafe) static var panX: Double = 0
    private nonisolated(unsafe) static var panY: Double = 0

    private nonisolated(unsafe) static var isDragging = false
    private nonisolated(unsafe) static var dragStartX: Double = 0
    private nonisolated(unsafe) static var dragStartY: Double = 0
    private nonisolated(unsafe) static var dragPanX: Double = 0
    private nonisolated(unsafe) static var dragPanY: Double = 0

    private nonisolated(unsafe) static var viewportW: Double = 0
    private nonisolated(unsafe) static var viewportH: Double = 0

    private nonisolated(unsafe) static var manifestURL: String = ""
    /// The canvas the page asked for, which outranks the one this reader was
    /// last on: a link to a page of the object means that page.
    private nonisolated(unsafe) static var startCanvas: Int?
    private nonisolated(unsafe) static var startService: String = ""
    private nonisolated(unsafe) static var readingPanes: [DOM.Element] = []

    private static func storageKey() -> String { "gnorium:artifact-canvas:\(manifestURL)" }
    private static func saveCanvasIndex() { localStorage.setItem(storageKey(), "\(canvasIndex)") }
    private static func savedCanvasIndex() -> Int {
      parseInt(localStorage.getItem(storageKey()) ?? "") ?? 0
    }

    static func start(
      root: DOM.Element,
      manifestURL: String,
      startCanvas: Int? = nil,
      startService: String = ""
    ) {
      self.root = root
      self.startCanvas = startCanvas
      self.startService = startService
      readingPanes = root.querySelectorAll(".artifact-reading [data-service-id]")
      let vp = root.querySelector("#artifact-viewport")
      viewport = vp
      pageInput = root.querySelector("#artifact-page-input")
      pageTotal = root.querySelector("#artifact-page-total")
      canvasLabelEl = root.querySelector("#artifact-canvas-label")
      prevBtn = root.querySelector("#artifact-prev")
      nextBtn = root.querySelector("#artifact-next")

      if let vp, let spinner = root.querySelector("#artifact-spinner") {
        TileCompositor.attach(to: vp, spinner: spinner)
      }

      // Recenter + reload tiles whenever the viewport resizes (sidebar toggle, window resize, etc.)
      // Guard against spurious ResizeObserver callbacks triggered by scroll in some browsers
      vp?.observeResize { w, h in
        guard w > 0, h > 0 else { return }
        guard w != viewportW || h != viewportH else { return }
        viewportW = w
        viewportH = h
        guard canvasIndex < imageWidths.count else { return }
        let iw = Double(imageWidths[canvasIndex]) * zoom
        let ih = Double(imageHeights[canvasIndex]) * zoom
        panX = (viewportW - iw) / 2
        panY = (viewportH - ih) / 2
        clampPan()
        updateTransform()
      }

      Self.manifestURL = manifestURL
      setupGestures()
      loadManifest(url: manifestURL)
    }

    private static func loadManifest(url: String) {
      root?.fetch(url) { jsonStr in
        guard let jsonStr else { return }
        parseManifest(jsonStr)
        let asked = canvasIndex(ofService: startService) ?? startCanvas ?? savedCanvasIndex()
        let opening = max(0, min(asked, serviceIDs.count - 1))
        canvasIndex = opening
        updateUI()
        loadCanvas(opening)
      }
    }

    private static func parseManifest(_ json: String) {
      // Compact format from element_fetch: {"label":"...","canvases":[{"id":"...","w":N,"h":N},...]}
      // Title is server-rendered; we skip overwriting it from the manifest label.
      let parts = stringSplit(json, separator: "\"canvases\":")
      guard parts.count > 1 else { return }
      let entries = stringSplit(parts[1], separator: "},{")
      for entry in entries {
        guard let id = extractJSONString(entry, key: "id") else { continue }
        guard stringStartsWith(id, "http") || stringStartsWith(id, "/") else { continue }
        guard let width = extractJSONInt(entry, key: "w") else { continue }
        guard let height = extractJSONInt(entry, key: "h") else { continue }
        serviceIDs.append(id)
        imageWidths.append(width)
        imageHeights.append(height)
        canvasLabels.append(extractJSONString(entry, key: "l") ?? "")
      }
    }
    private static func loadCanvas(_ idx: Int) {
      guard idx >= 0, idx < serviceIDs.count else { return }
      canvasIndex = idx
      saveCanvasIndex()
      updateUI()
      let w = imageWidths[idx]
      let h = imageHeights[idx]
      fitToViewport(imageW: Double(w), imageH: Double(h))
      TileCompositor.showSpinner()
      TileCompositor.setCanvas(serviceID: serviceIDs[idx], width: w, height: h)
      TileCompositor.update(panX: panX, panY: panY, zoom: zoom, viewportW: viewportW, viewportH: viewportH)
      preloadWindow(around: idx)
    }

    private static func preloadWindow(around idx: Int) {
      // Prioritize nearest canvases: +1, -1, +2, -2, ... so browser fetches most-likely-next first
      // Preload at DPR=1 so images are cached and appear instantly on navigation
      var urls: [String] = []
      for dist in 1...20 {
        let fwd = idx + dist
        let bwd = idx - dist
        if fwd < serviceIDs.count {
          urls.append(artifactImageURL(serviceID: serviceIDs[fwd], width: imageWidths[fwd], height: imageHeights[fwd], dprOverride: 1.0))
        }
        if bwd >= 0 {
          urls.append(artifactImageURL(serviceID: serviceIDs[bwd], width: imageWidths[bwd], height: imageHeights[bwd], dprOverride: 1.0))
        }
      }
      preloadImages(urls: urls)
    }

    private nonisolated(unsafe) static var minZoom: Double = 0.01

    private static func fitToViewport(imageW: Double, imageH: Double) {
      guard let vp = viewport, let rect = vp.getBoundingClientRect() else { return }
      viewportW = rect.width > 0 ? rect.width : 900
      viewportH = rect.height > 0 ? rect.height : 500
      let scaleW = viewportW / imageW
      let scaleH = viewportH / imageH
      minZoom = min(scaleW, scaleH)
      zoom = minZoom
      panX = (viewportW - imageW * zoom) / 2
      panY = (viewportH - imageH * zoom) / 2
    }

    private static func clampPan() {
      guard canvasIndex < imageWidths.count else { return }
      let iw = Double(imageWidths[canvasIndex]) * zoom
      let ih = Double(imageHeights[canvasIndex]) * zoom
      // If image is smaller than viewport in a dimension: center it, no panning allowed
      // If image is larger: clamp so no empty gap appears at any edge
      if iw <= viewportW {
        panX = (viewportW - iw) / 2
      } else {
        panX = min(0, max(viewportW - iw, panX))
      }
      if ih <= viewportH {
        panY = (viewportH - ih) / 2
      } else {
        panY = min(0, max(viewportH - ih, panY))
      }
    }

    private static func snapToHorizontalCenter() {
      guard canvasIndex < imageWidths.count else { return }
      let iw = Double(imageWidths[canvasIndex]) * zoom
      panX = (viewportW - iw) / 2
    }

    private static func updateTransform() {
      TileCompositor.update(panX: panX, panY: panY, zoom: zoom, viewportW: viewportW, viewportH: viewportH)
    }

    private static func updateUI() {
      let page = canvasIndex + 1
      let total = serviceIDs.count
      if let input = pageInput as? HTML.HTMLInputElement {
        input.value = "\(page)"
      }
      pageInput?.setAttribute(.max, "\(total)")
      pageTotal?.textContent = "\(total)"
      var digits = 1
      var n = total
      while n >= 10 { n /= 10; digits += 1 }
      pageInput?.setAttribute("size", intToString(digits))
      let label = canvasIndex < canvasLabels.count ? canvasLabels[canvasIndex] : ""
      canvasLabelEl?.textContent = label
      showReading(for: canvasIndex)
      prevBtn?.setDisabled(canvasIndex <= 0)
      nextBtn?.setDisabled(canvasIndex >= total - 1)
    }

    private static func commitPageInput() {
      guard let input = pageInput else { return }
      let total = serviceIDs.count
      guard total > 0 else {
        (input as? HTML.HTMLInputElement)?.value = "1"
        return
      }
      let valStr = input.inputValue
      var page = 0
      var hasDigit = false
      for ch in valStr.utf8 {
        guard ch >= 48 && ch <= 57 else { continue }
        hasDigit = true
        page = page * 10 + Int(ch - 48)
      }
      // Invalid (empty, 0, non-numeric): snap input back to the current page (1-based)
      if !hasDigit || page < 1 {
        (input as? HTML.HTMLInputElement)?.value = "\(canvasIndex + 1)"
        return
      }
      // Clamp to [1, total]
      if page > total { page = total }
      let idx = page - 1
      if idx == canvasIndex {
        // Already on this page — still normalize display (e.g. leading zeros, overshoot clamp)
        (input as? HTML.HTMLInputElement)?.value = "\(page)"
        return
      }
      loadCanvas(idx)
    }

    private static func artifactImageURL(serviceID: String, width: Int, height: Int, dprOverride: Double? = nil) -> String {
      let base = stringEndsWith(serviceID, "/") ? stringSubstring(serviceID, from: 0, to: serviceID.utf8.count - 1) : serviceID
      let dpr = dprOverride ?? (window.devicePixelRatio > 0 ? window.devicePixelRatio : 2.0)
      let displayedW = Double(width) * zoom
      let reqW = min(width, max(64, Int(displayedW * dpr)))
      return "\(base)/full/\(reqW),/0/default.\(TileCompositor.format)"
    }

    private static func setupGestures() {
      guard let vp = viewport else { return }

      vp.addEventListener(.mousedown) { e in
        e.preventDefault()
        isDragging = true
        dragStartX = e.clientX
        dragStartY = e.clientY
        dragPanX = panX
        dragPanY = panY
        vp.setAttribute(data("dragging"), "true")
      }

      window.addEventListener(.mousemove) { e in
        guard isDragging else { return }
        panX = dragPanX + (e.clientX - dragStartX)
        panY = dragPanY + (e.clientY - dragStartY)
        clampPan()
        updateTransform()
      }

      window.addEventListener(.mouseup) { _ in
        isDragging = false
        vp.setAttribute(data("dragging"), "false")
        if zoom <= minZoom + 0.001 {
          snapToHorizontalCenter()
          updateTransform()
        }
      }

      vp.addEventListener(.wheel) { e in
        e.preventDefault()
        // Proportional to deltaY magnitude, capped so mouse wheel isn't too fast
        let delta = max(-40.0, min(40.0, e.deltaY))
        let dz = 1.0 - delta * 0.005
        let cx = e.clientX - (viewport?.getBoundingClientRect()?.x ?? 0)
        let cy = e.clientY - (viewport?.getBoundingClientRect()?.y ?? 0)
        let newZoom = max(minZoom, min(8.0, zoom * dz))
        panX = cx - (cx - panX) * (newZoom / zoom)
        panY = cy - (cy - panY) * (newZoom / zoom)
        zoom = newZoom
        clampPan()
        updateTransform()
      }

      prevBtn?.addEventListener(.click) { _ in navigate(-1) }
      nextBtn?.addEventListener(.click) { _ in navigate(1) }

      root?.querySelector("#artifact-fullscreen-btn")?.addEventListener(.click) { _ in
        if document.isFullscreen {
          document.exitFullscreen()
        } else {
          root?.requestFullscreen()
        }
      }

      _ = document.addEventListener(.fullscreenchange) { _ in
        guard Self.canvasIndex < Self.imageWidths.count else { return }
        Self.fitToViewport(imageW: Double(Self.imageWidths[Self.canvasIndex]), imageH: Double(Self.imageHeights[Self.canvasIndex]))
        TileCompositor.update(panX: Self.panX, panY: Self.panY, zoom: Self.zoom, viewportW: Self.viewportW, viewportH: Self.viewportH)
      }

      pageInput?.addEventListener(.keydown) { e in
        let key = e.key
        let isDigit = key.utf8.count == 1 && (key.utf8.first.map { $0 >= 48 && $0 <= 57 } ?? false)
        let allowed = isDigit || stringEquals(key, "Enter") || stringEquals(key, "Backspace")
          || stringEquals(key, "Delete") || stringEquals(key, "Tab")
          || stringEquals(key, "ArrowLeft") || stringEquals(key, "ArrowRight")
          || stringEquals(key, "ArrowUp") || stringEquals(key, "ArrowDown")
        if !allowed { e.preventDefault(); return }
        if stringEquals(key, "ArrowLeft") || stringEquals(key, "ArrowRight") {
          e.stopPropagation()
        }
        if stringEquals(key, "Enter") {
          commitPageInput()
          pageInput?.blur()
        }
      }
      pageInput?.addEventListener(.change) { _ in commitPageInput() }
      pageInput?.addEventListener(.blur) { _ in
        // Always re-validate on blur (0, empty, or out-of-range → current page, min 1)
        commitPageInput()
      }

      window.addEventListener(.keydown) { e in
        if stringEquals(e.key, "ArrowLeft") { navigate(-1) }
        if stringEquals(e.key, "ArrowRight") { navigate(1) }
      }
    }

    /// Where an image service sits in this manifest, if it is in it at all.
    private static func canvasIndex(ofService service: String) -> Int? {
      guard !stringIsEmpty(service) else { return nil }
      for (index, id) in serviceIDs.enumerated() where stringEquals(id, service) {
        return index
      }
      return nil
    }

    /// The reading of the canvas on screen, and only that one.
    ///
    /// A pane names the image service it reads, not a page number, because the
    /// two orders are written by different hands: the manifest is the library's
    /// and the reading is the transcriber's. Matching on the service id means a
    /// reading that skips a canvas still lands on the right one; a pane that
    /// names nothing the manifest has simply never shows.
    private static func showReading(for index: Int) {
      guard !readingPanes.isEmpty else { return }
      let service = index < serviceIDs.count ? serviceIDs[index] : ""
      var matched = false
      for pane in readingPanes {
        let id = pane.dataset["service-id"] ?? ""
        let isActive = !stringIsEmpty(service) && stringEquals(id, service)
        if isActive { matched = true }
        pane.setAttribute(data("active"), isActive ? "true" : "false")
      }
      // No pane names this canvas: fall back to the transcriber's order, which
      // is right whenever the two sequences run together.
      if !matched {
        for (position, pane) in readingPanes.enumerated() {
          pane.setAttribute(data("active"), position == index ? "true" : "false")
        }
      }
      // Whoever drew the reading may have work to do when it changes — syntax
      // colouring a page of markup, say, which is worth doing for the page on
      // screen and wasteful for the nine hundred behind it.
      root?.dispatchEvent(CustomEvent(type: "artifact-canvas-change", detail: service))
    }

    private static func navigate(_ delta: Int) {
      let next = canvasIndex + delta
      guard next >= 0, next < serviceIDs.count else { return }
      loadCanvas(next)
    }

  }
#endif
