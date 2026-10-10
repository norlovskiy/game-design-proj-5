class_name Brain
extends Node
## The seam between the NPC state machine and decision-making.
## See docs/brain-contract.md. One Brain per NPC.
##
## Rules: never block; answer with exactly one of snapshot.legal_actions;
## never change state. Timeouts, stale answers and wind-ups are handled by
## the state machine (scripts/npc.gd), not here.

const SCHEMA_VERSION := 1

signal decided(request_id: int, action_id: String)


## Never blocks. The answer arrives later through `decided`.
func request_decision(_snapshot: Dictionary) -> void:
	pass
