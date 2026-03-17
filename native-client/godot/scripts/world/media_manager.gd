class_name MediaManager extends RefCounted

var main
var media_objects = {}
var _slideshow_timers = {}

var _load_request = null
var _attach_request = null
var _update_request = null
var _remove_request = null

func init(main_node) -> void:
	main = main_node

func _get_base_url() -> String:
	return main.backend_url_input.text.rstrip("/")

func _get_token() -> String:
	return main.session.get("token", "")

# --- HTTP helpers ---

func _make_request() -> HTTPRequest:
	var req = HTTPRequest.new()
	main.add_child(req)
	return req

func _cleanup_request(req: HTTPRequest) -> void:
	if req != null and is_instance_valid(req):
		req.queue_free()

# --- Load all media for a region ---

func load_media(region_id: String) -> void:
	var url = _get_base_url() + "/api/media?regionId=" + region_id
	_load_request = _make_request()
	_load_request.request_completed.connect(_on_load_completed)
	_load_request.request(url, [], HTTPClient.METHOD_GET)

func _on_load_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_cleanup_request(_load_request)
	_load_request = null
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.has("media"):
		return
	media_objects.clear()
	for item in json["media"]:
		var object_id = item.get("objectId", "")
		if object_id != "":
			media_objects[object_id] = item
	_render_media_objects()

# --- Attach media to an object ---

func attach_media(object_id: String, media_type: String, config: Dictionary) -> void:
	var url = _get_base_url() + "/api/media"
	var payload = JSON.stringify({
		"token": _get_token(),
		"objectId": object_id,
		"mediaType": media_type,
		"config": config
	})
	_attach_request = _make_request()
	_attach_request.request_completed.connect(_on_attach_completed)
	_attach_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)

func _on_attach_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_cleanup_request(_attach_request)
	_attach_request = null
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.has("media"):
		return
	var media = json["media"]
	var object_id = media.get("objectId", "")
	if object_id != "":
		media_objects[object_id] = media
		_render_single_media(object_id, media)

# --- Update media config ---

func update_media(object_id: String, config: Dictionary) -> void:
	var url = _get_base_url() + "/api/media/" + object_id
	var payload = JSON.stringify({
		"token": _get_token(),
		"config": config
	})
	_update_request = _make_request()
	_update_request.request_completed.connect(_on_update_completed)
	_update_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, payload)

func _on_update_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_cleanup_request(_update_request)
	_update_request = null
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.has("media"):
		return
	var media = json["media"]
	var object_id = media.get("objectId", "")
	if object_id != "":
		media_objects[object_id] = media
		_render_single_media(object_id, media)

# --- Remove media ---

func remove_media(object_id: String) -> void:
	var url = _get_base_url() + "/api/media/" + object_id
	var payload = JSON.stringify({
		"token": _get_token()
	})
	_remove_request = _make_request()
	_remove_request.request_completed.connect(_on_remove_completed.bind(object_id))
	_remove_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_DELETE, payload)

func _on_remove_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, object_id: String) -> void:
	_cleanup_request(_remove_request)
	_remove_request = null
	if response_code != 200:
		return
	_clear_render_node(object_id)
	media_objects.erase(object_id)

# --- WebSocket event handling ---

func handle_ws_event(event: Dictionary) -> void:
	var event_type = event.get("type", "")
	match event_type:
		"media:created":
			var media = event.get("media", {})
			var object_id = media.get("objectId", "")
			if object_id != "":
				media_objects[object_id] = media
				_render_single_media(object_id, media)
		"media:updated":
			var media = event.get("media", {})
			var object_id = media.get("objectId", "")
			if object_id != "":
				media_objects[object_id] = media
				_render_single_media(object_id, media)
		"media:removed":
			var object_id = event.get("objectId", "")
			if object_id != "":
				_clear_render_node(object_id)
				media_objects.erase(object_id)

# --- Rendering ---

func _render_media_objects() -> void:
	for object_id in media_objects:
		_render_single_media(object_id, media_objects[object_id])

