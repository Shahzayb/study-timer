# Public repo

Status: implemented on 2026-10-13.

## Context

The repo goes public on GitHub as `Shahzayb/study-timer`. Anyone who clones it SHOULD be able to
set it up from the README. The owner's Notion IDs and email MUST NOT appear in any commit.

## Changes

1. The Connect screen gets a `Data source ID` field under the token field. Connect stays disabled
   until both fields hold text. `Get a key` links to Notion's personal access token guide.
2. `AppModel` drops the built-in data source ID. Connect saves the ID once discovery passes. The
   owner's install keeps the ID it already stored in `UserDefaults`.
3. The README drops the `defaults write` step. The last step pastes the token and the ID.
4. `memory-bank/techContext.md` drops the six Notion IDs and keeps the database names.
5. Git history:
   - Save a bundle of every ref to `~/Programming/study-timer-backup.bundle` first.
   - Rewrite every commit. Replace each Notion ID with `<redacted>`. Replace the Gmail address
     with `29760858+Shahzayb@users.noreply.github.com` as author and committer.
   - Verify that no commit holds an ID or the Gmail address. Set the no-reply address as the
     repo's `user.email`.
6. Push `main` to `origin` only after the owner confirms.
