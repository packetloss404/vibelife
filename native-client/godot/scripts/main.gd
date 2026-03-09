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
@onready var gizmos_root: Node3D = $Gizmos
@onready var parcels_root: Node3D = $Parcels
@onready var regions_request: HTTPRequest = $Network/RegionsRequest
@onready var auth_request: HTTPRequest = $Network/AuthRequest
@onready var scene_request: HTTPRequest = $Network/SceneRequest
@onready var objects_request: HTTPRequest = $Network/ObjectsRequest
@onready var create_object_request: HTTPRequest = $Network/CreateObjectRequest
@onready var update_object_request: HTTPRequest = $Network/UpdateObjectRequest
@onready var delete_object_request: HTTPRequest = $Network/DeleteObjectRequest
@onready var backend_url_input: LineEdit = $CanvasLayer/UI/Sidebar/Margin/VBox/BackendUrlInput
@onready var profile_select: OptionButton = $CanvasLayer/UI/Sidebar/Margin/VBox/ProfileSelect
@onready var save_profile_button: Button = $CanvasLayer/UI/Sidebar/Margin/VBox/SaveProfileButton
@onready var display_name_input: LineEdit = $CanvasLayer/UI/Sidebar/Margin/VBox/DisplayNameInput
@onready var region_select: OptionButton = $CanvasLayer/UI/Sidebar/Margin/VBox/RegionSelect
@onready var refresh_regions_button: Button = $CanvasLayer/UI/Sidebar/Margin/VBox/RefreshRegionsButton
@onready var join_button: Button = $CanvasLayer/UI/Sidebar/Margin/VBox/JoinButton
@onready var status_label: Label = $CanvasLayer/UI/Sidebar/Margin/VBox/StatusLabel
@onready var status_pill: Label = $CanvasLayer/UI/TopBar/TopMargin/TopRow/StatusPill
@onready var inventory_list: ItemList = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/InventoryList
@onready var inventory_selection_label: Label = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/InventorySelectionLabel
@onready var equip_item_button: Button = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/InventoryActionRow/EquipItemButton
@onready var use_item_button: Button = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/InventoryActionRow/UseItemButton
@onready var chat_log: RichTextLabel = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/ChatLog
@onready var chat_input: LineEdit = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/ChatInputRow/ChatInput
@onready var send_chat_button: Button = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/ChatInputRow/SendChatButton
@onready var build_mode_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/BuildModeButton
@onready var build_asset_select: OptionButton = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/BuildAssetSelect
@onready var move_mode_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/GizmoModeRow/MoveModeButton
@onready var rotate_mode_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/GizmoModeRow/RotateModeButton
@onready var scale_mode_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/GizmoModeRow/ScaleModeButton
@onready var selection_label: Label = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/SelectionLabel
@onready var parcel_label: Label = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/ParcelLabel
@onready var duplicate_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/DuplicateButton
@onready var delete_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/DeleteButton

var websocket := WebSocketPeer.new()
var regions: Array = []
var session: Dictionary = {}
var parcels: Array = []
var avatar_states := {}
var avatar_nodes := {}
var avatar_previous_positions := {}
var object_nodes := {}
var inventory: Array = []
var yaw := 0.0
var pitch := 0.45
var orbiting := false
var model_scene_cache := {}
var build_mode := false
var selected_object_id := ""
var gizmo_mode := "move"
var drag_selected := false
var active_parcel: Dictionary = {}
var gizmo_handles := {}
var active_drag_axis := ""
var selected_inventory_index := -1
var backend_profiles: Array = []
var parcel_nodes := {}
const PROFILE_SAVE_PATH := "user://backend_profiles.json"
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
	profile_select.item_selected.connect(_on_profile_selected)
	save_profile_button.pressed.connect(_save_current_profile)
	join_button.pressed.connect(_join_world)
	send_chat_button.pressed.connect(_send_chat)
	chat_input.text_submitted.connect(func(_text: String): _send_chat())
	build_mode_button.pressed.connect(_toggle_build_mode)
	move_mode_button.pressed.connect(func(): _set_gizmo_mode("move"))
	rotate_mode_button.pressed.connect(func(): _set_gizmo_mode("rotate"))
	scale_mode_button.pressed.connect(func(): _set_gizmo_mode("scale"))
	duplicate_button.pressed.connect(_duplicate_selected_object)
	delete_button.pressed.connect(_delete_selected_object)
	inventory_list.item_selected.connect(_on_inventory_item_selected)
	equip_item_button.pressed.connect(_equip_selected_inventory_item)
	use_item_button.pressed.connect(_use_selected_inventory_item)
	regions_request.request_completed.connect(_on_regions_loaded)
	auth_request.request_completed.connect(_on_auth_completed)
	scene_request.request_completed.connect(_on_scene_loaded)
	objects_request.request_completed.connect(_on_objects_loaded)
	_fetch_regions()
	_load_profiles()
	for asset in build_assets:
		build_asset_select.add_item(asset.get_file().trim_suffix(".gltf").replace("-", " "))
	_set_gizmo_mode("move")


