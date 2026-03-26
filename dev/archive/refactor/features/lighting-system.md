# Feature: Lighting System

**Sprint**: 6
**Status**: Not Started
**Priority**: Medium-High

## Summary

Add block-based lighting with two channels (sky light and block light). BFS flood-fill propagation from light sources. Light levels affect vertex brightness and mob spawning. Smooth lighting interpolates values across faces.

## Target State

### Light Data Structure

```
Each block has two light values (4 bits each, packed into 1 byte):
  - Sky light: 0-15 (from the sun, attenuates under solid blocks)
  - Block light: 0-15 (from torches, glowstone, lava, etc.)

Effective light = max(sky_light * time_factor, block_light)
  time_factor: 1.0 at noon, 0.2 at midnight

Storage: separate PackedByteArray per chunk (16*256*16 = 65536 nibble pairs = 32768 bytes)
Or: two PackedByteArrays (sky_light[], block_light[]) of 65536 bytes each for simplicity
```

### Sky Light Propagation

```gdscript
# Sky light starts at 15 at the top of each column
# Propagates downward through air (no reduction)
# When hitting a solid block, stops
# Spreads horizontally with -1 per block

func _compute_sky_light(blocks: PackedByteArray) -> PackedByteArray:
    var sky_light := PackedByteArray()
    sky_light.resize(16 * 256 * 16)

    # Phase 1: vertical propagation (fast)
    for x in range(16):
        for z in range(16):
            var light := 15
            for y in range(255, -1, -1):
                var block_id := get_block_at(blocks, x, y, z)
                if palette.is_opaque(block_id):
                    light = 0  # Fully blocked
                elif palette.is_transparent(block_id) and light > 0:
                    pass  # Light passes through (leaves, glass reduce by 1)
                sky_light[y * 256 + z * 16 + x] = light

    # Phase 2: horizontal BFS spread
    _bfs_spread_light(sky_light, blocks)

    return sky_light
```

### Block Light Propagation

```gdscript
func _compute_block_light(blocks: PackedByteArray) -> PackedByteArray:
    var block_light := PackedByteArray()
    block_light.resize(16 * 256 * 16)

    # Find all light sources
    var sources: Array[Vector3i] = []
    for y in range(256):
        for z in range(16):
            for x in range(16):
                var block_id := get_block_at(blocks, x, y, z)
                var emission := palette.get_light_level(block_id)
                if emission > 0:
                    var idx := y * 256 + z * 16 + x
                    block_light[idx] = emission
                    sources.append(Vector3i(x, y, z))

    # BFS spread from all sources simultaneously
    _bfs_spread_light(block_light, blocks)

    return block_light
```

### BFS Light Spread

```gdscript
func _bfs_spread_light(light_data: PackedByteArray, blocks: PackedByteArray) -> void:
    var queue: Array[Vector3i] = []

    # Seed queue with all non-zero light cells
    for y in range(256):
        for z in range(16):
            for x in range(16):
                var idx := y * 256 + z * 16 + x
                if light_data[idx] > 0:
                    queue.append(Vector3i(x, y, z))

    # BFS: spread light to neighbors, reducing by 1 each step
    var neighbors := [
        Vector3i(1,0,0), Vector3i(-1,0,0),
        Vector3i(0,1,0), Vector3i(0,-1,0),
        Vector3i(0,0,1), Vector3i(0,0,-1)
    ]

    while not queue.is_empty():
        var pos: Vector3i = queue.pop_front()
        var idx := pos.y * 256 + pos.z * 16 + pos.x
        var current_light: int = light_data[idx]

        if current_light <= 1:
            continue

        for n in neighbors:
            var nx := pos.x + n.x
            var ny := pos.y + n.y
            var nz := pos.z + n.z

            if nx < 0 or nx >= 16 or ny < 0 or ny >= 256 or nz < 0 or nz >= 16:
                continue

            var nidx := ny * 256 + nz * 16 + nx
            var neighbor_block := get_block_at(blocks, nx, ny, nz)

            if palette.is_opaque(neighbor_block):
                continue  # Light doesn't pass through opaque blocks

            var new_light := current_light - 1
            if new_light > light_data[nidx]:
                light_data[nidx] = new_light
                queue.append(Vector3i(nx, ny, nz))
```

### Applying Light to Rendering

```gdscript
# In voxel_chunk_renderer.gd, when adding vertices:
func _get_vertex_brightness(x: int, y: int, z: int, face_normal: Vector3i) -> float:
    # Sample light at the block adjacent to this face
    var lx := x + face_normal.x
    var ly := y + face_normal.y
    var lz := z + face_normal.z

    var sky: int = sky_light_data[_light_index(lx, ly, lz)]
    var block: int = block_light_data[_light_index(lx, ly, lz)]

    var effective_sky := float(sky) * time_of_day_factor
    var effective := max(effective_sky, float(block))
    var brightness := effective / 15.0

    # Minimum ambient (so pitch black caves still have faint visibility)
    return max(brightness, 0.05)

# Apply to vertex color:
var ao := _compute_ao(...)
var light := _get_vertex_brightness(x, y, z, face_normal_i)
var final_brightness := ao * light
st.set_color(Color(final_brightness, final_brightness, final_brightness, 1.0))
```

### Light Updates on Block Changes

```gdscript
# When a block is placed or broken, recalculate lighting in affected area
func _update_lighting_around(x: int, y: int, z: int, radius: int) -> void:
    # Clear light values in radius
    # Re-propagate from all light sources in radius + 15
    # Rebuild affected chunk meshes
    pass
```

## Files Created

| File | Purpose |
|------|---------|
| `lighting_manager.gd` | Sky/block light computation, BFS, updates |

## Files Modified

| File | Changes |
|------|---------|
| `voxel_chunk_renderer.gd` | Apply light levels to vertex brightness |
| `voxel_manager.gd` | Store light data per chunk, trigger light updates on block changes |
| `block_palette.gd` | Add `get_light_level()`, `is_opaque()` methods |

## Acceptance Criteria

- [ ] Torches emit light (level 14) that brightens surrounding blocks
- [ ] Caves are dark without torches
- [ ] Sky light: bright outside, dark under solid blocks
- [ ] Light reduces by 1 per block distance from source
- [ ] Placing a torch immediately lights the area
- [ ] Breaking a torch immediately darkens the area
- [ ] Time of day affects sky light brightness
- [ ] Smooth lighting: light interpolated across faces
- [ ] Hostile mobs spawn where light < 7
