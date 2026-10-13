# Today stats

Status: implemented on 2026-10-14.

## Context

The stats cover a rolling last 24 hours. The owner wants the total for the calendar day instead.
The day starts at local midnight.

## Changes

1. `DayStats` counts time since local midnight. `Calendar.startOfDay(for: now)` replaces
   `now − 24 h`, and `DayStats.window` goes away. A session that crosses midnight counts only its
   part after midnight.
2. `DayStats` takes a `calendar` parameter that defaults to `.current`. Tests pin a UTC calendar,
   so they pass in any time zone.
3. The footer capsule reads `1h 20m today` instead of `1h 20m 24h`. Its tooltip reads `Today`.
4. The Stats header reads `Today`.
5. `StatsTests` use a noon `now`. The window test becomes a midnight-crossing test. A new test
   checks that the calendar's time zone sets the day boundary.
6. `docs/screenshot.png` drops the removed chart icon and reads `1h 58m today`. The footer text
   is redrawn on the existing image, because a retake would put live Notion data on screen.
7. After the change lands, `projectbrief.md` and `techContext.md` drop the 24-hour wording.

## Out of scope

- A per-day history of past days.
- A day start other than midnight, such as 4 AM.
