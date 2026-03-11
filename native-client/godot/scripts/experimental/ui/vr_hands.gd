class_name VrHands
extends RefCounted

## Archived experimental module.
##
## Manages hand model rendering, gesture recognition, grab/point/pinch
## detection, and haptic feedback triggers for VR hand tracking.
##
## Integration notes for main.gd:
##   var vr_hands = VrHands.new()
##   vr_hands.init(self)
##   # In _process(delta): vr_hands.process(delta)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const FINGER_LERP_SPEED := 12.0
const GESTURE_HOLD_TIME := 0.15
const GRAB_THRESHOLD := 0.7
const PINCH_THRESHOLD := 0.75
const POINT_THRESHOLD := 0.4
const FIST_THRESHOLD := 0.8
const HAND_MESH_SCALE := Vector3(0.02, 0.02, 0.02)

const HAPTIC_GRAB_INTENSITY := 0.4
const HAPTIC_GRAB_DURATION := 0.08
const HAPTIC_RELEASE_INTENSITY := 0.2
const HAPTIC_RELEASE_DURATION := 0.05
const HAPTIC_PINCH_INTENSITY := 0.25
const HAPTIC_PINCH_DURATION := 0.04
const HAPTIC_UI_INTENSITY := 0.15
const HAPTIC_UI_DURATION := 0.03
const HAPTIC_COLLISION_INTENSITY := 0.5
const HAPTIC_COLLISION_DURATION := 0.1

const HAND_COLOR_LEFT := Color(0.3, 0.5, 0.9, 0.85)
const HAND_COLOR_RIGHT := Color(0.9, 0.5, 0.3, 0.85)
const HAND_COLOR_GRAB := Color(0.2, 0.9, 0.3, 0.9)
const HAND_COLOR_POINT := Color(0.9, 0.9, 0.2, 0.9)
const HAND_COLOR_PINCH := Color(0.9, 0.2, 0.9, 0.9)

# Bone / finger joint names for skeletal hand models
const FINGER_NAMES := ["thumb", "index", "middle", "ring", "pinky"]
const JOINT_NAMES := ["metacarpal", "proximal", "intermediate", "distal", "tip"]

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

enum Gesture {
	NONE,
	OPEN_HAND,
	FIST,
	POINT,
	PINCH,
	THUMBS_UP,
	PEACE,
	GRAB,
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var main = null

# Hand nodes
var left_hand_root: Node3D = null
var right_hand_root: Node3D = null
var left_hand_mesh: MeshInstance3D = null
var right_hand_mesh: MeshInstance3D = null
var left_hand_material: StandardMaterial3D = null
var right_hand_material: StandardMaterial3D = null

# Finger curl targets and current (for smooth interpolation)
var left_finger_targets: Dictionary = {"thumb": 0.0, "index": 0.0, "middle": 0.0, "ring": 0.0, "pinky": 0.0}
var left_finger_current: Dictionary = {"thumb": 0.0, "index": 0.0, "middle": 0.0, "ring": 0.0, "pinky": 0.0}
var right_finger_targets: Dictionary = {"thumb": 0.0, "index": 0.0, "middle": 0.0, "ring": 0.0, "pinky": 0.0}
var right_finger_current: Dictionary = {"thumb": 0.0, "index": 0.0, "middle": 0.0, "ring": 0.0, "pinky": 0.0}

# Gesture state
var left_gesture: int = Gesture.NONE
var right_gesture: int = Gesture.NONE
var left_gesture_timer := 0.0
var right_gesture_timer := 0.0
var left_pending_gesture: int = Gesture.NONE
var right_pending_gesture: int = Gesture.NONE

# Grab state
var left_grab_active := false
var right_grab_active := false
var left_pinch_active := false
var right_pinch_active := false
var left_point_active := false
var right_point_active := false

# Grip / pinch analog values
var left_grip_strength := 0.0
var right_grip_strength := 0.0
var left_pinch_strength := 0.0
var right_pinch_strength := 0.0

# Finger joint nodes for skeleton-based hands
var left_finger_joints: Dictionary = {}
var right_finger_joints: Dictionary = {}

# Collision / physics for hand interaction
var left_hand_area: Area3D = null
var right_hand_area: Area3D = null
var left_overlapping_bodies: Array = []
var right_overlapping_bodies: Array = []

# Controller references (set from VrManager)
var left_controller: XRController3D = null
var right_controller: XRController3D = null

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func init(main_node) -> void:
	main = main_node

func setup_hands(left_ctrl: XRController3D, right_ctrl: XRController3D) -> void:
	left_controller = left_ctrl
	right_controller = right_ctrl
	_create_hand_models()
	_create_hand_collision_areas()

func cleanup() -> void:
	_destroy_hand_models()
	_destroy_hand_collision_areas()
	left_controller = null
	right_controller = null

# ---------------------------------------------------------------------------
# Hand Model Creation
# ---------------------------------------------------------------------------

func _create_hand_models() -> void:
	# Left hand
	left_hand_root = Node3D.new()
	left_hand_root.name = "LeftHandModel"

