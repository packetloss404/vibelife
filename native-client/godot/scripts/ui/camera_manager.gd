class_name CameraManager extends RefCounted

## Photography & Camera module for VibeLife.
## Provides first-person camera mode with filters, screenshot capture,
## and gallery viewing. Integrates with the backend photo service.

var main  # untyped reference to main node

var is_camera_mode = false
var current_filter = "none"
var available_filters = [
	"none", "vintage", "noir", "warm", "cool", "dreamy", "pixel", "posterize"
]
var _filter_index = 0

# UI overlay nodes (created dynamically)
var _viewfinder_overlay = null
var _filter_label = null
var _capture_label = null
var _color_rect = null

# Camera state
var _saved_camera_transform = Transform3D.IDENTITY
var _saved_camera_rig_transform = Transform3D.IDENTITY
var _camera_yaw = 0.0
var _camera_pitch = 0.0
var _zoom_level = 0.0
var _mouse_sensitivity = 0.003
var _move_speed = 5.0

# Gallery state
var _gallery_request = null


func init(main_node) -> void:
	main = main_node


func enter_camera_mode() -> void:
	if is_camera_mode:
		return
	is_camera_mode = true

	# Save current camera state
	if main.camera_rig:
		_saved_camera_rig_transform = main.camera_rig.global_transform
	if main.camera:
		_saved_camera_transform = main.camera.transform
		# Move camera to first-person position
		var cam_basis = main.camera.global_transform.basis
		_camera_yaw = cam_basis.get_euler().y
		_camera_pitch = cam_basis.get_euler().x

	_zoom_level = 0.0

	# Capture mouse for look controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Create viewfinder overlay
	_create_viewfinder_overlay()

	# Apply current filter
	_apply_filter(current_filter)


func exit_camera_mode() -> void:
	if not is_camera_mode:
		return
	is_camera_mode = false

	# Restore camera
	if main.camera_rig:
		main.camera_rig.global_transform = _saved_camera_rig_transform
	if main.camera:
		main.camera.transform = _saved_camera_transform

	# Release mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Remove overlay
	_remove_viewfinder_overlay()

	# Remove filter
	_clear_filter()


func set_filter(filter_name) -> void:
	if filter_name in available_filters:
		current_filter = filter_name
		_filter_index = available_filters.find(filter_name)
		_apply_filter(filter_name)
		if _filter_label:
			_filter_label.text = "Filter: " + str(filter_name).to_upper()


func cycle_filter() -> void:
	_filter_index = (_filter_index + 1) % available_filters.size()
	set_filter(available_filters[_filter_index])


func take_screenshot() -> void:
	if not is_camera_mode:
		return

	# Temporarily hide overlay for clean capture
	if _viewfinder_overlay:
		_viewfinder_overlay.visible = false

	# Wait one frame for overlay to disappear
	await main.get_tree().process_frame

	# Capture viewport
	var viewport = main.get_viewport()
	var image = viewport.get_texture().get_image()

	# Restore overlay
	if _viewfinder_overlay:
		_viewfinder_overlay.visible = true

	# Resize to thumbnail (max 320x240 to stay under 50KB)
	var thumb_width = 320
	var thumb_height = 240
	if image.get_width() > 0 and image.get_height() > 0:
		var aspect = float(image.get_width()) / float(image.get_height())
		if aspect > (float(thumb_width) / float(thumb_height)):
			thumb_height = int(thumb_width / aspect)
		else:
			thumb_width = int(thumb_height * aspect)
	image.resize(thumb_width, thumb_height, Image.INTERPOLATE_BILINEAR)

	# Convert to PNG then base64
	var png_data = image.save_png_to_buffer()
	var base64_data = Marshalls.raw_to_base64(png_data)

	# Upload to server
	_upload_photo(base64_data)


func show_gallery() -> void:
	## Load and display the player's gallery via the backend.
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")

	if token.is_empty():
		return

	var session = main.session
	var account_id = session.get("accountId", "")
	if account_id.is_empty():
		return

	var url = base_url + "/api/photos/gallery/" + str(account_id) + "?limit=20"

	if _gallery_request == null:
		_gallery_request = HTTPRequest.new()
		main.add_child(_gallery_request)
		_gallery_request.request_completed.connect(_on_gallery_response)

	_gallery_request.request(url, [], HTTPClient.METHOD_GET)