func _render_single_media(object_id: String, media: Dictionary) -> void:
	_clear_render_node(object_id)

	var media_type = media.get("mediaType", "")
	var config = media.get("config", {})

	# Find the parent 3D object in the scene by object_id
	var parent = _find_object_node(object_id)
	if parent == null:
		return

	var render_node = null

	match media_type:
		"photo_frame":
			render_node = _create_photo_frame(config)
		"video_screen":
			render_node = _create_video_screen(config)
		"billboard":
			render_node = _create_billboard(config)
		"slideshow":
			render_node = _create_slideshow(object_id, config)
		"projection":
			render_node = _create_projection(config)

	if render_node != null:
		render_node.name = "MediaAttachment"
		parent.add_child(render_node)
		media_objects[object_id]["_render_node_path"] = parent.get_path_to(render_node)

func _find_object_node(object_id: String) -> Node3D:
	# Search dynamic_world for the region object with matching id
	if not is_instance_valid(main):
		return null
	var dynamic_world = main.dynamic_world if main.get("dynamic_world") else null
	if dynamic_world == null:
		return null
	for child in dynamic_world.get_children():
		if child.has_meta("object_id") and child.get_meta("object_id") == object_id:
			return child
	return null

func _clear_render_node(object_id: String) -> void:
	# Stop any slideshow timer
	if _slideshow_timers.has(object_id):
		var timer = _slideshow_timers[object_id]
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
		_slideshow_timers.erase(object_id)

	var parent = _find_object_node(object_id)
	if parent == null:
		return
	var existing = parent.get_node_or_null("MediaAttachment")
	if existing != null:
		existing.queue_free()

# --- Media type renderers ---

func _create_photo_frame(config: Dictionary) -> Node3D:
	var root = Node3D.new()

	# Determine size
	var size_name = config.get("size", "medium")
	var quad_size = Vector2(1.0, 0.75)
	match size_name:
		"small":
			quad_size = Vector2(0.5, 0.375)
		"medium":
			quad_size = Vector2(1.0, 0.75)
		"large":
			quad_size = Vector2(2.0, 1.5)

	# Photo quad
	var mesh_instance = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = quad_size
	mesh_instance.mesh = quad
	mesh_instance.position = Vector3(0, quad_size.y / 2.0 + 0.1, 0)

	# Placeholder material with a color tint
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.8, 0.7)
	mat.metallic = 0.0
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	# Frame border (slightly larger quad behind)
	var frame_style = config.get("frameStyle", "wood")
	if frame_style != "none":
		var frame_mesh = MeshInstance3D.new()
		var frame_quad = QuadMesh.new()
		frame_quad.size = quad_size + Vector2(0.08, 0.08)
		frame_mesh.mesh = frame_quad
		frame_mesh.position = Vector3(0, quad_size.y / 2.0 + 0.1, -0.01)

		var frame_mat = StandardMaterial3D.new()
		match frame_style:
			"wood":
				frame_mat.albedo_color = Color(0.55, 0.35, 0.15)
			"metal":
				frame_mat.albedo_color = Color(0.7, 0.7, 0.72)
				frame_mat.metallic = 0.8
			"ornate":
				frame_mat.albedo_color = Color(0.8, 0.65, 0.2)
				frame_mat.metallic = 0.5
			"minimal":
				frame_mat.albedo_color = Color(0.2, 0.2, 0.2)
		frame_mesh.material_override = frame_mat
		root.add_child(frame_mesh)

	return root

func _create_video_screen(_config: Dictionary) -> Node3D:
	var root = Node3D.new()

	# Large flat quad as a screen placeholder
	var mesh_instance = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2.5, 1.5)
	mesh_instance.mesh = quad
	mesh_instance.position = Vector3(0, 1.0, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.1, 0.3)
	mat.emission_energy_multiplier = 0.5
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	# "VIDEO" label
	var label = Label3D.new()
	label.text = "VIDEO"
	label.font_size = 64
	label.position = Vector3(0, 1.0, 0.01)
	label.modulate = Color(0.4, 0.8, 1.0)
	root.add_child(label)

	return root

