class_name BlueprintManager extends RefCounted

var main

var cached_blueprints: Array = []


func init(main_node) -> void:
	main = main_node


func save_blueprint(blueprint_name: String, object_ids: Array) -> void:
	if object_ids.is_empty():
		return
	var session = main.session
	if session.is_empty():
		return
	var request := HTTPRequest.new()
	main.add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({
		"token": session.token,
		"name": blueprint_name,
		"objectIds": object_ids
	})
	var url = "%s/api/blueprints" % main.backend_url_input.text.rstrip("/")
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result = await request.request_completed
		if int(result[1]) == 200:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			if payload != null and payload.has("blueprint"):
				cached_blueprints.append(payload.blueprint)
				main.status_label.text = "Blueprint saved: %s" % blueprint_name
		else:
			main.status_label.text = "Failed to save blueprint"
	request.queue_free()


func load_blueprints() -> void:
	var session = main.session
	if session.is_empty():
		return
	var request := HTTPRequest.new()
	main.add_child(request)
	var url = "%s/api/blueprints?token=%s" % [main.backend_url_input.text.rstrip("/"), session.token]
	if request.request(url) == OK:
		var result = await request.request_completed
		if int(result[1]) == 200:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			if payload != null:
				cached_blueprints = payload.get("blueprints", [])
				main.status_label.text = "Loaded %d blueprints" % cached_blueprints.size()
		else:
			main.status_label.text = "Failed to load blueprints"
	request.queue_free()


func place_blueprint(blueprint_id: String, position: Vector3) -> void:
	var session = main.session
	if session.is_empty():
		return
	var request := HTTPRequest.new()
	main.add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({
		"token": session.token,
		"regionId": session.regionId,
		"x": position.x,
		"z": position.z
	})
	var url = "%s/api/blueprints/%s/place" % [main.backend_url_input.text.rstrip("/"), blueprint_id]
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result = await request.request_completed
		if int(result[1]) == 200:
			main.status_label.text = "Blueprint placed"
			await main._load_region_objects(session.regionId)
		else:
			main.status_label.text = "Failed to place blueprint"
	request.queue_free()


func delete_blueprint(blueprint_id: String) -> void:
	var session = main.session
	if session.is_empty():
		return
	var request := HTTPRequest.new()
	main.add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"token": session.token})
	var url = "%s/api/blueprints/%s" % [main.backend_url_input.text.rstrip("/"), blueprint_id]
	if request.request(url, headers, HTTPClient.METHOD_DELETE, body) == OK:
		var result = await request.request_completed
		if int(result[1]) == 200:
			cached_blueprints = cached_blueprints.filter(func(b): return b.id != blueprint_id)
			main.status_label.text = "Blueprint deleted"
		else:
			main.status_label.text = "Failed to delete blueprint"
	request.queue_free()
