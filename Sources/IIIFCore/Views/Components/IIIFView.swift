#if SERVER
  import CSSBuilder
  import CSSOMBuilder
  import DesignTokens
  import DOMBuilder
  import HTMLBuilder
  import WebTypes

  public struct IIIFView: HTMLContent {
    let manifestURL: String
    let style: CSSStyle

    public init(manifestURL: String, style: CSSStyle = .default) {
      self.manifestURL = manifestURL
      self.style = style
    }

    public func build() -> Node {
      div {
        header {
          span().id("iiif-title")
            .fontFamily(typographyFontSans.value as String)
            .fontSize(fontSizeMedium16.value as String)
            .fontWeight(fontWeightBold.value as String)
            .color(colorBase)
          span().id("iiif-canvas-label")
            .fontFamily(typographyFontSans.value as String)
            .fontSize(fontSizeXSmall12.value as String)
            .color(colorSubtle)
            .marginLeft(12)
        }
        .style {
          display(.flex)
          alignItems(.center)
          padding(12, 16)
          borderBlockEnd(borderWidthBase, .solid, borderColorSubtle)
          backgroundColor(backgroundColorSecondary)
        }

        div {
          div {
            div()
              .id("iiif-viewport")
              .style {
                width(100.percent)
                height(100.percent)
                overflow(.hidden)
                position(.relative)
                cursor("grab")
                backgroundColor(fillGrayQuaternaryAlpha)
              }
          }
          .id("iiif-viewer-container")
          .style {
            flex(1)
            position(.relative)
            overflow(.hidden)
          }
        }
        .id("iiif-viewer-body")
        .style {
          display(.flex)
          flexDirection(.column)
          flex(1)
          minWidth(0)
        }

        footer {
          div {
            button().id("iiif-prev").disabled(true)
              .fontFamily(typographyFontSans.value as String)
              .fontSize(fontSizeXSmall12.value as String)
            span().id("iiif-page-indicator")
              .fontFamily(typographyFontMono.value as String)
              .fontSize(fontSizeXSmall12.value as String)
              .margin(0, 12)
            button().id("iiif-next").disabled(true)
              .fontFamily(typographyFontSans.value as String)
              .fontSize(fontSizeXSmall12.value as String)
          }
          .style {
            display(.flex)
            alignItems(.center)
            justifyContent(.center)
          }
          div().id("iiif-zoom-controls")
            .style {
              display(.flex)
              alignItems(.center)
              gap(4)
              marginLeft(.auto)
            }
        }
        .style {
          display(.flex)
          alignItems(.center)
          justifyContent(.spaceBetween)
          padding(8, 16)
          borderBlockStart(borderWidthBase, .solid, borderColorSubtle)
          backgroundColor(backgroundColorSecondary)
        }
      }
      .id("iiif-view")
      .data("manifest-url", manifestURL)
      .data("style", style.rawValue)
      .style {
        display(.flex)
        flexDirection(.column)
        width(100.percent)
        height(100.percent)
        borderRadius(12)
        overflow(.hidden)
        border(borderWidthBase, .solid, borderColorSubtle)
        backgroundColor(backgroundColorBase)
      }
    }
  }

  extension IIIFView {
    public enum CSSStyle: String, Sendable {
      case `default`
      case dark
      case minimal
    }
  }
#endif

