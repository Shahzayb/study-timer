# Tech Context

## Architecture

All eight implementation steps are built. The full spec is in
[plans/2026-10-13_study-timer-v1.md](../plans/2026-10-13_study-timer-v1.md).

- The app is a SwiftPM package in Swift 6.4 with strict concurrency. UI state runs on
  `@MainActor`. It has no third-party dependencies.
- The shell script `build.sh` assembles the `.app` bundle (`LSUIElement`) and ad-hoc signs it.
  Build scripts MAY use shell.
- The menu bar uses an AppKit `NSStatusItem` with an `NSPopover` that hosts SwiftUI. The popover
  window is a non-activating panel, so it takes the keyboard while the previous app stays active.
- The app MUST NOT use `MenuBarExtra`. `MenuBarExtra` cannot be opened programmatically, and the
  ⌃⌥S hotkey needs that.
- The hotkey uses Carbon `RegisterEventHotKey`. It needs no Accessibility permission.
- Elapsed time equals `accumulated + (now − segmentStart)` from wall-clock `Date`s. The app MUST
  NOT count ticks. Tick counting drifts across sleep and lag.
- The app saves the active session on every state change, plus a heartbeat every 30 s while it
  runs. A quit, crash, or shutdown keeps it. A running session restores as paused at its last
  heartbeat, so downtime never counts.
- A commit writes `Interval = [end − activeTime, end]` in whole minutes. `activeTime` rounds to
  the nearest minute. Pauses move the start later.
- `end` is the commit moment floored to the minute. When paused, `end` is the pause moment.
  "Commit without overtime" uses the moment elapsed time reached the target.
- System sleep and screen lock pause the timer, because both mean the user is away. The timer
  stays paused after wake or unlock.

## External contracts

- The Notion API uses `Notion-Version: 2025-09-03`.
- `POST /v1/data_sources/{id}/query` returns at most 100 rows. Follow `next_cursor`.
- `POST /v1/pages` creates a row with `parent: {type: "data_source_id", data_source_id}`.
- A relation schema exposes `data_source_id`. Relation schema writes accept `data_source_id` only.
  A page's relation value is a list of page IDs.
- The sessions data source has exactly one title, one date, and one relation property. The
  relation points to the cards data source. The app stores the sessions data source ID under the
  `dataSourceID` default.
- The app MUST resolve the title, date, and relation properties by type. Name lookups break when
  a property is renamed.
- Cards have a title and MAY have several selects, which rules out a type lookup. The app MUST
  find `Status` by name, as a select or a status property. Without it, ranking drops the "Doing"
  tie-break.
- Insert content is enough to write a two-way relation.
- Manual testing SHOULD write to a separate test database with a title, a date, and a one-way
  relation to the cards, so the cards schema stays unchanged. Test rows still raise their cards in
  the ranking.
- An internal integration reaches only the top-level pages it is connected to. Nothing inherits
  access. A personal access token reaches every page its user can open.
- Notion stores date-times to the minute and drops the seconds. Every interval the app writes
  MUST use whole minutes, or the stored duration drifts by up to a minute.
- Notion date strings arrive in three forms: with milliseconds, without them, or date-only. The
  offset is `Z` or `+00:00`. The parser MUST handle every form.
- How date filters treat range ends is unverified. The app queries a 90-day window by start date.
  It computes the overlap with today locally.
- A create request that times out may still succeed. Before a retry, the app MUST look for a row
  with the same title and a start within ±60 s.

## Constraints

- The repo is public. It MUST NOT hold Notion IDs, tokens, email addresses, local paths, or other
  personal data.
- The Notion token lives only in the macOS Keychain.
- Ad-hoc signing changes the code signature on every rebuild. A rebuilt app still reads its Keychain
  item without a prompt, so rebuilding during a checkpoint is safe. `SMAppService.mainApp`
  registers the app without an approval prompt, and the login item stays enabled across rebuilds.
- macOS 27 draws status items in the Window Server. A status item click cannot activate the app.
  `NSApp.activate()` works from the Carbon hotkey only.
