# Progress

## Current state

The owner approved plan v1 in
[plans/2026-10-13_study-timer-v1.md](../plans/2026-10-13_study-timer-v1.md) on 2026-10-13. Work
runs on branch `feat/study-timer-v1`. Implementation step 1 is done. The `Study Timer Test`
database exists.

The throwaway UI prototype lives outside the repo in `~/Programming/study-timer-prototype`. It is
installed as `~/Applications/Study Timer Prototype.app`. `shots/` holds a render of every state.

## Next action

1. Claude implements step 2: `ActiveSession` timing math with tests.
2. Before step 3, the owner connects an internal integration to the test database and both live
   databases. It needs the Read content and Insert content capabilities. Every live Notion step
   depends on it.

## Validation gaps

- Whether a write to the live two-way relation needs the Update content capability is unverified.
  The test database's one-way relation cannot show it. Verification step 9 will.
- `SMAppService.mainApp` registration is unverified for an ad-hoc signed app in `~/Applications`.
- Notification permission prompts are unverified for an ad-hoc signed app.
- `RegisterEventHotKey` accepts ⌃⌥S, and the hotkey toggles the app popover. Apps that read keys
  through event taps can still collide. The owner has not confirmed that none do.

## Open decisions

None.