	left_hand_material = _create_hand_material(HAND_COLOR_LEFT)
	left_hand_mesh = _create_hand_mesh(left_hand_material)
	left_hand_root.add_child(left_hand_mesh)
	_create_finger_nodes(left_hand_root, true)

	if left_controller and is_instance_valid(left_controller):
		left_controller.add_child(left_hand_root)

	# Right hand
	right_hand_root = Node3D.new()
	right_hand_root.name = "RightHandModel"

	right_hand_material = _create_hand_material(HAND_COLOR_RIGHT)
	right_hand_mesh = _create_hand_mesh(right_hand_material)
	right_hand_root.add_child(right_hand_mesh)
	_create_finger_nodes(right_hand_root, false)

	if right_controller and is_instance_valid(right_controller):
		right_controller.add_child(right_hand_root)

func _create_hand_material(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	mat.roughness = 0.7
	mat.metallic = 0.1
	return mat

func _create_hand_mesh(material: StandardMaterial3D) -> MeshInstance3D:
	# Palm mesh — a flattened box representing the palm
	var palm_mesh = BoxMesh.new()
	palm_mesh.size = Vector3(0.08, 0.025, 0.1)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = palm_mesh
	mesh_instance.material_override = material
	mesh_instance.name = "Palm"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance

func _create_finger_nodes(hand_root: Node3D, is_left: bool) -> void:
	var finger_joints_dict = {}
	var hand_width = 0.08
	var finger_spacing = hand_width / 5.0

	for i in range(FINGER_NAMES.size()):
		var finger_name = FINGER_NAMES[i]
		var finger_root = Node3D.new()
		finger_root.name = finger_name

		# Position finger roots along the palm edge
		var x_offset = -hand_width / 2.0 + finger_spacing * (i + 0.5)
		if is_left:
			x_offset = -x_offset
		finger_root.position = Vector3(x_offset, 0.01, -0.05)

		# Create joint segments
		var joint_nodes = []
		var parent_node = finger_root
		var segment_length = 0.02 if finger_name == "thumb" else 0.018

		for j in range(3):  # 3 joints per finger
			var joint = Node3D.new()
			joint.name = "%s_joint_%d" % [finger_name, j]
			joint.position = Vector3(0, 0, -segment_length)
			parent_node.add_child(joint)

			# Visual segment
			var seg_mesh = CylinderMesh.new()
			seg_mesh.top_radius = 0.005
			seg_mesh.bottom_radius = 0.006
			seg_mesh.height = segment_length

			var seg_inst = MeshInstance3D.new()
			seg_inst.mesh = seg_mesh
			seg_inst.name = "segment"
			seg_inst.position = Vector3(0, 0, segment_length * 0.5)
			seg_inst.rotation_degrees = Vector3(90, 0, 0)
			seg_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			joint.add_child(seg_inst)

			# Fingertip sphere on last joint
			if j == 2:
				var tip_mesh = SphereMesh.new()
				tip_mesh.radius = 0.006
				tip_mesh.height = 0.012

				var tip_inst = MeshInstance3D.new()
				tip_inst.mesh = tip_mesh
				tip_inst.name = "tip"
				tip_inst.position = Vector3(0, 0, -0.005)
				tip_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				joint.add_child(tip_inst)

			joint_nodes.append(joint)
			parent_node = joint

		hand_root.add_child(finger_root)
		finger_joints_dict[finger_name] = joint_nodes

	if is_left:
		left_finger_joints = finger_joints_dict
	else:
		right_finger_joints = finger_joints_dict

func _destroy_hand_models() -> void:
	if left_hand_root and is_instance_valid(left_hand_root):
		left_hand_root.queue_free()
		left_hand_root = null
	if right_hand_root and is_instance_valid(right_hand_root):
		right_hand_root.queue_free()
		right_hand_root = null
	left_hand_mesh = null
	right_hand_mesh = null
	left_hand_material = null
	right_hand_material = null
	left_finger_joints = {}
	right_finger_joints = {}

# ---------------------------------------------------------------------------
# Hand Collision Areas
# ---------------------------------------------------------------------------

func _create_hand_collision_areas() -> void:
	left_hand_area = _create_collision_area("LeftHandArea")
	if left_controller and is_instance_valid(left_controller):
		left_controller.add_child(left_hand_area)
		left_hand_area.connect("body_entered", _on_left_hand_body_entered)
		left_hand_area.connect("body_exited", _on_left_hand_body_exited)

	right_hand_area = _create_collision_area("RightHandArea")
	if right_controller and is_instance_valid(right_controller):
		right_controller.add_child(right_hand_area)
		right_hand_area.connect("body_entered", _on_right_hand_body_entered)
		right_hand_area.connect("body_exited", _on_right_hand_body_exited)

func _create_collision_area(area_name: String) -> Area3D:
	var area = Area3D.new()
	area.name = area_name
	area.collision_layer = 0
	area.collision_mask = 1  # Detect world objects

	var shape = SphereShape3D.new()
	shape.radius = 0.05

	var collision = CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)