func handle_input(event) -> void:
	## Call this from main's _unhandled_input when camera mode is active.
	if not is_camera_mode:
		return

	if event is InputEventMouseMotion:
		_camera_yaw -= event.relative.x * _mouse_sensitivity
		_camera_pitch -= event.relative.y * _mouse_sensitivity
		_camera_pitch = clampf(_camera_pitch, -1.4, 1.4)
		_update_camera_orientation()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_level = clampf(_zoom_level - 0.5, -5.0, 5.0)
			_update_camera_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_level = clampf(_zoom_level + 0.5, -5.0, 5.0)
			_update_camera_zoom()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F:
				take_screenshot()
			KEY_TAB:
				cycle_filter()
			KEY_ESCAPE:
				exit_camera_mode()


func handle_process(delta) -> void:
	## Call this from main's _process when camera mode is active.
	if not is_camera_mode:
		return

	var direction = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direction.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.z += 1.0
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0

	if direction.length() > 0.0:
		direction = direction.normalized()
		# Rotate direction by camera yaw
		var basis = Basis(Vector3.UP, _camera_yaw)
		direction = basis * direction
		if main.camera_rig:
			main.camera_rig.global_position += direction * _move_speed * delta


# --- Private helpers ---

func _update_camera_orientation() -> void:
	if not main.camera_rig:
		return
	main.camera_rig.rotation.y = _camera_yaw
	if main.camera:
		main.camera.rotation.x = _camera_pitch


func _update_camera_zoom() -> void:
	if not main.camera:
		return
	# Adjust camera Z position for zoom
	var pos = main.camera.position
	pos.z = 0.0 + _zoom_level
	main.camera.position = pos


func _create_viewfinder_overlay() -> void:
	if _viewfinder_overlay:
		return

	var canvas_layer = main.get_node_or_null("CanvasLayer")
	if not canvas_layer:
		return

	_viewfinder_overlay = Control.new()
	_viewfinder_overlay.name = "ViewfinderOverlay"
	_viewfinder_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewfinder_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(_viewfinder_overlay)

	# Semi-transparent border frame
	# Top bar
	var top_bar = ColorRect.new()
	top_bar.color = Color(0, 0, 0, 0.5)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 40)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewfinder_overlay.add_child(top_bar)

	# Bottom bar
	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0, 0, 0, 0.5)
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.custom_minimum_size = Vector2(0, 60)
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -60
	bottom_bar.offset_bottom = 0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewfinder_overlay.add_child(bottom_bar)

	# Crosshair / center reticle
	var center_dot = ColorRect.new()
	center_dot.color = Color(1, 1, 1, 0.6)
	center_dot.custom_minimum_size = Vector2(8, 8)
	center_dot.set_anchors_preset(Control.PRESET_CENTER)
	center_dot.position = Vector2(-4, -4)
	center_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewfinder_overlay.add_child(center_dot)

	# Corner brackets (top-left)
	var tl = _make_corner_bracket()
	tl.position = Vector2(60, 50)
	_viewfinder_overlay.add_child(tl)

	# Corner brackets (top-right)
	var top_right = _make_corner_bracket()
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.position = Vector2(-90, 50)
	_viewfinder_overlay.add_child(top_right)

	# Corner brackets (bottom-left)
	var bl = _make_corner_bracket()
	bl.anchor_top = 1.0
	bl.anchor_bottom = 1.0
	bl.position = Vector2(60, -90)
	_viewfinder_overlay.add_child(bl)

	# Corner brackets (bottom-right)
	var br = _make_corner_bracket()
	br.anchor_left = 1.0
	br.anchor_right = 1.0
	br.anchor_top = 1.0
	br.anchor_bottom = 1.0
	br.position = Vector2(-90, -90)
	_viewfinder_overlay.add_child(br)

	# Filter name label (top-right area)
	_filter_label = Label.new()
	_filter_label.text = "Filter: " + str(current_filter).to_upper()
	_filter_label.add_theme_font_size_override("font_size", 16)
	_filter_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_filter_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_filter_label.position = Vector2(-200, 10)
	_filter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewfinder_overlay.add_child(_filter_label)

	# Capture hint label (bottom center)
	_capture_label = Label.new()
	_capture_label.text = "F - Capture  |  Tab - Filter  |  Esc - Exit"
	_capture_label.add_theme_font_size_override("font_size", 14)
	_capture_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_capture_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capture_label.anchor_top = 1.0
	_capture_label.anchor_bottom = 1.0
	_capture_label.offset_top = -35
	_capture_label.offset_bottom = -10
	_capture_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewfinder_overlay.add_child(_capture_label)

	# Color rect for filter effects (full screen behind UI)
	_color_rect = ColorRect.new()
	_color_rect.name = "FilterColorRect"
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.color = Color(0, 0, 0, 0)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Insert at index 0 so it's behind other overlay children
	_viewfinder_overlay.add_child(_color_rect)
	_viewfinder_overlay.move_child(_color_rect, 0)


