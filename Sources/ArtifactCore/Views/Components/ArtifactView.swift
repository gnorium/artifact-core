#if SERVER
  import CSSBuilder
  import DesignTokens
  import DOMBuilder
  import HTMLBuilder
  import WebComponents
  import WebTypes

  /// An object read page by page: a pager in its footer, markup of
  /// each page and, in its canvas slot, the object's images.
  ///
  /// The pages are the manifest's canvases when the viewer is given one
  /// (their order, labels and sizes), else the markup's own pages. The
  /// canvas slot is an add-in: without it the viewer is a pager over the
  /// markup; with it, each canvas (a ``CanvasView``, or a view wrapping
  /// one) is shown beside the markup while its page is on screen, and
  /// only the canvas on screen reads its image. A canvas the manifest has and
  /// the slot lacks is drawn by the reader when it is paged to. Without a
  /// markup the viewer is the object alone, every canvas drawn so.
  public struct ArtifactView: HTMLContent {
    /// Where the canvases to page are read; empty pages the markup.
    /// The answer is JSON in the viewer's own shape, not a IIIF manifest:
    /// `{"label":…,"canvases":[{"id":…,"w":…,"h":…,"l":…}]}`, each canvas by
    /// its image service, its size and its label—the host's server reads
    /// the manifest and answers so. `{"canvases":[],"error":"…"}` says why
    /// there are none.
    let manifestURL: String
    let style: CSSStyle
    /// Which canvas the viewer opens on, when the page knows better than the
    /// reader's last visit—a deep link to one page of the object.
    ///
    /// ``startService`` names it by image service, which is what a deep link
    /// should carry: a page number only means the same page if the manifest is
    /// ordered the way the page that linked to it was. ``startCanvas`` is the
    /// positional fallback.
    let startCanvas: Int?
    let startService: String?
    /// Markup of the object, shown beside it: a transcription, a
    /// translation, an apparatus. Any descendant carrying `data-service-id` is
    /// shown only while the canvas with that image service is the one on
    /// screen, so the markup pages with the object.
    let markup: [DOM.Node]
    /// Whether the footer carries a switch from the markup to the code it
    /// was made from—markup, in the usual case. The markup marks its two
    /// layers with `data-layer`, `"rendering"` and `"markup"`, and the
    /// switch swaps them in place.
    let rawSwitch: Bool
    /// What the switch is for, behind an ⓘ beside it, where the page needs to
    /// say—an editor that takes its edits in the code says so here.
    let rawSwitchInfo: String?
    /// The object's images, one per canvas, each naming its image service in
    /// `data-service-id`: shown, like the markup, only while its canvas
    /// is on screen, and read only then.
    let canvas: [DOM.Node]
    /// Whether the header carries a switch that shows the canvas slot, the
    /// page images, beside the markup (user, 2026-09-29): only with both
    /// markup and page images (user, 2026-10-09); with no markup
    /// the images are all there is and always show, with no switch. The
    /// reader offers the switch only once its manifest confirms an image
    /// (user, 2026-10-10): never while the manifest is unread.
    /// Off by default: the markup takes the whole width and no page
    /// image is fetched.
    /// The choice holds for the browser session (`sessionStorage`), across
    /// pages of the reader and the site's pages alike, and every reader on
    /// the page follows it. Without the switch the canvas always shows.
    let canvasSwitch: Bool
    /// Controls the host adds to the header, at its end (a Find button).
    let actions: [DOM.Node]
    /// A row the host adds under the header's own, the width of the viewer
    /// (a find bar), shown while the host marks the row open
    /// (`data-open="true"` on `.artifact-header-bar`). Closed, it takes no
    /// room: an empty row still took the header's gap under the controls.
    let bar: [DOM.Node]
    /// How many pages the markup has, when the host knows: the pager
    /// counts them from the start, before a manifest is read (which may
    /// count its canvases instead). Nil: unknown until the reader counts
    /// them, and the pager is hidden until then—never "of —".
    let pageCount: Int?

    public init(
      manifestURL: String = "",
      style: CSSStyle = .default,
      startCanvas: Int? = nil,
      startService: String? = nil,
      rawSwitch: Bool = false,
      rawSwitchInfo: String? = nil,
      canvasSwitch: Bool = false,
      pageCount: Int? = nil,
      @HTMLBuilder markup: () -> [DOM.Node] = { [] },
      @HTMLBuilder canvas: () -> [DOM.Node] = { [] },
      @HTMLBuilder actions: () -> [DOM.Node] = { [] },
      @HTMLBuilder bar: () -> [DOM.Node] = { [] }
    ) {
      self.manifestURL = manifestURL
      self.style = style
      self.startCanvas = startCanvas
      self.startService = startService
      self.rawSwitch = rawSwitch
      self.rawSwitchInfo = rawSwitchInfo
      self.canvasSwitch = canvasSwitch
      self.pageCount = pageCount.flatMap { $0 > 0 ? $0 : nil }
      self.markup = markup()
      self.canvas = canvas()
      self.actions = actions()
      self.bar = bar()
    }

    /// Whether the header shows the page-images switch: only when there are
    /// page images to show. Drawn hidden: the reader shows it once the
    /// manifest confirms an image (`data-canvas-confirmed`).
    private var switchesCanvas: Bool { canvasSwitch && !canvas.isEmpty && !markup.isEmpty }

    /// The header carries no title (user, 2026-10-09): on a biblio page
    /// the work is already the page's heading or its node's description,
    /// and a quotation's reader is credited under it. It names the page
    /// on screen at its start (user, 2026-10-10: the canvas label moved
    /// up from the footer, Raw down to the footer's start, so Raw sits at
    /// the bottom left of every box), and the host's controls take its
    /// end.

    public func build() -> DOM.Node {
      // A canvas the reader draws itself, for a canvas the slot lacks, is
      // styled by the canvas's own sheet, which the page must link.
      _ = CanvasView(serviceID: "").build()

      return div {
        // ── Header ──────────────────────────────────────────────────────────
        header {
          // One row of controls, never wrapped: where a narrow reader cannot
          // hold them all, the row scrolls sideways (user, 2026-09-30).
          div {
          // The page on screen, by its canvas's label, at the row's start
          // (user, 2026-10-10); the host's controls take the rest of the
          // row, at its end.
          span {}
            .id("artifact-canvas-label")
            .class("artifact-canvas-label")
            .data("edge-fade", "expand")
          if !actions.isEmpty || switchesCanvas {
            div {
              actions
              // An image switch is distinct from the adjacent page-navigation arrows.
              if switchesCanvas {
                ToggleButtonView(
                  label: "Resemblance",
                  icon: IconView(
                    icon: { s in ImageIconView(size: s) }, size: sizeIconSmall),
                  modelValue: false,
                  weight: .plain,
                  buttonColor: .gray,
                  iconOnly: true,
                  ariaLabel: "Resemblance",
                  size: .medium,
                  class: "artifact-canvas-toggle"
                )
              }
            }
            .class("artifact-header-actions")
          }
          }
          .class("artifact-header-row")

          if !bar.isEmpty {
            // The shell's height moves; its inset is the panel's, as an
            // alert's is, so closed it is truly nothing.
            div {
              div { bar }
                .class("artifact-header-bar-panel")
            }
              .class("artifact-header-bar")
              .data("open", false)
          }
        }
        .class("artifact-header")

        // ── Viewer body with prev/next overlaid on edges ─────────────────────
        div {
          // The markup first, the object beside it.
          //
          // The markup is what the page is for: it arrives with the document,
          // it carries the figures cut from the facsimile inline, and it is
          // what a reader reads. The object corroborates it—you look across
          // when you doubt a word. Putting the image first made the thing being
          // checked come before the thing being read, and on a narrow screen it
          // pushed the markup below the fold entirely.
          // The markup of the object, beside the object. It is a sibling of
          // the object rather than a block under the viewer so that the two
          // page together and fullscreen carries both.
          if !markup.isEmpty {
            div {
              markup
            }
            .id("artifact-markup")
            .class("artifact-markup")
            // A gloss opened in it covers it alone.
            .data("sheet-host", true)
          }

          // The object: the canvas of the page on screen. A viewer with no
          // markup is the object alone, its slot drawn empty for the
          // reader to fill with the manifest's canvases—a testament not yet
          // read, say, whose pages exist only as images.
          if !canvas.isEmpty || markup.isEmpty {
            div {
              canvas
            }
            .class("artifact-object")
          }
        }
        .id("artifact-viewer-container")
        .class("artifact-viewer-container")

        // ── Footer ───────────────────────────────────────────────────────────
        footer {
          // The switch between the markup and the code it was made from,
          // at the footer's start: the bottom left of the box, as Raw sits
          // on every box (user, 2026-10-10).
          div {
            if rawSwitch, !markup.isEmpty {
              ToggleButtonView(
                label: "Raw",
                icon: nil as HTML.HTMLSpanElement?,
                modelValue: false,
                weight: .static,
                buttonColor: .gray,
                fullWidth: false,
                ariaLabel: "Raw",
                indicateSelection: true,
                size: .medium,
                class: "artifact-raw-toggle",
                labelFontWeight: fontWeightNormal
              )
              if let info = rawSwitchInfo {
                // An icon on its own, on par with the row's 16px text, takes
                // the text's size, as the bars' other icons (user,
                // 2026-10-09).
                TooltipView(tooltip: info, class: "artifact-raw-info") {
                  IconView(icon: { size in [InfoIconView(size: size)] }, size: sizeIconSmall)
                }
              }
            }
          }
          .class("artifact-footer-start")

          // The page nav, beside fullscreen at the footer's end (user,
          // 2026-10-08): in the header it pushed the row past a phone's
          // width.
          PaginationView(
            currentPage: min((startCanvas ?? 0) + 1, pageCount ?? 1),
            totalPages: pageCount ?? 1,
            size: .medium,
            showControls: true,
            kind: "artifact",
            inputID: "artifact-page-input",
            totalID: "artifact-page-total",
            totalDisplay: pageCount.map { "\($0)" } ?? "—",
            ariaLabel: "Pages",
            inputAriaLabel: "Page number",
            class: "artifact-page-nav"
          )

          button {
            IconView(
              icon: { size in [FullscreenIconView(size: size)] }, size: sizeIconSmall)
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
      // Hidden until the reader knows the session's choice, so that a reader
      // left off never shows an empty column first.
      .data("canvas-shown", !switchesCanvas)
      // The images switch is drawn where the page names an image service,
      // but offered only once the manifest confirms an image (user,
      // 2026-10-10): hidden until the reader says so, and for good where
      // the manifest names none.
      .data("canvas-confirmed", !switchesCanvas)
      // Whether the pager knows its total; the reader says so once it has
      // counted the pages.
      .data("pages-known", pageCount != nil)
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
          // The controls' row, and the host's bar in a row of its own under
          // it.
          flexDirection(.column)
          alignItems(.stretch)
          // No gap: the bar carries the 12 above it as its own inset, so
          // closed to no height it takes no room, and its opening animates
          // its height alone (`TestamentFindHydration`).
          // The bar is 56 and its controls medium, 40 (user, 2026-10-10):
          // the 8 on every side of them is the row's own, so its label and
          // controls clear the box's rounded corners and its scrollport
          // takes in a control's focus ring, which it would otherwise cut
          // off.
          padding(0)
          borderBlockEnd(borderWidthBase, .solid, borderColorBase)
          minHeight(minSizeInteractiveTouch)
        }
        // One row, never wrapped: past its width it scrolls sideways under
        // a swipe, with no scrollbar drawn (the tabs' pattern), and never
        // the page.
        descendant(".artifact-header-row") {
          display(.flex)
          alignItems(.center)
          gap(spacing12)
          minWidth(0)
          padding(spacing8)
          overflowX(.auto)
          overflowY(.hidden)
          scrollbarWidth(.none)
          pseudoElement(.webkitScrollbar) { display(.none).important() }
        }
        // The host's controls take the rest of the row, at its end (the
        // start in RTL), the page's label alone at the row's start.
        descendant(".artifact-header-actions") {
          display(.flex)
          flexGrow(1)
          alignItems(.center)
          justifyContent(.flexEnd)
          gap(spacing8)
        }
        // The row above it again: 32 controls, 4 on every side, 8 under
        // the row (its 4 and the panel's 4). The inset is the panel's,
        // never the shell's: a shell's height counts its padding, so
        // animated to 0 it stopped at its padding and stalled there, then
        // grew.
        descendant(".artifact-header-bar") {
          minWidth(0)
        }
        descendant(".artifact-header-bar-panel") {
          minWidth(0)
          padding(spacing8)
        }
        descendant(".artifact-header-bar[data-open='false']") {
          display(.none)
        }
        selector("& .artifact-page-nav", "& .artifact-raw-toggle") {
          flexShrink(0)
        }
        // Its total unknown, the pager waits unseen rather than read "of —".
        selector("&[data-pages-known='false'] .artifact-page-nav") {
          visibility(.hidden)
        }
        selector("&[data-canvas-confirmed='false'] .artifact-canvas-toggle") {
          display(.none)
        }
        // Beside the switch it explains, the footer's own gap from it.
        descendant(".artifact-raw-info") {
          flexShrink(0)
          display(.inlineFlex)
          alignItems(.center)
        }
        // Raw at the footer's start, the pager and fullscreen at its end.
        descendant(".artifact-footer-start") {
          display(.flex)
          flex(1)
          alignItems(.center)
          gap(spacing8)
          minWidth(0)
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
          // screen the object takes the top half and its markup the bottom,
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
        descendant(".artifact-markup") {
          // Half the surface, whichever way the two are laid out. Without the
          // zero minimums a flex item never shrinks past its content, and a
          // page of verse would take two thirds of the viewer.
          flex(1, 1, perc(50))
          minWidth(0)
          minHeight(0)
          overflow(.auto)
          // No padding of its own (user, 2026-10-10): the markup view
          // carries the text's inset, so a state ring drawn on the pane
          // (TestamentView) sits on the pane's own edges, with the canvas
          // shown and put away alike.
          padding(0)
          // The divider sits on the markup's far edge, because the markup
          // comes first: to its right when the two are side by side, under it
          // when they stack. It used to be a leading border, from when the
          // object led and the markup sat to its right.
          borderInlineEnd(borderWidthBase, .solid, borderColorBase)
          backgroundColor(backgroundColorBase)
          media(maxWidth(maxWidthBreakpointMobile)) {
            borderInlineEnd(.none).important()
            borderBlockEnd(borderWidthBase, .solid, borderColorBase).important()
          }
        }
        // The page images switched off: the markup alone, the whole
        // width, with no divider beside or under it.
        selector("&[data-canvas-shown='false'] .artifact-object") {
          display(.none)
        }
        selector("&[data-canvas-shown='false'] .artifact-markup") {
          borderInlineEnd(.none).important()
          borderBlockEnd(.none).important()
        }
        // The switch is in the header and the layers are in the pane, so the
        // rule that ties them lives on the viewer, where both are in scope.
        selector("&:has(.artifact-raw-toggle[aria-pressed='true']) .artifact-markup [data-layer='rendering']") {
          display(.none)
        }
        // Flex, not block: a layer holding one element also holds the
        // whitespace around it in the markup, and a block container turns that
        // into a line box above and below—a gap that looks like padding
        // nobody asked for. A flex container drops whitespace-only children.
        selector("&:has(.artifact-raw-toggle[aria-pressed='true']) .artifact-markup [data-layer='markup']") {
          display(.flex)
          flexDirection(.column)
          width(perc(100))
          minWidth(0)
          maxWidth(perc(100))
          // The markup pane owns both scrollbars. Giving this layer an
          // overflow value creates a second vertical scroller in Raw mode.
          overflow(.visible)
        }
        // Raw XML is intentionally preformatted and can contain very long
        // lines. Let it contribute overflow to `.artifact-markup`, which is
        // the single scroll owner for the entire markup half.
        descendant(".artifact-markup [data-layer='markup'] .code-view") {
          width(perc(100))
          minWidth(0)
          maxWidth(perc(100))
          overflow(.visible)
        }
        // The code itself keeps the width of its longest line (CodeView's
        // own): the block above holds the row at the pane's width, so the
        // line overflows into the pane's scroller rather than widening the
        // row, and the text's box still spans its text—what a selection
        // dragged past the pane's edge extends into.
        // Only the markup and the canvas of the page on screen. The rest
        // stay in the document so that paging is a class change, not a fetch.
        selector(
          ".artifact-markup [data-service-id][data-active='false']",
          ".artifact-object [data-service-id][data-active='false']"
        ) {
          display(.none)
        }
        // 56, as the header: 40 controls, 8 on every side of them. The
        // pager and fullscreen at the row's end, the start in RTL.
        // Never squeezed by the viewer's column: a header grown tall (its
        // find bar open) takes the markup's room, never the pager's.
        descendant(".artifact-footer") {
          flexShrink(0)
          justifyContent(.flexEnd)
          gap(spacing8)
          padding(spacing8)
          minHeight(minSizeInteractiveTouch)
          boxSizing(.borderBox)
          borderBlockStart(borderWidthBase, .solid, borderColorBase)
        }
        descendant(".artifact-canvas-label") {
          fontSize(fontSizeMedium16)
          color(colorSubtle)
          flex(1)
          minWidth(0)
        }
        fadeOverflow("& .artifact-canvas-label")
        selector(".artifact-fullscreen-button") {
          display(.flex)
          alignItems(.center)
          justifyContent(.center)
          width(minSizeInteractiveTouch)
          height(minSizeInteractiveTouch)
          borderRadius(borderRadiusBase)
          border(.none)
          backgroundColor(.transparent)
          color(colorSubtle)
          cursor(.pointer)
          flexShrink(0)
          pseudoClass(.hover) { color(colorBase) }
        }
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

    /// Where the page-images switch keeps its state: for the browser
    /// session, so it holds across the reader's pages and the site's, and is
    /// off again in a new session. Storage refused reads as off.
    static let canvasShownKey = "gnorium:artifact-page-images"

    /// The page images shown or put away in every reader on the page, as
    /// one reader's switch was pressed, and the choice kept for the session.
    static func showCanvases(_ shown: Bool) {
      sessionStorage.setItem(canvasShownKey, shown ? "true" : "false")
      for reader in instance?.readers ?? [] { reader.setCanvasShown(shown) }
    }

    /// The viewers under `root`, which may be a fragment swapped in after the
    /// page's own pass. A viewer already reading is left alone, and a reader
    /// whose viewer has left the document lets go of the window it listened
    /// to—its arrow keys would otherwise turn the pages of nothing.
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
        let manifestURL = viewer.dataset["manifest-url"] ?? ""
        // An empty viewer—a form with nothing chosen yet—has nothing to
        // read: canvases and no manifest to page them by.
        guard !stringIsEmpty(manifestURL) || viewer.querySelector(".artifact-object") == nil else { continue }
        viewer.setAttribute(data("artifact-hydrated"), "true")
        hydration.readers.append(
          ArtifactReader(
            root: viewer,
            manifestURL: manifestURL,
            startCanvas: parseInt(viewer.dataset["start-canvas"] ?? ""),
            startService: viewer.dataset["start-service"] ?? ""
          ))
      }
    }
  }

  /// One viewer, reading one object. An instance, not a namespace: a page
  /// may hold several viewers, and a second one used to take over the
  /// first's state—its canvases appended to the first's list and its pages
  /// turned by the first's arrows.
  ///
  /// It keeps the pages: which is on screen, the pager, the markup and
  /// the canvas that go with it. Each canvas reads its own image
  /// (`CanvasReader`), made the first time it is shown.
  private final class ArtifactReader: @unchecked Sendable {
    private var pageInput: DOM.Element?
    private var pageTotal: DOM.Element?
    private var canvasLabelEl: DOM.Element?
    private var prevBtn: DOM.Element?
    private var nextBtn: DOM.Element?

    /// The pages, by the image service each reads, with their sizes and
    /// labels where a manifest gives them.
    private var serviceIDs: [String] = []
    private var imageWidths: [Int] = []
    private var imageHeights: [Int] = []
    private var canvasLabels: [String] = []
    private var canvasIndex: Int = 0

    private var manifestURL: String = ""
    /// The canvas the page asked for, which outranks the one this reader was
    /// last on: a link to a page of the object means that page.
    private var startCanvas: Int?
    private var startService: String = ""
    private var markupPanes: [DOM.Element] = []
    /// The canvas slot, when the viewer has one, and the canvases read so far.
    private var object: DOM.Element?
    private var canvases: [CanvasReader] = []
    private var shownCanvas: CanvasReader?
    /// The canvases a host lets the reader draw a crop box on
    /// (`artifact-crop-mode`), by image service.
    private var cropServices: [String] = []
    /// The page-images switch, when the viewer has one, and whether the
    /// canvas shows: always without the switch.
    private var canvasToggle: DOM.Element?
    private var canvasShown = true

    private func storageKey() -> String { "gnorium:artifact-canvas:\(manifestURL)" }
    /// Where the reader was last on this manifest; markup paged without
    /// one opens at its start.
    private func saveCanvasIndex() {
      guard !stringIsEmpty(manifestURL) else { return }
      localStorage.setItem(storageKey(), "\(canvasIndex)")
    }
    private func savedCanvasIndex() -> Int {
      guard !stringIsEmpty(manifestURL) else { return 0 }
      return parseInt(localStorage.getItem(storageKey()) ?? "") ?? 0
    }

    /// The window and document listeners, so a reader whose viewer has left
    /// the page can let go of them.
    private var keyDownListener: Int32 = -1
    private var fullscreenListener: Int32 = -1
    private let root: DOM.Element

    /// Whether the viewer is still on the page. A form that swaps its body
    /// takes the old viewer with it, and nothing tells the reader.
    var isInDocument: Bool { document.body.contains(root) }

    /// Let go of everything outside the viewer. The viewer's own listeners
    /// went with it; the window's and the document's did not.
    func detach() {
      window.removeEventListener(.keydown, keyDownListener)
      document.removeEventListener(.fullscreenchange, fullscreenListener)
      if selectionListener >= 0 { document.removeEventListener("selectionchange", selectionListener) }
      for canvas in canvases { canvas.detach() }
    }

    init(
      root: DOM.Element,
      manifestURL: String,
      startCanvas: Int? = nil,
      startService: String = ""
    ) {
      self.root = root
      self.manifestURL = manifestURL
      self.startCanvas = startCanvas
      self.startService = startService
      markupPanes = root.querySelectorAll(".artifact-markup [data-service-id]")
      object = root.querySelector(".artifact-object")
      pageInput = root.querySelector("#artifact-page-input")
      pageTotal = root.querySelector("#artifact-page-total")
      canvasLabelEl = root.querySelector("#artifact-canvas-label")
      // The page turns are the pager's buttons now; the ids are kept so a
      // caller that still renders its own arrows keeps working.
      prevBtn =
        root.querySelector("#artifact-prev") ?? root.querySelector(".pagination-prev")
      nextBtn =
        root.querySelector("#artifact-next") ?? root.querySelector(".pagination-next")

      setupControls()
      setupLayers()
      setupCanvasSwitch()
      setupRegions()
      // A host turns the reader to a page by its image service (a find
      // bar's match): an `artifact-show-service` event on the viewer.
      _ = root.addEventListener("artifact-show-service") { [self] (event: Event) in
        if let index = self.canvasIndex(ofService: event.detail) { self.loadCanvas(index) }
      }
      // A crop box (a call's, on an attached canvas): `artifact-crop-mode`
      // names the services, one a line, a box may be drawn on (none: off);
      // `artifact-crop-clear` takes the box off one service (empty: all).
      // Each box drawn, moved or cleared is told as `artifact-crop-change`,
      // "<service> x y w h" in the 0–1000 space, or "<service>" cleared.
      _ = root.addEventListener("artifact-crop-mode") { [self] (event: Event) in
        self.cropServices = stringSplit(event.detail, separator: "\n").filter { !stringIsEmpty($0) }
        for canvas in self.canvases { canvas.setCropping(self.mayCrop(canvas.serviceID)) }
      }
      _ = root.addEventListener("artifact-crop-clear") { [self] (event: Event) in
        for canvas in self.canvases
        where stringIsEmpty(event.detail) || stringEquals(canvas.serviceID, event.detail) {
          canvas.clearCrop()
        }
      }
      // Or by its place in the sequence (0-based), as a roster of the
      // canvases names it: `artifact-show-canvas`.
      _ = root.addEventListener("artifact-show-canvas") { [self] (event: Event) in
        if let index = Int(event.detail) { self.loadCanvas(index) }
      }
      if stringIsEmpty(manifestURL) {
        pageMarkup()
      } else {
        loadManifest(url: manifestURL)
      }
    }

    /// The code switch changes the markup, not the image viewport.  Keep
    /// that state in the hydrated view instead of relying on `:has()`: that
    /// selector is not consistently reevaluated when `aria-pressed` changes
    /// in every browser context that hosts the reader.
    ///
    /// Markup with a translation follows its page's language switch too,
    /// which is not the viewer's: the page sets `data-translated` on
    /// an ancestor and tells each viewer with a `markup-translated` event.
    /// A viewer fetched in after the switch was pressed reads the attribute
    /// as it stands.
    private func setupLayers() {
      let raw = root.querySelector(".artifact-raw-toggle")
      if case .some = root.querySelector(".artifact-markup [data-layer='translated-rendering']") {
        translatable = true
      }
      rawVisible = stringEquals(raw?.getAttribute("aria-pressed") ?? "false", "true")
      translationVisible = stringEquals(
        root.closest("[data-translated]")?.getAttribute(data("translated")) ?? "false", "true")
      showLayers()
      _ = raw?.addEventListener("toggle-button-update") { [self] (event: Event) in
        self.rawVisible = stringEquals(event.detail, "true")
        self.showLayers()
      }
      _ = root.addEventListener("markup-translated") { [self] (event: Event) in
        self.translationVisible = stringEquals(event.detail, "true")
        self.showLayers()
      }
    }

    // MARK: - Regions

    /// The region the page's markup names where the caret or the selection
    /// is in its code (an editor's, or a read-only Raw's) and where the
    /// pointer rests (a read-only Raw's), drawn on the canvas on screen: the
    /// pointer's over the caret's. A canvas put away draws nothing and is
    /// not opened for it.
    ///
    /// A bbox under the caret in an editor is edited on the canvas too: its
    /// box's corners resize it and its body moves it (`CanvasReader`'s crop
    /// box), and with the caret in its value the arrows nudge it by 1 (with
    /// Shift, 10) and with Alt resize it; each change is written into the
    /// bbox, one edit a drag or a key, as typing would be.
    private var caretRegion: MarkupRegion?
    private var hoverRegion: MarkupRegion?
    /// The editor whose caret names `caretRegion`, when one does, and where
    /// its caret stands (a byte of its text).
    private var caretEditor: DOM.Element?
    private var caretOffset = 0
    /// A drag under way on the canvas, written into the bbox as it goes
    /// (outside the editor's history): the text node, where the value
    /// starts and how long it is now (UTF-16), and the value it began as.
    private var dragNode: DOM.Text?
    private var dragStart = 0
    private var dragLength = 0
    private var dragOriginal = ""
    private var selectionListener: Int32 = -1

    /// The code of the page on screen, under Raw: its editor, or its
    /// read-only blocks (the page's and its translation's).
    private static let rawCode = ".artifact-markup .tei-page[data-active='true'] .tei-page-raw .code-code"

    private func setupRegions() {
      selectionListener = document.addEventListener("selectionchange") { [self] _ in self.followCaret() }
      // Typing moves the caret, and changes what it is on even where it
      // stays.
      _ = root.addEventListener(.input) { [self] _ in self.followCaret() }
      _ = root.addEventListener(.mousemove) { [self] e in self.followPointer(x: e.clientX, y: e.clientY) }
      _ = root.addEventListener(.mouseleave) { [self] _ in self.setRegion(hover: nil) }
      // Before the editor's own keys, which keep the arrows to themselves.
      _ = root.addEventListener(
        .keydown,
        { [self] e in
          if self.nudge(key: e.key, shift: e.shiftKey, alt: e.altKey) {
            e.preventDefault()
            e.stopPropagation()
          }
        }, capture: true)
    }

    private func followCaret() {
      // A drag writes the value as it goes; the drag is what it says.
      if case .some = dragNode { return }
      guard let selection = window.getSelection(), let node = selection.focusNode else {
        setRegion(caret: nil, editor: nil)
        return
      }
      for code in root.querySelectorAll(Self.rawCode) where code.contains(node) {
        let caret = offset(in: code, node: node, offset: selection.focusOffset)
        caretOffset = caret
        setRegion(
          caret: region(in: code, caret: caret), editor: code.hasAttribute("data-code-editing") ? code : nil)
        return
      }
      setRegion(caret: nil, editor: nil)
    }

    private func followPointer(x: Double, y: Double) {
      guard let position = document.caretPositionFromPoint(x, y), let node = position.offsetNode else {
        setRegion(hover: nil)
        return
      }
      for code in root.querySelectorAll(Self.rawCode) where !code.hasAttribute("data-code-editing") && code.contains(node) {
        setRegion(hover: region(in: code, caret: offset(in: code, node: node, offset: position.offset)))
        return
      }
      setRegion(hover: nil)
    }

    /// A point of the code as a byte of its text: the text before it
    /// counted.
    private func offset(in code: DOM.Element, node: DOM.Node, offset: Int) -> Int {
      let before = document.createRange()
      before.setStart(code, 0)
      before.setEnd(node, offset)
      return before.toString().utf8.count
    }

    /// What the code names at a byte of its text, read against the page's
    /// zones.
    private func region(in code: DOM.Element, caret: Int) -> MarkupRegion? {
      let zones = code.closest(".tei-page")?.getAttribute(data("zones")) ?? ""
      return MarkupRegion.at(Array(code.textContent.utf8), caret: caret, zones: zones)
    }

    private func setRegion(caret region: MarkupRegion?, editor: DOM.Element?) {
      let sameEditor: Bool
      if case .some(let a) = caretEditor, case .some(let b) = editor {
        sameEditor = a.id == b.id
      } else if case .none = caretEditor, case .none = editor {
        sameEditor = true
      } else {
        sameEditor = false
      }
      caretEditor = editor
      guard !sameEditor || !Self.same(caretRegion, region) else {
        caretRegion = region
        return
      }
      caretRegion = region
      drawRegion()
    }

    private func setRegion(hover region: MarkupRegion?) {
      guard !Self.same(hoverRegion, region) else { return }
      hoverRegion = region
      drawRegion()
    }

    private static func same(_ a: MarkupRegion?, _ b: MarkupRegion?) -> Bool {
      if case .some(let a) = a, case .some(let b) = b { return a.isSame(as: b) }
      if case .none = a, case .none = b { return true }
      return false
    }

    private func drawRegion() {
      guard let canvas = shownCanvas else { return }
      if case .some(let region) = hoverRegion {
        canvas.showRegion(x: region.x, y: region.y, width: region.width, height: region.height)
      } else if case .some(let region) = caretRegion {
        if case .some = caretEditor, region.editable {
          canvas.editRegion(x: region.x, y: region.y, width: region.width, height: region.height)
        } else {
          canvas.showRegion(x: region.x, y: region.y, width: region.width, height: region.height)
        }
      } else {
        canvas.clearRegion()
      }
    }

    /// The bbox under the editor's caret, as its text now stands: the text
    /// node holding its value, and the value's place there (UTF-16).
    private func editedValue() -> (node: DOM.Text, start: Int, length: Int, region: MarkupRegion, value: String)? {
      guard let code = caretEditor else { return nil }
      let text = Array(code.textContent.utf8)
      guard case .some(let region) = MarkupRegion.at(text, caret: caretOffset, zones: ""), region.editable else {
        return nil
      }
      // Bytes to UTF-16 code units: a byte that starts a character is one,
      // two for one of four bytes.
      func units(_ upTo: Int) -> Int {
        var count = 0
        var index = 0
        while index < upTo {
          let byte = text[index]
          if byte & 0xC0 != 0x80 { count += byte >= 0xF0 ? 2 : 1 }
          index += 1
        }
        return count
      }
      let start = units(region.valueStart)
      let end = units(region.valueEnd)
      var before = 0
      let walker = document.createTreeWalker(code, DOM.NodeFilter.SHOW_TEXT)
      while let next = walker.nextNode() {
        guard let node = next as? DOM.Text else { continue }
        var length = 0
        for byte in node.data.utf8 where byte & 0xC0 != 0x80 { length += byte >= 0xF0 ? 2 : 1 }
        if start >= before && end <= before + length {
          return (
            node, start - before, end - start, region,
            String(decoding: text[region.valueStart..<region.valueEnd], as: UTF8.self)
          )
        }
        before += length
      }
      return nil
    }

    /// A value written over the bbox under the caret as one edit of the
    /// editor (its undo takes it back), the caret left at its end, still in
    /// the attribute.
    private func write(_ value: String, node: DOM.Text, start: Int, length: Int) {
      guard let code = caretEditor else { return }
      code.focus(DOM.FocusOptions(preventScroll: true))
      window.getSelection()?.setBaseAndExtent(node, start, node, start + length)
      document.execCommand("insertText", value: value)
    }

    /// A drag on the canvas, written into the bbox: as it goes, straight
    /// into the text; once it ends, the value it began as put back and the
    /// last one written over it as one edit.
    private func regionEdited(x: Int, y: Int, width: Int, height: Int, done: Bool) {
      let value = MarkupRegion(x: x, y: y, width: width, height: height).bbox
      if case .none = dragNode {
        guard let edited = editedValue() else { return }
        dragNode = edited.node
        dragStart = edited.start
        dragLength = edited.length
        dragOriginal = edited.value
      }
      guard let node = dragNode else { return }
      var length = 0
      for byte in value.utf8 where byte & 0xC0 != 0x80 { length += byte >= 0xF0 ? 2 : 1 }
      if !done {
        node.replaceData(dragStart, dragLength, value)
        dragLength = length
        return
      }
      var originalLength = 0
      for byte in dragOriginal.utf8 where byte & 0xC0 != 0x80 { originalLength += byte >= 0xF0 ? 2 : 1 }
      node.replaceData(dragStart, dragLength, dragOriginal)
      let start = dragStart
      dragNode = nil
      write(value, node: node, start: start, length: originalLength)
    }

    /// The arrows, with the caret in an editor's bbox value: 1 a press
    /// (with Shift, 10), moving the box, or with Alt resizing it; kept
    /// inside the image, at least 1 by 1.
    private func nudge(key: String, shift: Bool, alt: Bool) -> Bool {
      guard case .some = caretEditor, case .some(let shown) = caretRegion, shown.holds(caretOffset),
        stringStartsWith(key, "Arrow"), let edited = editedValue()
      else { return false }
      let step = shift ? 10 : 1
      let dx = stringEquals(key, "ArrowLeft") ? -step : stringEquals(key, "ArrowRight") ? step : 0
      let dy = stringEquals(key, "ArrowUp") ? -step : stringEquals(key, "ArrowDown") ? step : 0
      var box = edited.region
      if alt {
        box = MarkupRegion(
          x: box.x, y: box.y, width: max(1, min(1000 - box.x, box.width + dx)),
          height: max(1, min(1000 - box.y, box.height + dy)))
      } else {
        box = MarkupRegion(
          x: max(0, min(1000 - box.width, box.x + dx)), y: max(0, min(1000 - box.height, box.y + dy)),
          width: box.width, height: box.height)
      }
      write(box.bbox, node: edited.node, start: edited.start, length: edited.length)
      return true
    }

    /// Whether the manifest has confirmed an image, so the switch is
    /// offered: until then it stays hidden and the images off.
    private var canvasConfirmed = false
    /// The reads again of an unread manifest so far.
    private var manifestRetries = 0

    /// The page images, off until the manifest confirms one, then off
    /// unless this session turned them on (`confirmCanvasSwitch`).
    private func setupCanvasSwitch() {
      guard let toggle = root.querySelector(".artifact-canvas-toggle") else { return }
      canvasToggle = toggle
      canvasShown = false
      reflectCanvasShown()
      _ = toggle.addEventListener("toggle-button-update") { (event: Event) in
        ArtifactHydration.showCanvases(stringEquals(event.detail, "true"))
      }
    }

    /// The manifest named an image: the switch offered, as this session
    /// left it.
    private func confirmCanvasSwitch() {
      guard let _ = canvasToggle, !canvasConfirmed else { return }
      canvasConfirmed = true
      root.setAttribute(data("canvas-confirmed"), "true")
      canvasShown = stringEquals(sessionStorage.getItem(ArtifactHydration.canvasShownKey) ?? "false", "true")
      reflectCanvasShown()
    }

    /// The manifest answered with no image: the switch stays hidden for
    /// good, and the images show only where there is no markup to read
    /// instead—a reader with markup keeps them off, as its default has it,
    /// so a selection dragged past the pane's edge finds no image pane to
    /// run into.
    private func dropCanvasSwitch() {
      guard let _ = canvasToggle else { return }
      canvasToggle = nil
      canvasShown = markupPanes.isEmpty
      root.setAttribute(data("canvas-shown"), canvasShown ? "true" : "false")
    }

    /// The page images shown, the page on screen's canvas read; or put
    /// away, its tiles let go. A switch not yet offered follows nothing:
    /// it reads the session's choice when it is.
    func setCanvasShown(_ shown: Bool) {
      guard let _ = canvasToggle, canvasConfirmed, shown != canvasShown else { return }
      canvasShown = shown
      reflectCanvasShown()
      if shown {
        if canvasIndex < serviceIDs.count { showCanvas(canvasIndex) }
      } else {
        shownCanvas?.hide()
        shownCanvas = nil
      }
    }

    /// The viewer's column and the switch, as the state is: the switch's
    /// wrapper (which its styles read) and its button (which assistive
    /// technology reads).
    private func reflectCanvasShown() {
      root.setAttribute(data("canvas-shown"), canvasShown ? "true" : "false")
      canvasToggle?.setAttribute("aria-pressed", canvasShown ? "true" : "false")
      canvasToggle?.querySelector("button")?.setAttribute("aria-pressed", canvasShown ? "true" : "false")
    }

    private var rawVisible = false
    private var translationVisible = false
    /// Whether the markup has a translated layer to show at all.
    private var translatable = false

    /// The one layer of each page that shows, by two switches (user,
    /// 2026-10-07): the language switch picks the markup or its
    /// translation, Raw picks either's text or its code. A page with no
    /// translation shows nothing under either: emptiness, never a dash.
    private func showLayers() {
      let translated = translatable && translationVisible
      for pane in root.querySelectorAll(".artifact-markup .tei-page") {
        let layer = translated ? (rawVisible ? "translated-markup" : "translated-rendering") : (rawVisible ? "markup" : "rendering")
        for element in pane.querySelectorAll("[data-layer]") {
          let name = element.getAttribute(data("layer")) ?? ""
          if !stringEquals(name, layer) {
            element.style.display(.none)
          } else if stringEquals(name, "rendering") {
            element.style.display(.block)
          } else {
            element.style.display(.flex)
          }
        }
      }
    }

    /// A manifest that cannot be read pages as none is there: by the
    /// markup's own pages.
    ///
    /// Read or not, the viewer says so: an `artifact-manifest-load` event on
    /// it, its detail the number of canvases read ("0" for a manifest that
    /// could not be read), so a host can show the viewer or say why not.
    /// When the answer says why there are none, an `artifact-manifest-error`
    /// event, its detail the reason, comes first.
    ///
    /// A manifest not read this time (no answer; the server's `"unread"`: a
    /// timeout, too many reads) pages the markup meanwhile, its switch
    /// hidden, and is asked for again a few times, each wait longer
    /// (`ArtifactManifest.retryDelays`, user, 2026-10-10). An answer that
    /// names images then pages by them, on the page on screen, and offers
    /// the switch; one that names none keeps it hidden.
    private func loadManifest(url: String) {
      root.fetch(url) { [self] jsonStr in
        let manifest = ArtifactManifest.parse(jsonStr)
        let first = manifestRetries == 0
        switch manifest.canvasSwitch {
        case .pending:
          if first {
            if let reason = manifest.error {
              root.dispatchEvent(CustomEvent(type: "artifact-manifest-error", detail: reason))
            }
            root.dispatchEvent(CustomEvent(type: "artifact-manifest-load", detail: "0"))
            pageMarkup()
          }
          retryManifest(url: url)
          return
        case .none:
          dropCanvasSwitch()
        case .confirmed:
          confirmCanvasSwitch()
        }
        // Read again after the markup paged meanwhile: by the manifest now,
        // on the page on screen.
        if !first {
          if manifest.pages.isEmpty { return }
          if canvasIndex < serviceIDs.count { startService = serviceIDs[canvasIndex] }
          serviceIDs = []
          imageWidths = []
          imageHeights = []
          canvasLabels = []
        }
        for page in manifest.pages {
          serviceIDs.append(page.serviceID)
          imageWidths.append(page.width)
          imageHeights.append(page.height)
          canvasLabels.append(page.label)
        }
        if manifest.pages.isEmpty, let reason = manifest.error {
          root.dispatchEvent(CustomEvent(type: "artifact-manifest-error", detail: reason))
        }
        root.dispatchEvent(CustomEvent(type: "artifact-manifest-load", detail: "\(serviceIDs.count)"))
        if serviceIDs.isEmpty {
          pageMarkup()
        } else {
          open()
        }
      }
    }

    /// The manifest asked for again after the next wait, while the viewer is
    /// on the page; past the last, the switch stays hidden.
    private func retryManifest(url: String) {
      guard manifestRetries < ArtifactManifest.retryDelays.count else { return }
      let delay = ArtifactManifest.retryDelays[manifestRetries]
      manifestRetries += 1
      _ = window.setTimeout(delay) { [self] in
        guard self.isInDocument else { return }
        self.loadManifest(url: url)
      }
    }

    /// No manifest: the pages are the markup's own, in its order.
    private func pageMarkup() {
      for pane in markupPanes {
        serviceIDs.append(pane.dataset["service-id"] ?? "")
        imageWidths.append(0)
        imageHeights.append(0)
        canvasLabels.append("")
      }
      open()
    }

    /// The page asked for, else the one this reader was last on.
    private func open() {
      guard !serviceIDs.isEmpty else { return }
      let asked = canvasIndex(ofService: startService) ?? startCanvas ?? savedCanvasIndex()
      loadCanvas(max(0, min(asked, serviceIDs.count - 1)))
    }

    private func loadCanvas(_ idx: Int) {
      guard idx >= 0, idx < serviceIDs.count else { return }
      // Another page's code names other regions.
      caretRegion = nil
      hoverRegion = nil
      shownCanvas?.clearRegion()
      canvasIndex = idx
      saveCanvasIndex()
      updateUI()
      showCanvas(idx)
    }

    /// The canvas of the page on screen, read; the one before it put away;
    /// the ones either side fetched ahead. The rest fetch nothing until they
    /// are paged to.
    private func showCanvas(_ idx: Int) {
      guard canvasShown, object != nil, imageWidths[idx] > 0, imageHeights[idx] > 0 else { return }
      let service = serviceIDs[idx]
      let canvas = canvasReader(ofService: service)
      for element in object?.querySelectorAll("[data-service-id]") ?? [] {
        let active = stringEquals(element.dataset["service-id"] ?? "", service)
        element.setAttribute(data("active"), active ? "true" : "false")
      }
      if let shown = shownCanvas, shown !== canvas { shown.hide() }
      shownCanvas = canvas
      canvas.show(width: imageWidths[idx], height: imageHeights[idx])
      drawRegion()
      for neighbor in [idx + 1, idx - 1] where neighbor >= 0 && neighbor < serviceIDs.count {
        CanvasReader.preload(
          serviceID: serviceIDs[neighbor], width: imageWidths[neighbor], zoom: canvas.fittedZoom)
      }
    }

    /// The reader of a canvas, made the first time it is shown: over the
    /// slot's canvas for that image service, else one drawn for it.
    private func canvasReader(ofService service: String) -> CanvasReader {
      for canvas in canvases where stringEquals(canvas.serviceID, service) {
        return canvas
      }
      var element: DOM.Element?
      for candidate in object?.querySelectorAll(".canvas-view") ?? []
      where stringEquals(candidate.dataset["service-id"] ?? "", service) {
        element = candidate
        break
      }
      if element == nil {
        let drawn = CanvasReader.make(serviceID: service)
        object?.appendChild(drawn)
        element = drawn
      }
      let canvas = CanvasReader(root: element ?? CanvasReader.make(serviceID: service))
      let viewer = root
      canvas.onCrop = { detail in
        viewer.dispatchEvent(CustomEvent(type: "artifact-crop-change", detail: detail))
      }
      canvas.onRegionEdit = { [self] x, y, width, height, done in
        self.regionEdited(x: x, y: y, width: width, height: height, done: done)
      }
      canvas.setCropping(mayCrop(service))
      canvases.append(canvas)
      return canvas
    }

    private func mayCrop(_ service: String) -> Bool {
      for allowed in cropServices where stringEquals(allowed, service) { return true }
      return false
    }

    private func updateUI() {
      let page = canvasIndex + 1
      let total = serviceIDs.count
      if let input = pageInput as? HTML.HTMLInputElement {
        input.value = "\(page)"
      }
      pageInput?.setAttribute(.max, "\(total)")
      pageTotal?.textContent = "\(total)"
      root.setAttribute(data("pages-known"), total > 0 ? "true" : "false")
      var digits = 1
      var n = total
      while n >= 10 { n /= 10; digits += 1 }
      pageInput?.setAttribute("size", intToString(digits))
      canvasLabelEl?.textContent = label(of: canvasIndex)
      showMarkup(for: canvasIndex)
      // The property AND the class. The pager greys itself with
      // `pagination-disabled`, so setting only the property left a working
      // button that looked dead—which is worse than a dead one.
      setPageTurn(prevBtn, disabled: canvasIndex <= 0)
      setPageTurn(nextBtn, disabled: canvasIndex >= total - 1)
    }

    /// What the footer names a page: the manifest's label for its canvas,
    /// else its place in the sequence (1, 2, 3)—never the markup's own
    /// `pb n`, which the explication writes from the image and the
    /// manifest outranks (user, 2026-10-09).
    private func label(of index: Int) -> String {
      guard index < serviceIDs.count else { return "" }
      let given = index < canvasLabels.count ? stringTrim(canvasLabels[index]) : ""
      return stringIsEmpty(given) ? intToString(index + 1) : given
    }

    /// A page turn's enabled state, on the property and in the class.
    ///
    /// The pager greys itself with `pagination-disabled`, so setting only the
    /// property left a working button that looked dead—worse than a dead one,
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
        // Already on this page—still normalize display (e.g. leading zeros, overshoot clamp)
        (input as? HTML.HTMLInputElement)?.value = "\(page)"
        return
      }
      loadCanvas(idx)
    }

    private func setupControls() {
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
        self.shownCanvas?.refit()
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
        // An arrow typed in a field moves its caret, never the pages: a
        // form may hold a viewer among its fields.
        if let _ = e.target?.closest("input, textarea, select, [contenteditable='true']") { return }
        if stringEquals(e.key, "ArrowLeft") { navigate(-1) }
        if stringEquals(e.key, "ArrowRight") { navigate(1) }
      }
    }

    /// Where an image service sits among the pages, if it is there at all.
    private func canvasIndex(ofService service: String) -> Int? {
      guard !stringIsEmpty(service) else { return nil }
      for (index, id) in serviceIDs.enumerated() where stringEquals(id, service) {
        return index
      }
      return nil
    }

    /// The markup of the canvas on screen, and only that one.
    ///
    /// A pane names the image service it reads, not a page number, because the
    /// two orders are written by different hands: the manifest is the library's
    /// and the markup is the transcriber's. Matching on the service id means a
    /// markup that skips a canvas still lands on the right one; a pane that
    /// names nothing the manifest has simply never shows.
    private func showMarkup(for index: Int) {
      let service = index < serviceIDs.count ? serviceIDs[index] : ""
      // The page turned whether or not markup reads it: a host that
      // follows the pager (a roster of the canvases, a prompt preview)
      // hears of it either way.
      guard !markupPanes.isEmpty else {
        root.dispatchEvent(CustomEvent(type: "artifact-canvas-change", detail: service))
        return
      }
      var matched = false
      for pane in markupPanes {
        let id = pane.dataset["service-id"] ?? ""
        let isActive = !stringIsEmpty(service) && stringEquals(id, service)
        if isActive { matched = true }
        pane.setAttribute(data("active"), isActive ? "true" : "false")
      }
      // No pane names this canvas: fall back to the transcriber's order, which
      // is right whenever the two sequences run together.
      if !matched {
        for (position, pane) in markupPanes.enumerated() {
          pane.setAttribute(data("active"), position == index ? "true" : "false")
        }
      }
      // Whoever drew the markup may have work to do when it changes—syntax
      // coloring a page of markup, say, which is worth doing for the page on
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
