class_name VrManager
extends RefCounted

## Archived experimental module.
##
## Handles XR initialization, hand tracking, teleport locomotion, comfort
## vignette, VR UI panels, spatial audio integration, and VR build mode.
##
## Integration notes for main.gd:
##   var vr_manager = VrManager.new()
##   vr_manager.init(self)
##   # In _process(delta): vr_manager.process(delta)
##   # In _input(event): vr_manager.handle_input(event)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const VR_SESSION_ENDPOINT := "/api/vr/session"
const VR_PREFERENCES_ENDPOINT := "/api/vr/preferences"
const VR_HAND_TRACKING_ENDPOINT := "/api/vr/hand-tracking"
const VR_BUILD_ENDPOINT := "/api/vr/build"
const VR_CALIBRATE_ENDPOINT := "/api/vr/calibrate"
const VR_SPATIAL_AUDIO_ENDPOINT := "/api/vr/spatial-audio/config"

const HAND_TRACKING_SEND_INTERVAL := 0.05
const TELEPORT_ARC_SEGMENTS := 20
const TELEPORT_ARC_GRAVITY := 9.8
const TELEPORT_ARC_VELOCITY := 8.0
const TELEPORT_MAX_DISTANCE := 10.0
const VIGNETTE_FADE_SPEED := 4.0
const COMFORT_VIGNETTE_THRESHOLD := 0.5
const SNAP_TURN_COOLDOWN := 0.3
const PERSONAL_SPACE_FADE_DISTANCE := 0.5
const VR_UI_PANEL_DISTANCE := 1.2
const VR_UI_PANEL_SCALE := 0.001
const BUILD_PREVIEW_OPACITY := 0.5

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var main = null

var xr_interface: XRInterface = null
var xr_active := false
var vr_session_id := ""
var vr_session_data: Dictionary = {}

# Controllers and cameras
var xr_origin: XROrigin3D = null
var xr_camera: XRCamera3D = null
var left_controller: XRController3D = null
var right_controller: XRController3D = null

# Hand tracking state
var left_hand_state: Dictionary = {}
var right_hand_state: Dictionary = {}
var head_state: Dictionary = {}
var hand_tracking_timer := 0.0

# Teleport locomotion
var teleport_active := false
var teleport_target := Vector3.ZERO
var teleport_valid := false
var teleport_arc_points: Array = []
var teleport_arc_mesh: MeshInstance3D = null
var teleport_target_marker: MeshInstance3D = null

# Comfort
var vignette_current := 0.0
var vignette_target := 0.0
var snap_turn_cooldown_timer := 0.0
var last_velocity := Vector3.ZERO
var smooth_velocity := Vector3.ZERO

# Preferences (synced with server)
var locomotion_mode := "teleport"
var turn_mode := "snap"
var snap_turn_degrees := 45.0
var smooth_turn_speed := 1.0
var vignette_enabled := true
var vignette_intensity := 0.6
var height_offset := 0.0
var seated_mode := false
var dominant_hand := "right"
var personal_space_bubble := true
var personal_space_radius := 1.0
var movement_speed := 1.0
var teleport_max_distance := 10.0
var show_floor_marker := true

# VR UI
var vr_ui_viewport: SubViewport = null
var vr_ui_panel: MeshInstance3D = null
var vr_ui_visible := false
var vr_menu_open := false

# VR Build mode
var vr_build_mode := false
var vr_build_preview: Node3D = null
var vr_build_asset := ""
var vr_grab_object_id := ""
var vr_grab_active := false
var vr_grab_hand := "right"
var vr_grab_offset := Transform3D.IDENTITY

# Calibration
var calibration_data: Dictionary = {}
var is_calibrating := false
var calibration_step := 0

# Spatial audio
var spatial_audio_config: Dictionary = {}
var audio_listener_node: AudioListener3D = null

# HTTP requests
var vr_session_request: HTTPRequest = null
var vr_preferences_request: HTTPRequest = null
var vr_hand_tracking_request: HTTPRequest = null
var vr_build_request: HTTPRequest = null
var vr_calibrate_request: HTTPRequest = null

# Vignette rendering
var vignette_material: ShaderMaterial = null
var vignette_mesh: MeshInstance3D = null

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func init(main_node) -> void:
	main = main_node
	_create_http_nodes()
	_init_default_hand_states()

func _create_http_nodes() -> void:
	vr_session_request = HTTPRequest.new()
	vr_session_request.connect("request_completed", _on_vr_session_response)
	main.add_child(vr_session_request)

	vr_preferences_request = HTTPRequest.new()
	vr_preferences_request.connect("request_completed", _on_vr_preferences_response)
	main.add_child(vr_preferences_request)

	vr_hand_tracking_request = HTTPRequest.new()
	vr_hand_tracking_request.connect("request_completed", _on_vr_hand_tracking_response)
	main.add_child(vr_hand_tracking_request)

	vr_build_request = HTTPRequest.new()
	vr_build_request.connect("request_completed", _on_vr_build_response)
	main.add_child(vr_build_request)

	vr_calibrate_request = HTTPRequest.new()
	vr_calibrate_request.connect("request_completed", _on_vr_calibrate_response)
	main.add_child(vr_calibrate_request)

