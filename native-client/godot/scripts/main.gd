extends Node3D

const WS_SNAPSHOT := "snapshot"

# Scene node references
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var ground: MeshInstance3D = $Ground
@onready var static_world: Node3D = $StaticWorld
@onready var dynamic_world: Node3D = $DynamicWorld
@onready var avatars_root: Node3D = $Avatars
@onready var gizmos_root: Node3D = $Gizmos
@onready var parcels_root: Node3D = $Parcels

# HTTP request nodes
@onready var regions_request: HTTPRequest = $Network/RegionsRequest
@onready var auth_request: HTTPRequest = $Network/AuthRequest
@onready var scene_request: HTTPRequest = $Network/SceneRequest
@onready var objects_request: HTTPRequest = $Network/ObjectsRequest
@onready var create_object_request: HTTPRequest = $Network/CreateObjectRequest
@onready var update_object_request: HTTPRequest = $Network/UpdateObjectRequest
@onready var delete_object_request: HTTPRequest = $Network/DeleteObjectRequest

# Sidebar UI
@onready var backend_url_input: LineEdit = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/BackendUrlInput
@onready var profile_select: OptionButton = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/ProfileSelect
@onready var save_profile_button: Button = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/SaveProfileButton
@onready var display_name_input: LineEdit = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/DisplayNameInput
@onready var auth_mode_select: OptionButton = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/AuthModeSelect
@onready var password_input: LineEdit = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/PasswordInput
@onready var region_select: OptionButton = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/RegionSelect
@onready var refresh_regions_button: Button = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/RefreshRegionsButton
@onready var join_button: Button = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/JoinButton
@onready var status_label: Label = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/StatusLabel
@onready var fullscreen_check: CheckBox = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/FullscreenCheck
@onready var mouse_sensitivity_slider: HSlider = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/MouseSensitivitySlider
@onready var invert_look_check: CheckBox = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/InvertLookCheck
@onready var camera_distance_slider: HSlider = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/CameraDistanceSlider
@onready var fov_slider: HSlider = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/FovSlider
@onready var shadows_check: CheckBox = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/ShadowsCheck
@onready var save_settings_button: Button = $CanvasLayer/UI/Sidebar/Margin/Scroll/VBox/SaveSettingsButton

# Top bar
@onready var status_pill: Label = $CanvasLayer/UI/TopBar/TopMargin/TopRow/StatusPill

# Right dock UI
@onready var inventory_list: ItemList = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/InventoryList
@onready var inventory_selection_label: Label = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/InventorySelectionLabel
@onready var equip_item_button: Button = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/InventoryActionRow/EquipItemButton
@onready var use_item_button: Button = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/InventoryActionRow/UseItemButton
@onready var chat_log: RichTextLabel = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/ChatLog
@onready var chat_input: LineEdit = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/ChatInputRow/ChatInput
@onready var send_chat_button: Button = $CanvasLayer/UI/RightDock/RightMargin/RightVBox/ChatInputRow/SendChatButton

# Build panel UI
@onready var build_mode_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/BuildModeButton
@onready var build_asset_select: OptionButton = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/BuildAssetSelect
@onready var move_mode_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/GizmoModeRow/MoveModeButton
@onready var rotate_mode_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/GizmoModeRow/RotateModeButton
@onready var scale_mode_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/GizmoModeRow/ScaleModeButton
@onready var selection_label: Label = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/SelectionLabel
@onready var parcel_label: Label = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/ParcelLabel
@onready var claim_parcel_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/ClaimParcelButton
@onready var release_parcel_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/ReleaseParcelButton
@onready var duplicate_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/DuplicateButton
@onready var delete_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/DeleteButton
@onready var admin_audit_log: RichTextLabel = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/AdminAuditLog
@onready var build_asset_search: LineEdit = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/BuildAssetSearch
@onready var save_blueprint_button: Button = $CanvasLayer/UI/BuildPanel/BuildMargin/BuildVBox/SaveBlueprintButton

