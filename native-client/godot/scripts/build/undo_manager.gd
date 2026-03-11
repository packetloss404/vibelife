class_name UndoManager
extends RefCounted

var main  # reference to main node

const MAX_UNDO_STACK := 20

var _undo_stack: Array = []  # Array of {action, object_id, before_state, after_state}
var _redo_stack: Array = []


func init(main_node) -> void:
	main = main_node


func push_action(action_type: String, object_id: String, before_state, after_state) -> void:
	_undo_stack.append({
		"action": action_type,
		"object_id": object_id,
		"before_state": before_state,
		"after_state": after_state
	})
	if _undo_stack.size() > MAX_UNDO_STACK:
		_undo_stack.pop_front()
	# Clear redo stack on new action
	_redo_stack.clear()


func undo() -> void:
	if _undo_stack.is_empty():
		main.status_label.text = "Nothing to undo"
		return

	var entry: Dictionary = _undo_stack.pop_back()
	_redo_stack.append(entry)

	var action: String = entry.action
	var object_id: String = entry.object_id
	var before_state = entry.before_state
	var after_state = entry.after_state

	match action:
		"move", "rotate", "scale":
			if before_state != null:
				await _apply_object_state(object_id, before_state)
				main.status_label.text = "Undo %s" % action
		"create":
			# Undo create = delete the object
			await _delete_object(object_id)
			main.status_label.text = "Undo create"
		"delete":
			# Undo delete = recreate the object
			if before_state != null:
				await _recreate_object(before_state)
				main.status_label.text = "Undo delete"


func redo() -> void:
	if _redo_stack.is_empty():
		main.status_label.text = "Nothing to redo"
		return

	var entry: Dictionary = _redo_stack.pop_back()
	_undo_stack.append(entry)

	var action: String = entry.action
	var object_id: String = entry.object_id
	var before_state = entry.before_state
	var after_state = entry.after_state

	match action:
		"move", "rotate", "scale":
			if after_state != null:
				await _apply_object_state(object_id, after_state)
				main.status_label.text = "Redo %s" % action
		"create":
			# Redo create = recreate the object
			if after_state != null:
				await _recreate_object(after_state)
				main.status_label.text = "Redo create"
		"delete":
			# Redo delete = delete it again
			await _delete_object(object_id)
			main.status_label.text = "Redo delete"


func _apply_object_state(object_id: String, state: Dictionary) -> void:
	if not main.objects.object_nodes.has(object_id):
		return
	var node = main.objects.object_nodes[object_id]
	node.position = Vector3(state.x, state.y, state.z)
	node.rotation.y = state.rotationY
	var s: float = state.scale
	node.scale = Vector3(s, s, s)

	# Send update to server
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({
		"token": main.session.token,
		"x": state.x,
		"y": state.y,
		"z": state.z,
		"rotationY": state.rotationY,
		"scale": state.scale
	})
	var url := "%s/api/objects/%s" % [main.backend_url, object_id]
	var request := HTTPRequest.new()
	main.add_child(request)
	if request.request(url, headers, HTTPClient.METHOD_PATCH, body) == OK:
		await request.request_completed
	request.queue_free()


func _delete_object(object_id: String) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"token": main.session.token})
	var url := "%s/api/objects/%s" % [main.backend_url, object_id]
	var request := HTTPRequest.new()
	main.add_child(request)
	if request.request(url, headers, HTTPClient.METHOD_DELETE, body) == OK:
		await request.request_completed
	request.queue_free()
	if main.objects.object_nodes.has(object_id):
		main.objects.object_nodes[object_id].queue_free()
		main.objects.object_nodes.erase(object_id)


func _recreate_object(state: Dictionary) -> void:
	# Re-create an object at the stored state position
	# This uses the asset from the build asset selector as a fallback
	var asset: String = state.get("asset", main.build_assets[main.build_asset_select.selected])
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({
		"token": main.session.token,
		"asset": asset,
		"x": state.get("x", 0.0),
		"y": state.get("y", 0.0),
		"z": state.get("z", 0.0),
		"rotationY": state.get("rotationY", 0.0),
		"scale": state.get("scale", 1.0)
	})
	var url := "%s/api/regions/%s/objects" % [main.backend_url, main.session.regionId]
	var request := HTTPRequest.new()
	main.add_child(request)
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		await request.request_completed
	request.queue_free()
	await main._load_region_objects(main.session.regionId)