func _init_default_hand_states() -> void:
	var default_fingers = {
		"thumb": 0.0, "index": 0.0, "middle": 0.0, "ring": 0.0, "pinky": 0.0
	}
	left_hand_state = {
		"position": {"x": -0.2, "y": 1.0, "z": -0.3},
		"rotation": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		"fingers": default_fingers.duplicate(),
		"gesture": "none",
		"pinchStrength": 0.0,
		"gripStrength": 0.0,
	}
	right_hand_state = {
		"position": {"x": 0.2, "y": 1.0, "z": -0.3},
		"rotation": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		"fingers": default_fingers.duplicate(),
		"gesture": "none",
		"pinchStrength": 0.0,
		"gripStrength": 0.0,
	}
	head_state = {
		"position": {"x": 0.0, "y": 1.6, "z": 0.0},
		"rotation": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
	}

# ---------------------------------------------------------------------------
# XR Initialization
# ---------------------------------------------------------------------------

func start_vr() -> bool:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		push_warning("VrManager: OpenXR interface not found, trying mobile VR")
		xr_interface = XRServer.find_interface("WebXR")
	if xr_interface == null:
		push_error("VrManager: No XR interface available")
		return false

	if not xr_interface.is_initialized():
		if not xr_interface.initialize():
			push_error("VrManager: Failed to initialize XR interface")
			return false

	# Configure viewport for VR
	var vp = main.get_viewport()
	vp.use_xr = true

	# Create XR origin and camera hierarchy
	_setup_xr_nodes()

	xr_active = true
	_create_teleport_visuals()
	_create_vignette_overlay()
	_create_vr_ui_panel()
	_setup_spatial_audio()

	# Notify server about VR session
	_send_vr_session_init()

	return true

func stop_vr() -> void:
	if not xr_active:
		return

	xr_active = false
	var vp = main.get_viewport()
	vp.use_xr = false

	_cleanup_xr_nodes()
	_cleanup_teleport_visuals()
	_cleanup_vignette_overlay()
	_cleanup_vr_ui_panel()
	_cleanup_spatial_audio()

	# Notify server
	_send_vr_session_end()
	vr_session_id = ""

func is_vr_active() -> bool:
	return xr_active

func _setup_xr_nodes() -> void:
	xr_origin = XROrigin3D.new()
	xr_origin.name = "XROrigin"
	main.add_child(xr_origin)

	xr_camera = XRCamera3D.new()
	xr_camera.name = "XRCamera"
	xr_origin.add_child(xr_camera)

	left_controller = XRController3D.new()
	left_controller.name = "LeftController"
	left_controller.tracker = "left_hand"
	xr_origin.add_child(left_controller)

	right_controller = XRController3D.new()
	right_controller.name = "RightController"
	right_controller.tracker = "right_hand"
	xr_origin.add_child(right_controller)

	# Connect controller signals
	left_controller.connect("button_pressed", _on_left_button_pressed)
	left_controller.connect("button_released", _on_left_button_released)
	right_controller.connect("button_pressed", _on_right_button_pressed)
	right_controller.connect("button_released", _on_right_button_released)

	# Apply height offset
	if seated_mode:
		xr_origin.position.y = height_offset

func _cleanup_xr_nodes() -> void:
	if xr_origin and is_instance_valid(xr_origin):
		xr_origin.queue_free()
		xr_origin = null
	xr_camera = null
	left_controller = null
	right_controller = null

# ---------------------------------------------------------------------------
# Process loop — call from main._process(delta)
# ---------------------------------------------------------------------------

func process(delta: float) -> void:
	if not xr_active:
		return

	_update_head_and_hand_states()
	_process_hand_tracking_send(delta)
	_process_locomotion(delta)
	_process_snap_turn(delta)
	_process_vignette(delta)
	_process_personal_space()
	_process_vr_build_mode()
	_process_spatial_audio()

# ---------------------------------------------------------------------------
# Input handling — call from main._input(event)
# ---------------------------------------------------------------------------

func handle_input(_event: InputEvent) -> void:
	if not xr_active:
		return
	# VR input is handled via controller signals, not InputEvent

# ---------------------------------------------------------------------------
# Controller button callbacks
# ---------------------------------------------------------------------------

func _on_left_button_pressed(button_name: String) -> void:
	match button_name:
		"trigger_click":
			if teleport_active:
				_execute_teleport()
			elif vr_build_mode:
				_vr_build_confirm("left")
		"grip_click":
			_start_grab("left")
		"primary_click":
			# Thumbstick click — toggle VR menu
			_toggle_vr_menu()
		"ax_button":
			# A/X button — toggle build mode
			_toggle_vr_build_mode()
		"by_button":
			# B/Y button — toggle teleport mode
			_toggle_teleport_mode()

func _on_left_button_released(button_name: String) -> void:
	match button_name:
		"grip_click":
			_end_grab("left")
		"trigger_click":
			if teleport_active and not vr_build_mode:
				teleport_active = false

func _on_right_button_pressed(button_name: String) -> void:
	match button_name:
		"trigger_click":
			if vr_build_mode:
				_vr_build_confirm("right")
			else:
				_start_interaction("right", "point")
		"grip_click":
			_start_grab("right")
		"primary_click":
			# Thumbstick click — recenter view
			_recenter_view()
		"ax_button":
			_toggle_vr_build_mode()
		"by_button":
			_toggle_vr_menu()

