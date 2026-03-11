class_name TerrainManager
extends RefCounted

## Generates a subdivided terrain mesh with shader-based height displacement,
## replacing the flat PlaneMesh ground. Uses the terrain.gdshader for
## multi-texture splatmap blending and gentle procedural hills.

var main  # reference to Main node

var terrain_mesh_instance: MeshInstance3D
var terrain_body: StaticBody3D

# Configuration
var terrain_size := 60.0
var subdivisions := 128  # vertex grid resolution
var height_scale := 0.8
var noise_freq := 0.08
var noise_freq2 := 0.2

var shader_material: ShaderMaterial


func init(main_node) -> void:
	main = main_node


func setup_terrain() -> void:
	_clear_existing_ground()
	_create_terrain_mesh()
	_apply_terrain_shader()
	_create_collision()


func _clear_existing_ground() -> void:
	# Remove all children from the Ground node (old PlaneMesh + collision)
	if main.ground:
		main.ground.mesh = null
		main.ground.material_override = null
		main.ground.rotation_degrees = Vector3.ZERO
		for child in main.ground.get_children():
			child.queue_free()


func _create_terrain_mesh() -> void:
	# Generate a subdivided plane mesh using SurfaceTool for proper vertex control
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := terrain_size * 0.5
	var step_size := terrain_size / float(subdivisions)

	# Generate vertices in a grid
	for z_i in range(subdivisions + 1):
		for x_i in range(subdivisions + 1):
			var x := -half + float(x_i) * step_size
			var z := -half + float(z_i) * step_size

			# UV maps 0-1 across terrain
			var u := float(x_i) / float(subdivisions)
			var v := float(z_i) / float(subdivisions)

			# Height will be computed in the shader, but we set y=0 here.
			# The shader does vertex displacement for visual hills.
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(0.0, 1.0, 0.0))
			st.add_vertex(Vector3(x, 0.0, z))

	# Generate triangle indices
	for z_i in range(subdivisions):
		for x_i in range(subdivisions):
			var top_left := z_i * (subdivisions + 1) + x_i
			var top_right := top_left + 1
			var bottom_left := (z_i + 1) * (subdivisions + 1) + x_i
			var bottom_right := bottom_left + 1

			# First triangle
			st.add_index(top_left)
			st.add_index(bottom_left)
			st.add_index(top_right)

			# Second triangle
			st.add_index(top_right)
			st.add_index(bottom_left)
			st.add_index(bottom_right)

	st.generate_tangents()
	var mesh := st.commit()

	main.ground.mesh = mesh
	# Ensure ground is not rotated (old setup rotated -90 for PlaneMesh)
	main.ground.rotation_degrees = Vector3.ZERO


func _apply_terrain_shader() -> void:
	var shader := load("res://shaders/terrain.gdshader") as Shader
	if not shader:
		push_warning("TerrainManager: terrain.gdshader not found, using fallback material")
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color("3a6b44")
		fallback.roughness = 0.92
		main.ground.material_override = fallback
		return

	shader_material = ShaderMaterial.new()
	shader_material.shader = shader

	# Set default uniform values
	shader_material.set_shader_parameter("terrain_size", terrain_size)
	shader_material.set_shader_parameter("height_scale", height_scale)
	shader_material.set_shader_parameter("noise_frequency", noise_freq)
	shader_material.set_shader_parameter("noise_frequency2", noise_freq2)
	shader_material.set_shader_parameter("texture_scale", 8.0)
	shader_material.set_shader_parameter("triplanar_sharpness", 4.0)
	shader_material.set_shader_parameter("slope_threshold", 0.6)
	shader_material.set_shader_parameter("detail_fade_start", 20.0)
	shader_material.set_shader_parameter("detail_fade_end", 50.0)

	# Lo-fi palette colors for procedural splatmap (no texture files needed)
	shader_material.set_shader_parameter("color_grass", Color(0.32, 0.55, 0.28))
	shader_material.set_shader_parameter("color_dirt", Color(0.45, 0.33, 0.2))
	shader_material.set_shader_parameter("color_sand", Color(0.76, 0.7, 0.5))
	shader_material.set_shader_parameter("color_stone", Color(0.5, 0.48, 0.45))

	# Warm tint consistency
	shader_material.set_shader_parameter("warm_tint", Color(1.04, 0.98, 0.93))
	shader_material.set_shader_parameter("tint_strength", 0.3)

	main.ground.material_override = shader_material


func _create_collision() -> void:
	# Create a flat collision shape for physics (the visual hills are subtle
	# enough that flat collision works fine for a chill sandbox)
	terrain_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(terrain_size, 0.2, terrain_size)
	shape.shape = box
	terrain_body.add_child(shape)
	main.ground.add_child(terrain_body)


# ── Runtime API ──────────────────────────────────────────────────────────────

func set_height_scale(value: float) -> void:
	height_scale = value
	if shader_material:
		shader_material.set_shader_parameter("height_scale", value)


func set_terrain_size(value: float) -> void:
	terrain_size = value
	if shader_material:
		shader_material.set_shader_parameter("terrain_size", value)
	# Rebuild mesh and collision at new size
	setup_terrain()


func set_texture_scale(value: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("texture_scale", value)


func set_detail_fade(start: float, end_dist: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("detail_fade_start", start)
		shader_material.set_shader_parameter("detail_fade_end", end_dist)
