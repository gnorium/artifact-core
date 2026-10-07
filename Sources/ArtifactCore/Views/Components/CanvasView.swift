#if SERVER
  import CSSBuilder
  import DesignTokens
  import DOMBuilder
  import HTMLBuilder
  import WebComponents
  import WebTypes

  /// One image, on a surface it can be panned and zoomed on: the image
  /// service it names is read in tiles, a low-resolution copy first and the
  /// detail the zoom asks for over it.
  ///
  /// Drawn empty. Nothing is fetched until the canvas is shown
  /// (`CanvasReader.show(width:height:)`), and a canvas put away lets go of
  /// its tiles, so a viewer holding four hundred canvases reads one image at
  /// a time. ``ArtifactView`` takes canvases in its canvas slot and shows the
  /// one whose `data-service-id` is the canvas on screen.
  public struct CanvasView: HTMLContent {
    /// The image service the canvas reads, as a manifest names it.
    let serviceID: String
    /// Whether it is the canvas shown before the viewer is hydrated.
    let active: Bool

    public init(serviceID: String, active: Bool = false) {
      self.serviceID = serviceID
      self.active = active
    }

    public func build() -> DOM.Node {
      div {
        div {
          // Shown while the image loads, hidden once it has.
          div {
            RotatingSectorView(ariaHidden: true)
          }
          .class("canvas-spinner")
          .data("visible", "false")
        }
        .class("canvas-viewport")
        .data("dragging", "false")
      }
      .class("canvas-view")
      .data("service-id", serviceID)
      .data("active", active ? "true" : "false")
      .style {
        selector("&") {
          display(.flex)
          flexDirection(.column)
          flex(1)
          minWidth(0)
          minHeight(0)
          position(.relative)
          overflow(.hidden)
        }
        // Explicit flex(1) and a zero minimum height make flex size it to
        // the room it has, not to the image.
        descendant(".canvas-viewport") {
          width(perc(100))
          flex(1)
          minHeight(0)
          overflow(.hidden)
          position(.relative)
          cursor(.grab)
          userSelect(.none)
        }
        descendant(".canvas-viewport[data-dragging='true']") { cursor(.grabbing) }
        descendant(".canvas-spinner") {
          display(.none)
          position(.absolute)
          inset(0)
          zIndex(5)
          alignItems(.center)
          justifyContent(.center)
          backgroundColor(backgroundColorBase)
        }
        descendant(".canvas-spinner[data-visible='true']") { display(.flex) }
        descendant(".canvas-tile-surface") {
          position(.absolute)
          inset(0)
          overflow(.visible)
        }
        descendant(".canvas-tile-compositor") {
          transformOrigin(px(0), px(0))
          willChange(.transform)
        }
        descendant(".canvas-tile-image[data-loaded='false']") { opacity(0) }
        descendant(".canvas-tile-image[data-loaded='true']") { opacity(1) }
      }
    }
  }
#endif

