class_name BuildController
extends RefCounted

var main  # reference to main node
var build_mode := false
var selected_object_id := ""
var gizmo_mode := "move"
var drag_selected := false
var active_drag_axis := ""
var gizmo_handles := {}

# Snap-to-grid settings
var snap_enabled := false
var snap_grid_size := 1.0  # 0.5, 1.0, or 2.0
var grid_overlay: GridOverlay
var undo_mgr: UndoManager


func init(main_node) -> void:
	main = main_node
	grid_overlay = GridOverlay.new()
	grid_overlay.init(main)
	undo_mgr = UndoManager.new()
	undo_mgr.init(main)


func toggle_build_mode() -> void:
	build_mode = not build_mode
	main.build_mode_button.text = "Disable build mode" if build_mode else "Enable build mode"
	main.status_label.text = "Build mode enabled" if build_mode else "Build mode disabled"
	main._show_build_panel(build_mode)
	if not build_mode:
		drag_selected = false
		active_drag_axis = ""
		grid_overlay.hide_grid()
	elif snap_enabled:
		grid_overlay.show_grid(snap_grid_size)
	main.parcels_mgr.claim_button_state()


func set_gizmo_mode(mode: String) -> void:
	gizmo_mode = mode
	main.status_label.text = "Gizmo mode: %s" % mode


func toggle_snap() -> void:
	snap_enabled = not snap_enabled
	main.status_label.text = "Snap: %s (grid: %s)" % ["ON" if snap_enabled else "OFF", str(snap_grid_size)]
	if snap_enabled and build_mode:
		grid_overlay.show_grid(snap_grid_size)
	else:
		grid_overlay.hide_grid()


func cycle_grid_size() -> void:
	if snap_grid_size == 0.5:
		snap_grid_size = 1.0
	elif snap_grid_size == 1.0:
		snap_grid_size = 2.0
	else:
		snap_grid_size = 0.5
	main.status_label.text = "Grid size: %s" % str(snap_grid_size)
	if snap_enabled and build_mode:
		grid_overlay.show_grid(snap_grid_size)


func snap_position(pos: Vector3) -> Vector3:
	if not snap_enabled:
		return pos
	return Vector3(
		snappedf(pos.x, snap_grid_size),
		snappedf(pos.y, snap_grid_size),
		snappedf(pos.z, snap_grid_size)
	)


func handle_build_click(mouse_position: Vector2) -> void:
	if main.session.is_empty():
		return

	var from = main.camera.project_ray_origin(mouse_position)
	var to = from + main.camera.project_ray_normal(mouse_position) * 500.0
	var space_state = main.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit = space_state.intersect_ray(query)

	if not hit.is_empty() and hit.collider is Node and (hit.collider as Node).has_meta("gizmo_axis"):
		active_drag_axis = str((hit.collider as Node).get_meta("gizmo_axis"))
		drag_selected = true
		main.status_label.text = "Dragging %s axis" % active_drag_axis.to_upper()
		return

	if not hit.is_empty() and hit.collider is Node and (hit.collider as Node).has_meta("object_id"):
		selected_object_id = str((hit.collider as Node).get_meta("object_id"))
		update_selection_state()
		drag_selected = true
		return

	var ground_plane := Plane(Vector3.UP, 0.0)
	var world_point = ground_plane.intersects_ray(from, main.camera.project_ray_normal(mouse_position))
	if world_point == null:
		return
	var parcel = main.parcels_mgr.get_parcel_at(world_point)
	if not main.parcels_mgr.can_build(parcel):
		main.status_label.text = main.parcels_mgr.parcel_denied_reason(parcel)
		return

	var snap_pos := snap_position(Vector3(world_point.x, 0.0, world_point.z))
	await _create_object(snap_pos)


