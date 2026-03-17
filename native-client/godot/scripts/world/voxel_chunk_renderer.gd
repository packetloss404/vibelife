class_name VoxelChunkRenderer
extends RefCounted

var palette: BlockPalette

# Face normals and vertex offsets for each of the 6 cube faces
const FACE_NORMALS := [
	Vector3(0, 1, 0),   # Up
	Vector3(0, -1, 0),  # Down
	Vector3(0, 0, -1),  # North (-Z)
	Vector3(0, 0, 1),   # South (+Z)
	Vector3(-1, 0, 0),  # West
	Vector3(1, 0, 0),   # East
]

# Vertex offsets for each face (two triangles = 6 vertices per face, CCW winding)
const FACE_VERTICES := [
	# Up (Y+)
	[Vector3(0,1,0), Vector3(0,1,1), Vector3(1,1,1), Vector3(0,1,0), Vector3(1,1,1), Vector3(1,1,0)],
	# Down (Y-)
	[Vector3(0,0,1), Vector3(0,0,0), Vector3(1,0,0), Vector3(0,0,1), Vector3(1,0,0), Vector3(1,0,1)],
	# North (Z-)
	[Vector3(1,1,0), Vector3(1,0,0), Vector3(0,0,0), Vector3(1,1,0), Vector3(0,0,0), Vector3(0,1,0)],
	# South (Z+)
	[Vector3(0,1,1), Vector3(0,0,1), Vector3(1,0,1), Vector3(0,1,1), Vector3(1,0,1), Vector3(1,1,1)],
	# West (X-)
	[Vector3(0,1,0), Vector3(0,0,0), Vector3(0,0,1), Vector3(0,1,0), Vector3(0,0,1), Vector3(0,1,1)],
	# East (X+)
	[Vector3(1,1,1), Vector3(1,0,1), Vector3(1,0,0), Vector3(1,1,1), Vector3(1,0,0), Vector3(1,1,0)],
]

# AO sample offsets per face: for each vertex of each face, the 3 neighbor positions to check
# These are relative to the block position
const AO_NEIGHBOR_OFFSETS := [
	# Up face - check blocks above in the 4 corners
	[Vector3(-1,1,-1), Vector3(-1,1,0), Vector3(0,1,-1),   # v0
	 Vector3(-1,1,0), Vector3(-1,1,1), Vector3(0,1,1),     # v1
	 Vector3(0,1,1), Vector3(1,1,1), Vector3(1,1,0),       # v2
	 Vector3(-1,1,-1), Vector3(-1,1,0), Vector3(0,1,-1),   # v3 (same as v0)
	 Vector3(0,1,1), Vector3(1,1,1), Vector3(1,1,0),       # v4 (same as v2)
	 Vector3(1,1,0), Vector3(1,1,-1), Vector3(0,1,-1)],    # v5
	# Down face
	[Vector3(-1,-1,0), Vector3(-1,-1,1), Vector3(0,-1,1),
	 Vector3(-1,-1,-1), Vector3(-1,-1,0), Vector3(0,-1,-1),
	 Vector3(0,-1,-1), Vector3(1,-1,-1), Vector3(1,-1,0),
	 Vector3(-1,-1,0), Vector3(-1,-1,1), Vector3(0,-1,1),
	 Vector3(0,-1,-1), Vector3(1,-1,-1), Vector3(1,-1,0),
	 Vector3(1,-1,0), Vector3(1,-1,1), Vector3(0,-1,1)],
	# North face (Z-)
	[Vector3(1,1,-1), Vector3(1,0,-1), Vector3(0,1,-1),
	 Vector3(1,0,-1), Vector3(1,-1,-1), Vector3(0,-1,-1),
	 Vector3(0,-1,-1), Vector3(-1,-1,-1), Vector3(-1,0,-1),
	 Vector3(1,1,-1), Vector3(1,0,-1), Vector3(0,1,-1),
	 Vector3(0,-1,-1), Vector3(-1,-1,-1), Vector3(-1,0,-1),
	 Vector3(-1,0,-1), Vector3(-1,1,-1), Vector3(0,1,-1)],
	# South face (Z+)
	[Vector3(-1,1,1), Vector3(-1,0,1), Vector3(0,1,1),
	 Vector3(-1,0,1), Vector3(-1,-1,1), Vector3(0,-1,1),
	 Vector3(0,-1,1), Vector3(1,-1,1), Vector3(1,0,1),
	 Vector3(-1,1,1), Vector3(-1,0,1), Vector3(0,1,1),
	 Vector3(0,-1,1), Vector3(1,-1,1), Vector3(1,0,1),
	 Vector3(1,0,1), Vector3(1,1,1), Vector3(0,1,1)],
	# West face (X-)
	[Vector3(-1,1,-1), Vector3(-1,0,-1), Vector3(-1,1,0),
	 Vector3(-1,0,-1), Vector3(-1,-1,-1), Vector3(-1,-1,0),
	 Vector3(-1,-1,0), Vector3(-1,-1,1), Vector3(-1,0,1),
	 Vector3(-1,1,-1), Vector3(-1,0,-1), Vector3(-1,1,0),
	 Vector3(-1,-1,0), Vector3(-1,-1,1), Vector3(-1,0,1),
	 Vector3(-1,0,1), Vector3(-1,1,1), Vector3(-1,1,0)],
	# East face (X+)
	[Vector3(1,1,1), Vector3(1,0,1), Vector3(1,1,0),
	 Vector3(1,0,1), Vector3(1,-1,1), Vector3(1,-1,0),
	 Vector3(1,-1,0), Vector3(1,-1,-1), Vector3(1,0,-1),
	 Vector3(1,1,1), Vector3(1,0,1), Vector3(1,1,0),
	 Vector3(1,-1,0), Vector3(1,-1,-1), Vector3(1,0,-1),
	 Vector3(1,0,-1), Vector3(1,1,-1), Vector3(1,1,0)],
]

