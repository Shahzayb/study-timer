# Study Timer v1

Status: draft. Approval waits on the UI spec.

Read first: `CLAUDE.md`, then `memory-bank/progress.md`, `memory-bank/projectbrief.md`, and
`memory-bank/techContext.md`. `techContext.md` holds the Notion IDs, the API contracts, and the
toolchain limits. This plan does not repeat them.

## Context

The owner logs study sessions in Notion (`📚 Daily Study Stats`, linked to cards in
`My Learning Path`). After every session they open Notion, pick a card, type a title, and enter
the date range. A Notion analysis on 2026-10-13 (654 sessions since 2023-06) found:

- 68% of sessions were created after they ended. 18% were created before they started. Almost
  nothing is logged live.
- 70% start and end exactly on a quarter hour. Durations are estimates.
- 7 sessions have zero length. 25 have no card. Both are missing from the card rollups.
- Titles are short and repeat per card ("job", "english", "drill N").
- Only 3 cards were used in the last 6 weeks. 5 cards are marked "Doing".
- Until 2026-07-28, 108 sessions each linked to 3 cards (a child card plus umbrella cards). Since
  then each session links to 1 card.

The goal is a menu bar app that removes this friction. The owner picks cards, times the session,
and commits one accurate row.

## Quality bar

- The app MUST look like a native macOS menu bar extra. Use system controls, SF Symbols, the
  system font, and system materials.
- The UI MUST be minimal and modern. Use little text, clear icons, and high contrast.
- The popover MUST keep a fixed size of 340 × 400 pt. Long content scrolls inside it.
- Controls and bars use the system accent color. Bars MUST be solid. Only the timer ring and the
  app icon use the brand gradient of cyan, violet, and pink.
- The app icon and the idle menu bar glyph MUST differ from system timer icons. Both use a ring
  mark that is 80% filled.
- Manual testing by Claude and the owner is the primary verification. Unit tests cover timing
  math, date parsing, ranking, and retry logic.

## UI spec

_Not yet written._

1. Claude builds a throwaway SwiftUI prototype outside the repo. It shows every popover state in a
   real popover: first run, start, running, paused, alarm, finish, commit error, and settings.
2. Claude screenshots each state. The owner clicks through the prototype.
3. After the owner approves, this section records each state's layout, keyboard flow, and its
   empty, loading, and error states.

Implementation MUST NOT start before the owner approves this section.

## Behavior

### Menu bar

- Idle: an icon only.
- Running countdown: the remaining time. Overtime: `+mm:ss`. Stopwatch: the elapsed time.
- Paused: `⏸` before the time.
- The time MUST use monospaced digits.
- ⌃⌥S toggles the popover. Opening activates the app so the card search field gets focus.
- First run with no API key opens the popover on Settings.

### Stats

- The stats cover a rolling last 24 hours of all sessions in the database. Rows entered manually
  in Notion count.
- The panel shows the total, time per card, and a session list.
- Only the part of a session inside the window counts.
- A session linked to several cards counts toward each card. It counts once in the total.
- Queued commits appear in the stats, marked as not synced.
- A fetched row with the same title and a start within ±60 s hides the matching queued commit.
- Refresh on popover open when data is older than 30 s, and after every commit.

### Start

- Cards are multi-select with search. Selected cards stay at the top of the list.
- Ranking: frecency first. Each session in the last 90 days adds `0.5^(ageDays / 7)` to its cards.
  Ties sort by status "Doing" first, then by name. Without a `Status` property, ties sort by name.
- The title is editable. Its default chain:
  1. The title of the most recent session linked to the first selected card.
  2. The first selected card's name.
  3. Empty.
- A manual title edit MUST stop the default from overwriting it when the card selection changes.
- Start requires at least one selected card.
- Mode: stopwatch, or countdown. Countdown presets are 25, 45, 60, and 90 minutes. A custom
  minutes field is always available.
- The app remembers the last mode and duration.
- Refresh cards on launch and on popover open when older than 10 minutes.

### Running

- Pause and resume are manual.
- System sleep pauses. The timer stays paused after wake. Screen lock MUST NOT pause.
- A quit, crash, or shutdown keeps the session. A running session comes back paused at its last
  heartbeat. Time while the app was not running MUST NOT count.
- At zero, the countdown starts the alarm:
  - A sound loops until the owner mutes it, pauses, or ends the session. Resume MUST NOT restart
    it.
  - A notification banner appears.
  - The timer keeps counting overtime.
- Mute silences the sound only. The timer keeps counting.
- The notification is scheduled on start or resume for the remaining time and cancelled on pause.
- Request notification permission at the first countdown start.
- The `--fast-countdown` launch argument runs countdown minutes as seconds. It exists for manual
  testing only. The UI does not show it.

### Finish

- Commit with overtime. In a countdown after the alarm, a second button commits the planned time
  only.
- Commit is disabled while the active time is zero.
- Discard asks for an inline confirmation.
- A commit writes one Notion row with the title, `Interval = [end − activeTime, end]` at exact
  seconds, and the selected cards.
  - `end` is the commit moment. When paused, `end` is the pause moment.
  - "Planned time only" sets `end` to the moment elapsed time reached the target. The duration
    equals the target.

### Retries

- Every commit enters a queue on disk before the first request.
- Retry after 30 s, 1 m, 2 m, and then every 5 m. Retry immediately when the network returns
  (`NWPathMonitor`) and on popover open.
