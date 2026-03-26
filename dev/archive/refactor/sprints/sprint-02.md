# Sprint 2: Player & Camera

**Phase**: 1C, 1D
**Status**: Not Started
**Priority**: 2
**Depends on**: Sprint 1 (voxel world exists to stand on)

## Goal

Replace the colored capsule avatar with a blocky Minecraft-style character model. Switch from orbit camera to first-person mouse-look as default. Add crosshair, head tracking, and walking/mining animations.

## Features

| Feature | Doc | Status |
|---------|-----|--------|
| Blocky Player Model | [player-model.md](../features/player-model.md) | Not Started |
| First-Person Camera | [first-person-camera.md](../features/first-person-camera.md) | Not Started |

## Files Modified

### Client
| File | Changes |
|------|---------|
| `native-client/godot/scripts/world/avatar_manager.gd` | Replace capsule mesh with blocky Steve model, add animation system, skin texture support |
| `native-client/godot/scripts/camera/camera_controller.gd` | First-person default, mouse look, F5 toggle, collision detection for third-person, bob animation |
| `native-client/godot/scripts/main.gd` | Mouse capture on click, Escape to release, crosshair overlay, F5 input handling |
| `native-client/godot/scenes/main.tscn` | Adjust CameraRig default position to player head height |

## Acceptance Criteria

- [ ] Player is a blocky Steve-style model (head, body, arms, legs)
- [ ] Other players also render as blocky models
- [ ] Walking animation: arms and legs swing
- [ ] Camera defaults to first-person (inside player head)
- [ ] Mouse controls look direction (pitch clamped ±90°, yaw unlimited)
- [ ] Mouse captured on click, released on Escape
- [ ] F5 cycles: first-person → third-person back → third-person front
- [ ] Third-person camera has scroll-wheel distance and block collision
- [ ] White crosshair + centered on screen in first-person
- [ ] Camera bobs slightly when walking
- [ ] Player head follows camera pitch (visible to other players)
- [ ] Name tag Label3D above other players' heads
- [ ] FOV configurable (60-110°, default 70)

## Implementation Order

1. Implement blocky character mesh generator in avatar_manager.gd
2. Add arm/leg swing animation system
3. Refactor camera_controller.gd to first-person default
4. Add mouse capture/release logic in main.gd
5. Add crosshair overlay to HUD
6. Implement F5 camera mode cycling
7. Add third-person collision detection
8. Add camera bob animation
9. Add head pitch sync for multiplayer
10. Add name tag Label3D

## Technical Notes

- Player model built from 6 box meshes (head, body, 2 arms, 2 legs)
- Each body part is a MeshInstance3D child of a root Node3D
- Animation is simple rotation of arm/leg pivots (sin wave based on walk speed)
- Skin texture: 64x64 PNG mapped to UV coords on each body part
- First-person: hide local player's head and body, show only arm
- Camera position: player position + Vector3(0, 1.62, 0) for eye height
- Mouse sensitivity stored in client settings
