# Feature: Voxel Physics (AABB Collision)

**Sprint**: 6
**Status**: Not Started
**Priority**: High — proper movement on voxel terrain

## Summary

Replace Godot's built-in physics with custom AABB collision against the voxel grid. Player hitbox collides with block boundaries. Gravity, jumping, sprinting, sneaking, swimming, ladder climbing, and knockback.

## Current State

`main.gd` uses basic position updates without proper voxel collision. Player can walk through blocks. No gravity (y-position mostly ignored).

## Target State

### Player Hitbox

```
Width: 0.6 blocks (centered on x,z)
Height: 1.8 blocks
Depth: 0.6 blocks

AABB: from (pos.x - 0.3, pos.y, pos.z - 0.3) to (pos.x + 0.3, pos.y + 1.8, pos.z + 0.3)

Eye position: pos.y + 1.62
```

### Movement System

```gdscript
# voxel_physics.gd

var velocity := Vector3.ZERO
var on_ground := false
var in_water := false
var on_ladder := false

const GRAVITY := 28.0        # blocks/s²
const TERMINAL_VELOCITY := 78.0
const JUMP_VELOCITY := 8.5   # Achieves ~1.25 block height
const WALK_SPEED := 4.317    # blocks/s
const SPRINT_SPEED := 5.612  # 1.3x walk
const SNEAK_SPEED := 1.295   # 0.3x walk
const SWIM_SPEED := 2.0      # blocks/s in water

func update(delta: float, input_dir: Vector2, jump: bool, sprint: bool, sneak: bool) -> void:
    # 1. Apply gravity
    if not on_ground and not in_water and not on_ladder:
        velocity.y -= GRAVITY * delta
        velocity.y = max(velocity.y, -TERMINAL_VELOCITY)

    # 2. Horizontal movement
    var speed := WALK_SPEED
    if sprint and input_dir.y < 0:  # Only sprint forward
        speed = SPRINT_SPEED
    elif sneak:
        speed = SNEAK_SPEED

    var forward := Vector3(sin(yaw), 0, cos(yaw))
    var right := Vector3(cos(yaw), 0, -sin(yaw))
    var move_dir := (forward * -input_dir.y + right * input_dir.x).normalized()

    velocity.x = move_dir.x * speed
    velocity.z = move_dir.z * speed

    # 3. Jump
    if jump and on_ground:
        velocity.y = JUMP_VELOCITY
        on_ground = false

    # 4. Water physics
    if in_water:
        velocity.y *= 0.8  # Drag
        if jump:
            velocity.y = 3.0  # Swim up
        velocity.x *= 0.8
        velocity.z *= 0.8

    # 5. Ladder
    if on_ladder:
        velocity.y = 0.0
        if input_dir.y < 0:  # W key (forward)
            velocity.y = 3.0  # Climb up
        elif sneak:
            velocity.y = 0.0  # Hold position
        else:
            velocity.y = -1.0  # Slow descend

    # 6. Resolve collisions
    var displacement := velocity * delta
    position = _resolve_collision(position, displacement)

    # 7. Sneak edge prevention
    if sneak and on_ground:
        position = _prevent_edge_fall(position)
```

### AABB Collision Resolution

```gdscript
func _resolve_collision(pos: Vector3, displacement: Vector3) -> Vector3:
    # Sweep test: move along each axis independently
    # Check X axis
    var new_pos := pos
    new_pos.x += displacement.x
    if _collides_at(new_pos):
        new_pos.x = pos.x
        velocity.x = 0

    # Check Y axis
    new_pos.y += displacement.y
    if _collides_at(new_pos):
        if displacement.y < 0:
            # Landing on ground
            new_pos.y = floor(new_pos.y) + 0.001  # Snap to block top
            on_ground = true
            # Calculate fall damage
            var fall_distance := _fall_start_y - new_pos.y
            if fall_distance > 3:
                _take_fall_damage(fall_distance)
            _fall_start_y = new_pos.y
        else:
            # Hit ceiling
            new_pos.y = pos.y
        velocity.y = 0
    else:
        if displacement.y < 0:
            on_ground = false

    # Check Z axis
    new_pos.z += displacement.z
    if _collides_at(new_pos):
        new_pos.z = pos.z
        velocity.z = 0

    return new_pos

func _collides_at(pos: Vector3) -> bool:
    # Player AABB at this position
    var min_x := int(floor(pos.x - 0.3))
    var max_x := int(floor(pos.x + 0.3))
    var min_y := int(floor(pos.y))
    var max_y := int(floor(pos.y + 1.8))
    var min_z := int(floor(pos.z - 0.3))
    var max_z := int(floor(pos.z + 0.3))

    for bx in range(min_x, max_x + 1):
        for by in range(min_y, max_y + 1):
            for bz in range(min_z, max_z + 1):
                var block_id := _get_world_block(bx, by, bz)
                if palette.is_solid(block_id):
                    return true
    return false
```

