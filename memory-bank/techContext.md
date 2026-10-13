# Tech Context

## Architecture

Implementation steps 1 to 5 are built. The rest is decided but not built. The full spec is in
[plans/2026-10-13_study-timer-v1.md](../plans/2026-10-13_study-timer-v1.md).

- The app is a SwiftPM package in Swift 6.4 with strict concurrency. UI state runs on
  `@MainActor`. It has no third-party dependencies.
- The shell script `build.sh` assembles the `.app` bundle (`LSUIElement`) and ad-hoc signs it.
  The owner accepts shell for build scripts in this repo.
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
- `NSWorkspace.willSleepNotification` pauses the timer. The timer stays paused after wake. Screen
  lock MUST NOT pause it.

## External contracts

- The Notion API uses `Notion-Version: 2025-09-03`.
- `POST /v1/data_sources/{id}/query` returns at most 100 rows. Follow `next_cursor`.
- `POST /v1/pages` creates a row with `parent: {type: "data_source_id", data_source_id}`.
- A relation schema exposes `data_source_id`. Relation schema writes accept `data_source_id` only.
  A page's relation value is a list of page IDs.
- The sessions database is `📚 Daily Study Stats`. Its database ID is
  `<redacted>`. Its data source ID is
  `<redacted>`.
- Sessions have `Title` (title), `Interval` (datetime range), a relation to cards, and formulas
  `Minutes` and `Hours`. The relation is named
  `My Learning Path: Organizing and Achieving Study Goals!`.
- The app MUST resolve the title, date, and relation properties by type. Name lookups break when
  the owner renames a property.
- The cards database is `My Learning Path`. Its database ID is
  `<redacted>`. Its data source ID is
  `<redacted>`.
- Cards have `Name` (title) and two selects, `Status` and `Priority`. Two selects rule out a type
  lookup. The app MUST find `Status` by name. Without it, ranking drops the "Doing" tie-break. The
  status options are Doing, Done 🙌, Gave Up, Backlog, and On Hold.
- The cards self-relation `Relations` links umbrella cards and child cards. The rollup
  `Time Spent (hours)` sums each card's session `Hours`.
- The session-to-card relation is two-way. Cards show it as `📚 Daily Study Stats`.
- Manual testing writes to a separate `Study Timer Test` database. It has `Title` (title),
  `Interval` (date), and `Cards`, a one-way relation to cards, so the cards schema stays unchanged.
  Its database ID is `<redacted>`. Its data source ID is
  `<redacted>`. Its test rows from 2026-10-12 and 2026-10-13 link only to
  `English Speaking` and `German A1`. They raise those cards in the ranking.
- All three databases are top-level pages. The integration MUST be connected to each one. Nothing
  inherits access. The owner's integration has Read content and Insert content and is connected to
  all three.
- Notion stores date-times to the minute and drops the seconds. Every interval the app writes
  MUST use whole minutes, or the stored duration drifts by up to a minute.
- Notion date strings arrive in three forms: with milliseconds, without them, or date-only. The
  offset is `Z` or `+00:00`. The parser MUST handle every form.
- How date filters treat range ends is unverified. The app queries a 90-day window by start date.
  It computes the 24-hour overlap locally.
- A create request that times out may still succeed. Before a retry, the app MUST look for a row
  with the same title and a start within ±60 s.

## Constraints

- The Notion API key lives only in the macOS Keychain.
- Ad-hoc signing changes the code signature on every rebuild. A rebuilt app still reads its Keychain
  item without a prompt, so rebuilding during a checkpoint is safe.
- macOS 27 draws status items in the Window Server. A status item click cannot activate the app.
  `NSApp.activate()` works from the Carbon hotkey only.
- Computer use MUST NOT put live Notion data on screen. The permission system blocks it. Checkpoints
  use rows in `Study Timer Test`.
- An accessory app has no menu bar. Text fields get ⌘V, ⌘C, ⌘A, and ⌘Z only from the Edit menu the
  app sets as `NSApp.mainMenu`.

## Environment

- The Mac runs macOS 27.0.1 with Command Line Tools only. Xcode is not installed. `xcodebuild` is
  unavailable.
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
- Claude's shell has no Screen Recording permission, so `screencapture` fails. To render a view
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
- The CoreGraphics overlay in this SDK has no `drawConicGradient`. Draw a gradient ring as short
  arcs with interpolated colors.
- macOS 27 shows a full-bleed rounded-square `.icns` with a glass edge and no gray backing tile.
- The Mac has no code-signing identities. Builds use ad-hoc signing.
- The installed prototype also registers ⌃⌥S. It MUST NOT run while the app is under test.

## Commands

- `./build.sh` builds the release binary, assembles and ad-hoc signs `Study Timer.app`, stops a
  running copy, and installs the app to `~/Applications`.
- `open "$HOME/Applications/Study Timer.app" --args --regular` launches the app for computer use.
- `swift test` runs the Swift Testing suite.