	return area

func _destroy_hand_collision_areas() -> void:
	if left_hand_area and is_instance_valid(left_hand_area):
		left_hand_area.queue_free()
		left_hand_area = null
	if right_hand_area and is_instance_valid(right_hand_area):
		right_hand_area.queue_free()
		right_hand_area = null
	left_overlapping_bodies.clear()
	right_overlapping_bodies.clear()

func _on_left_hand_body_entered(body: Node3D) -> void:
	if not body in left_overlapping_bodies:
		left_overlapping_bodies.append(body)
		_trigger_collision_haptic("left")

func _on_left_hand_body_exited(body: Node3D) -> void:
	left_overlapping_bodies.erase(body)

func _on_right_hand_body_entered(body: Node3D) -> void:
	if not body in right_overlapping_bodies:
		right_overlapping_bodies.append(body)
		_trigger_collision_haptic("right")

func _on_right_hand_body_exited(body: Node3D) -> void:
	right_overlapping_bodies.erase(body)

# ---------------------------------------------------------------------------
# Process loop — call from main._process(delta)
# ---------------------------------------------------------------------------

func process(delta: float) -> void:
	_update_finger_inputs()
	_interpolate_fingers(delta)
	_apply_finger_curl()
	_detect_gestures(delta)
	_update_hand_colors()

# ---------------------------------------------------------------------------
# Finger Input Reading
# ---------------------------------------------------------------------------

func _update_finger_inputs() -> void:
	if left_controller and is_instance_valid(left_controller):
		var trigger = left_controller.get_float("trigger")
		var grip = left_controller.get_float("grip")
		left_finger_targets["index"] = trigger
		left_finger_targets["middle"] = grip
		left_finger_targets["ring"] = grip * 0.9
		left_finger_targets["pinky"] = grip * 0.8
		left_finger_targets["thumb"] = maxf(trigger * 0.3, grip * 0.4)
		left_grip_strength = grip
		left_pinch_strength = trigger

