# Progress

## Current state

The owner approved plan v1 in
[plans/2026-10-13_study-timer-v1.md](../plans/2026-10-13_study-timer-v1.md) on 2026-10-13. Work
runs on branch `feat/study-timer-v1`. Implementation steps 1 to 7 are done. The app connects to
the `Study Timer Test` database.

The throwaway UI prototype lives outside the repo in `~/Programming/study-timer-prototype`. It is
installed as `~/Applications/Study Timer Prototype.app`. `shots/` holds a render of every state.

## Next action

1. The owner runs the step 7 offline check: save with Wi-Fi off, then turn it on. The row MUST
   appear exactly once.
2. Claude implements step 8: launch at login.

## Validation gaps

- Whether a write to the live two-way relation needs the Update content capability is unverified.
  The test database's one-way relation cannot show it. Verification step 9 will.
- `SMAppService.mainApp` registration is unverified for an ad-hoc signed app in `~/Applications`.
- `RegisterEventHotKey` accepts ⌃⌥S, and the hotkey toggles the app popover. Apps that read keys
  through event taps can still collide. The owner has not confirmed that none do.

## Open decisions

None.
