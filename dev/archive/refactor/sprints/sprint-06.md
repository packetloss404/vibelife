# Sprint 6: World Systems

**Phase**: 3A, 3B, 3C
**Status**: Not Started
**Priority**: 5
**Depends on**: Sprint 1 (voxel world), Sprint 2 (player model)

## Goal

Implement a 20-minute day/night cycle with mob spawning tied to light levels. Add block-based lighting with BFS propagation. Replace Godot physics with custom AABB voxel collision for player movement including gravity, jumping, sprinting, sneaking, and swimming.

## Features

| Feature | Doc | Status |
|---------|-----|--------|
| Day/Night Cycle | [day-night-cycle.md](../features/day-night-cycle.md) | Not Started |
| Lighting System | [lighting-system.md](../features/lighting-system.md) | Not Started |
| Voxel Physics | [voxel-physics.md](../features/voxel-physics.md) | Not Started |

## Files Modified

### Server
| File | Changes |
|------|---------|
| `src/world/voxel-service.ts` | Store light levels per block, recalculate on block change, include in chunk data |
| `src/contracts.ts` | Add world_time to region state, light data in VoxelChunkContract |
| `src/server.ts` | Broadcast world_time updates, add time tick loop |

### Client
| File | Changes |
|------|---------|
| `native-client/godot/scripts/visual/day_night_cycle.gd` | 20-min cycle synced to server time, sun/moon mesh orbit, sky gradient, stars at night |
| `native-client/godot/scripts/visual/sky_manager.gd` | Time-based sky colors, cloud layer at y=192 |
| `native-client/godot/scripts/world/voxel_chunk_renderer.gd` | Apply light levels to vertex colors (brightness multiplier) |
| `native-client/godot/scripts/main.gd` | Replace Godot CharacterBody physics with custom AABB movement, add sprint/sneak/swim states |
| `native-client/godot/scripts/camera/camera_controller.gd` | Sprint FOV widening, underwater FOV, bob intensity tied to sprint |

### New Files
| File | Purpose |
|------|---------|
| `native-client/godot/scripts/world/lighting_manager.gd` | BFS light propagation, sky light, block light, recalculation on changes |
| `native-client/godot/scripts/world/voxel_physics.gd` | AABB collision against voxel grid, gravity, step-up, all movement states |

## Acceptance Criteria

### Day/Night
- [ ] 20-minute full cycle (10 day, 1.5 sunset, 7 night, 1.5 sunrise)
- [ ] Sun and moon meshes orbit across the sky
- [ ] Sky gradient transitions smoothly
- [ ] Stars visible at night
- [ ] Hostile mobs spawn during night / in dark areas
- [ ] Server tracks and broadcasts world time
- [ ] Bed block skips to dawn when all players sleep

### Lighting
- [ ] Torches emit light level 14, propagates outward
- [ ] Sky light: 15 at surface, attenuates under solid blocks
- [ ] BFS flood-fill propagation
- [ ] Light recalculates when blocks placed/broken
- [ ] Vertex colors darkened by light level (dark caves, lit interiors)
- [ ] Smooth lighting: interpolated across block faces

### Physics
- [ ] Player AABB: 0.6 × 1.8 × 0.6
- [ ] Gravity: 28 blocks/s² acceleration
- [ ] Jump: 1.25 block height
- [ ] Sprint: Ctrl, 1.3x speed, wider FOV
- [ ] Sneak: Shift, 0.3x speed, no edge fall
- [ ] Swimming: space to rise in water, slow movement
- [ ] Ladder climbing: W against ladder blocks
- [ ] Step-up: auto-climb 0.5-block ledges (slabs, stairs)
- [ ] No clipping through blocks at any speed
- [ ] Knockback applies on damage

## Implementation Order

1. Implement voxel_physics.gd (AABB movement is foundational)
2. Wire up AABB physics in main.gd, remove Godot physics dependency
3. Add sprint, sneak, swim, ladder states
4. Refactor day_night_cycle.gd for 20-min cycle
5. Add sun/moon meshes and sky gradients
6. Sync world time from server
7. Implement lighting_manager.gd with BFS
8. Apply light levels to chunk vertex colors
9. Tie mob spawning to light levels
10. Add bed sleep-skip mechanic

## Technical Notes

- AABB collision: sweep test player box against all occupied blocks in movement path
- Step-up: if blocked horizontally and block above is air, auto-lift player 1 block
- Water detection: check if player head block is water type
- Sprint stops when: hunger < 6, collision, entering water, sneaking
- Light propagation: separate sky-light and block-light channels, take max for final value
- Light data: could be stored as nibbles (4 bits per block = 2 blocks per byte) to save memory
- Day/night light: sky light multiplied by time-of-day factor (1.0 noon, 0.2 midnight)
