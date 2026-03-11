class_name EnemyRenderer
extends RefCounted

var main_node: Node3D
var enemies_root: Node3D
var enemy_nodes: Dictionary = {}  # enemyId -> Node3D
var enemy_data_cache: Dictionary = {}  # enemyId -> last known data for lerping
var enemy_target_positions: Dictionary = {}  # enemyId -> target Vector3
var idle_time: float = 0.0


func init(main: Node3D) -> void:
	main_node = main
	enemies_root = Node3D.new()
	enemies_root.name = "EnemiesRoot"
	main_node.add_child(enemies_root)


func create_enemy_mesh(variant: String, level: int) -> Node3D:
	var root := Node3D.new()
	var scale_factor := 1.0 + level * 0.02

	match variant:
		"slime":
			root = _create_slime(level, scale_factor)
		"skeleton":
			root = _create_skeleton(level, scale_factor)
		"golem":
			root = _create_golem(level, scale_factor)
		"shadow":
			root = _create_shadow(level, scale_factor)
		"drake":
			root = _create_drake(level, scale_factor)
		_:
			root = _create_slime(level, scale_factor)

	# Add health bar above the enemy
	var health_bar := _create_health_bar()
	var bar_height := _get_variant_height(variant) * scale_factor + 0.3
	health_bar.position = Vector3(0, bar_height, 0)
	health_bar.name = "HealthBar"
	root.add_child(health_bar)

	root.scale = Vector3.ONE * scale_factor
	return root


func _create_slime(level: int, _scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Slime"

	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.7
	body.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 0.2).lerp(Color(0.1, 0.5, 0.1), clampf(level / 50.0, 0.0, 1.0))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	body.material_override = mat
	body.position = Vector3(0, 0.35, 0)
	body.name = "Body"
	root.add_child(body)

	return root


func _create_skeleton(_level: int, _scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Skeleton"

	# Body - capsule
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = 1.0
	body.mesh = capsule

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.9, 0.88, 0.82)
	body.material_override = body_mat
	body.position = Vector3(0, 0.6, 0)
	body.name = "Body"
	root.add_child(body)

	# Head - small sphere
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	head.mesh = head_mesh

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.92, 0.9, 0.84)
	head.material_override = head_mat
	head.position = Vector3(0, 1.25, 0)
	head.name = "Head"
	root.add_child(head)

	return root


func _create_golem(_level: int, _scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Golem"

	# Body - large cube
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.2, 1.5, 0.9)
	body.mesh = body_mesh

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.55, 0.4, 0.25)
	body.material_override = body_mat
	body.position = Vector3(0, 0.75, 0)
	body.name = "Body"
	root.add_child(body)

	# Head - smaller cube
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.8, 0.8, 0.7)
	head.mesh = head_mesh

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.5, 0.38, 0.22)
	head.material_override = head_mat
	head.position = Vector3(0, 1.9, 0)
	head.name = "Head"
	root.add_child(head)

	return root


func _create_shadow(_level: int, _scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Shadow"

	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	body.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.1, 0.55, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.05, 0.5)
	mat.emission_energy_multiplier = 0.5
	body.material_override = mat
	body.position = Vector3(0, 0.7, 0)  # Slightly floating
	body.name = "Body"
	root.add_child(body)

	return root


func _create_drake(_level: int, _scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Drake"

	# Body - elongated capsule
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	body.mesh = capsule

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.8, 0.15, 0.1)
	body.material_override = body_mat
	body.position = Vector3(0, 0.8, 0)
	body.name = "Body"
	root.add_child(body)

	# Head - cone
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.3
	cone.height = 0.5
	head.mesh = cone

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.2, 0.1)
	head.material_override = head_mat
	head.position = Vector3(0, 1.85, 0)
	head.name = "Head"
	root.add_child(head)

	return root


func _get_variant_height(variant: String) -> float:
	match variant:
		"slime": return 0.7
		"skeleton": return 1.4
		"golem": return 2.3
		"shadow": return 1.0
		"drake": return 2.1
		_: return 1.0


func _create_health_bar() -> Node3D:
	var bar_root := Node3D.new()

	# Background (dark)
	var bg := MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(0.8, 0.06, 0.02)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.15, 0.15, 0.15)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.material_override = bg_mat
	bg.name = "BarBackground"
	bar_root.add_child(bg)

	# Foreground (green, will be scaled/colored based on HP)
	var fg := MeshInstance3D.new()
	var fg_mesh := BoxMesh.new()
	fg_mesh.size = Vector3(0.76, 0.04, 0.03)
	fg.mesh = fg_mesh
	var fg_mat := StandardMaterial3D.new()
	fg_mat.albedo_color = Color(0.1, 0.9, 0.1)
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg.material_override = fg_mat
	fg.name = "BarFill"
	bar_root.add_child(fg)

	# Billboard mode - always face camera
	bar_root.set_meta("is_health_bar", true)

	return bar_root