func _process(delta: float) -> void:
	_poll_websocket()
	_update_local_movement(delta)
	_update_camera(delta)
	_update_gizmo_handles()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if build_mode and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed and drag_selected:
			drag_selected = false
			active_drag_axis = ""
			if not selected_object_id.is_empty() and object_nodes.has(selected_object_id):
				await _update_selected_object(object_nodes[selected_object_id])
		if button.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = button.pressed
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			if build_mode and not selected_object_id.is_empty() and object_nodes.has(selected_object_id):
				_apply_gizmo_wheel(1.0)
			else:
				camera.position.z = max(6.0, camera.position.z - 1.0)
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			if build_mode and not selected_object_id.is_empty() and object_nodes.has(selected_object_id):
				_apply_gizmo_wheel(-1.0)
			else:
				camera.position.z = min(24.0, camera.position.z + 1.0)
	elif event is InputEventMouseMotion and orbiting:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * 0.005
		pitch = clamp(pitch - motion.relative.y * 0.004, 0.15, 1.1)
	elif event is InputEventMouseMotion and build_mode and drag_selected and not selected_object_id.is_empty() and object_nodes.has(selected_object_id):
		_drag_selected_object(event)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.pressed and build_mode:
		await _handle_build_click(event.position)
	elif event is InputEventKey and event.pressed and build_mode:
		await _handle_build_key(event)


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
	status_pill.text = "Loading regions"
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
	status_pill.text = "Ready"
	_save_login_state()
	_apply_client_settings()


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
	status_pill.text = "Connected"
	_save_login_state()
	_apply_client_settings()
	inventory = payload.get("inventory", [])
	parcels = payload.get("parcels", [])
	_render_inventory()
	_render_parcels()
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
	_update_selection_state()


func _connect_websocket() -> void:
	websocket = WebSocketPeer.new()
	var base := backend_url_input.text.rstrip("/")
	var ws_url := base.replace("http://", "ws://").replace("https://", "wss://")
	ws_url += "/ws/regions/%s?token=%s" % [session.regionId, session.token]
	var error := websocket.connect_to_url(ws_url)
	if error != OK:
		status_label.text = "WebSocket failed: %s" % error
		status_pill.text = "Socket failed"


func _poll_websocket() -> void:
	if websocket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		if not session.is_empty():
			status_pill.text = "Disconnected"
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
			avatar_previous_positions.erase(avatar_id)

	for avatar_id in avatar_states.keys():
		var state: Dictionary = avatar_states[avatar_id]
		if not avatar_nodes.has(avatar_id):
			var avatar_node := _make_avatar_node(state)
			avatars_root.add_child(avatar_node)
			avatar_nodes[avatar_id] = avatar_node
			avatar_previous_positions[avatar_id] = avatar_node.position
		_update_avatar_node(avatar_nodes[avatar_id], state)


func _sync_objects(items: Array) -> void:
	for child in dynamic_world.get_children():
		child.queue_free()
	object_nodes.clear()
	for item in items:
		_sync_single_object(item)
	_render_parcels()


