class_name PetManager extends RefCounted

var main
var active_pets = {}  # petId -> { node: Node3D, state: Dictionary }
var my_pet_id = ""

func init(main_node) -> void:
	main = main_node

func _base_url() -> String:
	return main.backend_url_input.text.rstrip("/")

func _token() -> String:
	return main.session.get("token", "")

func _headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json"])

# --- REST API calls ---

func adopt_pet(pet_name: String, species: String) -> void:
	var url = _base_url() + "/api/pets/adopt"
	var body = JSON.stringify({ "token": _token(), "name": pet_name, "species": species })
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _hdrs, resp_body):
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if json and json.has("pet"):
			print("[PetManager] Adopted: ", json["pet"]["name"], " (", json["pet"]["species"], ")")
		else:
			print("[PetManager] Adopt failed: ", resp_body.get_string_from_utf8())
		http.queue_free()
	)
	http.request(url, _headers(), HTTPClient.METHOD_POST, body)

func summon_pet(pet_id: String) -> void:
	var url = _base_url() + "/api/pets/" + pet_id + "/summon"
	var body = JSON.stringify({ "token": _token() })
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _hdrs, resp_body):
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if json and json.has("pet") and json.has("state"):
			my_pet_id = json["pet"]["id"]
			_add_pet_node(json["pet"], json["state"])
			print("[PetManager] Summoned: ", json["pet"]["name"])
		else:
			print("[PetManager] Summon failed: ", resp_body.get_string_from_utf8())
		http.queue_free()
	)
	http.request(url, _headers(), HTTPClient.METHOD_POST, body)

func dismiss_pet() -> void:
	if my_pet_id == "":
		return
	var url = _base_url() + "/api/pets/" + my_pet_id + "/dismiss"
	var body = JSON.stringify({ "token": _token() })
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _hdrs, resp_body):
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if json and json.has("ok"):
			_remove_pet_node(my_pet_id)
			my_pet_id = ""
			print("[PetManager] Dismissed pet")
		else:
			print("[PetManager] Dismiss failed: ", resp_body.get_string_from_utf8())
		http.queue_free()
	)
	http.request(url, _headers(), HTTPClient.METHOD_POST, body)

func feed_pet() -> void:
	if my_pet_id == "":
		return
	var url = _base_url() + "/api/pets/" + my_pet_id + "/feed"
	var body = JSON.stringify({ "token": _token() })
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _hdrs, resp_body):
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if json and json.has("message"):
			print("[PetManager] ", json["message"])
		http.queue_free()
	)
	http.request(url, _headers(), HTTPClient.METHOD_POST, body)

func play_with_pet() -> void:
	if my_pet_id == "":
		return
	var url = _base_url() + "/api/pets/" + my_pet_id + "/play"
	var body = JSON.stringify({ "token": _token() })
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _hdrs, resp_body):
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if json and json.has("message"):
			print("[PetManager] ", json["message"])
		http.queue_free()
	)
	http.request(url, _headers(), HTTPClient.METHOD_POST, body)

func pet_pet() -> void:
	if my_pet_id == "":
		return
	var url = _base_url() + "/api/pets/" + my_pet_id + "/pet"
	var body = JSON.stringify({ "token": _token() })
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _hdrs, resp_body):
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if json and json.has("message"):
			print("[PetManager] ", json["message"])
		http.queue_free()
	)
	http.request(url, _headers(), HTTPClient.METHOD_POST, body)

func perform_trick(trick_name: String) -> void:
	if my_pet_id == "":
		return
	var url = _base_url() + "/api/pets/" + my_pet_id + "/trick"
	var body = JSON.stringify({ "token": _token(), "trick": trick_name })
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _hdrs, resp_body):
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if json and json.has("message"):
			print("[PetManager] ", json["message"])
		http.queue_free()
	)
	http.request(url, _headers(), HTTPClient.METHOD_POST, body)

func load_region_pets(region_id: String) -> void:
	# Clear existing pet nodes
	for pet_id in active_pets.keys():
		_remove_pet_node(pet_id)
	active_pets.clear()

	var url = _base_url() + "/api/pets/region/" + region_id
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _hdrs, resp_body):
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if json and json.has("pets"):
			for entry in json["pets"]:
				_add_pet_node(entry["pet"], entry["state"])
		http.queue_free()
	)
	http.request(url, _headers(), HTTPClient.METHOD_GET)

# --- Rendering ---

