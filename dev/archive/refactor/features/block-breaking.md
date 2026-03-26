# Feature: Block Breaking (Hold-to-Mine)

**Sprint**: 3
**Status**: Not Started
**Priority**: High — core gameplay

## Summary

Replace instant-click block breaking with hold-to-mine. Break time depends on block hardness and tool type. Show a 10-stage crack overlay on the block being mined. Spawn particles on break and drop an item entity.

## Current State

`voxel_manager.gd`:
- Left-click instantly places a block
- Right-click instantly breaks a block
- No mining duration, no crack overlay, no particles, no drops
- `break_block()` sends HTTP DELETE immediately

## Target State

### Mining State Machine

```gdscript
var mining := false
var mine_target_pos := Vector3.ZERO
var mine_progress := 0.0  # 0.0 to 1.0
var mine_total_time := 0.0  # Seconds to break this block
var crack_overlay: MeshInstance3D = null

func _process_mining(delta: float) -> void:
    if not mining:
        return

    # Check if still looking at same block
    if not cursor_valid or cursor_block_pos != mine_target_pos:
        _cancel_mining()
        return

    mine_progress += delta / mine_total_time
    _update_crack_overlay(mine_progress)

    if mine_progress >= 1.0:
        _complete_mining()
```

### Break Time Calculation

```gdscript
func _calculate_break_time(block_id: int, held_tool_id: int) -> float:
    var hardness: float = palette.get_hardness(block_id)
    if hardness < 0:
        return -1.0  # Unbreakable (bedrock)

    var tool_type: String = palette.get_tool_type(block_id)
    var tool_multiplier := 1.0

    # Check if held item is correct tool type
    if _is_correct_tool(held_tool_id, tool_type):
        tool_multiplier = _get_tool_speed(held_tool_id)
        # Wood=2, Stone=4, Iron=6, Diamond=8, Gold=12
    else:
        tool_multiplier = 1.0  # Hand mining (very slow)

    # Base formula: hardness * 1.5 / tool_multiplier
    # If wrong tool for blocks requiring specific tool: hardness * 5.0
    var requires_tool := palette.requires_tool(block_id)
    if requires_tool and not _is_correct_tool(held_tool_id, tool_type):
        return hardness * 5.0  # Slow and drops nothing

    return hardness * 1.5 / tool_multiplier

# Examples:
# Dirt (hardness=0.5) + shovel (speed=6): 0.5 * 1.5 / 6 = 0.125s (instant)
# Stone (hardness=1.5) + iron pickaxe (speed=6): 1.5 * 1.5 / 6 = 0.375s
# Stone (hardness=1.5) + hand: 1.5 * 1.5 / 1 = 2.25s
# Obsidian (hardness=50) + diamond pickaxe (speed=8): 50 * 1.5 / 8 = 9.375s
# Obsidian + hand: 50 * 5.0 = 250s (and drops nothing)
```

### Crack Overlay

10-stage crack texture overlaid on the block face being mined:

```gdscript
func _create_crack_overlay(block_pos: Vector3, face_normal: Vector3) -> void:
    if crack_overlay != null:
        crack_overlay.queue_free()

    crack_overlay = MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(1.01, 1.01)  # Slightly larger than block face to avoid z-fighting
    crack_overlay.mesh = quad

    # Position on the face
    crack_overlay.position = block_pos + Vector3(0.5, 0.5, 0.5) + face_normal * 0.505

    # Rotate to face outward
    crack_overlay.look_at(crack_overlay.position + face_normal)

    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_texture = crack_textures[0]  # Stage 0
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.no_depth_test = false
    crack_overlay.material_override = mat

    voxels_root.add_child(crack_overlay)

func _update_crack_overlay(progress: float) -> void:
    if crack_overlay == null:
        return
    var stage := int(progress * 10.0)
    stage = clamp(stage, 0, 9)
    var mat: StandardMaterial3D = crack_overlay.material_override
    mat.albedo_texture = crack_textures[stage]
```

### Break Particles

```gdscript
func _spawn_break_particles(block_pos: Vector3, block_id: int) -> void:
    var color: Color = palette.get_block_color(block_id)
    var particles := CPUParticles3D.new()
    particles.position = block_pos + Vector3(0.5, 0.5, 0.5)
    particles.amount = 20
    particles.lifetime = 0.8
    particles.one_shot = true
    particles.emitting = true
    particles.direction = Vector3(0, 1, 0)
    particles.spread = 180.0
    particles.initial_velocity_min = 2.0
    particles.initial_velocity_max = 5.0
    particles.gravity = Vector3(0, -15, 0)
    particles.scale_amount_min = 0.05
    particles.scale_amount_max = 0.15
    particles.color = color

    # Use a small box mesh as particle
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.1, 0.1, 0.1)
    particles.mesh = mesh

    voxels_root.add_child(particles)
    # Auto-free after lifetime
    var timer := Timer.new()
    timer.wait_time = 1.0
    timer.one_shot = true
    timer.timeout.connect(func(): particles.queue_free(); timer.queue_free())
    particles.add_child(timer)
    timer.start()
```

### Item Drop Entity

See [inventory-system.md](inventory-system.md) for `item_entity.gd` — the dropped item that players walk over to pick up.

```gdscript
func _complete_mining() -> void:
    var block_id: int = _get_block_at_world(mine_target_pos)
    var drop_id: int = palette.get_drop_id(block_id)
    var drop_count: int = palette.get_drop_count(block_id)

    # Spawn particles
    _spawn_break_particles(mine_target_pos, block_id)

    # Send break to server
    break_block(mine_target_pos)

    # Server will broadcast the block change and spawn item entity

    _cancel_mining()
```

### Input Flow

```
Hold LMB while looking at block:
  Frame 1: start mining → calculate break time, create crack overlay
  Each frame: update progress, update crack stage
  Release LMB: cancel mining
  Look away: cancel mining
  Move too far: cancel mining
  Progress reaches 1.0: break block, particles, drop

Right-click:
  Place block (from hotbar selected slot) on face normal side
```

## Files Modified

| File | Changes |
|------|---------|
| `voxel_manager.gd` | Mining state machine, crack overlay, particles, break time calc |
| `block_palette.gd` | Add `get_hardness()`, `get_tool_type()`, `get_drop_id()`, `requires_tool()` |
| `main.gd` | Change LMB from instant to hold-to-mine, pass held tool info |

## Acceptance Criteria

- [ ] Hold left-click to mine (not instant)
- [ ] Break time varies: dirt is fast, stone is medium, obsidian is very slow
- [ ] Correct tool speeds up mining (pickaxe on stone, axe on wood, shovel on dirt)
- [ ] Hand mining works but is slowest
- [ ] 10-stage crack overlay visible on block being mined
- [ ] Releasing mouse button cancels mining
- [ ] Looking away from block cancels mining
- [ ] Moving too far cancels mining
- [ ] Block-colored particles burst on break
- [ ] Mining animation on player arm (right arm swings)
- [ ] Tool durability decreases per mine action (future: with inventory)
- [ ] Wrong tool type: very slow and drops nothing for "requires tool" blocks
- [ ] Bedrock is unbreakable
