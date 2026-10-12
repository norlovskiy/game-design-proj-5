class_name Balance
extends RefCounted
## Every tunable number in the game, in one place. Mirrors docs/balance.md.
## No number is hard-coded anywhere else: the other scripts read these by name.
##
## Values marked "TBD" are placeholders picked so the prototype runs; they are
## Naxin's to set. Distances are in tiles, times in seconds, stats 0–100.

# --- Time and space ---------------------------------------------------------
const DAY_LENGTH := 210.0
const DAYS_PER_LEVEL := 3
## One tile is one world unit (1 m) in the 3D isometric kitchen.
const TILE_SIZE := 1.0
const MANAGER_RADIUS := 3.0
## Distance at which the manager can interact with an NPC ("walk next to").
const INTERACT_RANGE := 1.5  # TBD

## "Within one tile" for chats and coworkers passing by.
## Close enough for physical conflict and coworker annoyance.
const ADJACENT_RANGE := 1.5
## Close enough to start a conversation.
const CHAT_RANGE := 1.5

const MANAGER_SPEED := 4.0  # tiles/s, TBD
const NPC_WALK_SPEED := 2.5  # tiles/s, TBD

# --- Camera (isometric) -----------------------------------------------------
const CAMERA_PITCH_DEG := -35.264  # true isometric
const CAMERA_YAW_DEG := 45.0
const CAMERA_SIZE := 13.0  # orthographic view height in tiles
const CAMERA_DISTANCE := 20.0
const CAMERA_FOLLOW := 4.0  # how fast the camera eases toward the manager

# --- Decisions --------------------------------------------------------------
const DECISION_TICK := 4.0
const BRAIN_TIMEOUT := 1.0  # TBD, with Baani (Jev answers in ~70–500 ms)
const EVENT_LOG_SIZE := 5
const WINDUP_DURATION := 1.5

# --- Manager verbs ----------------------------------------------------------
const VERB_LOCK := 2.0
const VERB_COOLDOWN := 6.0  # per NPC, TBD
## Diminishing returns: each repeat of the same verb on the same NPC inside
## the window multiplies the effect by this factor.
const VERB_REPEAT_WINDOW := 30.0  # TBD
const VERB_REPEAT_FALLOFF := 0.5  # TBD
const SCOLD_SPEED_BONUS := 0.30
const SCOLD_BURST_DURATION := 20.0
const SCOLD_MOOD_DROP := 15.0
const SCOLD_OPINION_DROP := 10.0
const IRRITABLE_SCOLD_MULTIPLIER := 2.0
const PRAISE_MOOD_GAIN := 10.0  # TBD
const PRAISE_OPINION_GAIN := 5.0  # TBD
const BREAK_DURATION := 20.0
const CRASH_BREAK_MULTIPLIER := 2.0

# --- NPC actions ------------------------------------------------------------
const FIGHT_DURATION := 10.0
const FIGHT_PAIR_COOLDOWN := 45.0  # TBD
const FIGHT_OPINION_DROP := 10.0  # mutual, TBD
const FIGHT_NEARBY_MOOD_LOSS := 5.0  # TBD
const FIGHT_NEARBY_RANGE := 3.0  # tiles, TBD
const CHAT_DURATION := 6.0  # TBD
const CHAT_MOOD_GAIN := 5.0  # TBD
const BASE_WORK_SPEED := 1.0  # TBD
const ENERGY_DRAIN_WORK := 0.5  # per second at work, before personality, TBD
const ENERGY_RESTORE_BREAK := 3.5  # per second on break, TBD
const REFUSE_SHOW_TIME := 1.5  # how long the "no" telegraph stays up

# --- Opinions and mood ------------------------------------------------------
const OPINION_NEUTRAL := 50.0
## Authored starting offsets, "<personality> -> <personality>": how the first
## thinks of the second at the start. Everything else starts at neutral, and
## NPCs who join at a later level start neutral with everyone. TBD.
const STARTING_OPINION_OFFSETS := {
	"Clean freak -> Lazy": -10.0,
	"Irritable -> Lazy": -5.0,
	"Lazy -> Clean freak": 5.0,
}
const MOOD_START := 60.0  # TBD
const OPINION_DRIFT := 0.05  # toward neutral, per second, TBD
const MOOD_DRIFT := 0.05  # toward MOOD_START, per second, TBD
const MOOD_LOSS_LOW_ENERGY := 0.1  # per second while energy is low, TBD
const MOOD_TIER_BOUNDS := [20.0, 40.0, 60.0, 80.0]  # five tiers, proposed
const OPINION_CHAT_BUSY_DROP := 5.0  # pulled into a chat while busy, TBD
const OPINION_CHAT_IDLE_GAIN := 4.0  # chat while both idle, TBD
const OPINION_REASSIGN_DROP := 3.0  # per reassignment, TBD
const OPINION_BREAK_GRANTED_GAIN := 5.0  # break granted when energy low, TBD
const OPINION_BREAK_DENIED_DROP := 3.0  # saw "I need a break", no break, TBD
const OPINION_HOVER_DROP := 0.3  # per second, Irritable only, TBD
const OPINION_SLACKER_DROP := 0.2  # per second, working next to a slacker, TBD
const MOOD_SPREAD_RATE := 0.15  # per second, near a coworker in a bad mood, TBD
const MOOD_SPREAD_RANGE := 2.0  # tiles, TBD
const MOOD_SPREAD_BELOW := 40.0  # a "bad mood" is below this, TBD