func _add_pet_node(pet: Dictionary, state: Dictionary) -> void:
	var pet_id = pet.get("id", "")
	if pet_id == "" or active_pets.has(pet_id):
		return

	var root = Node3D.new()
	root.name = "Pet_" + pet_id

	# Body: sphere
	var body_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	body_mesh.mesh = sphere
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color.from_string(pet.get("color", "#f5a623"), Color.ORANGE)
	body_mesh.material_override = body_mat
	body_mesh.position = Vector3(0, 0.25, 0)
	root.add_child(body_mesh)

	# Head: small cone
	var head_mesh = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.15
	cone.height = 0.2
	head_mesh.mesh = cone
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color.from_string(pet.get("accentColor", "#d0021b"), Color.RED)
	head_mesh.material_override = head_mat
	head_mesh.position = Vector3(0, 0.55, 0)
	root.add_child(head_mesh)

	# Name label
	var label = Label3D.new()
	label.text = pet.get("name", "Pet")
	label.font_size = 32
	label.position = Vector3(0, 0.8, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color.WHITE
	root.add_child(label)

	# Position
	var px = float(state.get("x", 0))
	var py = float(state.get("y", 0))
	var pz = float(state.get("z", 0))
	root.position = Vector3(px, py, pz)

	# Add to scene tree under dynamic world or root
	if main.has_node("DynamicWorld"):
		main.get_node("DynamicWorld").add_child(root)
	else:
		main.add_child(root)

	active_pets[pet_id] = { "node": root, "state": state, "pet": pet }

func _remove_pet_node(pet_id: String) -> void:
	if not active_pets.has(pet_id):
		return
	var entry = active_pets[pet_id]
	var node = entry["node"]
	if is_instance_valid(node):
		node.queue_free()
	active_pets.erase(pet_id)

# --- Process: animate pets following owners ---

func _process_pets(delta: float) -> void:
	for pet_id in active_pets.keys():
		var entry = active_pets[pet_id]
		var node = entry["node"] as Node3D
		var state = entry["state"] as Dictionary

		if not is_instance_valid(node):
			continue

		var target_x = float(state.get("targetX", state.get("x", 0)))
		var target_z = float(state.get("targetZ", state.get("z", 0)))
		var current = node.position

		var target = Vector3(target_x, 0, target_z)
		var diff = target - current
		var dist = diff.length()

		if dist > 0.3:
			var speed = 3.0 * delta
			if dist > 3.0:
				speed = 6.0 * delta
			var move_dir = diff.normalized() * min(speed, dist)
			node.position += move_dir
			# Face movement direction
			if move_dir.length() > 0.01:
				node.look_at(node.position + move_dir, Vector3.UP)
		else:
			# Idle bob
			node.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.05

# --- WebSocket event handlers ---

func handle_ws_event(event: Dictionary) -> void:
	var event_type = event.get("type", "")
	match event_type:
		"pet:summoned":
			if event.has("pet") and event.has("state"):
				_add_pet_node(event["pet"], event["state"])
		"pet:dismissed":
			var pet_id = event.get("petId", "")
			if pet_id != "":
				_remove_pet_node(pet_id)
		"pet:trick":
			var pet_id = event.get("petId", "")
			if active_pets.has(pet_id):
				_play_trick_animation(pet_id, event.get("trick", ""))
		"pet:state_updated":
			if event.has("pet") and event.has("state"):
				var pet_id = event["state"].get("petId", "")
				if active_pets.has(pet_id):
					active_pets[pet_id]["state"] = event["state"]
					active_pets[pet_id]["pet"] = event["pet"]
				else:
					_add_pet_node(event["pet"], event["state"])

func _play_trick_animation(pet_id: String, trick_name: String) -> void:
	if not active_pets.has(pet_id):
		return
	var entry = active_pets[pet_id]
	var node = entry["node"] as Node3D
	if not is_instance_valid(node):
		return

	# Simple trick feedback: bounce the pet up
	var tween = node.create_tween()
	match trick_name:
		"sit":
			tween.tween_property(node, "position:y", 0.0, 0.3)
		"jump", "dance", "spin":
			tween.tween_property(node, "position:y", 0.8, 0.2)
			tween.tween_property(node, "position:y", 0.0, 0.3)
		"roll_over":
			tween.tween_property(node, "rotation_degrees:z", 360.0, 0.5)
			tween.tween_property(node, "rotation_degrees:z", 0.0, 0.0)
		"wave", "play_dead", "fetch":
			tween.tween_property(node, "position:y", 0.5, 0.15)
			tween.tween_property(node, "position:y", 0.0, 0.2)
		_:
			tween.tween_property(node, "position:y", 0.4, 0.2)
			tween.tween_property(node, "position:y", 0.0, 0.2)