func _sync_single_object(item: Dictionary) -> void:
	if object_nodes.has(item.id):
		object_nodes[item.id].queue_free()
	var node := _make_world_prop(item.asset, Vector3(item.x, item.y, item.z), item.rotationY, item.scale)
	node.set_meta("object_id", item.id)
	_tag_pickable_nodes(node, item.id)
	node.set_meta("parcel", _get_parcel_at(node.position))
	_apply_selection_visual(node, item.id == selected_object_id)
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
		var animation_player := _find_animation_player(imported)
		if animation_player and animation_player.has_animation("Idle"):
			animation_player.play("Idle")
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
	var previous := avatar_previous_positions.get(state.avatarId, node.position)
	node.position = Vector3(state.x, state.y, state.z)
	avatar_previous_positions[state.avatarId] = node.position
	var appearance: Dictionary = state.get("appearance", {})
	var label: Label3D = null
	for child in node.get_children():
		if child is Label3D:
			label = child
		if child is MeshInstance3D:
			var mesh_child := child as MeshInstance3D
			var material := StandardMaterial3D.new()
			if mesh_child.name.to_lower().contains("head"):
				material.albedo_color = Color(appearance.get("headColor", "#f2c7a8"))
			else:
				material.albedo_color = Color(appearance.get("bodyColor", "#8cd8ff"))
			mesh_child.set_surface_override_material(0, material)
	if label:
		label.text = state.displayName
	_update_avatar_animation(node, previous.distance_to(node.position))


func _make_world_prop(asset: String, position: Vector3, rotation_y: float, scale_value: float) -> Node3D:
	var imported := _instantiate_imported_asset(asset)
	if imported:
		imported.position = position
		imported.rotation.y = rotation_y
		imported.scale = Vector3.ONE * scale_value
		_attach_selection_body(imported)
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
	_attach_selection_body(root)
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


func _attach_selection_body(node: Node3D) -> void:
	var bounds := AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	var found := false
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh:
			var mesh_bounds := (child as MeshInstance3D).get_aabb()
			bounds = mesh_bounds if not found else bounds.merge(mesh_bounds)
			found = true
	if not found:
		for descendant in node.find_children("*", "MeshInstance3D"):
			var mesh_node := descendant as MeshInstance3D
			if mesh_node and mesh_node.mesh:
				var desc_bounds := mesh_node.get_aabb()
				bounds = desc_bounds if not found else bounds.merge(desc_bounds)
				found = true
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(bounds.size.x, 0.6), maxf(bounds.size.y, 0.6), maxf(bounds.size.z, 0.6))
	shape.shape = box
	body.position = bounds.get_center()
	body.add_child(shape)
	node.add_child(body)


func _tag_pickable_nodes(node: Node, object_id: String) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).set_meta("object_id", object_id)
		_tag_pickable_nodes(child, object_id)


func _render_inventory() -> void:
	inventory_list.clear()
	selected_inventory_index = -1
	inventory_selection_label.text = "No inventory item selected"
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


func _on_inventory_item_selected(index: int) -> void:
	selected_inventory_index = index
	var item: Dictionary = inventory[index]
	inventory_selection_label.text = "%s - %s" % [item.name, item.kind]


func _equip_selected_inventory_item() -> void:
	if selected_inventory_index < 0 or selected_inventory_index >= inventory.size() or session.is_empty():
		return
	var item: Dictionary = inventory[selected_inventory_index]
	if item.get("slot", null) == null:
		status_label.text = "Selected item cannot be equipped"
		return
	var request := HTTPRequest.new()
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"token": session.token, "itemId": item.id})
	var url := "%s/api/inventory/equip" % backend_url_input.text.rstrip("/")
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result := await request.request_completed
		var payload := JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
		inventory = payload.get("inventory", inventory)
		_render_inventory()
		if payload.has("avatar"):
			avatar_states[payload.avatar.avatarId] = payload.avatar
			_sync_avatars()
		status_label.text = "Equipped %s" % item.name
	request.queue_free()


func _use_selected_inventory_item() -> void:
	if selected_inventory_index < 0 or selected_inventory_index >= inventory.size():
		return
	var item: Dictionary = inventory[selected_inventory_index]
	if item.get("slot", null) != null:
		await _equip_selected_inventory_item()
		return
	if item.kind == "tool":
		status_label.text = "%s ready for parcel editing" % item.name
	elif item.kind == "pet":
		_append_chat("System: %s companion activated" % item.name)
	else:
		status_label.text = "%s used" % item.name


