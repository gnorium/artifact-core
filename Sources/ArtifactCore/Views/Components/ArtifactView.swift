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
    /// The document's header as code (a testament's `<teiHeader>`), where it
    /// has one; nil for none. Its own Header switch in the footer, after the
    /// code switch where there is one (user, 2026-10-21). The two share the
    /// markup's column as radio toggles: neither on, the rendering; XML on,
    /// the page's code; Header on, the header's code alone (no rendered
    /// side, no page's code, no diff), read-only on the code's gray,
    /// numbered from 1. Turning one on turns the other off; never stacked.
    /// The markup's own code never holds the header. Off by default and per
    /// viewer, the viewer wearing its state as `data-header`. It needs no
    /// markup: an object whose pages are images alone (a calibrated, not
    /// yet explicated testament) shows the header in that column beside
    /// them while the switch is on, and the images take the whole width
    /// while it is off.
    let documentHeader: String?
    /// What an object or edit did to the document's header (`added`,
    /// `changed`, `removed`), drawn as a ring on the Header switch and on
    /// the header pane; nil where unchanged.
    let headerRing: String?
    /// Switches the host adds to the footer, after the code switch (the
    /// testament's English switch, user 2026-10-18): the host draws them
    /// only where they apply. A switch that shows a layer of the markup
    /// has the class `artifact-english-toggle`, is off by default, and is
    /// the viewer's own, never the page's: each viewer is switched alone,
    /// and the viewer wears its state as `data-translated`.
    let footerSwitches: [DOM.Node]
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
    /// What the host shows under the markup pane, in its column (a page's
    /// diff, the markup's and not the image's: user 2026-10-15): beside the
    /// image when the two stand side by side, above it when they are
    /// stacked; one layout whether the reader is on the page or
    /// fullscreen, which only enlarges it. Empty, nothing is drawn.
    let underMarkup: [DOM.Node]
    /// What the host shows under the header pane, in its column, while the
    /// Header switch is on (the header's diff: user, 2026-10-26). Empty,
    /// nothing is drawn.
    let underHeader: [DOM.Node]
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
      header: String? = nil,
      headerRing: String? = nil,
      canvasSwitch: Bool = false,
      pageCount: Int? = nil,
      windowed: Bool = false,
      @HTMLBuilder markup: () -> [DOM.Node] = { [] },
      @HTMLBuilder canvas: () -> [DOM.Node] = { [] },
      @HTMLBuilder footerSwitches: () -> [DOM.Node] = { [] },
      @HTMLBuilder actions: () -> [DOM.Node] = { [] },
      @HTMLBuilder bar: () -> [DOM.Node] = { [] },
      @HTMLBuilder underMarkup: () -> [DOM.Node] = { [] },
      @HTMLBuilder underHeader: () -> [DOM.Node] = { [] }
    ) {
      self.manifestURL = manifestURL
      self.style = style
      self.startCanvas = startCanvas
      self.startService = startService
      self.rawSwitch = rawSwitch
      self.rawSwitchInfo = rawSwitchInfo
      self.documentHeader = header
      self.headerRing = headerRing
      self.canvasSwitch = canvasSwitch
      self.pageCount = pageCount.flatMap { $0 > 0 ? $0 : nil }
      self.windowed = windowed
      self.markup = markup()
      self.canvas = canvas()
      self.footerSwitches = footerSwitches()
      self.actions = actions()
      self.bar = bar()
      self.underMarkup = underMarkup()
      self.underHeader = underHeader()
    }

    /// Whether the header shows the page-images switch: only when there are
    /// page images to show. Drawn hidden: the reader shows it once the
    /// manifest confirms an image (`data-canvas-confirmed`).
    private var switchesCanvas: Bool { canvasSwitch && !canvas.isEmpty && !markup.isEmpty }

    /// Whether the viewer offers the Header switch and draws the header
    /// pane: when the document has a header now, or had one before that an
    /// object or edit removed (`headerRing`, `underHeader`; user, 2026-10-26).
    private var hasHeader: Bool {
      documentHeader != nil || !(headerRing ?? "").isEmpty || !underHeader.isEmpty
    }

    /// The header carries no title (user, 2026-10-09): on a biblio page
    /// the work is already the page's heading or its node's description,
    /// and a quote's reader is credited under it. It names the page
    /// on screen at its start (user, 2026-10-10: the canvas label moved
    /// up from the footer, Raw down to the footer's start, so Raw sits at
    /// the bottom left of every box), and the host's controls take its
    /// end.

    public func build() -> DOM.Node {
      // An image the reader draws itself, for an image the slot lacks, is
      // styled by the image's own sheet, which the page must link.
      _ = ImageView(serviceID: "").build()

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
                // Drawn as the footer's switches are (user, 2026-10-20):
                // subtle, bordered, gray.
                ToggleButtonView(
                  label: "Image",
                  icon: IconView(
                    icon: { s in ImageIconView(size: s) }, size: ButtonView.ButtonSize.medium.iconSize),
                  modelValue: false,
                  weight: .subtle,
                  buttonColor: .gray,
                  iconOnly: true,
                  ariaLabel: "Image",
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
          if !markup.isEmpty || hasHeader {
            div {
              // The document's header, as code alone, under its switch
              // (user, 2026-10-21): a pane of its own that takes the column
              // while it shows, the markup's pane (its zoom, its scroll)
              // put away beside it, not redrawn.
              if hasHeader {
                div {
                  CodeView(documentHeader ?? "", showLineNumbers: false, lined: true)
                }
                .class("artifact-document-header")
                .role("region")
                .ariaLabel("Header")
                .data("ring", headerRing ?? "")
              }
              if !underHeader.isEmpty {
                div { underHeader }
                  .class("artifact-under-header")
              }
              if !markup.isEmpty {
                // The pane in a box of its own, which a host's ring around
                // the pane is drawn on (gnorium-web `TestamentView`), clear
                // of what stands under it.
                div {
                  div { markup }
                    .id("artifact-markup")
                    .class("artifact-markup")
                }
                .class("artifact-markup-box")
              }
              if !underMarkup.isEmpty {
                div { underMarkup }
                  .class("artifact-under-markup")
              }
            }
            .class("artifact-markup-frame")
            // The header alone, no markup yet: the column is the header's,
            // drawn only while it shows.
            .data("header-only", markup.isEmpty)
            // A sheet opened from the text (a gloss) covers the pane's box
            // from its frame, which neither scrolls nor zooms: in the pane
            // it sat at the pane's scroll, so a pane scrolled sideways (a
            // zoomed page) cut it off at its left (user, 2026-10-14).
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
            .data("sheet-host", true)
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
            }
            // The document's header, after the code switch where there is
            // one, the two exclusive (user, 2026-10-21): offered wherever
            // there is a header (or one an object or edit removed: user,
            // 2026-10-26), with no markup too.
            if hasHeader {
              let toggle = HeaderToggleButtonView(class: "artifact-header-toggle").build()
              if let headerRing, !headerRing.isEmpty, let element = toggle as? DOM.Element {
                element.addingAttribute("data-ring", headerRing)
              } else {
                toggle
              }
            }
            if rawSwitch, !markup.isEmpty {
              // The English layer of a non-English page, the viewer's own.
              footerSwitches
              // Both layers' lines (user, 2026-10-12). Off: the rendered
              // page's lines as the scan breaks them (each `<lb/>` a line)
              // and the code's as stored, never wrapped, scrolling
              // sideways. On: the page's lines run on as paragraphs, the
              // code wrapped as plain text.
              ToggleButtonView(
                label: "Reflow",
                icon: IconView(icon: { s in TextWrapIconView(size: s) }, size: ButtonView.ButtonSize.medium.iconSize),
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
              // page whose text is not yet the scan's. Disabled where it
              // cannot apply (Raw, Reflow, the images put away), its state
              // kept underneath; disabled and off while the overlay is on,
              // which holds both panes still (user, 2026-10-14).
              if switchesCanvas {
                ToggleButtonView(
                  label: "Detach",
                  icon: IconView(icon: { s in RefreshClockwiseOffIconView(size: s) }, size: ButtonView.ButtonSize.medium.iconSize),
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
                  icon: IconView(icon: { s in LayersIconView(size: s) }, size: ButtonView.ButtonSize.medium.iconSize),
                  modelValue: false, weight: .subtle, buttonColor: .gray,
                  iconOnly: true, ariaLabel: "Overlay", size: .medium,
                  class: "artifact-overlay-toggle"
                )
              }
              if let info = rawSwitchInfo {
                // An icon on its own, on par with the row's text, as tall
                // as its 22px line, as the bars' other icons (user,
                // 2026-10-21).
                TooltipView(tooltip: info, class: "artifact-raw-info") {
                  IconView(icon: { size in [InfoIconView(size: size)] }, size: lineHeightSmall22)
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
              icon: { size in [MaximizeIconView(size: size)] }, size: lineHeightSmall22,
              class: "artifact-fullscreen-enter")
            IconView(
              icon: { size in [MinimizeIconView(size: size)] }, size: lineHeightSmall22,
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
      // The Header switch's state, off at first (`header`).
      .data("header", false)
      // The English switch's state, which a host's rules within the viewer
      // follow; a viewer with no switch leaves the page's to its ancestors.
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
        selector("& .artifact-page-nav", "& .artifact-xml-toggle", "& .artifact-header-toggle", "& .artifact-english-toggle", "& .artifact-reflow-toggle", "& .artifact-detach-toggle", "& .artifact-overlay-toggle") {
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
          // The pane, then what the host shows under it (`underMarkup`).
          display(.flex)
          flexDirection(.column)
        }
        // Its 1px edge is always there, transparent until the pane is ringed
        // (the host colors it): ringed or not, the text stands in the same
        // place, under the header's label.
        descendant(".artifact-markup-box") {
          position(.relative)
          border(borderWidthBase, .solid, borderColorTransparent)
          display(.flex)
          flexDirection(.column)
          flex("1 1 auto")
          minHeight(0)
          minWidth(0)
        }
        descendant(".artifact-markup-box > .artifact-markup") {
          width(perc(100))
          flex("1 1 auto")
          minHeight(0)
        }
        // Under the markup pane, in its column, a zone as the pane is: one
        // scrollport, both ways, at the pane's level (user, 2026-10-15);
        // what it holds never scrolls within it. The pane keeps the rest of
        // the column.
        descendant(".artifact-under-markup") {
          flexShrink(0)
          minWidth(0)
          maxHeight(perc(40))
          overflow(.auto)
        }
        // The document's header, under its switch (user, 2026-10-21): code,
        // read-only on the code's own gray, the whole column while it is on,
        // a zone that scrolls both ways. It and the XML switch share the
        // column as radio toggles do: the header on puts the markup's pane
        // (and what stands under it, a page's diff) away, never stacked
        // with the page's code.
        descendant(".artifact-document-header") {
          display(.none)
          border(borderWidthBase, .solid, borderColorTransparent)
        }
        descendant(".artifact-under-header") {
          display(.none)
        }
        for (state, color) in [("added", borderColorGreen), ("removed", borderColorRed), ("changed", borderColorOrange)] {
          selector("& .artifact-document-header[data-ring='\(state)']") {
            border(borderWidthBase, .solid, color)
            outline(borderWidthBase, .solid, color)
            CSS.Property("outline-offset", "calc(-2 * \(borderWidthBase.value))")
          }
          // The switch wears the ring only while the header is put away;
          // shown, the pane wears it (user, 2026-10-26).
          selector("&:not([data-header='true']) .artifact-header-toggle[data-ring='\(state)'] > .button-view") {
            borderColor(color).important()
            outline(borderWidthBase, .solid, color).important()
            outlineOffset(px(0)).important()
          }
        }
        selector("&[data-header='true'] .artifact-document-header") {
          display(.flex)
          flexDirection(.column)
          flex("1 1 auto")
          minWidth(0)
          minHeight(0)
          overflow(.auto)
          backgroundColor(backgroundColorNeutralSubtle)
        }
        // A diff under the header pane splits the column evenly with it, as a
        // page's diff splits the column with the markup pane (user, 2026-10-26).
        selector("&[data-header='true']:has(.artifact-under-header) .artifact-document-header") {
          flex("1 1 0")
        }
        selector(
          "&[data-header='true']:not([data-overlay-active='true']):not([data-overlay-registered='true']) .artifact-under-header"
        ) {
          display(.flex)
          flexDirection(.column)
          flex("1 1 0")
          minWidth(0)
          minHeight(0)
          overflow(.auto)
        }
        selector(
          "&[data-header='true']:not([data-overlay-active='true']):not([data-overlay-registered='true']) .artifact-markup-box",
          "&[data-header='true']:not([data-overlay-active='true']):not([data-overlay-registered='true']) .artifact-under-markup"
        ) {
          display(.none).important()
        }
        // The zone scrolls, never the code within it: its lines as wide as
        // the longest, on the gray the whole way.
        descendant(".artifact-document-header .code-view") {
          flex("1 0 auto")
          minWidth(perc(100))
          width(.maxContent)
          maxWidth(.none)
          overflow(.visible)
          borderRadius(0)
        }
        // Reflowed, its long lines wrap as the markup's code's do.
        selector("&[data-reflow='true'] .artifact-document-header .code-view") {
          width(perc(100)).important()
        }
        // Switched off with no markup, the column goes and the images take
        // the whole viewer, as an object's with no markup do.
        selector("&[data-header='false'] .artifact-markup-frame[data-header-only='true']") {
          display(.none).important()
        }
        selector("&[data-header='false']:has(.artifact-markup-frame[data-header-only='true']) .artifact-object") {
          CSS.Property("inset-inline-start", "0").important()
          CSS.Property("inset-block-start", "0").important()
          width(perc(100)).important()
          height(perc(100)).important()
        }
        // The overlay lays the markup's pane on the image: the header is
        // put away while it holds them.
        selector("&[data-overlay-active='true'] .artifact-document-header", "&[data-overlay-registered='true'] .artifact-document-header") {
          display(.none).important()
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
        // The rendered page takes the pane's cursor (the hand where a drag
        // pans, the I-beam over its text), whatever its view sets for itself
        // (an editable reader's, a Revise page's, sets the arrow, user,
        // 2026-10-14); a word with a gloss keeps its own.
        selector("& .artifact-markup [data-layer='rendering']", "& .artifact-markup [data-layer='translated-rendering']") {
          CSS.Property("cursor", "inherit").important()
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
        // Reflowed, it is a text pane that scrolls (user, 2026-10-14): the
        // browser's own cursor, the I-beam over its text; nothing pans.
        // So is its code (user, 2026-10-15): XML on, the browser's own
        // cursor, the I-beam over the code, the arrow elsewhere; nothing
        // pans. `data-raw` is the hydrated state (`showLayers`), never a
        // `:has()` the browser may not reevaluate.
        selector("&[data-reflow='true'] .artifact-markup", "&[data-raw='true'] .artifact-markup") {
          cursor(.auto)
        }
        // The same two positioned frames interpolate into an overlay,
        // rather than switching layout models halfway through the reveal.
        selector("&[data-canvas-shown='true']:has(.artifact-markup-frame) .artifact-markup-frame", "&[data-canvas-shown='true']:has(.artifact-markup-frame) .artifact-object") {
          position(.absolute)
          CSS.Property("inset-block-start", "0")
          CSS.Property("inset-inline-start", "0")
          width(perc(50))
          height(perc(100))
          // On the overlay's one clock and curve (`OverlayMotion`).
          CSS.Property("transition", Self.overlayTransition)
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
        }
        selector("&[data-overlay-active='true'] .artifact-markup") {
          overflow(.hidden).important()
        }
        // The overlay draws structure, never the scan's pixels (user,
        // 2026-10-14): from overlay on until off has run, the text on no
        // ground of its own, the scan fading out under it and back on the
        // overlay's one clock (`--artifact-overlay-progress`), gone at rest.
        selector("&[data-overlay-fading='true'] .artifact-markup") {
          backgroundColor(.transparent).important()
        }
        selector("&[data-overlay-fading='true'] .artifact-object") {
          CSS.Property("opacity", "calc(1 - var(--artifact-overlay-progress, 0))")
        }
        selector("&[data-overlay-active='true'] .image-viewport") { CSS.Property("touch-action", "none") }
        selector("& .artifact-detach-toggle[aria-pressed='true'] .button-view:disabled") {
          backgroundColor(backgroundColorBlue).important()
          borderColor(backgroundColorBlue).important()
          CSS.Property("opacity", "0.5")
        }
        selector("& .artifact-detach-toggle[aria-pressed='true'] .button-view:disabled .button-icon", "& .artifact-detach-toggle[aria-pressed='true'] .button-view:disabled .button-label") {
          color(colorOnSolid).important()
        }
        // A page whose main text block was measured on its scan (user,
        // 2026-10-14), from overlay on until overlay off has run: the
        // edition's page on top, never scrolled (its zoom and pan the
        // overlay's own), the scan's structure drawn over it
        // (`.artifact-structure`).
        selector("&[data-overlay-registered='true'] .artifact-markup-frame") {
          zIndex(1)
        }
        selector("&[data-overlay-registered='true'] .artifact-markup") {
          overflow(.hidden).important()
          CSS.Property("touch-action", "none")
        }
        // The structure overlay's scene (`drawStructure`), in the layer's
        // own pixels: the edition's outlines solid, the scan's dashed, a
        // stroke the screen's width whatever the zoom; quiet within the
        // tolerance, the diff's colors past it—orange a pair off, green an
        // edition line the scan lacks, red a scan line the edition lacks.
        descendant(".artifact-structure") {
          // Fading in as the scan fades out, on the same clock.
          CSS.Property("opacity", "var(--artifact-overlay-progress, 1)")
          position(.absolute)
          CSS.Property("left", "0")
          CSS.Property("top", "0")
          width(0)
          height(0)
          overflow(.visible)
          pointerEvents(.none)
        }
        descendant(".artifact-structure svg") {
          position(.absolute)
          CSS.Property("left", "0")
          CSS.Property("top", "0")
          width(px(1))
          height(px(1))
          overflow(.visible)
        }
        selector("& .artifact-structure rect", "& .artifact-structure polygon") {
          CSS.Property("fill", "none")
          CSS.Property("stroke", borderColorSubtle.value)
          CSS.Property("stroke-width", borderWidthBase.value)
          CSS.Property("vector-effect", "non-scaling-stroke")
        }
        descendant(".artifact-structure [data-side='scan']") {
          CSS.Property("stroke-dasharray", spacing4.value + " " + spacing4.value)
        }
        selector("& .artifact-structure [data-state='off']", "& .artifact-structure [data-state='extra']", "& .artifact-structure [data-state='missing']") {
          CSS.Property("stroke-width", "calc(2 * " + borderWidthBase.value + ")")
        }
        descendant(".artifact-structure [data-state='off']") { CSS.Property("stroke", colorOrange.value) }
        descendant(".artifact-structure [data-state='extra']") { CSS.Property("stroke", colorGreen.value) }
        descendant(".artifact-structure [data-state='missing']") { CSS.Property("stroke", colorRed.value) }
        // The edition's word the scan's under the pointer is (user,
        // 2026-10-14), as the scan's band marks it: the band's yellow at its
        // opacity (user, 2026-10-18), a pair.
        descendant(".artifact-markup .tei-word[data-corresponding='true']") {
          CSS.Property("background-color", "color-mix(in srgb, " + colorYellow.value + " calc(" + opacityLow.value + " * 100%), transparent)")
        }
        // Hugging the word: the fill drawn as one band at the glyphs'
        // extent (`band`), the span's own box left clear.
        descendant(".artifact-markup .tei-word[data-corresponding='true'][data-band='true']") {
          backgroundColor(.transparent)
          CSS.Property(
            "background-image",
            "linear-gradient(" + "color-mix(in srgb, " + colorYellow.value + " calc(" + opacityLow.value + " * 100%), transparent)" + ", " + "color-mix(in srgb, " + colorYellow.value + " calc(" + opacityLow.value + " * 100%), transparent)" + ")")
          CSS.Property("background-repeat", "no-repeat")
          CSS.Property("background-size", "var(--artifact-band-width) var(--artifact-band-height)")
          CSS.Property("background-position", "var(--artifact-band-x) var(--artifact-band-y)")
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
        // TEI view's 1px ring padding inside the box's 1px edge (ringed or
        // not), less the row's 8.
        descendant(".artifact-canvas-label") {
          fontSize(fontSizeMedium16)
          color(colorBase)
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
          color(colorBase)
          cursor(.pointer)
          flexShrink(0)
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
          // medium button; its icon stays on the 22px line, as theirs does.
          selector("\(ButtonView.phoneStep) & .artifact-fullscreen-button") {
            width(ButtonView.smallMinSize).important()
            height(ButtonView.smallMinSize).important()
          }
        }
      }
    }
  }

  extension ArtifactView {
    /// The panes' move into the overlay and out of it.
    static let overlayTransition = ["width", "height", "inset-inline-start", "inset-block-start"]
      .map { $0 + " " + OverlayMotion.timing }.joined(separator: ", ")
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
  import WebComponents

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
    /// Each canvas's plain images in place of its service, tried in order,
    /// where it has them (`ArtifactManifest.Page.images`): by the manifest's
    /// place.
    private var plainImages: [[String]] = []
    /// Whether each canvas's service may stand in where none of its plain
    /// images loads (`ArtifactManifest.Page.live`): by the manifest's place.
    private var liveImages: [Bool] = []
    /// Whether each canvas is shown with no image (`ArtifactManifest.Page
    /// .blank`): by the manifest's place.
    private var blankPages: [Bool] = []
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
    private var canvases: [ImageView] = []
    private var shownCanvas: ImageView?
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
      setupHeaderSwitch()
      setupReflowSwitch()
      setupSyncSwitch()
      setupZoom()
      setupCanvasSwitch()
      setupOverlay()
      setupCorrespondence()
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
        if self.syncs, let region = self.shownCanvas?.region {
          self.applyMatchText(region)
        }
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
        // The XML and the header share the column (user, 2026-10-21): the
        // XML on turns the header off, by its own switch's press, so every
        // listener hears it.
        if self.rawVisible, self.headerVisible {
          self.root.querySelector(".artifact-header-toggle button")?.click()
        }
      }
      _ = root.addEventListener("markup-translated") { [self] (event: Event) in
        self.translationVisible = stringEquals(event.detail, "true")
        self.showLayers()
      }
      // A viewer with an English switch of its own is switched by it alone
      // (user, 2026-10-18): off at first, whatever the page around it says,
      // and told to the host as the page's switch tells it.
      if let english = root.querySelector(".artifact-english-toggle") {
        translationVisible = stringEquals(english.getAttribute("aria-pressed") ?? "false", "true")
        root.setAttribute(data("translated"), translationVisible ? "true" : "false")
        showLayers()
        _ = english.addEventListener("toggle-button-update") { [self] (event: Event) in
          let state = stringEquals(event.detail, "true") ? "true" : "false"
          self.root.setAttribute(data("translated"), state)
          self.root.dispatchEvent(CustomEvent(type: "markup-translated", detail: state))
        }
      }
    }

    /// The Header switch (user, 2026-10-21): the document's header, as
    /// code, alone in the markup's column while it is on (`data-header`);
    /// off at first. It and the XML switch are exclusive, radio toggles
    /// sharing the column: the header on turns the XML off.
    private func setupHeaderSwitch() {
      guard let toggle = root.querySelector(".artifact-header-toggle") else { return }
      setHeader(stringEquals(toggle.getAttribute("aria-pressed") ?? "false", "true"))
      _ = toggle.addEventListener("toggle-button-update") { [self] (event: Event) in
        self.setHeader(stringEquals(event.detail, "true"))
      }
    }

    /// Whether the header holds the markup's column (`data-header`).
    private var headerVisible = false

    private func setHeader(_ on: Bool) {
      guard let toggle = root.querySelector(".artifact-header-toggle") else { return }
      headerVisible = on
      root.setAttribute(data("header"), on ? "true" : "false")
      toggle.setAttribute("aria-pressed", on ? "true" : "false")
      toggle.querySelector("button")?.setAttribute("aria-pressed", on ? "true" : "false")
      // The XML off by its own switch's press, so every listener (a host's
      // diff zone) hears it.
      if on, rawVisible {
        root.querySelector(".artifact-xml-toggle button")?.click()
      }
      // The markup's pane put away takes the overlay and the sync with it,
      // as the XML does.
      reflectSyncApplies()
      // With no markup its column comes and goes beside the images: the
      // image on screen fitted to the room it has now.
      if case .none = markupPane { shownCanvas?.refit() }
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
    /// The region whose value the drag writes (a bbox's or a zone's corners).
    private var dragRegion: MarkupRegion?
    private var selectionListener: Int32 = -1

    /// The code of the page on screen, under Raw: its editor, or its
    /// read-only blocks (the page's and its translation's).
    private static let rawCode = ".artifact-markup .tei-page[data-active='true'] .tei-page-raw .code-code"

    private func setupRegions() {
      // Once a frame at most (user, 2026-10-15): typing fires an input and
      // a selection change a key, and each read the whole page's code.
      selectionListener = document.addEventListener("selectionchange") { [self] _ in self.followCaretSoon() }
      // Typing moves the caret, and changes what it is on even where it
      // stays.
      _ = root.addEventListener(.input) { [self] _ in self.followCaretSoon() }
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

    private var caretFollowing = false

    private func followCaretSoon() {
      guard !caretFollowing else { return }
      caretFollowing = true
      _ = window.requestAnimationFrame { [self] in
        self.caretFollowing = false
        self.followCaret()
      }
    }

    /// Whether a region named in `code` can be drawn: the scan shown.
    /// Otherwise the code is not read for one—a whole page's text at every
    /// key and every move of the pointer (user, 2026-10-15).
    private func drawsRegions(of code: DOM.Element) -> Bool {
      imagesShown
    }

    private func followCaret() {
      // A drag writes the value as it goes; the drag is what it says.
      if case .some = dragNode { return }
      guard let selection = window.getSelection(), let node = selection.focusNode else {
        setRegion(caret: nil, editor: nil)
        return
      }
      for code in root.querySelectorAll(Self.rawCode) where code.contains(node) {
        guard drawsRegions(of: code) else {
          setRegion(caret: nil, editor: code.hasAttribute("data-code-editing") ? code : nil)
          return
        }
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
        guard drawsRegions(of: code) else { break }
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
          canvas.editRegion(
            x: region.x, y: region.y, width: region.width, height: region.height, vertices: region.points)
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
      // A bbox's value, a zone's four corners, or a polygon's points scaled
      // with its box (`MarkupRegion.writing`).
      dragged(done: done) { $0.writing(x: x, y: y, width: width, height: height) }
    }

    /// A polygon zone's vertex dragged on the canvas: the points value
    /// with that vertex moved, written as a box's drag is.
    private func vertexEdited(_ index: Int, x: Int, y: Int, done: Bool) {
      dragged(done: done) { $0.writing(vertex: index, toX: x, y: y) }
    }

    private func dragged(done: Bool, value make: (MarkupRegion) -> String) {
      if case .none = dragNode {
        guard let edited = editedValue() else { return }
        dragNode = edited.node
        dragStart = edited.start
        dragLength = edited.length
        dragOriginal = edited.value
        dragRegion = edited.region
      }
      guard let region = dragRegion else { return }
      let value = make(region)
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
      write(
        edited.region.writing(x: box.x, y: box.y, width: box.width, height: box.height), node: edited.node,
        start: edited.start, length: edited.length)
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
      // The images put away take the overlay with them, as its own switch
      // does (user, 2026-10-18): the overlay lays the text on the scan, and
      // with no scan the pane is the text's own again. Back on, the overlay
      // comes back as it was.
      if !shown, overlayOn {
        overlayBeforeImagesOff = true
        pressOverlay(false)
        setOverlay(false)
      }
      canvasShown = shown
      reflectCanvasShown()
      if shown {
        if canvasIndex < serviceIDs.count { showCanvas(canvasIndex) }
        if overlayBeforeImagesOff {
          overlayBeforeImagesOff = false
          if overlayApplies && !rawVisible && !reflowOn {
            pressOverlay(true)
            setOverlay(true)
          }
        }
      } else {
        shownCanvas?.hide()
        shownCanvas = nil
      }
    }

    /// Whether the overlay was on when the images were put away: turned
    /// back on with them (`setCanvasShown`).
    private var overlayBeforeImagesOff = false

    /// The overlay's switch shown as `on`, as the reader sets the overlay
    /// itself (`setCanvasShown`, `reflectPageMarkup`), never by a press.
    private func pressOverlay(_ on: Bool) {
      guard let toggle = root.querySelector(".artifact-overlay-toggle") else { return }
      toggle.setAttribute("aria-pressed", on ? "true" : "false")
      toggle.querySelector("button")?.setAttribute("aria-pressed", on ? "true" : "false")
    }

    /// Whether the page on screen has an image to show: none on a page
    /// shown with no image (`isBlank`: changed at its source with no copy of
    /// what was sent kept, or every copy failed to load; user, 2026-10-17).
    private var pageHasImage: Bool { !isBlank(canvasIndex) }

    /// Whether the page images are on screen: the person's switch on
    /// (`canvasShown`, kept as they left it) and an image to show. A page
    /// with none shows its text alone, as with the images off, only while it
    /// is on screen: the next page with one shows it as the switch says
    /// (user, 2026-10-17).
    private var imagesShown: Bool { canvasShown && pageHasImage }

    /// The viewer's column and the switch, as the state is: the switch's
    /// wrapper (which its styles read) and its button (which assistive
    /// technology reads). On a page with no image to show the switch reads
    /// off and is disabled, never hidden, its label kept: the images come
    /// back on a page that has one, the person's choice kept underneath
    /// (user, 2026-10-17).
    private func reflectCanvasShown() {
      reflectSyncApplies()
      let shown = imagesShown
      root.setAttribute(data("canvas-shown"), shown ? "true" : "false")
      canvasToggle?.setAttribute("aria-pressed", shown ? "true" : "false")
      guard let button = canvasToggle?.querySelector("button") else { return }
      button.setAttribute("aria-pressed", shown ? "true" : "false")
      if pageHasImage {
        button.removeAttribute("disabled")
        button.removeAttribute("aria-disabled")
      } else {
        button.setAttribute("disabled", "")
        button.setAttribute("aria-disabled", "true")
      }
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
    /// Reflow, the images put away—so it says it can come back, its state
    /// kept underneath; disabled and off while the overlay is on, where
    /// nothing pans or zooms to sync or not (user, 2026-10-14).
    private func reflectSyncApplies() {
      let active = overlayOn && !codeShown && !reflowOn && imagesShown
      root.setAttribute(data("overlay-active"), active ? "true" : "false")
      // The overlay's switch disabled, as Detach's is, where it cannot
      // apply: Raw, Reflow, the images put away, a page with no markup or
      // no image (`overlayApplies`, user, 2026-10-17).
      if let button = root.querySelector(".artifact-overlay-toggle button") {
        if codeShown || reflowOn || !imagesShown || !overlayApplies {
          button.setAttribute("disabled", "")
          button.setAttribute("aria-disabled", "true")
        } else {
          button.removeAttribute("disabled")
          button.removeAttribute("aria-disabled")
        }
      }
      let detached = !overlayOn && !syncOn
      detachToggle?.setAttribute("aria-pressed", detached ? "true" : "false")
      detachToggle?.querySelector("button")?.setAttribute("aria-pressed", detached ? "true" : "false")
      guard let button = detachToggle?.querySelector("button") else { return }
      if codeShown || reflowOn || !imagesShown || overlayOn {
        button.setAttribute("disabled", "")
        button.setAttribute("aria-disabled", "true")
      } else {
        button.removeAttribute("disabled")
        button.removeAttribute("aria-disabled")
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
      // A text pane's own cursor, never the pan's (`setupZoom`).
      if on {
        markupPane?.removeAttribute(data("over-text"))
        endPan()
        panStart = nil
      }
      toggle.setAttribute("aria-pressed", on ? "true" : "false")
      toggle.querySelector("button")?.setAttribute("aria-pressed", on ? "true" : "false")
      // A framed page's grid is Reflow off's alone.
      showLayers()
    }

    private var rawVisible = false
    /// The markup's column holds code, the page's (XML) or the header's:
    /// no rendering to overlay or sync.
    private var codeShown: Bool { rawVisible || headerVisible }
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
      // XML on or off, said on the reader (`data-raw`): its cursor, and the
      // page's diff under it (gnorium-web `TestamentView`), read it there
      // rather than by `:has()`, which Safari did not reevaluate as the
      // toggle was pressed (user, 2026-10-15).
      root.setAttribute(data("raw"), rawVisible ? "true" : "false")
      if rawVisible {
        markupPane?.removeAttribute(data("over-text"))
        endPan()
        panStart = nil
      }
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
            showLayer(element)
            element.closest("[data-page-scale='true']")?.style.display(.block)
          }
        }
      }
      applyZoom(about: nil)
      scheduleZoom()
    }

    /// A layer shown as its own rules lay it out: a framed page as its grid
    /// (`TEIView`: the frame, its marginalia around it, user 2026-10-14),
    /// unless reflowed; any other as a flex column. An inline flex on a
    /// framed page dropped its grid, and set a head note at its foot.
    private func showLayer(_ element: DOM.Element) {
      if !reflowOn, stringEquals(element.getAttribute(data("framed")) ?? "", "true") {
        element.style.display(.grid)
      } else {
        element.style.display(.flex)
      }
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
    /// Overlay turned off, the panes still on their way apart: the text
    /// and the scan slide into their own panes at the zoom the reader chose
    /// in the overlay (user, 2026-10-14), or the text to its own pane's fit
    /// where they never zoomed there (user, 2026-10-17).
    private var overlayLeaving = false
    /// The overlay's view at rest, where the reader zoomed and panned it
    /// (user, 2026-10-14): the text and the structure over it move as one; nil
    /// at its fit (`OverlayFraming.fitted`).
    private var overlayView: (zoom: Double, x: Double, y: Double)?
    /// Whether the reader has the overlay zoomed past its fit (user,
    /// 2026-10-17): its view theirs, kept as overlay off slides the panes
    /// apart; never zoomed, or zoomed back to its fit, the overlay keeps to
    /// its fit, and off returns the text to its own pane's (`overlayLeavesToFit`).
    private var overlayZoomed = false
    /// Overlay off from its fit: the text slides from the overlay's fit to
    /// its own pane's, in every layout, and is kept at its fit (user,
    /// 2026-10-17).
    private var overlayLeavesToFit = false
    /// The overlay's framing last placed: what the reader's zoom and pan
    /// are held to.
    private var lastFraming: OverlayFraming?
    /// The room the overlay frames the page in: the text pane's own room
    /// for its fit (`applyPageScale`), its inset from the pane's box and its
    /// size, so a page fitted in the overlay is fitted as its pane fits it,
    /// and the zoom overlay off keeps fits there exactly, never a scrollbar
    /// taller (the pane's whole client box did, its text's inset not kept).
    private var overlayRoom = (x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    /// Where the reader was looking when the overlay went off: a point of
    /// the page in its layer's own pixels and the zoom, which the text pane
    /// keeps at its middle as the panes slide apart.
    private var overlayFocus: (x: Double, y: Double, zoom: Double)?
    /// Whether the overlay lays the scan's structure over the text by the page's
    /// main text block (`overlayZone`), from overlay on until overlay off
    /// has run (user, 2026-10-14): the edition's page
    /// and the structure's reach framed (`OverlayFraming`), its zoom and place
    /// the overlay's own rather than the pane's zoom and scroll.
    private var overlayRegistered = false
    /// Where the layer was in the window, and its zoom, when the overlay's
    /// motion began: what the motion leaves from.
    private var overlayFrom: (zoom: Double, x: Double, y: Double)?
    /// The panes' size at the motion's last frame, to tell when they stop.
    private var overlayPanes = (0.0, 0.0)
    private func setupOverlay() {
      guard let toggle = root.querySelector(".artifact-overlay-toggle") else { return }
      _ = toggle.addEventListener("toggle-button-update") { [self] event in
        self.setOverlay(stringEquals(event.detail, "true"))
      }
      reflectSyncApplies()
    }

    /// Whether the page on screen has markup of its own (`TEIView`'s
    /// `data-has-markup`, `TEIRenderer.hasMarkup`): a page laid in blank,
    /// not yet explicated, renders nothing for the overlay to lay (user,
    /// 2026-10-17). A page not drawn yet is taken to have it until it is.
    private var pageHasMarkup: Bool {
      guard let page = root.querySelector(".artifact-markup .tei-page[data-active='true']") else { return true }
      return !stringEquals(page.getAttribute(data("has-markup")) ?? "true", "false")
    }

    /// Whether the overlay has anything to lay on the page on screen: markup
    /// of its own, and an image to compare it against (`pageHasImage`, the
    /// rule the images switch follows too; user, 2026-10-17).
    private var overlayApplies: Bool { pageHasMarkup && pageHasImage }

    /// The page on screen turned, or left with no image: on one the overlay
    /// does not apply to (`overlayApplies`) it goes off, its switch
    /// disabled; back on one it applies to, enabled. On a page with no image
    /// the text shows alone and the images switch is disabled; back on one
    /// with an image, the images show as the switch was left
    /// (`reflectCanvasShown`, user, 2026-10-17).
    private func reflectPageMarkup() {
      if overlayOn && !overlayApplies {
        pressOverlay(false)
        // Its image left as the page's turn showed it: the spot the overlay
        // came on at was the last page's.
        scanOwn = nil
        setOverlay(false)
      } else if overlayOn {
        overlayView = nil
        overlayZoomed = false
        setOverlayRegistered(overlayZone() != nil)
      }
      reflectCanvasShown()
    }

    /// The overlay on or off: by its switch, or off as the reader turns to
    /// a page with no markup of its own or no image (`reflectPageMarkup`,
    /// user, 2026-10-17).
    private func setOverlay(_ on: Bool) {
      // The word correspondence is side by side's alone. The structure is
      // measured here, the layer at rest, before the motion scales it.
      if on {
        self.markEdition([])
        _ = self.currentStructure()
      }
      if on && !self.overlayOn {
        self.overlayTarget = ("", [], false, 0)
        self.overlayView = nil
        self.overlayZoomed = false
        self.overlayLeavesToFit = false
        self.overlayFocus = nil
        self.overlayZoomStart = self.currentZoom()
        self.overlayScrollStart = (self.markupPane?.scrollLeft ?? 0, self.markupPane?.scrollTop ?? 0)
        self.overlayZoomBegan = window.performance.now()
        self.overlayLeaving = false
        self.beforeOverlay = self.storedZoom()
        if let _ = self.overlayZone() {
          // Laid by the page's text block, from what the text shows now,
          // the pane's zoom and scroll kept for the way back; the image
          // leaving from what it shows.
          self.scanOwn = self.shownCanvas?.spot
          self.overlayFrom = self.layerPlace()
          self.setOverlayRegistered(true)
        } else {
          // Without one, the text fits its whole page and the scan stays
          // as the reader left it.
          self.setZoom(nil, atFit: true)
        }
      } else if !on, let before = self.beforeOverlay {
        self.overlayZoomStart = self.currentZoom()
        self.overlayZoomBegan = window.performance.now()
        self.overlayLeaving = true
        if self.overlayRegistered {
          // The panes slide apart at the zoom the reader chose in the
          // overlay, each keeping the spot the reader was looking at
          // (user, 2026-10-14); never zoomed there, the text to its own
          // pane's fit (user, 2026-10-17).
          self.overlayLeavesToFit = !self.overlayZoomed
          self.overlayFrom = self.layerPlace()
          self.leaveOverlay()
        } else {
          self.setZoom(before.zoom, atFit: before.atFit)
        }
        self.beforeOverlay = nil
      }
      self.overlayOn = on
      self.reflectSyncApplies()
      self.scheduleZoom()
      self.overlayMotion += 1
      let ticket = self.overlayMotion
      self.overlayPanes = (-1, -1)
      @Sendable func frame() {
        guard self.overlayOn == on, self.overlayMotion == ticket, self.isInDocument else { return }
        self.applyZoom(about: nil)
        // Run until the motion has, and the panes' own move with it (its
        // CSS transition starts a frame later): its end is then exact.
        let box = self.root.querySelector(".artifact-object")?.getBoundingClientRect()
        let size = (box?.width ?? 0, box?.height ?? 0)
        let moving = size.0 != self.overlayPanes.0 || size.1 != self.overlayPanes.1
        self.overlayPanes = size
        if self.overlayProgress < 1 || moving {
          _ = window.requestAnimationFrame { frame() }
        } else if !on {
          // The panes apart at their normal sizes: the text at the
          // zoom it left with, the spot the reader was looking at in its
          // middle; the scan at the same spot and zoom, where the
          // registration's way out left it. Matching resumes from there.
          self.overlayLeaving = false
          let registered = self.overlayRegistered
          // The spot the pane's own layout can hold in its middle: the
          // scan is sent to it, so the two show one point.
          if registered, let focus = self.overlayFocus, let pane = self.markupPane, let layer = self.shownLayer(),
            let natural = self.naturalSize(of: layer)
          {
            // The view is the room's (`overlayRoom`); its middle the client box's.
            let view = self.leavingView(focus, natural: natural)
            let room = self.overlayRoom
            let middle = (
              x: (Double(pane.clientLeft) + Double(pane.clientWidth) / 2 - room.x - view.x) / focus.zoom,
              y: (Double(pane.clientTop) + Double(pane.clientHeight) / 2 - room.y - view.y) / focus.zoom
            )
            self.overlayFocus = (middle.x, middle.y, focus.zoom)
            if let spot = self.scanSpot(at: middle, zoom: focus.zoom) { self.scanOwn = spot }
          }
          // The image its own again, at the spot it came back to.
          self.shownCanvas?.endBlend()
          if registered, let own = self.scanOwn {
            self.shownCanvas?.showSpot(centerX: own.centerX, centerY: own.centerY, zoom: own.zoom)
          }
          self.scanOwn = nil
          self.overlayLeavesToFit = false
          self.setOverlayRegistered(false)
          self.applyZoom(about: nil)
          if registered, let pane = self.markupPane {
            if let focus = self.overlayFocus, let layer = self.shownLayer(), let box = layer.getBoundingClientRect(),
              let paneBox = pane.getBoundingClientRect()
            {
              let zoom = self.currentZoom()
              pane.scrollLeft += box.x - paneBox.x - Double(pane.clientLeft) + focus.x * zoom - Double(pane.clientWidth) / 2
              pane.scrollTop += box.y - paneBox.y - Double(pane.clientTop) + focus.y * zoom - Double(pane.clientHeight) / 2
            }
            self.matchedScroll = (pane.scrollLeft, pane.scrollTop)
            self.overlayFocus = nil
          } else if self.syncs {
            self.matchImage()
          }
        }
      }
      _ = window.requestAnimationFrame { frame() }
    }

    /// The overlay going off (user, 2026-10-14): the spot of the page at
    /// the middle of the view, and the zoom, which the text keeps as its
    /// pane slides back (`overlayFocus`); the scan sent to the same spot of
    /// its image at the zoom it is seen at (`CanvasReader.showSpot`),
    /// through the registration's homography taken back.
    private func leaveOverlay() {
      guard let pane = markupPane, let paneBox = pane.getBoundingClientRect(), let place = layerPlace(), place.zoom > 0
      else { return }
      let x = (paneBox.x + Double(pane.clientLeft) + Double(pane.clientWidth) / 2 - place.x) / place.zoom
      let y = (paneBox.y + Double(pane.clientTop) + Double(pane.clientHeight) / 2 - place.y) / place.zoom
      overlayFocus = (x, y, place.zoom)
      // From its fit, to the text pane's fit (`placeOverlay` follows it).
      setZoom(overlayLeavesToFit ? nil : place.zoom, atFit: overlayLeavesToFit)
      if let spot = scanSpot(at: (x, y), zoom: place.zoom) { scanOwn = spot }
    }

    /// The image's own view the overlay leaves from, coming on, and goes
    /// back to, going off (`CanvasReader.blend`).
    private var scanOwn: (centerX: Double, centerY: Double, zoom: Double)?

    /// The image moved with the overlay (user, 2026-10-14): between its own
    /// view (`scanOwn`) and where the overlay lays it, by the rendered text
    /// block, on the overlay's one clock and curve, as it fades.
    private func blendScan(_ layer: DOM.Element) {
      guard let canvas = shownCanvas, let own = scanOwn, overlayRegistered, overlayOn || overlayLeaving,
        let zone = overlayZone(), let measured = renderedTextBlock(in: layer)
      else { return }
      let box = shownImageSize.map {
        laid([measured[0], measured[1], measured[2], measured[5]], zone: zone, size: $0, unit: currentZoom())
      }
        ?? [measured[0], measured[1], measured[2], measured[5]]
      canvas.blend(own: own, zone: zone, target: box, progress: overlayOn ? overlayProgress : 1 - overlayProgress)
    }

    /// The image's spot under `spot` (the page's point, in the layer's own
    /// pixels) at the zoom the text is drawn at, through the registration's
    /// homography taken back: where the overlay off leaves it.
    private func scanSpot(at spot: (x: Double, y: Double), zoom: Double) -> (centerX: Double, centerY: Double, zoom: Double)? {
      guard let zone = overlayZone(), overlayTarget.box.count == 4, let size = shownImageSize else { return nil }
      let box = laid(overlayTarget.box, zone: zone, size: size)
      let target = [box[0], box[1], box[2], box[1], box[2], box[3], box[0], box[3]]
      let corners = (0..<8).map { zone[$0] / Self.zoneExtent * ($0 % 2 == 0 ? size.width : size.height) }
      guard let back = Homography(from: target, to: corners) else { return nil }
      let point = back.apply(x: spot.x, y: spot.y)
      let zoneSpan = ((corners[2] - corners[0]) * (corners[2] - corners[0]) + (corners[3] - corners[1]) * (corners[3] - corners[1])).squareRoot()
      guard zoneSpan > 0 else { return nil }
      return (point.x / size.width, point.y / size.height, zoom * (box[2] - box[0]) / zoneSpan)
    }

    /// Where registration lays the zone on the rendered main text block's
    /// box (`box`: left, top, right, bottom, in the layer's own pixels
    /// times `unit`), `OverlayRegistration.laid`'s rule: where the work's
    /// frame is declared, always at the type's scale—the rendered em
    /// (`overlayTarget.em`) over the work's em on the scan
    /// (`data-scan-em`)—never by the block's height, which is the edition's
    /// typesetting; with none declared, by the block.
    private func laid(_ box: [Double], zone: [Double], size: (width: Double, height: Double), unit: Double = 1) -> [Double] {
      let page = root.querySelector(".artifact-markup .tei-page[data-active='true']")
      let scanEm = OverlayRegistration.scanEm(page?.getAttribute(data("scan-em")) ?? "", width: size.width)
      let typeScale = scanEm > 0 && overlayTarget.em > 0 ? overlayTarget.em * unit / scanEm : 0
      return OverlayRegistration.laid(box, zone: zone, size: size, spans: overlayTarget.spans, typeScale: typeScale)
    }

    /// The shown layer's size unzoomed, its scale's frame's.
    private func naturalSize(of layer: DOM.Element) -> (width: Double, height: Double)? {
      let zoom = currentZoom()
      guard zoom > 0, let box = layer.getBoundingClientRect() else { return nil }
      return (box.width / zoom, box.height / zoom)
    }

    /// The shown canvas's image size in its pixels, nil until known.
    private var shownImageSize: (width: Double, height: Double)? {
      guard canvasIndex < imageWidths.count, canvasIndex < imageHeights.count, imageWidths[canvasIndex] > 0,
        imageHeights[canvasIndex] > 0
      else { return nil }
      return (Double(imageWidths[canvasIndex]), Double(imageHeights[canvasIndex]))
    }

    /// The space a zone's corners are in, over the whole image.
    private static let zoneExtent = 1000.0

    private func setOverlayRegistered(_ registered: Bool) {
      overlayRegistered = registered
      root.setAttribute(data("overlay-registered"), registered ? "true" : "false")
      if !registered {
        overlayFrom = nil
      }
    }

    /// The overlay's fade on its one clock and curve (user, 2026-10-14):
    /// coming on, the scan fades out under the text and the structure's
    /// lines fade in; going off, the reverse; the text itself never fades.
    /// `--artifact-overlay-progress` (0 the scan alone, 1 the structure
    /// alone) on the viewer while it runs or rests, none once off has run.
    private func fadeOverlay() {
      guard overlayOn || overlayLeaving else {
        root.removeAttribute(data("overlay-fading"))
        _ = root.style.removeProperty("--artifact-overlay-progress")
        return
      }
      root.setAttribute(data("overlay-fading"), "true")
      root.style.setProperty(
        "--artifact-overlay-progress", doubleToString(overlayOn ? overlayProgress : 1 - overlayProgress))
    }

    /// The overlay's motion so far, on its curve: 0 to 1.
    private var overlayProgress: Double {
      if window.matchMedia("(prefers-reduced-motion: reduce)") { return 1 }
      return OverlayMotion.eased((window.performance.now() - overlayZoomBegan) / OverlayMotion.milliseconds)
    }

    /// The shown layer's place in the window and its zoom.
    private func layerPlace() -> (zoom: Double, x: Double, y: Double)? {
      guard let box = shownLayer()?.getBoundingClientRect() else { return nil }
      return (currentZoom(), box.x, box.y)
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
      guard let box = layer.getBoundingClientRect(), let measured = textBlock(in: layer, drawnAt: currentZoom()) else {
        return nil
      }
      let zoom = currentZoom()
      let left = box.x + measured[0] * zoom
      let top = box.y + measured[1] * zoom
      let right = box.x + measured[2] * zoom
      let bottom = box.y + measured[3] * zoom
      return [left, top, right, top, right, bottom, left, bottom]
    }

    /// The page's rendered text block (`renderedTextBlock`) in its layer's
    /// own pixels (left, top, right, bottom), the layer drawn at `zoom`:
    /// measured once a page and kept (`overlayTarget`).
    private func textBlock(in layer: DOM.Element, drawnAt zoom: Double) -> [Double]? {
      guard let page = layer.closest(".tei-page"), let box = layer.getBoundingClientRect(), box.width > 0 else {
        return nil
      }
      let id = (page.getAttribute(data("service-id")) ?? "") + " " + (layer.getAttribute(data("layer")) ?? "")
      if !stringEquals(overlayTarget.page, id) || overlayTarget.box.count != 4 {
        let frame = layer.querySelector(".tei-text-block") ?? layer
        // Its em in its own pixels (a transform scales the layer, never its
        // type): the registration's type scale (`laid`).
        let em = pixels(window.getComputedStyle(frame).getPropertyValue("font-size"))
        // A derived text block (a page with no main text: the work frame
        // placed on its scan, gnorium-python `layout_measure.derived_corners`)
        // is the frame itself, laid on it whole; its marginalia keep their
        // measured offsets from it.
        if let derived = page.getAttribute(data("text-block-derived")), stringEquals(derived, "true"), frame !== layer,
          let edges = frame.getBoundingClientRect(), zoom > 0
        {
          overlayTarget = (
            id,
            [
              (edges.left - box.x) / zoom, (edges.top - box.y) / zoom, (edges.right - box.x) / zoom,
              (edges.bottom - box.y) / zoom,
            ],
            true,
            em
          )
          return overlayTarget.box
        }
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
        // block is the measure's. A block whose ink reaches both of the
        // frame's sides within a word space of its face (its lines
        // justified to the measure) spans it (`laid`).
        var spans = false
        if frame !== layer, let edges = frame.getBoundingClientRect() {
          ink.left = max(ink.left, edges.left)
          ink.right = min(ink.right, edges.right)
          if let context = document.createElement("canvas").getContext("2d") {
            let style = window.getComputedStyle(frame)
            context.font =
              style.getPropertyValue("font-style") + " " + style.getPropertyValue("font-weight") + " "
              + style.getPropertyValue("font-size") + " " + style.getPropertyValue("font-family")
            let space = context.measureText(" ").width * zoom
            spans = ink.left - edges.left <= space && edges.right - ink.right <= space
          }
        }
        guard let measured = ink.box, zoom > 0 else { return nil }
        overlayTarget = (
          id,
          [
            (measured[0] - box.x) / zoom, (measured[1] - box.y) / zoom, (measured[2] - box.x) / zoom,
            (measured[3] - box.y) / zoom,
          ],
          spans,
          em
        )
      }
      return overlayTarget.box
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
      for line in inkLines(of: node, in: parent, context: context, range: range) {
        ink.take(left: line.left, top: line.top, right: line.right, bottom: line.bottom)
      }
    }

    /// A text node's ink line by line (`measureInk`'s rule), each line's box
    /// in the window.
    private func inkLines(
      of node: DOM.Text, in parent: DOM.Element, context: DOM.CanvasRenderingContext2D, range: DOM.Range
    ) -> [StructureRow] {
      var found: [StructureRow] = []
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
      guard !glyphs.isEmpty else { return [] }
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
      guard let firstBox = boxes.first else { return [] }
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
        if right > left, rows.bottom > rows.top {
          // Its baseline: the font box's top plus the font's ascent, as
          // scaled (gnorium-python `layout_preview._INK_LINES`).
          var row = StructureRow(left: left, top: rows.top, right: right, bottom: rows.bottom)
          row.baseline = box.top + metrics.fontBoundingBoxAscent * scale
          found.append(row)
        }
      }
      return found
    }

    /// The shown page's rendered text block in its layer's own pixels
    /// (left, top, right, bottom), by its page's image and its layer.
    /// Its em there too (its frame's type, the work's body): the
    /// registration's type scale (`laid`).
    private var overlayTarget: (page: String, box: [Double], spans: Bool, em: Double) = ("", [], false, 0)

    /// The overlay's framing of the shown layer (`OverlayFraming`) in the
    /// pane's room as it is now (`overlayRoom`): the edition's whole page
    /// (`natural` its size unzoomed), on which the scan's text block is laid,
    /// never the scan beyond it (user, 2026-10-26); the reader's zoom held
    /// between its fit and the larger of the text's and the scan's actual
    /// sizes.
    private func overlayFraming(
      layer: DOM.Element, natural: (width: Double, height: Double), in room: (width: Double, height: Double)
    ) -> OverlayFraming {
      let content = (left: 0.0, top: 0.0, right: natural.width, bottom: natural.height)
      var actual = ViewerZoom.actualSize
      if let zone = overlayZone(), let size = shownImageSize, let measured = textBlock(in: layer, drawnAt: 1) {
        let box = laid(measured, zone: zone, size: size)
        let corners = (0..<8).map { zone[$0] / Self.zoneExtent * ($0 % 2 == 0 ? size.width : size.height) }
        // The overlay frames the edition's page alone: the scan's text block
        // is laid on its text block, so the scan beyond it—its margins and
        // what stands in them—frames nothing (user, 2026-10-26).
        let zoneSpan = ((corners[2] - corners[0]) * (corners[2] - corners[0]) + (corners[3] - corners[1]) * (corners[3] - corners[1])).squareRoot()
        if box[2] > box[0] { actual = max(actual, zoneSpan / (box[2] - box[0])) }
      }
      return OverlayFraming(content: content, width: room.width, height: room.height, actual: actual)
    }

    /// The layer where the overlay frames it (user, 2026-10-14): on its
    /// way in from where the reader had it to its fit, centered, the
    /// edition's page and the scan's reach framed; there, at the reader's
    /// own zoom and pan, the text and the structure over it moving as one
    /// (`overlayView`, held to the framing); on its way out at that zoom,
    /// sliding into its own pane with the spot the reader was looking at in
    /// its middle (`overlayFocus`). Set by the layer's scale and its frame's
    /// translation, the pane never scrolled. Framed in `room` (its inset
    /// from the pane's box and its size), the room the pane's fit is
    /// measured in.
    private func placeOverlay(
      _ layer: DOM.Element, frame: DOM.Element, in pane: DOM.Element, natural: DOM.Rect,
      room: (x: Double, y: Double, width: Double, height: Double), fit: Double, resting: Double
    ) {
      guard let paneBox = pane.getBoundingClientRect() else { return }
      overlayRoom = room
      let framing = overlayFraming(layer: layer, natural: (natural.width, natural.height), in: (room.width, room.height))
      lastFraming = framing
      let origin = (x: paneBox.x + room.x, y: paneBox.y + room.y)
      let progress = overlayProgress
      _ = frame.style.removeProperty("transform")
      var view: (zoom: Double, x: Double, y: Double)
      let from = overlayFrom.map { (zoom: $0.zoom, x: $0.x - origin.x, y: $0.y - origin.y) } ?? framing.fitted
      func between(_ a: Double, _ b: Double) -> Double { a + (b - a) * progress }
      if overlayOn && progress >= 1 {
        // Never zoomed, its fit, as the pane's size moves it.
        view = framing.held(overlayZoomed ? overlayView ?? framing.fitted : framing.fitted)
        overlayView = view
      } else if overlayOn {
        let to = framing.fitted
        view = (between(from.zoom, to.zoom), between(from.x, to.x), between(from.y, to.y))
      } else {
        // Out: at the overlay's zoom, the spot in the middle of the pane
        // as it is now (it grows back to its own size on the same clock),
        // as near as the pane's own layout lets it be.
        // From its fit, to the pane's fit as it is now, the scan sent to
        // the spot the text then shows (user, 2026-10-17).
        var focus = overlayFocus ?? (x: 0, y: 0, zoom: from.zoom)
        if overlayLeavesToFit {
          focus.zoom = fit
          overlayFocus = focus
        }
        let to = leavingView(focus, natural: (natural.width, natural.height))
        if overlayLeavesToFit {
          let middle = (
            x: (Double(pane.clientLeft) + Double(pane.clientWidth) / 2 - room.x - to.x) / fit,
            y: (Double(pane.clientTop) + Double(pane.clientHeight) / 2 - room.y - to.y) / fit
          )
          if let spot = scanSpot(at: middle, zoom: fit) { scanOwn = spot }
        }
        view = (between(from.zoom, focus.zoom), between(from.x, to.x), between(from.y, to.y))
      }
      frame.style.setProperty("width", doubleToString(natural.width * view.zoom) + "px")
      frame.style.setProperty("height", doubleToString(natural.height * view.zoom) + "px")
      frame.style.setProperty("margin-inline-start", "0")
      layer.style.setProperty("transform", "scale(" + doubleToString(view.zoom) + ")")
      layer.setAttribute(data("zoom"), doubleToString(view.zoom))
      pane.scrollLeft = 0
      pane.scrollTop = 0
      if let base = layer.getBoundingClientRect() {
        frame.style.setProperty(
          "transform",
          "translate(" + doubleToString(origin.x + view.x - base.x) + "px, " + doubleToString(origin.y + view.y - base.y)
            + "px)")
      }
      lastFit = fit
      matchedScroll = (pane.scrollLeft, pane.scrollTop)
      drawStructure()
      blendScan(layer)
    }

    /// Where the text's pane holds the page at the overlay's zoom, the spot
    /// the reader was looking at (`focus`, in the layer's own pixels) in
    /// its middle, as near as the pane's own layout lets it be: a page no
    /// wider than the pane's room (`overlayRoom`) centered across it, no
    /// taller than it at its top; else no edge pulled in past the room's.
    private func leavingView(
      _ focus: (x: Double, y: Double, zoom: Double), natural: (width: Double, height: Double)
    ) -> (x: Double, y: Double) {
      let width = overlayRoom.width
      let height = overlayRoom.height
      let across = natural.width * focus.zoom
      let down = natural.height * focus.zoom
      let x = across <= width ? (width - across) / 2 : min(0, max(width - across, width / 2 - focus.x * focus.zoom))
      let y = down <= height ? 0 : min(0, max(height - down, height / 2 - focus.y * focus.zoom))
      return (x, y)
    }

    /// Whether the overlay is at rest, laid by registration: the reader's
    /// zoom and pan move the text and the structure over it as one (user,
    /// 2026-10-14).
    private var overlayRests: Bool { overlayRegistered && overlayOn && overlayProgress >= 1 }

    /// The overlay's view zoomed to `value` about `anchor` (a point of the
    /// pane's box), the page's point under it kept there, held to the
    /// framing.
    private func zoomOverlay(to value: Double, about anchor: (x: Double, y: Double)) {
      guard let framing = lastFraming else { return }
      let view = overlayView ?? framing.fitted
      // The view is the room's: the anchor taken into it.
      let at = (x: anchor.x - overlayRoom.x, y: anchor.y - overlayRoom.y)
      let point = ((at.x - view.x) / view.zoom, (at.y - view.y) / view.zoom)
      let zoom = framing.held((value, 0, 0)).zoom
      overlayView = framing.held((zoom, at.x - point.0 * zoom, at.y - point.1 * zoom))
      // Past its fit by a pixel or more, the reader's zoom; within one, its fit.
      let extent = max(framing.content.right - framing.content.left, framing.content.bottom - framing.content.top)
      overlayZoomed = (zoom - framing.fit) * extent >= 1
      applyZoom(about: nil)
    }

    /// The overlay's view moved by `dx`, `dy` (the pane's pixels), held to
    /// the framing.
    private func panOverlay(by dx: Double, _ dy: Double) {
      guard let framing = lastFraming else { return }
      let view = overlayView ?? framing.fitted
      overlayView = framing.held((view.zoom, view.x + dx, view.y + dy))
      applyZoom(about: nil)
    }

    /// Whether the overlay holds the panes to its own motion: from overlay
    /// on until overlay off has run, no gesture moves either pane on its
    /// own; at rest, registered, the reader's zoom and pan move both as one
    /// (`overlayRests`).
    private var overlayLocked: Bool { overlayOn || overlayLeaving }

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

    private var lastPaneSize = (width: 0.0, height: 0.0)

    private func setupZoom() {
      guard let pane = markupPane else { return }
      // The fit follows the pane's size and the page's content: a page
      // fetched in, a page turned, the pane resized.
      pane.observeResize { [self] _, _ in
        if let box = self.markupPane?.getBoundingClientRect() {
          if abs(box.width - self.lastPaneSize.width) < 0.5 && abs(box.height - self.lastPaneSize.height) < 0.5 {
            return
          }
          self.lastPaneSize = (box.width, box.height)
        }
        self.scheduleZoom()
      }
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
          guard self.panStart == nil, !self.reflowOn, !self.rawVisible, let pane = self.markupPane else { return }
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
        "touchend",
        { [self] e in
          if e.touchCount < 2 { self.pinchStart = nil }
          if e.touchCount < 1 { self.touchStart = nil }
        }, capture: false, passive: true)
      // Safari's trackpad pinch: WebKit's gesture events, not ctrl+wheel.
      // Zoomed about the gesture's point from the zoom it began at, by its
      // scale; the page itself never zoomed. Other browsers never send them.
      _ = pane.addEventListener(
        "gesturestart",
        { [self] e in
          guard !self.rawVisible else { return }
          e.preventDefault()
          if self.overlayRests { self.gestureStartZoom = self.currentZoom() }
          guard !self.overlayLocked else { return }
          self.gestureStartZoom = self.currentZoom()
        }, capture: false, passive: false)
      _ = pane.addEventListener(
        "gesturechange",
        { [self] e in
          guard !self.rawVisible else { return }
          e.preventDefault()
          guard let pane = self.markupPane, let box = pane.getBoundingClientRect() else { return }
          if self.overlayRests {
            self.zoomOverlay(to: self.gestureStartZoom * e.webKitGestureScale, about: (e.clientX - box.x, e.clientY - box.y))
          }
          guard !self.overlayLocked else { return }
          self.zoom(to: self.gestureStartZoom * e.webKitGestureScale, about: (e.clientX - box.x, e.clientY - box.y))
        }, capture: false, passive: false)
      _ = pane.addEventListener("gestureend", { [self] e in if !self.rawVisible { e.preventDefault() } }, capture: false, passive: false)
      applyZoom(about: nil)
      scheduleZoom()
    }

    /// The wheel—a plain one, a trackpad's two fingers or pinch (the
    /// browser's ctrl+wheel), ctrl/cmd+wheel—zooms about the pointer, as
    /// the image's does, and never scrolls the page (user, 2026-10-12).
    private func wheel(_ event: Event) {
      // Raw is an ordinary code scrollport; it does not synchronize zoom.
      if rawVisible { return }
      // Reflowed, the pane is a text pane (user, 2026-10-14): the wheel
      // scrolls it natively; a pinch (the browser's ctrl+wheel) or
      // ctrl/cmd+wheel still zooms its text.
      if reflowOn && !event.ctrlKey && !event.metaKey { return }
      guard let pane = markupPane, let box = pane.getBoundingClientRect() else { return }
      event.preventDefault()
      if overlayRests {
        zoomOverlay(
          to: currentZoom() * ViewerZoom.wheelFactor(event.deltaY), about: (event.clientX - box.x, event.clientY - box.y))
        return
      }
      guard !overlayLocked else { return }
      zoom(
        to: currentZoom() * ViewerZoom.wheelFactor(event.deltaY),
        about: (event.clientX - box.x, event.clientY - box.y))
    }

    /// Two fingers zoom about their midpoint, by how far they spread.
    private func pinch(_ event: Event) {
      // The overlay at rest: one finger pans it, two zoom it, the text and
      // its structure as one; in its motion no finger moves it.
      if overlayLocked {
        event.preventDefault()
        guard overlayRests, let pane = markupPane, let box = pane.getBoundingClientRect() else { return }
        if event.touchCount == 1 {
          let x = event.touchClientX(0), y = event.touchClientY(0)
          if let last = touchStart { panOverlay(by: x - last.x, y - last.y) }
          touchStart = (x, y)
        } else if event.touchCount == 2 {
          touchStart = nil
          let x0 = event.touchClientX(0), y0 = event.touchClientY(0)
          let x1 = event.touchClientX(1), y1 = event.touchClientY(1)
          let distance = ((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)).squareRoot()
          guard distance > 0 else { return }
          guard let start = pinchStart else {
            pinchStart = (distance, currentZoom())
            return
          }
          zoomOverlay(to: start.zoom * distance / start.distance, about: ((x0 + x1) / 2 - box.x, (y0 + y1) / 2 - box.y))
        }
        return
      }
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

    /// One finger on the overlay at rest: where it was last.
    private var touchStart: (x: Double, y: Double)?
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
      if overlayLocked {
        guard overlayRests, event.button == 0, event.clickCount <= 1, !event.shiftKey,
          !isOnText(x: event.clientX, y: event.clientY), let pane = markupPane
        else { return }
        // The overlay at rest: a drag pans the text and its structure as one.
        event.preventDefault()
        pane.focus(DOM.FocusOptions(preventScroll: true))
        panMoved = false
        panStart = (event.clientX, event.clientY, 0, 0)
        endPan()
        panMoveListener = window.addEventListener(.mousemove) { [self] e in
          guard let start = self.panStart else { return }
          if e.clientX != start.x || e.clientY != start.y {
            self.panMoved = true
            self.markupPane?.setAttribute(data("dragging"), "true")
          }
          self.panOverlay(by: e.clientX - start.x, e.clientY - start.y)
          self.panStart = (e.clientX, e.clientY, 0, 0)
        }
        panUpListener = window.addEventListener(.mouseup) { [self] _ in
          self.panStart = nil
          self.endPan()
        }
        return
      }
      // Reflowed, a press selects text as in any text pane: nothing pans.
      guard !reflowOn, !rawVisible, let pane = markupPane, event.button == 0, event.clickCount <= 1, !event.shiftKey,
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
      let key = event.key
      let middle = (box.width / 2, box.height / 2)
      if overlayLocked {
        // The overlay at rest: its keys move the text and its structure as one.
        guard overlayRests else { return }
        if stringEquals(key, "+") || stringEquals(key, "=") {
          zoomOverlay(to: currentZoom() * ViewerZoom.wheelFactor(-ViewerZoom.wheelTravel), about: middle)
        } else if stringEquals(key, "-") {
          zoomOverlay(to: currentZoom() * ViewerZoom.wheelFactor(ViewerZoom.wheelTravel), about: middle)
        } else if stringEquals(key, "0") {
          overlayView = nil
          overlayZoomed = false
          applyZoom(about: nil)
        } else if stringEquals(key, "ArrowLeft") {
          panOverlay(by: ViewerZoom.wheelTravel, 0)
        } else if stringEquals(key, "ArrowRight") {
          panOverlay(by: -ViewerZoom.wheelTravel, 0)
        } else if stringEquals(key, "ArrowUp") {
          panOverlay(by: 0, ViewerZoom.wheelTravel)
        } else if stringEquals(key, "ArrowDown") {
          panOverlay(by: 0, -ViewerZoom.wheelTravel)
        } else {
          return
        }
        event.preventDefault()
        event.stopPropagation()
        return
      }
      // Reflowed or as code, the arrows scroll the text pane as the
      // browser's own.
      if (reflowOn || rawVisible) && stringStartsWith(key, "Arrow") { return }
      textMatchAnimation += 1
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
      guard syncs else { return }
      guard let pane = markupPane, let layer = shownLayer() else {
        if region.scale <= 1.0001 { setZoom(nil, atFit: true) }
        return
      }
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
      showLayer(rendered)
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
      // Measured where its own layout puts it: the overlay's translation
      // (`placeOverlay`) is set again below.
      if let parent = layer.parentElement, stringEquals(parent.getAttribute(data("page-scale")) ?? "", "true") {
        _ = parent.style.removeProperty("transform")
      }
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
      let innerWidth = pane.clientWidth > 0 ? min(paneBox.width - borderX, Double(pane.clientWidth)) : paneBox.width - borderX
      let innerHeight = pane.clientHeight > 0 ? min(paneBox.height - borderY, Double(pane.clientHeight)) : paneBox.height - borderY
      let paneWidth = innerWidth - 2 * insetX
      let paneHeight = innerHeight - 2 * insetY
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
      // A page set in its work's frame is its own size (TEIView: its frame,
      // its marginalia, its margins), and the zoom fits that page (user,
      // 2026-10-14); one with no frame takes its canvas's proportions.
      if stringEquals(layer.getAttribute(data("framed")) ?? "", "true") {
        _ = layer.style.removeProperty("min-width")
        _ = layer.style.removeProperty("min-height")
      } else {
        layer.style.setProperty("min-width", "640px")
        layer.style.setProperty("min-height", doubleToString(640 / ratio) + "px")
      }
      layer.style.setProperty("transform-origin", "top left")
      layer.style.setProperty("transform", "none")
      guard let natural = layer.getBoundingClientRect(), natural.width > 0, natural.height > 0 else { return }
      let fit = containFit(width: natural.width, height: natural.height, paneWidth: paneWidth, paneHeight: paneHeight)
      let stored = storedZoom()
      var resting = anchor == nil && stored.atFit ? fit : max(fit, min(maxZoom(fit: fit), stored.zoom ?? ViewerZoom.actualSize))
      // Within a pixel of its fit the page is at its fit: a zoom a hair
      // over it (one read back from its attribute, a sync's ratio, the
      // overlay's kept as it went off) made the pane a scrollbar for a
      // pixel's rounding, and left a fit the pane's size no longer moved.
      let span = max(natural.width, natural.height)
      if (resting - fit) * span < 1 { resting = fit }
      fadeOverlay()
      if overlayRegistered && (overlayOn || overlayLeaving) {
        placeOverlay(
          layer, frame: frame, in: pane, natural: natural, room: (insetX, insetY, paneWidth, paneHeight), fit: fit,
          resting: resting)
        return
      }
      var zoom = overlayOn ? overlayZoomStart + (fit - overlayZoomStart) * overlayProgress
        : overlayLeaving ? overlayZoomStart + (resting - overlayZoomStart) * overlayProgress : resting
      // Settled: a zoom a pixel or more over the fit, moved less than a
      // pixel, kept as it is; one within a pixel of the fit never is.
      let settled = !overlayOn && !overlayLeaving && (previous - fit) * span >= 1 && abs(zoom - previous) * span < 1
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
      drawStructure()
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
      applyZoomLayout(about: anchor, matching: matching)
      // The words marked as the scan's wear bands measured at the zoom and
      // size before (`band`): drawn again where the layer now is.
      for word in correspondingWords { band(word) }
    }

    private func applyZoomLayout(about anchor: (x: Double, y: Double)?, matching: Bool = false) {
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
      if codeView == nil && !reflowOn && stringEquals(layer.getAttribute(data("framed")) ?? "", "true") {
        // A page set in its work's frame is its own size.
        _ = layer.style.removeProperty("min-width")
        _ = layer.style.removeProperty("min-height")
      } else if codeView == nil && !reflowOn {
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
        if let page = layer.closest(".tei-page") {
          _ = page.style.removeProperty("min-width")
          _ = page.style.removeProperty("min-height")
        }
      }
      if reflowOn {
        pane.style.setProperty("overflow", "hidden")
      }
      guard let box = layer.getBoundingClientRect(), box.width > 0, box.height > 0
      else {
        if reflowOn { _ = pane.style.removeProperty("overflow") }
        return
      }
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
      let innerWidth = pane.clientWidth > 0 ? min(paneBox.width - borderX, Double(pane.clientWidth)) : paneBox.width - borderX
      let innerHeight = pane.clientHeight > 0 ? min(paneBox.height - borderY, Double(pane.clientHeight)) : paneBox.height - borderY
      let paneWidth = innerWidth - 2 * insetX
      let paneHeight = innerHeight - 2 * insetY
      guard paneWidth > 0, paneHeight > 0 else {
        if reflowOn { _ = pane.style.removeProperty("overflow") }
        return
      }
      // The whole page's fit, never above its actual size: its lines as
      // drawn, or, reflowed, its height as it wraps.
      let fit: Double
      if codeView != nil {
        // The code zooms out no further than its page's rendered text can
        // (user, 2026-10-12), for the two to keep one scale: past that its
        // long lines scroll sideways.
        guard let rendered = renderedFit(of: layer, paneWidth: paneWidth, paneHeight: paneHeight) else {
          if reflowOn { _ = pane.style.removeProperty("overflow") }
          return
        }
        fit = rendered
      } else if reflowOn {
        guard let reflowed = reflowedFit(layer, paneHeight: paneHeight) else {
          _ = pane.style.removeProperty("overflow")
          return
        }
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
      if reflowOn { _ = pane.style.removeProperty("overflow") }
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
      } else if !reflowOn {
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
          liveImages = []
          blankPages = []
        }
        for page in manifest.pages {
          serviceIDs.append(page.serviceID)
          plainImages.append(page.images)
          liveImages.append(page.live)
          blankPages.append(page.blank)
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
      // A page shown with no image (`ArtifactManifest.Page.blank`, or every
      // copy failed to load; user, 2026-10-17): no canvas active and none
      // read, the image pane put away and the text alone, as with the images
      // off (`imagesShown`)—never the image its service serves now, nor the
      // last page's.
      if isBlank(idx) {
        for element in object?.querySelectorAll("[data-service-id]") ?? [] {
          element.setAttribute(data("active"), "false")
        }
        shownCanvas?.hide()
        shownCanvas = nil
        return
      }
      let service = serviceIDs[idx]
      let canvas = canvasReader(ofService: service)
      for element in object?.querySelectorAll("[data-service-id]") ?? [] {
        let active = stringEquals(element.dataset["service-id"] ?? "", service)
        element.setAttribute(data("active"), active ? "true" : "false")
      }
      if let shown = shownCanvas, shown !== canvas { shown.hide() }
      shownCanvas = canvas
      canvas.show(
        width: imageWidths[idx], height: imageHeights[idx], images: idx < plainImages.count ? plainImages[idx] : [],
        live: idx >= liveImages.count || liveImages[idx])
      // Synced, the text opens on the image's part of the page, at its
      // size, rather than at 100%.
      if syncs, let region = canvas.region { matchText(to: region) }
      drawRegion()
      // The four either side, nearest first: images are what a turn waits
      // for (user, 2026-10-11). Once this page has what it shows, so they
      // never queue before it; in one batch, since a batch stops the last
      // one's loads (a call each kept only the last neighbor's).
      canvas.whenSettled { [self] in
        guard let shown = shownCanvas, shown === canvas else { return }
        var urls: [String] = []
        for distance in 1...4 {
          for neighbor in [idx + distance, idx - distance]
          where neighbor >= 0 && neighbor < serviceIDs.count && readsService(neighbor) {
            urls.append(
              contentsOf: canvas.openingURLs(
                serviceID: serviceIDs[neighbor], width: imageWidths[neighbor], height: imageHeights[neighbor]))
          }
        }
        // Waiting no longer than the host's own answers say a whole image
        // takes (none of this page's before it has answered enough).
        preloadImages(urls: urls, timeout: canvas.preloadTimeout(serviceID: service) ?? 0)
      }
    }

    /// Whether the canvas at `idx` is shown with no image (`blankPages`).
    private func isBlank(_ idx: Int) -> Bool { idx >= 0 && idx < blankPages.count && blankPages[idx] }

    /// Whether the canvas at `idx` reads its image service: not shown with no
    /// image, no plain image in its place, and its service allowed
    /// (`liveImages`)—never a page changed at its source, whose image now is
    /// not what was sent (user, 2026-10-17).
    private func readsService(_ idx: Int) -> Bool {
      !isBlank(idx) && (idx >= plainImages.count || plainImages[idx].isEmpty)
        && (idx >= liveImages.count || liveImages[idx])
    }

    /// Every copy of what a page's session was sent failed to load, and its
    /// image now may not stand in (`ArtifactManifest.Page.live`): the page is
    /// shown with no image from here on, as one the manifest gives none
    /// (user, 2026-10-17)—its canvas put away, its text alone, the images
    /// switch and the overlay's disabled, the overlay off. Told as
    /// `artifact-canvas-no-image` (its service), so a host's words about
    /// what the reader shows say none (gnorium-web's source-change notice).
    private func showNoImage(ofService service: String) {
      guard let idx = canvasIndex(ofService: service), idx < blankPages.count else { return }
      blankPages[idx] = true
      root.dispatchEvent(CustomEvent(type: "artifact-canvas-no-image", detail: service))
      guard idx == canvasIndex else { return }
      showCanvas(idx)
      reflectPageMarkup()
    }

    /// The reader of a canvas, made the first time it is shown: over the
    /// slot's canvas for that image service, else one drawn for it.
    private func canvasReader(ofService service: String) -> ImageView {
      for canvas in canvases where stringEquals(canvas.serviceID, service) {
        return canvas
      }
      var element: DOM.Element?
      for candidate in object?.querySelectorAll(".image-view") ?? []
      where stringEquals(candidate.dataset["service-id"] ?? "", service) {
        element = candidate
        break
      }
      if element == nil {
        let drawn = ImageView.make(serviceID: service)
        object?.appendChild(drawn)
        element = drawn
      }
      let canvas = ImageView(root: element ?? ImageView.make(serviceID: service))
      let viewer = root
      canvas.onCrop = { detail in
        viewer.dispatchEvent(CustomEvent(type: "artifact-crop-change", detail: detail))
      }
      canvas.onRegionEdit = { [self] x, y, width, height, done in
        self.regionEdited(x: x, y: y, width: width, height: height, done: done)
      }
      canvas.onVertexEdit = { [self] index, x, y, done in
        self.vertexEdited(index, x: x, y: y, done: done)
      }
      canvas.onNoImage = { [self] in self.showNoImage(ofService: service) }
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
        if let target = e.target, let pane = target.closest(".artifact-markup, .image-viewport"), pane.id == target.id {
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
      // A manifest that names it not (unread, or failed): the pane that
      // reads it, at its own place.
      for (position, pane) in markupPanes.enumerated() where stringEquals(pane.dataset["service-id"] ?? "", service) {
        return windowed ? (parseInt(pane.dataset["page-index"] ?? "") ?? position) : position
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
      reflectPageMarkup()
      applyZoom(about: nil)
      scheduleZoom()
    }

    // MARK: - The scan's structure

    /// A row of the scan's structure laid in the shown layer's own pixels:
    /// its box and its lines' corners there.
    private struct ScanRow {
      var box: StructureRow
      var lines: [[Double]]
    }

    /// The edition's structure and the scan's, laid in the shown layer's
    /// own pixels (unzoomed), paired (`StructurePairing`): what the
    /// structure overlay draws and the word correspondence reads. Measured
    /// once a page and layer (`key`).
    private struct Structure {
      let key: String
      let leading: Double
      let editionRows: [StructureRow]
      let editionBlocks: [StructureRow]
      let scanRows: [ScanRow]
      let scanBlocks: [[Double]]
      /// Each edition row's state and each scan row's: "within", "off",
      /// "extra" (an edition row the scan lacks), "missing" (a scan row the
      /// edition lacks).
      let editionStates: [String]
      let scanStates: [String]
    }

    private var structure: Structure?

    /// The page's scan layout (`data-scan-layout`,
    /// `OverlayRegistration.scanLayout`): its zones in reading order, a
    /// line's main-ness its block's.
    private func scanLayout(of page: DOM.Element) -> [ScanZone] {
      OverlayRegistration.scanLayout(page.getAttribute(data("scan-layout")) ?? "")
    }

    /// The scale the shown layer is drawn at now: its box over its own
    /// layout width, whatever its transform.
    private func drawnScale(of layer: DOM.Element) -> Double? {
      // Over its layout width to the fraction (`clientWidth` is rounded to a
      // pixel: a page's rows a fifth of a pixel off at its foot).
      let style = window.getComputedStyle(layer)
      var width = pixels(style.getPropertyValue("width"))
      if !stringEquals(style.getPropertyValue("box-sizing"), "border-box") {
        for side in ["padding-left", "padding-right", "border-left-width", "border-right-width"] {
          width += pixels(style.getPropertyValue(side))
        }
      }
      guard let box = layer.getBoundingClientRect(), width > 0, box.width > 0 else { return nil }
      return box.width / width
    }

    /// The overlay's registration as a map from the scan's 0–1000 space
    /// into the shown layer's own pixels (`registerOverlay`'s homography:
    /// the text block's corners onto the rendered main text's laid box);
    /// nil where the page's text block was not measured or its image's
    /// size is not known.
    private func scanToLayer(_ layer: DOM.Element, drawnAt scale: Double) -> Homography? {
      guard let zone = overlayZone(), let size = shownImageSize, let measured = textBlock(in: layer, drawnAt: scale)
      else { return nil }
      let box = laid(measured, zone: zone, size: size)
      let target = [box[0], box[1], box[2], box[1], box[2], box[3], box[0], box[3]]
      let corners = (0..<8).map { zone[$0] / Self.zoneExtent * ($0 % 2 == 0 ? size.width : size.height) }
      return Homography(from: corners, to: target)
    }

    /// The page's structure (`Structure`), measured where the rendered page
    /// is set by its lines (Reflow and Raw off) and its scan is laid by its
    /// text block; nil elsewhere, or where its scan's layout or its body's
    /// leading is not given.
    private func currentStructure() -> Structure? {
      guard !rawVisible, !reflowOn, let layer = shownLayer(), let page = layer.closest(".tei-page") else { return nil }
      let key = (page.getAttribute(data("service-id")) ?? "") + " " + (layer.getAttribute(data("layer")) ?? "")
      if let structure, stringEquals(structure.key, key) { return structure }
      let zones = scanLayout(of: page)
      guard !zones.isEmpty, let leadingRem = parseDouble(page.getAttribute(data("body-leading")) ?? ""),
        let scale = drawnScale(of: layer), let size = shownImageSize, let map = scanToLayer(layer, drawnAt: scale),
        let box = layer.getBoundingClientRect(), let context = document.createElement("canvas").getContext("2d")
      else { return nil }
      // The body's leading in the layer's pixels: the body type's (the
      // frame's em) times the scale's leading in rem.
      let frame = layer.querySelector(".tei-text-block")
      let rem = pixels(window.getComputedStyle(frame ?? layer).getPropertyValue("font-size"))
      let leading = leadingRem * rem
      guard leading > 0 else { return nil }

      // The scan's: each zone's corners laid in the layer.
      func laidPoints(_ points: [Double]) -> [Double] {
        var out: [Double] = []
        for corner in 0..<4 {
          let point = map.apply(
            x: points[2 * corner] / Self.zoneExtent * size.width, y: points[2 * corner + 1] / Self.zoneExtent * size.height)
          out.append(point.x)
          out.append(point.y)
        }
        return out
      }
      func bounds(_ points: [Double]) -> StructureRow {
        StructureRow(
          left: min(points[0], points[2], points[4], points[6]), top: min(points[1], points[3], points[5], points[7]),
          right: max(points[0], points[2], points[4], points[6]), bottom: max(points[1], points[3], points[5], points[7]))
      }
      var mainLines: [ScanRow] = []
      // The scan's marginalia block by block (each a block zone, its lines
      // after it): a note pairs with blocks, never with lines alone.
      var marginBlocks: [(box: StructureRow, lines: [ScanRow])] = []
      var scanBlocks: [[Double]] = []
      for zone in zones where zone.kind < 2 {
        let points = laidPoints(zone.points)
        if zone.kind == 0 {
          scanBlocks.append(points)
          if !zone.main { marginBlocks.append((bounds(points), [])) }
          continue
        }
        var row = ScanRow(box: bounds(points), lines: [points])
        // Its baseline laid as its corners are: the middle of its two ends
        // (gnorium-python `layout_measure.registered`).
        if zone.baseline.count == 4 {
          let start = map.apply(
            x: zone.baseline[0] / Self.zoneExtent * size.width, y: zone.baseline[1] / Self.zoneExtent * size.height)
          let end = map.apply(
            x: zone.baseline[2] / Self.zoneExtent * size.width, y: zone.baseline[3] / Self.zoneExtent * size.height)
          row.box.baseline = (start.y + end.y) / 2
        }
        if zone.main {
          mainLines.append(row)
        } else if !marginBlocks.isEmpty {
          marginBlocks[marginBlocks.count - 1].lines.append(row)
        }
      }
      // Lines side by side one row (`StructurePairing.rows`).
      func scanRows(_ lines: [ScanRow]) -> [ScanRow] {
        var rows: [ScanRow] = []
        for line in lines.sorted(by: { $0.box.top < $1.box.top }) {
          if let last = rows.last, line.box.top < last.box.bottom {
            rows[rows.count - 1].box = last.box.joined(line.box)
            rows[rows.count - 1].lines += line.lines
          } else {
            rows.append(line)
          }
        }
        return rows
      }
      let scanMain = scanRows(mainLines)

      // The edition's: each line's ink in the layer's own pixels, side by
      // side one row; each block the box around its lines.
      let range = document.createRange()
      var blocks: [(id: Int32, box: StructureRow)] = []
      func editionRows(of roots: [DOM.Element]) -> [StructureRow] {
        var lines: [StructureRow] = []
        for root in roots {
          let walker = document.createTreeWalker(root, DOM.NodeFilter.SHOW_TEXT)
          while let next = walker.nextNode() {
            guard let node = next as? DOM.Text, let parent = node.parentElement else { continue }
            let block: Int32 = parent.closest(".tei-block").map { $0.id } ?? -1
            // How its line is set: the edges the print aligns, and its
            // type's em (CSS pixels, the layer's own).
            let style = window.getComputedStyle(parent)
            let align = style.getPropertyValue("text-align")
            let rightToLeft = stringEquals(style.getPropertyValue("direction"), "rtl")
            let alignment: StructureAlignment =
              stringEquals(align, "justify") ? .justified
              : stringEquals(align, "center") ? .center
              : stringEquals(align, "right") || (stringEquals(align, "end") && !rightToLeft)
                || (stringEquals(align, "start") && rightToLeft) ? .right : .left
            let em = pixels(style.getPropertyValue("font-size"))
            for line in inkLines(of: node, in: parent, context: context, range: range) {
              let row = StructureRow(
                left: (line.left - box.x) / scale, top: (line.top - box.y) / scale, right: (line.right - box.x) / scale,
                bottom: (line.bottom - box.y) / scale, alignment: alignment, em: em, block: block,
                baseline: line.baseline.map { ($0 - box.y) / scale }, baselineEm: em)
              lines.append(row)
              if block >= 0 {
                if let index = blocks.firstIndex(where: { $0.id == block }) {
                  blocks[index].box = blocks[index].box.joined(row)
                } else {
                  blocks.append((block, row))
                }
              }
            }
          }
        }
        return StructurePairing.lastLinesLeft(StructurePairing.rows(lines))
      }
      let editionMain = editionRows(of: [frame ?? layer])
      // The edition's notes (each child of a margin area: a note's section
      // or its printed frame), each its rows, its box and its place's sides
      // (`TEIRenderer.marginalAreas`: "top-left" is top and margin-left).
      var notes: [(box: StructureRow, rows: [StructureRow], sides: [String])] = []
      for margin in layer.querySelectorAll(".tei-margin") {
        let place = margin.getAttribute(data("place")) ?? ""
        var sides: [String] = []
        if stringStartsWith(place, "top") { sides.append("top") }
        if stringStartsWith(place, "bottom") { sides.append("bottom") }
        if stringEndsWith(place, "left") { sides.append("margin-left") }
        if stringEndsWith(place, "right") { sides.append("margin-right") }
        for note in margin.querySelectorAll(":scope > *") {
          let rows = editionRows(of: [note])
          guard var box = rows.first else { continue }
          for row in rows { box = box.joined(row) }
          notes.append((box, rows, sides))
        }
      }
      // Each scan block of marginalia goes to the edition's note nearest it
      // on its side of the frame (gnorium-python `layout_measure.side`: the
      // side it lies wholly beyond, both at a corner, else the nearest
      // edge), the frame the edition's, the scan laid in it: a note may
      // gather several (a bookplate the measurement cuts in blocks).
      let frameBox: StructureRow = {
        guard let edges = (frame ?? layer).getBoundingClientRect() else { return StructureRow(left: 0, top: 0, right: 0, bottom: 0) }
        return StructureRow(
          left: (edges.left - box.x) / scale, top: (edges.top - box.y) / scale, right: (edges.right - box.x) / scale,
          bottom: (edges.bottom - box.y) / scale)
      }()
      func sides(of block: StructureRow) -> [String] {
        let beyond = [
          ("top", frameBox.top - block.bottom), ("bottom", block.top - frameBox.bottom),
          ("margin-left", frameBox.left - block.right), ("margin-right", block.left - frameBox.right),
        ]
        let clear = beyond.filter { $0.1 >= 0 }.map { $0.0 }
        if !clear.isEmpty { return clear }
        let middle = (block.top + block.bottom) / 2
        let center = (block.left + block.right) / 2
        let near = [
          ("top", middle - frameBox.top), ("bottom", frameBox.bottom - middle), ("margin-left", center - frameBox.left),
          ("margin-right", frameBox.right - center),
        ]
        var nearest = near[0]
        for side in near where side.1 < nearest.1 { nearest = side }
        return [nearest.0]
      }
      func distance(_ a: StructureRow, _ b: StructureRow) -> Double {
        abs(a.top - b.top) + abs(a.bottom - b.bottom) + abs(a.left - b.left) + abs(a.right - b.right)
      }
      var gathered = [[ScanRow]](repeating: [], count: notes.count)
      var alone: [ScanRow] = []
      for block in marginBlocks {
        let blockSides = sides(of: block.box)
        var nearest: (index: Int, distance: Double)?
        for (index, note) in notes.enumerated()
        where note.sides.contains(where: { side in blockSides.contains { stringEquals($0, side) } }) {
          let far = distance(note.box, block.box)
          if nearest.map({ far < $0.distance }) ?? true { nearest = (index, far) }
        }
        if let nearest { gathered[nearest.index] += block.lines } else { alone += block.lines }
      }

      // Paired, main text and marginalia apart; their states.
      var editionStates: [String] = []
      var scanStates: [String] = []
      // The main text's rows paired where they stand; each note's with the
      // scan's it gathered, each side from its own box's top-left (its
      // lines within it: gnorium-python `layout_measure.compare`'s
      // marginalia), so a note set elsewhere still pairs line for line.
      // A note's lines are judged by its own leading (user, 2026-10-14):
      // an owner's mark (a hand, a stamp, a label) is none of the type
      // scale, so its own measured line pitch—the median distance between
      // its scan lines' tops, else its edition lines', else the body's
      // leading for a line alone—is its L.
      func pitch(_ rows: [StructureRow]) -> Double? {
        guard rows.count > 1 else { return nil }
        var steps: [Double] = []
        for index in 1..<rows.count { steps.append(rows[index].top - rows[index - 1].top) }
        steps.sort()
        return steps[steps.count / 2]
      }
      var groups:
        [(edition: [StructureRow], scan: [ScanRow], from: (x: Double, y: Double), to: (x: Double, y: Double), leading: Double)] = [
          (editionMain, scanMain, (0, 0), (0, 0), leading)
        ]
      for (index, note) in notes.enumerated() {
        let rows = scanRows(gathered[index])
        var reach = rows.first?.box ?? note.box
        for row in rows { reach = reach.joined(row.box) }
        let own = pitch(rows.map { $0.box }) ?? pitch(note.rows) ?? leading
        groups.append((note.rows, rows, (note.box.left, note.box.top), (reach.left, reach.top), own))
      }
      groups.append(([], scanRows(alone), (0, 0), (0, 0), leading))
      var editionRowsAll: [StructureRow] = []
      var scanRowsAll: [ScanRow] = []
      func moved(_ row: StructureRow, by shift: (x: Double, y: Double)) -> StructureRow {
        StructureRow(
          left: row.left - shift.x, top: row.top - shift.y, right: row.right - shift.x, bottom: row.bottom - shift.y,
          baseline: row.baseline.map { $0 - shift.y }, baselineEm: row.baselineEm)
      }
      for (edition, scan, from, to, leading) in groups {
        editionRowsAll += edition
        scanRowsAll += scan
        var editionState = [String](repeating: "within", count: edition.count)
        var scanState = [String](repeating: "within", count: scan.count)
        for match in StructurePairing.pair(
          edition: edition.map { moved($0, by: from) }, scan: scan.map { moved($0.box, by: to) }, leading: leading)
        {
          switch match {
          case .pair(let e, let s, _):
            // Paired from their own boxes, judged where each stands: a
            // note regularized to its canonical place (a bookplate
            // centered) is orange where its measured place differs past
            // its own tolerance (user, 2026-10-14).
            let within = StructurePairing.within(edition[e], scan[s].box, leading: leading)
            editionState[e] = within ? "within" : "off"
            scanState[s] = within ? "within" : "off"
          case .extra(let e):
            editionState[e] = "extra"
          case .missing(let s):
            scanState[s] = "missing"
          }
        }
        editionStates += editionState
        scanStates += scanState
      }
      let made = Structure(
        key: key, leading: leading, editionRows: editionRowsAll, editionBlocks: blocks.map { $0.box },
        scanRows: scanRowsAll, scanBlocks: scanBlocks, editionStates: editionStates, scanStates: scanStates)
      structure = made
      return made
    }

    /// The structure overlay (user, 2026-10-14): over the edition, its line
    /// and block structure and the scan's as the tools measured it, laid by
    /// the overlay's registration, in one scene—the edition's outlines
    /// solid, the scan's dashed; a pair within the tolerance quiet, one out
    /// of it orange, an edition line the scan lacks green, a scan line the
    /// edition lacks red (`StructurePairing`). No scan pixels and no words:
    /// drawn in the layer's own pixels, so it zooms and pans with the text,
    /// its strokes at the screen's width. Shown while the overlay is on and
    /// the page's scan is laid by its text block; gnorium-python's review
    /// image draws the same scene for the model.
    private func drawStructure() {
      let shown = overlayRegistered && (overlayOn || overlayLeaving)
      for drawn in root.querySelectorAll(".artifact-markup .artifact-structure") {
        if !shown { drawn.remove() }
      }
      guard shown, let layer = shownLayer(), let structure = currentStructure() else { return }
      if let drawn = layer.querySelector(":scope > .artifact-structure"),
        stringEquals(drawn.getAttribute(data("key")) ?? "", structure.key)
      {
        return
      }
      layer.querySelector(":scope > .artifact-structure")?.remove()
      func number(_ value: Double) -> String { doubleToString((value * 100).rounded() / 100) }
      func rectangle(_ row: StructureRow, side: String, kind: String, state: String, index: Int = -1) -> String {
        stringJoin(
          [
            "<rect data-side=\"", side, "\" data-kind=\"", kind, "\" data-row=\"", intToString(index), "\" data-state=\"",
            state, "\" x=\"", number(row.left),
            "\" y=\"", number(row.top), "\" width=\"", number(row.right - row.left), "\" height=\"",
            number(row.bottom - row.top), "\"/>",
          ], separator: "")
      }
      func polygon(_ points: [Double], kind: String, state: String, index: Int = -1) -> String {
        var corners: [String] = []
        for corner in 0..<4 { corners.append(number(points[2 * corner]) + "," + number(points[2 * corner + 1])) }
        return stringJoin(
          [
            "<polygon data-side=\"scan\" data-kind=\"", kind, "\" data-row=\"", intToString(index), "\" data-state=\"",
            state, "\" points=\"",
            stringJoin(corners, separator: " "), "\"/>",
          ], separator: "")
      }
      var parts: [String] = []
      for block in structure.editionBlocks { parts.append(rectangle(block, side: "edition", kind: "block", state: "within")) }
      for block in structure.scanBlocks { parts.append(polygon(block, kind: "block", state: "within")) }
      // The quiet first, the marked over them.
      for quiet in [true, false] {
        for (index, row) in structure.editionRows.enumerated()
        where stringEquals(structure.editionStates[index], "within") == quiet {
          parts.append(rectangle(row, side: "edition", kind: "line", state: structure.editionStates[index], index: index))
        }
        for (index, row) in structure.scanRows.enumerated()
        where stringEquals(structure.scanStates[index], "within") == quiet {
          // Each of a row's lines, the row's state: lines side by side are
          // one row (`StructurePairing.rows`).
          for line in row.lines {
            parts.append(polygon(line, kind: "line", state: structure.scanStates[index], index: index))
          }
        }
      }
      let scene = document.createElement(.div)
      scene.setAttribute("class", "artifact-structure")
      scene.setAttribute(data("key"), structure.key)
      scene.setAttribute("aria-hidden", "true")
      scene.innerHTML = stringJoin(
        ["<svg xmlns=\"http://www.w3.org/2000/svg\">", stringJoin(parts, separator: ""), "</svg>"], separator: "")
      layer.appendChild(scene)
    }

    // MARK: - Word correspondence

    /// The shown page's words and their zones on the scan, as the tools
    /// linked them (user, 2026-10-15): each `<w>`'s `@facs` names its word
    /// zones (`data-word-zones`), whose corners the scan's layout gives
    /// (`data-scan-layout`). Read once a page and layer (`key`); never
    /// worked out again in the reader.
    private struct WordLinks {
      let key: String
      /// Each linked word: its parts in the shown layer (a word broken over
      /// lines has one a line) and its boxes on the scan (left, top, right,
      /// bottom in the 0–1000 space): its zones' union a scan line, so a
      /// word the print spaces apart is one box (user, 2026-10-18); words
      /// whose space the print closes share one.
      let words: [(parts: [DOM.Element], boxes: [[Double]])]
      /// Each encoded zone on the image (copy evidence, notes, figures): its
      /// index in `TEIRenderer.elements(of:)` and its box on the scan (left,
      /// top, right, bottom in the 0–1000 space).
      let elements: [(index: Int, box: [Double])]
    }

    private var wordLinks: WordLinks?

    /// The shown page's word links (`WordLinks`); nil where Raw is shown or
    /// no page is.
    private func currentWordLinks() -> WordLinks? {
      guard !rawVisible, let layer = shownLayer(), let page = layer.closest(".tei-page") else { return nil }
      let key = (page.getAttribute(data("service-id")) ?? "") + " " + (layer.getAttribute(data("layer")) ?? "")
      if let wordLinks, stringEquals(wordLinks.key, key) { return wordLinks }
      // The word zones' boxes, by their ids and lines.
      let zones = OverlayRegistration.wordZones(scanLayout(of: page))
      // Each word's boxes, by its place ("line:word"): its zones' union a
      // scan line (`OverlayRegistration.wordBoxes`).
      var named: [(place: String, boxes: [[Double]])] = []
      for entry in stringSplit(page.getAttribute(data("word-zones")) ?? "", separator: ";") {
        let parts = stringSplit(entry, separator: " ")
        guard parts.count > 1 else { continue }
        let boxes = OverlayRegistration.wordBoxes(Array(parts[1...]), in: zones)
        if !boxes.isEmpty { named.append((parts[0], boxes)) }
      }
      // Its parts in the layer, in order.
      var words: [(parts: [DOM.Element], boxes: [[Double]])] = []
      var places: [String] = []
      for element in layer.querySelectorAll(".tei-word") {
        let place = (element.getAttribute(data("line")) ?? "") + ":" + (element.getAttribute(data("word")) ?? "")
        if let index = places.firstIndex(where: { stringEquals($0, place) }) {
          words[index].parts.append(element)
        } else if let word = named.first(where: { stringEquals($0.place, place) }) {
          places.append(place)
          words.append(([element], word.boxes))
        }
      }
      var elements: [(index: Int, box: [Double])] = []
      for entry in stringSplit(page.getAttribute(data("element-zones")) ?? "", separator: ";") {
        let parts = stringSplit(entry, separator: " ")
        guard parts.count == 5,
          let index = parseInt(parts[0]),
          let x = parseDouble(parts[1]),
          let y = parseDouble(parts[2]),
          let w = parseDouble(parts[3]),
          let h = parseDouble(parts[4]),
          w > 0, h > 0
        else { continue }
        elements.append((index, [x, y, x + w, y + h]))
      }
      let made = WordLinks(key: key, words: words, elements: elements)
      wordLinks = made
      return made
    }

    /// The edition's words marked as the scan's under the pointer.
    private var correspondingWords: [DOM.Element] = []

    /// Whether the word correspondence applies: the scan shown beside the
    /// rendered page, the overlay off.
    private var corresponds: Bool { canvasShown && !overlayOn && !overlayLeaving && !rawVisible && shownCanvas != nil }

    /// Hovering or tapping a word of the edition bands its zones on the
    /// scan in the image pane, and a word of the scan marks the edition's
    /// (user, 2026-10-14): each word's zones as the tools linked them
    /// (`WordLinks`), never a reading. A word broken over lines is one: either
    /// part bands both its zones, and either zone marks both its parts.
    private func setupCorrespondence() {
      guard let pane = markupPane else { return }
      _ = pane.addEventListener(.mouseover) { [self] event in
        guard let target = event.target else { return }
        self.pointEdition(at: target.closest(".tei-word"))
      }
      _ = pane.addEventListener(.mouseleave) { [self] _ in self.pointEdition(at: nil) }
      guard let object else { return }
      _ = object.addEventListener(.mousemove) { [self] event in self.pointScan(x: event.clientX, y: event.clientY) }
      _ = object.addEventListener(.mousedown) { [self] event in
        self.scanPress = (event.clientX, event.clientY)
        self.pointScan(x: event.clientX, y: event.clientY)
      }
      // A click on a word's band opens the word's gloss, as a click on the
      // word in the text does (user, 2026-10-18); a click on an encoded zone
      // on the image opens its gloss on the image side.
      _ = object.addEventListener(.click) { [self] event in self.openScanWord(x: event.clientX, y: event.clientY) }
      _ = object.addEventListener(.mouseleave) { [self] _ in
        self.markEdition([])
        self.shownCanvas?.clearElement()
        self.shownCanvas?.setClickable(false)
      }
    }

    /// Where the press on the scan began: a click that ends elsewhere was a
    /// pan, as the text pane's (`panMoved`).
    private var scanPress: (x: Double, y: Double)?

    /// The smallest encoded element zone containing `point` (0–1000).
    private func elementAt(_ point: (x: Double, y: Double), in links: WordLinks) -> (index: Int, box: [Double])? {
      var best: (index: Int, box: [Double], area: Double)?
      for element in links.elements {
        let box = element.box
        guard point.x >= box[0], point.x <= box[2], point.y >= box[1], point.y <= box[3] else { continue }
        let area = (box[2] - box[0]) * (box[3] - box[1])
        if best.map({ area < $0.area }) ?? true {
          best = (element.index, box, area)
        }
      }
      return best.map { ($0.index, $0.box) }
    }

    /// The edition's word of the scan's word at a point of the window, as a
    /// click on it in the text: the pane brought to it the least it takes,
    /// then the word itself clicked, so whatever a click on a word does (its
    /// gloss opens, in the pane it is in) is done, never a copy of it. A
    /// click on a copy-evidence / encoded zone on the image opens its gloss
    /// sheet on the image side. A press that moved panned the image: nothing
    /// opens.
    private func openScanWord(x: Double, y: Double) {
      guard let press = scanPress, press.x == x, press.y == y else { return }
      scanPress = nil
      guard corresponds, let canvas = shownCanvas, let point = canvas.spacePoint(clientX: x, clientY: y),
        let links = currentWordLinks()
      else { return }
      if let word = links.words.first(where: { linked in
        linked.boxes.contains { point.x >= $0[0] && point.x <= $0[2] && point.y >= $0[1] && point.y <= $0[3] }
      }), let part = word.parts.first {
        markEdition(word.parts)
        part.click()
        return
      }
      if let element = elementAt(point, in: links), let object {
        object.dispatchEvent(
          CustomEvent(
            type: "artifact-image-element",
            detail: stringJoin([canvas.serviceID, intToString(element.index)], separator: " ")))
      }
    }

    /// The scan's zones of an edition word, banded, and its other parts
    /// marked; none clears them.
    private func pointEdition(at word: DOM.Element?) {
      guard let canvas = shownCanvas else { return }
      guard let word, corresponds, let links = currentWordLinks(),
        let linked = links.words.first(where: { $0.parts.contains { $0.id == word.id } })
      else {
        mark([])
        canvas.showWord([])
        return
      }
      mark(linked.parts.filter { $0.id != word.id })
      canvas.showWord(linked.boxes)
    }

    /// The edition's words of the scan's word under a point of the window
    /// (each word whose zones hold it: words whose space the print closes
    /// share one), marked, and their zones banded; or an encoded zone on the
    /// image outlined in neutral borderColorBase; none clears them.
    private func pointScan(x: Double, y: Double) {
      guard corresponds, let canvas = shownCanvas, let point = canvas.spacePoint(clientX: x, clientY: y),
        let links = currentWordLinks()
      else {
        markEdition([])
        shownCanvas?.clearElement()
        shownCanvas?.setClickable(false)
        return
      }
      let found = links.words.filter { word in
        word.boxes.contains { point.x >= $0[0] && point.x <= $0[2] && point.y >= $0[1] && point.y <= $0[3] }
      }
      if !found.isEmpty {
        canvas.clearElement()
        canvas.setClickable(true)
        markEdition(found.flatMap { $0.parts })
        canvas.showWord(found.flatMap { $0.boxes })
        return
      }
      markEdition([])
      if let element = elementAt(point, in: links) {
        let box = element.box
        canvas.setClickable(true)
        canvas.showElement(x: box[0], y: box[1], width: box[2] - box[0], height: box[3] - box[1])
      } else {
        canvas.clearElement()
        canvas.setClickable(false)
      }
    }

    /// Edition words marked as corresponding; the others unmarked.
    private func mark(_ words: [DOM.Element]) {
      for previous in correspondingWords where !words.contains(where: { $0.id == previous.id }) {
        previous.removeAttribute(data("corresponding"))
        unband(previous)
      }
      for word in words {
        word.setAttribute(data("corresponding"), "true")
        band(word)
      }
      correspondingWords = words
    }

    /// A face's ink envelope at the reference size, measured once per face
    /// (`faceEnvelope`): the font's ascent above the baseline, and the ink
    /// of the tallest ascenders and deepest descenders it draws.
    private struct FaceEnvelope {
      let face: String
      let fontAscent: Double
      let inkAscent: Double
      let inkDescent: Double
    }

    private var faceEnvelopes: [FaceEnvelope] = []

    /// The size a face is measured at, large enough that its metrics are not
    /// rounded to pixels; an envelope scales linearly from it.
    private static let envelopeSize = 200.0

    /// Characters whose ink reaches the face's highest and lowest: accented
    /// capitals and tall letters above the baseline, descenders and the bar
    /// below it.
    private static let envelopeProbe = "ÉÅfhgjpqy|"

    /// The face's envelope, from `measureText` of the probe at the reference
    /// size, kept per face (style, weight, family, caps) so every word of a
    /// face shares it.
    private func faceEnvelope(style: String, weight: String, family: String, caps: String) -> FaceEnvelope? {
      let face = style + " " + weight + " " + family + " " + caps
      if let known = faceEnvelopes.first(where: { stringEquals($0.face, face) }) { return known }
      guard let context = document.createElement("canvas").getContext("2d") else { return nil }
      context.font = style + " " + weight + " " + doubleToString(Self.envelopeSize) + "px " + family
      context.fontVariantCaps = caps
      let metrics = context.measureText(Self.envelopeProbe)
      guard metrics.fontBoundingBoxAscent > 0, metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent > 0
      else { return nil }
      let made = FaceEnvelope(
        face: face, fontAscent: metrics.fontBoundingBoxAscent, inkAscent: metrics.actualBoundingBoxAscent,
        inkDescent: metrics.actualBoundingBoxDescent)
      faceEnvelopes.append(made)
      return made
    }

    /// The band a corresponding word wears, drawn to hug the word (user,
    /// 2026-10-18): across, the glyphs' extent (the word's box, less the
    /// letter-spacing that trails its last letter); down, a constant of the
    /// typeface scaled by the word's own font size—the face's ink envelope
    /// (`faceEnvelope`) set on the baseline—so words of one size on a line
    /// share one band whatever letters they hold, and a smaller or larger
    /// span's band is proportionally smaller or larger.
    /// Set as the word's `--artifact-band-*` in its own pixels (the layer's
    /// zoom taken out), which the viewer's rule paints; a word set on more
    /// than one line keeps the plain fill.
    private func band(_ word: DOM.Element) {
      unband(word)
      let range = document.createRange()
      range.setStart(word, 0)
      range.setEnd(word, word.childNodes.count)
      let rects = range.getClientRects().filter { $0.width > 0 && $0.height > 0 }
      guard let first = rects.first, let own = word.getBoundingClientRect(), word.offsetWidth > 0,
        rects.allSatisfy({ $0.top < first.bottom && first.top < $0.bottom })
      else { return }
      let scale = own.width / word.offsetWidth
      guard scale > 0 else { return }
      var left = first.left, right = first.right, top = first.top, bottom = first.bottom
      for rect in rects {
        left = min(left, rect.left)
        right = max(right, rect.right)
        top = min(top, rect.top)
        bottom = max(bottom, rect.bottom)
      }
      let style = window.getComputedStyle(word)
      // Down: the face's envelope at the word's font size, as drawn (the
      // layer's zoom taken in), placed on the baseline the inline box's top
      // sits a font ascent above.
      let size = pixels(style.getPropertyValue("font-size")) * scale
      if size > 0, let face = faceEnvelope(
        style: style.getPropertyValue("font-style"), weight: style.getPropertyValue("font-weight"),
        family: style.getPropertyValue("font-family"), caps: style.getPropertyValue("font-variant-caps"))
      {
        let unit = size / Self.envelopeSize
        let baseline = first.top + face.fontAscent * unit
        top = baseline - face.inkAscent * unit
        bottom = baseline + face.inkDescent * unit
      }
      let spacing = max(0, pixels(style.getPropertyValue("letter-spacing"))) * scale
      if stringEquals(style.getPropertyValue("direction"), "rtl") { left += spacing } else { right -= spacing }
      guard right > left else { return }
      func local(_ value: Double) -> String { doubleToString(value / scale) + "px" }
      word.style.setProperty("--artifact-band-x", local(left - own.left))
      word.style.setProperty("--artifact-band-y", local(top - own.top))
      word.style.setProperty("--artifact-band-width", local(right - left))
      word.style.setProperty("--artifact-band-height", local(bottom - top))
      word.setAttribute(data("band"), "true")
    }

    private func unband(_ word: DOM.Element) {
      guard word.hasAttribute(data("band")) else { return }
      word.removeAttribute(data("band"))
      for name in ["x", "y", "width", "height"] { _ = word.style.removeProperty("--artifact-band-" + name) }
    }

    /// Edition words marked as corresponding, the first brought into the
    /// pane's view the least it takes; none unmarks them (and the scan's
    /// bands).
    private func markEdition(_ words: [DOM.Element]) {
      mark(words)
      guard let word = words.first else {
        shownCanvas?.showWord([])
        return
      }
      guard let pane = markupPane, let paneBox = pane.getBoundingClientRect(), let box = word.getBoundingClientRect()
      else { return }
      let top = box.top - paneBox.top - pane.clientTop
      let left = box.left - paneBox.left - pane.clientLeft
      let height = pane.clientHeight
      let width = pane.clientWidth
      var moved = false
      if top < 0 || top + box.height > height {
        pane.scrollTop += top < 0 ? top : top + box.height - height
        moved = true
      }
      if left < 0 || left + box.width > width {
        pane.scrollLeft += left < 0 ? left : left + box.width - width
        moved = true
      }
      // The pane moved to show the scan's word: no move to match back.
      if moved { matchedScroll = (pane.scrollLeft, pane.scrollTop) }
    }

    private func navigate(_ delta: Int) {
      let next = canvasIndex + delta
      guard next >= 0, next < serviceIDs.count else { return }
      loadCanvas(next)
    }

  }
#endif
