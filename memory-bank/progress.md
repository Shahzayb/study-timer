# Progress

## Current state

The owner approved plan v1 in
[plans/2026-10-13_study-timer-v1.md](../plans/2026-10-13_study-timer-v1.md) on 2026-10-13. Work
runs on branch `feat/study-timer-v1`, which is not merged. All eight implementation steps are done.
The owner confirmed a commit to the live database on 2026-10-13.

The throwaway UI prototype lives outside the repo in `~/Programming/study-timer-prototype`. It is
installed as `~/Applications/Study Timer Prototype.app`. `shots/` holds a render of every state.

## Next action

_Not yet established._ The owner picks the next task.

## Validation gaps

- The offline save check is unconfirmed: save with Wi-Fi off, then turn it on. The row MUST appear
  exactly once.
- Opening at login is unverified until the owner logs out and back in.
- `RegisterEventHotKey` accepts ⌃⌥S, and the hotkey toggles the app popover. Apps that read keys
  through event taps can still collide. The owner has not confirmed that none do.

## Open decisions

None.
