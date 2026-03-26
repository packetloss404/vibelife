# Feature: Chunk Management

**Sprint**: 1
**Status**: Not Started
**Priority**: High — needed for playable render distance

## Summary

Upgrade chunk loading from the current basic radius-2 system to a configurable render distance with spiral loading, frustum culling, LOD, background mesh building, and intelligent unloading.

## Current State

`voxel_manager.gd`:
- Loads chunks in radius 2 around player (5x5 = 25 chunks)
- Single HTTP request for all chunks in radius
- LRU eviction at MAX_CHUNKS = 64
- All mesh building happens synchronously on the main thread
- No frustum culling
- No LOD

## Target State

### Render Distance

```
Configurable in settings: 4 (minimum) to 16 (maximum), default 8
Render distance 8 = 17x17 = 289 chunks loaded
Render distance 12 = 25x25 = 625 chunks loaded
MAX_CHUNKS updated to (render_distance * 2 + 1)^2 + buffer
```

### Spiral Loading Order

Load chunks in a spiral outward from the player's current chunk, so nearby chunks render first:

```gdscript
func _generate_spiral_offsets(radius: int) -> Array[Vector2i]:
    var offsets: Array[Vector2i] = [Vector2i(0, 0)]
    for ring in range(1, radius + 1):
        # Top edge: left to right
        for x in range(-ring, ring + 1):
            offsets.append(Vector2i(x, -ring))
        # Right edge: top+1 to bottom
        for z in range(-ring + 1, ring + 1):
            offsets.append(Vector2i(ring, z))
        # Bottom edge: right-1 to left
        for x in range(ring - 1, -ring - 1, -1):
            offsets.append(Vector2i(x, ring))
        # Left edge: bottom-1 to top+1
        for z in range(ring - 1, -ring, -1):
            offsets.append(Vector2i(-ring, z))
    return offsets
```

### Background Chunk Loading

Don't load all chunks in one HTTP request. Load them incrementally:

```gdscript
var chunks_to_load: Array[Vector2i] = []  # Queue of chunk coords to load
var loading_chunk: bool = false  # Is an HTTP request in flight?
const CHUNKS_PER_FRAME := 2  # Max new chunk mesh builds per frame

func _update_chunk_queue(player_chunk: Vector2i) -> void:
    # Rebuild queue when player moves to new chunk
    chunks_to_load.clear()
    for offset in spiral_offsets:
        var target := player_chunk + offset
        var key := "%d:%d" % [target.x, target.y]
        if not loaded_chunks.has(key):
            chunks_to_load.append(target)

func _process_chunk_queue() -> void:
    # Called each frame, loads up to CHUNKS_PER_FRAME
    var built := 0
    while built < CHUNKS_PER_FRAME and not chunks_to_load.is_empty():
        var chunk_coord: Vector2i = chunks_to_load.pop_front()
        _request_chunk(chunk_coord.x, chunk_coord.y)
        built += 1
```

### Frustum Culling

Skip rendering chunks outside the camera's view frustum:

```gdscript
func _is_chunk_visible(camera: Camera3D, cx: int, cz: int) -> bool:
    # Chunk AABB: from (cx*16, 0, cz*16) to ((cx+1)*16, 256, (cz+1)*16)
    var chunk_aabb := AABB(
        Vector3(cx * 16, 0, cz * 16),
        Vector3(16, 256, 16)
    )
    return camera.is_position_in_frustum(chunk_aabb.get_center())
    # Better: check if any corner of the AABB is in frustum
    # Or use camera.get_frustum() planes and test AABB against all 6
```

For frustum-culled chunks: hide the MeshInstance3D (`mesh_instance.visible = false`) but keep it loaded. Much cheaper than mesh rebuild.

### LOD (Level of Detail)

Distant chunks render with simplified meshes:

```
Distance 0-4 chunks: Full detail (greedy meshing, AO)
Distance 5-8 chunks: Reduced detail (greedy meshing, no AO)
Distance 9-12 chunks: Low detail (skip underground faces, only surface)
Distance 13+: Minimal (top surface only, single color per chunk)
```

```gdscript
func _get_lod_level(distance: int) -> int:
    if distance <= 4: return 0  # Full
    if distance <= 8: return 1  # No AO
    if distance <= 12: return 2  # Surface only
    return 3  # Minimal

func build_chunk_mesh_lod(blocks: PackedByteArray, palette: Array, lod: int) -> ArrayMesh:
    match lod:
        0: return build_chunk_mesh_greedy(blocks, palette)  # Full
        1: return build_chunk_mesh_greedy_no_ao(blocks, palette)  # Skip AO
        2: return build_chunk_mesh_surface(blocks, palette)  # Only top surface
        3: return build_chunk_mesh_minimal(blocks, palette)  # Single quad per column
```

### Intelligent Unloading

```gdscript
const UNLOAD_BUFFER := 2  # Unload chunks beyond render_distance + buffer

func _unload_distant_chunks(player_chunk: Vector2i) -> void:
    var max_dist := render_distance + UNLOAD_BUFFER
    var keys_to_remove: Array[String] = []

    for key in loaded_chunks:
        var chunk_info: Dictionary = loaded_chunks[key]
        var dx: int = abs(chunk_info.cx - player_chunk.x)
        var dz: int = abs(chunk_info.cz - player_chunk.y)
        if dx > max_dist or dz > max_dist:
            keys_to_remove.append(key)

    for key in keys_to_remove:
        _remove_chunk(key)
```

### Chunk Caching

Server caches generated chunks so repeat requests are instant:

```typescript
// Server-side: cache generated chunks
const chunkCache = new Map<string, VoxelChunkContract>()

function getOrGenerateChunk(regionId: string, cx: number, cz: number): VoxelChunkContract {
    const key = `${regionId}:${cx}:${cz}`
    if (chunkCache.has(key)) return chunkCache.get(key)!
    const chunk = generateChunk(regionId, cx, cz)
    chunkCache.set(key, chunk)
    return chunk
}
```

### API Change

Instead of loading all chunks in one request, support individual chunk requests for incremental loading:

```
GET /api/regions/:regionId/chunks/:cx/:cz?token=...
Returns: single VoxelChunkContract

GET /api/regions/:regionId/chunks?cx=&cz=&radius=  (keep existing batch endpoint)
```

## Performance Targets

| Render Distance | Chunks | Target FPS |
|----------------|--------|------------|
| 4 | 81 | 60 |
| 8 | 289 | 60 |
| 12 | 625 | 45 |
| 16 | 1089 | 30 |

## Implementation

1. Add render distance setting to client settings
2. Generate spiral offsets
3. Implement chunk loading queue with per-frame budget
4. Add individual chunk API endpoint
5. Implement frustum culling
6. Add chunk visibility toggling
7. Implement LOD levels
8. Implement intelligent unloading
9. Benchmark at various render distances
10. Add server-side chunk caching

## Notes

- Thread-safe mesh building would be ideal (Godot threads) but complex; start with main-thread budgeting
- Server should support WebSocket chunk streaming as future optimization
- Chunk modifications (block place/break) stored as deltas on top of generated terrain
- Modified chunks must be loaded from server, not regenerated
