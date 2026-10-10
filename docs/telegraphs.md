# Telegraphs

Owners: Norman builds every state with placeholder art; Naxin replaces and
polishes it.

The rule is show, don't tell. The player must be able to read every NPC from
across the room. This page lists everything that needs a visual, so it can be
drawn without reading code.

## Always on

| What | Visual |
|------|--------|
| Mood | A small emoji above each NPC's head, five tiers from very unhappy to very happy |
| Manager presence | A faint circle of `MANAGER_RADIUS` tiles around the manager |
| Customer patience | A shrinking bar or changing face above each customer |
| Carried ticket or dish | Visible in the NPC's hands |

## Personality looks

Each personality has a look that hints at it before the NPC does anything.
For placeholders, one flat colour per personality is enough.

| Personality | Final look should suggest |
|-------------|---------------------------|
| Lazy | Slouched, untidy |
| Irritable | Tense, frowning |
| Clean freak | Spotless, neat |
| Chatty | Open, animated |
| Overachiever | Upright, eager |

## Action states

| State | Bubble | Animation |
|-------|--------|-----------|
| Work | none | Station-specific working loop |
| Waiting (Work with nothing to do) | none | Standing ready at the station |
| Slack | phone or "zzz" | Leaning, looking at a phone |
| Refuse | crossed arms or "no" | Head shake |
| Switch station | arrow toward the new station | Walking |
| Chat | speech bubbles | Two NPCs facing each other |
| Fight | anger symbol | Two NPCs facing each other, agitated |
| Break | cup | Sitting or standing away from the station |
| Overachiever crash | dizzy or collapsed | Slumped; visibly different from a normal break |

## Wind-ups

Every action the manager did not order is preceded by a wind-up of
`WINDUP_DURATION`. Each needs a bubble and animation distinct from the action
itself, readable as "this is about to happen".

| About to | Wind-up |
|----------|---------|
| Slack | Yawn, glance around |
| Switch station | Looks toward the other station |
| Chat | Waves at the coworker |
| Fight | Glare at the coworker |
| Break (unasked) | Wipes brow, looks at the door |

Refuse has no wind-up: it is an immediate answer to an order.

## Events

| Event | Visual |
|-------|--------|
| Praised | Heart or smile bubble |
| Scolded | Sweat drop, then a visibly faster work loop for the burst |
| Spill appears | Splash, then a puddle on the floor |
| Customer walks out | Angry bubble, customer leaves |
| Order paid | Coin over the counter |
| Mood tier changes | The overhead emoji pops |

## Placeholder set

- Coloured rectangles or simple sprites for the manager, five NPCs, and
  customers.
- A stock emoji sheet for all bubbles and mood tiers.
- Flat tiles for floor, walls and each of the five stations.