# Shared state
var websocket := WebSocketPeer.new()
var regions: Array = []
var session: Dictionary = {}
var inventory: Array = []
var selected_inventory_index := -1
var backend_profiles: Array = []
var last_sequence := 0

var backend_url: String:
	get: return backend_url_input.text.rstrip("/")

const PROFILE_SAVE_PATH := "user://backend_profiles.json"
const SETTINGS_SAVE_PATH := "user://client_settings.json"
var build_assets := [
	"/assets/models/market-hall.gltf",
	"/assets/models/skyport-tower.gltf",
	"/assets/models/garden-tree.gltf",
	"/assets/models/park-bench.gltf",
	"/assets/models/street-lantern.gltf",
	"/assets/models/dock-crate.gltf"
]

# Modules
var cam: CameraController
var avatars: AvatarManager
var objects: ObjectManager
var parcels_mgr: ParcelManager
var build: BuildController
var radio: RadioController
var emote_panel: EmotePanel
var post_processing: PostProcessing
var day_night: DayNightCycle
var terrain: TerrainManager
var sky_mgr: SkyManager
var particles: AmbientParticles
var mat_lib: MaterialLibrary
var chat_bubbles = ChatBubble.new()
var biome_mgr: BiomeManager
var weather: WeatherSystem
var blueprint_mgr: BlueprintManager
var build_assets_full: Array = []
var clipboard: Array = []


func _ready() -> void:
	# Initialize modules
	cam = CameraController.new()
	cam.init(camera_rig, camera)

	objects = ObjectManager.new()
	objects.init(self)

	avatars = AvatarManager.new()
	avatars.init(self)

	parcels_mgr = ParcelManager.new()
	parcels_mgr.init(self)

	build = BuildController.new()
	build.init(self)

	radio = RadioController.new()
	radio.init(self)

	emote_panel = EmotePanel.new()
	emote_panel.init(self)

	# Material library (must init before objects use it)
	mat_lib = MaterialLibrary.new()
	mat_lib.init(self)

	# Terrain (replaces flat ground)
	terrain = TerrainManager.new()
	terrain.init(self)
	terrain.setup_terrain()

	# Sky atmosphere
	sky_mgr = SkyManager.new()
	sky_mgr.init(self)
	sky_mgr.setup_sky()

	# Ambient particles
	particles = AmbientParticles.new()
	particles.init(self)
	particles.setup_particles()

	# Visual modules
	post_processing = PostProcessing.new()
	post_processing.init($WorldEnvironment)

	day_night = DayNightCycle.new()
	day_night.init($Sun, $WorldEnvironment.environment)

	# Biome & weather
	biome_mgr = BiomeManager.new()
	biome_mgr.init(self)
	weather = WeatherSystem.new()
	weather.init(self)

	# Chat bubbles
	chat_bubbles.init(self)

	# Blueprints
	blueprint_mgr = BlueprintManager.new()
	blueprint_mgr.init(self)

	# Wire signals
	refresh_regions_button.pressed.connect(_fetch_regions)
	profile_select.item_selected.connect(_on_profile_selected)
	save_profile_button.pressed.connect(_save_current_profile)
	join_button.pressed.connect(_join_world)
	save_settings_button.pressed.connect(_save_client_settings)
	send_chat_button.pressed.connect(_send_chat)
	chat_input.text_submitted.connect(func(_text: String): _send_chat())
	chat_input.text_changed.connect(func(new_text: String): chat_bubbles.on_chat_input_changed(new_text))
	build_mode_button.pressed.connect(build.toggle_build_mode)
	move_mode_button.pressed.connect(func(): build.set_gizmo_mode("move"))
	rotate_mode_button.pressed.connect(func(): build.set_gizmo_mode("rotate"))
	scale_mode_button.pressed.connect(func(): build.set_gizmo_mode("scale"))
	duplicate_button.pressed.connect(build.duplicate_selected_object)
	delete_button.pressed.connect(build._delete_selected_object)
	claim_parcel_button.pressed.connect(parcels_mgr.claim_active_parcel)
	release_parcel_button.pressed.connect(parcels_mgr.release_active_parcel)
	inventory_list.item_selected.connect(_on_inventory_item_selected)
	equip_item_button.pressed.connect(_equip_selected_inventory_item)
	use_item_button.pressed.connect(_use_selected_inventory_item)
	regions_request.request_completed.connect(_on_regions_loaded)
	auth_request.request_completed.connect(_on_auth_completed)
	scene_request.request_completed.connect(_on_scene_loaded)
	objects_request.request_completed.connect(_on_objects_loaded)

	build_assets_full = build_assets.duplicate()
	build_asset_search.text_changed.connect(_on_build_asset_search_changed)
	save_blueprint_button.pressed.connect(_save_blueprint_from_selection)
	for asset in build_assets:
		build_asset_select.add_item(asset.get_file().trim_suffix(".gltf").replace("-", " "))
	for auth_mode in ["Guest", "Register", "Login"]:
		auth_mode_select.add_item(auth_mode)

	_load_profiles()
	_load_client_settings()
	_fetch_regions()
	build.set_gizmo_mode("move")


