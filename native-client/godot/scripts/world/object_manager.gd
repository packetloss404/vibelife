class_name ObjectManager
extends RefCounted

var main  # reference to main node
var object_nodes := {}
var model_scene_cache := {}


func init(main_node) -> void:
	main = main_node


func sync_objects(items: Array) -> void:
	for child in main.dynamic_world.get_children():
		child.queue_free()
	object_nodes.clear()
	for item in items:
		sync_single_object(item)
	main.parcels_mgr.render_parcels()


func sync_single_object(item: Dictionary) -> void:
	if object_nodes.has(item.id):
		object_nodes[item.id].queue_free()
	var node := make_world_prop(item.asset, Vector3(item.x, item.y, item.z), item.rotationY, item.scale)
	node.set_meta("object_id", item.id)
	tag_pickable_nodes(node, item.id)
	node.set_meta("parcel", main.parcels_mgr.get_parcel_at(node.position))
	apply_selection_visual(node, item.id == main.build.selected_object_id)
	main.dynamic_world.add_child(node)
	object_nodes[item.id] = node


func load_scene_assets(payload: Dictionary) -> void:
	for child in main.static_world.get_children():
		child.queue_free()
	for item in payload.get("assets", []):
		main.static_world.add_child(make_world_prop(
			item.asset,
			Vector3(item.position[0], item.position[1], item.position[2]),
			item.rotation[1] if item.has("rotation") else 0.0,
			item.scale[0] if item.has("scale") else 1.0
		))


func make_world_prop(asset: String, position: Vector3, rotation_y: float, scale_value: float) -> Node3D:
	var imported := instantiate_imported_asset(asset)
	if imported:
		imported.position = position
		imported.rotation.y = rotation_y
		imported.scale = Vector3.ONE * scale_value
		attach_selection_body(imported)
		return imported

	var root := Node3D.new()
	root.position = position
	root.rotation.y = rotation_y
	root.scale = Vector3.ONE * scale_value

	# Use MaterialLibrary for PBR materials when available
	var lib: MaterialLibrary = main.mat_lib if "mat_lib" in main and main.mat_lib else null

	var mesh_instance := MeshInstance3D.new()

	if asset.contains("tower"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.5, 8.0, 3.5)
		mesh_instance.mesh = mesh
		mesh_instance.set_surface_override_material(0, lib.get_material("tower") if lib else _fallback_mat(Color("c7d3d9")))
		mesh_instance.position.y = 4.0
	elif asset.contains("hall"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(7.0, 4.0, 5.0)
		mesh_instance.mesh = mesh
		mesh_instance.set_surface_override_material(0, lib.get_material("hall") if lib else _fallback_mat(Color("d6d2c8")))
		mesh_instance.position.y = 2.0
	elif asset.contains("tree"):
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.18
		trunk_mesh.bottom_radius = 0.24
		trunk_mesh.height = 2.8
		trunk.mesh = trunk_mesh
		trunk.position.y = 1.4
		trunk.set_surface_override_material(0, lib.get_trunk_material() if lib else _fallback_mat(Color("5b4634")))
		root.add_child(trunk)
		var canopy := MeshInstance3D.new()
		var canopy_mesh := SphereMesh.new()
		canopy_mesh.radius = 1.1
		canopy.mesh = canopy_mesh
		canopy.position.y = 3.2
		canopy.set_surface_override_material(0, lib.get_canopy_material() if lib else _fallback_mat(Color("79ca92")))
		root.add_child(canopy)
		attach_selection_body(root)
		return root
	elif asset.contains("bench"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.8, 0.5, 0.6)
		mesh_instance.mesh = mesh
		mesh_instance.set_surface_override_material(0, lib.get_material("bench") if lib else _fallback_mat(Color("a7724f")))
		mesh_instance.position.y = 0.4
	elif asset.contains("lantern"):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.12
		mesh.bottom_radius = 0.12
		mesh.height = 2.2
		mesh_instance.mesh = mesh
		mesh_instance.set_surface_override_material(0, lib.get_material("lantern_post") if lib else _fallback_mat(Color("7ea4b3")))
		mesh_instance.position.y = 1.1
		var omni := OmniLight3D.new()
		omni.position.y = 2.3
		omni.light_color = Color("8cecff")
		omni.light_energy = 1.5
		root.add_child(omni)
		# Add small emissive bulb at top of lantern
		var bulb := MeshInstance3D.new()
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.1
		bulb.mesh = bulb_mesh
		bulb.position.y = 2.25
		bulb.set_surface_override_material(0, lib.get_lantern_light_material() if lib else _fallback_mat(Color("8cecff")))
		root.add_child(bulb)
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh_instance.mesh = mesh
		mesh_instance.set_surface_override_material(0, lib.get_material("crate") if lib else _fallback_mat(Color("7f6147")))
		mesh_instance.position.y = 0.5

	root.add_child(mesh_instance)
	attach_selection_body(root)
	return root


func _fallback_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func instantiate_imported_asset(asset: String) -> Node3D:
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


func attach_selection_body(node: Node3D) -> void:
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


func tag_pickable_nodes(node: Node, object_id: String) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).set_meta("object_id", object_id)
		tag_pickable_nodes(child, object_id)


func apply_selection_visual(node: Node3D, selected: bool) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_child := child as MeshInstance3D
			var mat := mesh_child.get_active_material(0)
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).emission_enabled = selected
				(mat as StandardMaterial3D).emission = Color("ffb36a")
