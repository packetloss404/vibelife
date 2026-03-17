# Feature: Sound System

**Sprint**: 7
**Status**: Not Started
**Priority**: Medium — immersion layer

## Summary

Add comprehensive audio: block sounds (place/break/step per material), ambient (cave/wind/underwater), background music with random pauses, mob sounds, UI sounds, combat sounds, and environmental audio. All world sounds are 3D positional.

## Target State

### Sound Manager (`sound_manager.gd`)

```gdscript
class_name SoundManager
extends RefCounted

var main_node: Node3D
var sfx_pool: Array[AudioStreamPlayer3D] = []  # Pre-allocated pool
var music_player: AudioStreamPlayer  # Non-positional, for music
var ambient_player: AudioStreamPlayer  # Non-positional, for ambient
const POOL_SIZE := 24

# Sound categories (each with volume slider)
enum Category { MASTER, MUSIC, BLOCKS, HOSTILE, PLAYERS, AMBIENT, WEATHER, UI }
var volumes: Dictionary = {
    Category.MASTER: 1.0, Category.MUSIC: 0.5, Category.BLOCKS: 1.0,
    Category.HOSTILE: 1.0, Category.PLAYERS: 1.0, Category.AMBIENT: 0.7,
    Category.WEATHER: 0.8, Category.UI: 0.8
}
```

### Block Sound Categories

| Material | Place Sound | Break Sound | Step Sound |
|----------|------------|-------------|------------|
| stone | stone click | stone crack | stone tap |
| wood | wood thud | wood crack | wood creak |
| dirt | dirt squish | dirt crumble | dirt shuffle |
| gravel | gravel crunch | gravel scatter | gravel crunch |
| sand | sand shift | sand scatter | sand shuffle |
| glass | glass clink | glass shatter | glass tap |
| metal | metal clang | metal break | metal ring |
| cloth/wool | cloth rustle | cloth tear | cloth soft |
| snow | snow crunch | snow crumble | snow crunch |
| slime | slime squish | slime pop | slime squish |

### Footstep System

```gdscript
var step_timer := 0.0
var step_interval := 0.5  # Seconds between steps at walk speed

func _process_footsteps(delta: float, speed: float, block_below_id: int) -> void:
    if speed < 0.1:
        step_timer = 0.0
        return

    # Faster steps when sprinting
    var interval := step_interval / (speed / 4.317)
    step_timer += delta

    if step_timer >= interval:
        step_timer -= interval
        var material := palette.get_block_material(block_below_id)
        play_3d_sound("step_" + material, player_position, Category.BLOCKS)
```

### Ambient State Machine

```gdscript
enum AmbientState { SURFACE, CAVE, UNDERWATER, HIGH_ALTITUDE }
var current_ambient := AmbientState.SURFACE

func _update_ambient(player_pos: Vector3, is_underwater: bool) -> void:
    var new_state := AmbientState.SURFACE

    if is_underwater:
        new_state = AmbientState.UNDERWATER
    elif player_pos.y < _surface_height_at(player_pos) - 10:
        new_state = AmbientState.CAVE
    elif player_pos.y > 180:
        new_state = AmbientState.HIGH_ALTITUDE

    if new_state != current_ambient:
        current_ambient = new_state
        _crossfade_ambient(_get_ambient_track(new_state))
```

### Music System

```gdscript
# Calm background tracks play randomly with long pauses
var music_tracks: Array[AudioStream] = []
var music_pause_timer := 0.0
const MIN_PAUSE := 120.0  # 2 minutes minimum between tracks
const MAX_PAUSE := 420.0  # 7 minutes maximum

func _process_music(delta: float) -> void:
    if music_player.playing:
        return

    music_pause_timer += delta
    var target_pause := randf_range(MIN_PAUSE, MAX_PAUSE)

    if music_pause_timer >= target_pause:
        music_pause_timer = 0.0
        var track: AudioStream = music_tracks[randi() % music_tracks.size()]
        music_player.stream = track
        music_player.play()
```

### Mob Sounds

| Mob | Idle Sound | Hurt Sound | Death Sound | Special |
|-----|-----------|-----------|-------------|---------|
| Zombie | groan (random 3-8s) | grunt | collapse | burning hiss |
| Skeleton | bone rattle (5-10s) | clatter | bone scatter | bow draw, arrow whoosh |
| Creeper | silence | hiss | explosion boom | 1.5s fuse hiss |
| Spider | hiss/chittering (5-15s) | screech | squish | - |
| Enderman | eerie static (10-20s) | scream | static burst | teleport whoosh |
| Cow | moo (10-30s) | moo (hurt) | - | - |
| Pig | oink (10-30s) | squeal | - | - |
| Sheep | baa (10-30s) | baa (hurt) | - | - |
| Chicken | cluck (5-15s) | squawk | - | egg plop |

### Combat Sounds

| Action | Sound |
|--------|-------|
| Sword swing | whoosh |
| Hit (melee) | thud/impact |
| Critical hit | high ding + impact |
| Shield block | metal clang |
| Arrow shoot | twang + whoosh |
| Arrow hit | thunk |
| Level up | ascending chime |
| XP pickup | high-pitched orb sound |
| Death | dramatic low tone |

### UI Sounds

| Action | Sound |
|--------|-------|
| Inventory open | chest open creak |
| Inventory close | chest close thud |
| Item pickup | pop |
| Item drop | soft thud |
| Chat message | soft blip |
| Button click | click |
| Error/denied | low buzz |

## Files Created

| File | Purpose |
|------|---------|
| `sound_manager.gd` | Central audio manager |
| `assets/audio/` | All sound files directory |

## Files Modified

| File | Changes |
|------|---------|
| `voxel_manager.gd` | Place/break sounds |
| `enemy_renderer.gd` | Mob sounds |
| `combat_hud.gd` | Combat sounds |
| `main.gd` | Footsteps, ambient, music init |
| `spatial_audio.gd` | Integrate with sound manager |

## Acceptance Criteria

- [ ] Block place/break sounds vary by material
- [ ] Footsteps change by block type walked on
- [ ] Cave ambient when underground
- [ ] Background music with long pauses
- [ ] Mob idle/hurt/death sounds
- [ ] Combat hit/swing/crit sounds
- [ ] UI open/close/pickup sounds
- [ ] All world sounds are 3D positional
- [ ] Per-category volume sliders in settings
- [ ] Sounds loaded as .ogg files
