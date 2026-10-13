# Study Timer v1

Status: approved on 2026-10-13.

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

The prototype named in `memory-bank/progress.md` is the visual reference. Implementation MAY port
its view code where it matches this section. This section wins where they differ.

### Shared

- The popover is 340 × 400 pt and `.transient`. An outside click, ⌃⌥S, or Esc on a root screen
  closes it.
- Opening gives the popover keyboard focus without activating the app. The previously active app
  keeps focus throughout.
- Connect, Start, and Active are root screens. Finish, Stats, and Settings are sub-screens with a
  44 pt header. The header holds a back chevron (Esc) and an optional title.
- Reopening shows the last screen with its field contents intact. A click outside, such as copying
  the API key from a browser, MUST NOT lose input.
- Start and Active share a 44 pt footer under a divider:
  - Leading: a capsule button with `chart.bar.fill`, the 24-hour total, and a secondary `24h`. It
    opens Stats.
  - After the total: an orange `icloud.slash` while a commit waits in the queue, or a red
    `exclamationmark.triangle.fill` after a permanent failure.
  - Trailing: a small spinner during any refresh, then a gear button that opens Settings (⌘,).
  - The total shows a spinner until stats first load. It shows an orange triangle if that load
    failed.
- Icon buttons are 28 pt circles with a hover fill and a tooltip. Session controls are 54 pt
  circles. A prominent control fills with the accent color.
- Times use monospaced digits. Large numbers use the rounded design.
- The accent color marks controls, selection, and bars. Orange marks the alarm and overtime. Red
  marks errors and Discard. Only the ring uses the brand gradient. Light mode uses deeper ring
  hues.
- Error text is one short line. Its tooltip holds Notion's full message.

| Cause | Text |
| --- | --- |
| No network or timeout | `Offline` |
| 401 | `Key rejected` |
| 403 or 404 | `Database not shared` |
| No title, date, or relation property | `Database missing a property` |
| Other 400 | `Notion rejected the row` |
| 5xx | `Notion unavailable` |

### Menu bar

- Idle: the 16 pt template ring glyph, 80% filled with a knob. No text.
- Running: a progress ring glyph, then the time. A countdown ring empties as time runs out. A
  stopwatch ring fills once per hour. Overtime shows a full ring and `+mm:ss`.
- Paused: the `pause.fill` symbol replaces the ring. The time stays.
- Times read `mm:ss` under an hour and `h:mm:ss` from an hour. A countdown rounds up.
- The label redraws only when its text or its ring step (1/60 turn) changes.
- Left and right clicks both toggle the popover. There is no menu.

### Connect

The popover shows Connect while no API key is stored. At launch without a key, the popover opens
on it.

- Layout, centered with 28 pt side margins: the app icon (76 pt), `Connect Notion` (title 2,
  semibold), a large secure field `Notion API key`, a 30 pt message line, and a full-width
  prominent `Connect` button. The bottom row holds a `Get a key` link to
  `https://www.notion.so/profile/integrations` and a Quit icon button.
- Keyboard: the field has focus on open. ↩ connects.
- Connect runs schema discovery on the data source in Settings. Success stores the key in the
  Keychain and moves to Start in its loading state.
- Empty field: Connect is disabled.
- Checking: a spinner replaces the label. The field and the button are disabled.
- Error: the message line shows a red `xmark.circle.fill` and the error text. An edit clears it.

### Start

Layout, top to bottom, with 14 pt margins and 10 pt spacing, then the footer:

1. The failed-commit banner, only after a permanent failure.
2. A large `NSSearchField` with the prompt `Search cards`.
3. The card list. It fills the free height, scrolls, and fades out at the bottom. Rows are 30 pt
   with an 8 pt corner radius. A selected row shows an accent fill, a semibold name, and a
   checkmark. The highlighted row shows a faint fill.
4. A large title field with the placeholder `Title`.
5. The duration row: a segmented control `[stopwatch] 25 45 60 90` and a 54 pt `min` field.
6. A full-width prominent `▶ Start` button.

Cards:

- Selected cards come first in selection order. The rest follow by rank.
- Search filters unselected cards by a case- and diacritic-insensitive substring. Selected cards
  always show.

Title:

- The field holds the default from the Behavior chain until the owner edits it. An edit survives
  selection changes.
- Clearing the field shows the default as the placeholder. The default then follows the selection
  again. Start with an empty field uses the default.

Duration:

- A segment sets the mode. Whole minutes typed in `min` select a custom countdown and clear the
  segments. The valid range is 1–600.
- The form opens with the last mode and duration.