#if CLIENT
  import DOMBuilder
  import EmbeddedSwiftUtilities
  import HTMLBuilder
  import WebAPIs
  import WebComponents
  import WebTypes

  /// One canvas, read: its tiles, its zoom and pan, the gestures that change
  /// them. Made by the viewer the first time the canvas is shown.
  final class CanvasReader: @unchecked Sendable {
    let root: DOM.Element
    let serviceID: String
    private var viewport: DOM.Element?
    private var compositor: TileCompositor?

    private var imageW = 0
    private var imageH = 0
    private var zoom: Double = 1.0
    private var minZoom: Double = 0.01
    private var panX: Double = 0
    private var panY: Double = 0
    private var viewportW: Double = 0
    private var viewportH: Double = 0

    private var dragStartX: Double = 0
    private var dragStartY: Double = 0
    private var dragPanX: Double = 0
    private var dragPanY: Double = 0
    /// The window's listeners while a drag is under way, and only then.
    private var mouseMoveListener: Int32 = -1
    private var mouseUpListener: Int32 = -1

    init(root: DOM.Element) {
      self.root = root
      serviceID = root.dataset["service-id"] ?? ""
      let vp = root.querySelector(".canvas-viewport")
      viewport = vp
      if let vp, let spinner = root.querySelector(".canvas-spinner") {
        compositor = TileCompositor(viewport: vp, spinner: spinner)
      }
      // Recenter whenever the viewport resizes (a sidebar toggled, the window
      // resized). A canvas put away measures nothing, and some browsers call
      // back on scroll with the size unchanged.
      vp?.observeResize { [self] w, h in
        guard w > 0, h > 0 else { return }
        guard w != viewportW || h != viewportH else { return }
        viewportW = w
        viewportH = h
        guard imageW > 0, imageH > 0 else { return }
        panX = (viewportW - Double(imageW) * zoom) / 2
        panY = (viewportH - Double(imageH) * zoom) / 2
        clampPan()
        updateTransform()
      }
      setupGestures()
    }

    /// A canvas drawn here rather than by the page: one the manifest has
    /// and the page drew none for.
    static func make(serviceID: String) -> DOM.Element {
      let canvas = document.createElement(.div)
      canvas.className = "canvas-view"
      canvas.setAttribute(data("service-id"), serviceID)
      canvas.setAttribute(data("active"), "false")
      let viewport = document.createElement(.div)
      viewport.className = "canvas-viewport"
      viewport.setAttribute(data("dragging"), "false")
      let spinner = document.createElement(.div)
      spinner.className = "canvas-spinner"
      spinner.setAttribute(data("visible"), "false")
      spinner.appendChild(RotatingSectorFactory.createElement())
      viewport.appendChild(spinner)
      canvas.appendChild(viewport)
      return canvas
    }

    /// The image, fitted to the viewport: its low-resolution copy, then the
    /// detail the fit asks for.
    func show(width: Int, height: Int) {
      imageW = width
      imageH = height
      fitToViewport()
      compositor?.showSpinner()
      compositor?.setCanvas(serviceID: serviceID, width: width, height: height)
      updateTransform()
    }

    /// Put away: its tiles go, so only the canvas on screen holds images.
    /// The browser keeps what it fetched, and showing it again is quick.
    func hide() {
      compositor?.clear()
      endDrag()
    }

    /// Fitted again, the viewport having changed its size (fullscreen).
    func refit() {
      guard imageW > 0, imageH > 0 else { return }
      fitToViewport()
      updateTransform()
    }

    /// Let go of everything outside the canvas.
    func detach() {
      endDrag()
      compositor?.detach()
    }

    /// What showing a canvas fetches first, fetched ahead for a canvas next
    /// to the one on screen: its low-resolution copy, and the image at the
    /// size the one on screen is fitted to.
    static func preload(serviceID: String, width: Int, zoom: Double) {
      let base = stringEndsWith(serviceID, "/") ? stringSubstring(serviceID, from: 0, to: serviceID.utf8.count - 1) : serviceID
      let format = TileCompositor.format(forService: base)
      let fitted = min(width, max(64, Int(Double(width) * zoom)))
      preloadImages(urls: [
        "\(base)/full/256,/0/default.\(format)",
        "\(base)/full/\(fitted),/0/default.\(format)",
      ])
    }

    /// The zoom that fits this canvas to its viewport, which a neighbor's
    /// preload borrows.
    var fittedZoom: Double { minZoom }

    private func fitToViewport() {
      guard let vp = viewport, let rect = vp.getBoundingClientRect() else { return }
      viewportW = rect.width > 0 ? rect.width : 900
      viewportH = rect.height > 0 ? rect.height : 500
      let imageW = Double(self.imageW)
      let imageH = Double(self.imageH)
      minZoom = min(viewportW / imageW, viewportH / imageH)
      zoom = minZoom
      panX = (viewportW - imageW * zoom) / 2
      panY = (viewportH - imageH * zoom) / 2
    }

    private func clampPan() {
      let iw = Double(imageW) * zoom
      let ih = Double(imageH) * zoom
      // Smaller than the viewport: centered, no panning. Larger: no empty
      // gap at any edge.
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

    private func updateTransform() {
      compositor?.update(panX: panX, panY: panY, zoom: zoom, viewportW: viewportW, viewportH: viewportH)
    }

    private func endDrag() {
      if mouseMoveListener >= 0 { window.removeEventListener(.mousemove, mouseMoveListener) }
      if mouseUpListener >= 0 { window.removeEventListener(.mouseup, mouseUpListener) }
      mouseMoveListener = -1
      mouseUpListener = -1
      viewport?.setAttribute(data("dragging"), "false")
    }

    private func setupGestures() {
      guard let vp = viewport else { return }

      vp.addEventListener(.mousedown) { [self] e in
        e.preventDefault()
        endDrag()
        dragStartX = e.clientX
        dragStartY = e.clientY
        dragPanX = panX
        dragPanY = panY
        vp.setAttribute(data("dragging"), "true")
        mouseMoveListener = window.addEventListener(.mousemove) { [self] e in
          panX = dragPanX + (e.clientX - dragStartX)
          panY = dragPanY + (e.clientY - dragStartY)
          clampPan()
          updateTransform()
        }
        mouseUpListener = window.addEventListener(.mouseup) { [self] _ in
          endDrag()
          if zoom <= minZoom + 0.001 {
            // Fitted: back to the middle, however it was dragged.
            panX = (viewportW - Double(imageW) * zoom) / 2
            updateTransform()
          }
        }
      }

      vp.addEventListener(.wheel) { [self] e in
        e.preventDefault()
        guard imageW > 0, imageH > 0 else { return }
        // Proportional to the wheel's travel, capped so a mouse wheel is not
        // too fast.
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
    }
  }
#endif
