# Feature: Block Textures

**Sprint**: 10
**Status**: Not Started
**Priority**: Medium — final visual polish

## Summary

Create or source a 16x16 pixel art texture atlas for all 60+ blocks. Map UV coords in the renderer. Use NEAREST filtering for crisp Minecraft-style visuals. Add animated textures for water and lava.

## Target State

### Atlas Specification

```
Size: 512x512 pixels
Grid: 32x32 tiles of 16x16 pixels each
Total capacity: 1024 tile slots
Format: PNG with alpha channel
Filtering: NEAREST (no interpolation)
```

### Tile Assignments (partial)

```
Row 0: stone, cobblestone, dirt, grass_top, grass_side, sand, gravel, clay
Row 1: sandstone_top, sandstone_side, snow, ice, obsidian, bedrock, netherrack, end_stone
Row 2: oak_log_top, oak_log_side, oak_planks, birch_log_top, birch_log_side, birch_planks...
Row 3: granite, diorite, andesite, smooth_stone, stone_bricks, mossy_stone_bricks...
Row 4: coal_ore, iron_ore, gold_ore, diamond_ore, emerald_ore, crystal_ore...
Row 5: bricks, nether_bricks, quartz_top, quartz_side, prismarine...
Row 6: oak_leaves, birch_leaves, spruce_leaves, jungle_leaves, tall_grass, flowers...
Row 7: water_frame_0, water_frame_1, ..., water_frame_7
Row 8: lava_frame_0, lava_frame_1, ..., lava_frame_7
Row 9: crafting_table_top, crafting_table_side, furnace_front, furnace_side, chest_front...
Row 10: torch, glass, door_top, door_bottom, ladder...
Row 11+: crack_stage_0 through crack_stage_9
```

### UV Mapping in Renderer

```gdscript
const ATLAS_SIZE := 32  # 32 tiles per row/column
const TILE_UV := 1.0 / 32.0  # 0.03125

func _get_tile_uv(tile_index: int) -> Vector2:
    var col: int = tile_index % ATLAS_SIZE
    var row: int = tile_index / ATLAS_SIZE
    return Vector2(float(col) * TILE_UV, float(row) * TILE_UV)

func _add_face_uvs(st: SurfaceTool, tile_index: int, face_uvs: Array) -> void:
    var origin := _get_tile_uv(tile_index)
    # Half-pixel inset to prevent bleeding
    var inset := 0.5 / 512.0  # 0.5 pixels in UV space
    for uv in face_uvs:
        var final_uv := origin + Vector2(
            lerp(inset, TILE_UV - inset, uv.x),
            lerp(inset, TILE_UV - inset, uv.y)
        )
        st.set_uv(final_uv)
```

### Material Setup

```gdscript
func _create_voxel_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = preload("res://assets/textures/block_atlas.png")
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    mat.vertex_color_use_as_albedo = true  # AO and lighting via vertex color
    # Vertex color multiplies texture color
    return mat
```

### Animated Textures

```gdscript
var water_frame := 0
var lava_frame := 0
var anim_timer := 0.0

func _update_animated_textures(delta: float) -> void:
    anim_timer += delta
    if anim_timer >= 0.1:  # 10 FPS animation
        anim_timer -= 0.1
        water_frame = (water_frame + 1) % 8
        lava_frame = (lava_frame + 1) % 8
        # Option A: Rebuild meshes containing water/lava (expensive)
        # Option B: Use shader uniform for UV offset (preferred)
        # Option C: Use Texture2DArray with animated layers
```

## Files Modified

| File | Changes |
|------|---------|
| `voxel_chunk_renderer.gd` | Add UV mapping, use atlas material |
| `block_palette.gd` | Atlas tile indices per block (top/side/bottom) |

## Assets Created

| File | Purpose |
|------|---------|
| `assets/textures/block_atlas.png` | 512x512 texture atlas |

## Acceptance Criteria

- [ ] Every block has proper 16x16 pixel art texture
- [ ] Per-face textures (grass: green top, dirt bottom, mixed side)
- [ ] NEAREST filtering (crisp pixels, no blur)
- [ ] No UV bleeding at tile edges
- [ ] Water and lava have frame animation
- [ ] AO still applies via vertex color multiplication
- [ ] Performance: no FPS impact vs vertex-color rendering
