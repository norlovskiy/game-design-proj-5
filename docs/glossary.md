# Glossary

Use these words, with these meanings, in code, docs and conversation.

| Term | Meaning |
|------|---------|
| Manager | The player's avatar. Never performs kitchen tasks. |
| NPC / employee | One of the kitchen staff. Has a personality and internal state. |
| Customer | A simple character that queues, waits and pays. Not an NPC in the sense above. |
| Personality | A data file defining an NPC's modifiers, traits, description and look. |
| Trait | An absolute rule attached to a personality, enforced by the state machine (for example `never_refuses`). |
| Station | A place of work: counter, grill, fryer, prep, cleaning. |
| Standing role | An NPC's assignment to a station, lasting until the manager changes it. |
| Assign | The manager giving an NPC a standing role. |
| Reassignment | An Assign to an NPC who already had a station. |
| Action | One of the seven things an NPC can be doing: Work, Slack, Refuse, Switch station, Chat, Fight, Break. |
| Waiting | Work with nothing to do. Not slacking. |
| Legal action | An action the state machine currently allows, given with its target. |
| Wind-up | The short, visible, interruptible state before any action the manager did not order. |
| Brain | The component that picks one legal action from a snapshot. |
| Snapshot | The JSON description of an NPC's situation sent to a brain. |
| Fallback | The deterministic utility brain used when Jev times out or answers invalidly. |
| Jev | Typesafe AI's non-autoregressive decision model, used as the production brain. |
| Mood | 0–100. How the NPC feels now. Shown as the overhead emoji. |
| Energy | 0–100. Drained by work, restored by breaks. At zero, Work is not legal. |
| Opinion | 0–100. What an NPC thinks of the manager or of one coworker. Persists. |
| Presence / in range | Within `MANAGER_RADIUS` tiles of the manager. |
| Hovering | The manager staying in range of an NPC for a long time. |
| Interact panel | The panel opened by interacting with an NPC: talk line, sliders, four verbs. |
| Talk line | The single sentence in the panel stating the NPC's most pressing need. |
| Verb | A manager command: Assign, Praise, Scold, Break. |
| Ticket | An order taken at the counter, marked for one cook station. |
| Dish | A cooked ticket, ready to serve. |
| Patience | A customer's timer from arrival to being served. |
| Tip | The part of an order's payment that shrinks as patience drains. |
| Spill | An accidental floor hazard that slows movement until cleaned. |
| Crash | The Overachiever's forced, double-length, uninterruptible break at zero energy. |
| Day | One real-time shift. |
| Level | Three days with one roster and one money goal. |
| Goal | The earnings a level requires across all its days. |
| Grade | F, C, B, A or S, from earnings as a share of the goal. |
| Telegraph | Any visual that tells the player what an NPC is, feels or is about to do. |