func _process(delta: float) -> void:
	_poll_websocket()
	if not avatars.is_local_player_sitting():
		avatars.update_local_movement(delta)
	if avatars.has_local_avatar():
		cam.update(delta, avatars.get_local_avatar_position())
	build.update_gizmo_handles()
	day_night.update(delta)
	# Sync sky shader and particles with the day/night cycle time.
	# DayNightCycle handles sun transform/energy and ambient light;
	# sky_mgr only updates the sky shader uniform here.
	if day_night and sky_mgr:
		sky_mgr.set_shader_time(day_night.time_of_day)
	if day_night and particles:
		particles.update_time(day_night.time_of_day)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if build.build_mode and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed and build.drag_selected:
			build.drag_selected = false
			build.active_drag_axis = ""
			if not build.selected_object_id.is_empty() and objects.object_nodes.has(build.selected_object_id):
				await build._update_selected_object(objects.object_nodes[build.selected_object_id])
		if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and not build.build_mode and not session.is_empty():
			if avatars.try_sit_on_object(button.position):
				return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			cam.orbiting = button.pressed
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			if build.build_mode and not build.selected_object_id.is_empty() and objects.object_nodes.has(build.selected_object_id):
				build.apply_gizmo_wheel(1.0)
			else:
				camera.position.z = max(6.0, camera.position.z - 1.0)
				camera_distance_slider.value = camera.position.z
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			if build.build_mode and not build.selected_object_id.is_empty() and objects.object_nodes.has(build.selected_object_id):
				build.apply_gizmo_wheel(-1.0)
			else:
				camera.position.z = min(24.0, camera.position.z + 1.0)
				camera_distance_slider.value = camera.position.z
	elif event is InputEventMouseMotion and cam.orbiting:
		var motion := event as InputEventMouseMotion
		cam.handle_orbit(motion.relative, mouse_sensitivity_slider.value, invert_look_check.button_pressed)
	elif event is InputEventMouseMotion and build.build_mode and build.drag_selected and not build.selected_object_id.is_empty() and objects.object_nodes.has(build.selected_object_id):
		build.drag_selected_object(event)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.pressed and build.build_mode:
		await build.handle_build_click(event.position)
	elif event is InputEventKey and event.pressed and build.build_mode:
		await build.handle_build_key(event)


# ── Network ─────────────────────────────────────────────────────────────────

func _fetch_regions() -> void:
	status_label.text = "Fetching regions..."
	status_pill.text = "Loading regions"
	region_select.clear()
	var url := "%s/api/regions" % backend_url
	var error := regions_request.request(url)
	if error != OK:
		status_label.text = "Region request failed: %s" % error


