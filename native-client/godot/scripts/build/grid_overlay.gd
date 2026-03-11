class_name GridOverlay
extends RefCounted

var main  # reference to main node
var _grid_node: MeshInstance3D = null
var _grid_size := 1.0
const GRID_EXTENT := 30.0


func init(main_node) -> void:
	main = main_node


func show_grid(grid_size: float) -> void:
	_grid_size = grid_size
	_rebuild_grid()
	if _grid_node:
		_grid_node.visible = true


func hide_grid() -> void:
	if _grid_node:
		_grid_node.visible = false


func _rebuild_grid() -> void:
	if _grid_node:
		_grid_node.queue_free()
		_grid_node = null

	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.15)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

	var half := GRID_EXTENT
	var step := _grid_size
	var y := 0.01  # slightly above ground to avoid z-fighting

	# Lines along X axis (varying Z)
	var z := -half
	while z <= half:
		mesh.surface_add_vertex(Vector3(-half, y, z))
		mesh.surface_add_vertex(Vector3(half, y, z))
		z += step

	# Lines along Z axis (varying X)
	var x := -half
	while x <= half:
		mesh.surface_add_vertex(Vector3(x, y, -half))
		mesh.surface_add_vertex(Vector3(x, y, half))
		x += step

	mesh.surface_end()

	_grid_node = MeshInstance3D.new()
	_grid_node.mesh = mesh
	_grid_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(_grid_node)
