extends Node3D

# Scene node references
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var ground: MeshInstance3D = $Ground
@onready var static_world: Node3D = $StaticWorld
@onready var dynamic_world: Node3D = $DynamicWorld
@onready var avatars_root: Node3D = $Avatars
@onready var gizmos_root: Node3D = $Gizmos
@onready var parcels_root: Node3D = $Parcels
@onready var voxels_root: Node3D = $VoxelsRoot
@onready var enemies_root: Node3D = $EnemiesRoot

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
var session_flow: SessionCoordinator

# Tier 3 modules
var chat_ctrl: ChatController
var social_mgr: SocialManager
var achievement_mgr: AchievementManager
var guild_mgr: GuildManager
var marketplace_mgr: MarketplaceManager
var pet_mgr: PetManager
var media_mgr: MediaManager
var seasonal_mgr: SeasonalManager
var script_mgr: ScriptManager
var home_mgr: HomeManager
var interactive_mgr: InteractiveManager
var event_mgr: EventManager
var camera_mgr: CameraManager
var home_rating: HomeRatingPanel
var storefront_mgr: StorefrontManager
var spatial_audio_mgr: SpatialAudio
var grid_overlay: GridOverlay
var undo_mgr: UndoManager

# Voxel MMORPG modules
var voxel_mgr: VoxelManager
var combat_hud: CombatHUD
var enemy_renderer: EnemyRenderer


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

	# Tier 3 modules
	chat_ctrl = ChatController.new()
	chat_ctrl.init(self)
	social_mgr = SocialManager.new()
	social_mgr.init(self)
	achievement_mgr = AchievementManager.new()
	achievement_mgr.init(self)
	guild_mgr = GuildManager.new()
	guild_mgr.init(self)
	marketplace_mgr = MarketplaceManager.new()
	marketplace_mgr.init(self)
	pet_mgr = PetManager.new()
	pet_mgr.init(self)
	media_mgr = MediaManager.new()
	media_mgr.init(self)
	seasonal_mgr = SeasonalManager.new()
	seasonal_mgr.init(self)
	script_mgr = ScriptManager.new()
	script_mgr.init(self)
	home_mgr = HomeManager.new()
	home_mgr.init(self)
	interactive_mgr = InteractiveManager.new()
	interactive_mgr.init(self)
	event_mgr = EventManager.new()
	event_mgr.init(self)
	camera_mgr = CameraManager.new()
	camera_mgr.init(self)
	home_rating = HomeRatingPanel.new()
	home_rating.init(self)
	storefront_mgr = StorefrontManager.new()
	storefront_mgr.init(self)
	spatial_audio_mgr = SpatialAudio.new()
	spatial_audio_mgr.init(self)
	grid_overlay = GridOverlay.new()
	grid_overlay.init(self)
	undo_mgr = UndoManager.new()
	undo_mgr.init(self)

	# Session and world streaming coordinator
	session_flow = SessionCoordinator.new()
	session_flow.init(self)

	# Voxel engine
	voxel_mgr = VoxelManager.new()
	voxel_mgr.init(self)

	# Combat HUD
	combat_hud = CombatHUD.new()
	combat_hud.init(self)

	# Enemy renderer
	enemy_renderer = EnemyRenderer.new()
	enemy_renderer.init(self)

	# Wire signals
	refresh_regions_button.pressed.connect(session_flow.fetch_regions)
	profile_select.item_selected.connect(_on_profile_selected)
	save_profile_button.pressed.connect(_save_current_profile)
	join_button.pressed.connect(session_flow.join_world)
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
	regions_request.request_completed.connect(session_flow.on_regions_loaded)
	auth_request.request_completed.connect(session_flow.on_auth_completed)
	scene_request.request_completed.connect(session_flow.on_scene_loaded)
	objects_request.request_completed.connect(session_flow.on_objects_loaded)

	build_assets_full = build_assets.duplicate()
	build_asset_search.text_changed.connect(_on_build_asset_search_changed)
	save_blueprint_button.pressed.connect(_save_blueprint_from_selection)
	for asset in build_assets:
		build_asset_select.add_item(asset.get_file().trim_suffix(".gltf").replace("-", " "))
	for auth_mode in ["Guest", "Register", "Login"]:
		auth_mode_select.add_item(auth_mode)

	_load_profiles()
	_load_client_settings()
	session_flow.fetch_regions()
	build.set_gizmo_mode("move")


func _process(delta: float) -> void:
	session_flow.poll_websocket()
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
	# Voxel chunk streaming based on player position
	if voxel_mgr and avatars.has_local_avatar():
		voxel_mgr.update_chunks(avatars.get_local_avatar_position())
		voxel_mgr.update_block_cursor(camera)
	# Enemy animations
	if enemy_renderer:
		enemy_renderer._process_enemies(delta)
	# Combat HUD updates
	if combat_hud:
		combat_hud._process_hud(delta)


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
		if button.button_index == MOUSE_BUTTON_RIGHT or button.button_index == MOUSE_BUTTON_MIDDLE:
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
	# Voxel mode toggle (V key)
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_V and not build.build_mode:
		if voxel_mgr:
			voxel_mgr.toggle_voxel_mode()
			if voxel_mgr.voxel_mode:
				_append_chat("System: Voxel mode enabled (LMB place, RMB break)")
			else:
				_append_chat("System: Voxel mode disabled")
	# Voxel input handling
	elif voxel_mgr and voxel_mgr.voxel_mode and event is InputEventMouseButton:
		voxel_mgr.handle_voxel_input(event)


func _fetch_regions() -> void:
	session_flow.fetch_regions()


func _join_world() -> void:
	session_flow.join_world()


func _load_region_scene(region_id: String) -> void:
	await session_flow.load_region_scene(region_id)


func _load_region_objects(region_id: String) -> void:
	await session_flow.load_region_objects(region_id)


func _connect_websocket() -> void:
	session_flow.connect_websocket()


func _poll_websocket() -> void:
	session_flow.poll_websocket()


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
