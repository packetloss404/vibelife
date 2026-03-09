extends Node3D

const MOVE_SPEED := 7.5
const CAMERA_DISTANCE := 12.0
const WS_SNAPSHOT := "snapshot"

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var ground: MeshInstance3D = $Ground
@onready var static_world: Node3D = $StaticWorld
@onready var dynamic_world: Node3D = $DynamicWorld
@onready var avatars_root: Node3D = $Avatars
@onready var regions_request: HTTPRequest = $Network/RegionsRequest
@onready var auth_request: HTTPRequest = $Network/AuthRequest
@onready var scene_request: HTTPRequest = $Network/SceneRequest
@onready var objects_request: HTTPRequest = $Network/ObjectsRequest
@onready var create_object_request: HTTPRequest = $Network/CreateObjectRequest
@onready var update_object_request: HTTPRequest = $Network/UpdateObjectRequest
@onready var delete_object_request: HTTPRequest = $Network/DeleteObjectRequest
@onready var backend_url_input: LineEdit = $CanvasLayer/UI/Sidebar/Margin/VBox/BackendUrlInput
@onready var display_name_input: LineEdit = $CanvasLayer/UI/Sidebar/Margin/VBox/DisplayNameInput
@onready var region_select: OptionButton = $CanvasLayer/UI/Sidebar/Margin/VBox/RegionSelect
@onready var refresh_regions_button: Button = $CanvasLayer/UI/Sidebar/Margin/VBox/RefreshRegionsButton
@onready var join_button: Button = $CanvasLayer/UI/Sidebar/Margin/VBox/JoinButton
@onready var status_label: Label = $CanvasLayer/UI/Sidebar/Margin/VBox/StatusLabel
@onready var inventory_list: ItemList = $CanvasLayer/UI/Sidebar/Margin/VBox/InventoryList
@onready var chat_log: RichTextLabel = $CanvasLayer/UI/Sidebar/Margin/VBox/ChatLog
@onready var chat_input: LineEdit = $CanvasLayer/UI/Sidebar/Margin/VBox/ChatInputRow/ChatInput
@onready var send_chat_button: Button = $CanvasLayer/UI/Sidebar/Margin/VBox/ChatInputRow/SendChatButton
@onready var build_mode_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/BuildModeButton
@onready var build_asset_select: OptionButton = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/BuildAssetSelect
@onready var selection_label: Label = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/SelectionLabel
@onready var duplicate_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/DuplicateButton
@onready var delete_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/DeleteButton

var websocket := WebSocketPeer.new()
var regions: Array = []
var session: Dictionary = {}
var avatar_states := {}
var avatar_nodes := {}
var object_nodes := {}
var inventory: Array = []
var yaw := 0.0
var pitch := 0.45
var orbiting := false
var model_scene_cache := {}
var build_mode := false
var selected_object_id := ""
var build_assets := [
	"/assets/models/market-hall.gltf",
	"/assets/models/skyport-tower.gltf",
	"/assets/models/garden-tree.gltf",
	"/assets/models/park-bench.gltf",
	"/assets/models/street-lantern.gltf",
	"/assets/models/dock-crate.gltf"
]

func _ready() -> void:
	_setup_ground()
	refresh_regions_button.pressed.connect(_fetch_regions)
	join_button.pressed.connect(_join_world)
	send_chat_button.pressed.connect(_send_chat)
	chat_input.text_submitted.connect(func(_text: String): _send_chat())
	build_mode_button.pressed.connect(_toggle_build_mode)
	duplicate_button.pressed.connect(_duplicate_selected_object)
	delete_button.pressed.connect(_delete_selected_object)
	regions_request.request_completed.connect(_on_regions_loaded)
	auth_request.request_completed.connect(_on_auth_completed)
	scene_request.request_completed.connect(_on_scene_loaded)
	objects_request.request_completed.connect(_on_objects_loaded)
	_fetch_regions()
	for asset in build_assets:
		build_asset_select.add_item(asset.get_file().trim_suffix(".gltf").replace("-", " "))