func _on_right_button_released(button_name: String) -> void:
	match button_name:
		"grip_click":
			_end_grab("right")

# ---------------------------------------------------------------------------
# Head & Hand State Updates
# ---------------------------------------------------------------------------

func _update_head_and_hand_states() -> void:
	if xr_camera == null or not is_instance_valid(xr_camera):
		return

	# Head state
	var cam_pos = xr_camera.global_position
	var cam_quat = xr_camera.global_transform.basis.get_rotation_quaternion()
	head_state = {
		"position": {"x": cam_pos.x, "y": cam_pos.y, "z": cam_pos.z},
		"rotation": {"x": cam_quat.x, "y": cam_quat.y, "z": cam_quat.z, "w": cam_quat.w},
	}

	# Left hand
	if left_controller and is_instance_valid(left_controller):
		var lpos = left_controller.global_position
		var lquat = left_controller.global_transform.basis.get_rotation_quaternion()
		left_hand_state["position"] = {"x": lpos.x, "y": lpos.y, "z": lpos.z}
		left_hand_state["rotation"] = {"x": lquat.x, "y": lquat.y, "z": lquat.z, "w": lquat.w}
		_update_hand_fingers(left_controller, left_hand_state)

	# Right hand
	if right_controller and is_instance_valid(right_controller):
		var rpos = right_controller.global_position
		var rquat = right_controller.global_transform.basis.get_rotation_quaternion()
		right_hand_state["position"] = {"x": rpos.x, "y": rpos.y, "z": rpos.z}
		right_hand_state["rotation"] = {"x": rquat.x, "y": rquat.y, "z": rquat.z, "w": rquat.w}
		_update_hand_fingers(right_controller, right_hand_state)

func _update_hand_fingers(controller: XRController3D, hand_state: Dictionary) -> void:
	# Read analog inputs for finger curl estimation
	var trigger_val = controller.get_float("trigger")
	var grip_val = controller.get_float("grip")

	var fingers = hand_state.get("fingers", {})
	fingers["index"] = trigger_val
	fingers["middle"] = grip_val
	fingers["ring"] = grip_val * 0.9
	fingers["pinky"] = grip_val * 0.8
	fingers["thumb"] = maxf(trigger_val * 0.3, grip_val * 0.4)
	hand_state["fingers"] = fingers
	hand_state["pinchStrength"] = trigger_val
	hand_state["gripStrength"] = grip_val

# ---------------------------------------------------------------------------
# Hand Tracking Network Sync
# ---------------------------------------------------------------------------

func _process_hand_tracking_send(delta: float) -> void:
	hand_tracking_timer += delta
	if hand_tracking_timer < HAND_TRACKING_SEND_INTERVAL:
		return
	hand_tracking_timer = 0.0
	_send_hand_tracking_data()

func _send_hand_tracking_data() -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		return

	var base_url = main.backend_url_input.text.rstrip("/")
	var url = base_url + VR_HAND_TRACKING_ENDPOINT

	var body = JSON.stringify({
		"token": token,
		"headState": head_state,
		"leftHand": left_hand_state,
		"rightHand": right_hand_state,
	})

	var headers = ["Content-Type: application/json"]
	vr_hand_tracking_request.request(url, headers, HTTPClient.METHOD_POST, body)

# ---------------------------------------------------------------------------
# Teleport Locomotion
# ---------------------------------------------------------------------------

func _toggle_teleport_mode() -> void:
	if locomotion_mode == "smooth":
		return
	teleport_active = not teleport_active
	teleport_valid = false
	if teleport_arc_mesh:
		teleport_arc_mesh.visible = teleport_active
	if teleport_target_marker:
		teleport_target_marker.visible = false

func _process_locomotion(delta: float) -> void:
	if locomotion_mode == "teleport" or locomotion_mode == "hybrid":
		_process_teleport_aim()
	if locomotion_mode == "smooth" or locomotion_mode == "hybrid":
		_process_smooth_locomotion(delta)

func _process_teleport_aim() -> void:
	if not teleport_active:
		return
	if left_controller == null or not is_instance_valid(left_controller):
		return

	var origin_pos = left_controller.global_position
	var forward = -left_controller.global_transform.basis.z
	teleport_arc_points.clear()
	teleport_valid = false

	var pos = origin_pos
	var vel = forward * TELEPORT_ARC_VELOCITY
	var step = 0.05

	for i in range(TELEPORT_ARC_SEGMENTS):
		teleport_arc_points.append(pos)
		vel.y -= TELEPORT_ARC_GRAVITY * step
		var next_pos = pos + vel * step

		# Raycast to check for ground hit
		var space_state = main.get_world_3d().direct_space_state
		if space_state:
			var query = PhysicsRayQueryParameters3D.create(pos, next_pos)
			var result = space_state.intersect_ray(query)
			if result.size() > 0:
				var hit_point = result["position"]
				var dist = origin_pos.distance_to(hit_point)
				if dist <= teleport_max_distance and hit_point.y >= -0.5:
					teleport_target = hit_point
					teleport_valid = true
					teleport_arc_points.append(hit_point)
					break

		pos = next_pos

	_update_teleport_visuals()

