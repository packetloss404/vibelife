class_name VoxelManager
extends RefCounted

var main_node: Node3D
var voxels_root: Node3D
var palette: BlockPalette
var renderer: VoxelChunkRenderer
var loaded_chunks: Dictionary = {}  # "cx:cz" -> {node: MeshInstance3D, collision: StaticBody3D, blocks: PackedByteArray, palette: Array}
var chunk_lru: Array = []  # LRU order of chunk keys
const MAX_CHUNKS := 64
const CHUNK_SIZE := 16
var last_chunk_x := -999
var last_chunk_z := -999
var http_request: HTTPRequest
var voxel_mode := false
var block_cursor: MeshInstance3D
var selected_block_type: int = 1
var current_region_id: String = ""
var auth_token: String = ""
var server_url: String = ""
var cursor_block_pos: Vector3 = Vector3.ZERO
var cursor_face_normal: Vector3 = Vector3.ZERO
var cursor_valid := false


func init(main: Node3D) -> void:
	main_node = main
	palette = BlockPalette.new()
	renderer = VoxelChunkRenderer.new(palette)

	voxels_root = Node3D.new()
	voxels_root.name = "VoxelsRoot"
	main_node.add_child(voxels_root)

	# Create block cursor - wireframe cube
	block_cursor = MeshInstance3D.new()
	block_cursor.name = "BlockCursor"
	var cursor_mesh := BoxMesh.new()
	cursor_mesh.size = Vector3(1.01, 1.01, 1.01)
	block_cursor.mesh = cursor_mesh

	var cursor_material := StandardMaterial3D.new()
	cursor_material.albedo_color = Color(1.0, 1.0, 1.0, 0.4)
	cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cursor_material.no_depth_test = true
	block_cursor.material_override = cursor_material
	block_cursor.visible = false
	main_node.add_child(block_cursor)

	# Create HTTPRequest for chunk loading
	http_request = HTTPRequest.new()
	http_request.name = "VoxelHTTPRequest"
	main_node.add_child(http_request)
	http_request.request_completed.connect(on_chunks_loaded)


func configure(region_id: String, token: String, url: String) -> void:
	current_region_id = region_id
	auth_token = token
	server_url = url


func update_chunks(player_pos: Vector3) -> void:
	var cx := int(floor(player_pos.x / CHUNK_SIZE))
	var cz := int(floor(player_pos.z / CHUNK_SIZE))

	if cx == last_chunk_x and cz == last_chunk_z:
		return

	last_chunk_x = cx
	last_chunk_z = cz

	if current_region_id.is_empty() or server_url.is_empty():
		return

	var url := "%s/api/regions/%s/chunks?token=%s&cx=%d&cz=%d&radius=2" % [
		server_url, current_region_id, auth_token, cx, cz
	]
	http_request.cancel_request()
	http_request.request(url)


func on_chunks_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return

	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		return

	var data = json.data
	if not data is Dictionary or not data.has("chunks"):
		return

	var chunks_data: Array = data.chunks
	for chunk_data in chunks_data:
		if not chunk_data is Dictionary:
			continue

		var cx: int = int(chunk_data.get("cx", 0))
		var cz: int = int(chunk_data.get("cz", 0))
		var key := "%d:%d" % [cx, cz]

		# Decode block data
		var block_data_encoded: String = chunk_data.get("blocks", "")
		var chunk_palette_data: Array = chunk_data.get("palette", [])
		var blocks := PackedByteArray()

		if not block_data_encoded.is_empty():
			blocks = Marshalls.base64_to_raw(block_data_encoded)

		if blocks.size() < 16 * 64 * 16:
			continue

		# Sync palette if server provided block types
		if chunk_data.has("blockTypes"):
			palette.sync_from_server(chunk_data.blockTypes)

		# Remove old chunk if exists
		_remove_chunk(key)

		# Build mesh
		var mesh := renderer.build_chunk_mesh(blocks, chunk_palette_data)
		var collision_shape := renderer.build_collision_shape(blocks, chunk_palette_data)

		# Create MeshInstance3D
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Chunk_%s" % key
		mesh_instance.mesh = mesh
		mesh_instance.position = Vector3(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE)

		# Create vertex color material
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		mesh_instance.material_override = material

		voxels_root.add_child(mesh_instance)

		# Create StaticBody3D for collision
		var static_body := StaticBody3D.new()
		static_body.name = "ChunkCollision_%s" % key
		static_body.position = Vector3(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE)

		var collision_node := CollisionShape3D.new()
		collision_node.shape = collision_shape
		static_body.add_child(collision_node)
		voxels_root.add_child(static_body)

		# Store in loaded chunks
		loaded_chunks[key] = {
			"node": mesh_instance,
			"collision": static_body,
			"blocks": blocks,
			"palette": chunk_palette_data,
			"cx": cx,
			"cz": cz,
		}

		# Update LRU
		if key in chunk_lru:
			chunk_lru.erase(key)
		chunk_lru.push_back(key)

	# Evict oldest chunks if over limit
	while chunk_lru.size() > MAX_CHUNKS:
		var oldest_key: String = chunk_lru.pop_front()
		_remove_chunk(oldest_key)


func _remove_chunk(key: String) -> void:
	if not loaded_chunks.has(key):
		return

	var chunk_info: Dictionary = loaded_chunks[key]
	var node: MeshInstance3D = chunk_info.node
	var collision: StaticBody3D = chunk_info.collision

	if is_instance_valid(node):
		node.queue_free()
	if is_instance_valid(collision):
		collision.queue_free()

	loaded_chunks.erase(key)
	chunk_lru.erase(key)


