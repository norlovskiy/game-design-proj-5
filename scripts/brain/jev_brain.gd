class_name JevBrain
extends Brain
## Sends NPC snapshots to the protected Cloudflare Worker.
## Invalid, failed, or slow answers are handled by NPC's Utility fallback.

@export var proxy_url := ""

var last_action := ""
var last_confidence := 0.0
var last_probabilities: Dictionary = {}
var last_model := ""
var last_error := ""

## request_id -> HTTPRequest
var _requests: Dictionary = {}

@export_range(0.0, 1.0, 0.05)
var minimum_confidence := 0.40

var npc_name := "Unknown"

var npc_personality := ""

var npc_station := ""

func request_decision(snapshot: Dictionary) -> void:
	var request_id := int(snapshot.get("request_id", -1))
	var legal_actions: Array = snapshot.get("legal_actions", [])

	var npc: Dictionary = snapshot.get("npc", {})
	npc_name = String(npc.get("name", "Unknown"))

	npc_personality = String(npc.get("personality", ""))

	npc_station = String(npc.get("station", ""))

	if request_id < 0:
		_fail.call_deferred(request_id, "missing request_id")
		return

	if legal_actions.is_empty():
		_fail.call_deferred(request_id, "no legal actions")
		return

	if proxy_url.strip_edges().is_empty():
		_fail.call_deferred(request_id, "missing proxy URL")
		return

	# A newer snapshot makes every previous request stale.
	_cancel_outstanding_requests()

	var http := HTTPRequest.new()
	http.timeout = Balance.BRAIN_TIMEOUT + 0.25
	add_child(http)

	_requests[request_id] = http

	http.request_completed.connect(
		_on_request_completed.bind(
			request_id,
			legal_actions.duplicate(),
			http
		)
	)

	var headers := PackedStringArray([
		"Content-Type: application/json",
	])

	var request_error := http.request(
		proxy_url.strip_edges(),
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(snapshot)
	)

	if request_error != OK:
		_requests.erase(request_id)
		http.queue_free()

		_fail.call_deferred(
			request_id,
			"request could not start: %s"
			% error_string(request_error)
		)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	request_id: int,
	legal_actions: Array,
	http: HTTPRequest
) -> void:
	# The request may have been cancelled because a newer snapshot arrived.
	if not _requests.has(request_id):
		return

	_requests.erase(request_id)

	if is_instance_valid(http):
		http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		_fail(
			request_id,
			"network result %d" % result
		)
		return

	if response_code != 200:
		_fail(
			request_id,
			"proxy HTTP %d" % response_code
		)
		return

	var parsed = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if not parsed is Dictionary:
		_fail(request_id, "invalid proxy JSON")
		return

	var response: Dictionary = parsed
	var returned_id := int(
		response.get("request_id", -1)
	)
	var action_id := String(
		response.get("action_id", "")
	)

	if returned_id != request_id:
		_fail(request_id, "wrong request_id")
		return

	if action_id not in legal_actions:
		_fail(
			request_id,
			"proxy returned illegal action: %s"
			% action_id
		)
		return

	# Kit must work whenever work is available.
	if (
		npc_personality == "Overachiever"
		and action_id in ["slack", "break"]
		and "work" in legal_actions
	):
		_fail(
			request_id,
			"Overachiever chose %s while work was available" % action_id
		)
		return

	var switch_available := false

	for legal_action in legal_actions:
		if String(legal_action).begins_with("switch:"):
			switch_available = true
			break

	# Unassigned Kit immediately claims an available station.
	if (
		npc_personality == "Overachiever"
		and npc_station.is_empty()
		and switch_available
		and not action_id.begins_with("switch:")
	):
		_fail(
			request_id,
			"Overachiever ignored available work"
		)
		return

	last_action = action_id
	last_confidence = clampf(
		float(response.get("confidence", 0.0)),
		0.0,
		1.0
	)

	if last_confidence < minimum_confidence:
		_fail(
			request_id,
			"confidence %.2f below %.2f"
			% [last_confidence, minimum_confidence]
		)
		return

	var probabilities = response.get(
		"probabilities",
		{}
	)

	last_probabilities = (
		probabilities
		if probabilities is Dictionary
		else {}
	)

	last_model = String(
		response.get("model", "Jev")
	)
	last_error = ""

	print(
		"JEV DECISION %s [%d]: %s (confidence %.2f)"
		% [
			npc_name,
			request_id,
			action_id,
			last_confidence,
		]
	)

	decided.emit(request_id, action_id)


func _cancel_outstanding_requests() -> void:
	for value in _requests.values():
		var http := value as HTTPRequest

		if http and is_instance_valid(http):
			http.cancel_request()
			http.queue_free()

	_requests.clear()


func _fail(request_id: int, reason: String) -> void:
	last_error = reason

	print(
		"JEV FALLBACK %s [%d]: %s"
		% [
			npc_name,
			request_id,
			reason,
		]
	)

	# An empty action is deliberately invalid. NPC will immediately ask its
	# Utility fallback instead of waiting for another timeout.
	decided.emit(request_id, "")
