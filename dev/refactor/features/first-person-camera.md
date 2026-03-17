# Feature: First-Person Camera

**Sprint**: 2
**Status**: Not Started
**Priority**: High — core Minecraft feel

## Summary

Refactor the camera from orbit-only to first-person mouse-look as default. Mouse captured on click, released on Escape. F5 cycles through camera modes. Add crosshair, camera bob, and FOV settings.

## Current State

`camera_controller.gd`:
- Orbit camera only (right-click drag to rotate)
- Camera follows player at fixed distance
- Scroll wheel zooms
- No mouse capture
- No first-person mode

## Target State

### Camera Modes

```
Mode 0: First-Person (default)
  - Camera at player eye height (position + Vector3(0, 1.62, 0))
  - Camera rotation = player look direction
  - Player model hidden (except first-person arm)
  - Mouse captured (invisible, locked to center)

Mode 1: Third-Person Back
  - Camera behind and above player
  - Distance adjustable with scroll wheel (2-10 blocks, default 4)
  - Camera collides with blocks (moves closer if obstructed)
  - Player model visible
  - Mouse still captured for look control

Mode 2: Third-Person Front
  - Camera in front of player, facing them
  - Same distance/collision as Mode 1
  - Player model visible, mirrored view
  - Useful for selfies
```

### Mouse Look

```gdscript
var mouse_sensitivity := 0.002  # radians per pixel
var yaw := 0.0      # Horizontal rotation (unlimited)
var pitch := 0.0    # Vertical rotation (clamped)
var mouse_captured := false

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and mouse_captured:
        yaw -= event.relative.x * mouse_sensitivity
        pitch -= event.relative.y * mouse_sensitivity
        pitch = clamp(pitch, -PI/2 + 0.01, PI/2 - 0.01)

func capture_mouse() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    mouse_captured = true

func release_mouse() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    mouse_captured = false
```

### Mouse Capture Flow

```
Game start: mouse visible (title screen / login)
Click in game world: capture mouse
Press Escape: release mouse, open ESC menu
Close ESC menu: re-capture mouse
Open inventory (E): release mouse
Close inventory: re-capture mouse
Open chat (T): release mouse (cursor in text field)
Send/cancel chat: re-capture mouse
```

### Third-Person Collision

```gdscript
func _update_third_person_camera(player_pos: Vector3) -> void:
    var target_pos := player_pos + Vector3(0, 1.62, 0)
    var camera_offset := Vector3(0, 0, camera_distance)
    camera_offset = camera_offset.rotated(Vector3.RIGHT, pitch)
    camera_offset = camera_offset.rotated(Vector3.UP, yaw)

    var desired_pos := target_pos + camera_offset

    # Raycast from player to desired camera position
    var space_state := camera.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(target_pos, desired_pos)
    var result := space_state.intersect_ray(query)

    if not result.is_empty():
        # Move camera closer to avoid clipping
        camera.global_position = result.position - camera_offset.normalized() * 0.2
    else:
        camera.global_position = desired_pos

    camera.look_at(target_pos)
```

### Camera Bob

```gdscript
var bob_timer := 0.0
var bob_intensity := 0.03  # Subtle
var sprint_bob_intensity := 0.06  # More noticeable when sprinting

func _apply_camera_bob(delta: float, is_walking: bool, is_sprinting: bool) -> void:
    if not is_walking:
        bob_timer = 0.0
        return

    var intensity := sprint_bob_intensity if is_sprinting else bob_intensity
    var speed := 12.0 if is_sprinting else 8.0

    bob_timer += delta * speed
    var bob_y := sin(bob_timer) * intensity
    var bob_x := cos(bob_timer * 0.5) * intensity * 0.5

    camera.position.y += bob_y
    camera.position.x += bob_x
```

### Crosshair

```gdscript
func _create_crosshair() -> void:
    var crosshair := Control.new()
    crosshair.name = "Crosshair"
    crosshair.set_anchors_preset(Control.PRESET_CENTER)
    crosshair.size = Vector2(20, 20)
    crosshair.position = Vector2(-10, -10)

    # Horizontal line
    var h_line := ColorRect.new()
    h_line.color = Color(1, 1, 1, 0.8)
    h_line.position = Vector2(2, 9)
    h_line.size = Vector2(16, 2)
    crosshair.add_child(h_line)

    # Vertical line
    var v_line := ColorRect.new()
    v_line.color = Color(1, 1, 1, 0.8)
    v_line.position = Vector2(9, 2)
    v_line.size = Vector2(2, 16)
    crosshair.add_child(v_line)

    hud_layer.add_child(crosshair)
```

### FOV

```gdscript
var base_fov := 70.0  # Configurable 60-110
var sprint_fov_boost := 10.0  # FOV widens when sprinting
var underwater_fov := 60.0  # Narrower underwater

func _update_fov(delta: float, is_sprinting: bool, is_underwater: bool) -> void:
    var target_fov := base_fov
    if is_sprinting:
        target_fov = base_fov + sprint_fov_boost
    elif is_underwater:
        target_fov = underwater_fov

    camera.fov = lerp(camera.fov, target_fov, delta * 5.0)
```

### F5 Toggle

```gdscript
var camera_mode := 0  # 0=first-person, 1=third-back, 2=third-front

func _toggle_camera_mode() -> void:
    camera_mode = (camera_mode + 1) % 3
    match camera_mode:
        0:  # First person
            _hide_local_player_model()
            _show_first_person_arm()
        1:  # Third person back
            _show_local_player_model()
            _hide_first_person_arm()
        2:  # Third person front
            _show_local_player_model()
            _hide_first_person_arm()
```

## Files Modified

| File | Changes |
|------|---------|
| `camera_controller.gd` | Complete rewrite: mouse look, capture, 3 modes, bob, FOV |
| `main.gd` | Mouse capture flow, F5 handling, crosshair creation, Escape releases mouse |
| `main.tscn` | Camera default position at origin (attached to player) |

## Acceptance Criteria

- [ ] First-person by default, camera at eye height
- [ ] Mouse look: pitch ±90°, yaw unlimited
- [ ] Mouse captured on click, released on Escape
- [ ] F5 cycles: first-person → third-person back → third-person front
- [ ] Third-person: scroll wheel distance, block collision
- [ ] Crosshair: white + at screen center (first-person only)
- [ ] Camera bob when walking (subtle)
- [ ] Sprint widens FOV smoothly
- [ ] FOV configurable in settings (60-110°, default 70)
- [ ] Mouse sensitivity configurable in settings
- [ ] Mouse re-captured when closing menus/inventory
