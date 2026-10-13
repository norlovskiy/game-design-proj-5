# Campaign

Start Game in `scenes/game.tscn` starts a fresh level 1.

| Level | Roster | Revenue target |
|-------|--------|----------------|
| 1 — Learn the Kitchen | Sam, Avery, Jo, Riley, Kit | $250 |
| 2 — Find Your Rhythm | Sam, Avery, Jo, Riley, Kit | $350 |
| 3 — The Dinner Rush | Sam, Avery, Jo, Riley, Kit | $550 |

Level 1 schedules exactly 30 customers. Completing at least 85% of the
scheduled orders adds 2 customers to the next level; otherwise the count
stays the same. Customers leaving before ordering count in the denominator.
For thirty customers, 26 successful orders increase demand to 32; 25 do not.

Every shift resets earnings, energy, opinions, mood and assignments. Higher
levels increase the target while retaining the same arrival cadence. The team stays at five
employees. There are no multi-day shifts or saves.

The first customer arrives after 3s; subsequent customers use the original
random arrival timer: a 9s base in all three levels, with +/-30%
variation on each arrival. This matches the standalone prototype's original
default scene (level = 3). There is no fixed arrival timetable. When the
queue is full, the timer restarts and tries again at its next tick, exactly
as in the original prototype. Only actual arrivals count toward the budget.
There is no target shift duration
or time limit. Larger budgets extend the arrival schedule. Results wait
until the full budget has arrived and every customer has physically left.

Revenue includes the $10 base price, up to $5 tip and combo bonuses. A
running combo is settled before comparison. Revenue >= target passes;
less fails. The targets do not require 85% completion; that threshold only
controls next-level demand. Targets are $250 / $350 / $550. The third
target requires combo bonuses: even 34 orders at the maximum $15 per order
would earn only $510 before bonuses.

Top left shows level, revenue and target, followed by completed/scheduled
orders, arrivals, elapsed time and a level-specific tip. Top right has Pause.
Pause freezes movement, staff, customers, patience, cooking, combos and time.
Resume Game continues; Return to Main Menu discards the run. Escape pauses
or resumes, unless an interaction panel uses it to close or go back.

Passing levels 1 and 2 offers Next Level and Return to Main Menu. Passing
level 3 shows campaign completion and Return to Main Menu. Failure shows
the result and Return to Main Menu, without an advance button.

All player-facing text is English. Tuning constants live in `scripts/balance.gd`.
