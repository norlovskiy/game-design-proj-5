# Balance

Owner: Naxin.

Every tunable number in the game lives in one balance file, mirrored on this
page. No number is hard-coded anywhere else; the other specs refer to
constants by name.

"Agreed" values came out of the design discussion and are starting points.
"TBD" values have not been discussed and are Naxin's to set.

## Time and space

| Constant | Value | Status |
|----------|-------|--------|
| `DAY_LENGTH` | 3–4 minutes (start at 210 s) | Agreed |
| `DAYS_PER_LEVEL` | 3 | Agreed |
| `TILE_SIZE` | 16 px | Agreed |
| `MANAGER_RADIUS` | 3 tiles | Agreed |

## Decisions

| Constant | Value | Status |
|----------|-------|--------|
| `DECISION_TICK` | 4 s per NPC | Agreed |
| `BRAIN_TIMEOUT` | TBD (Jev answers in roughly 70–500 ms) | TBD, with Baani |
| `EVENT_LOG_SIZE` | 5 | Agreed |
| `WINDUP_DURATION` | 1–2 s (start at 1.5 s) | Agreed |

## Manager verbs

| Constant | Value | Status |
|----------|-------|--------|
| `VERB_LOCK` | 2 s | Agreed |
| `VERB_COOLDOWN` (per NPC) | TBD | TBD |
| Diminishing returns on repeated praise or scold | TBD | TBD |
| `SCOLD_SPEED_BONUS` | +30% | Agreed |
| `SCOLD_BURST_DURATION` | 20 s | Agreed |
| `SCOLD_MOOD_DROP` | 15 | Agreed |
| `SCOLD_OPINION_DROP` | 10 | Agreed |
| Irritable scold multiplier | ×2 | Agreed |
| `PRAISE_MOOD_GAIN` | TBD | TBD |
| `PRAISE_OPINION_GAIN` | TBD | TBD |
| `BREAK_DURATION` | 20 s | Agreed |
| Overachiever crash break | 2 × `BREAK_DURATION` | Agreed |

## NPC actions

| Constant | Value | Status |
|----------|-------|--------|
| `FIGHT_DURATION` | 10 s | Agreed |
| `FIGHT_PAIR_COOLDOWN` | TBD | TBD |
| Fight: mutual opinion drop | TBD | TBD |
| Fight: mood loss for NPCs nearby | TBD | TBD |
| `CHAT_DURATION` | TBD | TBD |
| `BASE_WORK_SPEED` and the energy and mood factors | TBD | TBD |
| Energy drain while working, per personality | TBD | TBD |
| Energy restored by a break | TBD | TBD |

## Opinions and mood

| Constant | Value | Status |
|----------|-------|--------|
| `OPINION_NEUTRAL` | 50 | Agreed |
| Starting offsets per pair | TBD | TBD |
| Each cause in the opinion tables of [NPC state and actions](npc-state-and-actions.md) | TBD | TBD |
| Drift rate toward neutral | TBD | TBD |
| Mood kept between days | TBD | TBD |
| Mood tier boundaries (five tiers) | 0–19, 20–39, 40–59, 60–79, 80–100 | Proposed |
| Talk-line thresholds | TBD | TBD |

## Orders and spills

| Constant | Value | Status |
|----------|-------|--------|
| `CUSTOMER_PATIENCE` | TBD | TBD |
| Customer arrival rate, per level | TBD | TBD |
| Cook time per station | TBD | TBD |
| `ORDER_BASE_PRICE` | TBD | TBD |
| `ORDER_MAX_TIP` | TBD | TBD |
| Spill chance, by energy and personality | TBD | TBD |
| `SPILL_SLOW` | TBD | TBD |

## Goals and grades

| Constant | Value | Status |
|----------|-------|--------|
| Money goal, per level | TBD | TBD |
| Grade C | 100% of the goal | Agreed |
| Grade B | 120% | Agreed |
| Grade A | 150% | Agreed |
| Grade S | 200% | Agreed |