	if right_controller and is_instance_valid(right_controller):
		var trigger = right_controller.get_float("trigger")
		var grip = right_controller.get_float("grip")
		right_finger_targets["index"] = trigger
		right_finger_targets["middle"] = grip
		right_finger_targets["ring"] = grip * 0.9
		right_finger_targets["pinky"] = grip * 0.8
		right_finger_targets["thumb"] = maxf(trigger * 0.3, grip * 0.4)
		right_grip_strength = grip
		right_pinch_strength = trigger

# ---------------------------------------------------------------------------
# Finger Interpolation
# ---------------------------------------------------------------------------

func _interpolate_fingers(delta: float) -> void:
	for finger in FINGER_NAMES:
		left_finger_current[finger] = lerpf(
			left_finger_current[finger],
			left_finger_targets[finger],
			FINGER_LERP_SPEED * delta
		)
		right_finger_current[finger] = lerpf(
			right_finger_current[finger],
			right_finger_targets[finger],
			FINGER_LERP_SPEED * delta
		)

# ---------------------------------------------------------------------------
# Apply Finger Curl to Joint Nodes
# ---------------------------------------------------------------------------

func _apply_finger_curl() -> void:
	_apply_finger_curl_to_joints(left_finger_joints, left_finger_current)
	_apply_finger_curl_to_joints(right_finger_joints, right_finger_current)

func _apply_finger_curl_to_joints(finger_joints: Dictionary, finger_values: Dictionary) -> void:
	for finger_name in finger_joints:
		var curl = finger_values.get(finger_name, 0.0)
		var joints = finger_joints[finger_name]
		if not joints is Array:
			continue

		# Apply rotation to each joint based on curl amount
		# Max curl of ~90 degrees per joint gives a natural fist
		var max_angle = 80.0 if finger_name == "thumb" else 90.0
		for i in range(joints.size()):
			var joint = joints[i]
			if not is_instance_valid(joint):
				continue
			var angle = curl * max_angle * (0.7 + 0.3 * (float(i) / max(joints.size() - 1, 1)))
			joint.rotation_degrees.x = angle

# ---------------------------------------------------------------------------
# Gesture Detection
# ---------------------------------------------------------------------------

func _detect_gestures(delta: float) -> void:
	var new_left = _classify_gesture(left_finger_current, left_pinch_strength, left_grip_strength)
	var new_right = _classify_gesture(right_finger_current, right_pinch_strength, right_grip_strength)

	left_gesture = _apply_gesture_with_hold(new_left, left_gesture, left_pending_gesture, left_gesture_timer, delta, "left")
	right_gesture = _apply_gesture_with_hold(new_right, right_gesture, right_pending_gesture, right_gesture_timer, delta, "right")

	# Update grab/pinch/point active states
	var prev_left_grab = left_grab_active
	var prev_right_grab = right_grab_active
	var prev_left_pinch = left_pinch_active
	var prev_right_pinch = right_pinch_active

	left_grab_active = left_gesture == Gesture.GRAB
	right_grab_active = right_gesture == Gesture.GRAB
	left_pinch_active = left_gesture == Gesture.PINCH
	right_pinch_active = right_gesture == Gesture.PINCH
	left_point_active = left_gesture == Gesture.POINT
	right_point_active = right_gesture == Gesture.POINT