func handle_build_key(event: InputEventKey) -> void:
	# Undo: Ctrl+Z
	if event.physical_keycode == KEY_Z and event.ctrl_pressed and not event.shift_pressed:
		await undo_mgr.undo()
		return
	# Redo: Ctrl+Shift+Z
	if event.physical_keycode == KEY_Z and event.ctrl_pressed and event.shift_pressed:
		await undo_mgr.redo()
		return
	# Toggle snap: G key
	if event.physical_keycode == KEY_G and not event.ctrl_pressed:
		toggle_snap()
		return
	# Cycle grid size: H key
	if event.physical_keycode == KEY_H and not event.ctrl_pressed:
		cycle_grid_size()
		return
	# Copy: Ctrl+C
	if event.ctrl_pressed and event.physical_keycode == KEY_C and not selected_object_id.is_empty() and main.objects.object_nodes.has(selected_object_id):
		var copy_node = main.objects.object_nodes[selected_object_id]
		var asset_index = main.build_asset_select.selected
		var asset_path = main.build_assets[asset_index] if asset_index >= 0 and asset_index < main.build_assets.size() else ""
		main.clipboard = [{"asset": asset_path, "x": copy_node.position.x, "y": copy_node.position.y, "z": copy_node.position.z, "rotationY": copy_node.rotation.y, "scale": copy_node.scale.x}]
		main.status_label.text = "Copied object to clipboard"
		return
	# Paste: Ctrl+V
	if event.ctrl_pressed and event.physical_keycode == KEY_V and not main.clipboard.is_empty():
		for entry in main.clipboard:
			var paste_pos := Vector3(float(entry.x) + 2.0, float(entry.y), float(entry.z) + 2.0)
			var parcel = main.parcels_mgr.get_parcel_at(paste_pos)
			if main.parcels_mgr.can_build(parcel):
				await _create_object_at(paste_pos, str(entry.asset), float(entry.rotationY), float(entry.scale))
		main.status_label.text = "Pasted %d object(s)" % main.clipboard.size()
		return

	if selected_object_id.is_empty() or not main.objects.object_nodes.has(selected_object_id):
		return

	var node = main.objects.object_nodes[selected_object_id]
	var before_state := _capture_object_state(node)
	var moved := false
	if event.physical_keycode == KEY_UP:
		node.position.z -= 1.0
		moved = true
	if event.physical_keycode == KEY_DOWN:
		node.position.z += 1.0
		moved = true
	if event.physical_keycode == KEY_LEFT:
		node.position.x -= 1.0
		moved = true
	if event.physical_keycode == KEY_RIGHT:
		node.position.x += 1.0
		moved = true
	if event.physical_keycode == KEY_Q:
		node.rotation.y -= 0.2
		moved = true
	if event.physical_keycode == KEY_E:
		node.rotation.y += 0.2
		moved = true
	if event.physical_keycode == KEY_R:
		node.scale *= 1.1
		moved = true
	if event.physical_keycode == KEY_F:
		node.scale *= 0.9
		moved = true
	if event.physical_keycode == KEY_DELETE:
		var delete_before := _capture_object_state(node)
		await _delete_selected_object()
		undo_mgr.push_action("delete", selected_object_id, delete_before, null)
		return

	if moved:
		node.position = snap_position(node.position)
		var parcel = main.parcels_mgr.get_parcel_at(node.position)
		if not main.parcels_mgr.can_build(parcel):
			main.status_label.text = main.parcels_mgr.parcel_denied_reason(parcel)
			return
		await _update_selected_object(node)
		var after_state := _capture_object_state(node)
		var action_type := "move"
		if event.physical_keycode == KEY_Q or event.physical_keycode == KEY_E:
			action_type = "rotate"
		elif event.physical_keycode == KEY_R or event.physical_keycode == KEY_F:
			action_type = "scale"
		undo_mgr.push_action(action_type, selected_object_id, before_state, after_state)


