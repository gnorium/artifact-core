#if SERVER
  import CSSBuilder
  import DesignTokens
  import DOMBuilder
  import HTMLBuilder
  import WebComponents
  import WebTypes

  /// An object read page by page: a pager in its footer, a transcript of
  /// each page and, in its canvas slot, the object's images.
  ///
  /// The pages are the manifest's canvases when the viewer is given one
  /// (their order, labels and sizes), else the transcript's own pages. The
  /// canvas slot is an add-in: without it the viewer is a pager over the
  /// transcript; with it, each canvas (a ``CanvasView``, or a view wrapping
  /// one) is shown beside the transcript while its page is on screen, and
  /// only the canvas on screen reads its image. A canvas the manifest has and
  /// the slot lacks is drawn by the reader when it is paged to. Without a
  /// transcript the viewer is the object alone, every canvas drawn so.
  public struct ArtifactView: HTMLContent {
    /// Where the canvases to page are read; empty pages the transcript.
    /// The answer is JSON in the viewer's own shape, not a IIIF manifest:
    /// `{"label":…,"canvases":[{"id":…,"w":…,"h":…,"l":…}]}`, each canvas by
    /// its image service, its size and its label—the host's server reads
    /// the manifest and answers so. `{"canvases":[],"error":"…"}` says why
    /// there are none.
    let manifestURL: String
    /// The work's title, in the header, its authors after it ("by A and B",
    /// subtle). Nil or empty: the manifest's label, once it is read.
    let title: String?
    let authors: [String]
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
    /// A transcript of the object, shown beside it: a transcription, a
    /// translation, an apparatus. Any descendant carrying `data-service-id` is
    /// shown only while the canvas with that image service is the one on
    /// screen, so the transcript pages with the object.
    let transcript: [DOM.Node]
    /// Whether the footer carries a switch from the transcript to the code it
    /// was made from—markup, in the usual case. The transcript marks its two
    /// layers with `data-transcript-layer`, `"rendered"` and `"code"`, and the
    /// switch swaps them in place.
    let codeSwitch: Bool
    /// What the switch is for, behind an ⓘ beside it, where the page needs to
    /// say—an editor that takes its edits in the code says so here.
    let codeSwitchInfo: String?
    /// The object's images, one per canvas, each naming its image service in
    /// `data-service-id`: shown, like the transcript, only while its canvas
    /// is on screen, and read only then.
    let canvas: [DOM.Node]
    /// Whether the header carries a switch that shows the canvas slot, the
    /// page images, beside the transcript (user, 2026-09-29). Off by default:
    /// the transcript takes the whole width and no page image is fetched.
    /// The choice holds for the browser session (`sessionStorage`), across
    /// pages of the reader and the site's pages alike, and every reader on
    /// the page follows it. Without the switch the canvas always shows.
    let canvasSwitch: Bool
    /// Controls the host adds to the header, after the title (a Find
    /// button).
    let actions: [DOM.Node]
    /// A row the host adds under the header's own, the width of the viewer
    /// (a find bar), shown while the host marks the row open
    /// (`data-open="true"` on `.artifact-header-bar`). Closed, it takes no
    /// room: an empty row still took the header's gap under the controls.
    let bar: [DOM.Node]

    public init(
      manifestURL: String = "",
      title: String? = nil,
      authors: [String] = [],
      style: CSSStyle = .default,
      startCanvas: Int? = nil,
      startService: String? = nil,
      codeSwitch: Bool = false,
      codeSwitchInfo: String? = nil,
      canvasSwitch: Bool = false,
      @HTMLBuilder transcript: () -> [DOM.Node] = { [] },
      @HTMLBuilder canvas: () -> [DOM.Node] = { [] },
      @HTMLBuilder actions: () -> [DOM.Node] = { [] },
      @HTMLBuilder bar: () -> [DOM.Node] = { [] }
    ) {
      self.manifestURL = manifestURL
      self.title = title
      self.authors = authors
      self.style = style
      self.startCanvas = startCanvas
      self.startService = startService
      self.codeSwitch = codeSwitch
      self.codeSwitchInfo = codeSwitchInfo
      self.canvasSwitch = canvasSwitch
      self.transcript = transcript()
      self.canvas = canvas()
      self.actions = actions()
      self.bar = bar()
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

    /// Whether the header shows the page-images switch: only when there are
    /// page images to show.
    private var switchesCanvas: Bool { canvasSwitch && !canvas.isEmpty }

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
          // The switch between the transcript and the code it was made from.
          // First in the row, so it sits at the top left beside the transcript it
          // changes: the title block grows to fill and would push it right.
          if codeSwitch, !transcript.isEmpty {
            ToggleButtonView(
              label: "Raw",
              icon: nil as HTML.HTMLSpanElement?,
              modelValue: false,
              weight: .static,
              buttonColor: .gray,
              fullWidth: false,
              ariaLabel: "Code of this transcript",
              indicateSelection: true,
              size: .small,
              class: "artifact-code-toggle",
              labelFontWeight: fontWeightNormal
            )
            if let info = codeSwitchInfo {
              // 14, as the header's other small icons (user, 2026-10-08).
              TooltipView(tooltip: info, class: "artifact-code-info") {
                IconView(
                  icon: { size in [InfoIconView(size: size)] }, size: ButtonView.ButtonSize.small.iconSize)
              }
            }
          }
          // Faded where it runs past the row, and shown whole in a sheet
          // over the viewer from its fade, at every width (user,
          // 2026-10-08): wrapped in place, a phone's row made it a column a
          // word wide that covered the reader.
          span {
            span { title ?? "" }
              .id("artifact-title")
              .class("artifact-title-primary")
            if !headerSubtitle.isEmpty {
              span { " \(headerSubtitle)" }
                .class("artifact-title-subtitle")
            }
          }
          .class("artifact-title-block")
          .data("edge-fade", "sheet")

          if !actions.isEmpty || switchesCanvas {
            div {
              actions
              // An image switch is distinct from the adjacent page-navigation arrows.
              if switchesCanvas {
                ToggleButtonView(
                  label: "Semblance",
                  icon: IconView(
                    icon: { s in ImageIconView(size: s) }, size: ButtonView.ButtonSize.small.iconSize),
                  modelValue: false,
                  weight: .plain,
                  buttonColor: .gray,
                  iconOnly: true,
                  ariaLabel: "Semblance",
                  size: .small,
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
          // The transcript first, the object beside it.
          //
          // The transcript is what the page is for: it arrives with the document,
          // it carries the figures cut from the facsimile inline, and it is
          // what a reader reads. The object corroborates it—you look across
          // when you doubt a word. Putting the image first made the thing being
          // checked come before the thing being read, and on a narrow screen it
          // pushed the transcript below the fold entirely.
          // The transcript of the object, beside the object. It is a sibling of
          // the object rather than a block under the viewer so that the two
          // page together and fullscreen carries both.
          if !transcript.isEmpty {
            div {
              transcript
            }
            .id("artifact-transcript")
            .class("artifact-transcript")
            // A gloss opened in it covers it alone.
            .data("sheet-host", true)
          }

          // The object: the canvas of the page on screen. A viewer with no
          // transcript is the object alone, its slot drawn empty for the
          // reader to fill with the manifest's canvases—a testament not yet
          // read, say, whose pages exist only as images.
          if !canvas.isEmpty || transcript.isEmpty {
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
          span {}
            .id("artifact-canvas-label")
            .class("artifact-canvas-label")
            .data("edge-fade", "expand")

          div().id("artifact-zoom-controls")
            .class("artifact-zoom-controls")

          // The page nav, beside fullscreen at the footer's end (user,
          // 2026-10-08): in the header it pushed the row past a phone's
          // width, and the page turns sit with the page's own label here.
          PaginationView(
            currentPage: 1,
            totalPages: 1,
            size: .small,
            showControls: true,
            kind: "artifact",
            inputID: "artifact-page-input",
            totalID: "artifact-page-total",
            totalDisplay: "—",
            ariaLabel: "Pages",
            inputAriaLabel: "Page number",
            class: "artifact-page-nav"
          )

          button {
            IconView(
              icon: { size in [FullscreenIconView(size: size)] }, size: ButtonView.ButtonSize.small.iconSize)
          }
          .id("artifact-fullscreen-btn")
          .class("artifact-fullscreen-button")
        }
        .class("artifact-footer")

        // The header's title shown whole, over the viewer: the viewer is
        // the sheet's host.
        EdgeFadeSheetView()
      }
      .class("artifact-view")
      .data("sheet-host", true)
      .data("manifest-url", manifestURL)
      .data("start-canvas", startCanvas.map { "\($0)" } ?? "")
      .data("start-service", startService ?? "")
      .data("style", style.rawValue)
      // Hidden until the reader knows the session's choice, so that a reader
      // left off never shows an empty column first.
      .data("canvas-shown", !switchesCanvas)
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
          // The bar is 40 and its controls small, 32 (user, 2026-10-08):
          // the 4 above and under them is the row's own, so its scrollport
          // takes in a control's focus ring, which it would otherwise cut
          // off.
          padding(0, spacing8)
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
          padding(spacing4, spacing8)
          overflowX(.auto)
          overflowY(.hidden)
          scrollbarWidth(.none)
          pseudoElement(.webkitScrollbar) { display(.none).important() }
        }
        // The row's text at its controls' size: 16, as the pager's number.
        selector(".artifact-title-block") {
          fontFamily(typographyFontSans)
          fontSize(fontSizeMedium16)
          lineHeight(lineHeightSmall22)
          flex(1)
          minWidth(0)
        }
        fadeOverflow(".artifact-title-block")
        descendant(".artifact-title-primary") {
          fontWeight(fontWeightSemiBold)
          color(colorBase)
        }
        descendant(".artifact-title-subtitle") { color(colorSubtle) }
        descendant(".artifact-header-actions") {
          display(.flex)
          alignItems(.center)
          gap(spacing8)
          flexShrink(0)
        }
        // The row above it again: small controls, 4 above and under them,
        // 12 under the row (its 4 and the panel's 8). The inset is the
        // panel's, never the shell's: a shell's height counts its padding,
        // so animated to 0 it stopped at 20 and stalled there, then grew.
        descendant(".artifact-header-bar") {
          minWidth(0)
        }
        descendant(".artifact-header-bar-panel") {
          minWidth(0)
          padding(spacing8, spacing8, spacing4)
        }
        descendant(".artifact-header-bar[data-open='false']") {
          display(.none)
        }
        descendant(".artifact-page-nav") {
          flexShrink(0)
        }
        // Beside the switch it explains, no nearer than the switch sits to
        // the title: the header's own gap.
        descendant(".artifact-code-info") {
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
          // screen the object takes the top half and its transcript the bottom,
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
        descendant(".artifact-transcript") {
          // Half the surface, whichever way the two are laid out. Without the
          // zero minimums a flex item never shrinks past its content, and a
          // page of verse would take two thirds of the viewer.
          flex(1, 1, perc(50))
          minWidth(0)
          minHeight(0)
          overflow(.auto)
          padding(spacing16)
          // The divider sits on the transcript's far edge, because the transcript
          // comes first: to its right when the two are side by side, under it
          // when they stack. It used to be a leading border, from when the
          // object led and the transcript sat to its right.
          borderInlineEnd(borderWidthBase, .solid, borderColorBase)
          backgroundColor(backgroundColorBase)
          media(maxWidth(maxWidthBreakpointMobile)) {
            borderInlineEnd(.none).important()
            borderBlockEnd(borderWidthBase, .solid, borderColorBase).important()
          }
        }
        // The page images switched off: the transcript alone, the whole
        // width, with no divider beside or under it.
        selector("&[data-canvas-shown='false'] .artifact-object") {
          display(.none)
        }
        selector("&[data-canvas-shown='false'] .artifact-transcript") {
          borderInlineEnd(.none).important()
          borderBlockEnd(.none).important()
        }
        // The switch is in the header and the layers are in the pane, so the
        // rule that ties them lives on the viewer, where both are in scope.
        selector("&:has(.artifact-code-toggle[aria-pressed='true']) .artifact-transcript [data-transcript-layer='rendered']") {
          display(.none)
        }
        // Flex, not block: a layer holding one element also holds the
        // whitespace around it in the markup, and a block container turns that
        // into a line box above and below—a gap that looks like padding
        // nobody asked for. A flex container drops whitespace-only children.
        selector("&:has(.artifact-code-toggle[aria-pressed='true']) .artifact-transcript [data-transcript-layer='code']") {
          display(.flex)
          flexDirection(.column)
          width(perc(100))
          minWidth(0)
          maxWidth(perc(100))
          // The transcript pane owns both scrollbars. Giving this layer an
          // overflow value creates a second vertical scroller in Raw mode.
          overflow(.visible)
        }
        // Raw XML is intentionally preformatted and can contain very long
        // lines. Let it contribute overflow to `.artifact-transcript`, which is
        // the single scroll owner for the entire transcript half.
        descendant(".artifact-transcript [data-transcript-layer='code'] .code-view") {
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
        // Only the transcript and the canvas of the page on screen. The rest
        // stay in the document so that paging is a class change, not a fetch.
        selector(
          ".artifact-transcript [data-service-id][data-active='false']",
          ".artifact-object [data-service-id][data-active='false']"
        ) {
          display(.none)
        }
        // 40, as the header: small controls, 4 above and under them. The
        // pager and fullscreen at the row's end, the start in RTL.
        // Never squeezed by the viewer's column: a header grown tall (a
        // long title opened) takes the transcript's room, never the pager's.
        descendant(".artifact-footer") {
          flexShrink(0)
          justifyContent(.flexEnd)
          gap(spacing8)
          padding(spacing4, spacing16)
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
        descendant(".artifact-zoom-controls") {
          display(.flex)
          alignItems(.center)
          gap(spacing4)
        }
        selector(".artifact-fullscreen-button") {
          display(.flex)
          alignItems(.center)
          justifyContent(.center)
          width(ButtonView.ButtonSize.small.minSize)
          height(ButtonView.ButtonSize.small.minSize)
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
  /// It keeps the pages: which is on screen, the pager, the transcript and
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
    private var transcriptPanes: [DOM.Element] = []
    /// The canvas slot, when the viewer has one, and the canvases read so far.
    private var object: DOM.Element?
    private var canvases: [CanvasReader] = []
    private var shownCanvas: CanvasReader?
    /// The page-images switch, when the viewer has one, and whether the
    /// canvas shows: always without the switch.
    private var canvasToggle: DOM.Element?
    private var canvasShown = true

    private func storageKey() -> String { "gnorium:artifact-canvas:\(manifestURL)" }
    /// Where the reader was last on this manifest; a transcript paged without
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
      transcriptPanes = root.querySelectorAll(".artifact-transcript [data-service-id]")
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
      // A host turns the reader to a page by its image service (a find
      // bar's match): an `artifact-show-service` event on the viewer.
      _ = root.addEventListener("artifact-show-service") { [self] (event: Event) in
        if let index = self.canvasIndex(ofService: event.detail) { self.loadCanvas(index) }
      }
      // Or by its place in the sequence (0-based), as a roster of the
      // semblances names it: `artifact-show-canvas`.
      _ = root.addEventListener("artifact-show-canvas") { [self] (event: Event) in
        if let index = Int(event.detail) { self.loadCanvas(index) }
      }
      if stringIsEmpty(manifestURL) {
        pageTranscript()
      } else {
        loadManifest(url: manifestURL)
      }
    }

    /// The code switch changes the transcript, not the image viewport.  Keep
    /// that state in the hydrated view instead of relying on `:has()`: that
    /// selector is not consistently reevaluated when `aria-pressed` changes
    /// in every browser context that hosts the reader.
    ///
    /// A transcript with a translation follows its page's language switch too,
    /// which is not the viewer's: the page sets `data-transcript-translated` on
    /// an ancestor and tells each viewer with a `transcript-translated` event.
    /// A viewer fetched in after the switch was pressed reads the attribute
    /// as it stands.
    private func setupLayers() {
      let code = root.querySelector(".artifact-code-toggle")
      if case .some = root.querySelector(".artifact-transcript [data-transcript-layer='translation']") {
        translatable = true
      }
      codeVisible = stringEquals(code?.getAttribute("aria-pressed") ?? "false", "true")
      translationVisible = stringEquals(
        root.closest("[data-transcript-translated]")?.getAttribute(data("transcript-translated")) ?? "false", "true")
      showLayers()
      _ = code?.addEventListener("toggle-button-update") { [self] (event: Event) in
        self.codeVisible = stringEquals(event.detail, "true")
        self.showLayers()
      }
      _ = root.addEventListener("transcript-translated") { [self] (event: Event) in
        self.translationVisible = stringEquals(event.detail, "true")
        self.showLayers()
      }
    }

    /// The page images, off unless this session turned them on.
    private func setupCanvasSwitch() {
      guard let toggle = root.querySelector(".artifact-canvas-toggle") else { return }
      canvasToggle = toggle
      canvasShown = stringEquals(sessionStorage.getItem(ArtifactHydration.canvasShownKey) ?? "false", "true")
      reflectCanvasShown()
      _ = toggle.addEventListener("toggle-button-update") { (event: Event) in
        ArtifactHydration.showCanvases(stringEquals(event.detail, "true"))
      }
    }

    /// The page images shown, the page on screen's canvas read; or put
    /// away, its tiles let go.
    func setCanvasShown(_ shown: Bool) {
      guard let _ = canvasToggle, shown != canvasShown else { return }
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

    private var codeVisible = false
    private var translationVisible = false
    /// Whether the transcript has a translated layer to show at all.
    private var translatable = false

    /// The one layer of each page that shows, by two switches (user,
    /// 2026-10-07): the language switch picks the transcript or its
    /// translation, Raw picks either's text or its code. A page with no
    /// translation shows nothing under either: emptiness, never a dash.
    private func showLayers() {
      let translated = translatable && translationVisible
      for pane in root.querySelectorAll(".artifact-transcript .tei-transcript") {
        let layer = translated ? (codeVisible ? "translation-code" : "translation") : (codeVisible ? "code" : "rendered")
        for element in pane.querySelectorAll("[data-transcript-layer]") {
          let name = element.getAttribute(data("transcript-layer")) ?? ""
          if !stringEquals(name, layer) {
            element.style.display(.none)
          } else if stringEquals(name, "rendered") {
            element.style.display(.block)
          } else {
            element.style.display(.flex)
          }
        }
      }
    }

    /// A manifest that cannot be read pages as none is there: by the
    /// transcript's own pages.
    ///
    /// Read or not, the viewer says so: an `artifact-manifest-load` event on
    /// it, its detail the number of canvases read ("0" for a manifest that
    /// could not be read), so a host can show the viewer or say why not.
    /// When the answer says why there are none, an `artifact-manifest-error`
    /// event, its detail the reason, comes first.
    private func loadManifest(url: String) {
      root.fetch(url) { [self] jsonStr in
        guard let jsonStr else {
          root.dispatchEvent(CustomEvent(type: "artifact-manifest-load", detail: "0"))
          pageTranscript()
          return
        }
        parseManifest(jsonStr)
        if serviceIDs.isEmpty, let reason = extractJSONString(jsonStr, key: "error") {
          root.dispatchEvent(CustomEvent(type: "artifact-manifest-error", detail: reason))
        }
        root.dispatchEvent(CustomEvent(type: "artifact-manifest-load", detail: "\(serviceIDs.count)"))
        if serviceIDs.isEmpty {
          pageTranscript()
        } else {
          open()
        }
      }
    }

    /// No manifest: the pages are the transcript's own, in its order.
    private func pageTranscript() {
      for pane in transcriptPanes {
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

    private func parseManifest(_ json: String) {
      // The viewer's shape: {"label":"...","canvases":[{"id":"...","w":N,"h":N,"l":"..."},...]}
      // The title is the work's, from its record's fields, drawn by the
      // server; the manifest's free-text label never stands in for it.
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
      canvases.append(canvas)
      return canvas
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
      canvasLabelEl?.textContent = label(of: canvasIndex)
      showTranscript(for: canvasIndex)
      // The property AND the class. The pager greys itself with
      // `pagination-disabled`, so setting only the property left a working
      // button that looked dead—which is worse than a dead one.
      setPageTurn(prevBtn, disabled: canvasIndex <= 0)
      setPageTurn(nextBtn, disabled: canvasIndex >= total - 1)
    }

    /// What the footer names a page: the transcript's own label for it
    /// (its `pb`'s `n`, `data-label`), else the manifest's canvas label.
    private func label(of index: Int) -> String {
      guard index < serviceIDs.count else { return "" }
      let service = serviceIDs[index]
      for pane in transcriptPanes where stringEquals(pane.dataset["service-id"] ?? "", service) {
        let own = pane.dataset["label"] ?? ""
        if !stringIsEmpty(stringTrim(own)) { return own }
      }
      return index < canvasLabels.count ? canvasLabels[index] : ""
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

    /// The transcript of the canvas on screen, and only that one.
    ///
    /// A pane names the image service it reads, not a page number, because the
    /// two orders are written by different hands: the manifest is the library's
    /// and the transcript is the transcriber's. Matching on the service id means a
    /// transcript that skips a canvas still lands on the right one; a pane that
    /// names nothing the manifest has simply never shows.
    private func showTranscript(for index: Int) {
      let service = index < serviceIDs.count ? serviceIDs[index] : ""
      // The page turned whether or not a transcript reads it: a host that
      // follows the pager (a roster of the semblances, a prompt preview)
      // hears of it either way.
      guard !transcriptPanes.isEmpty else {
        root.dispatchEvent(CustomEvent(type: "artifact-canvas-change", detail: service))
        return
      }
      var matched = false
      for pane in transcriptPanes {
        let id = pane.dataset["service-id"] ?? ""
        let isActive = !stringIsEmpty(service) && stringEquals(id, service)
        if isActive { matched = true }
        pane.setAttribute(data("active"), isActive ? "true" : "false")
      }
      // No pane names this canvas: fall back to the transcriber's order, which
      // is right whenever the two sequences run together.
      if !matched {
        for (position, pane) in transcriptPanes.enumerated() {
          pane.setAttribute(data("active"), position == index ? "true" : "false")
        }
      }
      // Whoever drew the transcript may have work to do when it changes—syntax
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