func _toggle_build_mode() -> void:
	build_mode = not build_mode
	build_mode_button.text = "Disable build mode" if build_mode else "Enable build mode"
	status_label.text = "Build mode enabled" if build_mode else "Build mode disabled"
	if not build_mode:
		drag_selected = false
		active_drag_axis = ""
	_claim_button_state()


func _set_gizmo_mode(mode: String) -> void:
	gizmo_mode = mode
	status_label.text = "Gizmo mode: %s" % mode


func _handle_build_click(mouse_position: Vector2) -> void:
	if session.is_empty():
		return

	var from := camera.project_ray_origin(mouse_position)
	var to := from + camera.project_ray_normal(mouse_position) * 500.0
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space_state.intersect_ray(query)

	if not hit.is_empty() and hit.collider is Node and (hit.collider as Node).has_meta("gizmo_axis"):
		active_drag_axis = str((hit.collider as Node).get_meta("gizmo_axis"))
		drag_selected = true
		status_label.text = "Dragging %s axis" % active_drag_axis.to_upper()
		return

	if not hit.is_empty() and hit.collider is Node and (hit.collider as Node).has_meta("object_id"):
		selected_object_id = str((hit.collider as Node).get_meta("object_id"))
		_update_selection_state()
		drag_selected = true
		return

	var ground_plane := Plane(Vector3.UP, 0.0)
	var world_point := ground_plane.intersects_ray(from, camera.project_ray_normal(mouse_position))
	if world_point == null:
		return
	var parcel := _get_parcel_at(world_point)
	if not _can_build_in_parcel(parcel):
		status_label.text = _parcel_denied_reason(parcel)
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
		var parcel := _get_parcel_at(node.position)
		if not _can_build_in_parcel(parcel):
			status_label.text = _parcel_denied_reason(parcel)
			return
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
	active_parcel = _get_parcel_at(position)
	parcel_label.text = "Parcel: %s" % active_parcel.get("name", "none")
	_claim_button_state()
	await _load_region_objects(session.regionId)


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
		node.set_meta("parcel", _get_parcel_at(node.position))
		await _load_region_objects(session.regionId)


func _delete_selected_object() -> void:
	if selected_object_id.is_empty():
		return
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"token": session.token})
	var url := "%s/api/objects/%s" % [backend_url_input.text.rstrip("/"), selected_object_id]
	if delete_object_request.request(url, headers, HTTPClient.METHOD_DELETE, body) == OK:
		await delete_object_request.request_completed
		await _load_region_objects(session.regionId)
	selected_object_id = ""
	_update_selection_state()


func _duplicate_selected_object() -> void:
	if selected_object_id.is_empty() or not object_nodes.has(selected_object_id):
		return
	var node := object_nodes[selected_object_id]
	await _create_object(node.position + Vector3(1.0, 0.0, 1.0))


func _apply_gizmo_wheel(direction: float) -> void:
	var node := object_nodes[selected_object_id]
	if gizmo_mode == "rotate":
		node.rotation.y += 0.15 * direction
	elif gizmo_mode == "scale":
		node.scale *= 1.0 + (0.08 * direction)
	else:
		node.position.y += 0.3 * direction
	await _update_selected_object(node)


func _drag_selected_object(event: InputEventMouseMotion) -> void:
	var node := object_nodes[selected_object_id]
	if active_drag_axis.is_empty():
		return
	var delta := event.relative
	if gizmo_mode == "move":
		if active_drag_axis == "x":
			node.position.x += delta.x * 0.02
		elif active_drag_axis == "y":
			node.position.y -= delta.y * 0.02
		else:
			node.position.z += delta.x * 0.02
	elif gizmo_mode == "rotate":
		var rotation_delta := delta.x * 0.01
		if active_drag_axis == "x":
			node.rotation.x += rotation_delta
		elif active_drag_axis == "y":
			node.rotation.y += rotation_delta
		else:
			node.rotation.z += rotation_delta
	elif gizmo_mode == "scale":
		var scale_delta := max(0.2, 1.0 + (delta.x * 0.005))
		node.scale *= scale_delta
	active_parcel = _get_parcel_at(node.position)
	parcel_label.text = "Parcel: %s" % active_parcel.get("name", "none")
	_claim_button_state()


