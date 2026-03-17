# Feature: Particle System

**Sprint**: 10
**Status**: Not Started
**Priority**: Medium — visual juice

## Summary

Expand the particle system for block breaking, torches, water splash, lava embers, rain, snow, XP orbs, critical hits, dust, and potion effects.

## Target State

### Particle Types

| Type | Trigger | Count | Lifetime | Behavior |
|------|---------|-------|----------|----------|
| Block break | Block destroyed | 20 | 0.8s | Colored fragments scatter outward, gravity |
| Torch flame | Torch block exists | 3-5 | 0.4s | Small orange/yellow particles drift upward |
| Water splash | Entity enters water | 15 | 0.5s | White particles burst upward |
| Lava ember | Lava block surface | 1-2 | 1.5s | Orange particles float upward slowly |
| Rain | Weather = rain | 1000+ | 0.8s | White streaks fall from sky |
| Snow | Weather = snow | 500+ | 2.0s | White dots fall slowly, drift sideways |
| XP orb | Mob killed / ore mined | 3-8 | 5.0s | Green glowing orbs, home toward player |
| Critical hit | Critical attack | 10 | 0.5s | Yellow star shapes burst from target |
| Cave dust | Underground ambiance | 5-10 | 3.0s | Slow floating specks |
| Potion effect | Active potion | 5 | 1.0s | Colored swirl around player feet |
| Smoke | Fire / furnace | 3-5 | 1.0s | Gray particles drift upward |
| Note | Noteblock played | 1 | 1.0s | Colored note icon floats up |
| Heart | Mob breeding | 3-5 | 0.8s | Red hearts float up |
| Angry | Wolf hit | 3 | 0.5s | Dark particles burst |

### Implementation

```gdscript
# Use CPUParticles3D for small one-shot effects (< 30 particles)
# Use GPUParticles3D for large continuous effects (rain, snow)

func spawn_break_particles(pos: Vector3, color: Color) -> void:
    var p := CPUParticles3D.new()
    p.position = pos + Vector3(0.5, 0.5, 0.5)
    p.emitting = true
    p.one_shot = true
    p.amount = 20
    p.lifetime = 0.8
    p.explosiveness = 1.0
    p.direction = Vector3.UP
    p.spread = 180.0
    p.initial_velocity_min = 2.0
    p.initial_velocity_max = 5.0
    p.gravity = Vector3(0, -15, 0)
    p.scale_amount_min = 0.04
    p.scale_amount_max = 0.12
    p.color = color
    p.mesh = _small_box_mesh  # Reusable tiny cube mesh
    voxels_root.add_child(p)
    _auto_free(p, 1.0)

func create_torch_particles(pos: Vector3) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.position = pos + Vector3(0.5, 0.9, 0.5)
    p.emitting = true
    p.amount = 4
    p.lifetime = 0.4
    p.direction = Vector3.UP
    p.spread = 20.0
    p.initial_velocity_min = 0.5
    p.initial_velocity_max = 1.0
    p.gravity = Vector3(0, 2, 0)  # Float upward
    p.scale_amount_min = 0.02
    p.scale_amount_max = 0.06
    p.color_ramp = _orange_to_transparent_gradient()
    return p  # Persistent, attached to torch block

func create_rain_system() -> GPUParticles3D:
    var p := GPUParticles3D.new()
    p.amount = 2000
    p.lifetime = 1.0
    p.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
    # Particle material: white elongated billboard, falls fast
    # Follows player position (re-center each frame)
    return p
```

### XP Orb Entity

Special particle-like entity that homes toward the player:

```gdscript
func spawn_xp_orbs(pos: Vector3, total_xp: int) -> void:
    var orb_count := clampi(total_xp, 1, 8)
    var xp_per_orb := total_xp / orb_count

    for i in range(orb_count):
        var orb := _create_xp_orb(xp_per_orb)
        orb.position = pos + Vector3(randf() - 0.5, 0.5, randf() - 0.5)
        # Initial burst velocity
        orb.velocity = Vector3(randf() * 2 - 1, 3.0, randf() * 2 - 1)
        world_root.add_child(orb)

# XP orbs: green glowing sphere, homes toward nearest player after 0.5s delay
# On pickup: add XP, play sound, remove orb
```

## Files Modified

| File | Changes |
|------|---------|
| `ambient_particles.gd` | Expand with all particle types |
| `voxel_manager.gd` | Trigger break particles |
| `enemy_renderer.gd` | Death particles, damage particles |
| `weather_system.gd` | Rain/snow particles |

## Acceptance Criteria

- [ ] Block break: colored fragments scatter
- [ ] Torch: small flame particles
- [ ] Water splash on entry
- [ ] Rain particles during rain weather
- [ ] Snow particles during snow
- [ ] XP orbs home toward player
- [ ] Critical hit star burst
- [ ] Cave dust when underground
- [ ] All particles correctly lit and sized
- [ ] Performance: rain/snow don't drop FPS below 50