func _on_regions_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "Region request returned %s" % response_code
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
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
	var auth_modes := ["guest", "register", "login"]
	var auth_mode = auth_modes[auth_mode_select.selected]
	var body := JSON.stringify({
		"displayName": display_name_input.text,
		"regionId": chosen_region.id,
		"password": password_input.text
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := "%s/api/auth/%s" % [backend_url, auth_mode]
	var error := auth_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		status_label.text = "Auth request failed: %s" % error


func _on_auth_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "Join request returned %s" % response_code
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	session = payload.get("session", {})
	avatars.avatar_states.clear()
	avatars.avatar_states[payload.avatar.avatarId] = payload.avatar
	status_label.text = "Connected as %s" % session.displayName
	status_pill.text = "Connected"
	_save_login_state()
	_apply_client_settings()
	inventory = payload.get("inventory", [])
	parcels_mgr.parcels = payload.get("parcels", [])
	_render_inventory()
	parcels_mgr.render_parcels()
	await parcels_mgr.load_admin_audit_logs()
	_apply_region_biome(session.regionId)
	_append_chat("System: joined %s" % session.regionId)
	await _load_region_scene(session.regionId)
	await _load_region_objects(session.regionId)
	avatars.sync_avatars()
	_connect_websocket()


func _apply_region_biome(region_id: String) -> void:
	var biome_data = {}
	for region in regions:
		if region.get("id", "") == region_id:
			biome_data = region.get("biome", {})
			break
	if not biome_data.is_empty():
		biome_mgr.apply_biome(biome_data)
		var fog_density = biome_data.get("fogDensity", 0.01)
		weather.set_base_fog_density(float(fog_density))
		var weather_type = biome_data.get("weatherType", "clear")
		weather.set_weather(str(weather_type))


func _load_region_scene(region_id: String) -> void:
	for child in static_world.get_children():
		child.queue_free()
	var url := "%s/scenes/%s.json" % [backend_url, region_id]
	var error := scene_request.request(url)
	if error != OK:
		status_label.text = "Scene request failed: %s" % error
		return
	await scene_request.request_completed


func _on_scene_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "Scene request returned %s" % response_code
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	objects.load_scene_assets(payload)


func _load_region_objects(region_id: String) -> void:
	var url := "%s/api/regions/%s/objects" % [backend_url, region_id]
	var error := objects_request.request(url)
	if error != OK:
		status_label.text = "Objects request failed: %s" % error
		return
	await objects_request.request_completed


func _on_objects_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "Objects request returned %s" % response_code
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	for child in dynamic_world.get_children():
		child.queue_free()
	objects.object_nodes.clear()
	for item in payload.get("objects", []):
		var node := objects.make_world_prop(item.asset, Vector3(item.x, item.y, item.z), item.rotationY, item.scale)
		dynamic_world.add_child(node)
		objects.object_nodes[item.id] = node
	build.update_selection_state()


func _connect_websocket() -> void:
	websocket = WebSocketPeer.new()
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.close()
	var base := backend_url_input.text.rstrip("/")
	var ws_url := base.replace("http://", "ws://").replace("https://", "wss://")
	ws_url += "/ws/regions/%s?token=%s&lastSequence=%s" % [session.regionId, session.token, str(last_sequence)]
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
		var payload = JSON.parse_string(websocket.get_packet().get_string_from_utf8())
		_handle_socket_message(payload)


func _handle_socket_message(message: Dictionary) -> void:
	match message.get("type", ""):
		WS_SNAPSHOT:
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			avatars.avatar_states.clear()
			for avatar in message.get("avatars", []):
				avatars.avatar_states[avatar.avatarId] = avatar
			parcels_mgr.parcels = message.get("parcels", parcels_mgr.parcels)
			avatars.sync_avatars()
			objects.sync_objects(message.get("objects", []))
			# Load chat history from snapshot
			for chat_entry in message.get("chatHistory", []):
				var ts := _format_chat_timestamp(chat_entry.get("createdAt", ""))
				if chat_entry.get("avatarId", "") == "system":
					_append_chat("[%s] [System] %s" % [ts, chat_entry.get("message", "")])
				else:
					_append_chat("[%s] %s: %s" % [ts, chat_entry.get("displayName", ""), chat_entry.get("message", "")])
		"avatar:joined", "avatar:moved", "avatar:updated":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			var avatar = message.avatar
			avatars.avatar_states[avatar.avatarId] = avatar
			avatars.sync_avatars()
		"parcel:updated":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			parcels_mgr.update_parcel_from_event(message.parcel)
			parcels_mgr.render_parcels()
			parcels_mgr.claim_button_state()
		"avatar:left":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			chat_bubbles.cleanup_avatar(message.avatarId)
			avatars.avatar_states.erase(message.avatarId)
			avatars.sync_avatars()
		"chat":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			var ts := _format_chat_timestamp(message.get("createdAt", ""))
			if message.get("avatarId", "") == "system":
				_append_chat("[%s] [System] %s" % [ts, message.message])
			else:
				_append_chat("[%s] %s: %s" % [ts, message.displayName, message.message])
			chat_bubbles.show_bubble(message.get("avatarId", ""), message.get("message", ""))
		"avatar:typing":
			chat_bubbles.show_typing(message.get("avatarId", ""), message.get("typing", false))
		"chat:history":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			for entry in message.get("messages", []):
				var hist_ts := _format_chat_timestamp(entry.get("createdAt", ""))
				_append_chat("[%s] %s: %s" % [hist_ts, entry.get("displayName", ""), entry.get("message", "")])
		"whisper":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			var whisper_ts := _format_chat_timestamp(message.get("createdAt", ""))
			var from_id: String = message.get("fromAvatarId", "")
			var my_avatar_id: String = session.get("avatarId", "")
			if from_id == my_avatar_id:
				_append_chat("[%s] [whisper to %s] %s" % [whisper_ts, message.get("toDisplayName", ""), message.message])
			else:
				_append_chat("[%s] [whisper from %s] %s" % [whisper_ts, message.get("fromDisplayName", ""), message.message])
		"object:created", "object:updated":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			objects.sync_single_object(message.object)
		"object:deleted":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			if objects.object_nodes.has(message.objectId):
				objects.object_nodes[message.objectId].queue_free()
				objects.object_nodes.erase(message.objectId)
		"radio:changed":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			radio.handle_radio_changed(message)
			_append_chat("Radio: Now playing %s on %s" % [message.get("trackName", ""), message.get("stationName", "")])
		"avatar:emote":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			var emote_avatar_id: String = message.get("avatarId", "")
			var emote_name: String = message.get("emoteName", "")
			var emote_display: String = message.get("displayName", "")
			avatars.handle_emote_event(emote_avatar_id, emote_name)
			_append_chat("%s performs %s" % [emote_display, emote_name])
		"emote:combo":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			emote_panel.handle_emote_combo(message)
		"avatar:sit":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			avatars.handle_sit(str(message.avatarId), str(message.objectId), message.position)
		"avatar:stand":
			last_sequence = maxi(last_sequence, int(message.get("sequence", 0)))
			avatars.handle_stand(str(message.avatarId))


# ── Inventory & Chat ────────────────────────────────────────────────────────

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


func _format_chat_timestamp(iso_string: String) -> String:
	if iso_string.is_empty():
		return ""
	var t_pos := iso_string.find("T")
	if t_pos < 0:
		return ""
	var time_part := iso_string.substr(t_pos + 1)
	if time_part.length() >= 5:
		return time_part.substr(0, 5)
	return time_part


func _send_chat() -> void:
	var message := chat_input.text.strip_edges()
	if message.is_empty():
		return
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		status_label.text = "Chat unavailable until region WebSocket connects."
		return
	# Whisper command: /w username message
	if message.begins_with("/w "):
		var parts := message.substr(3).strip_edges()
		var space_idx := parts.find(" ")
		if space_idx > 0:
			var target_name := parts.substr(0, space_idx)
			var whisper_msg := parts.substr(space_idx + 1).strip_edges()
			if not whisper_msg.is_empty():
				websocket.send_text(JSON.stringify({
					"type": "whisper",
					"targetDisplayName": target_name,
					"message": whisper_msg
				}))
				chat_input.clear()
				return
		status_label.text = "Usage: /w <username> <message>"
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
	var url := "%s/api/inventory/equip" % backend_url
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result = await request.request_completed
		var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
		inventory = payload.get("inventory", inventory)
		_render_inventory()
		if payload.has("avatar"):
			avatars.avatar_states[payload.avatar.avatarId] = payload.avatar
			avatars.sync_avatars()
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


# ── Client Settings ─────────────────────────────────────────────────────────

func _load_client_settings() -> void:
	if FileAccess.file_exists(SETTINGS_SAVE_PATH):
		var file := FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				fullscreen_check.button_pressed = parsed.get("fullscreen", false)
				mouse_sensitivity_slider.value = float(parsed.get("mouseSensitivity", 1.0))
				invert_look_check.button_pressed = parsed.get("invertLook", false)
				camera_distance_slider.value = float(parsed.get("cameraDistance", 12.0))
				fov_slider.value = float(parsed.get("fov", 75.0))
				shadows_check.button_pressed = parsed.get("shadows", true)
	_apply_client_settings()


func _save_client_settings() -> void:
	var payload := {
		"fullscreen": fullscreen_check.button_pressed,
		"mouseSensitivity": mouse_sensitivity_slider.value,
		"invertLook": invert_look_check.button_pressed,
		"cameraDistance": camera_distance_slider.value,
		"fov": fov_slider.value,
		"shadows": shadows_check.button_pressed
	}
	var file := FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))
	_apply_client_settings()
	status_label.text = "Client settings saved"