func _get_parcel_at(position: Vector3) -> Dictionary:
	for parcel in parcels:
		if position.x >= float(parcel.minX) and position.x <= float(parcel.maxX) and position.z >= float(parcel.minZ) and position.z <= float(parcel.maxZ):
			return parcel
	return {}


func _render_parcels() -> void:
	for child in parcels_root.get_children():
		child.queue_free()
	parcel_nodes.clear()
	for parcel in parcels:
		var root := Node3D.new()
		var width := float(parcel.maxX) - float(parcel.minX)
		var depth := float(parcel.maxZ) - float(parcel.minZ)
		var center := Vector3((float(parcel.minX) + float(parcel.maxX)) / 2.0, 0.03, (float(parcel.minZ) + float(parcel.maxZ)) / 2.0)

		var fill := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(width, depth)
		fill.mesh = plane
		fill.rotation_degrees.x = -90
		fill.position = center
		var fill_material := StandardMaterial3D.new()
		fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fill_material.albedo_color = _parcel_color(parcel, true)
		fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fill.set_surface_override_material(0, fill_material)
		root.add_child(fill)

		var line_material := StandardMaterial3D.new()
		line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_material.albedo_color = _parcel_color(parcel, false)
		line_material.emission_enabled = true
		line_material.emission = _parcel_color(parcel, false)
		for edge in _parcel_edges(parcel):
			var edge_mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = edge["size"]
			edge_mesh.mesh = box
			edge_mesh.position = edge["position"]
			edge_mesh.set_surface_override_material(0, line_material)
			root.add_child(edge_mesh)

		var label := Label3D.new()
		label.text = "%s (%s)" % [parcel.name, parcel.ownerDisplayName if parcel.ownerDisplayName != null else parcel.tier]
		label.position = center + Vector3(0, 0.25, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(label)

		parcels_root.add_child(root)
		parcel_nodes[parcel.id] = root


func _load_profiles() -> void:
	backend_profiles.clear()
	profile_select.clear()
	if FileAccess.file_exists(PROFILE_SAVE_PATH):
		var file := FileAccess.open(PROFILE_SAVE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Array:
				backend_profiles = parsed
	if backend_profiles.is_empty():
		backend_profiles.append({"name": "Local Default", "backendUrl": backend_url_input.text, "displayName": display_name_input.text})
	for profile in backend_profiles:
		profile_select.add_item(profile.get("name", "Profile"))
	_on_profile_selected(0)


func _persist_profiles() -> void:
	var file := FileAccess.open(PROFILE_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(backend_profiles))


func _save_current_profile() -> void:
	var name := "Profile %s" % str(backend_profiles.size() + 1)
	if not display_name_input.text.strip_edges().is_empty():
		name = display_name_input.text.strip_edges()
	backend_profiles.append({
		"name": name,
		"backendUrl": backend_url_input.text.strip_edges(),
		"displayName": display_name_input.text.strip_edges()
	})
	_persist_profiles()
	_load_profiles()
	status_label.text = "Saved backend profile %s" % name


func _on_profile_selected(index: int) -> void:
	if index < 0 or index >= backend_profiles.size():
		return
	var profile: Dictionary = backend_profiles[index]
	backend_url_input.text = profile.get("backendUrl", backend_url_input.text)
	display_name_input.text = profile.get("displayName", display_name_input.text)


func _save_login_state() -> void:
	if profile_select.selected >= 0 and profile_select.selected < backend_profiles.size():
		backend_profiles[profile_select.selected]["backendUrl"] = backend_url_input.text.strip_edges()
		backend_profiles[profile_select.selected]["displayName"] = display_name_input.text.strip_edges()
		_persist_profiles()


func _load_client_settings() -> void:
	if FileAccess.file_exists(SETTINGS_SAVE_PATH):
		var file := FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				fullscreen_check.button_pressed = parsed.get("fullscreen", false)
				mouse_sensitivity_slider.value = float(parsed.get("mouseSensitivity", 1.0))
				camera_distance_slider.value = float(parsed.get("cameraDistance", 12.0))
	_apply_client_settings()


func _save_client_settings() -> void:
	var payload := {
		"fullscreen": fullscreen_check.button_pressed,
		"mouseSensitivity": mouse_sensitivity_slider.value,
		"cameraDistance": camera_distance_slider.value
	}
	var file := FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))
	_apply_client_settings()
	status_label.text = "Client settings saved"


