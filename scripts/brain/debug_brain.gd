class_name DebugBrain
extends Brain
## Behaves like the Obedient brain, except that the debug overlay can force
## any legal action on its NPC. This is how every interaction is proven to
## work. Forced actions still go through the state machine, wind-up included.

var _forced := ""


func force(action_id: String) -> void:
	_forced = action_id


func request_decision(snapshot: Dictionary) -> void:
	var action_id := ObedientBrain.pick(snapshot)
	if _forced != "" and _forced in snapshot.legal_actions:
		action_id = _forced
		_forced = ""
	_answer.call_deferred(snapshot.request_id, action_id)


func _answer(request_id: int, action_id: String) -> void:
	decided.emit(request_id, action_id)