func apply_gizmo_wheel(direction: float) -> void:
	var node = main.objects.object_nodes[selected_object_id]
	var before_state := _capture_object_state(node)
	if gizmo_mode == "rotate":
		node.rotation.y += 0.15 * direction
	elif gizmo_mode == "scale":
		node.scale *= 1.0 + (0.08 * direction)
	else:
		node.position.y += 0.3 * direction
	node.position = snap_position(node.position)
	await _update_selected_object(node)
	var after_state := _capture_object_state(node)
	undo_mgr.push_action(gizmo_mode, selected_object_id, before_state, after_state)


func drag_selected_object(event: InputEventMouseMotion) -> void:
	var node = main.objects.object_nodes[selected_object_id]
	if active_drag_axis.is_empty():
		return
	var delta := event.relative
	if gizmo_mode == "move":
		if active_drag_axis == "x":
			node.position.x += delta.x * 0.02
		elif active_drag_axis == "y":
			node.position.y -= delta.y * 0.02
		else:
			node.position.z += delta.x * 0.02
		node.position = snap_position(node.position)
	elif gizmo_mode == "rotate":
		var rotation_delta := delta.x * 0.01
		if active_drag_axis == "x":
			node.rotation.x += rotation_delta
		elif active_drag_axis == "y":
			node.rotation.y += rotation_delta
		else:
			node.rotation.z += rotation_delta
	elif gizmo_mode == "scale":
		var scale_delta := maxf(0.2, 1.0 + (delta.x * 0.005))
		node.scale *= scale_delta
	main.parcels_mgr.active_parcel = main.parcels_mgr.get_parcel_at(node.position)
	main.parcel_label.text = "Parcel: %s" % main.parcels_mgr.active_parcel.get("name", "none")
	main.parcels_mgr.claim_button_state()


func duplicate_selected_object() -> void:
	if selected_object_id.is_empty() or not main.objects.object_nodes.has(selected_object_id):
		return
	var node = main.objects.object_nodes[selected_object_id]
	var pos := snap_position(node.position + Vector3(1.0, 0.0, 1.0))
	await _create_object(pos)


func update_selection_state() -> void:
	main.selection_label.text = "Selected: %s" % selected_object_id if not selected_object_id.is_empty() else "No object selected"
	for object_id in main.objects.object_nodes.keys():
		main.objects.apply_selection_visual(main.objects.object_nodes[object_id], object_id == selected_object_id)
	if not selected_object_id.is_empty() and main.objects.object_nodes.has(selected_object_id):
		main.parcels_mgr.active_parcel = main.parcels_mgr.get_parcel_at(main.objects.object_nodes[selected_object_id].position)
	else:
		main.parcels_mgr.active_parcel = {}
	main.parcel_label.text = "Parcel: %s" % main.parcels_mgr.active_parcel.get("name", "none")
	update_gizmo_handles()
	main.parcels_mgr.claim_button_state()


func update_gizmo_handles() -> void:
	if gizmo_handles.is_empty():
		_rebuild_gizmo_handles()
	if selected_object_id.is_empty() or not main.objects.object_nodes.has(selected_object_id):
		for handle in gizmo_handles.values():
			handle.visible = false
		return

	var target = main.objects.object_nodes[selected_object_id].position
	var x_handle: Node3D = gizmo_handles["x"]
	var y_handle: Node3D = gizmo_handles["y"]
	var z_handle: Node3D = gizmo_handles["z"]
	x_handle.visible = true
	y_handle.visible = true
	z_handle.visible = true
	x_handle.position = target + Vector3(1.0, 0.65, 0.0)
	z_handle.position = target + Vector3(0.0, 0.65, 1.0)
	y_handle.position = target + Vector3(0.0, 1.2, 0.0)
	x_handle.rotation_degrees.z = 90
	z_handle.rotation_degrees.x = 90
	y_handle.rotation = Vector3.ZERO