# --- Talk-line thresholds (all TBD) -----------------------------------------
const TALK_ENERGY_LOW := 25.0
const TALK_COWORKER_MAD := 30.0
const TALK_COWORKER_LIKE := 70.0
const TALK_MANAGER_MAD := 30.0
const HOVER_TIME := 12.0  # seconds in range before it counts as hovering
const REASSIGN_WINDOW := 60.0
const REASSIGN_OFTEN := 3  # reassignments inside the window
const CHAT_PULLED_WINDOW := 60.0

# --- Orders and customers (all TBD) -----------------------------------------
const CUSTOMER_PATIENCE := 60.0
## Seconds between customer arrivals, per level (index 0 = level 1).
const CUSTOMER_INTERVAL := [16.0, 12.0, 9.0]
const CUSTOMER_INTERVAL_JITTER := 0.3  # +/- share of the interval
const FIRST_CUSTOMER_DELAY := 3.0
const MAX_QUEUE := 6  # customers waiting to order; more do not join
const CUSTOMER_WALK_SPEED := 2.0  # tiles/s
const ORDER_TAKE_TIME := 2.0  # seconds at work speed 1
## Cook time per station, in seconds at work speed 1.
const COOK_TIME := {"grill": 8.0, "fryer": 6.0, "prep": 5.0}
const ORDER_BASE_PRICE := 10.0
const ORDER_MAX_TIP := 5.0

# --- Spills (not built yet; TBD) ---------------------------------------------
const SPILL_SLOW := 0.5

# --- Goals and grades -------------------------------------------------------
const GRADE_C := 1.0
const GRADE_B := 1.2
const GRADE_A := 1.5
const GRADE_S := 2.0

# --- Utility brain ----------------------------------------------------------
# These are starting values for Naxin to tune. The Utility brain is
# deterministic: the legal action with the highest score wins.

# General actions.
const UTILITY_WORK_BASE := 25.0
const UTILITY_WORK_ENERGY_WEIGHT := 0.35
const UTILITY_WORK_MOOD_WEIGHT := 0.20
const UTILITY_WORK_MANAGER_OPINION_WEIGHT := 0.20

const UTILITY_SLACK_BASE := 20.0
const UTILITY_SLACK_EXHAUSTION_WEIGHT := 0.55
const UTILITY_SLACK_BAD_MOOD_WEIGHT := 0.25
const UTILITY_SLACK_LOW_MANAGER_OPINION_WEIGHT := 0.25

const UTILITY_BREAK_BASE := 0.0
const UTILITY_BREAK_EXHAUSTION_WEIGHT := 0.90
const UTILITY_BREAK_BAD_MOOD_WEIGHT := 0.15

const UTILITY_SWITCH_BASE := 0.0

# Social actions.
const UTILITY_CHAT_BASE := 5.0
const UTILITY_CHAT_OPINION_WEIGHT := 0.15
const UTILITY_CHAT_IDLE_TARGET_BONUS := 15.0
const UTILITY_CHAT_REPEAT_PENALTY := 100.0
const UTILITY_CHAT_REPEAT_WINDOW := 20.0

const UTILITY_FIGHT_BASE := -20.0
const UTILITY_FIGHT_MY_DISLIKE_WEIGHT := 1.20
const UTILITY_FIGHT_THEIR_DISLIKE_WEIGHT := 1.00

# Refusing manager orders.
const UTILITY_REFUSE_BASE := -10.0
const UTILITY_REFUSE_LOW_MANAGER_OPINION_WEIGHT := 2.50
const UTILITY_REFUSE_BAD_MOOD_WEIGHT := 0.25
const UTILITY_REASSIGN_PENALTY := 18.0
const UTILITY_REASSIGN_MEMORY := 30.0

# Personality-specific preferences.
const UTILITY_LAZY_WATCHED_WORK_BONUS := 35.0
const UTILITY_LAZY_UNWATCHED_WORK_PENALTY := 35.0
const UTILITY_LAZY_WATCHED_SLACK_PENALTY := 15.0
const UTILITY_LAZY_UNWATCHED_SLACK_BONUS := 40.0

const UTILITY_IRRITABLE_FIGHT_BONUS := 55.0
const UTILITY_IRRITABLE_REASSIGN_MULTIPLIER := 2.75

const UTILITY_CLEAN_SPILL_BONUS := 150.0
const UTILITY_SPILL_MEMORY := 12.0

const UTILITY_CHATTY_CHAT_BONUS := 100.0

const UTILITY_OVERACHIEVER_WORK_BONUS := 80.0
const UTILITY_OVERACHIEVER_SLACK_PENALTY := 50.0
const UTILITY_OVERACHIEVER_BREAK_PENALTY := 65.0