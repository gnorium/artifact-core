#if SERVER
  import CSSBuilder
  import DesignTokens
  import DOMBuilder
  import HTMLBuilder
  import WebComponents
  import WebTypes

  public struct ArtifactView: HTMLContent {
    let testamentURL: String
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
    /// What the switch is for, behind an ⓘ beside it, where the page needs to
    /// say — an editor that takes its edits in the source says so here.
    let sourceSwitchInfo: String?

    public init(
      testamentURL: String,
      title: String? = nil,
      authors: [String] = [],
      style: CSSStyle = .default,
      startCanvas: Int? = nil,
      startService: String? = nil,
      sourceSwitch: Bool = false,
      sourceSwitchInfo: String? = nil,
      @HTMLBuilder reading: () -> [DOM.Node] = { [] }
    ) {
      self.testamentURL = testamentURL
      self.title = title
      self.authors = authors
      self.style = style
      self.startCanvas = startCanvas
      self.startService = startService
      self.sourceSwitch = sourceSwitch
      self.sourceSwitchInfo = sourceSwitchInfo
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
          // The switch between the reading and the source it was made from.
          // First in the row, so it sits at the top left beside the reading it
          // changes: the title block grows to fill and would push it right.
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
            if let info = sourceSwitchInfo {
              TooltipView(tooltip: info, class: "artifact-source-info") {
                IconView(icon: { size in [InfoIconView(width: size, height: size)] }, size: .small)
              }
            }
          }
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
            // The page turns live here, with the number they change. Overlaid
            // on the object they sat halfway down a tall image, far from the
            // reading, and read as controls for the picture rather than the
            // page.
            showControls: true,
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
          // The reading first, the object beside it.
          //
          // The reading is what the page is for: it arrives with the document,
          // it carries the figures cut from the facsimile inline, and it is
          // what a reader reads. The object corroborates it — you look across
          // when you doubt a word. Putting the image first made the thing being
          // checked come before the thing being read, and on a narrow screen it
          // pushed the reading below the fold entirely.
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

          // The object, with its own page turns on its own edges: the arrows
          // belong to the thing being paged, not to the reading of it.
          div {
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

          }
          .class("artifact-object")
        }
        .id("artifact-viewer-container")
        .class("artifact-viewer-container")

        // ── Footer ───────────────────────────────────────────────────────────
        footer {
          span {}
            .id("artifact-canvas-label")
            .class("artifact-canvas-label")

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
      .data("testament-url", testamentURL)
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
        // Beside the switch it explains, no nearer than the switch sits to
        // the title: the header's own gap.
        descendant(".artifact-source-info") {
          flexShrink(0)
          display(.inlineFlex)
          alignItems(.center)
        }
        descendant(".artifact-viewer-container") {
          flex(1)
          display(.flex)
          position(.relative)
          width(perc(100))
          minWidth(0)
          maxWidth(perc(100))
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
          overflow(.auto)
          padding(spacing16)
          // The divider sits on the reading's far edge, because the reading
          // comes first: to its right when the two are side by side, under it
          // when they stack. It used to be a leading border, from when the
          // object led and the reading sat to its right.
          borderInlineEnd(borderWidthBase, .solid, borderColorSubtle)
          backgroundColor(backgroundColorBase)
          media(maxWidth(maxWidthBreakpointMobile)) {
            borderInlineEnd(.none).important()
            borderBlockEnd(borderWidthBase, .solid, borderColorSubtle).important()
          }
        }
        // The switch is in the header and the layers are in the pane, so the
        // rule that ties them lives on the viewer, where both are in scope.
        selector("&:has(.artifact-source-toggle[aria-pressed='true']) .artifact-reading [data-reading-layer='text']") {
          display(.none)
        }
        // Flex, not block: a layer holding one element also holds the
        // whitespace around it in the markup, and a block container turns that
        // into a line box above and below — a gap that looks like padding
        // nobody asked for. A flex container drops whitespace-only children.
        selector("&:has(.artifact-source-toggle[aria-pressed='true']) .artifact-reading [data-reading-layer='source']") {
          display(.flex)
          flexDirection(.column)
          width(perc(100))
          minWidth(0)
          maxWidth(perc(100))
          // The reading pane owns both scrollbars. Giving this layer an
          // overflow value creates a second vertical scroller in Raw mode.
          overflow(.visible)
        }
        // Raw XML is intentionally preformatted and can contain very long
        // lines. Let it contribute overflow to `.artifact-reading`, which is
        // the single scroll owner for the entire reading half.
        descendant(".artifact-reading [data-reading-layer='source'] .source-view") {
          width(perc(100))
          minWidth(0)
          maxWidth(perc(100))
          overflow(.visible)
        }
        descendant(".artifact-reading [data-reading-layer='source'] .source-view-code") {
          // A long XML token is paint overflow, not the intrinsic width of
          // the accordion row. The outer reading pane provides its horizontal
          // scrollbar.
          flexShrink(1)
          minWidth(0)
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

    /// One reader per viewer: a page may hold several (a record's rows each
    /// load their own), and a form may swap its viewer for another.
    private var readers: [ArtifactReader] = []

    public static func hydrateIfPresent() {
      guard document.querySelector(".artifact-view") != nil
      else { return }
      hydrate(in: document.body)
    }

    public init() {}

    /// The viewers under `root`, which may be a fragment swapped in after the
    /// page's own pass. A viewer already reading is left alone, and a reader
    /// whose viewer has left the document lets go of the window it listened
    /// to — its arrow keys would otherwise turn the pages of nothing.
    public static func hydrate(in root: DOM.Element) {
      let hydration = instance ?? ArtifactHydration()
      instance = hydration
      hydration.readers = hydration.readers.filter { reader in
        if reader.isInDocument { return true }
        reader.detach()
        return false
      }
      for viewer in root.querySelectorAll(".artifact-view") {
        guard !stringEquals(viewer.dataset["artifact-hydrated"] ?? "false", "true") else { continue }
        let testamentURL = viewer.dataset["testament-url"] ?? ""
        // An empty viewer — a form with nothing chosen yet — has nothing to read.
        guard !stringIsEmpty(testamentURL) else { continue }
        viewer.setAttribute(data("artifact-hydrated"), "true")
        hydration.readers.append(
          ArtifactReader(
            root: viewer,
            testamentURL: testamentURL,
            startCanvas: parseInt(viewer.dataset["start-canvas"] ?? ""),
            startService: viewer.dataset["start-service"] ?? ""
          ))
      }
    }
  }

  /// One viewer, reading one testament. An instance, not a namespace: a
  /// page may hold several viewers, and a second one used to take over the
  /// first's state — its canvases appended to the first's list and its pages
  /// turned by the first's arrows.
  private final class ArtifactReader: @unchecked Sendable {
    private var viewport: DOM.Element?

    private var pageInput: DOM.Element?
    private var pageTotal: DOM.Element?
    private var canvasLabelEl: DOM.Element?
    private var prevBtn: DOM.Element?
    private var nextBtn: DOM.Element?

    private var serviceIDs: [String] = []
    private var imageWidths: [Int] = []
    private var imageHeights: [Int] = []
    private var canvasLabels: [String] = []
    private var canvasIndex: Int = 0

    private var zoom: Double = 1.0
    private var panX: Double = 0
    private var panY: Double = 0

    private var isDragging = false
    private var dragStartX: Double = 0
    private var dragStartY: Double = 0
    private var dragPanX: Double = 0
    private var dragPanY: Double = 0

    private var viewportW: Double = 0
    private var viewportH: Double = 0

    private var testamentURL: String = ""
    /// The canvas the page asked for, which outranks the one this reader was
    /// last on: a link to a page of the object means that page.
    private var startCanvas: Int?
    private var startService: String = ""
    private var readingPanes: [DOM.Element] = []

    private func storageKey() -> String { "gnorium:artifact-canvas:\(testamentURL)" }
    private func saveCanvasIndex() { localStorage.setItem(storageKey(), "\(canvasIndex)") }
    private func savedCanvasIndex() -> Int {
      parseInt(localStorage.getItem(storageKey()) ?? "") ?? 0
    }

    /// The window and document listeners, so a reader whose viewer has left
    /// the page can let go of them.
    private var mouseMoveListener: Int32 = -1
    private var mouseUpListener: Int32 = -1
    private var keyDownListener: Int32 = -1
    private var fullscreenListener: Int32 = -1
    private var compositor: TileCompositor?
    private let root: DOM.Element

    /// Whether the viewer is still on the page. A form that swaps its body
    /// takes the old viewer with it, and nothing tells the reader.
    var isInDocument: Bool { document.body.contains(root) }

    /// Let go of everything outside the viewer. The viewer's own listeners
    /// went with it; the window's and the document's did not.
    func detach() {
      window.removeEventListener(.mousemove, mouseMoveListener)
      window.removeEventListener(.mouseup, mouseUpListener)
      window.removeEventListener(.keydown, keyDownListener)
      document.removeEventListener(.fullscreenchange, fullscreenListener)
      compositor?.detach()
    }

    init(
      root: DOM.Element,
      testamentURL: String,
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
      // The page turns are the pager's buttons now; the ids are kept so a
      // caller that still renders its own arrows keeps working.
      prevBtn =
        root.querySelector("#artifact-prev") ?? root.querySelector(".pagination-prev")
      nextBtn =
        root.querySelector("#artifact-next") ?? root.querySelector(".pagination-next")

      if let vp, let spinner = root.querySelector("#artifact-spinner") {
        compositor = TileCompositor(viewport: vp, spinner: spinner)
      }

      // Recenter + reload tiles whenever the viewport resizes (sidebar toggle, window resize, etc.)
      // Guard against spurious ResizeObserver callbacks triggered by scroll in some browsers
      vp?.observeResize { [self] w, h in
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

      self.testamentURL = testamentURL
      setupGestures()
      setupLayers()
      loadManifest(url: testamentURL)
    }

    /// The source switch changes the reading, not the image viewport.  Keep
    /// that state in the hydrated view instead of relying on `:has()`: that
    /// selector is not consistently reevaluated when `aria-pressed` changes
    /// in every browser context that hosts the reader.
    ///
    /// A reading with a translation follows its page's language switch too,
    /// which is not the viewer's: the page sets `data-reading-translated` on
    /// an ancestor and tells each viewer with a `reading-translated` event.
    /// A viewer fetched in after the switch was pressed reads the attribute
    /// as it stands.
    private func setupLayers() {
      let source = root.querySelector(".artifact-source-toggle")
      if case .some = root.querySelector(".artifact-reading [data-reading-layer='translation']") {
        translatable = true
      }
      sourceVisible = stringEquals(source?.getAttribute("aria-pressed") ?? "false", "true")
      translationVisible = stringEquals(
        root.closest("[data-reading-translated]")?.getAttribute(data("reading-translated")) ?? "false", "true")
      showLayers()
      _ = source?.addEventListener("toggle-button-update") { [self] (event: Event) in
        self.sourceVisible = stringEquals(event.detail, "true")
        self.showLayers()
      }
      _ = root.addEventListener("reading-translated") { [self] (event: Event) in
        self.translationVisible = stringEquals(event.detail, "true")
        self.showLayers()
      }
    }

    private var sourceVisible = false
    private var translationVisible = false
    /// Whether the reading has a translated layer to show at all.
    private var translatable = false

    /// The one layer of the reading that shows: the translated one while the
    /// page's language switch is on, else the source while Raw is on, else
    /// the reading.
    private func showLayers() {
      let layer = translatable && translationVisible ? "translation" : sourceVisible ? "source" : "text"
      for text in root.querySelectorAll(".artifact-reading [data-reading-layer='text']") {
        if stringEquals(layer, "text") { text.style.display(.block) } else { text.style.display(.none) }
      }
      for source in root.querySelectorAll(".artifact-reading [data-reading-layer='source']") {
        if stringEquals(layer, "source") { source.style.display(.flex) } else { source.style.display(.none) }
      }
      for translated in root.querySelectorAll(".artifact-reading [data-reading-layer='translation']") {
        if stringEquals(layer, "translation") { translated.style.display(.flex) } else { translated.style.display(.none) }
      }
    }

    private func loadManifest(url: String) {
      root.fetch(url) { [self] jsonStr in
        guard let jsonStr else { return }
        parseManifest(jsonStr)
        let asked = canvasIndex(ofService: startService) ?? startCanvas ?? savedCanvasIndex()
        let opening = max(0, min(asked, serviceIDs.count - 1))
        canvasIndex = opening
        updateUI()
        loadCanvas(opening)
      }
    }

    private func parseManifest(_ json: String) {
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
    private func loadCanvas(_ idx: Int) {
      guard idx >= 0, idx < serviceIDs.count else { return }
      canvasIndex = idx
      saveCanvasIndex()
      updateUI()
      let w = imageWidths[idx]
      let h = imageHeights[idx]
      fitToViewport(imageW: Double(w), imageH: Double(h))
      compositor?.showSpinner()
      compositor?.setCanvas(serviceID: serviceIDs[idx], width: w, height: h)
      compositor?.update(panX: panX, panY: panY, zoom: zoom, viewportW: viewportW, viewportH: viewportH)
      preloadWindow(around: idx)
    }

    private func preloadWindow(around idx: Int) {
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

    private var minZoom: Double = 0.01

    private func fitToViewport(imageW: Double, imageH: Double) {
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

    private func clampPan() {
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

    private func snapToHorizontalCenter() {
      guard canvasIndex < imageWidths.count else { return }
      let iw = Double(imageWidths[canvasIndex]) * zoom
      panX = (viewportW - iw) / 2
    }

    private func updateTransform() {
      compositor?.update(panX: panX, panY: panY, zoom: zoom, viewportW: viewportW, viewportH: viewportH)
    }

    private func updateUI() {
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
      // The property AND the class. The pager greys itself with
      // `pagination-disabled`, so setting only the property left a working
      // button that looked dead — which is worse than a dead one.
      setPageTurn(prevBtn, disabled: canvasIndex <= 0)
      setPageTurn(nextBtn, disabled: canvasIndex >= total - 1)
    }

    /// A page turn's enabled state, on the property and in the class.
    ///
    /// The pager greys itself with `pagination-disabled`, so setting only the
    /// property left a working button that looked dead — worse than a dead one,
    /// because nobody presses it.
    private func setPageTurn(_ button: DOM.Element?, disabled: Bool) {
      guard let button else { return }
      button.setDisabled(disabled)
      // Which turn it is, read off the button rather than passed in: a caller
      // that passes the wrong one produces a button styled as its opposite.
      let base = stringContains(button.getAttribute(.class) ?? "", "pagination-next")
        ? "pagination-next" : "pagination-prev"
      button.setAttribute(.class, disabled ? "\(base) pagination-disabled" : base)
    }

    private func commitPageInput() {
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

    private func artifactImageURL(serviceID: String, width: Int, height: Int, dprOverride: Double? = nil) -> String {
      let base = stringEndsWith(serviceID, "/") ? stringSubstring(serviceID, from: 0, to: serviceID.utf8.count - 1) : serviceID
      let dpr = dprOverride ?? (window.devicePixelRatio > 0 ? window.devicePixelRatio : 2.0)
      let displayedW = Double(width) * zoom
      let reqW = min(width, max(64, Int(displayedW * dpr)))
      return "\(base)/full/\(reqW),/0/default.\(compositor?.format ?? TileCompositor.defaultFormat)"
    }

    private func setupGestures() {
      guard let vp = viewport else { return }

      vp.addEventListener(.mousedown) { [self] e in
        e.preventDefault()
        isDragging = true
        dragStartX = e.clientX
        dragStartY = e.clientY
        dragPanX = panX
        dragPanY = panY
        vp.setAttribute(data("dragging"), "true")
      }

      mouseMoveListener = window.addEventListener(.mousemove) { [self] e in
        guard isDragging else { return }
        panX = dragPanX + (e.clientX - dragStartX)
        panY = dragPanY + (e.clientY - dragStartY)
        clampPan()
        updateTransform()
      }

      mouseUpListener = window.addEventListener(.mouseup) { [self] _ in
        isDragging = false
        vp.setAttribute(data("dragging"), "false")
        if zoom <= minZoom + 0.001 {
          snapToHorizontalCenter()
          updateTransform()
        }
      }

      vp.addEventListener(.wheel) { [self] e in
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

      prevBtn?.addEventListener(.click) { [self] _ in navigate(-1) }
      nextBtn?.addEventListener(.click) { [self] _ in navigate(1) }

      root.querySelector("#artifact-fullscreen-btn")?.addEventListener(.click) { [self] _ in
        if document.isFullscreen {
          document.exitFullscreen()
        } else {
          root.requestFullscreen()
        }
      }

      fullscreenListener = document.addEventListener(.fullscreenchange) { [self] _ in
        guard self.canvasIndex < self.imageWidths.count else { return }
        self.fitToViewport(imageW: Double(self.imageWidths[self.canvasIndex]), imageH: Double(self.imageHeights[self.canvasIndex]))
        compositor?.update(panX: self.panX, panY: self.panY, zoom: self.zoom, viewportW: self.viewportW, viewportH: self.viewportH)
      }

      pageInput?.addEventListener(.keydown) { [self] e in
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
      pageInput?.addEventListener(.change) { [self] _ in commitPageInput() }
      pageInput?.addEventListener(.blur) { [self] _ in
        // Always re-validate on blur (0, empty, or out-of-range → current page, min 1)
        commitPageInput()
      }

      keyDownListener = window.addEventListener(.keydown) { [self] e in
        if stringEquals(e.key, "ArrowLeft") { navigate(-1) }
        if stringEquals(e.key, "ArrowRight") { navigate(1) }
      }
    }

    /// Where an image service sits in this manifest, if it is in it at all.
    private func canvasIndex(ofService service: String) -> Int? {
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
    private func showReading(for index: Int) {
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
      root.dispatchEvent(CustomEvent(type: "artifact-canvas-change", detail: service))
    }

    private func navigate(_ delta: Int) {
      let next = canvasIndex + delta
      guard next >= 0, next < serviceIDs.count else { return }
      loadCanvas(next)
    }

  }
#endif
