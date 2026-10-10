class_name ObedientBrain
extends Brain
## Always picks Work when it is legal. Lets the game run with no
## decision-making at all. Never refuses an order.


func request_decision(snapshot: Dictionary) -> void:
	_answer.call_deferred(snapshot.request_id, pick(snapshot))


static func pick(snapshot: Dictionary) -> String:
	var legal: Array = snapshot.legal_actions
	if "work" in legal:
		return "work"
	# An order arrives as [<ordered action>, "refuse"]; obey it.
	if "refuse" in legal:
		for action_id in legal:
			if action_id != "refuse":
				return action_id
	# Out of energy: rest. No station: stand by.
	if snapshot.npc.energy <= 0 and "break" in legal:
		return "break"
	return "slack"


func _answer(request_id: int, action_id: String) -> void:
	decided.emit(request_id, action_id)
