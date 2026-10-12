# Study Timer v1

Status: approved, not implemented.

## Context

The owner logs study sessions in Notion (`📚 Daily Study Stats`, linked to cards in
`My Learning Path`). After every session they open Notion, pick a card, type a title, and enter
the date range. A Notion analysis on 2026-10-13 (654 sessions since 2023-06) found:

- 68% of sessions were created after they ended and 18% before they started, so almost nothing
  is logged live.
- 70% start and end exactly on a quarter hour, so durations are estimates.
- 7 sessions have zero length and 25 have no card, so both are missing from the card rollups.
- Titles are short and repeated per card ("job", "english", "drill N").
- Only 3 cards were used in the last 6 weeks, although 5 are marked "Doing".
- Until 2026-07-28, 108 sessions were each linked to 3 cards (child plus umbrella cards); since
  then each links to 1.

The goal is a menu bar app that removes this friction: pick cards, time the session, commit one
accurate row.

## Behavior

- **Menu bar:** an icon when idle. While running it shows the countdown's remaining time,
  `+mm:ss` in overtime, or stopwatch elapsed time. While paused it shows `⏸` before the time.
  ⌃⌥S toggles the popover.
- **Stats:** a rolling last 24 hours of all sessions in the database, including ones entered
  manually in Notion. It shows the total, time per card, and a session list. Only the part of a
  session inside the window counts. Commits not yet synced are shown and marked.
- **Start:**
  - Multi-select cards with search. Cards are ranked by frecency (last 90 days, 7-day half-life),
    then status "Doing", then name.
  - The editable title defaults to the last title used for the card, then the card name, then
    empty.
  - Mode is a stopwatch, or a countdown with presets 25/45/60/90 or custom minutes.
- **Pause:** manual pause and resume. System sleep pauses, and the timer stays paused on wake.
  Screen lock does not pause.
- **Alarm:** when the countdown reaches zero, a sound loops and a notification banner appears.
  The timer keeps counting overtime. Mute silences the sound only.
- **Finish:**
  - Commit with overtime, or commit only the planned time.
  - Discard asks for confirmation.
- **Commit:** one Notion row with the title, `Interval = [end − active time, end]` at exact
  seconds, and the selected cards.
  - `end` is now, or the pause moment if paused.
  - "Without overtime" uses the moment the alarm hit.
- **Retries:**
  - Failed commits are saved on disk and retried with backoff, and again when the network
    returns.
  - Before each retry the app checks Notion for an existing match so it never duplicates a row.
  - Permanent errors are shown with Retry and Discard.
- **Settings (in the popover):** API key (Keychain), sessions data source ID (prefilled), alarm
  sound, and launch at login (on by default).
- **Out of scope:** editing times, rounding, logging past sessions, creating cards.

## Architecture

- **Code:** Swift 6.4, built as a SwiftPM package with the Command Line Tools; `build.sh` makes
  the `.app`.
- **Menu bar:** AppKit `NSStatusItem` with an `NSPopover` that hosts SwiftUI. `MenuBarExtra`
  can't be opened programmatically, and the hotkey needs that.
- **Hotkey:** Carbon `RegisterEventHotKey`, no dependencies.
- **Notion:** REST with `Notion-Version: 2025-09-03`.
  - `POST /v1/data_sources/{id}/query` lists sessions and cards.
  - `POST /v1/pages` with `parent: {type: data_source_id}` creates a session.
  - At launch the app resolves the title, date, and relation properties by type from
    `GET /v1/data_sources/{id}`. The cards data source comes from the relation's
    `data_source_id`.
- **Timer state:** `accumulated + (segmentStart → now)`, computed from wall-clock dates and saved
  on every state change. Ticks are never counted.
- **Sleep:** `NSWorkspace.willSleepNotification` triggers pause.
- **Alarm:** a looping `NSSound` plus `UNUserNotificationCenter`.
- **Login item:** `SMAppService.mainApp`.
- **Persistence:** JSON files in Application Support hold the active session and the retry queue.
  The API key is stored only in the Keychain.

## Files

- `Package.swift`, `build.sh`, `Info.plist` (`LSUIElement`)
- `Sources/StudyTimer/`: `App`, `StatusBarController`, `HotKey`, `AppModel`, `ActiveSession`,
  `NotionClient`, `CommitQueue`, `Alarm`, `Keychain`, `Persistence`, `Views/`
- `Tests/` (Swift Testing): pause/sleep/overtime math, commit interval math, 24-hour overlap,
  ranking, Notion date parsing

## Verification

1. `swift test`.
2. Build and install with `build.sh`. The owner enters the API key in Settings.
3. Run a 1-minute countdown and check the alarm, mute, and overtime. Commit once with overtime and
   once without, then confirm both rows in Notion. These are real rows in the owner's database:
   ask before creating them.
4. Run `pmset sleepnow` mid-session. The timer should be paused and stay paused after wake.
5. Commit with Wi-Fi off; the commit should be queued. Turn Wi-Fi on; it should sync exactly once.

Prerequisite: the owner creates a Notion internal integration and connects it to both databases.