func _execute_teleport() -> void:
	if not teleport_valid:
		return
	if xr_origin == null or not is_instance_valid(xr_origin):
		return

	# Apply comfort vignette during teleport
	if vignette_enabled:
		vignette_target = vignette_intensity

	# Move origin to teleport target, adjusting for camera offset
	var cam_offset = xr_camera.global_position - xr_origin.global_position
	cam_offset.y = 0.0
	xr_origin.global_position = teleport_target - cam_offset

	teleport_active = false
	teleport_valid = false

	if teleport_arc_mesh:
		teleport_arc_mesh.visible = false
	if teleport_target_marker:
		teleport_target_marker.visible = false

	# Trigger haptic feedback
	_trigger_haptic("left", 0.3, 0.1)

func _process_smooth_locomotion(delta: float) -> void:
	if xr_origin == null or not is_instance_valid(xr_origin):
		return
	if left_controller == null or not is_instance_valid(left_controller):
		return

	var stick = Vector2.ZERO
	stick.x = left_controller.get_float("primary_x")
	stick.y = left_controller.get_float("primary_y")

	if stick.length() < 0.15:
		smooth_velocity = smooth_velocity.lerp(Vector3.ZERO, delta * 5.0)
		return

	# Movement relative to head direction
	var cam_basis = xr_camera.global_transform.basis if xr_camera else Basis.IDENTITY
	var forward = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right_dir = cam_basis.x
	right_dir.y = 0.0
	right_dir = right_dir.normalized()

	var move_dir = (forward * -stick.y + right_dir * stick.x).normalized()
	smooth_velocity = move_dir * movement_speed * 3.0

	# Apply comfort vignette when moving
	if vignette_enabled and smooth_velocity.length() > COMFORT_VIGNETTE_THRESHOLD:
		vignette_target = vignette_intensity * clampf(smooth_velocity.length() / 3.0, 0.0, 1.0)
	else:
		vignette_target = 0.0

	xr_origin.global_position += smooth_velocity * delta

# ---------------------------------------------------------------------------
# Snap Turn / Smooth Turn
# ---------------------------------------------------------------------------

func _process_snap_turn(delta: float) -> void:
	if right_controller == null or not is_instance_valid(right_controller):
		return

	snap_turn_cooldown_timer = maxf(0.0, snap_turn_cooldown_timer - delta)

	var stick_x = right_controller.get_float("primary_x")

	if turn_mode == "snap":
		if absf(stick_x) > 0.7 and snap_turn_cooldown_timer <= 0.0:
			var turn_dir = 1.0 if stick_x > 0 else -1.0
			_apply_snap_turn(turn_dir * snap_turn_degrees)
			snap_turn_cooldown_timer = SNAP_TURN_COOLDOWN
	elif turn_mode == "smooth":
		if absf(stick_x) > 0.15:
			var turn_amount = stick_x * smooth_turn_speed * 90.0 * delta
			_apply_smooth_turn(turn_amount)
			if vignette_enabled:
				vignette_target = vignette_intensity * clampf(absf(stick_x), 0.0, 1.0)

func _apply_snap_turn(degrees: float) -> void:
	if xr_origin == null or not is_instance_valid(xr_origin):
		return

	# Rotate around the camera position so the user stays centered
	var cam_pos = xr_camera.global_position if xr_camera else xr_origin.global_position
	var offset = xr_origin.global_position - cam_pos
	offset = offset.rotated(Vector3.UP, deg_to_rad(degrees))
	xr_origin.global_position = cam_pos + offset
	xr_origin.rotate_y(deg_to_rad(degrees))

	# Brief vignette flash for comfort
	if vignette_enabled:
		vignette_current = vignette_intensity

	_trigger_haptic("right", 0.15, 0.05)

func _apply_smooth_turn(degrees: float) -> void:
	if xr_origin == null or not is_instance_valid(xr_origin):
		return
	var cam_pos = xr_camera.global_position if xr_camera else xr_origin.global_position
	var offset = xr_origin.global_position - cam_pos
	offset = offset.rotated(Vector3.UP, deg_to_rad(degrees))
	xr_origin.global_position = cam_pos + offset
	xr_origin.rotate_y(deg_to_rad(degrees))

# ---------------------------------------------------------------------------
# Comfort Vignette
# ---------------------------------------------------------------------------

func _process_vignette(delta: float) -> void:
	if not vignette_enabled:
		vignette_current = 0.0
		_apply_vignette_visual()
		return

	# Smoothly interpolate vignette
	vignette_current = lerpf(vignette_current, vignette_target, VIGNETTE_FADE_SPEED * delta)

	# Decay target
	if vignette_target > 0.0 and smooth_velocity.length() < 0.1:
		vignette_target = lerpf(vignette_target, 0.0, delta * 2.0)

	_apply_vignette_visual()

func _apply_vignette_visual() -> void:
	if vignette_material:
		vignette_material.set_shader_parameter("intensity", vignette_current)