func _apply_client_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_check.button_pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	camera.position.z = camera_distance_slider.value


func _parcel_color(parcel: Dictionary, transparent: bool) -> Color:
	if not active_parcel.is_empty() and parcel.id == active_parcel.get("id", ""):
		return Color(1.0, 0.95, 0.54, 0.18 if transparent else 1.0)
	if parcel.tier == "public":
		return Color(0.4, 1.0, 0.82, 0.08 if transparent else 1.0)
	if parcel.ownerAccountId == null:
		return Color(0.95, 0.58, 0.35, 0.08 if transparent else 1.0)
	if String(parcel.ownerAccountId) == String(session.get("accountId", "")):
		return Color(1.0, 0.7, 0.42, 0.1 if transparent else 1.0)
	return Color(0.92, 0.35, 0.35, 0.08 if transparent else 1.0)


func _parcel_edges(parcel: Dictionary) -> Array:
	var min_x := float(parcel.minX)
	var max_x := float(parcel.maxX)
	var min_z := float(parcel.minZ)
	var max_z := float(parcel.maxZ)
	var center_x := (min_x + max_x) / 2.0
	var center_z := (min_z + max_z) / 2.0
	return [
		{"position": Vector3(center_x, 0.08, min_z), "size": Vector3(max_x - min_x, 0.08, 0.08)},
		{"position": Vector3(center_x, 0.08, max_z), "size": Vector3(max_x - min_x, 0.08, 0.08)},
		{"position": Vector3(min_x, 0.08, center_z), "size": Vector3(0.08, 0.08, max_z - min_z)},
		{"position": Vector3(max_x, 0.08, center_z), "size": Vector3(0.08, 0.08, max_z - min_z)}
	]


func _can_build_in_parcel(parcel: Dictionary) -> bool:
	if parcel.is_empty():
		return false
	if parcel.tier == "public":
		return true
	if parcel.ownerAccountId == null:
		return false
	return String(parcel.ownerAccountId) == String(session.accountId)


func _parcel_denied_reason(parcel: Dictionary) -> String:
	if parcel.is_empty():
		return "Builds must be placed inside a parcel"
	if parcel.ownerAccountId == null and parcel.tier != "public":
		return "Claim this parcel before building here"
	return "Parcel owned by %s" % parcel.get("ownerDisplayName", "another resident")


func _update_selection_state() -> void:
	selection_label.text = "Selected: %s" % selected_object_id if not selected_object_id.is_empty() else "No object selected"
	for object_id in object_nodes.keys():
		_apply_selection_visual(object_nodes[object_id], object_id == selected_object_id)
	active_parcel = object_nodes[selected_object_id].get_meta("parcel", {}) if not selected_object_id.is_empty() and object_nodes.has(selected_object_id) else {}
	if not selected_object_id.is_empty() and object_nodes.has(selected_object_id):
		active_parcel = _get_parcel_at(object_nodes[selected_object_id].position)
	else:
		active_parcel = {}
	parcel_label.text = "Parcel: %s" % active_parcel.get("name", "none")
	_update_gizmo_handles()
	_claim_button_state()


func _apply_selection_visual(node: Node3D, selected: bool) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_child := child as MeshInstance3D
			var material := mesh_child.get_active_material(0)
			if material is StandardMaterial3D:
				(material as StandardMaterial3D).emission_enabled = selected
				(material as StandardMaterial3D).emission = Color("ffb36a")


func _rebuild_gizmo_handles() -> void:
	for child in gizmos_root.get_children():
		child.queue_free()
	gizmo_handles.clear()
	for axis in ["x", "y", "z"]:
		var handle_root := Node3D.new()
		var handle := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.04
		mesh.bottom_radius = 0.04
		mesh.height = 1.3
		handle.mesh = mesh
		var material := StandardMaterial3D.new()
		material.emission_enabled = true
		material.albedo_color = axis == "x" ? Color("ff6b6b") : axis == "y" ? Color("66ffd1") : Color("6aa8ff")
		material.emission = material.albedo_color
		handle.set_surface_override_material(0, material)
		handle_root.add_child(handle)
		var body := StaticBody3D.new()
		body.set_meta("gizmo_axis", axis)
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.height = 1.3
		cylinder.radius = 0.18
		shape.shape = cylinder
		body.add_child(shape)
		handle_root.add_child(body)
		handle_root.visible = false
		gizmos_root.add_child(handle_root)
		gizmo_handles[axis] = handle_root