#if CLIENT
  import DOMBuilder
  import WebAPIs
  import WebTypes

  public final class IIIFHydration: @unchecked Sendable {
    public init() {}

    public func hydrate() {
      guard let root = document.querySelector("#iiif-view") else { return }
      let manifestURL = root.dataset["manifest-url"] ?? ""
      guard !manifestURL.isEmpty else { return }

      Task {
        await Engine.start(
          root: root,
          manifestURL: manifestURL
        )
      }
    }
  }

  private enum Engine {
    private nonisolated(unsafe) static var root: Element?
    private nonisolated(unsafe) static var viewport: Element?
    private nonisolated(unsafe) static var imageDiv: Element?

    private nonisolated(unsafe) static var titleEl: Element?
    private nonisolated(unsafe) static var canvasLabelEl: Element?
    private nonisolated(unsafe) static var pageIndicator: Element?
    private nonisolated(unsafe) static var prevBtn: Element?
    private nonisolated(unsafe) static var nextBtn: Element?

    private nonisolated(unsafe) static var manifest: IIIFManifest?
    private nonisolated(unsafe) static var canvases: [CanvasInfo] = []
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

    struct CanvasInfo {
      let id: String
      let label: String
      let serviceID: String
      let width: Int
      let height: Int
    }

    static func start(root: Element, manifestURL: String) async {
      self.root = root
      viewport = root.querySelector("#iiif-viewport")
      titleEl = root.querySelector("#iiif-title")
      canvasLabelEl = root.querySelector("#iiif-canvas-label")
      pageIndicator = root.querySelector("#iiif-page-indicator")
      prevBtn = root.querySelector("#iiif-prev")
      nextBtn = root.querySelector("#iiif-next")

      imageDiv = viewport
      _ = imageDiv?.setInnerHTML("<div id=\"iiif-image\" style=\"position:absolute;transform-origin:0 0;will-change:transform\"></div>")
      imageDiv = viewport?.querySelector("#iiif-image")

      setupGestures()
      await loadManifest(url: manifestURL)
    }

    private static func loadManifest(url: String) async {
      root?.fetch(url) { jsonStr in
        guard let jsonStr, let data = jsonStr.data(using: .utf8) else { return }
        do {
          let m = try JSONDecoder().decode(IIIFManifest.self, from: data)
          manifest = m
          canvases = parseCanvases(m)
          canvasIndex = 0
          updateUI()
          Task { await loadCanvas(0) }
        } catch {
          print("[IIIF] Manifest parse error: \(error)")
        }
      }
    }

    private static func parseCanvases(_ m: IIIFManifest) -> [CanvasInfo] {
      guard let items = m.items else { return [] }
      return items.compactMap { canvas in
        guard let ap = canvas.items.first,
              let ann = ap.items?.first,
              let body = ann.body,
              let svc = body.service?.first,
              svc.type.contains("ImageService"),
              let w = svc.width,
              let h = svc.height
        else { return nil }
        return CanvasInfo(
          id: canvas.id,
          label: canvas.label?.best ?? "",
          serviceID: svc.id,
          width: w,
          height: h
        )
      }
    }

    private static func loadCanvas(_ idx: Int) async {
      guard idx >= 0, idx < canvases.count else { return }
      canvasIndex = idx
      updateUI()
      let ci = canvases[idx]
      fitToViewport(imageW: Double(ci.width), imageH: Double(ci.height))
      _ = imageDiv?.setStyleProperty("backgroundImage", "url(\(iiifImageURL(serviceID: ci.serviceID, width: ci.width, height: ci.height)))")
      _ = imageDiv?.setStyleProperty("backgroundSize", "\(ci.width)px \(ci.height)px")
      _ = imageDiv?.setStyleProperty("backgroundRepeat", "no-repeat")
      _ = imageDiv?.setStyleProperty("width", "\(ci.width)px")
      _ = imageDiv?.setStyleProperty("height", "\(ci.height)px")
      updateTransform()
    }

    private static func fitToViewport(imageW: Double, imageH: Double) {
      guard let vp = viewport,
            let rect = vp.getBoundingClientRect() else { return }
      viewportW = rect.width
      viewportH = rect.height
      let scaleW = viewportW / imageW
      let scaleH = viewportH / imageH
      zoom = min(scaleW, scaleH, 1.0)
      panX = (viewportW - imageW * zoom) / 2
      panY = (viewportH - imageH * zoom) / 2
    }

    private static func updateTransform() {
      let tx = "translate(\(Int(panX))px, \(Int(panY))px) scale(\(zoom))"
      _ = imageDiv?.setStyleProperty("transform", tx)
    }

    private static func updateUI() {
      let m = manifest
      _ = titleEl?.setTextContent(m?.label?.best ?? "")
      _ = canvasLabelEl?.setTextContent(canvasIndex < canvases.count ? canvases[canvasIndex].label : "")
      _ = pageIndicator?.setTextContent("\(canvasIndex + 1) / \(canvases.count)")
      _ = prevBtn?.setAttribute(.disabled, canvasIndex <= 0 ? 1 : 0)
      _ = nextBtn?.setAttribute(.disabled, canvasIndex >= canvases.count - 1 ? 1 : 0)
    }

    private static func iiifImageURL(serviceID: String, width: Int, height: Int) -> String {
      let base = serviceID.hasSuffix("/") ? String(serviceID.dropLast()) : serviceID
      let vpW = Int(viewportW > 0 ? viewportW : 800)
      let reqW = min(width, Int(Double(vpW) * zoom * (window.devicePixelRatio > 0 ? window.devicePixelRatio : 1)))
      return "\(base)/full/\(reqW),/0/default.jpg"
    }

    private static func setupGestures() {
      guard let vp = viewport else { return }

      _ = vp.addEventListener(.mousedown) { e in
        isDragging = true
        dragStartX = e.clientX
        dragStartY = e.clientY
        dragPanX = panX
        dragPanY = panY
        _ = vp.setStyleProperty("cursor", "grabbing")
      }

      _ = window.addEventListener(.mousemove) { e in
        guard isDragging else { return }
        panX = dragPanX + (e.clientX - dragStartX)
        panY = dragPanY + (e.clientY - dragStartY)
        updateTransform()
      }

      _ = window.addEventListener(.mouseup) { _ in
        isDragging = false
        _ = vp.setStyleProperty("cursor", "grab")
      }

      _ = vp.addEventListener(.wheel) { e in
        let dz = e.deltaY > 0 ? 0.9 : 1.1
        let cx = e.clientX - (viewport?.getBoundingClientRect()?.x ?? 0)
        let cy = e.clientY - (viewport?.getBoundingClientRect()?.y ?? 0)
        let newZoom = max(0.1, min(8.0, zoom * dz))
        panX = cx - (cx - panX) * (newZoom / zoom)
        panY = cy - (cy - panY) * (newZoom / zoom)
        zoom = newZoom
        updateTransform()
        Task { await refreshImage() }
      }

      _ = prevBtn?.addEventListener(.click) { _ in
        Task { await navigate(-1) }
      }
      _ = nextBtn?.addEventListener(.click) { _ in
        Task { await navigate(1) }
      }

      _ = window.addEventListener(.keydown) { e in
        if e.key == "ArrowLeft" { Task { await navigate(-1) } }
        if e.key == "ArrowRight" { Task { await navigate(1) } }
      }
    }

    private static func navigate(_ delta: Int) async {
      let next = canvasIndex + delta
      guard next >= 0, next < canvases.count else { return }
      await loadCanvas(next)
    }

    private static func refreshImage() async {
      guard canvasIndex < canvases.count else { return }
      let ci = canvases[canvasIndex]
      let url = iiifImageURL(serviceID: ci.serviceID, width: ci.width, height: ci.height)
      _ = imageDiv?.setStyleProperty("backgroundImage", "url(\(url))")
    }
  }
#endif
