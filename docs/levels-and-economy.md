# Levels and economy

Owners: Norman builds the structure; Naxin tunes the numbers. Constants in
`CAPS` are defined in [Balance](balance.md).

## Levels

| Level | NPCs | Roster | Orders |
|-------|------|--------|--------|
| 1 | 3 | Lazy, Irritable, Clean freak | Lowest volume |
| 2 | 4 | The same three individuals + Chatty | Higher |
| 3 | 5 | The same four individuals + Overachiever | Highest |

The same employees return from level to level, so what the player has learned
about them carries over.

## Days

- A level is `DAYS_PER_LEVEL` days.
- A day is `DAY_LENGTH` of real time.
- Between days the player sees the day summary: the day's earnings and
  progress toward the level goal.

## The goal

- Each level has one money goal covering all of its days. There is no daily
  target, and nothing is deducted for wages or maintenance.
- Earnings accumulate across the days of the level.
- At the end of the last day, total earnings are compared with the goal.

## Grades

| Grade | Earnings as a share of the goal |
|-------|---------------------------------|
| F | Below 100%. The level restarts from day one. |
| C | 100% or more |
| B | 120% or more |
| A | 150% or more |
| S | 200% or more |

The grade is the only reward for playing on past the goal. Perks for a large
surplus may come later.

## What persists

| | Between days | Between levels | On level restart |
|-|--------------|----------------|------------------|
| Opinions (of the manager, of coworkers) | Kept | Kept | Back to their values at the start of that level |
| Mood | Partially resets toward neutral | Resets | Resets |
| Energy | Resets to full | Resets | Resets |
| Stations | Cleared; the player assigns again each morning | Cleared | Cleared |
| Earnings | Accumulate | Start from zero | Start from zero |

## Saving

The browser's storage holds only the highest unlocked level and the best
grade for each level. Nothing is saved mid-level.
