# Sprint 1: Voxel World Foundation

**Phase**: 1A, 1B
**Status**: Not Started
**Priority**: 1 (highest — everything builds on this)
**Depends on**: Nothing

## Goal

Replace the flat ground plane with a fully procedural voxel world. Expand from 12 block types to 60+. Implement greedy meshing and texture atlas rendering so chunks are performant and look like Minecraft.

## Features

| Feature | Doc | Status |
|---------|-----|--------|
| Procedural Terrain Generation | [terrain-generation.md](../features/terrain-generation.md) | Not Started |
| Block Types Expansion | [block-types.md](../features/block-types.md) | Not Started |
| Greedy Meshing | [greedy-meshing.md](../features/greedy-meshing.md) | Not Started |
| Texture Atlas | [texture-atlas.md](../features/texture-atlas.md) | Not Started |
| Chunk Management | [chunk-management.md](../features/chunk-management.md) | Not Started |

## Files Modified

### Server
| File | Changes |
|------|---------|
| `src/world/voxel-service.ts` | Procedural world gen, biomes, caves, ores, trees, seed-based deterministic generation, height 64→256 |
| `src/contracts.ts` | Update `BlockTypeContract` with texture coords, tool_type, drop_id, light_level. Update `VoxelChunkContract` for 256 height |
| `src/world/store.ts` | Re-export any new helpers |

### Client
| File | Changes |
|------|---------|
| `native-client/godot/scripts/world/voxel_chunk_renderer.gd` | Greedy meshing, UV mapping from texture atlas, two-pass transparent rendering |
| `native-client/godot/scripts/world/voxel_manager.gd` | Render distance 8-12, spiral chunk loading, frustum culling, LOD, background loading |
| `native-client/godot/scripts/world/block_palette.gd` | Expand to 60+ blocks, add texture atlas coords, per-face texture indices |
| `native-client/godot/scripts/world/terrain_manager.gd` | **DELETE** — voxel system replaces terrain |
| `native-client/godot/scripts/world/biome_manager.gd` | Refactor: client-side biome visuals (fog color, particle tint) based on server biome data |
| `native-client/godot/scenes/main.tscn` | Remove Ground node, remove terrain references |
| `native-client/godot/scripts/main.gd` | Remove terrain_manager init, update chunk loading in _process |

### New Files
| File | Purpose |
|------|---------|
| `native-client/godot/assets/textures/block_atlas.png` | 16x16 pixel art texture atlas (256x256 or 512x512) |

## Acceptance Criteria

- [ ] Standing in a generated world with hills, valleys, and flat plains
- [ ] Underground caves visible when mining down
- [ ] Ores appear at correct depth ranges
- [ ] Trees spawn on surface in forest biomes
- [ ] Water fills below sea level (y=32 or y=64 for 256-height)
- [ ] Bedrock at y=0
- [ ] At least 60 block types defined with colors (textures come in Sprint 10)
- [ ] Chunks render with greedy meshing (vertex count < 10k per chunk)
- [ ] 8-chunk render distance at 60 FPS
- [ ] Chunks load in spiral pattern from player position
- [ ] Chunks beyond render distance + 2 are unloaded
- [ ] World is deterministic from seed (same seed = same world)

## Implementation Order

1. Expand block_palette.gd to 60+ blocks (quick, unblocks everything)
2. Implement procedural terrain gen in voxel-service.ts (server-side)
3. Update VoxelChunkContract for 256 height
4. Implement greedy meshing in voxel_chunk_renderer.gd
5. Implement spiral chunk loading in voxel_manager.gd
6. Remove terrain_manager.gd and Ground node
7. Add frustum culling and LOD
8. Test performance and optimize

## Technical Notes

- Chunk size stays 16×16 horizontal, but height goes from 64 to 256
- Block index formula: `y * 256 + z * 16 + x` (same as now, 256 = 16*16)
- For 256 height: total blocks per chunk = 16 * 256 * 16 = 65,536 bytes
- Greedy meshing reduces faces by ~80% on average terrain
- Server generates chunks lazily on first request, caches them
- World seed stored per region in region config
- Biome is determined by 2D noise at chunk level, affects block composition