func _create_vignette_overlay() -> void:
	# Create a quad in front of the camera with a radial vignette shader
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_centered = UV * 2.0 - 1.0;
	float dist = length(uv_centered);
	float vignette = smoothstep(0.4, 1.2, dist) * intensity;
	ALBEDO = vec3(0.0);
	ALPHA = vignette;
}
"""
	vignette_material = ShaderMaterial.new()
	vignette_material.shader = shader
	vignette_material.set_shader_parameter("intensity", 0.0)

	var mesh = QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)

	vignette_mesh = MeshInstance3D.new()
	vignette_mesh.mesh = mesh
	vignette_mesh.material_override = vignette_material
	vignette_mesh.name = "VRVignette"
	vignette_mesh.position = Vector3(0, 0, -0.5)
	vignette_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if xr_camera and is_instance_valid(xr_camera):
		xr_camera.add_child(vignette_mesh)

func _cleanup_vignette_overlay() -> void:
	if vignette_mesh and is_instance_valid(vignette_mesh):
		vignette_mesh.queue_free()
		vignette_mesh = null
	vignette_material = null

# ---------------------------------------------------------------------------
# Teleport Visuals
# ---------------------------------------------------------------------------

func _create_teleport_visuals() -> void:
	# Arc line
	teleport_arc_mesh = MeshInstance3D.new()
	teleport_arc_mesh.name = "TeleportArc"
	teleport_arc_mesh.visible = false
	teleport_arc_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(teleport_arc_mesh)

	# Target marker
	var marker_mesh = CylinderMesh.new()
	marker_mesh.top_radius = 0.3
	marker_mesh.bottom_radius = 0.3
	marker_mesh.height = 0.02

	var marker_mat = StandardMaterial3D.new()
	marker_mat.albedo_color = Color(0.2, 0.7, 1.0, 0.7)
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(0.2, 0.7, 1.0)
	marker_mat.emission_energy_multiplier = 2.0

	teleport_target_marker = MeshInstance3D.new()
	teleport_target_marker.mesh = marker_mesh
	teleport_target_marker.material_override = marker_mat
	teleport_target_marker.name = "TeleportMarker"
	teleport_target_marker.visible = false
	teleport_target_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(teleport_target_marker)

func _update_teleport_visuals() -> void:
	if not teleport_arc_mesh or teleport_arc_points.size() < 2:
		return

	# Build immediate mesh for the arc line
	var imm = ImmediateMesh.new()
	imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	var color = Color(0.2, 0.7, 1.0) if teleport_valid else Color(1.0, 0.3, 0.3)
	for point in teleport_arc_points:
		imm.surface_set_color(color)
		imm.surface_add_vertex(point)

	imm.surface_end()

	teleport_arc_mesh.mesh = imm
	teleport_arc_mesh.visible = true

	if teleport_target_marker:
		teleport_target_marker.visible = teleport_valid and show_floor_marker
		if teleport_valid:
			teleport_target_marker.global_position = teleport_target + Vector3(0, 0.01, 0)

func _cleanup_teleport_visuals() -> void:
	if teleport_arc_mesh and is_instance_valid(teleport_arc_mesh):
		teleport_arc_mesh.queue_free()
		teleport_arc_mesh = null
	if teleport_target_marker and is_instance_valid(teleport_target_marker):
		teleport_target_marker.queue_free()
		teleport_target_marker = null

# ---------------------------------------------------------------------------
# VR UI Panel
# ---------------------------------------------------------------------------

func _create_vr_ui_panel() -> void:
	# SubViewport for rendering the 2D UI in VR space
	vr_ui_viewport = SubViewport.new()
	vr_ui_viewport.size = Vector2i(1024, 768)
	vr_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vr_ui_viewport.transparent_bg = true
	vr_ui_viewport.name = "VRUIViewport"
	main.add_child(vr_ui_viewport)

	# Create a panel mesh to display the viewport texture
	var panel_mesh = QuadMesh.new()
	panel_mesh.size = Vector2(1.0, 0.75)

	var panel_mat = StandardMaterial3D.new()
	panel_mat.albedo_texture = vr_ui_viewport.get_texture()
	panel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_mat.emission_enabled = true
	panel_mat.emission_energy_multiplier = 0.5
	panel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	vr_ui_panel = MeshInstance3D.new()
	vr_ui_panel.mesh = panel_mesh
	vr_ui_panel.material_override = panel_mat
	vr_ui_panel.name = "VRUIPanel"
	vr_ui_panel.visible = false
	vr_ui_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(vr_ui_panel)

func _toggle_vr_menu() -> void:
	vr_menu_open = not vr_menu_open

	if vr_ui_panel and is_instance_valid(vr_ui_panel):
		vr_ui_panel.visible = vr_menu_open

		if vr_menu_open and xr_camera and is_instance_valid(xr_camera):
			# Position the panel in front of the user
			var cam_t = xr_camera.global_transform
			var panel_pos = cam_t.origin - cam_t.basis.z * VR_UI_PANEL_DISTANCE
			panel_pos.y = cam_t.origin.y - 0.2
			vr_ui_panel.global_position = panel_pos
			vr_ui_panel.look_at(cam_t.origin, Vector3.UP)

	_trigger_haptic("left", 0.15, 0.05)

func _cleanup_vr_ui_panel() -> void:
	if vr_ui_panel and is_instance_valid(vr_ui_panel):
		vr_ui_panel.queue_free()
		vr_ui_panel = null
	if vr_ui_viewport and is_instance_valid(vr_ui_viewport):
		vr_ui_viewport.queue_free()
		vr_ui_viewport = null

# ---------------------------------------------------------------------------
# Personal Space Bubble
# ---------------------------------------------------------------------------

func _process_personal_space() -> void:
	if not personal_space_bubble or not xr_active:
		return
	if xr_camera == null or not is_instance_valid(xr_camera):
		return

	var my_pos = xr_camera.global_position
	var avatar_states = main.avatar_states

	for avatar_id in avatar_states:
		var state = avatar_states[avatar_id]
		if not state is Dictionary:
			continue
		var other_pos = Vector3(
			state.get("x", 0.0),
			state.get("y", 0.0),
			state.get("z", 0.0)
		)
		var dist = my_pos.distance_to(other_pos)

		if dist < personal_space_radius:
			# Fade out other avatar as they get closer
			var fade_start = personal_space_radius
			var fade_end = personal_space_radius - PERSONAL_SPACE_FADE_DISTANCE
			var alpha = clampf((dist - fade_end) / (fade_start - fade_end), 0.1, 1.0)

			var avatar_node = main.avatar_nodes.get(avatar_id)
			if avatar_node and is_instance_valid(avatar_node):
				_set_node_transparency(avatar_node, alpha)
		else:
			var avatar_node = main.avatar_nodes.get(avatar_id)
			if avatar_node and is_instance_valid(avatar_node):
				_set_node_transparency(avatar_node, 1.0)

func _set_node_transparency(node: Node3D, alpha: float) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat = child.get_active_material(0)
			if mat is StandardMaterial3D:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.albedo_color.a = alpha

# ---------------------------------------------------------------------------
# VR Build Mode
# ---------------------------------------------------------------------------

func _toggle_vr_build_mode() -> void:
	vr_build_mode = not vr_build_mode
	if not vr_build_mode:
		_cleanup_build_preview()
	_trigger_haptic("left", 0.2, 0.05)

func _process_vr_build_mode() -> void:
	if not vr_build_mode:
		return

	var hand_ctrl = right_controller if dominant_hand == "right" else left_controller
	if hand_ctrl == null or not is_instance_valid(hand_ctrl):
		return

	# Update build preview position to follow the dominant hand
	if vr_build_preview and is_instance_valid(vr_build_preview):
		var hand_t = hand_ctrl.global_transform
		vr_build_preview.global_position = hand_t.origin - hand_t.basis.z * 0.5
		vr_build_preview.global_rotation = hand_t.basis.get_euler()

func _vr_build_confirm(hand: String) -> void:
	if not vr_build_mode:
		return

	var hand_ctrl = right_controller if hand == "right" else left_controller
	if hand_ctrl == null or not is_instance_valid(hand_ctrl):
		return

	var hand_t = hand_ctrl.global_transform
	var place_pos = hand_t.origin - hand_t.basis.z * 0.5
	var quat = hand_t.basis.get_rotation_quaternion()

	_send_vr_build_action("place", hand, null, vr_build_asset, place_pos, quat, 1.0)
	_trigger_haptic(hand, 0.4, 0.1)

func _cleanup_build_preview() -> void:
	if vr_build_preview and is_instance_valid(vr_build_preview):
		vr_build_preview.queue_free()
		vr_build_preview = null

# ---------------------------------------------------------------------------
# Grab Interaction
# ---------------------------------------------------------------------------

func _start_grab(hand: String) -> void:
	var ctrl = left_controller if hand == "left" else right_controller
	if ctrl == null or not is_instance_valid(ctrl):
		return

	# Raycast to find an object to grab
	var origin_pos = ctrl.global_position
	var forward = -ctrl.global_transform.basis.z
	var end_pos = origin_pos + forward * 2.0

	var space_state = main.get_world_3d().direct_space_state
	if not space_state:
		return

	var query = PhysicsRayQueryParameters3D.create(origin_pos, end_pos)
	var result = space_state.intersect_ray(query)
	if result.size() > 0:
		var collider = result["collider"]
		if collider and collider.has_meta("object_id"):
			vr_grab_object_id = collider.get_meta("object_id")
			vr_grab_active = true
			vr_grab_hand = hand
			vr_grab_offset = ctrl.global_transform.inverse() * collider.global_transform
			_trigger_haptic(hand, 0.3, 0.05)

func _end_grab(hand: String) -> void:
	if vr_grab_active and vr_grab_hand == hand:
		if not vr_grab_object_id.is_empty():
			var ctrl = left_controller if hand == "left" else right_controller
			if ctrl and is_instance_valid(ctrl):
				var final_t = ctrl.global_transform * vr_grab_offset
				var pos = final_t.origin
				var quat = final_t.basis.get_rotation_quaternion()
				_send_vr_build_action("move", hand, vr_grab_object_id, null, pos, quat, 1.0)

		vr_grab_active = false
		vr_grab_object_id = ""
		_trigger_haptic(hand, 0.15, 0.05)

func _start_interaction(hand: String, interaction_type: String) -> void:
	var ctrl = left_controller if hand == "left" else right_controller
	if ctrl == null or not is_instance_valid(ctrl):
		return
	_trigger_haptic(hand, 0.1, 0.03)

# ---------------------------------------------------------------------------
# Recenter
# ---------------------------------------------------------------------------

func _recenter_view() -> void:
	if xr_interface:
		xr_interface.center_on_hmd(XRInterface.RESET_FULL_ROTATION, true)
	_trigger_haptic("right", 0.2, 0.05)

# ---------------------------------------------------------------------------
# Spatial Audio Integration
# ---------------------------------------------------------------------------

func _setup_spatial_audio() -> void:
	if xr_camera and is_instance_valid(xr_camera):
		audio_listener_node = AudioListener3D.new()
		audio_listener_node.name = "VRAudioListener"
		xr_camera.add_child(audio_listener_node)
		audio_listener_node.make_current()

func _process_spatial_audio() -> void:
	# The AudioListener3D attached to the XR camera automatically handles
	# spatial audio positioning. We just keep it active and current.
	if audio_listener_node and is_instance_valid(audio_listener_node):
		if not audio_listener_node.is_current():
			audio_listener_node.make_current()

func _cleanup_spatial_audio() -> void:
	if audio_listener_node and is_instance_valid(audio_listener_node):
		audio_listener_node.queue_free()
		audio_listener_node = null

# ---------------------------------------------------------------------------
# Haptic Feedback
# ---------------------------------------------------------------------------

func _trigger_haptic(hand: String, intensity: float, duration: float) -> void:
	var ctrl = left_controller if hand == "left" else right_controller
	if ctrl and is_instance_valid(ctrl):
		ctrl.trigger_haptic_pulse("haptic", 0.0, intensity, duration, 0.0)

# ---------------------------------------------------------------------------
# Calibration
# ---------------------------------------------------------------------------

func start_calibration() -> void:
	is_calibrating = true
	calibration_step = 0

func process_calibration_step() -> Dictionary:
	if not is_calibrating:
		return {"done": true}

	match calibration_step:
		0:
			# Step 1: Stand straight, record floor and eye height
			var floor_height = 0.0
			var eye_height = 1.6
			if xr_camera and is_instance_valid(xr_camera):
				eye_height = xr_camera.global_position.y
				if xr_origin and is_instance_valid(xr_origin):
					floor_height = xr_origin.global_position.y
			calibration_data["floorHeight"] = floor_height
			calibration_data["eyeHeight"] = eye_height
			calibration_step = 1
			return {"step": 1, "instruction": "Stand straight with arms at your sides. Press trigger to continue.", "done": false}
		1:
			# Step 2: T-pose for arm span
			var arm_span = 1.5
			if left_controller and right_controller and is_instance_valid(left_controller) and is_instance_valid(right_controller):
				arm_span = left_controller.global_position.distance_to(right_controller.global_position)
			calibration_data["armSpan"] = arm_span
			calibration_step = 2
			return {"step": 2, "instruction": "Extend arms to a T-pose. Press trigger to continue.", "done": false}
		2:
			# Step 3: Record hand offsets
			var left_offset = {"x": 0.0, "y": 0.0, "z": 0.0}
			var right_offset = {"x": 0.0, "y": 0.0, "z": 0.0}
			if left_controller and is_instance_valid(left_controller) and xr_camera and is_instance_valid(xr_camera):
				var offset = left_controller.global_position - xr_camera.global_position
				left_offset = {"x": offset.x, "y": offset.y, "z": offset.z}
			if right_controller and is_instance_valid(right_controller) and xr_camera and is_instance_valid(xr_camera):
				var offset = right_controller.global_position - xr_camera.global_position
				right_offset = {"x": offset.x, "y": offset.y, "z": offset.z}
			calibration_data["handOffsetLeft"] = left_offset
			calibration_data["handOffsetRight"] = right_offset
			calibration_step = 3

			# Send calibration to server
			_send_calibration_data()
			is_calibrating = false
			return {"step": 3, "instruction": "Calibration complete!", "done": true}
		_:
			is_calibrating = false
			return {"done": true}

# ---------------------------------------------------------------------------
# Network: VR Session
# ---------------------------------------------------------------------------

func _send_vr_session_init() -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		return

	var base_url = main.backend_url_input.text.rstrip("/")
	var url = base_url + VR_SESSION_ENDPOINT

	var device_name = "Unknown"
	var device_type = "unknown"
	if xr_interface:
		device_name = xr_interface.get_name()
		if "quest 3" in device_name.to_lower():
			device_type = "meta_quest_3"
		elif "quest pro" in device_name.to_lower():
			device_type = "meta_quest_pro"
		elif "quest" in device_name.to_lower():
			device_type = "meta_quest_2"
		else:
			device_type = "generic_6dof"

	var body = JSON.stringify({
		"token": token,
		"deviceType": device_type,
		"deviceName": device_name,
		"ipd": 63.0,
		"refreshRate": 72.0,
	})

	var headers = ["Content-Type: application/json"]
	vr_session_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _send_vr_session_end() -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		return

	var base_url = main.backend_url_input.text.rstrip("/")
	var url = base_url + VR_SESSION_ENDPOINT

	var body = JSON.stringify({"token": token})
	var headers = ["Content-Type: application/json"]
	vr_session_request.request(url, headers, HTTPClient.METHOD_DELETE, body)

func _on_vr_session_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("VrManager: VR session request failed with code %d" % response_code)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary and parsed.has("vrSession"):
		vr_session_data = parsed["vrSession"]
		vr_session_id = vr_session_data.get("id", "")
		_apply_preferences_from_server(vr_session_data.get("preferences", {}))

# ---------------------------------------------------------------------------
# Network: Preferences
# ---------------------------------------------------------------------------

func save_preferences_to_server() -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		return

	var base_url = main.backend_url_input.text.rstrip("/")
	var url = base_url + VR_PREFERENCES_ENDPOINT

	var body = JSON.stringify({
		"token": token,
		"locomotionMode": locomotion_mode,
		"turnMode": turn_mode,
		"snapTurnDegrees": snap_turn_degrees,
		"smoothTurnSpeed": smooth_turn_speed,
		"vignetteEnabled": vignette_enabled,
		"vignetteIntensity": vignette_intensity,
		"heightOffset": height_offset,
		"seatedMode": seated_mode,
		"dominantHand": dominant_hand,
		"personalSpaceBubble": personal_space_bubble,
		"personalSpaceRadius": personal_space_radius,
		"movementSpeed": movement_speed,
		"teleportMaxDistance": teleport_max_distance,
		"showFloorMarker": show_floor_marker,
	})

	var headers = ["Content-Type: application/json"]
	vr_preferences_request.request(url, headers, HTTPClient.METHOD_PATCH, body)

func _on_vr_preferences_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("VrManager: preferences save failed with code %d" % response_code)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary and parsed.has("preferences"):
		_apply_preferences_from_server(parsed["preferences"])

func _apply_preferences_from_server(prefs: Dictionary) -> void:
	if prefs.is_empty():
		return
	locomotion_mode = prefs.get("locomotionMode", locomotion_mode)
	turn_mode = prefs.get("turnMode", turn_mode)
	snap_turn_degrees = prefs.get("snapTurnDegrees", snap_turn_degrees)
	smooth_turn_speed = prefs.get("smoothTurnSpeed", smooth_turn_speed)
	vignette_enabled = prefs.get("vignetteEnabled", vignette_enabled)
	vignette_intensity = prefs.get("vignetteIntensity", vignette_intensity)
	height_offset = prefs.get("heightOffset", height_offset)
	seated_mode = prefs.get("seatedMode", seated_mode)
	dominant_hand = prefs.get("dominantHand", dominant_hand)
	personal_space_bubble = prefs.get("personalSpaceBubble", personal_space_bubble)
	personal_space_radius = prefs.get("personalSpaceRadius", personal_space_radius)
	movement_speed = prefs.get("movementSpeed", movement_speed)
	teleport_max_distance = prefs.get("teleportMaxDistance", teleport_max_distance)
	show_floor_marker = prefs.get("showFloorMarker", show_floor_marker)

	# Apply seated mode offset
	if seated_mode and xr_origin and is_instance_valid(xr_origin):
		xr_origin.position.y = height_offset

# ---------------------------------------------------------------------------
# Network: Hand Tracking
# ---------------------------------------------------------------------------

func _on_vr_hand_tracking_response(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	# Hand tracking responses are fire-and-forget for performance
	pass

# ---------------------------------------------------------------------------
# Network: Build Actions
# ---------------------------------------------------------------------------

func _send_vr_build_action(action_type: String, hand: String, object_id, asset, position: Vector3, rotation: Quaternion, scale_val: float) -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		return

	var base_url = main.backend_url_input.text.rstrip("/")
	var url = base_url + VR_BUILD_ENDPOINT

	var payload = {
		"token": token,
		"actionType": action_type,
		"hand": hand,
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"rotation": {"x": rotation.x, "y": rotation.y, "z": rotation.z, "w": rotation.w},
		"scale": scale_val,
	}

	if object_id != null and not str(object_id).is_empty():
		payload["objectId"] = str(object_id)
	if asset != null and not str(asset).is_empty():
		payload["asset"] = str(asset)

	var body = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	vr_build_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_vr_build_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("VrManager: build action failed with code %d" % response_code)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary and parsed.has("haptics"):
		var haptics = parsed["haptics"]
		if haptics is Array:
			for h in haptics:
				if h is Dictionary:
					_trigger_haptic(
						h.get("hand", "right"),
						h.get("intensity", 0.3),
						h.get("duration", 0.1)
					)

# ---------------------------------------------------------------------------
# Network: Calibration
# ---------------------------------------------------------------------------

func _send_calibration_data() -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		return

	var base_url = main.backend_url_input.text.rstrip("/")
	var url = base_url + VR_CALIBRATE_ENDPOINT

	var body = JSON.stringify({
		"token": token,
		"floorHeight": calibration_data.get("floorHeight", 0.0),
		"eyeHeight": calibration_data.get("eyeHeight", 1.6),
		"armSpan": calibration_data.get("armSpan", 1.5),
		"handOffsetLeft": calibration_data.get("handOffsetLeft", {"x": 0, "y": 0, "z": 0}),
		"handOffsetRight": calibration_data.get("handOffsetRight", {"x": 0, "y": 0, "z": 0}),
	})

	var headers = ["Content-Type: application/json"]
	vr_calibrate_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_vr_calibrate_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("VrManager: calibration save failed with code %d" % response_code)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary and parsed.has("calibration"):
		calibration_data = parsed["calibration"]
