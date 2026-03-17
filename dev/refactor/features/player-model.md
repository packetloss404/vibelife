# Feature: Blocky Player Model

**Sprint**: 2
**Status**: Not Started
**Priority**: High — makes the game feel like Minecraft

## Summary

Replace the colored capsule avatar with a blocky Minecraft-style character model (Steve). Built from 6 procedural box meshes (head, body, 2 arms, 2 legs) with walking, mining, and idle animations. Support for 64x64 skin textures.

## Current State

`avatar_manager.gd` creates avatars as:
- CapsuleMesh (1.8m tall, 0.35m radius)
- Colored by `bodyColor` from avatar appearance
- No animations
- Name displayed as Label3D above

## Target State

### Body Part Dimensions (Minecraft standard)

```
All measurements in Godot units (1 unit = 1 block = 1 meter):

Head:   0.5 × 0.5 × 0.5   pivot at neck (bottom-center)
Body:   0.5 × 0.75 × 0.25  pivot at top-center
R Arm:  0.25 × 0.75 × 0.25 pivot at shoulder (top-center)
L Arm:  0.25 × 0.75 × 0.25 pivot at shoulder (top-center)
R Leg:  0.25 × 0.75 × 0.25 pivot at hip (top-center)
L Leg:  0.25 × 0.75 × 0.25 pivot at hip (top-center)

Total height: 0.5 (head) + 0.75 (body) + 0.75 (legs) = 2.0 units
Eye height: 1.62 units from feet
```

### Mesh Construction

```gdscript
func _build_player_model(appearance: Dictionary) -> Node3D:
    var root := Node3D.new()
    root.name = "PlayerModel"

    # Body
    var body_mesh := _create_box_part(Vector3(0.5, 0.75, 0.25))
    body_mesh.position = Vector3(0, 0.75, 0)  # Above legs
    root.add_child(body_mesh)

    # Head (pivots at neck)
    var head_pivot := Node3D.new()
    head_pivot.position = Vector3(0, 1.5, 0)  # Top of body
    var head_mesh := _create_box_part(Vector3(0.5, 0.5, 0.5))
    head_mesh.position = Vector3(0, 0.25, 0)  # Center of head above pivot
    head_pivot.add_child(head_mesh)
    root.add_child(head_pivot)

    # Right Arm (pivots at shoulder)
    var r_arm_pivot := Node3D.new()
    r_arm_pivot.position = Vector3(-0.375, 1.5, 0)  # Right shoulder
    var r_arm_mesh := _create_box_part(Vector3(0.25, 0.75, 0.25))
    r_arm_mesh.position = Vector3(0, -0.375, 0)  # Hang down from pivot
    r_arm_pivot.add_child(r_arm_mesh)
    root.add_child(r_arm_pivot)

    # Left Arm
    var l_arm_pivot := Node3D.new()
    l_arm_pivot.position = Vector3(0.375, 1.5, 0)
    var l_arm_mesh := _create_box_part(Vector3(0.25, 0.75, 0.25))
    l_arm_mesh.position = Vector3(0, -0.375, 0)
    l_arm_pivot.add_child(l_arm_mesh)
    root.add_child(l_arm_pivot)

    # Right Leg (pivots at hip)
    var r_leg_pivot := Node3D.new()
    r_leg_pivot.position = Vector3(-0.125, 0.75, 0)
    var r_leg_mesh := _create_box_part(Vector3(0.25, 0.75, 0.25))
    r_leg_mesh.position = Vector3(0, -0.375, 0)
    r_leg_pivot.add_child(r_leg_mesh)
    root.add_child(r_leg_pivot)

    # Left Leg
    var l_leg_pivot := Node3D.new()
    l_leg_pivot.position = Vector3(0.125, 0.75, 0)
    var l_leg_mesh := _create_box_part(Vector3(0.25, 0.75, 0.25))
    l_leg_mesh.position = Vector3(0, -0.375, 0)
    l_leg_pivot.add_child(l_leg_mesh)
    root.add_child(l_leg_pivot)

    return root

func _create_box_part(size: Vector3) -> MeshInstance3D:
    var mesh_inst := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh_inst.mesh = box
    return mesh_inst
```

