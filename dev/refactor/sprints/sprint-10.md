# Sprint 10: Visual Polish

**Phase**: 6A, 6B, 6C
**Status**: Not Started
**Priority**: 10
**Depends on**: Sprint 1 (texture atlas support in renderer), Sprint 6 (sky/weather systems)

## Goal

Create or source a 16x16 pixel art texture atlas for all blocks. Add particle effects for breaking, torches, weather, XP, and combat. Polish sky rendering with clouds, moon phases, and weather transitions.

## Features

| Feature | Doc | Status |
|---------|-----|--------|
| Block Textures | [block-textures.md](../features/block-textures.md) | Not Started |
| Particle System | [particles-system.md](../features/particles-system.md) | Not Started |
| Sky & Weather | [sky-weather.md](../features/sky-weather.md) | Not Started |

## Files Modified

### Client
| File | Changes |
|------|---------|
| `native-client/godot/scripts/world/voxel_chunk_renderer.gd` | UV mapping from texture atlas coords, NEAREST filtering, animated texture UV offset for water/lava |
| `native-client/godot/scripts/world/block_palette.gd` | Atlas coords (top/side/bottom) per block, animation frame data |
| `native-client/godot/scripts/visual/ambient_particles.gd` | Expand: block break fragments, torch flames, water splash, lava embers, XP orbs, crit stars, potion swirls |
| `native-client/godot/scripts/visual/sky_manager.gd` | Cloud layer mesh at y=192, moon phases (8), star field, fog distance tied to render distance |
| `native-client/godot/scripts/visual/weather_system.gd` | Rain/thunder/snow with proper particles, lightning strikes, sky darkening |
| `native-client/godot/scripts/visual/day_night_cycle.gd` | Sun/moon texture meshes instead of directional light only |

### New/Modified Assets
| File | Purpose |
|------|---------|
| `native-client/godot/assets/textures/block_atlas.png` | 256x256 or 512x512 texture atlas with 16x16 tiles |
| `native-client/godot/assets/textures/particles/` | Particle textures (crack stages, flame, rain, snow, XP, etc.) |
| `native-client/godot/assets/textures/gui/` | HUD textures (hearts, hunger, armor, XP bar, hotbar) |
| `native-client/godot/assets/textures/sky/` | Sun, moon (phases), star textures |

## Acceptance Criteria

### Block Textures
- [ ] Every block has at least 1 texture (many have top/side/bottom variants)
- [ ] Atlas: 16x16 pixel tiles in power-of-2 texture
- [ ] UV mapping calculates correct atlas coords per face
- [ ] Texture filtering: NEAREST (crisp pixel art, no blur)
- [ ] Water/lava: animated UV offset cycling through frames
- [ ] Grass block: green top, dirt bottom, grass-side texture

### Particles
- [ ] Block break: colored fragments scatter outward
- [ ] Torch: flame particles flicker upward
- [ ] Water splash on player entry
- [ ] Lava embers float upward
- [ ] Rain particles during rain weather
- [ ] Snow particles during snow weather
- [ ] XP orb particles: green, float toward player on pickup
- [ ] Critical hit: star burst on impact
- [ ] Dust in caves
- [ ] Portal swirl (future)

### Sky & Weather
- [ ] Skybox gradient by time of day
- [ ] Sun: bright disc arcing across sky
- [ ] Moon: 8 phase cycle over game days
- [ ] Stars: appear at night, twinkle
- [ ] Cloud layer at y=192, slowly scrolling
- [ ] Rain: darkened sky, rain particles, wet sound
- [ ] Thunder: lightning flash, strike damage, fire start
- [ ] Snow: white particles, snow layer accumulates
- [ ] Clear/rain/thunder cycle randomly with minimum durations

## Implementation Order

1. Create or source block_atlas.png texture
2. Add atlas coords to block_palette.gd
3. Implement UV mapping in voxel_chunk_renderer.gd
4. Set texture filtering to NEAREST
5. Add water/lava UV animation
6. Create GUI textures (hearts, hunger, hotbar)
7. Implement block break particle system
8. Add torch/fire particles
9. Add weather particles (rain, snow)
10. Add XP orb and combat particles
11. Implement cloud layer mesh
12. Add moon phases
13. Add star field
14. Implement lightning strikes

## Technical Notes

- Atlas layout: 16 tiles per row, tile index = row * 16 + col
- UV per vertex: (col * tile_size, row * tile_size) to ((col+1) * tile_size, (row+1) * tile_size)
- tile_size in UV space = 1.0 / tiles_per_row (e.g., 1/16 = 0.0625)
- Animated textures: offset V coord by frame * tile_size each tick
- Particles: use GPUParticles3D for large systems (rain), CPUParticles3D for small (break)
- Cloud layer: large plane mesh with noise texture, alpha cutoff for cloud shapes, scrolls via UV offset
- Moon phases: 8 textures or 1 atlas with UV offset per phase, phase = world_day % 8
- Lightning: instantaneous bright DirectionalLight flash + spawn fire block at strike point