Keyboard:

- On open, the search field has focus. The first unselected match is highlighted.
- ↑ and ↓ move the highlight. ↩ toggles the highlighted card and clears the search. Hover moves
  the highlight. A click toggles.
- Esc clears the search first. A second Esc closes the popover.
- Tab moves from search to title to `min`.
- ↩ in the title starts. ⌘↩ starts from anywhere.
- ⌘1 picks the stopwatch. ⌘2 to ⌘5 pick 25, 45, 60, and 90.

Start saves the session, closes the popover, and starts the menu bar label. The form then clears
its selection, search, and title. Mode and duration stay.

States:

- Start is disabled when no card is selected or `min` is out of range.
- Cards loading with none cached: four redacted placeholder rows. Search and title stay usable.
- Cards refreshing: the list stays usable. The footer shows its spinner.
- Card load failed with none cached: an orange triangle, the error line, and `Retry`, centered.
- No cards in the database: a secondary `No cards`, centered.
- No match: `magnifyingglass` and a secondary `No match`, centered.
- Failed-commit banner: a red-tinted rounded rectangle with a 12 pt radius. It shows a red
  triangle, `"<title>" not saved` on one line, and the error line. Retry (`arrow.clockwise`) and
  Discard (`xmark`) icon buttons sit at the trailing edge. Retry shows a spinner while it runs.
  Discard uses the same inline confirmation as Finish. With several failures, the banner shows the
  oldest.

### Active

Active covers running, paused, alarm, and overtime.

Layout, then the footer:

- A 188 pt ring with a 12 pt round-capped stroke on a faint track, 24 pt from the top.
- Inside the ring: an 18 pt status icon slot, the time (42 pt, semibold, rounded), and a caption
  (caption, semibold, secondary, uppercase).
- Below the ring: the title (headline) and the cards joined by ` · ` (subheadline, secondary).
  Each takes one truncated line.
- The session controls, centered, 16 pt above the footer.

| State | Ring | Time | Caption | Status icon |
| --- | --- | --- | --- | --- |
| Countdown | Remaining fraction, brand gradient | Remaining, rounded up | `45 MIN` | — |
| Stopwatch | Fills once per hour | Elapsed | `ELAPSED` | — |
| Paused | Dimmed to 30% | Dimmed to 45% | `PAUSED` | — |
| Alarm | Full, orange to red | Orange `+mm:ss` | `OVERTIME` | Wiggling orange `bell.fill` |
| Overtime, muted | Full, orange to red | Orange `+mm:ss` | `OVERTIME` | Secondary `bell.slash.fill` |

Controls, left to right:

- Mute: a prominent orange `bell.slash.fill`, shown only while the alarm rings. Key M.
- Pause (`pause.fill`) or a prominent Resume (`play.fill`). Key Space.
- Finish (`checkmark`). It is prominent while running without the alarm. Key ↩.

Esc closes the popover. During a session the popover never opens by itself. A click on the alarm
notification opens it on Active.

### Finish

Finish opens from Active. The timer keeps running here, so `end` stays the minute of Save. Opening
Finish mutes a ringing alarm.

- Layout: the header with a back chevron only. Centered below: the active time (44 pt, semibold,
  rounded) and the saved interval `4:23 AM – 5:15 AM` (callout, secondary). After the alarm, an orange
  `+2m 12s overtime` line (callout, semibold) follows. The title and cards follow as on Active.
- Bottom, with 14 pt margins: a Discard icon button (`trash`) and a full-width prominent
  `Save 52m`. After the alarm, a full-width bordered `Save 45m only` sits below.
- The active time reads `Xm Ys` under an hour and `Xh Ym` from an hour. Button labels show the
  saved length in whole minutes.
- Keyboard: ↩ saves. ⌥↩ saves the planned time only. ⌘⌫ arms Discard. A second ⌘⌫ or a click
  discards. Esc returns to Active.
- While the active time rounds to zero minutes, Save is disabled.
- Armed Discard: the trash becomes a prominent red `Discard` for 3 s, then reverts.
- Save adds the commit to the queue and shows Start at once. Stats shows the row as sending. A
  later permanent failure shows the failed-commit banner.
- After Save or Discard, the popover stays open on a cleared Start.

### Stats

Stats opens from the footer capsule. The header reads `Last 24 hours`. The content scrolls with
18 pt margins:

1. The total (40 pt, semibold, rounded).
2. One bar per card, by time descending. The name (callout, medium) and the time (callout,
   secondary) sit above a 6 pt solid accent capsule on a faint track. Width is relative to the top
   card, at least 6 pt. Sessions without a card form a gray `No card` bar.