func _make_corner_bracket() -> Control:
	var bracket = Control.new()
	bracket.custom_minimum_size = Vector2(30, 30)
	bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var h_line = ColorRect.new()
	h_line.color = Color(1, 1, 1, 0.7)
	h_line.custom_minimum_size = Vector2(30, 2)
	h_line.position = Vector2(0, 0)
	h_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bracket.add_child(h_line)

	var v_line = ColorRect.new()
	v_line.color = Color(1, 1, 1, 0.7)
	v_line.custom_minimum_size = Vector2(2, 30)
	v_line.position = Vector2(0, 0)
	v_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bracket.add_child(v_line)

	return bracket


func _remove_viewfinder_overlay() -> void:
	if _viewfinder_overlay:
		_viewfinder_overlay.queue_free()
		_viewfinder_overlay = null
		_filter_label = null
		_capture_label = null
		_color_rect = null


func _apply_filter(filter_name) -> void:
	if not _color_rect:
		return

	# Use color modulation to simulate filters
	match filter_name:
		"none":
			_color_rect.color = Color(0, 0, 0, 0)
		"vintage":
			_color_rect.color = Color(0.6, 0.4, 0.2, 0.15)
		"noir":
			_color_rect.color = Color(0.0, 0.0, 0.0, 0.3)
		"warm":
			_color_rect.color = Color(0.8, 0.4, 0.1, 0.1)
		"cool":
			_color_rect.color = Color(0.1, 0.3, 0.8, 0.1)
		"dreamy":
			_color_rect.color = Color(0.8, 0.6, 0.9, 0.12)
		"pixel":
			_color_rect.color = Color(0.0, 0.5, 0.0, 0.08)
		"posterize":
			_color_rect.color = Color(0.5, 0.0, 0.5, 0.1)
		_:
			_color_rect.color = Color(0, 0, 0, 0)


func _clear_filter() -> void:
	if _color_rect:
		_color_rect.color = Color(0, 0, 0, 0)


func _upload_photo(base64_data) -> void:
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")
	var region_id = main.session.get("regionId", "")

	if token.is_empty():
		return

	var url = base_url + "/api/photos"

	var body = {
		"token": token,
		"regionId": region_id,
		"title": "Photo from " + main.session.get("displayName", "Unknown"),
		"thumbnailData": base64_data,
		"filter": current_filter,
		"position": {
			"x": 0.0,
			"y": 0.0,
			"z": 0.0
		},
		"cameraRotation": {
			"x": _camera_pitch,
			"y": _camera_yaw
		}
	}

	# Get avatar position if available
	if main.camera_rig:
		var pos = main.camera_rig.global_position
		body["position"] = {
			"x": pos.x,
			"y": pos.y,
			"z": pos.z
		}

	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]

	var upload_request = HTTPRequest.new()
	main.add_child(upload_request)
	upload_request.request_completed.connect(_on_upload_response.bind(upload_request))
	upload_request.request(url, headers, HTTPClient.METHOD_POST, json_body)


func _on_upload_response(_result, response_code, _headers, _body, request_node) -> void:
	if request_node:
		request_node.queue_free()

	if response_code == 200:
		# Show success feedback
		if _capture_label:
			_capture_label.text = "Photo saved!"
			# Reset after 2 seconds
			await main.get_tree().create_timer(2.0).timeout
			if _capture_label:
				_capture_label.text = "F - Capture  |  Tab - Filter  |  Esc - Exit"
	else:
		if _capture_label:
			_capture_label.text = "Failed to save photo"
			await main.get_tree().create_timer(2.0).timeout
			if _capture_label:
				_capture_label.text = "F - Capture  |  Tab - Filter  |  Esc - Exit"


func _on_gallery_response(_result, response_code, _headers, body) -> void:
	if response_code != 200:
		return

	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		return

	var data = json.get_data()
	if not data.has("photos"):
		return

	var photos = data["photos"]
	var count = photos.size()

	# Display gallery info in chat as a summary
	# (The main node would need to expose a chat display method;
	#  for now we print to console as a fallback)
	print("[Gallery] You have ", count, " photos")
	for i in range(mini(count, 5)):
		var photo = photos[i]
		var title = photo.get("title", "Untitled")
		var likes = 0
		if photo.has("likes"):
			likes = photo["likes"].size()
		print("  - ", title, " (", likes, " likes)")
