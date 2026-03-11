# InteractiveManager — handles interactive object state and animation
#
# NOTE for main.gd: instantiate and initialize this module:
#   var interactive_manager = InteractiveManager.new()
#   interactive_manager.init(self)
#
# In _process(delta):
#   interactive_manager._process_interactives(delta)
#
# In WebSocket message handler, for "interactive:state_changed":
#   interactive_manager._on_state_changed(event)
#
# For right-click detection on interactive objects:
#   interactive_manager.try_interact(object_id)

class_name InteractiveManager extends RefCounted

var main
var _interactives: Dictionary = {}
var _http_request: HTTPRequest = null
var _interact_request: HTTPRequest = null

func init(main_node) -> void:
	main = main_node
	_http_request = HTTPRequest.new()
	_http_request.request_completed.connect(_on_load_completed)
	main.add_child(_http_request)
	_interact_request = HTTPRequest.new()
	_interact_request.request_completed.connect(_on_interact_completed)
	main.add_child(_interact_request)

# ---------------------------------------------------------------------------
# Network: load interactives for a region
# ---------------------------------------------------------------------------

func load_interactives(region_id: String) -> void:
	_interactives.clear()
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")
	if token == "":
		return
	var url = "%s/api/interactives?regionId=%s&token=%s" % [base_url, region_id, token]
	_http_request.request(url, [], HTTPClient.METHOD_GET)

func _on_load_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.has("interactives"):
		return
	var items = json["interactives"]
	for item in items:
		var obj_id = item.get("objectId", "")
		if obj_id != "":
			_interactives[obj_id] = item

# ---------------------------------------------------------------------------
# Network: interact with an object
# ---------------------------------------------------------------------------

func interact_with(object_id: String) -> void:
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")
	if token == "":
		return
	var url = "%s/api/interactives/%s/interact" % [base_url, object_id]
	var headers = ["Content-Type: application/json"]
	var payload = JSON.stringify({"token": token})
	_interact_request.request(url, headers, HTTPClient.METHOD_POST, payload)

func _on_interact_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.has("interactive"):
		return
	var interactive = json["interactive"]
	var obj_id = interactive.get("objectId", "")
	if obj_id != "":
		_interactives[obj_id] = interactive

# ---------------------------------------------------------------------------
# WebSocket event handler
# ---------------------------------------------------------------------------

func handle_ws_event(event: Dictionary) -> void:
	var event_type = event.get("type", "")
	if event_type != "interactive:state_changed":
		return
	_on_state_changed(event)

func _on_state_changed(event: Dictionary) -> void:
	var object_id = event.get("objectId", "")
	if object_id == "":
		return
	if _interactives.has(object_id):
		_interactives[object_id]["state"] = event.get("newState", {})
		_interactives[object_id]["interactionType"] = event.get("interactionType", "")
	else:
		_interactives[object_id] = {
			"objectId": object_id,
			"interactionType": event.get("interactionType", ""),
			"state": event.get("newState", {}),
			"config": {},
		}

# ---------------------------------------------------------------------------
# Right-click interaction helper
# ---------------------------------------------------------------------------

func is_interactive(object_id: String) -> bool:
	return _interactives.has(object_id)

func try_interact(object_id: String) -> bool:
	if not _interactives.has(object_id):
		return false
	interact_with(object_id)
	return true

func get_interaction_label(object_id: String) -> String:
	if not _interactives.has(object_id):
		return ""
	var entry = _interactives[object_id]
	var itype = entry.get("interactionType", "")
	match itype:
		"door":
			var is_open = entry.get("state", {}).get("open", false)
			return "Close" if is_open else "Open"
		"elevator":
			var is_moving = entry.get("state", {}).get("moving", false)
			return "Stop" if is_moving else "Start"
		"platform":
			var is_moving = entry.get("state", {}).get("moving", false)
			return "Stop" if is_moving else "Start"
		"button", "switch":
			var is_active = entry.get("state", {}).get("active", false)
			return "Deactivate" if is_active else "Activate"
		"teleporter":
			return "Teleport"
		"chest":
			var is_open = entry.get("state", {}).get("open", false)
			return "Close" if is_open else "Open"
		_:
			return "Interact"

# ---------------------------------------------------------------------------
# Animation tick — call from main._process(delta)
# ---------------------------------------------------------------------------

func _process_interactives(delta: float) -> void:
	for object_id in _interactives:
		var entry = _interactives[object_id]
		var itype = entry.get("interactionType", "")
		var state = entry.get("state", {})
		var config = entry.get("config", {})

		# Find the corresponding scene node
		if not main.object_nodes.has(object_id):
			continue
		var node = main.object_nodes[object_id]
		if node == null or not is_instance_valid(node):
			continue

		match itype:
			"door":
				_animate_door(node, state, config, delta)
			"elevator":
				_animate_elevator(node, state, config, delta)
			"platform":
				_animate_platform(node, state, config, delta)

func _animate_door(node: Node3D, state: Dictionary, config: Dictionary, delta: float) -> void:
	var is_open = state.get("open", false)
	var open_rot = config.get("openRotationY", 1.5708)
	var closed_rot = config.get("closedRotationY", 0.0)
	var speed = config.get("speed", 2.0)
	var target_rot = open_rot if is_open else closed_rot
	var current_rot = node.rotation.y
	if absf(current_rot - target_rot) > 0.01:
		if current_rot < target_rot:
			node.rotation.y = minf(current_rot + speed * delta, target_rot)
		else:
			node.rotation.y = maxf(current_rot - speed * delta, target_rot)

func _animate_elevator(node: Node3D, state: Dictionary, _config: Dictionary, _delta: float) -> void:
	# The authoritative Y position comes from server state
	var current_y = state.get("currentY", 0.0)
	node.position.y = current_y

func _animate_platform(node: Node3D, state: Dictionary, _config: Dictionary, _delta: float) -> void:
	# The authoritative position comes from server state
	var cx = state.get("currentX", node.position.x)
	var cy = state.get("currentY", node.position.y)
	var cz = state.get("currentZ", node.position.z)
	node.position = Vector3(cx, cy, cz)
