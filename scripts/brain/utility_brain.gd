class_name UtilityBrain
extends Brain
## Deterministically scores every legal action and chooses the highest.
##
## This is the offline decision-maker and the fallback for Jev. It never
## changes NPC state and never returns an action outside legal_actions.

## Retained so the debug UI can eventually display why a choice was made.
var last_scores: Dictionary = {}


func request_decision(snapshot: Dictionary) -> void:
	last_scores = score_actions(snapshot)
	var action_id := _best_action(
		snapshot.get("legal_actions", []),
		last_scores
	)
	_answer.call_deferred(
		int(snapshot.get("request_id", -1)),
		action_id
	)


static func pick(snapshot: Dictionary) -> String:
	var scores := score_actions(snapshot)
	return _best_action(snapshot.get("legal_actions", []), scores)


static func score_actions(snapshot: Dictionary) -> Dictionary:
	var scores := {}
	var legal: Array = snapshot.get("legal_actions", [])

	for raw_action in legal:
		var action_id := String(raw_action)
		scores[action_id] = _score_action(action_id, snapshot)

	return scores


static func _best_action(legal: Array, scores: Dictionary) -> String:
	if legal.is_empty():
		return ""

	var best_action := String(legal[0])
	var best_score := float(scores.get(best_action, -INF))

	# Using > instead of >= makes ties deterministic: the first legal action
	# keeps priority.
	for raw_action in legal:
		var action_id := String(raw_action)
		var score := float(scores.get(action_id, -INF))

		if score > best_score:
			best_action = action_id
			best_score = score

	return best_action


