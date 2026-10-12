# Tech Context

## Architecture

Decided but not built. The full spec is in
[plans/2026-10-13_study-timer-v1.md](../plans/2026-10-13_study-timer-v1.md).

- The app is a SwiftPM package in Swift 6.4 with strict concurrency. UI state runs on
  `@MainActor`. It has no third-party dependencies.
- The shell script `build.sh` assembles the `.app` bundle (`LSUIElement`) and ad-hoc signs it.
  The owner accepts shell for build scripts in this repo.
- The menu bar uses an AppKit `NSStatusItem` with an `NSPopover` that hosts SwiftUI.
- The app MUST NOT use `MenuBarExtra`. `MenuBarExtra` cannot be opened programmatically, and the
  ⌃⌥S hotkey needs that.
- The hotkey uses Carbon `RegisterEventHotKey`. It needs no Accessibility permission.
- Elapsed time equals `accumulated + (now − segmentStart)` from wall-clock `Date`s. The app MUST
  NOT count ticks. Tick counting drifts across sleep and lag.
- The app saves the active session on every state change. A quit or crash keeps it.
- A commit writes `Interval = [end − activeTime, end]` at exact seconds. Pauses move the start
  later.
- `end` is the commit moment. When paused, `end` is the pause moment. "Commit without overtime"
  uses the moment elapsed time reached the target.
- `NSWorkspace.willSleepNotification` pauses the timer. The timer stays paused after wake. Screen
  lock MUST NOT pause it.

## External contracts

- The Notion API uses `Notion-Version: 2025-09-03`.
- `POST /v1/data_sources/{id}/query` returns at most 100 rows. Follow `next_cursor`.
- `POST /v1/pages` creates a row with `parent: {type: "data_source_id", data_source_id}`.
- A relation schema exposes `data_source_id`. Relation writes accept `data_source_id` only.
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
- Cards have `Name` (title) and a `Status` select. The status options are Doing, Done 🙌, Gave Up,
  Backlog, and On Hold.
- The cards self-relation `Relations` links umbrella cards and child cards. The rollup
  `Time Spent (hours)` sums each card's session `Hours`.
- Notion date strings arrive in three forms: with milliseconds, without them, or date-only. The
  offset is `Z` or `+00:00`. The parser MUST handle every form.
- How date filters treat range ends is unverified. The app queries a 90-day window by start date.
  It computes the 24-hour overlap locally.
- A create request that times out may still succeed. Before a retry, the app MUST look for a row
  with the same title and a start within ±60 s.

## Constraints

- The Notion API key lives only in the macOS Keychain.
- Ad-hoc signing changes the code signature on every rebuild. macOS then asks once for Keychain
  access.

## Environment

- The Mac runs macOS 27.0.1 with Command Line Tools only. Xcode is not installed. `xcodebuild` is
  unavailable.
- The toolchain is Swift 6.4 with the macOS 27 SDK. Observation macros, Swift Testing, and
  `swift format` are available.
- Code MUST NOT use `#Preview`. Its macro plugin ships only with Xcode.
- The Mac has no code-signing identities. Builds use ad-hoc signing.

## Commands

Build, test, and install commands: _Not yet established._