- Computer use MUST NOT put live Notion data on screen. Checkpoints use the test database.
- An accessory app has no menu bar. Text fields get ⌘V, ⌘C, ⌘A, and ⌘Z only from the Edit menu the
  app sets as `NSApp.mainMenu`.

## Environment

- The project builds with Command Line Tools only. It MUST NOT need Xcode or `xcodebuild`.
- The toolchain is Swift 6.4 with the macOS 27 SDK. Observation macros, Swift Testing, and
  `swift format` are available.
- Code MUST NOT use `#Preview`. Its macro plugin ships only with Xcode.
- The macOS 27 SDK declares `@State`, `@Entry`, and `@Animatable` as `SwiftUIMacros` macros. That
  plugin ships only with Xcode, so code MUST NOT use them. Store view state as a plain property,
  `private let hovering = State(initialValue: false)`, and use `hovering.wrappedValue`.
- `swift format` runs with its defaults, including 2-space indentation. The repo has no
  `.swift-format` file.
- The default build system does not load the Swift Testing macro plugin. The test target MUST pass
  `-plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing` through
  `.unsafeFlags` in its `swiftSettings`. Without it, `@Test` fails to expand.
  `--build-system native` cannot find the `Testing` module.
- Claude cannot hear the alarm or see notification banners, because screenshots hide Notification
  Center. `/usr/bin/log show` reveals both: `audiomxd` logs the app's audio session going active
  and inactive, and `usernoted` logs each delivery. In zsh, plain `log` is a shell builtin.
- Banners appear only after the user clicks Allow on the first permission prompt. Claude cannot
  unlock the screen, wake the Mac, or switch Wi-Fi, so a person runs the lock, sleep, and offline
  checks. A hand-written `commit-queue.json`, written while the app is not running, can stage
  duplicate and permanent-failure cases.
- Without Screen Recording permission, `screencapture` fails in Claude's shell. To render a view
  to PNG in-process, use `CALayer.render(in:)`. `NSView.cacheDisplay` drops SwiftUI content.
  Neither renders window materials.
- An in-process capture MUST NOT activate the app. Keystrokes typed during the capture land in
  the popover. An inactive app draws prominent controls gray. Setting `controlActiveState` to
  `.key` fixes SwiftUI-drawn controls. It does not fix AppKit-backed ones such as segmented
  pickers.
- Computer use cannot list or target an `LSUIElement` app. It can target the same app under a
  regular activation policy. A popover has no AX window, so the background `app_*` tools fail on
  it. Full-screen screenshots and clicks reach it. A full-screen `zoom` with `save_to_disk` keeps
  real screenshots. A debug hotkey that steps through mock states lets one batch capture every
  state.
- Computer use hides apps outside its allowlist, so a capture shows the popover over black. Over
  black, each pixel equals color × alpha. The alpha channel of `docs/screenshot.png` holds the
  popover's shape. A new cutout MAY reuse it while the arrow sits centered.
- `save_to_disk` writes JPEG in the display's color profile. Convert it to sRGB before saving a PNG.
- The popover closes when another app takes focus, so a long wait with it open can lose the shot.
  Close it with ⌃⌥S after Start and reopen it about 0.5 s before the capture.
- Opening the popover refreshes data older than 30 s, and the footer shows a spinner meanwhile.
  Open and close it about 30 s before the capture, so the final open skips the refresh.
- A countdown label holds each second for one second, and the view redraws every 0.5 s. Three
  zooms 0.3 s apart in one batch catch a target time.
- Picking a card fills the title with the card name. Press ⌘A in the title field before typing.
  Discard needs two clicks within 3 s, so both clicks MUST go in one batch.
- A demo session saves its length in the `minutes` default. Restore the owner's preset afterward.
- macOS 27 shows a full-bleed rounded-square `.icns` with a glass edge and no gray backing tile.
- Builds use ad-hoc signing, so they need no signing identity.

## Commands

- `./build.sh` builds the release binary, assembles and ad-hoc signs `Study Timer.app`, stops a
  running copy, and installs the app to `~/Applications`.
- `open "$HOME/Applications/Study Timer.app" --args --regular` launches the app for computer use.
- `swift test` runs the Swift Testing suite.