func place_block(position: Vector3, block_type_id: int) -> void:
	if server_url.is_empty():
		return

	var place_http := HTTPRequest.new()
	main_node.add_child(place_http)
	place_http.request_completed.connect(func(_r, _rc, _h, body):
		if _rc == 200:
			var json := JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var resp = json.data
				if resp is Dictionary and resp.has("x"):
					apply_block_delta(int(resp.x), int(resp.y), int(resp.z), block_type_id)
		place_http.queue_free()
	)

	var body := JSON.stringify({
		"x": int(position.x),
		"y": int(position.y),
		"z": int(position.z),
		"blockType": block_type_id,
		"regionId": current_region_id,
		"token": auth_token,
	})

	var headers := PackedStringArray(["Content-Type: application/json"])
	place_http.request(server_url + "/api/voxels/block", headers, HTTPClient.METHOD_POST, body)


func break_block(position: Vector3) -> void:
	if server_url.is_empty():
		return

	var break_http := HTTPRequest.new()
	main_node.add_child(break_http)
	break_http.request_completed.connect(func(_r, _rc, _h, body):
		if _rc == 200:
			apply_block_delta(int(position.x), int(position.y), int(position.z), 0)
		break_http.queue_free()
	)

	var body := JSON.stringify({
		"x": int(position.x),
		"y": int(position.y),
		"z": int(position.z),
		"regionId": current_region_id,
		"token": auth_token,
	})

	var headers := PackedStringArray(["Content-Type: application/json"])
	break_http.request(server_url + "/api/voxels/block", headers, HTTPClient.METHOD_DELETE, body)


func update_block_cursor(camera: Camera3D) -> void:
	if not voxel_mode or not is_instance_valid(camera):
		block_cursor.visible = false
		cursor_valid = false
		return

	var viewport := camera.get_viewport()
	if viewport == null:
		block_cursor.visible = false
		cursor_valid = false
		return

	var screen_center := viewport.get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_dir := camera.project_ray_normal(screen_center)
	var ray_end := ray_origin + ray_dir * 10.0  # 10 block reach

	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		block_cursor.visible = false
		cursor_valid = false
		return

	var hit_pos: Vector3 = result.position
	var hit_normal: Vector3 = result.normal

	# Snap to block grid - the block we're looking at
	var block_pos := Vector3(
		floor(hit_pos.x - hit_normal.x * 0.01),
		floor(hit_pos.y - hit_normal.y * 0.01),
		floor(hit_pos.z - hit_normal.z * 0.01)
	)

	cursor_block_pos = block_pos
	cursor_face_normal = hit_normal
	cursor_valid = true

	# Position cursor at block center
	block_cursor.position = block_pos + Vector3(0.5, 0.5, 0.5)
	block_cursor.visible = true


func toggle_voxel_mode() -> void:
	voxel_mode = not voxel_mode
	block_cursor.visible = voxel_mode
	if not voxel_mode:
		cursor_valid = false


func handle_voxel_input(event: InputEvent) -> void:
	if not voxel_mode or not cursor_valid:
		return

	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			# Place block on the face we're looking at
			var place_pos := cursor_block_pos + cursor_face_normal
			place_block(place_pos, selected_block_type)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			# Break the block we're looking at
			break_block(cursor_block_pos)


func apply_block_delta(x: int, y: int, z: int, block_type_id: int) -> void:
	# Find which chunk this block belongs to
	var cx := int(floor(float(x) / CHUNK_SIZE))
	var cz := int(floor(float(z) / CHUNK_SIZE))
	var key := "%d:%d" % [cx, cz]

	if not loaded_chunks.has(key):
		return

	var chunk_info: Dictionary = loaded_chunks[key]
	var blocks: PackedByteArray = chunk_info.blocks
	var chunk_palette: Array = chunk_info.palette

	# Local coordinates within the chunk
	var lx := x - cx * CHUNK_SIZE
	var lz := z - cz * CHUNK_SIZE

	if lx < 0 or lx >= 16 or y < 0 or y >= 64 or lz < 0 or lz >= 16:
		return

	var index := y * 256 + lz * 16 + lx

	# If using chunk palette, find or add the block type
	if not chunk_palette.is_empty():
		var palette_index := -1
		for i in range(chunk_palette.size()):
			if int(chunk_palette[i]) == block_type_id:
				palette_index = i
				break
		if palette_index == -1:
			chunk_palette.append(block_type_id)
			palette_index = chunk_palette.size() - 1
		blocks[index] = palette_index
	else:
		blocks[index] = block_type_id

	chunk_info.blocks = blocks
	chunk_info.palette = chunk_palette
	loaded_chunks[key] = chunk_info

	# Rebuild mesh
	var new_mesh := renderer.build_chunk_mesh(blocks, chunk_palette)
	var new_collision := renderer.build_collision_shape(blocks, chunk_palette)

	var mesh_node: MeshInstance3D = chunk_info.node
	if is_instance_valid(mesh_node):
		mesh_node.mesh = new_mesh

	var collision_body: StaticBody3D = chunk_info.collision
	if is_instance_valid(collision_body):
		for child in collision_body.get_children():
			if child is CollisionShape3D:
				child.shape = new_collision
				break