static func _score_action(action_id: String, snapshot: Dictionary) -> float:
	var npc: Dictionary = snapshot.get("npc", {})
	var manager: Dictionary = snapshot.get("manager", {})

	var personality := String(npc.get("personality", ""))
	var station := String(npc.get("station", ""))
	var energy := float(npc.get("energy", 100.0))
	var mood := float(npc.get("mood", Balance.MOOD_START))
	var manager_opinion := float(
		npc.get("opinion_of_manager", Balance.OPINION_NEUTRAL)
	)
	var manager_in_range := bool(manager.get("in_range", false))

	var verb := action_id
	var target := ""
	var colon := action_id.find(":")

	if colon >= 0:
		verb = action_id.substr(0, colon)
		target = action_id.substr(colon + 1)

	var score := 0.0

	match verb:
		"work":
			score = (
				Balance.UTILITY_WORK_BASE
				+ energy * Balance.UTILITY_WORK_ENERGY_WEIGHT
				+ mood * Balance.UTILITY_WORK_MOOD_WEIGHT
				+ manager_opinion
					* Balance.UTILITY_WORK_MANAGER_OPINION_WEIGHT
			)

			if personality == "Lazy":
				if manager_in_range:
					score += Balance.UTILITY_LAZY_WATCHED_WORK_BONUS
				else:
					score -= Balance.UTILITY_LAZY_UNWATCHED_WORK_PENALTY

			if personality == "Overachiever":
				score += Balance.UTILITY_OVERACHIEVER_WORK_BONUS

			if (
				personality == "Clean freak"
				and station == "cleaning"
				and _has_recent_event(
					snapshot,
					"spill_nearby",
					Balance.UTILITY_SPILL_MEMORY
				)
			):
				score += Balance.UTILITY_CLEAN_SPILL_BONUS

		"slack":
			score = (
				Balance.UTILITY_SLACK_BASE
				+ (100.0 - energy)
					* Balance.UTILITY_SLACK_EXHAUSTION_WEIGHT
				+ maxf(Balance.MOOD_START - mood, 0.0)
					* Balance.UTILITY_SLACK_BAD_MOOD_WEIGHT
				+ maxf(
					Balance.OPINION_NEUTRAL - manager_opinion,
					0.0
				) * Balance.UTILITY_SLACK_LOW_MANAGER_OPINION_WEIGHT
			)

			if personality == "Lazy":
				if manager_in_range:
					score -= Balance.UTILITY_LAZY_WATCHED_SLACK_PENALTY
				else:
					score += Balance.UTILITY_LAZY_UNWATCHED_SLACK_BONUS

			if personality == "Overachiever":
				score -= Balance.UTILITY_OVERACHIEVER_SLACK_PENALTY

		"break":
			score = (
				Balance.UTILITY_BREAK_BASE
				+ (100.0 - energy)
					* Balance.UTILITY_BREAK_EXHAUSTION_WEIGHT
				+ maxf(Balance.MOOD_START - mood, 0.0)
					* Balance.UTILITY_BREAK_BAD_MOOD_WEIGHT
			)

			if personality == "Overachiever":
				score -= Balance.UTILITY_OVERACHIEVER_BREAK_PENALTY

		"switch":
			score = Balance.UTILITY_SWITCH_BASE

			if (
				personality == "Clean freak"
				and target == "cleaning"
				and _has_recent_event(
					snapshot,
					"spill_nearby",
					Balance.UTILITY_SPILL_MEMORY
				)
			):
				score += Balance.UTILITY_CLEAN_SPILL_BONUS

		"chat":
			var coworker := _find_coworker(snapshot, target)
			score = (
				Balance.UTILITY_CHAT_BASE
				+ float(
					coworker.get(
						"my_opinion_of_them",
						Balance.OPINION_NEUTRAL
					)
				) * Balance.UTILITY_CHAT_OPINION_WEIGHT
			)

			if String(coworker.get("action", "")) in ["slack", "break"]:
				score += Balance.UTILITY_CHAT_IDLE_TARGET_BONUS

			if personality == "Chatty":
				score += Balance.UTILITY_CHATTY_CHAT_BONUS

			# Prevent Chatty NPCs from repeatedly trapping the same coworker
			# in an endless chat loop.
			if _has_recent_named_event(
				snapshot,
				"chatted_with",
				target,
				Balance.UTILITY_CHAT_REPEAT_WINDOW
			):
				score -= Balance.UTILITY_CHAT_REPEAT_PENALTY

		"fight":
			var coworker := _find_coworker(snapshot, target)
			var my_opinion := float(
				coworker.get(
					"my_opinion_of_them",
					Balance.OPINION_NEUTRAL
				)
			)
			var their_opinion := float(
				coworker.get(
					"their_opinion_of_me",
					Balance.OPINION_NEUTRAL
				)
			)

			score = (
				Balance.UTILITY_FIGHT_BASE
				+ maxf(Balance.OPINION_NEUTRAL - my_opinion, 0.0)
					* Balance.UTILITY_FIGHT_MY_DISLIKE_WEIGHT
				+ maxf(
					Balance.OPINION_NEUTRAL - their_opinion,
					0.0
				) * Balance.UTILITY_FIGHT_THEIR_DISLIKE_WEIGHT
			)

			if (
				personality == "Irritable"
				or String(coworker.get("personality", "")) == "Irritable"
			):
				score += Balance.UTILITY_IRRITABLE_FIGHT_BONUS

		"refuse":
			score = (
				Balance.UTILITY_REFUSE_BASE
				+ maxf(
					Balance.OPINION_NEUTRAL - manager_opinion,
					0.0
				) * Balance.UTILITY_REFUSE_LOW_MANAGER_OPINION_WEIGHT
				+ maxf(Balance.MOOD_START - mood, 0.0)
					* Balance.UTILITY_REFUSE_BAD_MOOD_WEIGHT
			)

			var reassignments := _recent_event_count(
				snapshot,
				"reassigned",
				Balance.UTILITY_REASSIGN_MEMORY
			)
			var reassignment_pressure := (
				float(reassignments)
				* Balance.UTILITY_REASSIGN_PENALTY
			)

			if personality == "Irritable":
				reassignment_pressure *= (
					Balance.UTILITY_IRRITABLE_REASSIGN_MULTIPLIER
				)

			score += reassignment_pressure

		_:
			# Unknown actions remain selectable but lose against every known
			# action. The NPC state machine will still validate the answer.
			score = -INF

	return score


static func _find_coworker(
	snapshot: Dictionary,
	coworker_name: String
) -> Dictionary:
	for coworker: Dictionary in snapshot.get("coworkers", []):
		if String(coworker.get("name", "")) == coworker_name:
			return coworker

	return {}


static func _has_recent_event(
	snapshot: Dictionary,
	event_type: String,
	max_age: float
) -> bool:
	return _recent_event_count(snapshot, event_type, max_age) > 0


static func _recent_event_count(
	snapshot: Dictionary,
	event_type: String,
	max_age: float
) -> int:
	var count := 0

	for event: Dictionary in snapshot.get("recent_events", []):
		if (
			String(event.get("type", "")) == event_type
			and float(event.get("seconds_ago", INF)) <= max_age
		):
			count += 1

	return count


static func _has_recent_named_event(
	snapshot: Dictionary,
	event_type: String,
	other_name: String,
	max_age: float
) -> bool:
	for event: Dictionary in snapshot.get("recent_events", []):
		if (
			String(event.get("type", "")) == event_type
			and String(event.get("name", "")) == other_name
			and float(event.get("seconds_ago", INF)) <= max_age
		):
			return true

	return false


func _answer(request_id: int, action_id: String) -> void:
	decided.emit(request_id, action_id)