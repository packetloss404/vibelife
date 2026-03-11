class_name VoiceIndicator extends RefCounted
## Manages voice activity indicators (speaking/muted icons) above avatars.
## Uses Label3D nodes positioned above avatar heads.
## NOTE: main.gd needs to call voice_indicator.init(self) and
##       voice_indicator._update_indicators() each frame in _process().

var main
var speaking_avatars = {}   # avatar_id -> true
var muted_avatars = {}      # avatar_id -> true
var indicator_nodes = {}    # avatar_id -> Label3D
var pulse_time = 0.0

const INDICATOR_HEIGHT = 2.8
const PULSE_SPEED = 6.0
const PULSE_MIN_SCALE = 0.8
const PULSE_MAX_SCALE = 1.2

func init(main_node) -> void:
	main = main_node

func show_speaking(avatar_id: String, is_speaking: bool) -> void:
	if is_speaking:
		speaking_avatars[avatar_id] = true
		muted_avatars.erase(avatar_id)
		_ensure_indicator(avatar_id)
		var label = indicator_nodes.get(avatar_id)
		if label != null:
			label.text = "🔊"
			label.modulate = Color(0.2, 1.0, 0.4, 1.0)
			label.visible = true
	else:
		speaking_avatars.erase(avatar_id)
		if not muted_avatars.has(avatar_id):
			_hide_indicator(avatar_id)

func show_muted(avatar_id: String) -> void:
	muted_avatars[avatar_id] = true
	speaking_avatars.erase(avatar_id)
	_ensure_indicator(avatar_id)
	var label = indicator_nodes.get(avatar_id)
	if label != null:
		label.text = "🔇"
		label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		label.visible = true

func remove_avatar(avatar_id: String) -> void:
	speaking_avatars.erase(avatar_id)
	muted_avatars.erase(avatar_id)
	_remove_indicator(avatar_id)

func _update_indicators(delta: float) -> void:
	pulse_time += delta
	var pulse_scale = lerp(PULSE_MIN_SCALE, PULSE_MAX_SCALE, (sin(pulse_time * PULSE_SPEED) + 1.0) / 2.0)

	for avatar_id in indicator_nodes:
		var label = indicator_nodes[avatar_id]
		if label == null or not is_instance_valid(label):
			continue

		# Position above avatar head
		var avatar_node = _get_avatar_node(avatar_id)
		if avatar_node == null or not is_instance_valid(avatar_node):
			_remove_indicator(avatar_id)
			continue

		label.global_position = avatar_node.global_position + Vector3(0, INDICATOR_HEIGHT, 0)

		# Pulse effect for speaking avatars
		if speaking_avatars.has(avatar_id):
			label.scale = Vector3(pulse_scale, pulse_scale, pulse_scale)
		else:
			label.scale = Vector3.ONE

func _ensure_indicator(avatar_id: String) -> void:
	if indicator_nodes.has(avatar_id):
		var existing = indicator_nodes[avatar_id]
		if existing != null and is_instance_valid(existing):
			return

	var avatar_node = _get_avatar_node(avatar_id)
	if avatar_node == null:
		return

	var label = Label3D.new()
	label.text = ""
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = Color.WHITE

	main.add_child(label)
	indicator_nodes[avatar_id] = label

func _hide_indicator(avatar_id: String) -> void:
	var label = indicator_nodes.get(avatar_id)
	if label != null and is_instance_valid(label):
		label.visible = false

func _remove_indicator(avatar_id: String) -> void:
	var label = indicator_nodes.get(avatar_id)
	if label != null and is_instance_valid(label):
		label.queue_free()
	indicator_nodes.erase(avatar_id)

func _get_avatar_node(avatar_id: String):
	if main == null:
		return null
	# Access avatar Node3D references via main.avatars_root children
	# Convention: avatar nodes are children of Avatars root with name matching avatar_id
	if main.avatars_root == null:
		return null
	for child in main.avatars_root.get_children():
		if child.name == avatar_id:
			return child
	return null

func cleanup() -> void:
	for avatar_id in indicator_nodes.keys():
		_remove_indicator(avatar_id)
	speaking_avatars.clear()
	muted_avatars.clear()
	indicator_nodes.clear()
