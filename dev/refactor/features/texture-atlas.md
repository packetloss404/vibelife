# Feature: Texture Atlas

**Sprint**: 1 (foundation), Sprint 10 (actual textures)
**Status**: Not Started
**Priority**: High — UV infrastructure in Sprint 1, actual textures in Sprint 10

## Summary

Replace vertex-color rendering with UV-mapped textures from a texture atlas. Each block face maps to a 16x16 pixel region in the atlas. Support per-face textures (e.g., grass block: green top, dirt bottom, grass-dirt side) and animated textures (water, lava).

## Current State

`voxel_chunk_renderer.gd` uses `SurfaceTool.set_color()` with vertex colors. Material is `StandardMaterial3D` with `vertex_color_use_as_albedo = true`. No UV mapping exists.

## Target State

### Atlas Layout

```
Atlas size: 512x512 pixels (32x32 grid of 16x16 tiles)
Tile size in UV space: 1.0 / 32 = 0.03125

Tile index to UV:
  col = index % 32
  row = index / 32
  uv_min = Vector2(col * 0.03125, row * 0.03125)
  uv_max = Vector2((col + 1) * 0.03125, (row + 1) * 0.03125)
```

### Per-Face UV Mapping

Each block defines 3 texture indices: `tex_top`, `tex_side`, `tex_bottom`.

```gdscript
func _get_face_texture_index(block_id: int, face_index: int) -> int:
    var block_data: Dictionary = block_types[block_id]
    match face_index:
        0: return block_data.tex_top      # Up
        1: return block_data.tex_bottom   # Down
        _: return block_data.tex_side     # North, South, East, West
```

### UV Calculation per Vertex

For a standard (non-greedy) face:
```gdscript
# Each face is a unit quad, UV maps to one tile in the atlas
const FACE_UVS := [
    Vector2(0, 0), Vector2(0, 1), Vector2(1, 1),  # Triangle 1
    Vector2(0, 0), Vector2(1, 1), Vector2(1, 0),  # Triangle 2
]

func _add_face_with_uv(st: SurfaceTool, face_index: int, block_pos: Vector3,
    block_id: int, ao_factors: Array) -> void:

    var tex_index := _get_face_texture_index(block_id, face_index)
    var col: int = tex_index % 32
    var row: int = tex_index / 32
    var tile_size := 1.0 / 32.0

    var uv_origin := Vector2(col * tile_size, row * tile_size)

    var normal: Vector3 = FACE_NORMALS[face_index]
    st.set_normal(normal)

    var verts: Array = FACE_VERTICES[face_index]
    for vi in range(6):
        var base_uv: Vector2 = FACE_UVS[vi]
        var uv := uv_origin + base_uv * tile_size
        st.set_uv(uv)

        # Still apply AO via vertex color (white * ao_factor)
        var ao: float = ao_factors[vi]
        st.set_color(Color(ao, ao, ao, 1.0))

        st.add_vertex(block_pos + verts[vi])
```

### UV with Greedy Meshing

For greedy-merged quads larger than 1x1, UV must tile:
```gdscript
# Merged quad is width x height blocks
# UV should tile the texture across the quad
func _add_greedy_quad_with_uv(st: SurfaceTool, ..., width: int, height: int,
    block_id: int, face_index: int) -> void:

    var tex_index := _get_face_texture_index(block_id, face_index)
    var col: int = tex_index % 32
    var row: int = tex_index / 32
    var tile_size := 1.0 / 32.0

    var uv_origin := Vector2(col * tile_size, row * tile_size)

    # UV spans width and height tiles
    # Corner UVs: (0,0), (width,0), (width,height), (0,height)
    # But clamped within the single tile using REPEAT texture wrap
    # OR: use a trick — set UV to tile coords and let texture repeat handle it

    # Actually: for atlas textures, tiling doesn't work with standard UV repeat
    # Solution: clamp to single tile UVs and let the shader handle tiling
    # OR: don't greedy-merge when using texture atlas (lose performance)
    # OR: use array textures instead of atlas

    # Best approach: Use TextureArray (Texture2DArray) instead of atlas
    # Each block face texture is a layer in the array
    # UV.xy is the tile coords (0-width, 0-height), texture layer is the block texture
    # This allows tiling naturally
```

### Material Setup

```gdscript
# Option A: Atlas with NEAREST filtering
var material := StandardMaterial3D.new()
material.albedo_texture = preload("res://assets/textures/block_atlas.png")
material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
material.vertex_color_use_as_albedo = false  # Use texture, not vertex color
# But vertex color still used for AO darkening:
material.vertex_color_use_as_albedo = true  # Multiply texture by vertex color

# Option B: Texture2DArray with custom shader (better for greedy meshing)
# Requires a ShaderMaterial with a custom fragment shader
```

### Animated Textures

Water and lava cycle through animation frames:

```gdscript
# Water: 32 frames of 16x16, laid out vertically in the atlas
# Each frame is one row below the base texture
var water_frame := 0
var water_timer := 0.0
const WATER_FRAME_TIME := 0.05  # 20 FPS animation

func _update_water_animation(delta: float) -> void:
    water_timer += delta
    if water_timer >= WATER_FRAME_TIME:
        water_timer -= WATER_FRAME_TIME
        water_frame = (water_frame + 1) % 32
        # Update material uniform or rebuild affected chunk meshes
        # Better: use shader uniform for UV offset
```

### Shader Approach (recommended for greedy + tiling)

```glsl
// Custom shader for voxel rendering
shader_type spatial;

uniform sampler2DArray block_textures;  // All block textures as array layers
uniform float water_frame;

// Vertex attributes
varying flat int texture_layer;

void fragment() {
    // UV is in tile space (0..width, 0..height), wraps naturally
    vec2 uv = fract(UV);  // Repeats per block
    ALBEDO = texture(block_textures, vec3(uv, float(texture_layer))).rgb;
    ALBEDO *= COLOR.rgb;  // Multiply by AO vertex color
}
```

## Implementation Plan (Sprint 1 — UV infrastructure)

1. Add `tex_top`, `tex_side`, `tex_bottom` fields to block_palette.gd
2. Add UV mapping to `build_chunk_mesh()` (or greedy variant)
3. Create placeholder atlas (solid colors matching current vertex colors)
4. Set material to use atlas texture with NEAREST filtering
5. Verify rendering looks identical to current vertex-color approach

## Implementation Plan (Sprint 10 — actual textures)

1. Create or source 16x16 pixel art textures for all 60+ blocks
2. Pack into atlas PNG
3. Map atlas indices in block_palette.gd
4. Add water/lava animation
5. Test visual quality

## Notes

- NEAREST texture filtering is critical — it gives the crisp Minecraft pixel art look
- Half-pixel UV bleeding: add 0.5px inset to UV coords to prevent atlas bleeding at edges
- For greedy meshing + atlas, Texture2DArray is superior to a single atlas image
- AO stays as vertex color multiplication even with textures
- Transparent blocks (glass, water, leaves) need `ALPHA` in the shader
