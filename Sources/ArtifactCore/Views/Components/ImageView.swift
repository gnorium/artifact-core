#if SERVER
  import CSSBuilder
  import DesignTokens
  import DOMBuilder
  import Foundation
  import HTMLBuilder
  import WebComponents
  import WebTypes

  /// One image, on a surface it can be panned and zoomed on: the image
  /// service it names is read in tiles, a low-resolution copy first and the
  /// detail the zoom asks for over it.
  ///
  /// Drawn empty. Nothing is fetched until the image is shown
  /// (`ImageView.show(width:height:)`), and an image put away lets go of
  /// its tiles, so a viewer holding four hundred images reads one image at
  /// a time. ``ArtifactView`` takes images in its image slot and shows the
  /// one whose `data-service-id` is the image on screen.
  public struct ImageView: HTMLContent {
    /// The image service the image reads, as a manifest names it.
    let serviceID: String
    /// Whether it is the image shown before the viewer is hydrated.
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
            RotatingDottedRingSectorView(ariaHidden: true)
          }
          .class("image-spinner")
          .data("visible", "false")
        }
        .class("image-viewport")
        .data("dragging", "false")
      }
      .class("image-view")
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
        selector("&[data-aspect-ratio]") {
          display(.block)
          flex("none")
          backgroundColor(backgroundColorBase)
        }
        selector("&[data-position='left']") { marginInlineEnd(.auto) }
        selector("&[data-position='center']") { marginInline(.auto) }
        selector("&[data-position='right']") { marginInlineStart(.auto) }
        selector("&[data-aspect-ratio='16:9']") { paddingBottom(perc((9.0 / 16.0) * 100)) }
        selector("&[data-aspect-ratio='3:2']") { paddingBottom(perc((2.0 / 3.0) * 100)) }
        selector("&[data-aspect-ratio='4:3']") { paddingBottom(perc((3.0 / 4.0) * 100)) }
        selector("&[data-aspect-ratio='1:1']") { paddingBottom(perc(100)) }
        selector("&[data-aspect-ratio='3:4']") { paddingBottom(perc((4.0 / 3.0) * 100)) }
        selector("&[data-aspect-ratio='2:3']") { paddingBottom(perc((3.0 / 2.0) * 100)) }
        descendant(".image-image") {
          display(.block)
          width(perc(100))
          height(perc(100))
        }
        descendant(".image-image[data-has-aspect-ratio='true']") {
          position(.absolute)
          insetBlockStart(0)
          insetInlineStart(0)
        }
        descendant(".image-image[data-object-fit='cover']") { objectFit(.cover) }
        descendant(".image-image[data-object-fit='contain']") { objectFit(.contain) }
        descendant(".image-image[data-object-fit='fill']") { objectFit(.fill) }
        descendant(".image-image[data-object-fit='none']") { objectFit(.none) }
        descendant(".image-image[data-object-fit='scale-down']") { objectFit(.scaleDown) }
        descendant(".image-image[data-object-position='center']") { objectPosition(.center) }
        descendant(".image-image[data-object-position='top']") { objectPosition(.top) }
        descendant(".image-image[data-object-position='bottom']") { objectPosition(.bottom) }
        descendant(".image-image[data-object-position='left']") { objectPosition(.left) }
        descendant(".image-image[data-object-position='right']") { objectPosition(.right) }
        descendant(".image-placeholder") {
          position(.absolute)
          insetBlockStart(0)
          insetInlineStart(0)
          width(perc(100))
          height(perc(100))
          display(.flex)
          alignItems(.center)
          justifyContent(.center)
          backgroundColor(backgroundColorBase)
          color(colorPlaceholder)
          fontSize(size20)
        }
        // Explicit flex(1) and a zero minimum height make flex size it to
        // the room it has, not to the image.
        descendant(".image-viewport") {
          width(perc(100))
          flex(1)
          minHeight(0)
          overflow(.hidden)
          position(.relative)
          cursor(.grab)
          userSelect(.none)
        }
        descendant(".image-viewport[data-clickable='true']") { cursor(.pointer) }
        descendant(".image-viewport[data-dragging='true']") { cursor(.grabbing) }
        descendant(".image-spinner") {
          display(.none)
          position(.absolute)
          inset(0)
          zIndex(5)
          alignItems(.center)
          justifyContent(.center)
          backgroundColor(backgroundColorBase)
        }
        descendant(".image-spinner[data-visible='true']") { display(.flex) }
        // The tile layer is the viewport's own size, user units its CSS
        // pixels, and clips what it draws: the tiles' group carries the
        // pan and zoom and is itself clipped to the image's rectangle
        // (`TileCompositor`), so nothing is drawn beside the image. It is
        // not composited (no `will-change`): WebKit left strips of the
        // image's edge at earlier positions on a composited SVG group as
        // the zoom changed, and a layer of that size is its own cost.
        descendant(".image-tile-surface") {
          position(.absolute)
          inset(0)
          width(perc(100))
          height(perc(100))
          overflow(.hidden)
        }
        descendant(".image-tile-compositor") {
          transformOrigin(px(0), px(0))
        }
        // Drawing a crop box: a crosshair, not a hand.
        descendant(".image-viewport[data-cropping='true']") { cursor(.crosshair) }
        // A crop box over the image, and the region the markup names where
        // the caret or the pointer is: the house ring (1px border and 1px
        // outline, one color), the image seen through it.
        selector("& .image-crop", "& .image-region") {
          position(.absolute)
          boxSizing(.borderBox)
          border(borderWidthBase, .solid, colorBlue)
          outline(borderWidthBase, .solid, colorBlue)
          pointerEvents(.none)
        }
        descendant(".image-crop") { zIndex(5) }
        // An encoded zone on the image (copy evidence, note, signature, figure)
        // outlined in neutral borderColorBase when hovered on the image;
        // nothing is drawn at rest.
        descendant(".image-element") {
          position(.absolute)
          zIndex(4)
          boxSizing(.borderBox)
          border(borderWidthBase, .solid, borderColorBase)
          outline(borderWidthBase, .solid, borderColorBase)
          pointerEvents(.none)
        }
        // The edition's word the reader points at, on the scan (user,
        // 2026-10-14): a translucent band, the scan seen through it in
        // either scheme. Blue (user, 2026-10-29): yellow is Find's alone,
        // and a pointed word in yellow read as a match; the edition's word
        // wears the same blue at the same opacity. The quote a reader is
        // opened on wears it too (user, 2026-10-31).
        selector("& .image-word", "& .image-quote") {
          position(.absolute)
          zIndex(1)
          backgroundColor(colorBlue)
          opacity(opacityLow)
          pointerEvents(.none)
        }
        descendant(".image-region") { zIndex(4) }
        // The 0–1000 space drawn over the image while a region is: lines
        // every 100, 50, 10, 5 and 1, each finer level fainter and drawn
        // only once its lines stand 4px apart on screen (its gradients set
        // as the image is scaled), each 100 named along the top and the left
        // edges. Above the dim, under the region's ring.
        selector("& .image-grid", "& .image-grid-lines") {
          position(.absolute)
          zIndex(3)
          pointerEvents(.none)
        }
        // The pointer's place in the 0–1000 space, beside it.
        descendant(".image-readout") {
          position(.absolute)
          zIndex(6)
          pointerEvents(.none)
        }
        selector("& .image-grid-label", "& .image-readout") {
          position(.absolute)
          paddingInline(spacing2)
          fontSize(fontSizeMedium16)
          lineHeight(lineHeightSmall22)
          color(colorSubtle)
          backgroundColor(backgroundColorBackdropLight)
          whiteSpace(.nowrap)
        }
        // Under twice its fit (`gridLabelsFrom`), the edges' names put away:
        // there they crowd the image, the pointer's place names a point
        // (user, 2026-10-28).
        selector("& .image-grid[data-labels='off'] .image-grid-label") { display(.none) }
        // Everything but the region dimmed, as an image editor marks a
        // selection: a backdrop over the viewport, the region (and its ring)
        // cut out of it.
        descendant(".image-region-dim") {
          position(.absolute)
          inset(0)
          zIndex(2)
          backgroundColor(backgroundColorBackdropDarkFixed)
          opacity(opacityMedium)
          pointerEvents(.none)
        }
        // A box's corners, each a handle a drag resizes it by (the box's
        // body moves it).
        descendant(".image-crop-handle") {
          position(.absolute)
          width(spacing8)
          height(spacing8)
          boxSizing(.borderBox)
          backgroundColor(backgroundColorBase)
          border(borderWidthBase, .solid, colorBlue)
          transform(translate(perc(-50), perc(-50)))
        }
        descendant(".image-crop-handle[data-corner='nw']") { left(px(0)); top(px(0)) }
        descendant(".image-crop-handle[data-corner='ne']") { left(perc(100)); top(px(0)) }
        descendant(".image-crop-handle[data-corner='sw']") { left(px(0)); top(perc(100)) }
        descendant(".image-crop-handle[data-corner='se']") { left(perc(100)); top(perc(100)) }
        // A polygon zone's vertices, each a handle a drag moves by.
        descendant(".image-vertex") {
          position(.absolute)
          zIndex(7)
          width(spacing8)
          height(spacing8)
          boxSizing(.borderBox)
          backgroundColor(backgroundColorBase)
          border(borderWidthBase, .solid, colorBlue)
          transform(translate(perc(-50), perc(-50)))
          pointerEvents(.none)
        }
        descendant(".image-viewport[data-crop-hover='vertex']") { cursor(.move) }
        descendant(".image-viewport[data-crop-hover='move']") { cursor(.move) }
        selector("& .image-viewport[data-crop-hover='nw']", "& .image-viewport[data-crop-hover='se']") {
          cursor(.nwseResize)
        }
        selector("& .image-viewport[data-crop-hover='ne']", "& .image-viewport[data-crop-hover='sw']") {
          cursor(.neswResize)
        }
        selector(
          "& .image-crop[hidden]", "& .image-element[hidden]", "& .image-word[hidden]", "& .image-quote[hidden]",
          "& .image-region[hidden]", "& .image-region-dim[hidden]", "& .image-grid[hidden]",
          "& .image-readout[hidden]", "& .image-vertex[hidden]"
        ) {
          display(.none)
        }
        descendant(".image-tile-image[data-loaded='false']") { opacity(0) }
        descendant(".image-tile-image[data-loaded='true']") { opacity(1) }
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

  /// One image, read: its tiles, its zoom and pan, the gestures that change
  /// them. Made by the viewer the first time the image is shown.
  final class ImageView: @unchecked Sendable {
    let root: DOM.Element
    let serviceID: String
    private var viewport: DOM.Element?
    private var compositor: TileCompositor?

    /// The image's zoom and pan: the model every image zoomed where it
    /// stands shares (`ViewerZoom.Surface`), read and set here by the names
    /// this reader has always used.
    private var surface = ViewerZoom.Surface()
    private var imageW: Int {
      get { Int(surface.imageWidth) }
      set { surface.imageWidth = Double(newValue) }
    }
    private var imageH: Int {
      get { Int(surface.imageHeight) }
      set { surface.imageHeight = Double(newValue) }
    }
    private var zoom: Double {
      get { surface.zoom }
      set { surface.zoom = newValue }
    }
    private var minZoom: Double {
      get { surface.minZoom }
      set { surface.minZoom = newValue }
    }
    /// Whether the image is at its fit, which it follows as the viewport
    /// changes size; any other zoom is clamped.
    private var atFit: Bool {
      get { surface.atFit }
      set { surface.atFit = newValue }
    }
    /// The most it zooms in: its actual size, or its fit where that is
    /// larger.
    private var maxZoom: Double { surface.maxZoom }
    private var panX: Double {
      get { surface.panX }
      set { surface.panX = newValue }
    }
    private var panY: Double {
      get { surface.panY }
      set { surface.panY = newValue }
    }
    private var viewportW: Double {
      get { surface.viewportWidth }
      set { surface.viewportWidth = newValue }
    }
    private var viewportH: Double {
      get { surface.viewportHeight }
      set { surface.viewportHeight = newValue }
    }
    /// The wheel and Safari's pinch on the viewport.
    private var zoomInput: ViewerZoom.Input?
    /// Told what the image shows whenever the reader moves it—a drag, a
    /// wheel, a double-click—never when it is moved to match the text
    /// (pane sync).
    var onRegion: ((ViewerZoom.Region) -> Void)?

    /// Told when the image is left with no image: every copy of what was
    /// sent failed to load, and its service's image now may not stand in
    /// (`TileCompositor.onNoImage`).
    var onNoImage: (() -> Void)? {
      didSet { compositor?.onNoImage = onNoImage }
    }

    /// What the image shows now, nil until it has a size.
    var region: ViewerZoom.Region? { surface.region }

    /// The image's size in its pixels, its fit (the viewport's pixels per
    /// image pixel at it) and its viewport's size: what a region of the
    /// image is in the text's terms (`ArtifactView`'s sync); nil before it
    /// has them.
    var sizing: (width: Double, height: Double, fit: Double, viewportWidth: Double, viewportHeight: Double)? {
      guard imageW > 0, imageH > 0, minZoom > 0, viewportW > 0 else { return nil }
      return (Double(imageW), Double(imageH), minZoom, viewportW, viewportH)
    }

    /// The image at `region`: its zoom over its fit, clamped, the point at
    /// its middle. Told to no one: it is the text's move, matched.
    func show(region: ViewerZoom.Region) {
      guard imageW > 0, imageH > 0 else { return }
      surface.show(region: region)
      // Kept for the session as its own zoom is: a text zoomed out to its
      // fit leaves the image at its fit for the next page too, never at the
      // zoom it had before, which the next page's text then matched—fitted
      // to its width instead of whole (user, 2026-10-26).
      keepZoom()
      updateTransform()
    }

    /// The image's zoom kept for the session (`ViewerZoom.imageKey`): "fit",
    /// or its zoom over its fit, which the next image shown lays at
    /// (`fitToViewport`) whatever its size or shape (user, 2026-10-30).
    /// Every zoom the reader makes keeps it—the image's own, the overlay's,
    /// and the text's matched onto it—so a turn never zooms back to a zoom
    /// the reader left.
    private func keepZoom() {
      sessionStorage.setItem(ViewerZoom.imageKey, atFit ? "fit" : doubleToString(surface.scale))
    }

    private func tellRegion() {
      if let onRegion, let region { onRegion(region) }
    }

    private var dragStartX: Double = 0
    private var dragStartY: Double = 0
    private var dragPanX: Double = 0
    private var dragPanY: Double = 0
    /// The window's listeners while a drag is under way, and only then.
    private var mouseMoveListener: Int32 = -1
    private var mouseUpListener: Int32 = -1

    /// Whether a drag draws a crop box rather than pans (a host's call, on
    /// an attached image), the box in image pixels (width 0: none), the
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
    /// The grid's lines (`drawGridLevels`), over the part of the image the
    /// viewport shows.
    private var gridLines: DOM.Element?
    private var readout: DOM.Element?
    /// An encoded zone on the image hovered by the pointer, in the 0–1000
    /// space (width 0: none), and its neutral outline element over the image.
    private var elementX: Double = 0
    private var elementY: Double = 0
    private var elementW: Double = 0
    private var elementH: Double = 0
    private var elementBox: DOM.Element?
    /// The grid levels drawn, as last set ("" none), so a pan sets nothing.
    private var gridLevels = ""
    /// Whether the crop box is the region, edited where its markup is
    /// written (a bbox in an editor): its drags are told as
    /// `onRegionEdit`, live and once more when they end, never as `onCrop`.
    private var editing = false
    /// Told x y w h (0–1000, whole, inside the image) as an edited region
    /// is moved or resized, `true` once the drag ends.
    var onRegionEdit: ((Int, Int, Int, Int, Bool) -> Void)?
    /// The vertices of an edited polygon zone (x y x y …, 0–1000), each a
    /// handle over the image, and their elements.
    private var vertices: [Int] = []
    private var vertexHandles: [DOM.Element] = []
    /// Told the vertex, its x and y (0–1000, whole) as one is dragged,
    /// `true` once the drag ends.
    var onVertexEdit: ((Int, Int, Int, Bool) -> Void)?
    /// What a drag on the box does: draws a new one, moves it, or resizes
    /// it from the corner it holds still (`anchorX`, `anchorY`).
    private enum CropDrag { case draw, move, resize }
    private var cropDrag = CropDrag.draw
    private var anchorX: Double = 0
    private var anchorY: Double = 0

    init(root: DOM.Element) {
      self.root = root
      serviceID = root.dataset["service-id"] ?? ""
      let vp = root.querySelector(".image-viewport")
      viewport = vp
      if let vp, let spinner = root.querySelector(".image-spinner") {
        compositor = TileCompositor(viewport: vp, spinner: spinner)
      }
      // Whenever the viewport resizes (a sidebar toggled, the window
      // resized, the panes sliding into the overlay and apart), the image
      // keeps what it shows: the same point at the viewport's middle and the
      // same zoom over its fit, found again (a pane made shorter fits the
      // whole image again, not its width alone), so it scales with its pane
      // at its fit or zoomed in alike (user, 2026-10-14: a zoomed image
      // held its size as the overlay's panes parted). An image put away
      // measures nothing, and some browsers call back on scroll with the
      // size unchanged.
      vp?.observeResize { [self] w, h in
        guard w > 0, h > 0 else { return }
        guard w != viewportW || h != viewportH else { return }
        // Moving with the overlay, it is the overlay's to place.
        guard !blending else { return }
        surface.resize(
          viewportWidth: w, viewportHeight: h,
          fit: ViewerZoom.Surface.fit(
            imageWidth: surface.imageWidth, imageHeight: surface.imageHeight, viewportWidth: w, viewportHeight: h))
        guard imageW > 0, imageH > 0 else { return }
        updateTransform()
      }
      setupGestures()
    }

    /// An image drawn here rather than by the page: one the manifest has
    /// and the page drew none for.
    static func make(serviceID: String) -> DOM.Element {
      let canvas = document.createElement(.div)
      canvas.className = "image-view"
      canvas.setAttribute(data("service-id"), serviceID)
      canvas.setAttribute(data("active"), "false")
      let viewport = document.createElement(.div)
      viewport.className = "image-viewport"
      viewport.setAttribute(data("dragging"), "false")
      let spinner = document.createElement(.div)
      spinner.className = "image-spinner"
      spinner.setAttribute(data("visible"), "false")
      spinner.appendChild(RotatingDottedRingSectorFactory.createElement())
      viewport.appendChild(spinner)
      canvas.appendChild(viewport)
      return canvas
    }

    /// The image, fitted to the viewport: its low-resolution copy, then the
    /// detail the fit asks for; or the first of `images` that loads, a plain
    /// image shown whole in place of the service (the archived copy of what
    /// was sent)—the service where none loads only as
    /// `live` lets it, else no image (`onNoImage`).
    func show(width: Int, height: Int, images: [String] = [], live: Bool = true) {
      imageW = width
      imageH = height
      fitToViewport()
      compositor?.setCanvas(serviceID: serviceID, width: width, height: height, images: images, live: live)
      updateTransform()
    }

    /// Put away: its tiles go, so only the image on screen holds images.
    /// The browser keeps what it fetched, and showing it again is quick.
    func hide() {
      compositor?.clear()
      endDrag()
      clearRegion()
      clearElement()
    }

    /// Laid again, the viewport having changed its size (fullscreen, the
    /// markup's pane put away): at its fit, or the session's zoom over it
    /// (`fitToViewport`).
    func refit() {
      guard imageW > 0, imageH > 0 else { return }
      fitToViewport()
      updateTransform()
    }

    /// Let go of everything outside the image.
    func detach() {
      endDrag()
      compositor?.detach()
    }

    /// What showing an image of `width` by `height` in this image's
    /// viewport asks for first (its first copies, at the viewport's fit),
    /// fetched ahead for the images beside the one on screen: the URLs it
    /// then asks for, so they come from the browser's cache. Its service's:
    /// only for an image that reads its service (`ArtifactView`'s
    /// `readsService`), never one changed at its source.
    func openingURLs(serviceID: String, width: Int, height: Int) -> [String] {
      TileCompositor.openingURLs(
        serviceID: serviceID, width: width, height: height, viewportW: viewportW, viewportH: viewportH)
    }

    /// How long a preload of `serviceID`'s images may wait: its host's
    /// timeout for whole images; nil for the browser's own.
    func preloadTimeout(serviceID: String) -> Double? {
      TileCompositor.preloadTimeout(serviceID: serviceID)
    }

    /// `callback`, once the image shows all its view needs.
    func whenSettled(_ callback: @escaping () -> Void) {
      compositor?.whenSettled(callback)
    }

    private func fitToViewport() {
      guard let vp = viewport, let rect = vp.getBoundingClientRect() else { return }
      let width = rect.width > 0 ? rect.width : 900
      let height = rect.height > 0 ? rect.height : 500
      // At its fit, unless the session zoomed the images (a turn and a
      // reload keep it): at the kept zoom over this image's own fit
      // (`keepZoom`), so an image of another size or shape shows as much
      // of its page as the last did (user, 2026-10-30).
      surface.lay(
        viewportWidth: width, viewportHeight: height,
        fit: ViewerZoom.Surface.fit(
          imageWidth: surface.imageWidth, imageHeight: surface.imageHeight, viewportWidth: width,
          viewportHeight: height),
        scale: parseDouble(sessionStorage.getItem(ViewerZoom.imageKey) ?? ""))
    }

    /// Whether the reader's overlay holds the scan still (user,
    /// 2026-10-14): while it is on, no wheel, drag, pinch, touch or key
    /// pans or zooms it.
    private var locked: Bool {
      stringEquals(root.closest(".artifact-view")?.getAttribute(data("overlay-active")) ?? "", "true")
    }

    /// Smaller than the viewport: centered, no panning. Larger: no empty
    /// gap at any edge.
    private func clampPan() {
      surface.clampPan()
    }

    private func updateTransform() {
      compositor?.update(panX: panX, panY: panY, zoom: zoom, viewportW: viewportW, viewportH: viewportH)
      drawCrop()
      drawRegion()
      drawElement()
      drawVertices()
      drawWord()
      drawQuote()
    }

    // MARK: - A spot, a word

    /// What the image shows as a spot: the point of it at the viewport's
    /// middle (fractions of it) and its zoom (viewport pixels per image
    /// pixel); nil before it has a size.
    /// Whether the image rests at its fit, following the viewport.
    var isAtFit: Bool { atFit }

    var spot: (centerX: Double, centerY: Double, zoom: Double)? {
      guard imageW > 0, imageH > 0, zoom > 0, viewportW > 0 else { return nil }
      return (
        (viewportW / 2 - panX) / (Double(imageW) * zoom), (viewportH / 2 - panY) / (Double(imageH) * zoom), zoom
      )
    }

    /// Where the image is shown (user, 2026-10-28: the overlay lays the
    /// edition on the image, never the image on the edition): its
    /// viewport's place in the window, its pan and zoom (the viewport's
    /// pixels per image pixel) and its own size in pixels; nil before it
    /// has one.
    var placement: (x: Double, y: Double, panX: Double, panY: Double, zoom: Double, width: Double, height: Double)? {
      guard imageW > 0, imageH > 0, zoom > 0, let box = viewport?.getBoundingClientRect(), box.width > 0 else {
        return nil
      }
      return (box.x, box.y, panX, panY, zoom, Double(imageW), Double(imageH))
    }

    /// The overlay's zoom, the image's (user, 2026-10-28): by `factor`
    /// about a point of the window, held to its fit and its actual size,
    /// the edition laid on it following. The overlay holds the image's own
    /// gestures (`locked`); this is the overlay's.
    func zoomInOverlay(by factor: Double, clientX: Double, clientY: Double) {
      guard imageW > 0, imageH > 0, factor > 0, let box = viewport?.getBoundingClientRect() else { return }
      surface.zoom(to: zoom * factor, aboutX: clientX - box.x, y: clientY - box.y)
      // Kept as the image's own zoom is: the next image turned to in the
      // overlay lays at it, never back at the zoom the overlay was entered
      // at (user, 2026-10-30).
      keepZoom()
      updateTransform()
    }

    /// The overlay's fit, the image's (its 0 key): back to its fit, about
    /// the viewport's middle, and the fit kept for the session (user,
    /// 2026-10-30)—where `refit` lays it at the session's kept zoom again.
    func fitInOverlay() {
      guard imageW > 0, imageH > 0 else { return }
      surface.zoom(to: minZoom, aboutX: viewportW / 2, y: viewportH / 2)
      keepZoom()
      updateTransform()
    }

    /// The overlay's pan, the image's, by `dx`, `dy` (the window's pixels).
    func panInOverlay(by dx: Double, _ dy: Double) {
      guard imageW > 0, imageH > 0 else { return }
      surface.pan(by: dx, dy)
      updateTransform()
    }

    /// Whether the overlay is moving the image (`blend`): its viewport's
    /// resizing leaves it be.
    private var blending = false

    /// The image on its way between its own view (`own`, a spot) and where
    /// the overlay lays it (user, 2026-10-14): at the scale and place that
    /// put the top edge of its text block (`zone`, its corners in the
    /// 0–1000 space) on the rendered text block's laid box (`target`: left,
    /// top, right, bottom in the window), `progress` (eased) of the way
    /// there; its own view at 0. As the panes slide, each frame: coming on,
    /// it zooms into the text's place as it fades out; going off, back into
    /// its pane as it fades in.
    func blend(own: (centerX: Double, centerY: Double, zoom: Double), zone: [Double], target: [Double], progress: Double) {
      guard zone.count == 8, target.count == 4, imageW > 0, imageH > 0,
        let box = viewport?.getBoundingClientRect(), box.width > 0, box.height > 0
      else { return }
      blending = true
      viewportW = box.width
      viewportH = box.height
      minZoom = min(viewportW / Double(imageW), viewportH / Double(imageH))
      let x0 = zone[0] / Self.zoneExtent * Double(imageW)
      let y0 = zone[1] / Self.zoneExtent * Double(imageH)
      let x1 = zone[2] / Self.zoneExtent * Double(imageW)
      let y1 = zone[3] / Self.zoneExtent * Double(imageH)
      let span = ((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)).squareRoot()
      guard span > 0 else { return }
      let laidZoom = (target[2] - target[0]) / span
      let laidX = target[0] - box.x - x0 * laidZoom
      let laidY = target[1] - box.y - y0 * laidZoom
      // Its own end as it will rest (`showSpot`): its zoom within its reach,
      // its pan held to its viewport. Unheld, the blend aimed past where the
      // image then stops, and it jumped there once the overlay was off
      // (user, 2026-10-26).
      let ownZoom = max(minZoom, min(max(maxZoom, own.zoom), own.zoom))
      let width = Double(imageW) * ownZoom, height = Double(imageH) * ownZoom
      var ownX = viewportW / 2 - own.centerX * width
      var ownY = viewportH / 2 - own.centerY * height
      ownX = width <= viewportW ? (viewportW - width) / 2 : min(0, max(viewportW - width, ownX))
      ownY = height <= viewportH ? (viewportH - height) / 2 : min(0, max(viewportH - height, ownY))
      let p = max(0, min(1, progress))
      zoom = ownZoom + (laidZoom - ownZoom) * p
      panX = ownX + (laidX - ownX) * p
      panY = ownY + (laidY - ownY) * p
      updateTransform()
    }

    /// The overlay's move done: the image its own again.
    func endBlend() {
      blending = false
    }

    /// The image at `centerX`, `centerY` (fractions of it) at the
    /// viewport's middle, at `zoom` (the viewport's pixels per image pixel),
    /// within its own zoom's reach: where the reader was looking in the
    /// overlay as it goes off (user, 2026-10-14). Told to no one: it is the
    /// text's spot, matched.
    func showSpot(centerX: Double, centerY: Double, zoom value: Double) {
      guard imageW > 0, imageH > 0, minZoom > 0 else { return }
      zoom = max(minZoom, min(max(maxZoom, value), value))
      atFit = zoom <= minZoom
      panX = viewportW / 2 - centerX * Double(imageW) * zoom
      panY = viewportH / 2 - centerY * Double(imageH) * zoom
      clampPan()
      updateTransform()
    }

    /// The edition's word the reader points at, on the scan (user,
    /// 2026-10-14): each of its zones (`left`, `top`, `right`, `bottom` in
    /// the 0–1000 space; one a scan line, its zones' union: a word broken
    /// over lines has several, one the print spaces apart one, user,
    /// 2026-10-18) a translucent band over it, as
    /// the image is panned and zoomed; the image moved the least that
    /// brings them all into view where they are outside it. None clears
    /// them.
    func showWord(_ boxes: [[Double]]) {
      let boxes = boxes.filter { $0.count == 4 }
      guard !boxes.isEmpty, imageW > 0, imageH > 0 else {
        wordBoxes = []
        drawWord()
        return
      }
      wordBoxes = boxes.map { box in
        [
          box[0] / Self.zoneExtent * Double(imageW), box[1] / Self.zoneExtent * Double(imageH),
          box[2] / Self.zoneExtent * Double(imageW), box[3] / Self.zoneExtent * Double(imageH),
        ]
      }
      // Into view: each axis moved by the least that shows the word's
      // zones, their near edge first where they are larger than the view.
      var reach = wordBoxes[0]
      for box in wordBoxes {
        reach = [min(reach[0], box[0]), min(reach[1], box[1]), max(reach[2], box[2]), max(reach[3], box[3])]
      }
      let left = panX + reach[0] * zoom
      let right = panX + reach[2] * zoom
      let top = panY + reach[1] * zoom
      let bottom = panY + reach[3] * zoom
      var moved = false
      if left < 0 || right > viewportW {
        panX += left < 0 || right - left > viewportW ? -left : viewportW - right
        moved = true
      }
      if top < 0 || bottom > viewportH {
        panY += top < 0 || bottom - top > viewportH ? -top : viewportH - bottom
        moved = true
      }
      if moved {
        clampPan()
        updateTransform()
      } else {
        drawWord()
      }
    }

    /// The word's zones in image pixels (each left, top, right, bottom);
    /// empty for none.
    private var wordBoxes: [[Double]] = []
    /// One band a zone, made as they are first needed.
    private var wordBands: [DOM.Element] = []

    private func drawWord() {
      while wordBands.count < wordBoxes.count, let band = overlay("image-word") { wordBands.append(band) }
      for (index, band) in wordBands.enumerated() {
        guard index < wordBoxes.count else {
          band.setAttribute(.hidden, "")
          continue
        }
        let box = wordBoxes[index]
        place(band, x: box[0], y: box[1], width: box[2] - box[0], height: box[3] - box[1])
      }
    }

    /// The quote the reader is opened on, on the scan (user, 2026-10-31):
    /// each of its words' zones (`left`, `top`, `right`, `bottom` in the
    /// 0–1000 space) a band as a pointed word's (`showWord`), kept as the
    /// image is panned and zoomed, the image never moved for it. None
    /// clears them.
    func showQuote(_ boxes: [[Double]]) {
      quoteBoxes = boxes.filter { $0.count == 4 }
      drawQuote()
    }

    /// The quote's zones in the 0–1000 space; empty for none.
    private var quoteBoxes: [[Double]] = []
    /// One band a zone, made as they are first needed.
    private var quoteBands: [DOM.Element] = []

    private func drawQuote() {
      while quoteBands.count < quoteBoxes.count, let band = overlay("image-quote") { quoteBands.append(band) }
      for (index, band) in quoteBands.enumerated() {
        guard index < quoteBoxes.count, imageW > 0, imageH > 0 else {
          band.setAttribute(.hidden, "")
          continue
        }
        let box = quoteBoxes[index]
        let scaleX = Double(imageW) / Self.zoneExtent
        let scaleY = Double(imageH) / Self.zoneExtent
        place(
          band, x: box[0] * scaleX, y: box[1] * scaleY, width: (box[2] - box[0]) * scaleX,
          height: (box[3] - box[1]) * scaleY)
      }
    }

    /// A point of the viewport in the 0–1000 space over the image; nil off
    /// it or before the image has a size.
    func spacePoint(clientX: Double, clientY: Double) -> (x: Double, y: Double)? {
      guard imageW > 0, imageH > 0, zoom > 0, let rect = viewport?.getBoundingClientRect() else { return nil }
      let x = (clientX - rect.x - panX) / zoom
      let y = (clientY - rect.y - panY) / zoom
      guard x >= 0, y >= 0, x <= Double(imageW), y <= Double(imageH) else { return nil }
      return (x / Double(imageW) * Self.zoneExtent, y / Double(imageH) * Self.zoneExtent)
    }

    /// The space a zone's corners are in, over the whole image.
    private static let zoneExtent = 1000.0

    // MARK: - Hovered element zone

    /// An encoded zone on the image (0–1000) outlined in neutral
    /// `borderColorBase` while the pointer hovers it on the image.
    func showElement(x: Double, y: Double, width: Double, height: Double) {
      elementX = x
      elementY = y
      elementW = width
      elementH = height
      drawElement()
    }

    func clearElement() {
      guard elementW > 0 || elementH > 0 else { return }
      elementW = 0
      elementH = 0
      drawElement()
    }

    func setClickable(_ clickable: Bool) {
      if clickable {
        viewport?.setAttribute(data("clickable"), "true")
      } else {
        viewport?.removeAttribute(data("clickable"))
      }
    }

    private func drawElement() {
      guard elementW > 0, elementH > 0, imageW > 0, imageH > 0 else {
        elementBox?.setAttribute(.hidden, "")
        return
      }
      if case .none = elementBox { elementBox = overlay("image-element") }
      guard let box = elementBox else { return }
      let scaleX = Double(imageW) / 1000
      let scaleY = Double(imageH) / 1000
      place(box, x: elementX * scaleX, y: elementY * scaleY, width: elementW * scaleX, height: elementH * scaleY)
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

    /// A region edited on the image as well as in its markup: the crop
    /// box drawn over it, its corners and body dragged. An image taking a
    /// crop box for a call keeps it, and only shows the region.
    func editRegion(x: Int, y: Int, width: Int, height: Int, vertices: [Int] = []) {
      guard !cropping else {
        showRegion(x: x, y: y, width: width, height: height)
        return
      }
      // Mid-drag, the vertices are the drag's.
      if mouseMoveListener < 0 { self.vertices = vertices }
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
      drawVertices()
    }

    private func stopEditing() {
      guard editing else { return }
      editing = false
      vertices = []
      drawVertices()
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
        gridLines?.setAttribute(.hidden, "")
        readout?.setAttribute(.hidden, "")
        return
      }
      if case .none = grid { grid = gridElement() }
      if case .none = gridLines { gridLines = overlay("image-grid-lines") }
      if let grid {
        place(grid, x: 0, y: 0, width: Double(imageW), height: Double(imageH))
        grid.setAttribute(data("labels"), zoom < minZoom * Self.gridLabelsFrom ? "off" : "on")
      }
      if let gridLines { drawGridLevels(gridLines) }
      if case .none = regionDim { regionDim = overlay("image-region-dim") }
      if case .none = regionBox { regionBox = overlay("image-region") }
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
      guard let grid = overlay("image-grid") else { return nil }
      var value = 0
      while value <= 1000 {
        for axis in ["x", "y"] {
          // The 0 corner is named once, on the top edge.
          if value == 0, stringEquals(axis, "y") { continue }
          let label = document.createElement(.div)
          label.className = "image-grid-label"
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

    /// How many times its fit the image is zoomed before the grid's edges
    /// are named (`data-labels`).
    static let gridLabelsFrom = 2.0

    /// The grid's levels, those whose lines stand at least 4px apart as
    /// the image is shown: each a gradient a line wide, repeating at its
    /// spacing, one an axis, the finer the fainter, on a layer over the
    /// part of the image the viewport shows, each level's phase the pan's
    /// (user, 2026-10-28: drawn over the whole image at its zoom, tens of
    /// thousands of pixels, the browser left the lines out at some zooms).
    /// Named on the layer (`data-levels`, "100 50 10") for whoever reads it.
    private func drawGridLevels(_ lines: DOM.Element) {
      let shownW = Double(imageW) * zoom
      let shownH = Double(imageH) * zoom
      let left = max(0, panX)
      let top = max(0, panY)
      let right = min(viewportW, panX + shownW)
      let bottom = min(viewportH, panY + shownH)
      guard right > left, bottom > top else {
        lines.setAttribute(.hidden, "")
        return
      }
      lines.removeAttribute(.hidden)
      lines.style.setProperty("left", pixels(left))
      lines.style.setProperty("top", pixels(top))
      lines.style.setProperty("width", pixels(right - left))
      lines.style.setProperty("height", pixels(bottom - top))
      var layers: [String] = []
      var names: [String] = []
      for (units, strength) in [(100, "40%"), (50, "28%"), (10, "20%"), (5, "14%"), (1, "10%")] {
        let stepX = shownW * Double(units) / 1000
        let stepY = shownH * Double(units) / 1000
        guard stepX >= 4, stepY >= 4 else { break }
        let color = stringJoin(["color-mix(in srgb, var(--color-base) ", strength, ", transparent)"], separator: "")
        // Repeating at the level's exact pitch from where the image's own
        // lines fall on the layer, never a tile the browser rounds to a
        // pixel: tiles rounded level by level drifted the fine lines off
        // the coarse ones as the image was zoomed (user, 2026-10-27).
        for (direction, step, offset) in [("right", stepX, left - panX), ("bottom", stepY, top - panY)] {
          let phase = offset - (offset / step).rounded(.down) * step
          layers.append(
            stringJoin(
              [
                "repeating-linear-gradient(to ", direction, ", ", color, " ", pixels(-phase), " ", pixels(1 - phase),
                ", transparent ", pixels(1 - phase), " ", pixels(step - phase), ")",
              ], separator: ""))
        }
        names.append(intToString(units))
      }
      let levels = stringJoin(names, separator: " ")
      let key = stringJoin(layers, separator: ", ")
      guard !stringEquals(key, gridLevels) else { return }
      gridLevels = key
      lines.setAttribute(data("levels"), levels)
      lines.style.setProperty("background-image", key)
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
      if case .none = readout { readout = overlay("image-readout") }
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
        cropBox = overlay("image-crop")
        for corner in ["nw", "ne", "sw", "se"] {
          let handle = document.createElement(.div)
          handle.className = "image-crop-handle"
          handle.setAttribute(data("corner"), corner)
          cropBox?.appendChild(handle)
        }
      }
      guard let box = cropBox else { return }
      place(box, x: cropX, y: cropY, width: cropW, height: cropH)
    }

    /// The vertices' handles over the image, one a vertex, placed as the
    /// image is panned and zoomed; the spare ones hidden.
    private func drawVertices() {
      guard editing, imageW > 0, imageH > 0 else {
        for handle in vertexHandles { handle.setAttribute(.hidden, "") }
        return
      }
      let count = vertices.count / 2
      while vertexHandles.count < count {
        guard let handle = overlay("image-vertex") else { break }
        vertexHandles.append(handle)
      }
      for (index, handle) in vertexHandles.enumerated() {
        guard index < count else {
          handle.setAttribute(.hidden, "")
          continue
        }
        handle.removeAttribute(.hidden)
        handle.style.setProperty("left", pixels(panX + Double(vertices[index * 2]) / 1000 * Double(imageW) * zoom))
        handle.style.setProperty("top", pixels(panY + Double(vertices[index * 2 + 1]) / 1000 * Double(imageH) * zoom))
      }
    }

    /// The vertex a point of the viewport is on (within a handle's reach),
    /// or -1.
    private func vertexAt(clientX: Double, clientY: Double) -> Int {
      guard editing, imageW > 0, imageH > 0, let rect = viewport?.getBoundingClientRect() else { return -1 }
      let x = clientX - rect.x
      let y = clientY - rect.y
      let reach = 8.0
      var found = -1
      var nearest = reach * reach
      var index = 0
      while index * 2 + 1 < vertices.count {
        let vx = panX + Double(vertices[index * 2]) / 1000 * Double(imageW) * zoom
        let vy = panY + Double(vertices[index * 2 + 1]) / 1000 * Double(imageH) * zoom
        let distance = (x - vx) * (x - vx) + (y - vy) * (y - vy)
        if distance <= nearest {
          nearest = distance
          found = index
        }
        index += 1
      }
      return found
    }

    /// A drag on a vertex's handle: the vertex follows the pointer, kept
    /// inside the image, the box around the polygon with it; told live and
    /// once more when the drag ends.
    private func beginVertex(_ index: Int) {
      viewport?.setAttribute(data("dragging"), "true")
      mouseMoveListener = window.addEventListener(.mousemove) { [self] e in
        let point = imagePoint(clientX: e.clientX, clientY: e.clientY)
        moveVertex(index, toX: point.x, y: point.y)
        onVertexEdit?(index, vertices[index * 2], vertices[index * 2 + 1], false)
      }
      mouseUpListener = window.addEventListener(.mouseup) { [self] _ in
        endDrag()
        onVertexEdit?(index, vertices[index * 2], vertices[index * 2 + 1], true)
      }
    }

    /// Vertex `index` at a point of the image (pixels), whole in the
    /// 0–1000 space; the region's box and the crop box follow.
    private func moveVertex(_ index: Int, toX px: Double, y py: Double) {
      guard index * 2 + 1 < vertices.count, imageW > 0, imageH > 0 else { return }
      vertices[index * 2] = max(0, min(1000, Int((px / Double(imageW) * 1000).rounded())))
      vertices[index * 2 + 1] = max(0, min(1000, Int((py / Double(imageH) * 1000).rounded())))
      if let box = MarkupRegion.box(around: vertices) {
        regionX = Double(box.x)
        regionY = Double(box.y)
        regionW = Double(box.width)
        regionH = Double(box.height)
        cropX = regionX * Double(imageW) / 1000
        cropY = regionY * Double(imageH) / 1000
        cropW = regionW * Double(imageW) / 1000
        cropH = regionH * Double(imageH) / 1000
      }
      drawCrop()
      drawRegion()
      drawVertices()
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

    /// The keys, on the focused image while it takes a box: Enter draws
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

    /// A touch on the scan the overlay holds still: taken, so the page
    /// neither scrolls nor zooms under it.
    private func lockedTouch(_ event: Event) {
      guard locked else { return }
      event.preventDefault()
    }

    private func setupGestures() {
      guard let vp = viewport else { return }
      _ = vp.addEventListener("touchstart", { [self] event in lockedTouch(event) }, capture: false, passive: false)
      _ = vp.addEventListener("touchmove", { [self] event in lockedTouch(event) }, capture: false, passive: false)

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
          let vertex = vertexAt(clientX: e.clientX, clientY: e.clientY)
          if vertex >= 0 {
            beginVertex(vertex)
            return
          }
          let part = cropPart(clientX: e.clientX, clientY: e.clientY)
          if !stringIsEmpty(part) {
            beginCrop(clientX: e.clientX, clientY: e.clientY, part: part)
            return
          }
        }
        guard !locked else { return }
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
            panX = (viewportW - Double(imageW) * zoom) / 2
            updateTransform()
          }
        }
      }

      // The pointer over a box's corner or body says what a drag would do.
      vp.addEventListener(.mousemove) { [self] e in
        showReadout(clientX: e.clientX, clientY: e.clientY)
        guard mouseMoveListener < 0, cropping || editing else { return }
        let part = vertexAt(clientX: e.clientX, clientY: e.clientY) >= 0
          ? "vertex" : cropPart(clientX: e.clientX, clientY: e.clientY)
        if stringIsEmpty(part) {
          vp.removeAttribute(data("crop-hover"))
        } else {
          vp.setAttribute(data("crop-hover"), part)
        }
      }

      vp.addEventListener(.mouseleave) { [self] _ in readout?.setAttribute(.hidden, "") }

      // The wheel, and Safari's trackpad pinch (WebKit's gesture events, not
      // the ctrl+wheel other browsers send, which the wheel zooms by): the
      // model every image zoomed where it stands shares. Always taken: the
      // page never scrolls or zooms over the image.
      zoomInput = ViewerZoom.Input(
        on: vp, takes: { true }, current: { [self] in zoom },
        zoomTo: { [self] value, x, y in
          guard imageW > 0, imageH > 0, !locked else { return }
          zoom(to: value, aboutX: x, y: y)
        })

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
        guard imageW > 0, imageH > 0, !locked else { return }
        guard let command = ViewerZoom.command(forKey: e.key) else { return }
        switch command {
        case .zoomIn, .zoomOut:
          zoom(to: zoom * command.factor, aboutX: viewportW / 2, y: viewportH / 2)
        case .actualSize:
          zoom(to: ViewerZoom.actualSize, aboutX: viewportW / 2, y: viewportH / 2)
        case .pan(let x, let y):
          surface.pan(by: x, y)
          updateTransform()
          tellRegion()
        }
        e.preventDefault()
        e.stopPropagation()
      }
    }

    /// `value`, clamped to the fit and the actual size, about a point of
    /// the viewport, kept for the session.
    private func zoom(to value: Double, aboutX cx: Double, y cy: Double) {
      // Held still by the overlay.
      guard !locked else { return }
      surface.zoom(to: value, aboutX: cx, y: cy)
      keepZoom()
      updateTransform()
      tellRegion()
    }
  }
#endif