func _process(delta: float) -> void:
	_poll_websocket()
	_update_local_movement(delta)
	_update_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = button.pressed
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			camera.position.z = max(6.0, camera.position.z - 1.0)
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			camera.position.z = min(24.0, camera.position.z + 1.0)
	elif event is InputEventMouseMotion and orbiting:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * 0.005
		pitch = clamp(pitch - motion.relative.y * 0.004, 0.15, 1.1)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.pressed and build_mode:
		_handle_build_click(event.position)
	elif event is InputEventKey and event.pressed and build_mode:
		_handle_build_key(event)


func _setup_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.rotation_degrees.x = -90
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 0.2, 60)
	shape.shape = box
	body.add_child(shape)
	ground.add_child(body)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("24586a")
	material.roughness = 0.95
	ground.material_override = material


func _fetch_regions() -> void:
	status_label.text = "Fetching regions..."
	region_select.clear()
	var url := "%s/api/regions" % backend_url_input.text.rstrip("/")
	var error := regions_request.request(url)
	if error != OK:
		status_label.text = "Region request failed: %s" % error


func _on_regions_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "Region request returned %s" % response_code
		return

	var payload := JSON.parse_string(body.get_string_from_utf8())
	regions = payload.get("regions", [])
	region_select.clear()
	for region in regions:
		region_select.add_item("%s - %s/%s" % [region.name, region.population, region.capacity])
	status_label.text = "Ready to join."