### Step-Up

```gdscript
# Auto-climb ledges up to 0.5 blocks (slabs, stairs)
func _try_step_up(pos: Vector3, displacement: Vector3) -> Vector3:
    var test_pos := pos + displacement
    if _collides_at(test_pos):
        # Try stepping up 0.5 blocks
        var stepped := test_pos + Vector3(0, 0.5, 0)
        if not _collides_at(stepped):
            return stepped
    return pos + displacement
```

### Sneak Edge Prevention

```gdscript
func _prevent_edge_fall(pos: Vector3) -> Vector3:
    # Check if the block below each edge of the hitbox is air
    # If so, clamp position to prevent falling off
    var check_points := [
        Vector2(pos.x - 0.3, pos.z - 0.3),
        Vector2(pos.x + 0.3, pos.z - 0.3),
        Vector2(pos.x - 0.3, pos.z + 0.3),
        Vector2(pos.x + 0.3, pos.z + 0.3),
    ]

    for point in check_points:
        var below := _get_world_block(int(floor(point.x)), int(floor(pos.y - 0.1)), int(floor(point.y)))
        if not palette.is_solid(below):
            # Clamp this edge inward
            pos.x = clamp(pos.x, floor(pos.x) + 0.3, floor(pos.x) + 0.7)
            pos.z = clamp(pos.z, floor(pos.z) + 0.3, floor(pos.z) + 0.7)

    return pos
```

### Water Detection

```gdscript
func _update_water_state(pos: Vector3) -> void:
    var head_block := _get_world_block(int(floor(pos.x)), int(floor(pos.y + 1.62)), int(floor(pos.z)))
    var feet_block := _get_world_block(int(floor(pos.x)), int(floor(pos.y)), int(floor(pos.z)))

    in_water = palette.is_water(feet_block) or palette.is_water(head_block)

    # Drowning: if head is underwater
    if palette.is_water(head_block):
        air_timer -= delta
        if air_timer <= 0:
            # Bubble pops, take 1 damage per second
            take_damage(1)
    else:
        air_timer = 15.0  # 15 seconds of air (30 bubbles at 0.5s each)
```

### Knockback

```gdscript
func apply_knockback(direction: Vector3, force: float) -> void:
    velocity += direction.normalized() * force
    velocity.y = max(velocity.y, 4.0)  # Slight upward component
    on_ground = false
```

## Files Created

| File | Purpose |
|------|---------|
| `voxel_physics.gd` | AABB collision, gravity, all movement states |

## Files Modified

| File | Changes |
|------|---------|
| `main.gd` | Replace movement code with voxel_physics calls |
| `block_palette.gd` | Add `is_water()`, `is_climbable()` methods |

## Acceptance Criteria

- [ ] Player collides with blocks (can't walk through walls)
- [ ] Gravity: player falls when not on solid ground
- [ ] Jump: 1.25 block height
- [ ] Sprint: Ctrl, 1.3x speed
- [ ] Sneak: Shift, prevents falling off edges
- [ ] Swimming: space to rise in water, slow movement
- [ ] Ladder climbing: W to climb, sneak to hold
- [ ] Step-up: auto-climb 0.5-block ledges
- [ ] Fall damage: 1 HP per block beyond 3
- [ ] Knockback pushes player
- [ ] Drowning timer underwater (30 bubbles)
- [ ] No clipping through blocks at any speed
