# Progress

## Current state

No code exists. Plan v1 in
[plans/2026-10-13_study-timer-v1.md](../plans/2026-10-13_study-timer-v1.md) is back in draft.
Approval waits on its UI spec.

The throwaway UI prototype lives outside the repo in `~/Programming/study-timer-prototype`. It is
installed as `~/Applications/Study Timer Prototype.app`. `shots/` holds a render of every state.
The prototype follows the minimal redesign the owner asked for on 2026-10-13.

## Next action

1. The owner clicks through the prototype and gives feedback. Claude then writes the plan's UI
   spec section.
2. Claude creates the `Study Timer Test` database after the owner confirms its details.

## Validation gaps

- The owner has not confirmed a Notion internal integration connected to both live databases and
  the test database. Every live Notion step depends on it.
- `SMAppService.mainApp` registration is unverified for an ad-hoc signed app in `~/Applications`.
- Notification permission prompts are unverified for an ad-hoc signed app.
- `RegisterEventHotKey` accepts ⌃⌥S, and the hotkey toggles the prototype popover. Apps that read
  keys through event taps can still collide. The owner has not confirmed that none do.

## Open decisions

None.
