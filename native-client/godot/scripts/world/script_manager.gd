# ----- Changes needed in main.gd (DO NOT apply automatically) -----
# var script_manager = ScriptManager.new()
# In _ready():  script_manager.init(self)
# In ws message handler, add:
#   "script:triggered":
#       script_manager._on_script_triggered(parsed)
# In _process(delta):
#   script_manager.check_trigger_zones(Vector3(avatar_x, avatar_y, avatar_z))
# Add two HTTPRequest children under $Network:
#   $Network/ScriptsRequest
#   $Network/ScriptsActionRequest
# -------------------------------------------------------------------

class_name ScriptManager extends RefCounted

var main
var scripts: Array = []
var trigger_zones: Array = []
var _inside_zone_ids: Dictionary = {}
var _http_scripts: HTTPRequest
var _http_action: HTTPRequest

func init(main_node) -> void:
	main = main_node
	# We create our own HTTPRequest nodes so main.gd doesn't need to declare them
	_http_scripts = HTTPRequest.new()
	_http_scripts.name = "ScriptMgrScripts"
	main.add_child(_http_scripts)
	_http_scripts.request_completed.connect(_on_scripts_request_completed)

	_http_action = HTTPRequest.new()
	_http_action.name = "ScriptMgrAction"
	main.add_child(_http_action)
	_http_action.request_completed.connect(_on_action_request_completed)


func _base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _token() -> String:
	return main.session.get("token", "")


# ---------- Load scripts for the current region ----------

func load_scripts(region_id: String) -> void:
	var url = _base_url() + "/api/scripts?token=" + _token() + "&regionId=" + region_id
	_http_scripts.request(url, [], HTTPClient.METHOD_GET)


func _on_scripts_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("ScriptManager: failed to load scripts, HTTP %d" % response_code)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed.has("scripts"):
		return

	scripts = parsed["scripts"]

	# Also load trigger zones for the region
	var region_id = main.session.get("regionId", "")
	if region_id != "":
		_load_trigger_zones(region_id)


func _load_trigger_zones(region_id: String) -> void:
	var url = _base_url() + "/api/trigger-zones?token=" + _token() + "&regionId=" + region_id
	# Reuse the same request node (sequential)
	_http_action.request(url, [], HTTPClient.METHOD_GET)


# ---------- Create a new script ----------

func create_script(script_name: String, parcel_id: String) -> void:
	var region_id = main.session.get("regionId", "")
	var payload = JSON.stringify({
		"token": _token(),
		"name": script_name,
		"regionId": region_id,
		"parcelId": parcel_id
	})
	var headers = ["Content-Type: application/json"]
	_http_action.request(_base_url() + "/api/scripts", headers, HTTPClient.METHOD_POST, payload)


# ---------- Update script graph ----------

func update_script(script_id: String, nodes: Array, connections: Array) -> void:
	var payload = JSON.stringify({
		"token": _token(),
		"nodes": nodes,
		"connections": connections
	})
	var headers = ["Content-Type: application/json"]
	_http_action.request(_base_url() + "/api/scripts/" + script_id, headers, HTTPClient.METHOD_PUT, payload)


# ---------- Toggle script enabled/disabled ----------

func toggle_script(script_id: String) -> void:
	var payload = JSON.stringify({ "token": _token() })
	var headers = ["Content-Type: application/json"]
	_http_action.request(_base_url() + "/api/scripts/" + script_id + "/toggle", headers, HTTPClient.METHOD_POST, payload)


# ---------- Client-side proximity check ----------

func check_trigger_zones(position: Vector3) -> void:
	for zone in trigger_zones:
		var zone_id = zone.get("id", "")
		if zone_id == "":
			continue

		var zpos = zone.get("position", {})
		var zx = float(zpos.get("x", 0))
		var zy = float(zpos.get("y", 0))
		var zz = float(zpos.get("z", 0))
		var zone_pos = Vector3(zx, zy, zz)

		var inside = false
		var shape = zone.get("shape", "sphere")

		if shape == "sphere":
			var radius = float(zone.get("radius", 3))
			inside = position.distance_to(zone_pos) <= radius
		else:
			var sz = zone.get("size", {})
			var half_x = float(sz.get("x", 3)) / 2.0
			var half_y = float(sz.get("y", 3)) / 2.0
			var half_z = float(sz.get("z", 3)) / 2.0
			inside = (
				absf(position.x - zone_pos.x) <= half_x
				and absf(position.y - zone_pos.y) <= half_y
				and absf(position.z - zone_pos.z) <= half_z
			)

		var was_inside = _inside_zone_ids.has(zone_id)

		if inside and not was_inside:
			_inside_zone_ids[zone_id] = true
			_on_zone_entered(zone)
		elif not inside and was_inside:
			_inside_zone_ids.erase(zone_id)
			_on_zone_exited(zone)


func _on_zone_entered(zone: Dictionary) -> void:
	push_warning("ScriptManager: entered trigger zone %s" % zone.get("id", ""))


func _on_zone_exited(zone: Dictionary) -> void:
	push_warning("ScriptManager: exited trigger zone %s" % zone.get("id", ""))


# ---------- Handle script:triggered events from WebSocket ----------

func handle_script_triggered(event: Dictionary) -> void:
	var actions = event.get("actions", [])
	for action in actions:
		var action_type = action.get("type", "")
		var params = action.get("params", {})
		match action_type:
			"chat":
				var msg = params.get("message", "")
				if msg != "" and main.has_method("_append_chat"):
					pass # main can handle chat display
				push_warning("ScriptManager: script chat — %s" % msg)
			"move_object":
				push_warning("ScriptManager: move_object %s" % str(params))
			"toggle":
				push_warning("ScriptManager: toggle %s" % str(params))
			"spawn_particles":
				push_warning("ScriptManager: spawn_particles %s" % str(params))
			"delay":
				push_warning("ScriptManager: delay %s seconds" % str(params.get("seconds", 1)))


# ---------- Generic action request callback ----------

func _on_action_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("ScriptManager: action request failed, HTTP %d" % response_code)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null:
		return

	# If this was a trigger zones response, cache them
	if parsed.has("zones"):
		trigger_zones = parsed["zones"]
		_inside_zone_ids.clear()

	# If this was a script creation / update response, refresh the cache
	if parsed.has("script"):
		var updated = parsed["script"]
		var found = false
		for i in range(scripts.size()):
			if scripts[i].get("id", "") == updated.get("id", ""):
				scripts[i] = updated
				found = true
				break
		if not found:
			scripts.append(updated)
