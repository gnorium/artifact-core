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
    /// Whether the markup holds only some of its pages—the one on screen
    /// and those either side—and the host fetches the rest as they are
    /// turned to (a long book: user, 2026-10-11). Each pane then names its
    /// place among the pages (`data-page-index`), and `pageCount` counts
    /// them all. When the reader turns to a page none of whose panes is
    /// drawn, it says so in `artifact-canvas-change` with no pane active;
    /// the host adds the pane and tells it with `artifact-markup-added`.
    let windowed: Bool

    public init(
      manifestURL: String = "",
      style: CSSStyle = .default,
      startCanvas: Int? = nil,
      startService: String? = nil,
      rawSwitch: Bool = false,
      rawSwitchInfo: String? = nil,
      canvasSwitch: Bool = false,
      pageCount: Int? = nil,
      windowed: Bool = false,
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
      self.windowed = windowed
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
            .data("edge-fade-view", "expand")
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
              div { markup }
                .id("artifact-markup")
                .class("artifact-markup")
                .data("sheet-host", true)
            }
            .class("artifact-markup-frame")
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
              // Icons, subtle and bordered as the reactions button is (user,
              // 2026-10-12): the code (`</>`), its lines' flow, and the panes
              // unlinked.
              XMLToggleButtonView(class: "artifact-xml-toggle")
              // Both layers' lines (user, 2026-10-12). Off: the rendered
              // page's lines as the scan breaks them (each `<lb/>` a line)
              // and the code's as stored, never wrapped, scrolling
              // sideways. On: the page's lines run on as paragraphs, the
              // code wrapped as plain text.
              ToggleButtonView(
                label: "Reflow",
                icon: IconView(icon: { s in TextWrapIconView(size: s) }, size: sizeIconSmall),
                modelValue: false,
                weight: .subtle,
                buttonColor: .gray,
                iconOnly: true,
                ariaLabel: "Reflow",
                size: .medium,
                class: "artifact-reflow-toggle"
              )
              // The image and the rendered text kept on the same part of the
              // page (user, 2026-10-12); pressed, each scrolls alone, for a
              // page whose text is not yet the scan's. Disabled, never
              // hidden, where it cannot apply (Raw, Reflow, the images put
              // away), its state kept underneath.
              if switchesCanvas {
                ToggleButtonView(
                  label: "Detach",
                  icon: IconView(icon: { s in RefreshClockwiseOffIconView(size: s) }, size: sizeIconSmall),
                  modelValue: false,
                  weight: .subtle,
                  buttonColor: .gray,
                  iconOnly: true,
                  ariaLabel: "Detach",
                  size: .medium,
                  class: "artifact-detach-toggle"
                )
                ToggleButtonView(
                  label: "Overlay",
                  icon: IconView(icon: { s in LayersIconView(size: s) }, size: sizeIconSmall),
                  modelValue: false, weight: .subtle, buttonColor: .gray,
                  iconOnly: true, ariaLabel: "Overlay", size: .medium,
                  class: "artifact-overlay-toggle"
                )
              }
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

          // Maximize to go full screen; in full screen the same button
          // leaves it, and shows minimize.
          button {
            IconView(
              icon: { size in [MaximizeIconView(size: size)] }, size: sizeIconSmall,
              class: "artifact-fullscreen-enter")
            IconView(
              icon: { size in [MinimizeIconView(size: size)] }, size: sizeIconSmall,
              class: "artifact-fullscreen-exit")
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
      .data("windowed", windowed)
      .data("page-count", pageCount ?? 0)
      .style {
        selector("&") {
          display(.flex)
          flexDirection(.column)
          width(perc(100))
          height(perc(100))
          borderRadius(borderRadiusBase)
          overflow(.hidden)
          border(borderWidthBase, .solid, borderColorSubtle)
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
          borderBlockEnd(borderWidthBase, .solid, borderColorSubtle)
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
        selector("& .artifact-page-nav", "& .artifact-xml-toggle", "& .artifact-reflow-toggle", "& .artifact-detach-toggle", "& .artifact-overlay-toggle") {
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
        descendant(".artifact-markup-frame") {
          flex(1, 1, perc(50))
          position(.relative)
          minWidth(0)
          minHeight(0)
          overflow(.hidden)
        }
        descendant(".artifact-markup-frame > .artifact-markup") {
          width(perc(100))
          height(perc(100))
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
          borderInlineEnd(borderWidthBase, .solid, borderColorSubtle)
          backgroundColor(backgroundColorBase)
          media(maxWidth(maxWidthBreakpointMobile)) {
            borderInlineEnd(.none).important()
            borderBlockEnd(borderWidthBase, .solid, borderColorSubtle).important()
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
        selector("&:has(.artifact-xml-toggle[aria-pressed='true']) .artifact-markup [data-layer='rendering']") {
          display(.none)
        }
        // Flex, not block: a layer holding one element also holds the
        // whitespace around it in the markup, and a block container turns that
        // into a line box above and below—a gap that looks like padding
        // nobody asked for. A flex container drops whitespace-only children.
        selector("&:has(.artifact-xml-toggle[aria-pressed='true']) .artifact-markup [data-layer='markup']") {
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
        // The rendered page's lines, Reflow off, overflow into the pane too
        // (user, 2026-10-12): `.artifact-markup` the one scroller for both
        // axes, as under Raw, so its sideways bar stays at the pane's edge
        // at every scroll, never at the foot of a tall page. (TEIView
        // scrolls its own lines where no pane holds it.)
        descendant(".artifact-markup .tei-page-text") {
          overflow(.visible).important()
        }
        // Reflow off, a page's layer is as wide as its longest line: the
        // shape its zoom fits (`ArtifactReader.applyZoom`).
        // Two fingers on the pane pinch the text, never the page.
        selector("&:not([data-reflow='true']) .artifact-markup [data-layer]") {
          width(.maxContent).important()
          maxWidth(.none).important()
        }
        descendant(".artifact-markup[data-over-text='true']") { cursor(.text) }
        descendant(".artifact-markup[data-dragging='true']") { cursor(.grabbing) }
        selector("& .artifact-markup") {
          CSS.Property("touch-action", "pan-x pan-y")
          // Its scroll is the reader's or the sync's alone: the browser's
          // anchoring would move it again after each zoom.
          CSS.Property("overflow-anchor", "none")
          // A swipe at its edge stays in it, as the image's does.
          CSS.Property("overscroll-behavior", "contain")
          // Panned by a drag off its text, as the image is: the text keeps
          // its I-beam, the rest of the pane the hand.
          cursor(.grab)
        }
        // The same two positioned frames interpolate into an overlay,
        // rather than switching layout models halfway through the reveal.
        selector("&[data-canvas-shown='true']:has(.artifact-markup-frame) .artifact-markup-frame", "&[data-canvas-shown='true']:has(.artifact-markup-frame) .artifact-object") {
          position(.absolute)
          CSS.Property("inset-block-start", "0")
          CSS.Property("inset-inline-start", "0")
          width(perc(50))
          height(perc(100))
          CSS.Property("transition", "width 400ms ease-in-out, height 400ms ease-in-out, inset-inline-start 400ms ease-in-out, inset-block-start 400ms ease-in-out")
          media(maxWidth(maxWidthBreakpointMobile)) {
            width(perc(100))
            height(perc(50))
          }
          CSS.Property("will-change", "width, height, inset-inline-start, inset-block-start")
          media("(prefers-reduced-motion: reduce)") { CSS.Property("transition", "none") }
        }
        selector("&[data-canvas-shown='true']:has(.artifact-markup-frame) .artifact-object") {
          CSS.Property("inset-inline-start", "50%")
          media(maxWidth(maxWidthBreakpointMobile)) {
            CSS.Property("inset-inline-start", "0")
            CSS.Property("inset-block-start", "50%")
          }
        }
        selector("&[data-overlay-active='true'] .artifact-object", "&[data-overlay-active='true'] .artifact-markup-frame") {
          CSS.Property("inset-inline-start", "0").important()
          CSS.Property("inset-block-start", "0").important()
          width(perc(100)).important()
          height(perc(100)).important()
        }
        selector("&[data-overlay-active='true'] .artifact-viewer-container") {
          display(.block)
        }
        selector("&[data-overlay-active='true'] .artifact-object", "&[data-overlay-active='true'] .artifact-markup-frame") {
          position(.absolute)
          width(perc(100)).important()
          height(perc(100)).important()
        }
        selector("&[data-overlay-active='true'] .artifact-markup-frame") {
          zIndex(1)
          CSS.Property("pointer-events", "none")
        }
        selector("&[data-overlay-active='true'] .artifact-markup") {
          backgroundColor(.transparent).important()
          overflow(.hidden).important()
        }
        selector("&[data-overlay-active='true'] .canvas-viewport") { CSS.Property("touch-action", "none") }
        selector("& .artifact-detach-toggle[aria-pressed='true'] .button-view:disabled") {
          backgroundColor(backgroundColorBlue).important()
          borderColor(backgroundColorBlue).important()
          CSS.Property("opacity", "0.5")
        }
        selector("& .artifact-detach-toggle[aria-pressed='true'] .button-view:disabled .button-icon", "& .artifact-detach-toggle[aria-pressed='true'] .button-view:disabled .button-label") {
          color(colorOnSolid).important()
        }
        selector("&[data-overlay-active='true'] .artifact-object") {
          CSS.Property("opacity", "0.5")
        }
        // The code in the pane on the page's ground, gutter and all, as an
        // editor's (Xcode's) is (user, 2026-10-12); a code block in prose
        // keeps the code's gray, to stand apart from it.
        selector("& .artifact-markup .code-view", "& .artifact-markup .code-view .code-gutter") {
          backgroundColor(backgroundColorBase).important()
        }
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
          borderBlockStart(borderWidthBase, .solid, borderColorSubtle)
        }
        // Its text where the rendered text starts below when left-aligned
        // (user, 2026-10-12): the text's 16 inset in its layer, inside the
        // TEI view's 1px ring padding and the pane's 1px, less the row's 8.
        descendant(".artifact-canvas-label") {
          fontSize(fontSizeMedium16)
          color(colorSubtle)
          flex(1)
          minWidth(0)
          CSS.Property(
            "padding-inline-start",
            "calc(\(spacing16.value) - \(spacing8.value) + 2 * \(borderWidthBase.value))")
        }
        edgeFadeView("& .artifact-canvas-label")
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
        selector("& .artifact-fullscreen-exit", "&:fullscreen .artifact-fullscreen-enter") {
          display(.none)
        }
        selector("&:fullscreen .artifact-fullscreen-exit") {
          display(.flex)
        }
        // On a phone (below 480px) the viewer is never narrower than its
        // footer's one row at its own size (user, 2026-10-12)—Raw, Reflow,
        // the pager and fullscreen, their gaps, the footer's inset and the
        // viewer's border—whatever the pager's total holds: the footer is
        // as wide as its contents (`max-content`) and the viewer as wide as
        // that (`min-content`), measured from the footer alone. A page that
        // nests the viewer deeper scrolls
        // sideways, as the outliner's does; nothing in it is resized.
        media(maxWidth(maxWidthBreakpointPhoneNarrow)) {
          selector("&") { CSS.Property("min-width", "min-content").important() }
          selector("& .artifact-footer") { CSS.Property("min-width", "max-content").important() }
          // Only the footer sets it: the rest (the header row, the pane and
          // its unwrapped lines) is as wide as the viewer, whatever it holds.
          selector("& > :not(.artifact-footer)") { CSS.Property("contain", "inline-size") }
          // Option B (`ButtonView.phoneStep`): fullscreen small with every
          // medium button, its icon the small type's size as theirs is.
          selector("\(ButtonView.phoneStep) & .artifact-fullscreen-button") {
            width(ButtonView.smallMinSize).important()
            height(ButtonView.smallMinSize).important()
            customProperty("--size-icon-small", fontSizeSmall14.value).important()
          }
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
    /// Reflow's choice, kept for the session as the page images' is.
    static let reflowKey = "gnorium:artifact-reflow"
    /// Detach's choice, kept for the session; synced until detached.
    static let detachKey = "gnorium:artifact-detach"

    /// Every reader's panes detached or synced, as one reader's Detach was
    /// pressed, and the choice kept for the session.
    static func detach(_ on: Bool) {
      sessionStorage.setItem(detachKey, on ? "true" : "false")
      for reader in instance?.readers ?? [] { reader.setDetached(on) }
    }

    /// Every reader's markup reflowed or set by its lines, as one reader's
    /// Reflow was pressed, and the choice kept for the session.
    static func reflow(_ on: Bool) {
      sessionStorage.setItem(reflowKey, on ? "true" : "false")
      for reader in instance?.readers ?? [] { reader.setReflow(on) }
    }

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
    /// Each canvas's plain image in place of its service, where it has one
    /// (`ArtifactManifest.Page.image`): by the manifest's place.
    private var plainImages: [String] = []
    private var imageHeights: [Int] = []
    private var canvasLabels: [String] = []
    private var canvasIndex: Int = 0

    private var manifestURL: String = ""
    /// Whether the markup holds only some of its pages (`ArtifactView.windowed`).
    private var windowed = false
    /// The canvas the page asked for, which outranks the one this reader was
    /// last on: a link to a page of the object means that page.
    private var startCanvas: Int?
    private var startService: String = ""
    /// The markup's panes drawn now: a windowed reader's change as it is
    /// paged, so they are read afresh each time.
    private var markupPanes: [DOM.Element] { root.querySelectorAll(".artifact-markup [data-service-id]") }
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
      windowed = stringEquals(root.dataset["windowed"] ?? "false", "true")
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
      setupReflowSwitch()
      setupSyncSwitch()
      setupZoom()
      setupCanvasSwitch()
      setupOverlay()
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
      // Or by a markup page, "<index> <service>", as an evidence roster
      // names it: by its image where the pages hold it, else by its place
      // among the markup's pages, which a windowed reader may not have
      // drawn yet.
      _ = root.addEventListener("artifact-show-markup") { [self] (event: Event) in
        let parts = stringSplit(event.detail, separator: " ")
        let service = parts.count > 1 ? parts[1] : ""
        if let index = self.canvasIndex(ofService: service) {
          self.loadCanvas(index)
        } else if let first = parts.first, let index = Int(first) {
          self.loadCanvas(index)
        }
      }
      // A windowed reader's host has drawn a pane: show it if it is the
      // page on screen, its layers as the switches stand.
      _ = root.addEventListener("artifact-markup-added") { [self] _ in
        for pane in self.markupPanes {
          let index = parseInt(pane.dataset["page-index"] ?? "") ?? -1
          if self.manifestFailed, index >= 0, index < self.serviceIDs.count, stringIsEmpty(self.serviceIDs[index]) {
            self.serviceIDs[index] = pane.dataset["service-id"] ?? ""
          }
        }
        if case .some = root.querySelector(".artifact-markup [data-layer='translated-rendering']") {
          self.translatable = true
        }
        self.showLayers()
        self.showMarkup(for: self.canvasIndex)
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
      let raw = root.querySelector(".artifact-xml-toggle")
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
      reflectSyncApplies()
      root.setAttribute(data("canvas-shown"), canvasShown ? "true" : "false")
      canvasToggle?.setAttribute("aria-pressed", canvasShown ? "true" : "false")
      canvasToggle?.querySelector("button")?.setAttribute("aria-pressed", canvasShown ? "true" : "false")
    }

    private var reflowToggle: DOM.Element?
    private var detachToggle: DOM.Element?
    private var syncOn = true

    private func setupSyncSwitch() {
      guard let toggle = root.querySelector(".artifact-detach-toggle") else { return }
      detachToggle = toggle
      setDetached(stringEquals(sessionStorage.getItem(ArtifactHydration.detachKey) ?? "false", "true"))
      _ = toggle.addEventListener("toggle-button-update") { (event: Event) in
        ArtifactHydration.detach(stringEquals(event.detail, "true"))
      }
    }

    /// Each pane alone, or synced again (the text brought to the image's
    /// part of the page at once).
    func setDetached(_ detached: Bool) {
      guard let toggle = detachToggle else { return }
      syncOn = !detached
      toggle.setAttribute("aria-pressed", detached ? "true" : "false")
      toggle.querySelector("button")?.setAttribute("aria-pressed", detached ? "true" : "false")
      reflectSyncApplies()
      if !detached, let region = shownCanvas?.region { animateTextMatch(to: region) }
    }

    /// The switch disabled, never hidden, where sync cannot apply—Raw,
    /// Reflow, the images put away—so it says it can come back; its state
    /// kept underneath.
    private func reflectSyncApplies() {
      let active = overlayOn && !rawVisible && !reflowOn && canvasShown
      root.setAttribute(data("overlay-active"), active ? "true" : "false")
      if let button = root.querySelector(".artifact-overlay-toggle button") {
        if rawVisible || reflowOn || !canvasShown { button.setAttribute("disabled", "") }
        else { button.removeAttribute("disabled") }
      }
      let detached = active || !syncOn
      detachToggle?.setAttribute("aria-pressed", detached ? "true" : "false")
      detachToggle?.querySelector("button")?.setAttribute("aria-pressed", detached ? "true" : "false")
      guard let button = detachToggle?.querySelector("button") else { return }
      if rawVisible || reflowOn || !canvasShown || active {
        button.setAttribute("disabled", "")
      } else {
        button.removeAttribute("disabled")
      }
    }

    /// Reflow, as this session left it: the markup's lines and its code's,
    /// which pages fetched later follow (TEIView's and CodeView's CSS read
    /// `data-reflow`).
    private func setupReflowSwitch() {
      guard let toggle = root.querySelector(".artifact-reflow-toggle") else { return }
      reflowToggle = toggle
      setReflow(stringEquals(sessionStorage.getItem(ArtifactHydration.reflowKey) ?? "false", "true"))
      _ = toggle.addEventListener("toggle-button-update") { (event: Event) in
        ArtifactHydration.reflow(stringEquals(event.detail, "true"))
      }
    }

    func setReflow(_ on: Bool) {
      guard let toggle = reflowToggle else { return }
      root.setAttribute(data("reflow"), on ? "true" : "false")
      toggle.setAttribute("aria-pressed", on ? "true" : "false")
      toggle.querySelector("button")?.setAttribute("aria-pressed", on ? "true" : "false")
      reflectSyncApplies()
      scheduleZoom()
    }

    private var rawVisible = false
    private var translationVisible = false
    /// Whether the markup has a translated layer to show at all.
    private var translatable = false

    /// The layer each page shows, by the two switches.
    private var shownLayerName: String {
      let translated = translatable && translationVisible
      return translated ? (rawVisible ? "translated-markup" : "translated-rendering") : (rawVisible ? "markup" : "rendering")
    }

    /// The one layer of each page that shows, by two switches (user,
    /// 2026-10-07): the language switch picks the markup or its
    /// translation, Raw picks either's text or its code. A page with no
    /// translation shows nothing under either: emptiness, never a dash.
    private func showLayers() {
      reflectSyncApplies()
      let layer = shownLayerName
      for pane in root.querySelectorAll(".artifact-markup .tei-page") {
        for element in pane.querySelectorAll("[data-layer]") {
          let name = element.getAttribute(data("layer")) ?? ""
          // Each layer is a flex column: the rendered page's paragraphs
          // stand apart by its gap (user, 2026-10-11).
          if !stringEquals(name, layer) {
            element.style.display(.none)
            element.closest("[data-page-scale='true']")?.style.display(.none)
          } else {
            element.style.display(.flex)
            element.closest("[data-page-scale='true']")?.style.display(.block)
          }
        }
      }
      scheduleZoom()
    }

    // MARK: - Zoom

    /// The text zooms as the image does (`CanvasReader`, user, 2026-10-12),
    /// so a page's lines can be laid against its scan: from the fit of the
    /// whole page (`CanvasReader.fitToViewport`'s) to its actual size,
    /// 100% (`ViewerZoom.actualSize`), its page top-aligned, the rendered
    /// page centered across the pane as the image is, the code filling it,
    /// scrolled with no gap where it is larger. Its fit: the whole page's
    /// where it is larger than the pane, else its actual size. Unlike the image, which opens at
    /// its fit, the text opens at its actual size: text is read at its
    /// size. A sized frame reserves the rendered page's scaled extent while
    /// a transform preserves its typography. Reflow and code use CSS zoom. Each layer keeps its own
    /// zoom (the rendered page's, the code's) for the session, Reflow on or
    /// off: reflowed, zooming out wraps the text wider and shorter, and its
    /// fit is the zoom at which its whole height fits the pane.
    ///
    /// Each layer's zoom, nil until set or read back, and whether it is at
    /// its fit, which it follows as the pane, the page or Reflow changes
    /// (a dictionary of them would hash its String keys, which embedded
    /// WASM cannot).
    private var renderingZoom: Double?
    private var markupZoom: Double?
    private var renderingAtFit: Bool?
    private var markupAtFit: Bool?
    private var zoomQueued = false
    /// The zoom a Safari pinch began at (WebKit's `gesturestart`).
    private var gestureStartZoom = 1.0
    /// A pinch's two fingers' distance and the zoom it began at.
    private var pinchStart: (distance: Double, zoom: Double)?
    /// The session's zoom of a layer: "fit", or a zoom.
    private static let zoomKey = "gnorium:artifact-zoom:"

    private var markupPane: DOM.Element? { root.querySelector(".artifact-markup") }
    private var reflowOn: Bool { stringEquals(root.getAttribute(data("reflow")) ?? "", "true") }
    private var overlayOn = false
    private var beforeOverlay: (zoom: Double?, atFit: Bool)?
    private var overlayZoomStart = 1.0
    private var overlayZoomBegan = 0.0
    private var overlayScrollStart = (x: 0.0, y: 0.0)
    private var overlayMotion = 0
    /// Overlay turned off, the text still on its way back to its zoom and
    /// scroll: the same motion as the way in, run backward.
    private var overlayLeaving = false
    private func setupOverlay() {
      guard let toggle = root.querySelector(".artifact-overlay-toggle") else { return }
      _ = toggle.addEventListener("toggle-button-update") { [self] event in
        let on = stringEquals(event.detail, "true")
        if on && !self.overlayOn {
          // Registered from the scan's fit, where the page's text block
          // is measured; without one, the scan stays as the reader left it.
          self.overlayTarget = ("", [])
          if let _ = self.overlayZone() { self.shownCanvas?.fitForRegistration() }
          self.beforeOverlay = self.storedZoom()
          self.overlayZoomStart = self.currentZoom()
          self.overlayScrollStart = (self.markupPane?.scrollLeft ?? 0, self.markupPane?.scrollTop ?? 0)
          self.overlayZoomBegan = window.performance.now()
          self.overlayLeaving = false
          self.setZoom(nil, atFit: true)
        } else if !on, let before = self.beforeOverlay {
          self.overlayZoomStart = self.currentZoom()
          self.overlayZoomBegan = window.performance.now()
          self.overlayLeaving = true
          self.setZoom(before.zoom, atFit: before.atFit)
          self.beforeOverlay = nil
        }
        self.overlayOn = on
        self.reflectSyncApplies()
        self.scheduleZoom()
        self.overlayMotion += 1
        let ticket = self.overlayMotion
        @Sendable func frame() {
          guard self.overlayOn == on, self.overlayMotion == ticket, self.isInDocument else { return }
          self.applyZoom(about: nil)
          if self.overlayProgress < 1 {
            _ = window.requestAnimationFrame { frame() }
          } else if !on {
            // Back at its zoom, with the panels at their normal sizes:
            // matching resumes from the restored text view rather than the
            // calibrated scan.
            self.overlayLeaving = false
            self.applyZoom(about: nil)
            if self.syncs { self.matchImage() }
          }
        }
        _ = window.requestAnimationFrame { frame() }
      }
      reflectSyncApplies()
    }

    private var overlayProgress: Double {
      if window.matchMedia("(prefers-reduced-motion: reduce)") { return 1 }
      let p = min(1, max(0, (window.performance.now() - overlayZoomBegan) / 400))
      return p * p * (3 - 2 * p)
    }

    /// The shown page's text block on its scan (`TEIView`'s
    /// `data-text-block`): its four corners, x and y in turn, in the 0–1000
    /// space; nil where it was not measured.
    private func overlayZone() -> [Double]? {
      guard let page = root.querySelector(".artifact-markup .tei-page[data-active='true']"),
        let text = page.getAttribute(data("text-block")), !stringIsEmpty(text)
      else { return nil }
      var values: [Double] = []
      for point in stringSplit(text, separator: " ") {
        for value in stringSplit(point, separator: ",") {
          guard let number = parseDouble(value) else { return nil }
          values.append(number)
        }
      }
      return values.count == 8 ? values : nil
    }

    /// The page's rendered text block in the window: the ink box of all
    /// its frame sets—its text (`InkExtent`: its glyphs' ink, not their
    /// font boxes nor a line's trailing letter-spacing), its rules, its
    /// figures and its printed frames (those that draw a border)—as its four
    /// corners clockwise from the top-left, x and y in turn, within the
    /// frame's measure. The scan's
    /// zone is the box around all the page prints and holds in writing, as
    /// the edition sets it all in its frame (user, 2026-10-14). Measured
    /// once a page in the layer's own pixels (`overlayTarget`) and placed
    /// where the layer now is, so the overlay's motion reads no text a
    /// frame. gnorium-python's `layout_preview` measures the same box, rule
    /// for rule, on the explication's render (`_TEXT_BLOCK`): a change here
    /// is made there too.
    private func renderedTextBlock(in layer: DOM.Element) -> [Double]? {
      guard let page = layer.closest(".tei-page"), let box = layer.getBoundingClientRect(), box.width > 0 else {
        return nil
      }
      let zoom = currentZoom()
      let id = (page.getAttribute(data("service-id")) ?? "") + " " + (layer.getAttribute(data("layer")) ?? "")
      if !stringEquals(overlayTarget.page, id) || overlayTarget.box.count != 4 {
        let frame = layer.querySelector(".tei-text-block") ?? layer
        var ink = InkExtent()
        if let context = document.createElement("canvas").getContext("2d") {
          let walker = document.createTreeWalker(frame, DOM.NodeFilter.SHOW_TEXT)
          let range = document.createRange()
          while let next = walker.nextNode() {
            guard let node = next as? DOM.Text, let parent = node.parentElement else { continue }
            measureInk(of: node, in: parent, context: context, range: range, into: &ink)
          }
        }
        for drawn in frame.querySelectorAll(".tei-rule, .tei-figure-image, .tei-frame") {
          // A frame draws ink only where it draws a border: one that sets
          // its lines' margins or measure alone draws nothing.
          if drawn.classList.contains("tei-frame") && !drawsBorder(drawn) { continue }
          if let rect = drawn.getBoundingClientRect() {
            ink.take(left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom)
          }
        }
        // Never wider than the frame: a line set wider than its measure
        // (a face wider than the print's) runs past it, and the scan's text
        // block is the measure's.
        if frame !== layer, let edges = frame.getBoundingClientRect() {
          ink.left = max(ink.left, edges.left)
          ink.right = min(ink.right, edges.right)
        }
        guard let measured = ink.box, zoom > 0 else { return nil }
        overlayTarget = (
          id,
          [
            (measured[0] - box.x) / zoom, (measured[1] - box.y) / zoom, (measured[2] - box.x) / zoom,
            (measured[3] - box.y) / zoom,
          ]
        )
      }
      let measured = overlayTarget.box
      let left = box.x + measured[0] * zoom
      let top = box.y + measured[1] * zoom
      let right = box.x + measured[2] * zoom
      let bottom = box.y + measured[3] * zoom
      return [left, top, right, top, right, bottom, left, bottom]
    }

    /// Whether an element draws a border on any side: a style other than
    /// none, at a width.
    private func drawsBorder(_ element: DOM.Element) -> Bool {
      let style = window.getComputedStyle(element)
      for side in ["top", "right", "bottom", "left"] {
        let drawn = !stringEquals(style.getPropertyValue("border-" + side + "-style"), "none")
        if drawn, let width = parseDouble(stringReplace(style.getPropertyValue("border-" + side + "-width"), "px", "")),
          width > 0
        {
          return true
        }
      }
      return false
    }

    /// A text node's ink (`InkExtent`), line by line: on each line it is
    /// set on, its font box as drawn less the font's ascent and descent and
    /// plus its glyphs' (`measureText` in the node's computed font), and
    /// across from its first and last glyphs' ink—a glyph a code point that
    /// is no space, tab or line end. The node's own lines where it is set on
    /// one; else its glyphs grouped by the line each is set on.
    private func measureInk(
      of node: DOM.Text, in parent: DOM.Element, context: DOM.CanvasRenderingContext2D, range: DOM.Range,
      into ink: inout InkExtent
    ) {
      let bytes = Array(node.data.utf8)
      // Each glyph's bounds in UTF-16 code units (the range's) and in
      // UTF-8 bytes (its text's).
      var glyphs: [(start: Int, end: Int, from: Int, to: Int)] = []
      var unit = 0
      var byte = 0
      for scalar in node.data.unicodeScalars {
        let units = UTF16.width(scalar)
        let size = UTF8.width(scalar)
        if !(scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r") {
          glyphs.append((unit, unit + units, byte, byte + size))
        }
        unit += units
        byte += size
      }
      guard !glyphs.isEmpty else { return }
      func drawn(_ start: Int, _ end: Int) -> DOM.Rect? {
        range.setStart(node, start)
        range.setEnd(node, end)
        return range.getBoundingClientRect()
      }
      func text(_ from: Int, _ to: Int) -> String {
        String(decoding: bytes[from..<to], as: UTF8.self)
      }
      let style = window.getComputedStyle(parent)
      context.font =
        style.getPropertyValue("font-style") + " " + style.getPropertyValue("font-weight") + " "
        + style.getPropertyValue("font-size") + " " + style.getPropertyValue("font-family")
      context.fontVariantCaps = style.getPropertyValue("font-variant-caps")
      context.fontKerning = style.getPropertyValue("font-kerning")
      range.setStart(node, 0)
      range.setEnd(node, node.length)
      let boxes = range.getClientRects().filter { $0.height > 0 }
      guard let firstBox = boxes.first else { return }
      let oneLine = boxes.allSatisfy { $0.top < firstBox.bottom && firstBox.top < $0.bottom }
      // Each line: its span (UTF-16, UTF-8), its rows, its first and last
      // glyph's bytes and drawn left.
      var lines: [(start: Int, end: Int, from: Int, to: Int, top: Double, bottom: Double, ends: [(Int, Int, Double)])] =
        []
      for (index, glyph) in glyphs.enumerated() {
        if oneLine && index > 0 && index < glyphs.count - 1 { continue }
        guard let rect = drawn(glyph.start, glyph.end), rect.height > 0 else { continue }
        let end = (glyph.from, glyph.to, rect.left)
        if let last = lines.last, rect.top < last.bottom, last.top < rect.bottom {
          lines[lines.count - 1].end = glyph.end
          lines[lines.count - 1].to = glyph.to
          lines[lines.count - 1].ends = [last.ends[0], end]
        } else {
          lines.append((glyph.start, glyph.end, glyph.from, glyph.to, rect.top, rect.bottom, [end, end]))
        }
      }
      for line in lines {
        guard let box = drawn(line.start, line.end) else { continue }
        let metrics = context.measureText(text(line.from, line.to))
        guard
          let scale = InkExtent.scale(
            drawnHeight: box.height, fontAscent: metrics.fontBoundingBoxAscent,
            fontDescent: metrics.fontBoundingBoxDescent)
        else { continue }
        let rows = InkExtent.vertical(
          drawnTop: box.top, drawnBottom: box.bottom, fontAscent: metrics.fontBoundingBoxAscent,
          fontDescent: metrics.fontBoundingBoxDescent, inkAscent: metrics.actualBoundingBoxAscent,
          inkDescent: metrics.actualBoundingBoxDescent, scale: scale)
        var left = Double.infinity
        var right = -Double.infinity
        for (from, to, drawnLeft) in line.ends {
          let glyph = context.measureText(text(from, to))
          let across = InkExtent.horizontal(
            drawnLeft: drawnLeft, inkLeft: glyph.actualBoundingBoxLeft, inkRight: glyph.actualBoundingBoxRight,
            scale: scale)
          left = min(left, across.left)
          right = max(right, across.right)
        }
        ink.take(left: left, top: rows.top, right: right, bottom: rows.bottom)
      }
    }

    /// The shown page's rendered text block in its layer's own pixels
    /// (left, top, right, bottom), by its page's image and its layer.
    private var overlayTarget: (page: String, box: [Double]) = ("", [])

    /// The overlay's registration (user, 2026-10-13): where the shown page's
    /// text block was measured on its scan (`overlayZone`), the scan is laid
    /// by the projective transform that takes those corners to the rendered
    /// text block's (`renderedTextBlock`), eased in with the overlay's own
    /// motion and out with it (`CanvasReader.register`). Without one, the
    /// scan is as before.
    private func registerOverlay() {
      guard let canvas = shownCanvas else { return }
      let progress = overlayOn ? overlayProgress : overlayLeaving ? 1 - overlayProgress : 0
      guard progress > 0, let zone = overlayZone(), let layer = shownLayer(),
        let target = renderedTextBlock(in: layer)
      else {
        canvas.clearRegistration()
        return
      }
      canvas.register(zone: zone, onto: target, progress: progress)
    }

    /// Which zoom the shown layer keeps: the code's (Raw) or the page's.
    private var zoomKind: String { rawVisible ? "markup" : "rendering" }

    /// The shown layer's zoom: as set, else as the session left it, else
    /// its actual size; and whether it is at its fit.
    private func storedZoom() -> (zoom: Double?, atFit: Bool) {
      let zoom = rawVisible ? markupZoom : renderingZoom
      let atFit = rawVisible ? markupAtFit : renderingAtFit
      if let atFit { return (zoom, atFit) }
      let kept = sessionStorage.getItem(Self.zoomKey + zoomKind) ?? ""
      if stringEquals(kept, "fit") { return (nil, true) }
      return (parseDouble(kept), false)
    }

    /// The shown layer's zoom as drawn now.
    private func currentZoom() -> Double {
      parseDouble(shownLayer()?.getAttribute(data("zoom")) ?? "") ?? ViewerZoom.actualSize
    }

    private func setZoom(_ value: Double?, atFit: Bool) {
      if rawVisible {
        markupZoom = value
        markupAtFit = atFit
      } else {
        renderingZoom = value
        renderingAtFit = atFit
      }
    }

    /// The page on screen's shown layer.
    private func shownLayer() -> DOM.Element? {
      root.querySelector(
        ".artifact-markup .tei-page[data-active='true'] [data-layer='" + shownLayerName + "']")
    }

    private func setupZoom() {
      guard let pane = markupPane else { return }
      // The fit follows the pane's size and the page's content: a page
      // fetched in, a page turned, the pane resized.
      pane.observeResize { [self] _, _ in self.scheduleZoom() }
      pane.observeMutations(childList: true, subtree: true) { [self] in self.scheduleZoom() }
      _ = pane.addEventListener("wheel", { [self] e in self.wheel(e) }, capture: false, passive: false)
      // A drag from the text selects it, as text is selected; a drag from
      // anywhere else (between lines, the margins, the ground) pans it, as
      // the image is panned. The current rule (user, 2026-10-12), which may
      // be revisited: on a dense page the scrollbars and the wheel's zoom
      // pan it too. A double or triple click and Shift+click stay the
      // browser's own.
      _ = pane.addEventListener("mousedown", { [self] e in self.beginPan(e) }, capture: false, passive: false)
      // The cursor says which a drag would do: the I-beam over the text,
      // the hand elsewhere.
      _ = pane.addEventListener(
        "mousemove",
        { [self] e in
          guard self.panStart == nil, let pane = self.markupPane else { return }
          let over = self.isOnText(x: e.clientX, y: e.clientY) ? "true" : "false"
          if !stringEquals(pane.getAttribute(data("over-text")) ?? "", over) { pane.setAttribute(data("over-text"), over) }
        }, capture: false, passive: true)
      // A press that moved was a pan, not a click: no gloss, no link.
      _ = pane.addEventListener(
        "click",
        { [self] e in
          if self.panMoved {
            self.panMoved = false
            e.preventDefault()
            e.stopPropagation()
          }
        }, capture: true, passive: false)
      // Focused, the keys move it as the image's do: the arrows pan, + and
      // − zoom, 0 opens it again at its actual size or its fit.
      pane.setAttribute("tabindex", "0")
      _ = pane.addEventListener("keydown", { [self] e in self.zoomKey(e) }, capture: false, passive: false)
      _ = pane.addEventListener("scroll", { [self] _ in self.scrolled() }, capture: false, passive: true)
      _ = pane.addEventListener("touchstart", { [self] e in self.pinch(e) }, capture: false, passive: false)
      _ = pane.addEventListener("touchmove", { [self] e in self.pinch(e) }, capture: false, passive: false)
      _ = pane.addEventListener(
        "touchend", { [self] e in if e.touchCount < 2 { self.pinchStart = nil } }, capture: false, passive: true)
      // Safari's trackpad pinch: WebKit's gesture events, not ctrl+wheel.
      // Zoomed about the gesture's point from the zoom it began at, by its
      // scale; the page itself never zoomed. Other browsers never send them.
      _ = pane.addEventListener(
        "gesturestart",
        { [self] e in
          guard !self.rawVisible else { return }
          e.preventDefault()
          self.gestureStartZoom = self.currentZoom()
        }, capture: false, passive: false)
      _ = pane.addEventListener(
        "gesturechange",
        { [self] e in
          guard !self.rawVisible else { return }
          e.preventDefault()
          guard let pane = self.markupPane, let box = pane.getBoundingClientRect() else { return }
          self.zoom(to: self.gestureStartZoom * e.webKitGestureScale, about: (e.clientX - box.x, e.clientY - box.y))
        }, capture: false, passive: false)
      _ = pane.addEventListener("gestureend", { [self] e in if !self.rawVisible { e.preventDefault() } }, capture: false, passive: false)
      scheduleZoom()
    }

    /// The wheel—a plain one, a trackpad's two fingers or pinch (the
    /// browser's ctrl+wheel), ctrl/cmd+wheel—zooms about the pointer, as
    /// the image's does, and never scrolls the page (user, 2026-10-12).
    private func wheel(_ event: Event) {
      // Raw is an ordinary code scrollport; it does not synchronize zoom.
      if rawVisible { return }
      guard let pane = markupPane, let box = pane.getBoundingClientRect() else { return }
      event.preventDefault()
      zoom(
        to: currentZoom() * ViewerZoom.wheelFactor(event.deltaY),
        about: (event.clientX - box.x, event.clientY - box.y))
    }

    /// Two fingers zoom about their midpoint, by how far they spread.
    private func pinch(_ event: Event) {
      guard !rawVisible, event.touchCount == 2, let pane = markupPane, let box = pane.getBoundingClientRect() else { return }
      let x0 = event.touchClientX(0), y0 = event.touchClientY(0)
      let x1 = event.touchClientX(1), y1 = event.touchClientY(1)
      let distance = ((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)).squareRoot()
      guard distance > 0 else { return }
      event.preventDefault()
      guard let start = pinchStart else {
        pinchStart = (distance, currentZoom())
        return
      }
      zoom(to: start.zoom * distance / start.distance, about: ((x0 + x1) / 2 - box.x, (y0 + y1) / 2 - box.y))
    }

    /// A drag under way: where it began, and the scroll it began at.
    private var panStart: (x: Double, y: Double, left: Double, top: Double)?
    private var panMoveListener: Int32 = -1
    private var panUpListener: Int32 = -1
    /// Whether the press under way, or just ended, moved: a pan, not a
    /// click. Any movement counts, as the browser exposes no drag threshold.
    private var panMoved = false

    /// Whether a point of the viewport is on text: the character the caret
    /// would stand by there (`caretPositionFromPoint`) has the point in its
    /// box, either side of the caret.
    private func isOnText(x: Double, y: Double) -> Bool {
      guard let caret = document.caretPositionFromPoint(x, y), let text = caret.offsetNode as? DOM.Text else {
        return false
      }
      for (start, end) in [(caret.offset - 1, caret.offset), (caret.offset, caret.offset + 1)]
      where start >= 0 && end <= text.length {
        let range = document.createRange()
        range.setStart(text, start)
        range.setEnd(text, end)
        if let box = range.getBoundingClientRect(), x >= box.left, x <= box.right, y >= box.top, y <= box.bottom {
          return true
        }
      }
      return false
    }

    /// A press of the main button off the text starts a pan; on the text,
    /// a double or triple click (a word, a line) and Shift (extend) are left
    /// to the browser's own selection.
    private func beginPan(_ event: Event) {
      guard let pane = markupPane, event.button == 0, event.clickCount <= 1, !event.shiftKey,
        !isOnText(x: event.clientX, y: event.clientY)
      else { return }
      // Code being edited takes its own presses: its caret, its selection.
      if let _ = event.target?.closest("input, textarea, select, [contenteditable='true'], [contenteditable='plaintext-only']") {
        return
      }
      // No selection begun, and the focus the press would have given, the
      // page left where it is.
      event.preventDefault()
      pane.focus(DOM.FocusOptions(preventScroll: true))
      textMatchAnimation += 1
      matchImage()
      panMoved = false
      panStart = (event.clientX, event.clientY, pane.scrollLeft, pane.scrollTop)
      endPan()
      panMoveListener = window.addEventListener(.mousemove) { [self] e in
        guard let start = self.panStart, let pane = self.markupPane else { return }
        if e.clientX != start.x || e.clientY != start.y {
          self.panMoved = true
          pane.setAttribute(data("dragging"), "true")
        }
        pane.scrollLeft = start.left - (e.clientX - start.x)
        pane.scrollTop = start.top - (e.clientY - start.y)
        self.matchImage()
      }
      panUpListener = window.addEventListener(.mouseup) { [self] _ in
        self.panStart = nil
        self.endPan()
      }
    }

    private func endPan() {
      if panMoveListener >= 0 { window.removeEventListener(.mousemove, panMoveListener) }
      if panUpListener >= 0 { window.removeEventListener(.mouseup, panUpListener) }
      panMoveListener = -1
      panUpListener = -1
      markupPane?.removeAttribute(data("dragging"))
    }

    /// The keys of the focused pane: the arrows pan by a wheel's travel
    /// (`ViewerZoom.wheelTravel`), + and − zoom by a wheel's step about the
    /// pane's middle, 0 opens it again (its actual size, or its fit).
    private func zoomKey(_ event: Event) {
      // The pane's own keys, when it has the focus: a word's arrows move
      // between words, a field's its caret.
      guard !rawVisible, let pane = markupPane, let target = event.target, target.id == pane.id,
        let box = pane.getBoundingClientRect()
      else { return }
      textMatchAnimation += 1
      let key = event.key
      let middle = (box.width / 2, box.height / 2)
      if stringEquals(key, "+") || stringEquals(key, "=") {
        zoom(to: currentZoom() * ViewerZoom.wheelFactor(-ViewerZoom.wheelTravel), about: middle)
      } else if stringEquals(key, "-") {
        zoom(to: currentZoom() * ViewerZoom.wheelFactor(ViewerZoom.wheelTravel), about: middle)
      } else if stringEquals(key, "0") {
        setZoom(nil, atFit: false)
        sessionStorage.removeItem(Self.zoomKey + zoomKind)
        applyZoom(about: nil)
        matchImage()
      } else if stringEquals(key, "ArrowLeft") {
        pane.scrollLeft -= ViewerZoom.wheelTravel
      } else if stringEquals(key, "ArrowRight") {
        pane.scrollLeft += ViewerZoom.wheelTravel
      } else if stringEquals(key, "ArrowUp") {
        pane.scrollTop -= ViewerZoom.wheelTravel
      } else if stringEquals(key, "ArrowDown") {
        pane.scrollTop += ViewerZoom.wheelTravel
      } else {
        return
      }
      event.preventDefault()
      event.stopPropagation()
    }

    private func zoom(to value: Double, about anchor: (x: Double, y: Double)) {
      textMatchAnimation += 1
      // A new wording gesture supersedes an image move awaiting its frame.
      pendingTextRegion = nil
      setZoom(value, atFit: false)
      applyZoom(about: anchor)
      // Even at a zoom limit, cancelling a reattach must bring the image
      // to the text's current view, including the newest input.
      matchImage()
    }

    // MARK: - Pane sync

    /// The image and the rendered text, Reflow off, show the same part of
    /// their page (a dev experiment, user 2026-10-12; on, no switch): each
    /// a fraction of its own page and a zoom over its own fit
    /// (`ViewerZoom.Region`), so a move in one is matched in the other. The
    /// code is not: its lines are not the page's. A move made to match is
    /// never matched back: the image's is told to no one, and the text's
    /// scroll is known by where it was put (`matchedScroll`).
    private var lastFit = ViewerZoom.actualSize
    private var matchedScroll: (x: Double, y: Double)?
    /// The text zooms as far over its fit as its page's image can over its
    /// own (`ViewerZoom.Region.maxScale`), synced or not, so the two sizes
    /// match and stay matched; with no image, to 100%.
    private var matchedMaxScale: Double? {
      guard canvasShown && !rawVisible && !reflowOn else { return nil }
      return shownCanvas?.region?.maxScale
    }

    /// The most the text zooms in, its fit being `fit`.
    private func maxZoom(fit: Double) -> Double {
      guard let scale = matchedMaxScale else { return max(fit, ViewerZoom.actualSize) }
      return max(fit, fit * scale)
    }

    /// Whether the two are matched now.
    private var syncs: Bool { !overlayOn && !overlayLeaving && syncOn && !reflowOn && !rawVisible && canvasShown && shownCanvas != nil }

    /// What the text shows now, nil until it has a size.
    private func textRegion() -> ViewerZoom.Region? {
      guard let pane = markupPane, let layer = shownLayer(), let box = layer.getBoundingClientRect(),
        let paneBox = pane.getBoundingClientRect(), box.width > 0, box.height > 0
      else { return nil }
      let zoom = parseDouble(layer.getAttribute(data("zoom")) ?? "") ?? ViewerZoom.actualSize
      return .init(
        centerX: (paneBox.x + pane.clientWidth / 2 - box.x) / box.width,
        centerY: (paneBox.y + pane.clientHeight / 2 - box.y) / box.height,
        scale: zoom / lastFit, maxScale: maxZoom(fit: lastFit) / lastFit)
    }

    /// The image's latest region, for the text to take at the next frame:
    /// a burst of wheel events (several a frame) moves the text once a
    /// frame, the latest region winning, so it never stutters.
    private var pendingTextRegion: ViewerZoom.Region?
    private var matchQueued = false
    private var pendingImageMatch = false

    private var textMatchAnimation = 0

    /// Reattaching is a reader action, so visibly move into the image's view.
    /// A newer gesture or mode change cancels the interpolation.
    private func animateTextMatch(to target: ViewerZoom.Region) {
      textMatchAnimation += 1
      pendingTextRegion = nil
      pendingImageMatch = false
      guard syncs, let start = textRegion(), !window.matchMedia("(prefers-reduced-motion: reduce)") else {
        matchText(to: target)
        return
      }
      let ticket = textMatchAnimation
      let began = window.performance.now()
      @Sendable func step() {
        guard ticket == self.textMatchAnimation, self.syncs, self.isInDocument else { return }
        let progress = min(1, max(0, (window.performance.now() - began) / 400))
        let eased = progress * progress * (3 - 2 * progress)
        func between(_ a: Double, _ b: Double) -> Double { a + (b - a) * eased }
        self.applyMatchText(.init(
          centerX: between(start.centerX, target.centerX),
          centerY: between(start.centerY, target.centerY),
          scale: between(start.scale, target.scale), maxScale: target.maxScale))
        if progress < 1 { _ = window.requestAnimationFrame { step() } }
      }
      _ = window.requestAnimationFrame { step() }
    }

    /// The text at the image's region, at the next frame.
    private func matchText(to region: ViewerZoom.Region) {
      textMatchAnimation += 1
      pendingTextRegion = region
      pendingImageMatch = false
      scheduleMatch()
    }

    /// Both directions share a frame: the latest reader move wins, and
    /// an older move from the other pane cannot overwrite it afterwards.
    private func scheduleMatch() {
      if matchQueued { return }
      matchQueued = true
      _ = window.requestAnimationFrame { [self] in
        self.matchQueued = false
        let region = self.pendingTextRegion
        let image = self.pendingImageMatch
        self.pendingTextRegion = nil
        self.pendingImageMatch = false
        if let region {
          self.applyMatchText(region)
        } else if image, self.syncs, let canvas = self.shownCanvas, let region = self.textRegion() {
          canvas.show(region: region)
        }
      }
    }

    /// The text's zoom, then its scroll, in one frame: the scroll from the
    /// region's own point, never from the scroll before, so no rounding
    /// adds up.
    private func applyMatchText(_ region: ViewerZoom.Region) {
      guard syncs, let pane = markupPane, let layer = shownLayer() else { return }
      let zoom = max(lastFit, min(maxZoom(fit: lastFit), lastFit * region.scale))
      setZoom(zoom, atFit: zoom <= lastFit)
      applyZoom(about: nil, matching: true)
      guard let box = layer.getBoundingClientRect(), let paneBox = pane.getBoundingClientRect() else { return }
      // The layer's place in what the pane scrolls, and the point to center.
      let left = box.x - paneBox.x + pane.scrollLeft
      let top = box.y - paneBox.y + pane.scrollTop
      pane.scrollLeft = left + region.centerX * box.width - pane.clientWidth / 2
      pane.scrollTop = top + region.centerY * box.height - pane.clientHeight / 2
      matchedScroll = (pane.scrollLeft, pane.scrollTop)
    }

    /// The image at the text's region, when the reader moved the text: at
    /// the next frame, once however many moves it saw.
    private func matchImage() {
      pendingTextRegion = nil
      pendingImageMatch = true
      scheduleMatch()
    }

    /// The pane scrolled: by the reader, matched; to match, let be.
    private func scrolled() {
      guard let pane = markupPane else { return }
      // Where it was put to match, within a pixel's rounding: no echo.
      if let matched = matchedScroll, abs(pane.scrollLeft - matched.x) <= 1, abs(pane.scrollTop - matched.y) <= 1 {
        return
      }
      matchedScroll = nil
      textMatchAnimation += 1
      matchImage()
    }

    /// "12.5px" as 12.5; anything else as 0.
    private func pixels(_ value: String) -> Double {
      parseDouble(stringRemoveSuffix(value, "px")) ?? 0
    }

    private func scheduleZoom() {
      if zoomQueued { return }
      zoomQueued = true
      _ = window.requestAnimationFrame { [self] in
        self.zoomQueued = false
        self.applyZoom(about: nil)
      }
    }

    /// The contain fit, never above the text's actual size: a page smaller
    /// than the pane is read at its size, its box filling the pane, never
    /// enlarged or shown small in it.
    private func containFit(width: Double, height: Double, paneWidth: Double, paneHeight: Double) -> Double {
      min(paneWidth / max(paneWidth, width), paneHeight / max(paneHeight, height))
    }

    /// The fit of the rendered text of the page `codeLayer` is on: measured
    /// from it as it would be shown—at its actual size, Reflow off; its
    /// height as it wraps, Reflow on—out of sight, then put back as it was.
    private func renderedFit(of codeLayer: DOM.Element, paneWidth: Double, paneHeight: Double) -> Double? {
      let name = stringEquals(codeLayer.getAttribute(data("layer")) ?? "", "translated-markup")
        ? "translated-rendering" : "rendering"
      guard let page = codeLayer.closest(".tei-page"),
        let rendered = page.querySelector("[data-layer='" + name + "']")
      else { return nil }
      restoreFlow(of: rendered)
      let zoom = rendered.style.getPropertyValue("zoom")
      let transform = rendered.style.getPropertyValue("transform")
      rendered.style.setProperty("transform", "none")
      rendered.style.setProperty("visibility", "hidden")
      rendered.style.setProperty("position", "absolute")
      rendered.style.display(.flex)
      // Reflowed, it wraps to the pane's width, as when shown.
      if reflowOn { rendered.style.setProperty("width", doubleToString(paneWidth) + "px") }
      var fit: Double?
      if reflowOn {
        fit = reflowedFit(rendered, paneHeight: paneHeight)
      } else if let box = measure(rendered, at: ViewerZoom.actualSize), box.width > 0, box.height > 0 {
        fit = containFit(width: box.width, height: box.height, paneWidth: paneWidth, paneHeight: paneHeight)
      }
      rendered.style.display(.none)
      if stringIsEmpty(transform) {
        _ = rendered.style.removeProperty("transform")
      } else {
        rendered.style.setProperty("transform", transform)
      }
      _ = rendered.style.removeProperty("visibility")
      _ = rendered.style.removeProperty("position")
      _ = rendered.style.removeProperty("width")
      if stringIsEmpty(zoom) {
        _ = rendered.style.removeProperty("zoom")
      } else {
        rendered.style.setProperty("zoom", zoom)
      }
      return fit
    }

    /// `layer` at `zoom`: its rendered box.
    private func measure(_ layer: DOM.Element, at zoom: Double) -> DOM.Rect? {
      layer.style.setProperty("zoom", doubleToString(zoom))
      return layer.getBoundingClientRect()
    }

    /// The zoom at which reflowed text's whole height fits `paneHeight`,
    /// never above its actual size, found by halving: zoomed out, it wraps
    /// wider and shorter, so its height is measured, never estimated. At
    /// `paneHeight /` its height at its actual size it fits (no line is
    /// taller, none are added); at its actual size it does not; the two
    /// close to within a pixel of its height.
    private func reflowedFit(_ layer: DOM.Element, paneHeight: Double) -> Double? {
      guard let whole = measure(layer, at: ViewerZoom.actualSize), whole.height > 0 else { return nil }
      // Shorter than the pane at its actual size, it is read there.
      if whole.height <= paneHeight { return ViewerZoom.actualSize }
      var fits = paneHeight / whole.height
      var overflows = ViewerZoom.actualSize
      while (overflows - fits) * whole.height > 1 {
        let middle = (fits + overflows) / 2
        guard let box = measure(layer, at: middle) else { return nil }
        if box.height <= paneHeight { fits = middle } else { overflows = middle }
      }
      return fits
    }

    /// Scale a stable printed layout. CSS zoom recalculates font metrics and
    /// intrinsic widths, changing the page height and paired fit mid-gesture.
    private func applyPageScale(
      _ layer: DOM.Element, in pane: DOM.Element,
      about anchor: (x: Double, y: Double)?, matching: Bool
    ) {
      guard let oldBox = layer.getBoundingClientRect(), let paneBox = pane.getBoundingClientRect(),
        let parent = layer.parentElement else { return }
      let previous = currentZoom()
      let oldScroll = (x: pane.scrollLeft, y: pane.scrollTop)
      let point = anchor.map { ((paneBox.x + $0.x - oldBox.x) / previous, (paneBox.y + $0.y - oldBox.y) / previous) }
      let existing = stringEquals(parent.getAttribute(data("page-scale")) ?? "", "true")
      let margin = existing ? pixels(parent.style.getPropertyValue("margin-inline-start"))
        : pixels(layer.style.getPropertyValue("margin-inline-start")) * previous
      let insetX = max(0, oldBox.x - paneBox.x + oldScroll.x - margin)
      let insetY = max(0, oldBox.y - paneBox.y + oldScroll.y)
      let style = window.getComputedStyle(pane)
      let borderX = pixels(style.getPropertyValue("border-left-width")) + pixels(style.getPropertyValue("border-right-width"))
      let borderY = pixels(style.getPropertyValue("border-top-width")) + pixels(style.getPropertyValue("border-bottom-width"))
      let paneWidth = paneBox.width - borderX - 2 * insetX
      let paneHeight = paneBox.height - borderY - 2 * insetY
      guard paneWidth > 0, paneHeight > 0 else { return }
      let frame: DOM.Element
      if existing {
        frame = parent
      } else {
        frame = document.createElement(.div)
        frame.setAttribute(data("page-scale"), "true")
        frame.style.setProperty("position", "relative")
        frame.style.setProperty("flex-shrink", "0")
        frame.style.setProperty("overflow", "hidden")
        parent.insertBefore(frame, layer)
        frame.appendChild(layer)
      }
      let ratio = canvasIndex < imageWidths.count && canvasIndex < imageHeights.count
        && imageWidths[canvasIndex] > 0 && imageHeights[canvasIndex] > 0
        ? Double(imageWidths[canvasIndex]) / Double(imageHeights[canvasIndex]) : 0.75
      layer.style.setProperty("zoom", "1")
      layer.style.setProperty("position", "absolute")
      layer.style.setProperty("inset", "0 auto auto 0")
      layer.style.setProperty("margin-inline-start", "0")
      layer.style.setProperty("min-width", "640px")
      layer.style.setProperty("min-height", doubleToString(640 / ratio) + "px")
      layer.style.setProperty("transform-origin", "top left")
      layer.style.setProperty("transform", "none")
      guard let natural = layer.getBoundingClientRect(), natural.width > 0, natural.height > 0 else { return }
      let fit = containFit(width: natural.width, height: natural.height, paneWidth: paneWidth, paneHeight: paneHeight)
      let stored = storedZoom()
      let resting = anchor == nil && stored.atFit ? fit : max(fit, min(maxZoom(fit: fit), stored.zoom ?? ViewerZoom.actualSize))
      var zoom = overlayOn ? overlayZoomStart + (fit - overlayZoomStart) * overlayProgress
        : overlayLeaving ? overlayZoomStart + (resting - overlayZoomStart) * overlayProgress : resting
      let settled = !overlayOn && !overlayLeaving && abs(zoom - previous) * max(natural.width, natural.height) < 1
      if settled { zoom = previous }
      // On the way back the zoom kept is the one it returns to, never a step
      // of the motion.
      let chosen = !overlayLeaving && (stored.zoom != nil || stored.atFit)
      let atFit = chosen && zoom <= fit
      frame.style.setProperty("width", doubleToString(natural.width * zoom) + "px")
      frame.style.setProperty("height", doubleToString(natural.height * zoom) + "px")
      frame.style.setProperty("margin-inline-start", doubleToString(max(0, (pane.clientWidth - 2 * insetX - natural.width * zoom) / 2)) + "px")
      layer.style.setProperty("transform", "scale(" + doubleToString(zoom) + ")")
      layer.setAttribute(data("zoom"), doubleToString(zoom))
      lastFit = fit
      if chosen {
        setZoom(zoom, atFit: atFit)
        sessionStorage.setItem(Self.zoomKey + zoomKind, atFit ? "fit" : doubleToString(zoom))
      }
      if overlayOn {
        pane.scrollLeft = overlayScrollStart.x * (1 - overlayProgress)
        pane.scrollTop = overlayScrollStart.y * (1 - overlayProgress)
      } else if overlayLeaving {
        pane.scrollLeft = overlayScrollStart.x * overlayProgress
        pane.scrollTop = overlayScrollStart.y * overlayProgress
      } else if !settled, let anchor, let point, let newBox = layer.getBoundingClientRect() {
        pane.scrollLeft += newBox.x - paneBox.x + point.0 * zoom - anchor.x
        pane.scrollTop += newBox.y - paneBox.y + point.1 * zoom - anchor.y
        if !matching { matchImage() }
      } else {
        pane.scrollLeft = oldScroll.x
        pane.scrollTop = oldScroll.y
      }
      matchedScroll = (pane.scrollLeft, pane.scrollTop)
      registerOverlay()
    }

    /// Reflow returns to ordinary layout, with its own wrapping and CSS zoom.
    private func restoreFlow(of layer: DOM.Element) {
      guard let frame = layer.parentElement,
        stringEquals(frame.getAttribute(data("page-scale")) ?? "", "true"),
        let parent = frame.parentElement else { return }
      parent.insertBefore(layer, frame)
      parent.removeChild(frame)
      for property in ["position", "inset", "transform", "transform-origin"] {
        _ = layer.style.removeProperty(property)
      }
      layer.style.setProperty("zoom", layer.getAttribute(data("zoom")) ?? "1")
    }

    /// The shown layer at its zoom, clamped to its fit and its actual size,
    /// centered where smaller than the pane; `anchor` (a point of the pane)
    /// keeps the text under it in place. Nothing is clamped before the
    /// layer has a size: a page not yet drawn is left as it is.
    private func applyZoom(about anchor: (x: Double, y: Double)?, matching: Bool = false) {
      guard let pane = markupPane, let layer = shownLayer() else { return }
      if rawVisible {
        // Source code has one readable size on every page, independent of
        // scan proportions, rendered fit, and old session zoom settings.
        let left = pane.scrollLeft, top = pane.scrollTop
        layer.style.setProperty("zoom", "1")
        layer.setAttribute(data("zoom"), "1")
        if let code = layer.querySelector(".code-view") {
          code.style.setProperty("min-width", doubleToString(pane.clientWidth) + "px")
          code.style.setProperty("min-height", doubleToString(pane.clientHeight) + "px")
        }
        pane.scrollLeft = left
        pane.scrollTop = top
        matchedScroll = (pane.scrollLeft, pane.scrollTop)
        return
      }
      if layer.querySelector(".code-view") == nil && !reflowOn {
        applyPageScale(layer, in: pane, about: anchor, matching: matching)
        return
      }
      restoreFlow(of: layer)
      // Capture the point before measuring changes layout or clamps scroll.
      // It belongs to the layer, whose centering margin changes with zoom.
      guard let oldBox = layer.getBoundingClientRect(), let paneBox = pane.getBoundingClientRect() else { return }
      let previous = parseDouble(layer.getAttribute(data("zoom")) ?? "") ?? ViewerZoom.actualSize
      let oldScroll = (x: pane.scrollLeft, y: pane.scrollTop)
      let point = anchor.map { ((paneBox.x + $0.x - oldBox.x) / previous, (paneBox.y + $0.y - oldBox.y) / previous) }
      // The text's own box: without the code view's pane-filling minimum or
      // the page's centering margin.
      let codeView = layer.querySelector(".code-view")
      _ = codeView?.style.removeProperty("min-width")
      _ = codeView?.style.removeProperty("min-height")
      // A margin does not affect the measured width. Removing it briefly
      // shrinks the scroll range and loses the reader's previous position.
      let margin = pixels(layer.style.getPropertyValue("margin-inline-start")) * previous
      if codeView == nil && !reflowOn {
        // Center a stable page frame, not the width of its shortest text.
        // Canvas proportions describe the page only; no text coordinates.
        let ratio = canvasIndex < imageWidths.count && canvasIndex < imageHeights.count
          && imageWidths[canvasIndex] > 0 && imageHeights[canvasIndex] > 0
          ? Double(imageWidths[canvasIndex]) / Double(imageHeights[canvasIndex]) : 0.75
        let pageWidth = 640.0
        layer.style.setProperty("min-width", doubleToString(pageWidth) + "px")
        layer.style.setProperty("min-height", doubleToString(pageWidth / ratio) + "px")
      } else if codeView == nil {
        _ = layer.style.removeProperty("min-width")
        _ = layer.style.removeProperty("min-height")
        _ = layer.style.removeProperty("margin-inline-start")
      }
      guard let box = layer.getBoundingClientRect(), box.width > 0, box.height > 0
      else { return }
      // What stands around the layer in the pane (the view's 1px inset,
      // which keeps a ring clear), on both sides alike: where the layer
      // starts, less its centering margin.
      let insetX = max(0, box.x - paneBox.x + pane.scrollLeft - margin)
      let insetY = max(0, box.y - paneBox.y + pane.scrollTop)
      // The pane's size as if it had no scrollbars: the fit is the zoom at
      // which it needs none, and a size that changed as they came and went
      // would move the fit, the zoom with it, and the bars again.
      let style = window.getComputedStyle(pane)
      let borderX = pixels(style.getPropertyValue("border-left-width")) + pixels(style.getPropertyValue("border-right-width"))
      let borderY = pixels(style.getPropertyValue("border-top-width")) + pixels(style.getPropertyValue("border-bottom-width"))
      let paneWidth = paneBox.width - borderX - 2 * insetX
      let paneHeight = paneBox.height - borderY - 2 * insetY
      guard paneWidth > 0, paneHeight > 0 else { return }
      // The whole page's fit, never above its actual size: its lines as
      // drawn, or, reflowed, its height as it wraps.
      let fit: Double
      if codeView != nil {
        // The code zooms out no further than its page's rendered text can
        // (user, 2026-10-12), for the two to keep one scale: past that its
        // long lines scroll sideways.
        guard let rendered = renderedFit(of: layer, paneWidth: paneWidth, paneHeight: paneHeight) else { return }
        fit = rendered
      } else if reflowOn {
        guard let reflowed = reflowedFit(layer, paneHeight: paneHeight) else { return }
        fit = reflowed
      } else {
        fit = containFit(width: box.width / previous, height: box.height / previous, paneWidth: paneWidth, paneHeight: paneHeight)
      }
      let stored = storedZoom()
      // The reader's zoom, or at the fit, or, until the reader zooms, the
      // text's actual size.
      var zoom: Double
      if anchor == nil && stored.atFit {
        zoom = fit
      } else {
        zoom = max(fit, min(maxZoom(fit: fit), stored.zoom ?? ViewerZoom.actualSize))
      }
      // Settled: a change that would move the page by less than a pixel is
      // a measure's rounding (its fit, so its maximum, read again at a new
      // zoom), not a zoom; left as it is, so nothing redraws, frame after
      // frame, for nothing.
      // Zooming on against a limit is the same: the zoom does not move, and
      // neither does the text under the pointer.
      let settled = abs(zoom - previous) * max(box.width, box.height) / previous < 1
      if settled { zoom = previous }
      let held = settled ? nil : anchor
      // At the fit by the reader's choice alone (a zoom, a sync): a page
      // that opened enlarged to its fit leaves the next page to open at its
      // own size, never at a fit the reader did not ask for.
      let chosen = stored.zoom != nil || stored.atFit
      let atFit = chosen && zoom <= fit
      layer.style.setProperty("zoom", doubleToString(zoom))
      layer.setAttribute(data("zoom"), doubleToString(zoom))
      // The page at least the pane's size, top-aligned: never a gap above
      // it to center.
      // The pane's room as it is, its scrollbars taken out, so the page
      // never makes one of its own.
      let roomWidth = pane.clientWidth - 2 * insetX
      let roomHeight = pane.clientHeight - 2 * insetY
      if let page = layer.closest(".tei-page") {
        page.style.setProperty("min-width", doubleToString(roomWidth) + "px")
        page.style.setProperty("min-height", doubleToString(roomHeight) + "px")
      }
      if let codeView {
        // The code fills the pane at every zoom, its gutter and ground with
        // it, as an editor's do, its text at its start (user, 2026-10-12):
        // the pane's size in the code's own, zoomed, units.
        codeView.style.setProperty("min-width", doubleToString(roomWidth / zoom) + "px")
        codeView.style.setProperty("min-height", doubleToString(roomHeight / zoom) + "px")
      } else {
        // The rendered page centered across the pane where narrower, as the
        // image is, for the two to be laid side by side; its lines keep
        // their own alignment, and wider, it scrolls with no gap. A zoomed
        // element's margin is zoomed too: set unzoomed.
        let width = box.width / previous * zoom
        layer.style.setProperty(
          "margin-inline-start", doubleToString(max(0, (roomWidth - width) / 2) / zoom) + "px")
      }
      lastFit = fit
      if chosen {
        setZoom(zoom, atFit: atFit)
        sessionStorage.setItem(Self.zoomKey + zoomKind, atFit ? "fit" : doubleToString(zoom))
      }
      if let anchor = held, let point {
        if let newBox = layer.getBoundingClientRect() {
          pane.scrollLeft += newBox.x - paneBox.x + point.0 * zoom - anchor.x
          pane.scrollTop += newBox.y - paneBox.y + point.1 * zoom - anchor.y
        }
        // The reader zoomed the text: the image follows (pane sync).
        if !matching { matchImage() }
      } else {
        pane.scrollLeft = oldScroll.x
        pane.scrollTop = oldScroll.y
      }
      // Measurement and zoom can generate deferred scroll events too.
      // Only a subsequent reader scroll should start another sync.
      matchedScroll = (pane.scrollLeft, pane.scrollTop)
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
    /// hidden, and is asked for again with capped backoff
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
          plainImages = []
        }
        for page in manifest.pages {
          serviceIDs.append(page.serviceID)
          plainImages.append(page.image)
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

    /// A temporary failure never settles "no images": keep retrying with
    /// capped backoff while the viewer remains in the document.
    private func retryManifest(url: String) {
      guard isInDocument else { return }
      let delay = ArtifactManifest.retryDelay(after: manifestRetries)
      manifestRetries += 1
      _ = window.setTimeout(delay) { [self] in
        guard self.isInDocument else { return }
        self.loadManifest(url: url)
      }
    }

    /// Whether the pages are the markup's own: no manifest, or one that
    /// named none.
    private var manifestFailed = false

    /// No manifest: the pages are the markup's own, in its order. A
    /// windowed markup counts them all and knows the image of those drawn.
    private func pageMarkup() {
      manifestFailed = true
      if windowed {
        let count = parseInt(root.dataset["page-count"] ?? "") ?? 0
        var services: [String] = []
        for _ in 0..<max(count, 0) { services.append("") }
        for pane in markupPanes {
          let index = parseInt(pane.dataset["page-index"] ?? "") ?? -1
          if index >= 0, index < services.count { services[index] = pane.dataset["service-id"] ?? "" }
        }
        for service in services {
          serviceIDs.append(service)
          imageWidths.append(0)
          imageHeights.append(0)
          canvasLabels.append("")
        }
        open()
        return
      }
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
    /// the four either side fetched ahead. The rest fetch nothing until they
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
      canvas.show(width: imageWidths[idx], height: imageHeights[idx], image: idx < plainImages.count ? plainImages[idx] : "")
      // Synced, the text opens on the image's part of the page, at its
      // size, rather than at 100%.
      if syncs, let region = canvas.region { matchText(to: region) }
      drawRegion()
      // The four either side, nearest first: images are what a turn waits
      // for (user, 2026-10-11).
      for distance in 1...4 {
        for neighbor in [idx + distance, idx - distance]
        where neighbor >= 0 && neighbor < serviceIDs.count
          && (neighbor >= plainImages.count || stringIsEmpty(plainImages[neighbor])) {
          CanvasReader.preload(
            serviceID: serviceIDs[neighbor], width: imageWidths[neighbor], zoom: canvas.fittedZoom)
        }
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
      canvas.onRegion = { [self] region in self.matchText(to: region) }
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
        // A focused pane's arrows pan it, as its own keys do.
        if let target = e.target, let pane = target.closest(".artifact-markup, .canvas-viewport"), pane.id == target.id {
          return
        }
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
      // is right whenever the two sequences run together—each pane's own
      // place where the markup is windowed, which a pane not drawn yet
      // leaves with none active, for the host to fetch.
      if !matched {
        for (position, pane) in markupPanes.enumerated() {
          let place = windowed ? (parseInt(pane.dataset["page-index"] ?? "") ?? -1) : position
          pane.setAttribute(data("active"), place == index ? "true" : "false")
        }
      }
      // Whoever drew the markup may have work to do when it changes—syntax
      // coloring a page of markup, say, which is worth doing for the page on
      // screen and wasteful for the nine hundred behind it.
      root.dispatchEvent(CustomEvent(type: "artifact-canvas-change", detail: service))
      scheduleZoom()
    }

    private func navigate(_ delta: Int) {
      let next = canvasIndex + delta
      guard next >= 0, next < serviceIDs.count else { return }
      loadCanvas(next)
    }

  }
#endif