	# Haptic feedback on state transitions
	if left_grab_active and not prev_left_grab:
		_trigger_grab_haptic("left")
	if right_grab_active and not prev_right_grab:
		_trigger_grab_haptic("right")
	if not left_grab_active and prev_left_grab:
		_trigger_release_haptic("left")
	if not right_grab_active and prev_right_grab:
		_trigger_release_haptic("right")
	if left_pinch_active and not prev_left_pinch:
		_trigger_pinch_haptic("left")
	if right_pinch_active and not prev_right_pinch:
		_trigger_pinch_haptic("right")

func _classify_gesture(fingers: Dictionary, pinch: float, grip: float) -> int:
	var thumb = fingers.get("thumb", 0.0)
	var index = fingers.get("index", 0.0)
	var middle = fingers.get("middle", 0.0)
	var ring_val = fingers.get("ring", 0.0)
	var pinky = fingers.get("pinky", 0.0)

	var all_curled = thumb > 0.7 and index > 0.7 and middle > 0.7 and ring_val > 0.7 and pinky > 0.7
	var all_open = thumb < 0.3 and index < 0.3 and middle < 0.3 and ring_val < 0.3 and pinky < 0.3

	# Grab: high grip with all fingers curled
	if grip > GRAB_THRESHOLD and all_curled:
		return Gesture.GRAB

	# Fist: all curled, low grip (not actively grabbing something)
	if all_curled and grip < 0.3:
		return Gesture.FIST

	# Open hand
	if all_open:
		return Gesture.OPEN_HAND

	# Pinch: high trigger (index+thumb)
	if pinch > PINCH_THRESHOLD:
		return Gesture.PINCH

	# Point: index extended, others curled
	if index < POINT_THRESHOLD and middle > 0.6 and ring_val > 0.6 and pinky > 0.6:
		return Gesture.POINT

	# Thumbs up: thumb extended, others curled
	if thumb < 0.3 and index > 0.6 and middle > 0.6 and ring_val > 0.6 and pinky > 0.6:
		return Gesture.THUMBS_UP

	# Peace sign: index and middle extended, others curled
	if index < 0.3 and middle < 0.3 and ring_val > 0.6 and pinky > 0.6:
		return Gesture.PEACE

	return Gesture.NONE

func _apply_gesture_with_hold(new_gesture: int, current_gesture: int, pending_gesture: int, timer: float, delta: float, hand: String) -> int:
	if new_gesture == current_gesture:
		# Reset pending state
		if hand == "left":
			left_pending_gesture = new_gesture
			left_gesture_timer = 0.0
		else:
			right_pending_gesture = new_gesture
			right_gesture_timer = 0.0
		return current_gesture

	if new_gesture == pending_gesture:
		# Same pending gesture, accumulate time
		var new_timer = timer + delta
		if hand == "left":
			left_gesture_timer = new_timer
		else:
			right_gesture_timer = new_timer

