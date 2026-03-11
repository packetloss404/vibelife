class_name ParcelManager
extends RefCounted

var main  # reference to main node
var parcels: Array = []
var active_parcel: Dictionary = {}
var parcel_nodes := {}


func init(main_node) -> void:
	main = main_node


func get_parcel_at(position: Vector3) -> Dictionary:
	for parcel in parcels:
		if position.x >= float(parcel.minX) and position.x <= float(parcel.maxX) and position.z >= float(parcel.minZ) and position.z <= float(parcel.maxZ):
			return parcel
	return {}


func render_parcels() -> void:
	for child in main.parcels_root.get_children():
		child.queue_free()
	parcel_nodes.clear()
	for parcel in parcels:
		var root := Node3D.new()
		var width := float(parcel.maxX) - float(parcel.minX)
		var depth := float(parcel.maxZ) - float(parcel.minZ)
		var center := Vector3((float(parcel.minX) + float(parcel.maxX)) / 2.0, 0.03, (float(parcel.minZ) + float(parcel.maxZ)) / 2.0)

		var fill := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(width, depth)
		fill.mesh = plane
		fill.rotation_degrees.x = -90
		fill.position = center
		var fill_material := StandardMaterial3D.new()
		fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fill_material.albedo_color = _parcel_color(parcel, true)
		fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fill.set_surface_override_material(0, fill_material)
		root.add_child(fill)

		var line_material := StandardMaterial3D.new()
		line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_material.albedo_color = _parcel_color(parcel, false)
		line_material.emission_enabled = true
		line_material.emission = _parcel_color(parcel, false)
		for edge in _parcel_edges(parcel):
			var edge_mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = edge["size"]
			edge_mesh.mesh = box
			edge_mesh.position = edge["position"]
			edge_mesh.set_surface_override_material(0, line_material)
			root.add_child(edge_mesh)

		var label := Label3D.new()
		label.text = "%s (%s)" % [parcel.name, parcel.ownerDisplayName if parcel.ownerDisplayName != null else parcel.tier]
		label.position = center + Vector3(0, 0.25, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(label)

		main.parcels_root.add_child(root)
		parcel_nodes[parcel.id] = root


func can_build(parcel: Dictionary) -> bool:
	if parcel.is_empty():
		return false
	if parcel.tier == "public":
		return true
	if parcel.ownerAccountId == null:
		return false
	return String(parcel.ownerAccountId) == String(main.session.accountId)


func parcel_denied_reason(parcel: Dictionary) -> String:
	if parcel.is_empty():
		return "Builds must be placed inside a parcel"
	if parcel.ownerAccountId == null and parcel.tier != "public":
		return "Claim this parcel before building here"
	return "Parcel owned by %s" % parcel.get("ownerDisplayName", "another resident")


func update_parcel_from_event(next_parcel: Dictionary) -> void:
	var replaced := false
	for index in range(parcels.size()):
		if parcels[index].id == next_parcel.id:
			parcels[index] = next_parcel
			replaced = true
			break
	if not replaced:
		parcels.append(next_parcel)
	if not active_parcel.is_empty() and active_parcel.get("id", "") == next_parcel.id:
		active_parcel = next_parcel


func claim_button_state() -> void:
	var is_admin = main.session.get("role", "resident") == "admin"
	main.claim_parcel_button.disabled = active_parcel.is_empty() or active_parcel.get("tier", "") == "public" or (active_parcel.get("ownerAccountId", null) != null and not is_admin)
	main.release_parcel_button.disabled = active_parcel.is_empty() or (String(active_parcel.get("ownerAccountId", "")) != String(main.session.get("accountId", "")) and not is_admin)
	main.admin_audit_log.visible = is_admin


func claim_active_parcel() -> void:
	if active_parcel.is_empty() or main.session.is_empty() or active_parcel.get("tier", "") == "public":
		return
	var request := HTTPRequest.new()
	main.add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var is_admin = main.session.get("role", "resident") == "admin"
	var body := JSON.stringify({"token": main.session.token, "parcelId": active_parcel.id, "ownerAccountId": main.session.accountId} if is_admin else {"token": main.session.token, "parcelId": active_parcel.id})
	var url := "%s%s" % [main.backend_url, "/api/admin/parcels/assign" if is_admin else "/api/parcels/claim"]
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result = await request.request_completed
		if int(result[1]) == 200:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			var parcel = payload.get("parcel", {})
			for index in range(parcels.size()):
				if parcels[index].id == parcel.id:
					parcels[index] = parcel
			active_parcel = parcel
			render_parcels()
			claim_button_state()
			main.status_label.text = "%s %s" % ["Admin claimed" if is_admin else "Claimed", parcel.get("name", "parcel")]
			await load_admin_audit_logs()
		else:
			main.status_label.text = "Parcel claim failed"
	request.queue_free()


func release_active_parcel() -> void:
	if active_parcel.is_empty() or main.session.is_empty():
		return
	var request := HTTPRequest.new()
	main.add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var is_admin = main.session.get("role", "resident") == "admin"
	var body := JSON.stringify({"token": main.session.token, "parcelId": active_parcel.id, "ownerAccountId": null} if is_admin else {"token": main.session.token, "parcelId": active_parcel.id})
	var url := "%s%s" % [main.backend_url, "/api/admin/parcels/assign" if is_admin else "/api/parcels/release"]
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result = await request.request_completed
		if int(result[1]) == 200:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			var parcel = payload.get("parcel", {})
			for index in range(parcels.size()):
				if parcels[index].id == parcel.id:
					parcels[index] = parcel
			active_parcel = parcel
			render_parcels()
			claim_button_state()
			main.status_label.text = "%s %s" % ["Admin cleared" if is_admin else "Released", parcel.get("name", "parcel")]
			await load_admin_audit_logs()
		else:
			main.status_label.text = "Parcel release failed"
	request.queue_free()


func load_admin_audit_logs() -> void:
	if main.session.get("role", "resident") != "admin":
		main.admin_audit_log.text = ""
		return
	var request := HTTPRequest.new()
	main.add_child(request)
	var url := "%s/api/admin/audit-logs?token=%s&limit=10" % [main.backend_url, main.session.token]
	if request.request(url) == OK:
		var result = await request.request_completed
		if int(result[1]) == 200:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			var lines: Array[String] = []
			for entry in payload.get("logs", []):
				lines.append("%s - %s" % [entry.action, entry.details])
			main.admin_audit_log.text = "\n".join(lines)
	request.queue_free()


func _parcel_color(parcel: Dictionary, transparent: bool) -> Color:
	if not active_parcel.is_empty() and parcel.id == active_parcel.get("id", ""):
		return Color(1.0, 0.95, 0.54, 0.18 if transparent else 1.0)
	if parcel.tier == "public":
		return Color(0.4, 1.0, 0.82, 0.08 if transparent else 1.0)
	if parcel.ownerAccountId == null:
		return Color(0.95, 0.58, 0.35, 0.08 if transparent else 1.0)
	if String(parcel.ownerAccountId) == String(main.session.get("accountId", "")):
		return Color(1.0, 0.7, 0.42, 0.1 if transparent else 1.0)
	return Color(0.92, 0.35, 0.35, 0.08 if transparent else 1.0)


func _parcel_edges(parcel: Dictionary) -> Array:
	var min_x := float(parcel.minX)
	var max_x := float(parcel.maxX)
	var min_z := float(parcel.minZ)
	var max_z := float(parcel.maxZ)
	var center_x := (min_x + max_x) / 2.0
	var center_z := (min_z + max_z) / 2.0
	return [
		{"position": Vector3(center_x, 0.08, min_z), "size": Vector3(max_x - min_x, 0.08, 0.08)},
		{"position": Vector3(center_x, 0.08, max_z), "size": Vector3(max_x - min_x, 0.08, 0.08)},
		{"position": Vector3(min_x, 0.08, center_z), "size": Vector3(0.08, 0.08, max_z - min_z)},
		{"position": Vector3(max_x, 0.08, center_z), "size": Vector3(0.08, 0.08, max_z - min_z)}
	]
