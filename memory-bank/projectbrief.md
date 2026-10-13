# Project Brief

## Goal

Remove the friction of logging study sessions in Notion. From the macOS menu bar, the user picks
cards, times a session, and commits one accurate row to Notion without opening it. The user can
also see their study time for the last 24 hours at a glance.

The app MUST feel like a native macOS menu bar extra: pleasant, cohesive, and polished.

## Users

Anyone on macOS 27+ who logs study sessions in Notion. The source is public. Each user clones it
and sets it up with their own Notion token and databases. Claude writes and maintains the code.

## In scope

- Last-24-hour stats covering every session in the Notion database, including manual entries.
- Starting a session: multi-select cards, an editable default title, and a stopwatch or a
  countdown with an alarm.
- Pause, plus auto-pause on system sleep and screen lock.
- Commit (with or without overtime) or discard. Each commit is one row.
- Offline retry without duplicates.
- A global hotkey (⌃⌥S) and launch at login.

## Non-goals

- Editing session times, rounding times, or logging past sessions.
- Creating or editing cards, or changing the Notion schema.
- App Store or binary distribution, shared setups, or other devices.
- Any storage besides Notion, apart from the local retry queue, the active-session state, and
  preferences in `UserDefaults`.
