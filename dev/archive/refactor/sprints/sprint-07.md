# Sprint 7: Sound & Audio

**Phase**: 3D
**Status**: Not Started
**Priority**: 8
**Depends on**: Sprint 1-6 (world, blocks, mobs, combat all exist to add sound to)

## Goal

Add comprehensive audio that makes the world feel alive. Block sounds, ambient audio, background music, mob sounds, UI sounds, combat sounds, and environmental audio — all with 3D positional support.

## Features

| Feature | Doc | Status |
|---------|-----|--------|
| Sound System | [sound-system.md](../features/sound-system.md) | Not Started |

## Files Modified

### Client
| File | Changes |
|------|---------|
| `native-client/godot/scripts/ui/spatial_audio.gd` | Extend for block/mob/environmental positional audio |
| `native-client/godot/scripts/world/voxel_manager.gd` | Play place/break sounds per block material |
| `native-client/godot/scripts/world/enemy_renderer.gd` | Play mob idle/hurt/death sounds |
| `native-client/godot/scripts/ui/combat_hud.gd` | Play hit, crit, level-up sounds |
| `native-client/godot/scripts/main.gd` | Footstep sounds based on block type walked on, ambient detection (cave, surface, underwater) |
| `native-client/godot/scripts/visual/weather_system.gd` | Rain/thunder audio |

### New Files
| File | Purpose |
|------|---------|
| `native-client/godot/scripts/audio/sound_manager.gd` | Central sound manager: pools AudioStreamPlayer3D nodes, manages music playlist, ambient state machine |
| `native-client/godot/assets/audio/` | Directory for all sound effect and music files |

## Acceptance Criteria

- [ ] Block sounds: unique place/break/step per material type (stone, wood, dirt, gravel, sand, glass, metal, cloth)
- [ ] Footsteps: play at walk speed, change sound by block below player
- [ ] Ambient: cave ambience underground, wind at high altitude, underwater muffle
- [ ] Music: calm background tracks with long random pauses between
- [ ] Mob sounds: zombie groans, skeleton rattles, creeper hiss, cow moo, pig oink, etc.
- [ ] UI sounds: inventory open/close, item pickup pop, level-up ding, chat blip
- [ ] Combat: sword swing, hit impact, critical ding, shield clang
- [ ] Environment: water flow, lava bubbles, fire crackle, rain, thunder
- [ ] All world sounds are 3D positional (fade with distance)
- [ ] Volume sliders per category in settings (master, music, blocks, hostile, players, ambient, weather)

## Implementation Order

1. Create sound_manager.gd with AudioStreamPlayer3D pooling
2. Add block material → sound mapping
3. Implement footstep system (detect block below, play at walk intervals)
4. Add place/break sounds to voxel_manager.gd
5. Add ambient state machine (surface/cave/underwater)
6. Add mob sounds to enemy_renderer.gd
7. Add combat sounds
8. Add UI sounds
9. Add music playlist with random pauses
10. Add weather sounds
11. Wire up volume sliders in settings

## Technical Notes

- AudioStreamPlayer3D pool: pre-allocate 16-32 players, reuse for one-shot sounds
- Music: AudioStreamPlayer (non-positional), crossfade between tracks
- Footstep interval: based on movement speed (faster sprint = faster steps)
- Cave detection: player y < surface height at current x,z position
- Block material categories: stone, wood, dirt, gravel, sand, glass, metal, cloth, snow, slime
- Use Godot's AudioBus system for per-category volume control
- Sounds loaded as .ogg (compressed) for effects, .ogg for music