func _join_world() -> void:
	if regions.is_empty():
		status_label.text = "No regions available yet."
		return

	var chosen_region: Dictionary = regions[region_select.selected]
	var body := JSON.stringify({
		"displayName": display_name_input.text,
		"regionId": chosen_region.id
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := "%s/api/auth/guest" % backend_url_input.text.rstrip("/")
	var error := auth_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		status_label.text = "Auth request failed: %s" % error


func _on_auth_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "Join request returned %s" % response_code
		return

	var payload := JSON.parse_string(body.get_string_from_utf8())
	session = payload.get("session", {})
	avatar_states.clear()
	avatar_states[payload.avatar.avatarId] = payload.avatar
	status_label.text = "Connected as %s" % session.displayName
	inventory = payload.get("inventory", [])
	_render_inventory()
	_append_chat("System: joined %s" % session.regionId)
	await _load_region_scene(session.regionId)
	await _load_region_objects(session.regionId)
	_sync_avatars()
	_connect_websocket()


func _load_region_scene(region_id: String) -> void:
	for child in static_world.get_children():
		child.queue_free()
	var url := "%s/scenes/%s.json" % [backend_url_input.text.rstrip("/"), region_id]
	var error := scene_request.request(url)
	if error != OK:
		status_label.text = "Scene request failed: %s" % error
		return
	await scene_request.request_completed


func _on_scene_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "Scene request returned %s" % response_code
		return

	var payload := JSON.parse_string(body.get_string_from_utf8())
	for item in payload.get("assets", []):
		static_world.add_child(_make_world_prop(item.asset, Vector3(item.position[0], item.position[1], item.position[2]), item.rotation[1] if item.has("rotation") else 0.0, item.scale[0] if item.has("scale") else 1.0))


func _load_region_objects(region_id: String) -> void:
	var url := "%s/api/regions/%s/objects" % [backend_url_input.text.rstrip("/"), region_id]
	var error := objects_request.request(url)
	if error != OK:
		status_label.text = "Objects request failed: %s" % error
		return
	await objects_request.request_completed


func _on_objects_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "Objects request returned %s" % response_code
		return

	var payload := JSON.parse_string(body.get_string_from_utf8())
	for child in dynamic_world.get_children():
		child.queue_free()
	object_nodes.clear()
	for item in payload.get("objects", []):
		var node := _make_world_prop(item.asset, Vector3(item.x, item.y, item.z), item.rotationY, item.scale)
		dynamic_world.add_child(node)
		object_nodes[item.id] = node


func _connect_websocket() -> void:
	websocket = WebSocketPeer.new()
	var base := backend_url_input.text.rstrip("/")
	var ws_url := base.replace("http://", "ws://").replace("https://", "wss://")
	ws_url += "/ws/regions/%s?token=%s" % [session.regionId, session.token]
	var error := websocket.connect_to_url(ws_url)
	if error != OK:
		status_label.text = "WebSocket failed: %s" % error


func _poll_websocket() -> void:
	if websocket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		return

	websocket.poll()
	while websocket.get_available_packet_count() > 0:
		var payload := JSON.parse_string(websocket.get_packet().get_string_from_utf8())
		_handle_socket_message(payload)


func _handle_socket_message(message: Dictionary) -> void:
	match message.get("type", ""):
		WS_SNAPSHOT:
			avatar_states.clear()
			for avatar in message.get("avatars", []):
				avatar_states[avatar.avatarId] = avatar
			_sync_avatars()
			_sync_objects(message.get("objects", []))
		"avatar:joined", "avatar:moved", "avatar:updated":
			var avatar := message.avatar
			avatar_states[avatar.avatarId] = avatar
			_sync_avatars()
		"avatar:left":
			avatar_states.erase(message.avatarId)
			_sync_avatars()
		"chat":
			_append_chat("%s: %s" % [message.displayName, message.message])
		"object:created", "object:updated":
			_sync_single_object(message.object)
		"object:deleted":
			if object_nodes.has(message.objectId):
				object_nodes[message.objectId].queue_free()
				object_nodes.erase(message.objectId)


func _sync_avatars() -> void:
	for avatar_id in avatar_nodes.keys():
		if not avatar_states.has(avatar_id):
			avatar_nodes[avatar_id].queue_free()
			avatar_nodes.erase(avatar_id)

	for avatar_id in avatar_states.keys():
		var state: Dictionary = avatar_states[avatar_id]
		if not avatar_nodes.has(avatar_id):
			var avatar_node := _make_avatar_node(state)
			avatars_root.add_child(avatar_node)
			avatar_nodes[avatar_id] = avatar_node
		_update_avatar_node(avatar_nodes[avatar_id], state)


func _sync_objects(items: Array) -> void:
	for child in dynamic_world.get_children():
		child.queue_free()
	object_nodes.clear()
	for item in items:
		_sync_single_object(item)


func _sync_single_object(item: Dictionary) -> void:
	if object_nodes.has(item.id):
		object_nodes[item.id].queue_free()
	var node := _make_world_prop(item.asset, Vector3(item.x, item.y, item.z), item.rotationY, item.scale)
	node.set_meta("object_id", item.id)
	dynamic_world.add_child(node)
	object_nodes[item.id] = node


func _make_avatar_node(state: Dictionary) -> Node3D:
	var imported := _instantiate_imported_asset("/assets/models/avatar-runner.gltf")
	if imported:
		var label := Label3D.new()
		label.text = state.displayName
		label.position.y = 3.4
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		imported.add_child(label)
		return imported

	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.45
	body_mesh.height = 1.4
	body.mesh = body_mesh
	body.position.y = 1.6
	root.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.32
	head.mesh = head_mesh
	head.position.y = 2.75
	root.add_child(head)

	var label := Label3D.new()
	label.text = state.displayName
	label.position.y = 3.4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	return root


func _update_avatar_node(node: Node3D, state: Dictionary) -> void:
	node.position = Vector3(state.x, state.y, state.z)
	var appearance: Dictionary = state.get("appearance", {})
	var body := node.get_child(0) as MeshInstance3D
	var head := node.get_child(1) as MeshInstance3D
	var label := node.get_child(2) as Label3D
	label.text = state.displayName
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(appearance.get("bodyColor", "#8cd8ff"))
	body.set_surface_override_material(0, body_material)
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(appearance.get("headColor", "#f2c7a8"))
	head.set_surface_override_material(0, head_material)


func _make_world_prop(asset: String, position: Vector3, rotation_y: float, scale_value: float) -> Node3D:
	var imported := _instantiate_imported_asset(asset)
	if imported:
		imported.position = position
		imported.rotation.y = rotation_y
		imported.scale = Vector3.ONE * scale_value
		return imported

	var root := Node3D.new()
	root.position = position
	root.rotation.y = rotation_y
	root.scale = Vector3.ONE * scale_value

	var mesh_instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.roughness = 0.85

	if asset.contains("tower"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.5, 8.0, 3.5)
		mesh_instance.mesh = mesh
		material.albedo_color = Color("c7d3d9")
		mesh_instance.position.y = 4.0
	elif asset.contains("hall"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(7.0, 4.0, 5.0)
		mesh_instance.mesh = mesh
		material.albedo_color = Color("d6d2c8")
		mesh_instance.position.y = 2.0
	elif asset.contains("tree"):
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.18
		trunk_mesh.bottom_radius = 0.24
		trunk_mesh.height = 2.8
		trunk.mesh = trunk_mesh
		trunk.position.y = 1.4
		var trunk_material := StandardMaterial3D.new()
		trunk_material.albedo_color = Color("5b4634")
		trunk.set_surface_override_material(0, trunk_material)
		root.add_child(trunk)
		var canopy := MeshInstance3D.new()
		var canopy_mesh := SphereMesh.new()
		canopy_mesh.radius = 1.1
		canopy.mesh = canopy_mesh
		canopy.position.y = 3.2
		var canopy_material := StandardMaterial3D.new()
		canopy_material.albedo_color = Color("79ca92")
		canopy.set_surface_override_material(0, canopy_material)
		root.add_child(canopy)
		return root
	elif asset.contains("bench"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.8, 0.5, 0.6)
		mesh_instance.mesh = mesh
		material.albedo_color = Color("a7724f")
		mesh_instance.position.y = 0.4
	elif asset.contains("lantern"):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.12
		mesh.bottom_radius = 0.12
		mesh.height = 2.2
		mesh_instance.mesh = mesh
		material.albedo_color = Color("7ea4b3")
		mesh_instance.position.y = 1.1
		var omni := OmniLight3D.new()
		omni.position.y = 2.3
		omni.light_color = Color("8cecff")
		omni.light_energy = 1.5
		root.add_child(omni)
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh_instance.mesh = mesh
		material.albedo_color = Color("7f6147")
		mesh_instance.position.y = 0.5

	mesh_instance.set_surface_override_material(0, material)
	root.add_child(mesh_instance)
	return root


func _instantiate_imported_asset(asset: String) -> Node3D:
	var file_name := asset.get_file()
	var resource_path := "res://assets/models/%s" % file_name
	if not ResourceLoader.exists(resource_path):
		return null

	var packed = model_scene_cache.get(resource_path)
	if packed == null:
		packed = load(resource_path)
		model_scene_cache[resource_path] = packed

	if packed is PackedScene:
		return (packed as PackedScene).instantiate()

	return null


func _render_inventory() -> void:
	inventory_list.clear()
	for item in inventory:
		var equipped := ""
		if item.get("equipped", false):
			equipped = " [equipped]"
		inventory_list.add_item("%s%s" % [item.name, equipped])


func _append_chat(message: String) -> void:
	chat_log.append_text(message + "\n")


func _send_chat() -> void:
	var message := chat_input.text.strip_edges()
	if message.is_empty():
		return
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		status_label.text = "Chat unavailable until region WebSocket connects."
		return
	websocket.send_text(JSON.stringify({
		"type": "chat",
		"message": message
	}))
	chat_input.clear()


func _toggle_build_mode() -> void:
	build_mode = not build_mode
	build_mode_button.text = "Disable build mode" if build_mode else "Enable build mode"
	status_label.text = "Build mode enabled" if build_mode else "Build mode disabled"


func _handle_build_click(mouse_position: Vector2) -> void:
	if session.is_empty():
		return

	var from := camera.project_ray_origin(mouse_position)
	var to := from + camera.project_ray_normal(mouse_position) * 500.0
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space_state.intersect_ray(query)

	if not hit.is_empty() and hit.collider is Node and (hit.collider as Node).has_meta("object_id"):
		selected_object_id = str((hit.collider as Node).get_meta("object_id"))
		selection_label.text = "Selected: %s" % selected_object_id
		return

	var ground_plane := Plane(Vector3.UP, 0.0)
	var world_point := ground_plane.intersects_ray(from, camera.project_ray_normal(mouse_position))
	if world_point == null:
		return

	await _create_object(Vector3(world_point.x, 0.0, world_point.z))


func _handle_build_key(event: InputEventKey) -> void:
	if selected_object_id.is_empty() or not object_nodes.has(selected_object_id):
		return

	var node := object_nodes[selected_object_id]
	var moved := false
	if event.physical_keycode == KEY_UP:
		node.position.z -= 1.0
		moved = true
	if event.physical_keycode == KEY_DOWN:
		node.position.z += 1.0
		moved = true
	if event.physical_keycode == KEY_LEFT:
		node.position.x -= 1.0
		moved = true
	if event.physical_keycode == KEY_RIGHT:
		node.position.x += 1.0
		moved = true
	if event.physical_keycode == KEY_Q:
		node.rotation.y -= 0.2
		moved = true
	if event.physical_keycode == KEY_E:
		node.rotation.y += 0.2
		moved = true
	if event.physical_keycode == KEY_R:
		node.scale *= 1.1
		moved = true
	if event.physical_keycode == KEY_F:
		node.scale *= 0.9
		moved = true
	if event.physical_keycode == KEY_DELETE:
		await _delete_selected_object()
		return

	if moved:
		await _update_selected_object(node)


func _create_object(position: Vector3) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({
		"token": session.token,
		"asset": build_assets[build_asset_select.selected],
		"x": position.x,
		"y": position.y,
		"z": position.z,
		"rotationY": 0.0,
		"scale": 1.0
	})
	var url := "%s/api/regions/%s/objects" % [backend_url_input.text.rstrip("/"), session.regionId]
	if create_object_request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		await create_object_request.request_completed


func _update_selected_object(node: Node3D) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({
		"token": session.token,
		"x": node.position.x,
		"y": node.position.y,
		"z": node.position.z,
		"rotationY": node.rotation.y,
		"scale": node.scale.x
	})
	var url := "%s/api/objects/%s" % [backend_url_input.text.rstrip("/"), selected_object_id]
	if update_object_request.request(url, headers, HTTPClient.METHOD_PATCH, body) == OK:
		await update_object_request.request_completed


func _delete_selected_object() -> void:
	if selected_object_id.is_empty():
		return
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"token": session.token})
	var url := "%s/api/objects/%s" % [backend_url_input.text.rstrip("/"), selected_object_id]
	if delete_object_request.request(url, headers, HTTPClient.METHOD_DELETE, body) == OK:
		await delete_object_request.request_completed
	selected_object_id = ""
	selection_label.text = "No object selected"


func _duplicate_selected_object() -> void:
	if selected_object_id.is_empty() or not object_nodes.has(selected_object_id):
		return
	var node := object_nodes[selected_object_id]
	await _create_object(node.position + Vector3(1.0, 0.0, 1.0))


func _update_local_movement(delta: float) -> void:
	if session.is_empty() or not avatar_states.has(session.avatarId):
		return

	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if input_vector.length() == 0:
		return

	input_vector = input_vector.normalized()
	var move := Vector3(input_vector.x, 0, input_vector.y) * MOVE_SPEED * delta
	var avatar: Dictionary = avatar_states[session.avatarId]
	avatar.x = clampf(float(avatar.x) + move.x, -28.0, 28.0)
	avatar.z = clampf(float(avatar.z) + move.z, -28.0, 28.0)
	avatar_states[session.avatarId] = avatar
	_sync_avatars()
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		websocket.send_text(JSON.stringify({
			"type": "move",
			"x": avatar.x,
			"y": avatar.y,
			"z": avatar.z
		}))


func _update_camera(delta: float) -> void:
	if session.is_empty() or not avatar_nodes.has(session.avatarId):
		return

	var target := avatar_nodes[session.avatarId].position + Vector3(0, 2.5, 0)
	var desired := target + Vector3(
		sin(yaw) * cos(pitch) * CAMERA_DISTANCE,
		sin(pitch) * CAMERA_DISTANCE + 2.0,
		cos(yaw) * cos(pitch) * CAMERA_DISTANCE
	)
	camera_rig.position = camera_rig.position.lerp(desired, minf(1.0, delta * 6.0))
	camera.look_at(target)
