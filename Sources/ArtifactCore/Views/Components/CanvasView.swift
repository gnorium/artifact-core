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
            RotatingRingSectorView(ariaHidden: true)
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
        // Drawing a crop box: a crosshair, not a hand.
        descendant(".canvas-viewport[data-cropping='true']") { cursor(.crosshair) }
        // A crop box over the image, and the region the markup names where
        // the caret or the pointer is: the house ring (1px border and 1px
        // outline, one color), the image seen through it.
        selector("& .canvas-crop", "& .canvas-region") {
          position(.absolute)
          boxSizing(.borderBox)
          border(borderWidthBase, .solid, colorBlue)
          outline(borderWidthBase, .solid, colorBlue)
          pointerEvents(.none)
        }
        descendant(".canvas-crop") { zIndex(5) }
        descendant(".canvas-region") { zIndex(4) }
        // The 0–1000 space drawn over the image while a region is: lines
        // every 100, 50, 10, 5 and 1, each finer level fainter and drawn
        // only once its lines stand 4px apart on screen (its gradients set
        // as the image is scaled), each 100 named along the top and the left
        // edges. Above the dim, under the region's ring.
        descendant(".canvas-grid") {
          position(.absolute)
          zIndex(3)
          pointerEvents(.none)
        }
        // The pointer's place in the 0–1000 space, beside it.
        descendant(".canvas-readout") {
          position(.absolute)
          zIndex(6)
          pointerEvents(.none)
        }
        selector("& .canvas-grid-label", "& .canvas-readout") {
          position(.absolute)
          paddingInline(spacing2)
          fontSize(fontSizeMedium16)
          lineHeight(lineHeightSmall22)
          color(colorSubtle)
          backgroundColor(backgroundColorBackdropLight)
          whiteSpace(.nowrap)
        }
        // Everything but the region dimmed, as an image editor marks a
        // selection: a backdrop over the viewport, the region (and its ring)
        // cut out of it.
        descendant(".canvas-region-dim") {
          position(.absolute)
          inset(0)
          zIndex(2)
          backgroundColor(backgroundColorBackdropDarkFixed)
          opacity(opacityMedium)
          pointerEvents(.none)
        }
        // A box's corners, each a handle a drag resizes it by (the box's
        // body moves it).
        descendant(".canvas-crop-handle") {
          position(.absolute)
          width(spacing8)
          height(spacing8)
          boxSizing(.borderBox)
          backgroundColor(backgroundColorBase)
          border(borderWidthBase, .solid, colorBlue)
          transform(translate(perc(-50), perc(-50)))
        }
        descendant(".canvas-crop-handle[data-corner='nw']") { left(px(0)); top(px(0)) }
        descendant(".canvas-crop-handle[data-corner='ne']") { left(perc(100)); top(px(0)) }
        descendant(".canvas-crop-handle[data-corner='sw']") { left(px(0)); top(perc(100)) }
        descendant(".canvas-crop-handle[data-corner='se']") { left(perc(100)); top(perc(100)) }
        descendant(".canvas-viewport[data-crop-hover='move']") { cursor(.move) }
        selector("& .canvas-viewport[data-crop-hover='nw']", "& .canvas-viewport[data-crop-hover='se']") {
          cursor(.nwseResize)
        }
        selector("& .canvas-viewport[data-crop-hover='ne']", "& .canvas-viewport[data-crop-hover='sw']") {
          cursor(.neswResize)
        }
        selector(
          "& .canvas-crop[hidden]", "& .canvas-region[hidden]", "& .canvas-region-dim[hidden]", "& .canvas-grid[hidden]",
          "& .canvas-readout[hidden]"
        ) {
          display(.none)
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

  /// How a reader's views zoom, the image's and the text's alike (user,
  /// 2026-10-12): from the fit of the whole page to its actual size, the
  /// wheel zooming in proportion to its travel. A double-click is the
  /// browser's own (it selects, and Live Text reads it): no zoom.
  enum ViewerZoom {
    /// The actual size: one pixel of the image (its full resolution), or
    /// of the text, to one CSS pixel. The most a view zooms in, unless its
    /// fit is larger still.
    static let actualSize = 1.0
    /// The session's image zoom: "fit", or a zoom.
    static let imageKey = "gnorium:artifact-zoom:image"

    /// What a view shows of its page (pane sync, a dev experiment, user
    /// 2026-10-12): the point at the view's middle as fractions of the
    /// page's width and height, and its zoom over its fit—so two views of
    /// one page, the image and its text, show the same part of it, each by
    /// its own fit.
    struct Region {
      let centerX: Double
      let centerY: Double
      let scale: Double
      /// The most its zoom over its fit can be (the image's actual size
      /// over its fit), which the text mirrors while matched.
      let maxScale: Double
    }
    /// A wheel's travel counted in one event, at most, so a mouse wheel's
    /// notch is not too fast.
    static let wheelTravel = 40.0
    /// The zoom one unit of the wheel's travel makes.
    static let wheelStep = 0.005

    /// What one wheel event multiplies the zoom by: in proportion to its
    /// travel (`deltaY`), capped.
    static func wheelFactor(_ deltaY: Double) -> Double {
      1.0 - max(-wheelTravel, min(wheelTravel, deltaY)) * wheelStep
    }
  }

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
    /// Whether the image is at its fit, which it follows as the viewport
    /// changes size; any other zoom is clamped.
    private var atFit = true
    /// The most it zooms in: its actual size, or its fit where that is
    /// larger.
    private var maxZoom: Double { max(minZoom, ViewerZoom.actualSize) }
    /// The zoom a Safari pinch began at (WebKit's `gesturestart`).
    private var gestureStartZoom = 1.0
    /// Told what the image shows whenever the reader moves it—a drag, a
    /// wheel, a double-click—never when it is moved to match the text
    /// (pane sync).
    var onRegion: ((ViewerZoom.Region) -> Void)?

    /// What the image shows now, nil until it has a size.
    var region: ViewerZoom.Region? {
      guard imageW > 0, imageH > 0, minZoom > 0 else { return nil }
      let width = Double(imageW) * zoom
      let height = Double(imageH) * zoom
      return .init(
        centerX: (viewportW / 2 - panX) / width, centerY: (viewportH / 2 - panY) / height, scale: zoom / minZoom,
        maxScale: maxZoom / minZoom)
    }

    /// The image at `region`: its zoom over its fit, clamped, the point at
    /// its middle. Told to no one: it is the text's move, matched.
    func show(region: ViewerZoom.Region) {
      guard imageW > 0, imageH > 0 else { return }
      zoom = max(minZoom, min(maxZoom, minZoom * region.scale))
      atFit = zoom <= minZoom
      panX = viewportW / 2 - region.centerX * Double(imageW) * zoom
      panY = viewportH / 2 - region.centerY * Double(imageH) * zoom
      clampPan()
      updateTransform()
    }

    private func tellRegion() {
      if let onRegion, let region { onRegion(region) }
    }
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

    /// Whether a drag draws a crop box rather than pans (a host's call, on
    /// an attached canvas), the box in image pixels (width 0: none), the
    /// corner a drag started from, and its element over the image.
    private var cropping = false
    private var cropX: Double = 0
    private var cropY: Double = 0
    private var cropW: Double = 0
    private var cropH: Double = 0
    private var cropStartX: Double = 0
    private var cropStartY: Double = 0
    private var cropBox: DOM.Element?
    /// Told "<service> x y w h" (0–1000) as the box is drawn, moved or
    /// resized, and "<service>" once it is cleared.
    var onCrop: ((String) -> Void)?

    /// The region the page's markup names where the caret or the pointer
    /// is, in the 0–1000 space (width 0: none), and its element over the
    /// image.
    private var regionX: Double = 0
    private var regionY: Double = 0
    private var regionW: Double = 0
    private var regionH: Double = 0
    private var regionBox: DOM.Element?
    private var regionDim: DOM.Element?
    private var grid: DOM.Element?
    private var readout: DOM.Element?
    /// The grid levels drawn, as last set ("" none), so a pan sets nothing.
    private var gridLevels = ""
    /// Whether the crop box is the region, edited where its markup is
    /// written (a bbox in an editor): its drags are told as
    /// `onRegionEdit`, live and once more when they end, never as `onCrop`.
    private var editing = false
    /// Told x y w h (0–1000, whole, inside the image) as an edited region
    /// is moved or resized, `true` once the drag ends.
    var onRegionEdit: ((Int, Int, Int, Int, Bool) -> Void)?
    /// What a drag on the box does: draws a new one, moves it, or resizes
    /// it from the corner it holds still (`anchorX`, `anchorY`).
    private enum CropDrag { case draw, move, resize }
    private var cropDrag = CropDrag.draw
    private var anchorX: Double = 0
    private var anchorY: Double = 0

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
      // The fit is found again: an image at its fit follows it (a pane
      // made shorter fits the whole image again, not its width alone);
      // any other zoom is clamped to it.
      vp?.observeResize { [self] w, h in
        guard w > 0, h > 0 else { return }
        guard w != viewportW || h != viewportH else { return }
        viewportW = w
        viewportH = h
        guard imageW > 0, imageH > 0 else { return }
        minZoom = min(viewportW / Double(imageW), viewportH / Double(imageH))
        zoom = atFit ? minZoom : max(minZoom, min(maxZoom, zoom))
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
      spinner.appendChild(RotatingRingSectorFactory.createElement())
      viewport.appendChild(spinner)
      canvas.appendChild(viewport)
      return canvas
    }

    /// The image, fitted to the viewport: its low-resolution copy, then the
    /// detail the fit asks for; or `image`, a plain image shown whole in
    /// place of the service (an archived copy).
    func show(width: Int, height: Int, image: String = "") {
      imageW = width
      imageH = height
      fitToViewport()
      compositor?.showSpinner()
      compositor?.setCanvas(serviceID: serviceID, width: width, height: height, image: image)
      updateTransform()
    }

    /// Put away: its tiles go, so only the canvas on screen holds images.
    /// The browser keeps what it fetched, and showing it again is quick.
    func hide() {
      compositor?.clear()
      endDrag()
      clearRegion()
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
      // At its fit, unless the session zoomed the images in (a reload keeps
      // it).
      let kept = parseDouble(sessionStorage.getItem(ViewerZoom.imageKey) ?? "")
      zoom = kept.map { max(minZoom, min(maxZoom, $0)) } ?? minZoom
      atFit = zoom <= minZoom
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
      drawCrop()
      drawRegion()
    }

    // MARK: - Region

    /// A region of the image (0–1000) drawn over it, as the image is
    /// panned and zoomed, until it is cleared.
    func showRegion(x: Int, y: Int, width: Int, height: Int) {
      stopEditing()
      regionX = Double(x)
      regionY = Double(y)
      regionW = Double(width)
      regionH = Double(height)
      drawRegion()
    }

    func clearRegion() {
      stopEditing()
      regionW = 0
      regionH = 0
      drawRegion()
    }

    /// A region edited on the canvas as well as in its markup: the crop
    /// box drawn over it, its corners and body dragged. A canvas taking a
    /// crop box for a call keeps it, and only shows the region.
    func editRegion(x: Int, y: Int, width: Int, height: Int) {
      guard !cropping else {
        showRegion(x: x, y: y, width: width, height: height)
        return
      }
      regionX = Double(x)
      regionY = Double(y)
      regionW = Double(width)
      regionH = Double(height)
      editing = true
      // Mid-drag, the box is the drag's.
      if mouseMoveListener < 0, imageW > 0, imageH > 0 {
        cropX = regionX * Double(imageW) / 1000
        cropY = regionY * Double(imageH) / 1000
        cropW = regionW * Double(imageW) / 1000
        cropH = regionH * Double(imageH) / 1000
      }
      drawCrop()
      drawRegion()
    }

    private func stopEditing() {
      guard editing else { return }
      editing = false
      if mouseMoveListener >= 0 { endDrag() }
      cropW = 0
      cropH = 0
      viewport?.removeAttribute(data("crop-hover"))
      drawCrop()
    }

    private func drawRegion() {
      guard regionW > 0, regionH > 0, imageW > 0, imageH > 0 else {
        regionBox?.setAttribute(.hidden, "")
        regionDim?.setAttribute(.hidden, "")
        grid?.setAttribute(.hidden, "")
        readout?.setAttribute(.hidden, "")
        return
      }
      if case .none = grid { grid = gridElement() }
      if let grid {
        place(grid, x: 0, y: 0, width: Double(imageW), height: Double(imageH))
        drawGridLevels(grid)
      }
      if case .none = regionDim { regionDim = overlay("canvas-region-dim") }
      if case .none = regionBox { regionBox = overlay("canvas-region") }
      guard let box = regionBox else { return }
      let scaleX = Double(imageW) / 1000
      let scaleY = Double(imageH) / 1000
      let x = regionX * scaleX
      let y = regionY * scaleY
      let w = regionW * scaleX
      let h = regionH * scaleY
      place(box, x: x, y: y, width: w, height: h)
      // The backdrop with the region cut out, its ring (1px border inside,
      // 1px outline outside) clear too.
      guard let dim = regionDim else { return }
      dim.removeAttribute(.hidden)
      let left = pixels(panX + x * zoom - 1)
      let top = pixels(panY + y * zoom - 1)
      let right = pixels(panX + (x + w) * zoom + 1)
      let bottom = pixels(panY + (y + h) * zoom + 1)
      dim.style.setProperty(
        "clip-path",
        stringJoin(
          [
            "polygon(evenodd, 0 0, 100% 0, 100% 100%, 0 100%, 0 0, ", left, " ", top, ", ", right, " ", top, ", ",
            right, " ", bottom, ", ", left, " ", bottom, ", ", left, " ", top, ")",
          ], separator: ""))
    }

    /// The 0–1000 grid, laid out once in its own percentages: placed over
    /// the image, it scales with it.
    private func gridElement() -> DOM.Element? {
      guard let grid = overlay("canvas-grid") else { return nil }
      var value = 0
      while value <= 1000 {
        for axis in ["x", "y"] {
          // The 0 corner is named once, on the top edge.
          if value == 0, stringEquals(axis, "y") { continue }
          let label = document.createElement(.div)
          label.className = "canvas-grid-label"
          label.setAttribute(data("axis"), axis)
          label.textContent = intToString(value)
          // Centered on its line, kept inside the image at the ends.
          let shift = value == 0 ? "0%" : value == 1000 ? "-100%" : "-50%"
          if stringEquals(axis, "x") {
            label.style.setProperty("left", percent(value))
            label.style.setProperty("top", "0")
            label.style.setProperty("transform", stringJoin(["translateX(", shift, ")"], separator: ""))
          } else {
            label.style.setProperty("top", percent(value))
            label.style.setProperty("left", "0")
            label.style.setProperty("transform", stringJoin(["translateY(", shift, ")"], separator: ""))
          }
          grid.appendChild(label)
        }
        value += 100
      }
      return grid
    }

    /// The grid's levels, those whose lines stand at least 4px apart as
    /// the image is shown: each a gradient a line wide, tiled at its
    /// spacing, one an axis, the finer the fainter. Named on the grid
    /// (`data-levels`, "100 50 10") for whoever reads it.
    private func drawGridLevels(_ grid: DOM.Element) {
      let shownW = Double(imageW) * zoom
      let shownH = Double(imageH) * zoom
      var layers: [String] = []
      var sizes: [String] = []
      var names: [String] = []
      for (units, strength) in [(100, "40%"), (50, "28%"), (10, "20%"), (5, "14%"), (1, "10%")] {
        let stepX = shownW * Double(units) / 1000
        let stepY = shownH * Double(units) / 1000
        guard stepX >= 4, stepY >= 4 else { break }
        let color = stringJoin(["color-mix(in srgb, var(--color-base) ", strength, ", transparent)"], separator: "")
        layers.append(stringJoin(["linear-gradient(to right, ", color, " 0 1px, transparent 1px)"], separator: ""))
        sizes.append(stringJoin([pixels(stepX), " 100%"], separator: ""))
        layers.append(stringJoin(["linear-gradient(to bottom, ", color, " 0 1px, transparent 1px)"], separator: ""))
        sizes.append(stringJoin(["100% ", pixels(stepY)], separator: ""))
        names.append(intToString(units))
      }
      let levels = stringJoin(names, separator: " ")
      let key = stringJoin([levels, "|", doubleToString(shownW), "|", doubleToString(shownH)], separator: "")
      guard !stringEquals(key, gridLevels) else { return }
      gridLevels = key
      grid.setAttribute(data("levels"), levels)
      grid.style.setProperty("background-image", stringJoin(layers, separator: ", "))
      grid.style.setProperty("background-size", stringJoin(sizes, separator: ", "))
    }

    /// The pointer's place in the 0–1000 space beside it, while a region
    /// is drawn and the pointer is on the image.
    private func showReadout(clientX: Double, clientY: Double) {
      guard regionW > 0, regionH > 0, imageW > 0, imageH > 0, let rect = viewport?.getBoundingClientRect() else {
        readout?.setAttribute(.hidden, "")
        return
      }
      let x = (clientX - rect.x - panX) / zoom
      let y = (clientY - rect.y - panY) / zoom
      guard x >= 0, y >= 0, x <= Double(imageW), y <= Double(imageH) else {
        readout?.setAttribute(.hidden, "")
        return
      }
      if case .none = readout { readout = overlay("canvas-readout") }
      guard let readout else { return }
      readout.textContent = stringJoin(
        [
          intToString(Int((x / Double(imageW) * 1000).rounded())), ", ",
          intToString(Int((y / Double(imageH) * 1000).rounded())),
        ], separator: "")
      readout.removeAttribute(.hidden)
      readout.style.setProperty("left", pixels(clientX - rect.x + 12))
      readout.style.setProperty("top", pixels(clientY - rect.y + 12))
    }

    private func percent(_ value: Int) -> String {
      stringJoin([doubleToString(Double(value) / 10), "%"], separator: "")
    }

    private func pixels(_ value: Double) -> String {
      stringJoin([doubleToString(value), "px"], separator: "")
    }

    /// A box over the image, hidden until it is placed.
    private func overlay(_ className: String) -> DOM.Element? {
      guard let vp = viewport else { return nil }
      let box = document.createElement(.div)
      box.className = className
      box.setAttribute("aria-hidden", "true")
      box.setAttribute(.hidden, "")
      vp.appendChild(box)
      return box
    }

    /// A box shown over a stretch of the image (in image pixels), as the
    /// image is panned and zoomed.
    private func place(_ box: DOM.Element, x: Double, y: Double, width: Double, height: Double) {
      box.removeAttribute(.hidden)
      box.style.setProperty("left", pixels(panX + x * zoom))
      box.style.setProperty("top", pixels(panY + y * zoom))
      box.style.setProperty("width", pixels(width * zoom))
      box.style.setProperty("height", pixels(height * zoom))
    }

    // MARK: - Crop box

    /// A drag draws a crop box (and the box can be moved and resized with
    /// the keys), or pans, as it always did.
    func setCropping(_ on: Bool) {
      cropping = on
      viewport?.setAttribute(data("cropping"), on ? "true" : "false")
      if on {
        viewport?.setAttribute("aria-label", "Crop box: drag on the image, or Enter, then the arrow keys")
      } else {
        viewport?.removeAttribute("aria-label")
      }
      drawCrop()
    }

    /// The box taken away, and said so.
    func clearCrop() {
      let had = cropW > 0
      cropW = 0
      cropH = 0
      drawCrop()
      if had { onCrop?(serviceID) }
    }

    /// The box in the 0–1000 space, rounded, kept inside it.
    private var cropBox1000: (x: Int, y: Int, w: Int, h: Int) {
      guard imageW > 0, imageH > 0 else { return (0, 0, 0, 0) }
      let x = max(0, min(999, Int((cropX / Double(imageW) * 1000).rounded())))
      let y = max(0, min(999, Int((cropY / Double(imageH) * 1000).rounded())))
      let w = max(1, min(1000 - x, Int((cropW / Double(imageW) * 1000).rounded())))
      let h = max(1, min(1000 - y, Int((cropH / Double(imageH) * 1000).rounded())))
      return (x, y, w, h)
    }

    private func reportCrop() {
      guard cropW > 0, cropH > 0 else { return }
      let box = cropBox1000
      onCrop?(stringJoin([serviceID, intToString(box.x), intToString(box.y), intToString(box.w), intToString(box.h)],
        separator: " "))
    }

    private func drawCrop() {
      guard cropW > 0, cropH > 0, imageW > 0 else {
        cropBox?.setAttribute(.hidden, "")
        return
      }
      // The box's element, made the first time a box is drawn, its corners
      // handles.
      if case .none = cropBox {
        cropBox = overlay("canvas-crop")
        for corner in ["nw", "ne", "sw", "se"] {
          let handle = document.createElement(.div)
          handle.className = "canvas-crop-handle"
          handle.setAttribute(data("corner"), corner)
          cropBox?.appendChild(handle)
        }
      }
      guard let box = cropBox else { return }
      place(box, x: cropX, y: cropY, width: cropW, height: cropH)
    }

    /// A point of the viewport in image pixels, kept on the image.
    private func imagePoint(clientX: Double, clientY: Double) -> (x: Double, y: Double) {
      let rect = viewport?.getBoundingClientRect()
      let x = (clientX - (rect?.x ?? 0) - panX) / zoom
      let y = (clientY - (rect?.y ?? 0) - panY) / zoom
      return (max(0, min(Double(imageW), x)), max(0, min(Double(imageH), y)))
    }

    /// Where a point of the viewport stands on the box: on a corner's
    /// handle (within a handle's reach of it), inside, or off it.
    private func cropPart(clientX: Double, clientY: Double) -> String {
      guard cropW > 0, cropH > 0, let rect = viewport?.getBoundingClientRect() else { return "" }
      let x = clientX - rect.x
      let y = clientY - rect.y
      let left = panX + cropX * zoom
      let top = panY + cropY * zoom
      let right = left + cropW * zoom
      let bottom = top + cropH * zoom
      let reach = 8.0
      let nearLeft = abs(x - left) <= reach
      let nearRight = abs(x - right) <= reach
      let nearTop = abs(y - top) <= reach
      let nearBottom = abs(y - bottom) <= reach
      if nearTop && nearLeft { return "nw" }
      if nearTop && nearRight { return "ne" }
      if nearBottom && nearLeft { return "sw" }
      if nearBottom && nearRight { return "se" }
      if x > left && x < right && y > top && y < bottom { return "move" }
      return ""
    }

    /// A drag on the box: a handle resizes it, its body moves it, and
    /// anywhere else draws a new one.
    private func beginCrop(clientX: Double, clientY: Double, part: String) {
      let start = imagePoint(clientX: clientX, clientY: clientY)
      cropStartX = start.x
      cropStartY = start.y
      if stringEquals(part, "move") {
        cropDrag = .move
        anchorX = cropX
        anchorY = cropY
      } else if !stringIsEmpty(part) {
        cropDrag = .resize
        // The corner across from the one held stays put.
        anchorX = stringEndsWith(part, "w") ? cropX + cropW : cropX
        anchorY = stringStartsWith(part, "n") ? cropY + cropH : cropY
      } else {
        cropDrag = .draw
        anchorX = start.x
        anchorY = start.y
        cropX = start.x
        cropY = start.y
        cropW = 0
        cropH = 0
      }
      viewport?.setAttribute(data("dragging"), "true")
      mouseMoveListener = window.addEventListener(.mousemove) { [self] e in
        let point = imagePoint(clientX: e.clientX, clientY: e.clientY)
        switch cropDrag {
        case .move:
          cropX = max(0, min(Double(imageW) - cropW, anchorX + point.x - cropStartX))
          cropY = max(0, min(Double(imageH) - cropH, anchorY + point.y - cropStartY))
        case .resize, .draw:
          cropX = min(anchorX, point.x)
          cropY = min(anchorY, point.y)
          cropW = abs(point.x - anchorX)
          cropH = abs(point.y - anchorY)
        }
        drawCrop()
        if editing { reportRegion(done: false) }
      }
      mouseUpListener = window.addEventListener(.mouseup) { [self] _ in
        endDrag()
        if editing {
          reportRegion(done: true)
        } else if cropW * zoom < 4 || cropH * zoom < 4 {
          // A click, or a sliver under four screen pixels, draws no box.
          clearCrop()
        } else {
          drawCrop()
          reportCrop()
        }
      }
    }

    /// The edited region as the box now stands (whole, inside the image, at
    /// least 1 by 1), drawn and told.
    private func reportRegion(done: Bool) {
      let box = cropBox1000
      regionX = Double(box.x)
      regionY = Double(box.y)
      regionW = Double(box.w)
      regionH = Double(box.h)
      drawRegion()
      onRegionEdit?(box.x, box.y, box.w, box.h, done)
    }

    /// The keys, on the focused canvas while it takes a box: Enter draws
    /// one in the middle when there is none; the arrows move it 10 in the
    /// 0–1000 space (with Shift, they resize it); Delete or Backspace
    /// clears it; Escape too.
    private func cropKey(_ key: String, shift: Bool) -> Bool {
      guard cropping, imageW > 0, imageH > 0 else { return false }
      let stepX = Double(imageW) / 100
      let stepY = Double(imageH) / 100
      if stringEquals(key, "Enter") {
        guard cropW <= 0 else { return false }
        cropX = Double(imageW) / 4
        cropY = Double(imageH) / 4
        cropW = Double(imageW) / 2
        cropH = Double(imageH) / 2
      } else if stringEquals(key, "Delete") || stringEquals(key, "Backspace") || stringEquals(key, "Escape") {
        guard cropW > 0 else { return false }
        clearCrop()
        return true
      } else if cropW > 0, stringStartsWith(key, "Arrow") {
        let dx = stringEquals(key, "ArrowLeft") ? -stepX : stringEquals(key, "ArrowRight") ? stepX : 0
        let dy = stringEquals(key, "ArrowUp") ? -stepY : stringEquals(key, "ArrowDown") ? stepY : 0
        if shift {
          cropW = max(stepX, min(Double(imageW) - cropX, cropW + dx))
          cropH = max(stepY, min(Double(imageH) - cropY, cropH + dy))
        } else {
          cropX = max(0, min(Double(imageW) - cropW, cropX + dx))
          cropY = max(0, min(Double(imageH) - cropH, cropY + dy))
        }
      } else {
        return false
      }
      drawCrop()
      reportCrop()
      return true
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
        vp.focus(DOM.FocusOptions(preventScroll: true))
        endDrag()
        if cropping, imageW > 0, imageH > 0 {
          vp.focus()
          beginCrop(clientX: e.clientX, clientY: e.clientY, part: cropPart(clientX: e.clientX, clientY: e.clientY))
          return
        }
        // An edited region's box takes a drag on itself; anywhere else
        // pans, and the focus stays in the editor.
        if editing, imageW > 0, imageH > 0 {
          let part = cropPart(clientX: e.clientX, clientY: e.clientY)
          if !stringIsEmpty(part) {
            beginCrop(clientX: e.clientX, clientY: e.clientY, part: part)
            return
          }
        }
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
          tellRegion()
        }
        mouseUpListener = window.addEventListener(.mouseup) { [self] _ in
          endDrag()
          if atFit {
            // Fitted: back to the middle, however it was dragged.
            panX = (viewportW - Double(imageW) * zoom) / 2
            updateTransform()
          }
        }
      }

      // The pointer over a box's corner or body says what a drag would do.
      vp.addEventListener(.mousemove) { [self] e in
        showReadout(clientX: e.clientX, clientY: e.clientY)
        guard mouseMoveListener < 0, cropping || editing else { return }
        let part = cropPart(clientX: e.clientX, clientY: e.clientY)
        if stringIsEmpty(part) {
          vp.removeAttribute(data("crop-hover"))
        } else {
          vp.setAttribute(data("crop-hover"), part)
        }
      }

      vp.addEventListener(.mouseleave) { [self] _ in readout?.setAttribute(.hidden, "") }

      // Safari's trackpad pinch: WebKit's gesture events, not the ctrl+wheel
      // other browsers send (which the wheel above zooms by). Zoomed about
      // the gesture's point from the zoom it began at, by its scale; the
      // page itself never zoomed. Other browsers never send them.
      vp.addEventListener("gesturestart") { [self] e in
        e.preventDefault()
        gestureStartZoom = zoom
      }
      vp.addEventListener("gesturechange") { [self] e in
        e.preventDefault()
        guard imageW > 0, imageH > 0 else { return }
        let box = viewport?.getBoundingClientRect()
        zoom(
          to: gestureStartZoom * e.webKitGestureScale, aboutX: e.clientX - (box?.x ?? 0), y: e.clientY - (box?.y ?? 0))
      }
      vp.addEventListener("gestureend") { e in e.preventDefault() }

      // Focused, the keys move it as the text's do (user, 2026-10-12): the
      // arrows pan by a wheel's travel, + and − zoom by a wheel's step about
      // the middle, 0 fits it again; a crop box's keys come first.
      vp.setAttribute("tabindex", "0")
      vp.addEventListener(.keydown) { [self] e in
        if cropKey(e.key, shift: e.shiftKey) {
          e.preventDefault()
          e.stopPropagation()
          return
        }
        guard imageW > 0, imageH > 0 else { return }
        let key = e.key
        if stringEquals(key, "+") || stringEquals(key, "=") {
          zoom(to: zoom * ViewerZoom.wheelFactor(-ViewerZoom.wheelTravel), aboutX: viewportW / 2, y: viewportH / 2)
        } else if stringEquals(key, "-") {
          zoom(to: zoom * ViewerZoom.wheelFactor(ViewerZoom.wheelTravel), aboutX: viewportW / 2, y: viewportH / 2)
        } else if stringEquals(key, "0") {
          zoom(to: minZoom, aboutX: viewportW / 2, y: viewportH / 2)
        } else if stringEquals(key, "ArrowLeft") || stringEquals(key, "ArrowRight") || stringEquals(key, "ArrowUp")
          || stringEquals(key, "ArrowDown")
        {
          panX += stringEquals(key, "ArrowLeft") ? ViewerZoom.wheelTravel : stringEquals(key, "ArrowRight") ? -ViewerZoom.wheelTravel : 0
          panY += stringEquals(key, "ArrowUp") ? ViewerZoom.wheelTravel : stringEquals(key, "ArrowDown") ? -ViewerZoom.wheelTravel : 0
          clampPan()
          updateTransform()
          tellRegion()
        } else {
          return
        }
        e.preventDefault()
        e.stopPropagation()
      }

      vp.addEventListener(.wheel) { [self] e in
        e.preventDefault()
        guard imageW > 0, imageH > 0 else { return }
        let dz = ViewerZoom.wheelFactor(e.deltaY)
        let cx = e.clientX - (viewport?.getBoundingClientRect()?.x ?? 0)
        let cy = e.clientY - (viewport?.getBoundingClientRect()?.y ?? 0)
        zoom(to: zoom * dz, aboutX: cx, y: cy)
      }
    }

    /// `value`, clamped to the fit and the actual size, about a point of
    /// the viewport, kept for the session.
    private func zoom(to value: Double, aboutX cx: Double, y cy: Double) {
      let newZoom = max(minZoom, min(maxZoom, value))
      panX = cx - (cx - panX) * (newZoom / zoom)
      panY = cy - (cy - panY) * (newZoom / zoom)
      zoom = newZoom
      atFit = zoom <= minZoom
      sessionStorage.setItem(ViewerZoom.imageKey, atFit ? "fit" : doubleToString(zoom))
      clampPan()
      updateTransform()
      tellRegion()
    }
  }
#endif
