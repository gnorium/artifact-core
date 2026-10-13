# Repository guidance

This directory is its own Git repository. The parent Gnorium workspace is not a repository; run Git commands here and inspect sibling repositories separately.

- Preserve unrelated working changes. When renaming an internal API, update callers in sibling packages rather than leave obsolete aliases.
- Run focused checks for the changed behavior. Do not run full server/browser suites unless requested.
- Keep build caches and `.build` directories. Diagnose build/toolchain errors before rebuilding; do not wipe caches to troubleshoot.
- Batch related changes before building. Deployment requires an explicit user request; a local build or server restart is not deployment.
- If committing authorized work, omit attribution trailers and push normally after the commit; never force-push.

## Embedded Swift client

- CLIENT-reachable code includes unguarded helpers called by hydration. Use `EmbeddedSwiftUtilities` string helpers rather than Unicode normalization, String-keyed dictionaries/sets, or String equality/hash operations.
- Prefer pattern matching for optional strings and String-backed enums. Diagnose undefined WASM symbols from their call sites instead of guessing or clearing caches.
- Separate DOM queries return fresh Swift wrappers. Compare the bridge's stable numeric node IDs, not Swift reference identity (`===`).
- Add missing standard browser APIs to the bridge and typed API packages rather than simulate them in views.

## TEI fidelity and layout

- Preserve the exact source reading and whitespace evidence. Linguistic alternatives and annotations go beside the reading, never replace it.
- Use standard TEI structure: physical `pb`, `cb`, `lb`, supported rendition settings, and explicit vertical spaces. Text coordinates, text bounding boxes, and absolute positioning are excluded; existing figure/initial zones remain supported.
- A `pb` label identifies the surface and is not synthetic page text. Display numbers actually printed on the page through `fw type="pageNum"`.
- Contents pages use `table type="contents"`, one row per entry, separate title/reference cells, indentation inside title cells, and continuation lines within their entry.
- Left alignment is the default; justify only explicit `align(justify)` settings. Some drift from the scan is acceptable.

## Paired panes

Keep zoom/pan synchronization free of feedback loops: only reader gestures drive matching, the latest queued gesture wins, and layout measurements preserve scroll and zoom anchors. Center a stable page frame, not shrink-wrapped short text.

XML/code mode scrolls normally; it is independent of image zoom. Detach remains visible but disabled where pairing cannot apply. Recover from transient manifest failures without requiring a refresh.
