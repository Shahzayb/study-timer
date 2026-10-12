# Project Brief

## Goal

Remove the friction of logging study sessions in Notion. From the macOS menu bar, the owner picks
cards, times a session, and commits one accurate row to Notion without opening it. They can also
see their study time for the last 24 hours at a glance.

## Users

One person, the owner, on one Mac (M4 Pro, macOS 27+). The app runs locally and is never
distributed. Claude writes and maintains the code.

## In scope

- Last-24-hour stats covering every session in the Notion database, including manual entries.
- Starting a session: multi-select cards, an editable default title, and a stopwatch or a
  countdown with an alarm.
- Pause, plus auto-pause on system sleep.
- Commit (with or without overtime) or discard. Each commit is one row.
- Offline retry without duplicates.
- A global hotkey (⌃⌥S) and launch at login.

## Non-goals

- Editing session times, rounding times, or logging past sessions.
- Creating or editing cards, or changing the Notion schema.
- App Store distribution, other users, or other devices.
- Any storage besides Notion, apart from the local retry queue and the active-session state.
