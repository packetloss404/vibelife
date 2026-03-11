class_name AvatarManager
extends RefCounted

const MOVE_SPEED := 7.5

var main  # reference to main node
var avatar_states := {}
var avatar_nodes := {}
var avatar_previous_positions := {}
var sitting_avatars := {}


func init(main_node) -> void:
	main = main_node


func sync_avatars() -> void:
	for avatar_id in avatar_nodes.keys():
		if not avatar_states.has(avatar_id):
			avatar_nodes[avatar_id].queue_free()
			avatar_nodes.erase(avatar_id)
			avatar_previous_positions.erase(avatar_id)

	for avatar_id in avatar_states.keys():
		var state: Dictionary = avatar_states[avatar_id]
		if not avatar_nodes.has(avatar_id):
			var avatar_node := _make_avatar_node(state)
			main.avatars_root.add_child(avatar_node)
			avatar_nodes[avatar_id] = avatar_node
			avatar_previous_positions[avatar_id] = avatar_node.position
		_update_avatar_node(avatar_nodes[avatar_id], state)


func update_local_movement(delta: float) -> void:
	if main.session.is_empty() or not avatar_states.has(main.session.avatarId):
		return

	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if input_vector.length() == 0:
		return

	input_vector = input_vector.normalized()
	var move := Vector3(input_vector.x, 0, input_vector.y) * MOVE_SPEED * delta
	var avatar: Dictionary = avatar_states[main.session.avatarId]
	avatar.x = clampf(float(avatar.x) + move.x, -28.0, 28.0)
	avatar.z = clampf(float(avatar.z) + move.z, -28.0, 28.0)
	avatar_states[main.session.avatarId] = avatar
	sync_avatars()
	if main.websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		main.websocket.send_text(JSON.stringify({
			"type": "move",
			"x": avatar.x,
			"y": avatar.y,
			"z": avatar.z
		}))


func play_emote(emote_name: String) -> void:
	if not avatar_nodes.has(main.session.avatarId):
		return
	_play_emote_on_avatar(main.session.avatarId, emote_name)


func handle_emote_event(avatar_id: String, emote_name: String) -> void:
	if not avatar_nodes.has(avatar_id):
		return
	_play_emote_on_avatar(avatar_id, emote_name)


func _play_emote_on_avatar(avatar_id: String, emote_name: String) -> void:
	if not avatar_nodes.has(avatar_id):
		return
	var node = avatar_nodes[avatar_id]
	var animation_player := _find_animation_player(node)
	if animation_player == null:
		return
	var emote_animations := [
		"Wave", "Dance", "Point", "Cheer", "Sit", "Jump",
		"Bow", "Salute", "Laugh", "Cry", "Meditate",
		"Yoga", "Stretch", "Dab", "Backflip", "AirGuitar"
	]
	# Capitalize first letter and handle hyphenated names like "air-guitar" -> "AirGuitar"
	var anim_name := ""
	for part in emote_name.split("-"):
		anim_name += part.capitalize()
	if anim_name in emote_animations and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
		await animation_player.animation_finished
		animation_player.play("Idle")
	elif animation_player.has_animation(emote_name.capitalize()):
		animation_player.play(emote_name.capitalize())
		await animation_player.animation_finished
		animation_player.play("Idle")


func get_local_avatar_position() -> Vector3:
	if avatar_nodes.has(main.session.avatarId):
		return avatar_nodes[main.session.avatarId].position
	return Vector3.ZERO


func has_local_avatar() -> bool:
	return not main.session.is_empty() and avatar_nodes.has(main.session.avatarId)


func _make_avatar_node(state: Dictionary) -> Node3D:
	var imported = main.objects.instantiate_imported_asset("/assets/models/avatar-runner.gltf")
	if imported:
		var name_tag := Label3D.new()
		name_tag.text = state.displayName
		name_tag.position.y = 3.4
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		imported.add_child(name_tag)
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

	var fallback_tag := Label3D.new()
	fallback_tag.text = state.displayName
	fallback_tag.position.y = 3.4
	fallback_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(fallback_tag)
	return root


func _update_avatar_node(node: Node3D, state: Dictionary) -> void:
	var previous = avatar_previous_positions.get(state.avatarId, node.position)
	node.position = Vector3(state.x, state.y, state.z)
	avatar_previous_positions[state.avatarId] = node.position
	var appearance: Dictionary = state.get("appearance", {})
	var existing_tag: Label3D = null
	for child in node.get_children():
		if child is Label3D:
			existing_tag = child
		if child is MeshInstance3D:
			var mesh_child := child as MeshInstance3D
			var material := StandardMaterial3D.new()
			if mesh_child.name.to_lower().contains("head"):
				material.albedo_color = Color(appearance.get("headColor", "#f2c7a8"))
			else:
				material.albedo_color = Color(appearance.get("bodyColor", "#8cd8ff"))
			mesh_child.set_surface_override_material(0, material)
	if existing_tag:
		existing_tag.text = state.displayName
	_update_avatar_animation(node, previous.distance_to(node.position))


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
	var desired := "Idle"
	if movement_delta > 0.15:
		desired = "Run"
	elif movement_delta > 0.02:
		desired = "Walk"
	if animation_player.has_animation(desired) and animation_player.current_animation != desired:
		animation_player.play(desired)


# ── Sitting ─────────────────────────────────────────────────────────────────

func handle_sit(avatar_id: String, object_id: String, position) -> void:
	sitting_avatars[avatar_id] = object_id
	if avatar_nodes.has(avatar_id):
		var node = avatar_nodes[avatar_id]
		node.position = Vector3(float(position.x), float(position.y), float(position.z))
		var anim = _find_animation_player(node)
		if anim and anim.has_animation("Sit"):
			anim.play("Sit")


func handle_stand(avatar_id: String) -> void:
	sitting_avatars.erase(avatar_id)
	if avatar_nodes.has(avatar_id):
		var node = avatar_nodes[avatar_id]
		var anim = _find_animation_player(node)
		if anim and anim.has_animation("Idle"):
			anim.play("Idle")


func is_local_player_sitting() -> bool:
	var avatar_id = main.session.get("avatarId", "")
	return sitting_avatars.has(avatar_id)


func try_sit_on_object(mouse_position: Vector2) -> bool:
	if main.session.is_empty():
		return false
	var camera = main.camera
	var from = camera.project_ray_origin(mouse_position)
	var to = from + camera.project_ray_normal(mouse_position) * 100.0
	var space_state = main.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit = space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider = hit.collider
	if not collider is Node:
		return false
	if not (collider as Node).has_meta("object_id"):
		return false
	var object_id = str((collider as Node).get_meta("object_id"))
	# Check if already sitting
	var local_avatar_id = str(main.session.get("avatarId", ""))
	if sitting_avatars.has(local_avatar_id):
		# Stand up
		if main.websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			main.websocket.send_text(JSON.stringify({"type": "stand"}))
		return true
	# Try to sit — server validates if it's a bench/chair
	if main.websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		main.websocket.send_text(JSON.stringify({"type": "sit", "objectId": object_id}))
	return true