		if new_timer >= GESTURE_HOLD_TIME:
			return new_gesture
		return current_gesture
	else:
		# Different pending gesture, start fresh
		if hand == "left":
			left_pending_gesture = new_gesture
			left_gesture_timer = 0.0
		else:
			right_pending_gesture = new_gesture
			right_gesture_timer = 0.0
		return current_gesture

# ---------------------------------------------------------------------------
# Hand Color Updates (visual feedback for gesture state)
# ---------------------------------------------------------------------------

func _update_hand_colors() -> void:
	if left_hand_material:
		left_hand_material.albedo_color = _get_gesture_color(left_gesture, true)
		left_hand_material.emission = left_hand_material.albedo_color
	if right_hand_material:
		right_hand_material.albedo_color = _get_gesture_color(right_gesture, false)
		right_hand_material.emission = right_hand_material.albedo_color

func _get_gesture_color(gesture: int, is_left: bool) -> Color:
	match gesture:
		Gesture.GRAB:
			return HAND_COLOR_GRAB
		Gesture.PINCH:
			return HAND_COLOR_PINCH
		Gesture.POINT:
			return HAND_COLOR_POINT
		_:
			return HAND_COLOR_LEFT if is_left else HAND_COLOR_RIGHT

# ---------------------------------------------------------------------------
# Gesture Queries
# ---------------------------------------------------------------------------

func get_left_gesture() -> int:
	return left_gesture

func get_right_gesture() -> int:
	return right_gesture

func get_gesture_name(gesture: int) -> String:
	match gesture:
		Gesture.NONE: return "none"
		Gesture.OPEN_HAND: return "open_hand"
		Gesture.FIST: return "fist"
		Gesture.POINT: return "point"
		Gesture.PINCH: return "pinch"
		Gesture.THUMBS_UP: return "thumbs_up"
		Gesture.PEACE: return "peace"
		Gesture.GRAB: return "grab"
		_: return "unknown"

func is_left_grabbing() -> bool:
	return left_grab_active

func is_right_grabbing() -> bool:
	return right_grab_active

func is_left_pinching() -> bool:
	return left_pinch_active

func is_right_pinching() -> bool:
	return right_pinch_active

func is_left_pointing() -> bool:
	return left_point_active

func is_right_pointing() -> bool:
	return right_point_active

func get_left_grip_strength() -> float:
	return left_grip_strength

func get_right_grip_strength() -> float:
	return right_grip_strength

func get_left_pinch_strength() -> float:
	return left_pinch_strength

func get_right_pinch_strength() -> float:
	return right_pinch_strength

# ---------------------------------------------------------------------------
# Get fingertip world positions (for precise interaction)
# ---------------------------------------------------------------------------

func get_left_fingertip_position(finger_name: String) -> Vector3:
	return _get_fingertip_position(left_finger_joints, finger_name)

func get_right_fingertip_position(finger_name: String) -> Vector3:
	return _get_fingertip_position(right_finger_joints, finger_name)

func _get_fingertip_position(finger_joints: Dictionary, finger_name: String) -> Vector3:
	var joints = finger_joints.get(finger_name, [])
	if joints is Array and joints.size() > 0:
		var last_joint = joints[joints.size() - 1]
		if is_instance_valid(last_joint):
			return last_joint.global_position
	return Vector3.ZERO

func get_left_pinch_position() -> Vector3:
	var thumb_tip = get_left_fingertip_position("thumb")
	var index_tip = get_left_fingertip_position("index")
	return (thumb_tip + index_tip) * 0.5

func get_right_pinch_position() -> Vector3:
	var thumb_tip = get_right_fingertip_position("thumb")
	var index_tip = get_right_fingertip_position("index")
	return (thumb_tip + index_tip) * 0.5

# ---------------------------------------------------------------------------
# Overlap Queries
# ---------------------------------------------------------------------------

func get_left_overlapping_bodies() -> Array:
	return left_overlapping_bodies.duplicate()

func get_right_overlapping_bodies() -> Array:
	return right_overlapping_bodies.duplicate()

func is_left_touching_object() -> bool:
	return left_overlapping_bodies.size() > 0

func is_right_touching_object() -> bool:
	return right_overlapping_bodies.size() > 0

# ---------------------------------------------------------------------------
# Haptic Feedback
# ---------------------------------------------------------------------------

func _trigger_grab_haptic(hand: String) -> void:
	_trigger_haptic(hand, HAPTIC_GRAB_INTENSITY, HAPTIC_GRAB_DURATION)

func _trigger_release_haptic(hand: String) -> void:
	_trigger_haptic(hand, HAPTIC_RELEASE_INTENSITY, HAPTIC_RELEASE_DURATION)

func _trigger_pinch_haptic(hand: String) -> void:
	_trigger_haptic(hand, HAPTIC_PINCH_INTENSITY, HAPTIC_PINCH_DURATION)

func _trigger_collision_haptic(hand: String) -> void:
	_trigger_haptic(hand, HAPTIC_COLLISION_INTENSITY, HAPTIC_COLLISION_DURATION)

func trigger_ui_haptic(hand: String) -> void:
	_trigger_haptic(hand, HAPTIC_UI_INTENSITY, HAPTIC_UI_DURATION)

func trigger_custom_haptic(hand: String, intensity: float, duration: float) -> void:
	_trigger_haptic(hand, clampf(intensity, 0.0, 1.0), clampf(duration, 0.0, 1.0))

func _trigger_haptic(hand: String, intensity: float, duration: float) -> void:
	var ctrl = left_controller if hand == "left" else right_controller
	if ctrl and is_instance_valid(ctrl):
		ctrl.trigger_haptic_pulse("haptic", 0.0, intensity, duration, 0.0)

# ---------------------------------------------------------------------------
# Serialization (for network sync)
# ---------------------------------------------------------------------------

func get_left_hand_data() -> Dictionary:
	return {
		"position": _vec3_to_dict(_get_controller_position(left_controller)),
		"rotation": _quat_to_dict(_get_controller_rotation(left_controller)),
		"fingers": left_finger_current.duplicate(),
		"gesture": get_gesture_name(left_gesture),
		"pinchStrength": left_pinch_strength,
		"gripStrength": left_grip_strength,
	}

func get_right_hand_data() -> Dictionary:
	return {
		"position": _vec3_to_dict(_get_controller_position(right_controller)),
		"rotation": _quat_to_dict(_get_controller_rotation(right_controller)),
		"fingers": right_finger_current.duplicate(),
		"gesture": get_gesture_name(right_gesture),
		"pinchStrength": right_pinch_strength,
		"gripStrength": right_grip_strength,
	}

func _get_controller_position(ctrl: XRController3D) -> Vector3:
	if ctrl and is_instance_valid(ctrl):
		return ctrl.global_position
	return Vector3.ZERO

func _get_controller_rotation(ctrl: XRController3D) -> Quaternion:
	if ctrl and is_instance_valid(ctrl):
		return ctrl.global_transform.basis.get_rotation_quaternion()
	return Quaternion.IDENTITY

func _vec3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}

