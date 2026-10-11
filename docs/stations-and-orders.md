# Stations and orders

Owner: Norman. Constants in `CAPS` are defined in [Balance](balance.md).

## The kitchen

- One kitchen layout, used for all three levels, laid out like a commercial
  kitchen: a cook line along the back wall (grill, fryer), two rows of
  counters through the middle with gaps to walk through (prep sits in the
  first row), the sink for cleaning on the side wall, and the service counter
  at the front. Errands have to route around the counter rows, so distances
  between stations differ and matter.
- A 3D grid of tiles, each `TILE_SIZE` world units, seen through an
  isometric camera, with grid pathfinding.
- NPCs pass through each other, which avoids deadlocks. Passing within one
  tile of a coworker still counts as "passing by" for decisions.

## Stations

| Station | Role | Work done there |
|---------|------|-----------------|
| Counter | Front of house | Take a customer's order, carry the ticket to the right cook station, carry the finished dish to the customer |
| Grill | Cook | Cook grill tickets |
| Fryer | Cook | Cook fryer tickets |
| Prep | Cook | Cook prep tickets |
| Cleaning | Cleaner | Walk to each spill and remove it |

Each station holds one NPC. A station with no one on it does nothing: its
tickets wait.

## The order pipeline

Recipes and ingredient steps are out of scope. Every order is the same fixed
pipeline, and needs exactly one cook station.

1. A customer arrives and joins the queue at the counter. Their patience
   timer starts.
2. The counter NPC takes the order. A ticket appears, marked for grill, fryer
   or prep.
3. The counter NPC carries the ticket to that station.
4. The cook on that station cooks it. A dish appears.
5. The counter NPC carries the dish to the customer.
6. The customer pays and leaves.

Tickets and dishes are visible objects that NPCs carry.

How the counter NPC works through it:

- Serving comes first: a finished dish is fetched and served before new
  orders are taken. Then tickets left on the counter are delivered, then the
  next customer's order is taken.
- The counter NPC drops off tickets and picks up dishes standing just behind
  the cook (the station's hand-off tile), and serves across the counter.
- Taking an order takes `ORDER_TAKE_TIME`; cooking takes the station's
  `COOK_TIME`. Both are scaled by work speed.
- Only actual work drains energy: taking an order, carrying, or cooking a
  ticket. Waiting at a station with nothing to do does not.
- A counter NPC who loses the role (reassigned, or swapped off) leaves
  whatever they were carrying on the counter for the next counter NPC.
- Cooking progress belongs to the station, so a new cook carries on where the
  last one stopped.
- When a customer walks out, their ticket or dish is thrown away wherever it
  is, including in an NPC's hands.

## Customers

- Simple characters that queue at the counter. No personalities, no behaviour
  beyond waiting. They line up along the outside of the front wall; after
  ordering they step aside to wait for their dish. At most `MAX_QUEUE` wait
  to order; anyone arriving while the line is full does not come in.
- Patience shows as a face above each customer that worsens as it drains.
- One patience timer of `CUSTOMER_PATIENCE`, running from arrival until the
  dish is served.
- If patience runs out, the customer leaves and the sale is lost. NPCs log a
  `customer_walked_out` event.

## What an order is worth

Payment = `ORDER_BASE_PRICE` + a tip of up to `ORDER_MAX_TIP`, scaled by the
share of patience remaining when the dish is served. A well-run kitchen
earns more per order, not just more orders.

## Spills

- A spill is an accident, never a chosen action. It can happen while an NPC
  works. The chance rises as energy falls and is multiplied by the
  personality's spill modifier (high for Lazy).
- A spill is an object on the floor. Anyone crossing it is slowed by
  `SPILL_SLOW`.
- A spill is removed by an NPC working the cleaning role.
- Each spill remembers who made it, because cleaning someone else's spill
  lowers the cleaner's opinion of them.
