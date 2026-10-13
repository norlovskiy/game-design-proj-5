# Campaign

Start Game in `scenes/game.tscn` starts a fresh level 1.

The main menu contains the title, a short tagline, and bright-blue Instructions and Start Game. Start
Game gently pulses between 97% and 103% scale on a two-second cycle.
Instructions opens a separate screen explaining controls, staff management,
personality traits, revenue, combo bonuses, customer patience and pause.
Back to Main Menu is at the top right; Escape also returns to the menu.
Each employee interaction panel displays Personality using the name from
that employee's authored Personality resource.

| Level | Roster | Revenue target |
|-------|--------|----------------|
| 1 — Learn the Kitchen | Avery, Sam, Jo | $250 |
| 2 — Find Your Rhythm | Avery, Sam, Jo + Riley | $350 |
| 3 — The Dinner Rush | Avery, Sam, Jo, Riley + Kit | $550 |

At the start of level 1, the camera smoothly focuses on Avery, Sam and Jo
in order. Level 2 introduces only Riley; level 3 introduces only Kit. The
kitchen and shift clock pause during introductions. A white rounded panel
at the bottom types a brief English personality tip at 40 characters/second.
Continue (or E / Space / Enter) reveals unfinished text; a second press
advances. After the last tip, the camera returns to its full view and play
resumes. Escape during introductions returns to the main menu.

Jo's Cleaning preference is reduced from +200 to +100. While her assigned
cook station has unfinished tickets, or she has pending counter service
or errands, switch:cleaning is excluded from legal actions. This applies
to Utility and Jev, including answers that arrive after work begins.
Jev no longer rejects other actions simply because Cleaning is available.

Level 1 schedules exactly 30 customers. Completing at least 85% of the
scheduled orders adds 10 customers to the next level; otherwise the count
stays the same. Customers leaving before ordering count in the denominator.
For thirty customers, 26 successful orders increase demand to 40; 25 do not.

Every shift resets earnings, energy, opinions, mood and assignments. Higher
levels increase the target and add employees while retaining the same
arrival cadence. There are no multi-day shifts or saves.

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
target requires combo bonuses if demand remains at 30 customers, since
30 orders at the maximum $15 per order earn only $450 before bonuses.

Top left shows level, revenue and target, followed by completed/scheduled
orders, arrivals, elapsed time and a level-specific tip. Top right has Pause.
Pause freezes movement, staff, customers, patience, cooking, combos and time.
Resume Game continues; Return to Main Menu discards the run. Escape pauses
or resumes, unless an interaction panel uses it to close or go back.

Passing levels 1 and 2 offers Next Level and Return to Main Menu. Passing
level 3 shows campaign completion and Return to Main Menu. Failure shows
the result and Return to Main Menu, without an advance button.

All player-facing text is English. Tuning constants live in `scripts/balance.gd`.
