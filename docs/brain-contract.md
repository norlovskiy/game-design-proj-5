# Brain contract

Owners: Norman owns the interface and the snapshot schema. Baani owns every
brain that makes real decisions, the wording sent to Jev, and the proxy.

This is the seam between the two halves of the project. Baani can build
against this page before the game exists; Norman can build the game without
any real brain.

## The contract

One Brain per NPC. The state machine gives it a snapshot that includes the
list of legal actions; the brain returns exactly one of them.

```gdscript
class_name Brain
extends Node

signal decided(request_id: int, action_id: String)

# Never blocks. The answer arrives later through `decided`.
func request_decision(snapshot: Dictionary) -> void:
    pass
```

Rules:

1. **Asynchronous.** The NPC keeps doing its current action until an answer
   arrives.
2. **Legal actions only.** An answer that is not in the snapshot's
   `legal_actions` is invalid.
3. **Timeout.** If no answer arrives within `BRAIN_TIMEOUT`, the state
   machine asks the fallback brain instead.
4. **Stale answers are dropped.** Each snapshot carries a `request_id`. If a
   newer request has been sent, or the chosen action is no longer legal when
   the answer lands, the answer is discarded.
5. **The brain never changes state.** It reads the snapshot and picks.
   Wind-ups, durations and effects all belong to the state machine.

## When a decision is requested

On any of these events, plus a slow tick every `DECISION_TICK` per NPC:

- assigned or reassigned by the manager
- ordered on break
- current task finished
- a spill appears nearby
- the manager enters or leaves range
- a coworker passes within one tile
- energy reaches zero

This bounds the number of Jev calls and gives network latency somewhere to
hide.

## Snapshot schema (version 1)

```json
{
  "schema_version": 1,
  "request_id": 412,
  "npc": {
    "name": "Avery",
    "personality": "Irritable",
    "personality_description": "Works worse when watched; snaps if moved around too often.",
    "mood": 38,
    "energy": 61,
    "opinion_of_manager": 44,
    "station": "grill",
    "action": "work"
  },
  "manager": {
    "in_range": true,
    "distance_tiles": 2
  },
  "coworkers": [
    {
      "name": "Sam",
      "personality": "Lazy",
      "distance_tiles": 1,
      "action": "slack",
      "my_opinion_of_them": 29,
      "their_opinion_of_me": 41
    }
  ],
  "recent_events": [
    { "type": "reassigned", "seconds_ago": 12 },
    { "type": "manager_entered_range", "seconds_ago": 3 }
  ],
  "legal_actions": [
    "work",
    "slack",
    "switch:fryer",
    "chat:Sam",
    "fight:Sam",
    "break"
  ]
}
```

Action ids are either a bare action (`work`, `slack`, `refuse`, `break`) or
an action with a target (`switch:<station>`, `chat:<name>`, `fight:<name>`).

Any change to this shape bumps `schema_version` and is agreed by both owners.

## Event types

Each NPC keeps its last `EVENT_LOG_SIZE` events.

| Type | Meaning |
|------|---------|
| `assigned` | Given a first station |
| `reassigned` | Moved to a different station |
| `praised` | |
| `scolded` | |
| `sent_on_break` | |
| `spill_nearby` | |
| `fight_nearby` | |
| `chatted_with` | Carries the coworker's name |
| `manager_entered_range` | |
| `manager_left_range` | |
| `order_completed` | |
| `customer_walked_out` | |

## Brains

| Brain | Purpose | Owner |
|-------|---------|-------|
| Obedient | Always picks Work when it is legal. Lets the game run with no decision-making at all. | Norman |
| Debug | A panel that forces any legal action on any NPC. This is how every interaction is proven to work. | Norman |
| Utility | Deterministic weighted scoring over the legal actions. The fallback on timeout or an invalid answer, and a complete game without a network. | Baani |
| Jev | Sends the snapshot to Jev and maps the answer back to an action id. | Baani |

## Jev

Jev (Typesafe AI) is a non-autoregressive decision model. It takes a state as
text or JSON plus typed questions and returns typed answers with
probabilities in a single pass, in roughly 70–500 ms. It does not generate
text. The decision is asked as one Choice question whose candidates are the
legal action ids (Jev allows 2 to 255 candidates).

The game is a web build, and a web build cannot keep an API key secret. The
Jev brain therefore calls a small proxy that holds the key. The key never
ships in the game.

## What the brain is expected to weigh

These are preferences, so they live in the brain and not in legality:

- Lazy works when the manager is in range and slacks otherwise.
- Clean freak switches to cleaning when a spill exists.
- Chatty starts chats when a coworker passes.
- Fight has a small baseline weight for any adjacent pair, growing as mutual
  opinion falls and when either NPC is Irritable.
- Low energy favours Break and Slack; low opinion of the manager favours
  Refuse.

Design rule for both brains: failure should come from accumulated neglect,
never from one bad roll.