func _create_billboard(config: Dictionary) -> Node3D:
	var root = Node3D.new()

	# Background quad
	var bg_color_str = config.get("backgroundColor", "#333333")
	var text_color_str = config.get("textColor", "#ffffff")
	var font_size_val = config.get("fontSize", 32)
	var display_text = config.get("text", "")

	# Ensure font_size_val is an int
	if font_size_val is float:
		font_size_val = int(font_size_val)

	var bg_mesh = MeshInstance3D.new()
	var bg_quad = QuadMesh.new()
	bg_quad.size = Vector2(2.0, 1.0)
	bg_mesh.mesh = bg_quad
	bg_mesh.position = Vector3(0, 1.0, 0)

	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = Color.from_string(bg_color_str, Color(0.2, 0.2, 0.2))
	bg_mesh.material_override = bg_mat
	root.add_child(bg_mesh)

	# Text label
	var label = Label3D.new()
	label.text = display_text
	label.font_size = font_size_val
	label.position = Vector3(0, 1.0, 0.01)
	label.modulate = Color.from_string(text_color_str, Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = 180.0
	root.add_child(label)

	return root

func _create_slideshow(object_id: String, config: Dictionary) -> Node3D:
	var root = Node3D.new()

	# Display quad (placeholder)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "SlideQuad"
	var quad = QuadMesh.new()
	quad.size = Vector2(1.5, 1.0)
	mesh_instance.mesh = quad
	mesh_instance.position = Vector3(0, 0.75, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.75)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	# Slide index label
	var label = Label3D.new()
	label.name = "SlideLabel"
	label.font_size = 48
	label.position = Vector3(0, 0.75, 0.01)
	label.modulate = Color(0.3, 0.3, 0.3)
	root.add_child(label)

	var photo_ids = config.get("photoIds", [])
	var interval = config.get("intervalSeconds", 5.0)
	if interval is int:
		interval = float(interval)

	if photo_ids.size() > 0:
		label.text = "Slide 1/" + str(photo_ids.size())

		# Create a timer to cycle slides
		var timer = Timer.new()
		timer.wait_time = interval
		timer.autostart = true
		timer.one_shot = false
		timer.timeout.connect(_on_slideshow_tick.bind(object_id))
		main.add_child(timer)
		_slideshow_timers[object_id] = timer

	return root

func _on_slideshow_tick(object_id: String) -> void:
	if not media_objects.has(object_id):
		return
	var media = media_objects[object_id]
	var config = media.get("config", {})
	var photo_ids = config.get("photoIds", [])
	if photo_ids.size() == 0:
		return

	# Track current index in the media dict
	var current_index = media.get("_slide_index", 0)
	current_index = (current_index + 1) % photo_ids.size()
	media_objects[object_id]["_slide_index"] = current_index

	# Update the label
	var parent = _find_object_node(object_id)
	if parent == null:
		return
	var attachment = parent.get_node_or_null("MediaAttachment")
	if attachment == null:
		return
	var label = attachment.get_node_or_null("SlideLabel")
	if label != null:
		label.text = "Slide " + str(current_index + 1) + "/" + str(photo_ids.size())

	# Cycle placeholder color to simulate transition
	var slide_quad = attachment.get_node_or_null("SlideQuad")
	if slide_quad != null and slide_quad is MeshInstance3D:
		var mat = slide_quad.material_override as StandardMaterial3D
		if mat != null:
			var hue = float(current_index) / float(photo_ids.size())
			mat.albedo_color = Color.from_hsv(hue, 0.15, 0.9)

func _create_projection(_config: Dictionary) -> Node3D:
	var root = Node3D.new()

	# Simple projected-light style placeholder
	var mesh_instance = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(3.0, 2.0)
	mesh_instance.mesh = quad
	mesh_instance.position = Vector3(0, 1.5, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.9)
	mat.emission_energy_multiplier = 0.3
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	var label = Label3D.new()
	label.text = "PROJECTION"
	label.font_size = 48
	label.position = Vector3(0, 1.5, 0.01)
	label.modulate = Color(0.8, 0.8, 0.6)
	root.add_child(label)

	return root