func _init(p: BlockPalette) -> void:
	palette = p


func get_block_at(blocks: PackedByteArray, x: int, y: int, z: int) -> int:
	if x < 0 or x >= 16 or y < 0 or y >= 64 or z < 0 or z >= 16:
		return 0  # Out of bounds treated as air
	var index := y * 256 + z * 16 + x
	if index < 0 or index >= blocks.size():
		return 0
	return blocks[index]


func _resolve_block_id(raw_id: int, chunk_palette: Array) -> int:
	if chunk_palette.is_empty():
		return raw_id
	if raw_id >= 0 and raw_id < chunk_palette.size():
		var val = chunk_palette[raw_id]
		if val == null:
			return 0
		if val is Dictionary:
			return int(val.get("id", raw_id))
		return int(val)
	return 0


func _compute_ao(blocks: PackedByteArray, chunk_palette: Array, bx: int, by: int, bz: int, face_index: int, vertex_index: int) -> float:
	var offsets: Array = AO_NEIGHBOR_OFFSETS[face_index]
	var base := vertex_index * 3
	var occluders := 0
	for i in range(3):
		var offset: Vector3 = offsets[base + i]
		var nx := bx + int(offset.x)
		var ny := by + int(offset.y)
		var nz := bz + int(offset.z)
		var neighbor_raw := get_block_at(blocks, nx, ny, nz)
		var neighbor_id := _resolve_block_id(neighbor_raw, chunk_palette)
		if palette.is_solid(neighbor_id):
			occluders += 1
	# Return AO factor: 1.0 = fully lit, lower = darker
	match occluders:
		0: return 1.0
		1: return 0.8
		2: return 0.6
		3: return 0.45
		_: return 0.45


func build_chunk_mesh(blocks: PackedByteArray, chunk_palette: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var expected_size := 16 * 64 * 16
	if blocks.size() < expected_size:
		return st.commit()

	# Neighbor offsets for each face direction (matching FACE_NORMALS order)
	var neighbor_offsets: Array[Vector3i] = [
		Vector3i(0, 1, 0),   # Up
		Vector3i(0, -1, 0),  # Down
		Vector3i(0, 0, -1),  # North
		Vector3i(0, 0, 1),   # South
		Vector3i(-1, 0, 0),  # West
		Vector3i(1, 0, 0),   # East
	]

	for y in range(64):
		for z in range(16):
			for x in range(16):
				var raw_id := get_block_at(blocks, x, y, z)
				var block_id := _resolve_block_id(raw_id, chunk_palette)

				if block_id == 0:
					continue  # Skip air

				var base_color := palette.get_block_color(block_id)
				var block_pos := Vector3(x, y, z)

				for face_index in range(6):
					var no: Vector3i = neighbor_offsets[face_index]
					var nx := x + no.x
					var ny := y + no.y
					var nz := z + no.z

					var neighbor_raw := get_block_at(blocks, nx, ny, nz)
					var neighbor_id := _resolve_block_id(neighbor_raw, chunk_palette)

					# Only add face if neighbor is air or transparent (and we aren't transparent ourselves,
					# or neighbor is a different block type)
					var show_face := false
					if neighbor_id == 0:
						show_face = true
					elif palette.is_transparent(neighbor_id) and neighbor_id != block_id:
						show_face = true

					if not show_face:
						continue

					var normal: Vector3 = FACE_NORMALS[face_index]
					st.set_normal(normal)

					var verts: Array = FACE_VERTICES[face_index]
					for vi in range(6):
						var ao_factor := _compute_ao(blocks, chunk_palette, x, y, z, face_index, vi)
						var vert_color := Color(
							base_color.r * ao_factor,
							base_color.g * ao_factor,
							base_color.b * ao_factor,
							base_color.a
						)
						st.set_color(vert_color)
						var vertex: Vector3 = verts[vi]
						st.add_vertex(block_pos + vertex)

	st.generate_normals()
	var mesh := st.commit()
	return mesh


func build_collision_shape(blocks: PackedByteArray, chunk_palette: Array) -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()
	var expected_size := 16 * 64 * 16
	if blocks.size() < expected_size:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		return shape

	var neighbor_offsets: Array[Vector3i] = [
		Vector3i(0, 1, 0),
		Vector3i(0, -1, 0),
		Vector3i(0, 0, -1),
		Vector3i(0, 0, 1),
		Vector3i(-1, 0, 0),
		Vector3i(1, 0, 0),
	]

	for y in range(64):
		for z in range(16):
			for x in range(16):
				var raw_id := get_block_at(blocks, x, y, z)
				var block_id := _resolve_block_id(raw_id, chunk_palette)

				if block_id == 0 or palette.is_transparent(block_id):
					continue  # Only solid blocks get collision

				var block_pos := Vector3(x, y, z)

				for face_index in range(6):
					var no: Vector3i = neighbor_offsets[face_index]
					var nx := x + no.x
					var ny := y + no.y
					var nz := z + no.z

					var neighbor_raw := get_block_at(blocks, nx, ny, nz)
					var neighbor_id := _resolve_block_id(neighbor_raw, chunk_palette)

					if palette.is_solid(neighbor_id):
						continue  # Neighbor is solid, skip this face

					var verts: Array = FACE_VERTICES[face_index]
					for vi in range(6):
						var vertex: Vector3 = verts[vi]
						faces.append(block_pos + vertex)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape
