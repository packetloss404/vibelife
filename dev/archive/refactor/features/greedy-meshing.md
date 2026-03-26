# Feature: Greedy Meshing

**Sprint**: 1
**Status**: Not Started
**Priority**: Critical — required for performance

## Summary

Replace per-block face rendering with greedy meshing algorithm. Merge adjacent coplanar faces of the same block type into larger quads, reducing vertex count by ~80% on typical terrain.

## Current State

`voxel_chunk_renderer.gd` `build_chunk_mesh()` emits 6 vertices per visible face, per block. A chunk with 1000 visible faces = 6000 vertices. Dense terrain can produce 20,000+ vertices per chunk, causing FPS issues at large render distances.

## Target State

### Algorithm: Greedy Meshing

For each of the 6 face directions, for each layer (slice) perpendicular to that direction:

```
1. Create a 2D mask of faces that need rendering in this slice
   - mask[x][y] = block_id if face is visible, 0 if hidden or air

2. Greedy merge:
   For each unvisited cell in the mask:
     a. Find the widest run of matching block_id in the current row
     b. Extend downward: find how many subsequent rows have the same run width and block_id
     c. Emit one quad for the entire merged rectangle
     d. Mark all merged cells as visited

3. Each merged quad becomes 2 triangles (6 vertices) instead of
   potentially dozens of individual face quads
```

### Pseudocode

```gdscript
func build_chunk_mesh_greedy(blocks: PackedByteArray, chunk_palette: Array) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    for face_index in range(6):
        var axis := _get_face_axis(face_index)      # 0=X, 1=Y, 2=Z
        var direction := _get_face_direction(face_index)  # +1 or -1

        # Determine slice range for this axis
        var slice_count := 256 if axis == 1 else 16  # Y is 256, X/Z are 16
        var u_count := _get_u_count(face_index)  # width of the 2D slice
        var v_count := _get_v_count(face_index)  # height of the 2D slice

        for slice in range(slice_count):
            # Build 2D mask for this slice
            var mask: Array = []  # u_count x v_count, stores block_id or 0
            for u in range(u_count):
                mask.append([])
                for v in range(v_count):
                    var block_pos := _slice_to_world(face_index, slice, u, v)
                    var raw_id := get_block_at(blocks, block_pos.x, block_pos.y, block_pos.z)
                    var block_id := _resolve_block_id(raw_id, chunk_palette)

                    if block_id == 0:
                        mask[u].append(0)
                        continue

                    # Check neighbor in face direction
                    var neighbor_pos := block_pos + FACE_NORMALS[face_index]
                    var neighbor_raw := get_block_at(blocks, neighbor_pos.x, neighbor_pos.y, neighbor_pos.z)
                    var neighbor_id := _resolve_block_id(neighbor_raw, chunk_palette)

                    if neighbor_id == 0 or (palette.is_transparent(neighbor_id) and neighbor_id != block_id):
                        mask[u].append(block_id)
                    else:
                        mask[u].append(0)

            # Greedy merge the mask
            var visited := []  # u_count x v_count bools
            for u in range(u_count):
                visited.append([])
                for v in range(v_count):
                    visited[u].append(false)

            for u in range(u_count):
                for v in range(v_count):
                    if visited[u][v] or mask[u][v] == 0:
                        continue

                    var block_id: int = mask[u][v]

                    # Find width (extend in u direction)
                    var width := 1
                    while u + width < u_count and mask[u + width][v] == block_id and not visited[u + width][v]:
                        width += 1

                    # Find height (extend in v direction)
                    var height := 1
                    var can_extend := true
                    while v + height < v_count and can_extend:
                        for du in range(width):
                            if mask[u + du][v + height] != block_id or visited[u + du][v + height]:
                                can_extend = false
                                break
                        if can_extend:
                            height += 1

                    # Emit quad for this merged rectangle
                    _emit_greedy_quad(st, face_index, slice, u, v, width, height, block_id)

                    # Mark visited
                    for du in range(width):
                        for dv in range(height):
                            visited[u + du][v + dv] = true

    st.generate_normals()
    return st.commit()
```

### Quad Emission

```gdscript
func _emit_greedy_quad(st: SurfaceTool, face_index: int, slice: int,
    u: int, v: int, width: int, height: int, block_id: int) -> void:

    var color := palette.get_block_color(block_id)
    var normal: Vector3 = FACE_NORMALS[face_index]

    # Calculate 4 corner positions in world space
    var corners: Array[Vector3] = _get_quad_corners(face_index, slice, u, v, width, height)

    st.set_normal(normal)

    # AO: compute per-corner (4 corners, interpolated across quad)
    # For greedy meshes, use corner AO values

    # Triangle 1: corners[0], corners[1], corners[2]
    st.set_color(color); st.add_vertex(corners[0])
    st.set_color(color); st.add_vertex(corners[1])
    st.set_color(color); st.add_vertex(corners[2])

    # Triangle 2: corners[0], corners[2], corners[3]
    st.set_color(color); st.add_vertex(corners[0])
    st.set_color(color); st.add_vertex(corners[2])
    st.set_color(color); st.add_vertex(corners[3])
```

### AO with Greedy Meshing

Greedy meshing complicates AO because merged quads span multiple blocks. Two options:

1. **Don't merge faces with different AO values** — keeps visual quality, reduces merge opportunities by ~20%
2. **Per-vertex AO at quad corners only** — slightly less accurate but maximal merging

Recommend option 1 for quality: modify the mask to encode `(block_id, ao_corner_values)` and only merge adjacent cells with matching AO.

### Collision Shape (also greedy)

Apply the same greedy algorithm to `build_collision_shape()`:

```gdscript
func build_collision_shape_greedy(blocks: PackedByteArray, chunk_palette: Array) -> ConcavePolygonShape3D:
    # Same greedy algorithm but for solid blocks only
    # Output: PackedVector3Array of triangle vertices
    # Greedy merging here is even more important — collision with 20k triangles is slow
```

## Performance Targets

| Metric | Current (per-face) | Target (greedy) |
|--------|-------------------|-----------------|
| Vertices per chunk (flat terrain) | ~6,000 | ~600 |
| Vertices per chunk (hilly terrain) | ~15,000 | ~3,000 |
| Vertices per chunk (cave-heavy) | ~25,000 | ~5,000 |
| Mesh build time | ~10ms | ~20ms (acceptable tradeoff) |
| Draw calls | 1 per chunk | 1 per chunk (same) |

## Implementation

1. Add helper functions: `_get_face_axis`, `_slice_to_world`, `_get_quad_corners`
2. Implement greedy mask builder for one face direction
3. Implement greedy merge algorithm
4. Implement quad emission with correct winding order
5. Handle AO (option 1: split by AO values)
6. Apply to all 6 face directions
7. Apply to collision shape builder
8. Benchmark: compare vertex counts before/after
9. Test visual correctness: no missing faces, no z-fighting

## Notes

- Greedy meshing is THE biggest performance win for voxel rendering
- The mesh build time increases but total frame time decreases massively due to fewer vertices to render
- When texture atlas is added (Sprint 10), greedy merging must also consider texture — only merge faces with same texture
- Transparent blocks should be in a separate pass (don't merge with opaque)
