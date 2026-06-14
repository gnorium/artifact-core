#if SERVER
  import CSSBuilder
  import DesignTokens
  import DOMBuilder
  import HTMLBuilder
  import WebTypes

  public struct ArtifactView: HTMLContent {
    let manifestURL: String
    let style: CSSStyle

    public init(manifestURL: String, style: CSSStyle = .default) {
      self.manifestURL = manifestURL
      self.style = style
    }

    public func build() -> DOM.Node {
      div {
        header {
          span().id("artifact-title")
            .style {
              fontFamily(typographyFontSans)
              fontSize(fontSizeMedium16)
              fontWeight(fontWeightBold)
              color(colorBase)
            }
          span().id("artifact-canvas-label")
            .style {
              fontFamily(typographyFontSans)
              fontSize(fontSizeXSmall12)
              color(colorSubtle)
              marginLeft(spacing12)
            }
        }
        .style {
          display(.flex)
          alignItems(.center)
          padding(spacing12, spacing16)
          borderBlockEnd(borderWidthBase, .solid, borderColorSubtle)
          backgroundColor(backgroundColorBase)
        }

        div {
          div {
            div()
              .id("artifact-viewport")
              .style {
                width(perc(100))
                height(perc(100))
                overflow(.hidden)
                position(.relative)
                cursor(.grab)
                backgroundColor(fillGrayQuaternaryAlpha)
              }
          }
          .id("artifact-viewer-container")
          .style {
            flex(1)
            position(.relative)
            overflow(.hidden)
          }
        }
        .id("artifact-viewer-body")
        .style {
          display(.flex)
          flexDirection(.column)
          flex(1)
          minWidth(0)
        }

        footer {
          div {
            button().id("artifact-prev").disabled(true)
              .style {
                fontFamily(typographyFontSans)
                fontSize(fontSizeXSmall12)
              }
            span().id("artifact-page-indicator")
              .style {
                fontFamily(typographyFontMono)
                fontSize(fontSizeXSmall12)
                margin(spacing0, spacing12)
              }
            button().id("artifact-next").disabled(true)
              .style {
                fontFamily(typographyFontSans)
                fontSize(fontSizeXSmall12)
              }
          }
          .style {
            display(.flex)
            alignItems(.center)
            justifyContent(.center)
          }
          div().id("artifact-zoom-controls")
            .style {
              display(.flex)
              alignItems(.center)
              gap(4)
            }
        }
        .style {
          display(.flex)
          alignItems(.center)
          justifyContent(.spaceBetween)
          padding(spacing8, spacing16)
          borderBlockStart(borderWidthBase, .solid, borderColorSubtle)
          backgroundColor(backgroundColorBase)
        }
      }
      .id("artifact-view")
      .data("manifest-url", manifestURL)
      .data("style", style.rawValue)
      .style {
        display(.flex)
        flexDirection(.column)
        width(perc(100))
        height(perc(100))
        borderRadius(12)
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
    public init() {}

    public func hydrate() {
      guard let root = document.querySelector("#artifact-view") else { return }
      let manifestURL = root.dataset["manifest-url"] ?? ""
      guard !stringIsEmpty(manifestURL) else { return }
      Engine.start(root: root, manifestURL: manifestURL)
    }
  }

  private enum Engine {
    private nonisolated(unsafe) static var root: DOM.Element?
    private nonisolated(unsafe) static var viewport: DOM.Element?
    private nonisolated(unsafe) static var imageDiv: DOM.Element?

    private nonisolated(unsafe) static var titleEl: DOM.Element?
    private nonisolated(unsafe) static var canvasLabelEl: DOM.Element?
    private nonisolated(unsafe) static var pageIndicator: DOM.Element?
    private nonisolated(unsafe) static var prevBtn: DOM.Element?
    private nonisolated(unsafe) static var nextBtn: DOM.Element?

    private nonisolated(unsafe) static var serviceIDs: [String] = []
    private nonisolated(unsafe) static var imageWidths: [Int] = []
    private nonisolated(unsafe) static var imageHeights: [Int] = []
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

    static func start(root: DOM.Element, manifestURL: String) {
      self.root = root
      viewport = root.querySelector("#artifact-viewport")
      titleEl = root.querySelector("#artifact-title")
      canvasLabelEl = root.querySelector("#artifact-canvas-label")
      pageIndicator = root.querySelector("#artifact-page-indicator")
      prevBtn = root.querySelector("#artifact-prev")
      nextBtn = root.querySelector("#artifact-next")

      imageDiv = viewport
      imageDiv?.innerHTML = renderHTML {
      div().id("artifact-image")
        .style {
          position(.absolute)
          transformOrigin(px(0))
          willChange(.transform)
        }
      }
      imageDiv = viewport?.querySelector("#artifact-image")

      setupGestures()
      loadManifest(url: manifestURL)
    }

    private static func loadManifest(url: String) {
      root?.fetch(url) { jsonStr in
        guard let jsonStr else { return }
        parseManifest(jsonStr)
        canvasIndex = 0
        updateUI()
        loadCanvas(0)
      }
    }

    private static func parseManifest(_ json: String) {
      guard let label = extractJSONString(json, key: "label") else { return }
      titleEl?.textContent = label

      // Scan for canvases by splitting on "type":"Canvas"
      let parts = stringSplit(json, separator: "\"type\":\"Canvas\"")
      for part in parts {
        guard let id = extractJSONString(part, key: "id") else { continue }
        guard stringStartsWith(id, "http") || stringStartsWith(id, "/") else { continue }
        guard let width = extractJSONInt(part, key: "width") else { continue }
        guard let height = extractJSONInt(part, key: "height") else { continue }
        serviceIDs.append(id)
        imageWidths.append(width)
        imageHeights.append(height)
      }
    }
    private static func loadCanvas(_ idx: Int) {
      guard idx >= 0, idx < serviceIDs.count else { return }
      canvasIndex = idx
      updateUI()
      let serviceID = serviceIDs[idx]
      let w = imageWidths[idx]
      let h = imageHeights[idx]
      fitToViewport(imageW: Double(w), imageH: Double(h))
      let urlStr = artifactImageURL(serviceID: serviceID, width: w, height: h)
      if let img = imageDiv {
        img.style.backgroundImage(url(urlStr))
        img.style.backgroundSize(px(w), px(h))
        img.style.backgroundRepeat(.noRepeat)
        img.style.width(px(w))
        img.style.height(px(h))
      }
      updateTransform()
    }

    private static func fitToViewport(imageW: Double, imageH: Double) {
      guard let vp = viewport, let rect = vp.getBoundingClientRect() else { return }
      viewportW = rect.width
      viewportH = rect.height
      let scaleW = viewportW / imageW
      let scaleH = viewportH / imageH
      zoom = min(scaleW, scaleH, 1.0)
      panX = (viewportW - imageW * zoom) / 2
      panY = (viewportH - imageH * zoom) / 2
    }

    private static func updateTransform() {
      imageDiv?.style.transform(translate(px(panX), px(panY)), scale(zoom))
    }

    private static func updateUI() {
      canvasLabelEl?.textContent = canvasIndex < serviceIDs.count ? "" : ""
      pageIndicator?.textContent = "\(canvasIndex + 1) / \(serviceIDs.count)"
      prevBtn?.setAttribute(.disabled, canvasIndex <= 0 ? 1 : 0)
      nextBtn?.setAttribute(.disabled, canvasIndex >= serviceIDs.count - 1 ? 1 : 0)
    }

    private static func artifactImageURL(serviceID: String, width: Int, height: Int) -> String {
      let base = stringEndsWith(serviceID, "/") ? stringSubstring(serviceID, from: 0, to: serviceID.utf8.count - 1) : serviceID
      let vpW = Int(viewportW > 0 ? viewportW : 800)
      let reqW = min(width, Int(Double(vpW) * zoom * (window.devicePixelRatio > 0 ? window.devicePixelRatio : 1)))
      return "\(base)/full/\(reqW),/0/default.jpg"
    }

    private static func setupGestures() {
      guard let vp = viewport else { return }

      vp.addEventListener(.mousedown) { e in
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
        updateTransform()
      }

      window.addEventListener(.mouseup) { _ in
        isDragging = false
        vp.style.cursor(.grab)
      }

      vp.addEventListener(.wheel) { e in
        let dz = e.deltaY > 0 ? 0.9 : 1.1
        let cx = e.clientX - (viewport?.getBoundingClientRect()?.x ?? 0)
        let cy = e.clientY - (viewport?.getBoundingClientRect()?.y ?? 0)
        let newZoom = max(0.1, min(8.0, zoom * dz))
        panX = cx - (cx - panX) * (newZoom / zoom)
        panY = cy - (cy - panY) * (newZoom / zoom)
        zoom = newZoom
        updateTransform()
        refreshImage()
      }

      prevBtn?.addEventListener(.click) { _ in navigate(-1) }
      nextBtn?.addEventListener(.click) { _ in navigate(1) }

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

    private static func refreshImage() {
      guard canvasIndex < serviceIDs.count else { return }
      let serviceID = serviceIDs[canvasIndex]
      let w = imageWidths[canvasIndex]
      let h = imageHeights[canvasIndex]
      let urlStr = artifactImageURL(serviceID: serviceID, width: w, height: h)
      imageDiv?.style.backgroundImage(url(urlStr))
    }
  }
#endif