func _update_gizmo_handles() -> void:
	if gizmo_handles.is_empty():
		_rebuild_gizmo_handles()
	if selected_object_id.is_empty() or not object_nodes.has(selected_object_id):
		for handle in gizmo_handles.values():
			handle.visible = false
		return

	var target := object_nodes[selected_object_id].position
	var x_handle: Node3D = gizmo_handles["x"]
	var y_handle: Node3D = gizmo_handles["y"]
	var z_handle: Node3D = gizmo_handles["z"]
	x_handle.visible = true
	y_handle.visible = true
	z_handle.visible = true
	x_handle.position = target + Vector3(1.0, 0.65, 0.0)
	z_handle.position = target + Vector3(0.0, 0.65, 1.0)
	y_handle.position = target + Vector3(0.0, 1.2, 0.0)
	x_handle.rotation_degrees.z = 90
	z_handle.rotation_degrees.x = 90
	y_handle.rotation = Vector3.ZERO


func _claim_button_state() -> void:
	claim_parcel_button.disabled = active_parcel.is_empty() or active_parcel.get("tier", "") == "public" or active_parcel.get("ownerAccountId", null) != null


func _claim_active_parcel() -> void:
	if active_parcel.is_empty() or session.is_empty() or active_parcel.get("tier", "") == "public":
		return
	var request := HTTPRequest.new()
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"token": session.token, "parcelId": active_parcel.id})
	var url := "%s/api/parcels/claim" % backend_url_input.text.rstrip("/")
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result := await request.request_completed
		if int(result[1]) == 200:
			var payload := JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			var parcel = payload.get("parcel", {})
			for index in range(parcels.size()):
				if parcels[index].id == parcel.id:
					parcels[index] = parcel
			active_parcel = parcel
			_render_parcels()
			_claim_button_state()
			status_label.text = "Claimed %s" % parcel.get("name", "parcel")
		else:
			status_label.text = "Parcel claim failed"
	request.queue_free()


func _on_inventory_item_selected(index: int) -> void:
	selected_inventory_index = index
	var item: Dictionary = inventory[index]
	inventory_selection_label.text = "%s - %s" % [item.name, item.kind]


func _equip_selected_inventory_item() -> void:
	if selected_inventory_index < 0 or selected_inventory_index >= inventory.size() or session.is_empty():
		return
	var item: Dictionary = inventory[selected_inventory_index]
	if item.get("slot", null) == null:
		status_label.text = "Selected item cannot be equipped"
		return
	var request := HTTPRequest.new()
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"token": session.token, "itemId": item.id})
	var url := "%s/api/inventory/equip" % backend_url_input.text.rstrip("/")
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result := await request.request_completed
		var payload := JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
		inventory = payload.get("inventory", inventory)
		_render_inventory()
		status_label.text = "Equipped %s" % item.name
	request.queue_free()


func _use_selected_inventory_item() -> void:
	if selected_inventory_index < 0 or selected_inventory_index >= inventory.size():
		return
	var item: Dictionary = inventory[selected_inventory_index]
	if item.get("slot", null) != null:
		await _equip_selected_inventory_item()
		return
	if item.kind == "tool":
		status_label.text = "%s ready for parcel editing" % item.name
	elif item.kind == "pet":
		_append_chat("System: %s companion activated" % item.name)
	else:
		status_label.text = "%s used" % item.name


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


func _update_avatar_animation(node: Node3D, movement_delta: float) -> void:
	var animation_player := _find_animation_player(node)
	if animation_player == null:
		return
	var desired := "Walk" if movement_delta > 0.02 else "Idle"
	if animation_player.has_animation(desired) and animation_player.current_animation != desired:
		animation_player.play(desired)


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