func sync_enemies(enemy_data: Array) -> void:
	var seen_ids: Dictionary = {}

	for data in enemy_data:
		if not data is Dictionary:
			continue

		var enemy_id: String = str(data.get("id", ""))
		if enemy_id.is_empty():
			continue

		seen_ids[enemy_id] = true
		var target_pos := Vector3(
			float(data.get("x", 0)),
			float(data.get("y", 0)),
			float(data.get("z", 0))
		)
		var variant: String = str(data.get("variant", "slime"))
		var level: int = int(data.get("level", 1))

		enemy_target_positions[enemy_id] = target_pos

		if not enemy_nodes.has(enemy_id):
			# Create new enemy
			var node := create_enemy_mesh(variant, level)
			node.name = "Enemy_%s" % enemy_id
			node.position = target_pos
			enemies_root.add_child(node)
			enemy_nodes[enemy_id] = node
			enemy_data_cache[enemy_id] = data
		else:
			enemy_data_cache[enemy_id] = data

	# Remove enemies no longer present
	var to_remove: Array = []
	for eid in enemy_nodes:
		if not seen_ids.has(eid):
			to_remove.append(eid)

	for eid in to_remove:
		remove_enemy(eid)


func update_enemy_health(enemy_id: String, hp: int, max_hp: int) -> void:
	if not enemy_nodes.has(enemy_id):
		return

	var node: Node3D = enemy_nodes[enemy_id]
	var health_bar := node.find_child("HealthBar", true, false)
	if health_bar == null:
		return

	var bar_fill := health_bar.find_child("BarFill", true, false)
	if bar_fill == null or not bar_fill is MeshInstance3D:
		return

	var ratio := clampf(float(hp) / max(max_hp, 1), 0.0, 1.0)

	# Scale the fill bar
	bar_fill.scale.x = ratio
	bar_fill.position.x = -(1.0 - ratio) * 0.38  # Keep bar left-aligned

	# Color: green -> yellow -> red
	var bar_color: Color
	if ratio > 0.5:
		bar_color = Color(0.1, 0.9, 0.1).lerp(Color(0.9, 0.9, 0.1), 1.0 - (ratio - 0.5) * 2.0)
	else:
		bar_color = Color(0.9, 0.9, 0.1).lerp(Color(0.9, 0.1, 0.1), 1.0 - ratio * 2.0)

	var mat: StandardMaterial3D = bar_fill.material_override
	if mat:
		mat.albedo_color = bar_color


func play_death_animation(enemy_id: String) -> void:
	if not enemy_nodes.has(enemy_id):
		return

	var node: Node3D = enemy_nodes[enemy_id]

	# Create a tween to scale down and remove
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ZERO, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func():
		remove_enemy(enemy_id)
	)


func remove_enemy(enemy_id: String) -> void:
	if enemy_nodes.has(enemy_id):
		var node: Node3D = enemy_nodes[enemy_id]
		if is_instance_valid(node):
			node.queue_free()
		enemy_nodes.erase(enemy_id)
	enemy_data_cache.erase(enemy_id)
	enemy_target_positions.erase(enemy_id)


func _process_enemies(delta: float) -> void:
	idle_time += delta

	for enemy_id in enemy_nodes:
		var node: Node3D = enemy_nodes[enemy_id]
		if not is_instance_valid(node):
			continue

		# Lerp toward target position for smooth movement
		if enemy_target_positions.has(enemy_id):
			var target: Vector3 = enemy_target_positions[enemy_id]
			node.position = node.position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))

		# Idle animation
		var data: Dictionary = enemy_data_cache.get(enemy_id, {})
		var variant: String = str(data.get("variant", "slime"))
		_animate_idle(node, variant, delta)

		# Make health bar face camera
		var health_bar := node.find_child("HealthBar", true, false)
		if health_bar and is_instance_valid(health_bar):
			var camera := node.get_viewport().get_camera_3d()
			if camera and is_instance_valid(camera):
				health_bar.look_at(camera.global_position, Vector3.UP)


func _animate_idle(node: Node3D, variant: String, _delta: float) -> void:
	var body := node.find_child("Body", true, false)
	if body == null or not body is MeshInstance3D:
		return

	match variant:
		"slime":
			# Squash and stretch
			var t := sin(idle_time * 3.0) * 0.1
			body.scale = Vector3(1.0 + t, 1.0 - t, 1.0 + t)
		"skeleton":
			# Slight sway
			body.rotation.z = sin(idle_time * 2.0) * 0.05
		"golem":
			# Slow bob
			body.position.y = 0.75 + sin(idle_time * 1.5) * 0.03
		"shadow":
			# Float up and down more noticeably
			body.position.y = 0.7 + sin(idle_time * 2.5) * 0.15
		"drake":
			# Slight rotation
			node.rotation.y = sin(idle_time * 1.0) * 0.1
