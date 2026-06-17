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

    public init(manifestURL: String, title: String? = nil, authors: [String] = [], style: CSSStyle = .default) {
      self.manifestURL = manifestURL
      self.title = title
      self.authors = authors
      self.style = style
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
                .style {
                  fontWeight(fontWeightSemiBold)
                  color(colorBase)
                }
              if !headerSubtitle.isEmpty {
                span { " \(headerSubtitle)" }
                  .style { color(colorSubtle) }
              }
            }
            .style {
              fontFamily(typographyFontSans)
              fontSize(fontSizeXSmall12)
              lineHeight(1.4)
              flex(1)
              minWidth(0)
              overflow(.hidden)
              textOverflow(.ellipsis)
              whiteSpace(.nowrap)
            }
          } else {
            span().id("artifact-title").style { flex(1); minWidth(0) }
          }

          // Page nav — top right
          div {
            input()
              .type(.number)
              .id("artifact-page-input")
              .min(1)
              .max(1)
              .value("")
              .style {
                fontFamily(typographyFontMono)
                fontSize(fontSizeXSmall12)
                color(colorBase)
                fontWeight(fontWeightNormal)
                padding(spacing0, spacing4)
                border(borderWidthBase, .solid, borderColorSubtle)
                borderRadius(borderRadiusBase)
                backgroundColor(backgroundColorBase)
                height(px(20))
                textAlign(.center)
                width(calc(ch(1) + px(10)))
                transition(.width, transitionDurationBase, .ease)
                outline(.none)
                pseudoClass(.focus) {
                  borderColor(colorBlue).important()
                  boxShadow(0, 0, 0, px(2), colorBlueFocus)
                }
                boxSizing(.borderBox)
                webkitAppearance(.none)
                mozAppearance(.textfield)
                margin(0)
                pseudoElement(.webkitOuterSpinButton) {
                  webkitAppearance(.none)
                  margin(0)
                }
                pseudoElement(.webkitInnerSpinButton) {
                  webkitAppearance(.none)
                  margin(0)
                }
              }
            span { "of" }
              .style { fontSize(fontSizeXSmall12); color(colorBase) }
            span { "—" }
              .id("artifact-page-total")
              .style { fontFamily(typographyFontMono); fontSize(fontSizeXSmall12); color(colorBase) }
          }
          .style { display(.flex); alignItems(.center); gap(spacing6); flexShrink(0) }
        }
        .style {
          display(.flex)
          alignItems(.center)
          gap(spacing12)
          padding(spacing8, spacing16)
          borderBlockEnd(borderWidthBase, .solid, borderColorSubtle)
          backgroundColor(backgroundColorBase)
          minHeight(px(36))
        }

        // ── Viewer body with prev/next overlaid on edges ─────────────────────
        div {
          // Prev button — left edge overlay
          button {
            PreviousIconView(width: px(16), height: px(16))
          }
          .id("artifact-prev")
          .disabled(true)
          .style {
            position(.absolute)
            insetInlineStart(spacing8)
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

          // Viewport — explicit flex(1) + height(0) forces flex to size it correctly
          div {
            // Spinner overlay — shown while image loads, hidden when done
            div {
              ProgressIndicatorView(ariaHidden: true)
            }
            .id("artifact-spinner")
            .style {
              display(.none)
              position(.absolute)
              inset(0)
              zIndex(5)
              alignItems(.center)
              justifyContent(.center)
              backgroundColor(backgroundColorBase)
            }
          }
          .id("artifact-viewport")
          .style {
            width(perc(100))
            flex(1)
            minHeight(0)
            overflow(.hidden)
            position(.relative)
            cursor(.grab)
            userSelect(.none)
          }

          // Next button — right edge overlay
          button {
            NextIconView(width: px(16), height: px(16))
          }
          .id("artifact-next")
          .disabled(true)
          .style {
            position(.absolute)
            insetInlineEnd(spacing8)
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
        }
        .id("artifact-viewer-container")
        .style {
          flex(1)
          display(.flex)
          position(.relative)
          overflow(.hidden)
        }

        // ── Footer ───────────────────────────────────────────────────────────
        footer {
          span {}
            .id("artifact-canvas-label")
            .style {
              fontSize(fontSizeXSmall12)
              color(colorSubtle)
              flex(1)
              overflow(.hidden)
              textOverflow(.ellipsis)
              whiteSpace(.nowrap)
            }

          div().id("artifact-zoom-controls")
            .style { display(.flex); alignItems(.center); gap(spacing4) }

          button {
            IconView(icon: { size in [FullscreenIconView(width: size, height: size)] }, size: .small)
          }
          .id("artifact-fullscreen-btn")
          .style {
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
        }
        .style {
          display(.flex)
          alignItems(.center)
          gap(spacing8)
          padding(spacing8, spacing16)
          borderBlockStart(borderWidthBase, .solid, borderColorSubtle)
          backgroundColor(backgroundColorBase)
        }
      }
      .class("artifact-view")
      .data("manifest-url", manifestURL)
      .data("style", style.rawValue)
      .style {
        display(.flex)
        flexDirection(.column)
        width(perc(100))
        height(perc(100))
        borderRadius(borderRadiusBase)
        overflow(.hidden)
        border(borderWidthBase, .solid, borderColorSubtle)
        backgroundColor(backgroundColorBase)
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
      Engine.start(root: root, manifestURL: manifestURL)
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

    private static func storageKey() -> String { "gnorium:artifact-canvas:\(manifestURL)" }
    private static func saveCanvasIndex() { localStorage.setItem(storageKey(), "\(canvasIndex)") }
    private static func savedCanvasIndex() -> Int {
      parseInt(localStorage.getItem(storageKey()) ?? "") ?? 0
    }

    static func start(root: DOM.Element, manifestURL: String) {
      self.root = root
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
        let saved = min(savedCanvasIndex(), serviceIDs.count - 1)
        canvasIndex = saved
        updateUI()
        loadCanvas(saved)
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
      pageInput?.setAttribute(.value, "\(page)")
      pageInput?.setAttribute(.max, "\(total)")
      pageTotal?.textContent = "\(total)"
      var digits = 1
      var n = total
      while n >= 10 { n /= 10; digits += 1 }
      pageInput?.style.width(calc(ch(digits) + px(10)))
      let label = canvasIndex < canvasLabels.count ? canvasLabels[canvasIndex] : ""
      canvasLabelEl?.textContent = label
      prevBtn?.setDisabled(canvasIndex <= 0)
      nextBtn?.setDisabled(canvasIndex >= total - 1)
    }

    private static func commitPageInput() {
      guard let input = pageInput else { return }
      let valStr = input.inputValue
      var page = 0
      for ch in valStr.utf8 {
        guard ch >= 48 && ch <= 57 else { continue }
        page = page * 10 + Int(ch - 48)
      }
      guard page > 0 else { return }
      let idx = max(0, min(serviceIDs.count - 1, page - 1))
      guard idx != canvasIndex else { return }
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
        vp.style.cursor(.grabbing)
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
        vp.style.cursor(.grab)
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
        if stringEquals(key, "Enter") { commitPageInput() }
      }
      pageInput?.addEventListener(.change) { _ in commitPageInput() }
      pageInput?.addEventListener(.blur) { _ in
        guard let input = pageInput else { return }
        if stringIsEmpty(input.inputValue) {
          input.setAttribute(.value, "\(canvasIndex + 1)")
        }
      }

      window.addEventListener(.keydown) { e in
        if stringEquals(e.key, "ArrowLeft") { navigate(-1) }
        if stringEquals(e.key, "ArrowRight") { navigate(1) }
      }
    }

    private static func navigate(_ delta: Int) {
      let next = canvasIndex + delta
      guard next >= 0, next < serviceIDs.count else { return }
      loadCanvas(next)
    }

  }
#endif