### Animations

```gdscript
# Animation state
var walk_cycle := 0.0
var is_walking := false
var is_mining := false

func _animate_player(model: Node3D, delta: float, velocity: Vector3) -> void:
    var speed := Vector2(velocity.x, velocity.z).length()
    is_walking = speed > 0.1

    if is_walking:
        walk_cycle += delta * speed * 4.0  # Speed-dependent cycle
        var swing := sin(walk_cycle) * 0.6  # ±0.6 radians (~35°)

        # Arms swing opposite to legs
        model.get_node("RArmPivot").rotation.x = swing
        model.get_node("LArmPivot").rotation.x = -swing
        model.get_node("RLegPivot").rotation.x = -swing
        model.get_node("LLegPivot").rotation.x = swing
    else:
        # Idle: slowly return to neutral
        _lerp_rotation_to_zero(model, delta)

func _animate_mining(model: Node3D, delta: float) -> void:
    # Right arm swings down rapidly
    var mine_swing := sin(mine_timer * 8.0) * 1.2  # Fast swing
    model.get_node("RArmPivot").rotation.x = mine_swing
```

### First-Person Arm

When in first-person, hide the full model and show only a floating right arm:

```gdscript
func _setup_first_person_arm(camera: Camera3D) -> void:
    var fp_arm := _create_box_part(Vector3(0.25, 0.75, 0.25))
    fp_arm.name = "FirstPersonArm"
    # Position bottom-right of camera view
    fp_arm.position = Vector3(0.4, -0.4, -0.5)
    camera.add_child(fp_arm)

    # Held item shown at end of arm
    var held_item := MeshInstance3D.new()
    held_item.name = "HeldItem"
    held_item.position = Vector3(0, -0.375, -0.125)
    fp_arm.add_child(held_item)
```

### Head Pitch Sync

The head pivot follows the camera's pitch angle, visible to other players:

```gdscript
func _sync_head_pitch(model: Node3D, pitch: float) -> void:
    var head_pivot: Node3D = model.get_node("HeadPivot")
    head_pivot.rotation.x = clamp(pitch, -PI/2, PI/2)
```

Broadcast pitch in avatar move updates:
```typescript
// Add to avatar state
type AvatarStateContract = {
  // ... existing fields
  headPitch: number  // radians, -PI/2 to PI/2
}
```

### Name Tag

```gdscript
func _add_name_tag(model: Node3D, display_name: String) -> void:
    var label := Label3D.new()
    label.text = display_name
    label.position = Vector3(0, 2.2, 0)  # Above head
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 32
    label.outline_size = 4
    label.modulate = Color.WHITE
    label.no_depth_test = true  # Always visible
    model.add_child(label)
```

### Skin Texture (future)

```
64x64 PNG skin layout (Minecraft format):
  - Head front:  8x8 at (8,8)
  - Head back:   8x8 at (24,8)
  - Head top:    8x8 at (8,0)
  - Head bottom: 8x8 at (16,0)
  - Head right:  8x8 at (0,8)
  - Head left:   8x8 at (16,8)
  - Body front:  8x12 at (20,20)
  - etc.

UV mapping each box face to the correct skin region.
Default: use appearance.bodyColor as solid color until skins are implemented.
```

## Files Modified

| File | Changes |
|------|---------|
| `avatar_manager.gd` | Replace capsule with blocky model, add animation system |
| `main.gd` | First-person arm setup, head pitch sync, velocity to animation |
| `contracts.ts` | Add headPitch to AvatarStateContract |

## Acceptance Criteria

- [ ] Player model is 6 connected boxes (Steve-style)
- [ ] Walking animation: arms/legs swing in sync with movement speed
- [ ] Mining animation: right arm swings down rapidly
- [ ] Head tracks camera pitch (visible to other players)
- [ ] Name tag Label3D above head
- [ ] Other players render identically
- [ ] First-person: only arm visible, body hidden
- [ ] Model colors from avatar appearance (body, head, accent colors)
- [ ] Smooth transition between idle and walking