func _quat_to_dict(q: Quaternion) -> Dictionary:
	return {"x": q.x, "y": q.y, "z": q.z, "w": q.w}

# ---------------------------------------------------------------------------
# Apply remote hand data (for rendering other VR users' hands)
# ---------------------------------------------------------------------------

func apply_remote_hand_data(hand_node: Node3D, hand_data: Dictionary) -> void:
	if not hand_node or not is_instance_valid(hand_node):
		return

	var pos_data = hand_data.get("position", {})
	var rot_data = hand_data.get("rotation", {})
	var fingers_data = hand_data.get("fingers", {})

	if pos_data.has("x"):
		hand_node.global_position = Vector3(
			pos_data.get("x", 0.0),
			pos_data.get("y", 0.0),
			pos_data.get("z", 0.0)
		)

	if rot_data.has("w"):
		var quat = Quaternion(
			rot_data.get("x", 0.0),
			rot_data.get("y", 0.0),
			rot_data.get("z", 0.0),
			rot_data.get("w", 1.0)
		)
		hand_node.global_transform.basis = Basis(quat)

	# Apply finger curl to child finger joints if present
	for child in hand_node.get_children():
		if child.name in fingers_data:
			var curl = fingers_data.get(child.name, 0.0)
			_apply_remote_finger_curl(child, curl)

func _apply_remote_finger_curl(finger_root: Node3D, curl: float) -> void:
	var joints = []
	var node = finger_root
	for _i in range(3):
		for child in node.get_children():
			if child is Node3D and "joint" in child.name:
				joints.append(child)
				node = child
				break

	for i in range(joints.size()):
		var angle = curl * 90.0 * (0.7 + 0.3 * (float(i) / maxf(joints.size() - 1, 1)))
		joints[i].rotation_degrees.x = angle