3. A divider.
4. Sessions, newest first. Each row shows the title (callout, medium) over `cards · start – end`
   (caption, secondary). Several cards are joined by `, `. The trailing time counts only the part
   inside the window.
5. A sync badge before the time: a spinner while sending, an orange `icloud.slash` while queued,
   and a red triangle after a permanent failure.

The failed-commit banner also shows at the top of Stats. Esc goes back.

States:

- Loading with no data: a centered spinner.
- Refreshing with data: a small spinner at the trailing edge of the header.
- Failed with no data: a centered `wifi.exclamationmark` when offline, otherwise
  `exclamationmark.triangle`. The error line and `Retry` sit below.
- Failed with data: the data stays. An orange triangle in the header carries the error as a
  tooltip.
- Empty: `0m` and a secondary `No sessions`.

### Settings

Settings opens from the gear or ⌘,. The header reads `Settings` and holds a trailing Quit
(`power`) button. A grouped form fills the rest without scrolling:

- Notion section: `API key` (secure, placeholder `ntn_…`, tooltip `Stored in your Keychain`) and
  `Data source` (the ID). A status row below shows `Checking…` with a spinner, a green check with
  the data source name, or a red error line.
- Alarm section: the sound picker, which previews each pick, and the `Open at login` toggle.
- Under the form: a secondary keyboard symbol and `⌃⌥S`.

Behavior:

- A Notion field validates when editing ends: on ↩, Tab, or focus loss. Validation runs the
  Connect schema discovery. A new value is saved only when it passes. Until then the app keeps the
  last working value. Back reverts a failing field.
- The Notion fields are read-only while a session is active. Each queued commit keeps the data
  source it was made with.
- If login item registration fails, the toggle reverts and a red error line shows under it.
- Quit saves the active session and exits.
- Keyboard: Esc goes back. Tab moves between fields.

## Behavior

### Menu bar

- Idle: an icon only.
- Running: a progress ring glyph, then the time. Countdown: the remaining time. Overtime:
  `+mm:ss`. Stopwatch: the elapsed time.
- Paused: the `pause.fill` symbol replaces the ring glyph.
- The time MUST use monospaced digits.
- ⌃⌥S toggles the popover. Opening gives the card search field keyboard focus. The app MUST NOT
  activate, so the previously active app keeps focus.
- First run with no API key opens the popover on the Connect screen.

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
- Clearing the title restores the default as a placeholder. Start with an empty title uses the
  default.
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
- Commit is disabled while the active time rounds to zero minutes, under 30 s.
- Discard asks for an inline confirmation.
- A commit writes one Notion row with the title, `Interval = [end − activeTime, end]`, and the
  selected cards. Notion stores date-times to the minute, so the interval MUST use whole minutes.
  - `end` is the commit moment floored to the minute. When paused, `end` is the pause moment
    floored to the minute.
  - `activeTime` is the active time rounded to the nearest minute. Half a minute rounds up.
  - "Planned time only" sets `end` to the moment elapsed time reached the target, floored to the
    minute. The duration equals the target.

### Retries

- Every commit enters a queue on disk before the first request. Save MUST NOT wait for Notion.
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
- **Menu bar:** an AppKit `NSStatusItem` with an `.transient` `NSPopover` that hosts SwiftUI. The
  popover window is a non-activating panel. A global mouse-down monitor closes it on outside
  clicks, because a transient popover in an inactive app never sees them.
- **App icon:** a Swift script draws `AppIcon.icns` through `iconutil`. `build.sh` bundles it.
  `actool` and Icon Composer need Xcode.
- **Computer use:** the `--regular` launch argument sets a regular activation policy, so computer
  use can list and target the app.
- **Hotkey:** Carbon `RegisterEventHotKey` for ⌃⌥S.
- **Notion:** `URLSession` with async/await and `Codable`. At launch the app resolves the title,
  date, and relation properties by type from `GET /v1/data_sources/{id}`. The cards data source
  comes from the relation's `data_source_id`. Card `Status` is found by name.
- **Timer state:** `accumulated + (now − segmentStart)` from wall-clock dates. A 0.5 s timer
  updates the label only while a session is active. The label changes only when its text or ring
  step changes.
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
- The `Study Timer Test` database exists.
- Before step 3, the owner's Notion internal integration is connected to the test database and
  both live databases.

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
5. Start, running, and finish views, and the saved active session. Until step 7, Save sends the
   row directly and keeps the session on Finish when it fails. **Checkpoint.**
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