func _capture_object_state(node: Node3D) -> Dictionary:
	return {
		"x": node.position.x,
		"y": node.position.y,
		"z": node.position.z,
		"rotationY": node.rotation.y,
		"scale": node.scale.x
	}


func _create_object_at(position: Vector3, asset: String, rotation_y: float, scale_value: float) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({
		"token": main.session.token,
		"asset": asset,
		"x": position.x,
		"y": position.y,
		"z": position.z,
		"rotationY": rotation_y,
		"scale": scale_value
	})
	var url := "%s/api/regions/%s/objects" % [main.backend_url, main.session.regionId]
	var request := HTTPRequest.new()
	main.add_child(request)
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		await request.request_completed
	request.queue_free()
	await main._load_region_objects(main.session.regionId)


func _create_object(position: Vector3) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({
		"token": main.session.token,
		"asset": main.build_assets[main.build_asset_select.selected],
		"x": position.x,
		"y": position.y,
		"z": position.z,
		"rotationY": 0.0,
		"scale": 1.0
	})
	var url := "%s/api/regions/%s/objects" % [main.backend_url, main.session.regionId]
	if main.create_object_request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		await main.create_object_request.request_completed
	main.parcels_mgr.active_parcel = main.parcels_mgr.get_parcel_at(position)
	main.parcel_label.text = "Parcel: %s" % main.parcels_mgr.active_parcel.get("name", "none")
	main.parcels_mgr.claim_button_state()
	await main._load_region_objects(main.session.regionId)


func _update_selected_object(node: Node3D) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({
		"token": main.session.token,
		"x": node.position.x,
		"y": node.position.y,
		"z": node.position.z,
		"rotationY": node.rotation.y,
		"scale": node.scale.x
	})
	var url := "%s/api/objects/%s" % [main.backend_url, selected_object_id]
	if main.update_object_request.request(url, headers, HTTPClient.METHOD_PATCH, body) == OK:
		await main.update_object_request.request_completed
		node.set_meta("parcel", main.parcels_mgr.get_parcel_at(node.position))
		await main._load_region_objects(main.session.regionId)


func _delete_selected_object() -> void:
	if selected_object_id.is_empty():
		return
	var headers := PackedStringArray(["Content-Type: application/json"])
	var is_admin = main.session.get("role", "resident") == "admin"
	var body := JSON.stringify({"token": main.session.token, "objectId": selected_object_id} if is_admin else {"token": main.session.token})
	var url := "%s/api/admin/objects/delete" % main.backend_url if is_admin else "%s/api/objects/%s" % [main.backend_url, selected_object_id]
	var method := HTTPClient.METHOD_POST if is_admin else HTTPClient.METHOD_DELETE
	if main.delete_object_request.request(url, headers, method, body) == OK:
		await main.delete_object_request.request_completed
		await main._load_region_objects(main.session.regionId)
	selected_object_id = ""
	update_selection_state()


func _rebuild_gizmo_handles() -> void:
	for child in main.gizmos_root.get_children():
		child.queue_free()
	gizmo_handles.clear()
	for axis in ["x", "y", "z"]:
		var handle_root := Node3D.new()
		var handle := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.04
		mesh.bottom_radius = 0.04
		mesh.height = 1.3
		handle.mesh = mesh
		var material := StandardMaterial3D.new()
		material.emission_enabled = true
		material.albedo_color = Color("ff6b6b") if axis == "x" else Color("66ffd1") if axis == "y" else Color("6aa8ff")
		material.emission = material.albedo_color
		handle.set_surface_override_material(0, material)
		handle_root.add_child(handle)
		var body := StaticBody3D.new()
		body.set_meta("gizmo_axis", axis)
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.height = 1.3
		cylinder.radius = 0.18
		shape.shape = cylinder
		body.add_child(shape)
		handle_root.add_child(body)
		handle_root.visible = false
		main.gizmos_root.add_child(handle_root)
		gizmo_handles[axis] = handle_root