- On 429, wait for `Retry-After`. Timeouts and 5xx errors retry.
- 400, 401, 403, and 404 errors are permanent. The UI shows the error with Retry and Discard.
- Before any retry, look for an existing row with the same title and a start within ±60 s. A
  match marks the commit as done.

### Settings

- Settings live inside the popover.
- Fields: API key (Keychain), sessions data source ID (prefilled from `techContext.md`), alarm
  sound, and launch at login.
- Launch at login is on by default.
- Alarm sound: a picker over `/System/Library/Sounds`. The default sound is `Glass`.

### Out of scope

Editing times, rounding, logging past sessions, and creating cards.

## Architecture

- **Package:** a SwiftPM executable built with the Command Line Tools. `build.sh` builds the
  release binary and assembles `Study Timer.app`. It writes `Info.plist` with `LSUIElement` and
  bundle ID `dev.local.StudyTimer`, ad-hoc signs the app, and installs it to `~/Applications`.
  Manual testing MUST use the installed bundle. Notifications and the login item need a bundle,
  so `swift run` cannot exercise them.
- **Menu bar:** an AppKit `NSStatusItem` with an `.transient` `NSPopover` that hosts SwiftUI.
- **App icon:** a Swift script draws `AppIcon.icns` through `iconutil`. `build.sh` bundles it.
  `actool` and Icon Composer need Xcode.
- **Computer use:** the `--regular` launch argument sets a regular activation policy, so computer
  use can list and target the app.
- **Hotkey:** Carbon `RegisterEventHotKey` for ⌃⌥S.
- **Notion:** `URLSession` with async/await and `Codable`. At launch the app resolves the title,
  date, and relation properties by type from `GET /v1/data_sources/{id}`. The cards data source
  comes from the relation's `data_source_id`. Card `Status` is found by name.
- **Timer state:** `accumulated + (now − segmentStart)` from wall-clock dates. A 0.5 s timer
  updates the label only while a session is active. The label changes only when its text changes.
- **Sleep:** `NSWorkspace.willSleepNotification` triggers pause.
- **Alarm:** a looping `NSSound` plus `UNUserNotificationCenter`.
- **Login item:** `SMAppService.mainApp`.
- **Persistence:** `~/Library/Application Support/Study Timer/` holds `active-session.json` and
  `commit-queue.json`. The app writes them on every state change. While a session runs, it also
  writes a heartbeat every 30 s. A clean quit writes the quit moment as the last heartbeat.
  Settings and the last mode and duration live in `UserDefaults`. The API key lives only in the
  Keychain.

## Files

- `Package.swift`, `build.sh`
- `Sources/StudyTimer/`: `App`, `StatusBarController`, `HotKey`, `AppModel`, `ActiveSession`,
  `NotionClient`, `CommitQueue`, `Alarm`, `Keychain`, `Persistence`, `Views/`
- `Tests/StudyTimerTests/` (Swift Testing). Fake Notion with a `URLProtocol` stub. No live network
  in tests.

## Implementation order

Prerequisites:

- The Command Line Tools build a SwiftPM package. See `memory-bank/progress.md`.
- The owner approves the UI spec.
- The `Study Timer Test` database exists. The owner's Notion internal integration is connected to
  it and to both live databases.

Work on branch `feat/study-timer-v1`. Commit after each step.

A step marked **checkpoint** ends with a manual test before its commit:

1. Claude installs with `build.sh` and launches the app with `--regular`. Claude drives it with
   full-screen computer use and screenshots each changed state. Claude compares each screenshot
   with the UI spec.
2. The owner tries the same states.
3. The step commits after the owner's OK.

All manual commits go to the `Study Timer Test` database. Rows in the live database need the
owner's permission.

1. Package skeleton, `build.sh`, a status item with an empty popover, and the ⌃⌥S hotkey.
   **Checkpoint.**
2. `ActiveSession` timing math with tests: pause, sleep, relaunch, overtime, and both commit
   intervals.
3. Settings, Keychain, and `NotionClient` with schema discovery, pagination, date parsing, and
   tests. **Checkpoint:** enter the API key and load the test database.
4. Stats and card ranking with tests (24-hour overlap, frecency, title default). **Checkpoint.**
5. Start, running, and finish views. **Checkpoint.**
6. Alarm, notifications, and sleep pause. **Checkpoint** with `--fast-countdown`.
7. `CommitQueue` with retry, backoff, and duplicate check, with tests. **Checkpoint.**
8. Launch at login. **Checkpoint.**

## Verification

1. Run `swift test`, then both `swift format` commands from `CLAUDE.md`.
2. Build and install with `build.sh`. Settings points at the `Study Timer Test` data source.
3. With `--fast-countdown`, run a 1-minute countdown. Check the alarm, mute, pause during the
   alarm, and overtime.
4. Commit once with overtime and once with planned time only. Confirm both rows in the test
   database.
5. Run `pmset sleepnow` mid-session. The timer MUST be paused after wake and stay paused.
6. Quit mid-session and relaunch. The session MUST come back paused at the quit moment. Repeat
   with `kill -9`. The session MUST come back paused at most 30 s before the kill.
7. Commit with Wi-Fi off. The commit MUST queue. Turn Wi-Fi on. The row MUST appear exactly once.
8. Check the open validation gaps in `memory-bank/progress.md`.
9. Point Settings at the live data source. With the owner's permission, commit one session.

## Done when

- Every verification step passes.
- `memory-bank/techContext.md` lists the build, test, and install commands.
- The v1 row in `memory-bank/history.md` reads `implemented`.
- `memory-bank/progress.md` holds only open items.
