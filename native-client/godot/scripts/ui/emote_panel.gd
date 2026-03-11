class_name EmotePanel
extends RefCounted

var main  # reference to main node
var emotes: Array = []
var emotes_by_category := {}


func init(main_node) -> void:
	main = main_node


func set_emotes(emote_list: Array) -> void:
	emotes = emote_list
	emotes_by_category.clear()
	for emote in emotes:
		var category: String = emote.get("category", "fun")
		if not emotes_by_category.has(category):
			emotes_by_category[category] = []
		emotes_by_category[category].append(emote)


func get_categories() -> Array:
	return emotes_by_category.keys()


func get_emotes_in_category(category: String) -> Array:
	return emotes_by_category.get(category, [])


func get_all_emote_names() -> Array:
	var names: Array = []
	for emote in emotes:
		names.append(emote.get("name", ""))
	return names


func send_emote(emote_name: String) -> void:
	if main.websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var emote := _find_emote(emote_name)
	if emote.is_empty():
		return
	main.websocket.send_text(JSON.stringify({
		"type": "emote",
		"emoteName": emote_name
	}))


func get_emote_duration(emote_name: String) -> int:
	var emote := _find_emote(emote_name)
	return int(emote.get("duration_ms", 2000))


func _find_emote(emote_name: String) -> Dictionary:
	for emote in emotes:
		if emote.get("name", "") == emote_name:
			return emote
	return {}


# ── Emote Combo Effects ─────────────────────────────────────────────────────

const COMBO_LABELS := {
	"combo:high-five": "High Five!",
	"combo:dance-sync": "Dance Sync!",
	"combo:mutual-bow": "Mutual Bow!",
	"combo:wave-sync": "Wave Sync!"
}

const COMBO_COLORS := {
	"combo:high-five": Color(1.0, 0.85, 0.2),
	"combo:dance-sync": Color(0.4, 1.0, 0.7),
	"combo:mutual-bow": Color(0.8, 0.6, 1.0),
	"combo:wave-sync": Color(0.4, 0.8, 1.0)
}


func handle_emote_combo(message: Dictionary) -> void:
	var combo_name = str(message.get("comboName", ""))
	var pos = message.get("position", {})
	var world_pos := Vector3(float(pos.get("x", 0)), float(pos.get("y", 0)) + 2.5, float(pos.get("z", 0)))

	# Floating label
	var label := Label3D.new()
	label.text = COMBO_LABELS.get(combo_name, combo_name)
	label.font_size = 32
	label.modulate = COMBO_COLORS.get(combo_name, Color.WHITE)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = world_pos
	label.no_depth_test = true
	main.add_child(label)

	# Animate: rise and fade over 1.5 seconds
	var tween = main.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", world_pos.y + 2.0, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.chain().tween_callback(label.queue_free)

	# Particle burst (simple colored spheres)
	var color = COMBO_COLORS.get(combo_name, Color.WHITE)
	for i in range(8):
		var sphere := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.08
		mesh.height = 0.16
		sphere.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere.set_surface_override_material(0, mat)
		sphere.position = world_pos
		main.add_child(sphere)
		var angle := float(i) / 8.0 * TAU
		var target := world_pos + Vector3(cos(angle) * 1.5, 0.5, sin(angle) * 1.5)
		var stween = main.create_tween()
		stween.set_parallel(true)
		stween.tween_property(sphere, "position", target, 0.8)
		stween.tween_property(sphere, "scale", Vector3.ZERO, 0.8)
		stween.chain().tween_callback(sphere.queue_free)