func _apply_client_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_check.button_pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	camera.position.z = camera_distance_slider.value
	camera.fov = fov_slider.value
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = shadows_check.button_pressed


# ── Backend Profiles ────────────────────────────────────────────────────────

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
	var profile_name := "Profile %s" % str(backend_profiles.size() + 1)
	if not display_name_input.text.strip_edges().is_empty():
		profile_name = display_name_input.text.strip_edges()
	backend_profiles.append({
		"name": profile_name,
		"backendUrl": backend_url_input.text.strip_edges(),
		"displayName": display_name_input.text.strip_edges(),
		"authMode": auth_mode_select.selected
	})
	_persist_profiles()
	_load_profiles()
	status_label.text = "Saved backend profile %s" % profile_name


func _on_profile_selected(index: int) -> void:
	if index < 0 or index >= backend_profiles.size():
		return
	var profile: Dictionary = backend_profiles[index]
	backend_url_input.text = profile.get("backendUrl", backend_url_input.text)
	display_name_input.text = profile.get("displayName", display_name_input.text)
	auth_mode_select.select(int(profile.get("authMode", 0)))


func _save_login_state() -> void:
	if profile_select.selected >= 0 and profile_select.selected < backend_profiles.size():
		backend_profiles[profile_select.selected]["backendUrl"] = backend_url_input.text.strip_edges()
		backend_profiles[profile_select.selected]["displayName"] = display_name_input.text.strip_edges()
		backend_profiles[profile_select.selected]["authMode"] = auth_mode_select.selected
		_persist_profiles()


func _on_build_asset_search_changed(search_text: String) -> void:
	build_asset_select.clear()
	build_assets = []
	var lower_search := search_text.strip_edges().to_lower()
	for asset in build_assets_full:
		var label_text = asset.get_file().trim_suffix(".gltf").replace("-", " ")
		if lower_search.is_empty() or label_text.to_lower().contains(lower_search):
			build_assets.append(asset)
			build_asset_select.add_item(label_text)
	if build_asset_select.item_count > 0:
		build_asset_select.selected = 0


func _save_blueprint_from_selection() -> void:
	if build.selected_object_id.is_empty():
		status_label.text = "Select object(s) before saving blueprint"
		return
	var ids: Array = [build.selected_object_id]
	await blueprint_mgr.save_blueprint("Blueprint %s" % str(Time.get_ticks_msec()), ids)
