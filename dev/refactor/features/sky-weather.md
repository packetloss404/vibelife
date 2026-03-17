# Feature: Sky & Weather

**Sprint**: 10
**Status**: Not Started
**Priority**: Medium — visual polish

## Summary

Polish sky rendering with time-of-day gradients, sun/moon textures, 8-phase moon cycle, star field, cloud layer, and weather states (clear, rain, thunder, snow) with transitions.

## Target State

### Sky Gradient

```gdscript
# WorldEnvironment background set to custom sky shader or procedural sky

func _get_sky_top_color(time: float) -> Color:
    # time: 0.0 = midnight, 0.5 = noon
    var colors := {
        0.0: Color(0.02, 0.02, 0.08),     # Midnight
        0.2: Color(0.02, 0.02, 0.08),     # Pre-dawn
        0.25: Color(0.4, 0.2, 0.3),       # Dawn
        0.3: Color(0.35, 0.55, 0.9),      # Morning
        0.5: Color(0.45, 0.65, 1.0),      # Noon
        0.7: Color(0.35, 0.55, 0.9),      # Afternoon
        0.75: Color(0.8, 0.4, 0.2),       # Sunset
        0.8: Color(0.15, 0.05, 0.2),      # Dusk
        1.0: Color(0.02, 0.02, 0.08),     # Midnight
    }
    return _interpolate_gradient(colors, time)

func _get_horizon_color(time: float) -> Color:
    # Warmer at horizon during sunrise/sunset
    pass

func _get_fog_color(time: float) -> Color:
    # Matches horizon color for seamless distance fade
    pass
```

### Cloud Layer

```gdscript
func _create_cloud_layer() -> MeshInstance3D:
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(512, 512)  # Large plane
    var cloud_mesh := MeshInstance3D.new()
    cloud_mesh.mesh = mesh
    cloud_mesh.position = Vector3(0, 192, 0)  # High altitude

    var mat := ShaderMaterial.new()
    # Noise texture for cloud shapes
    # Alpha cutoff for cloud vs sky
    # UV offset for scrolling
    cloud_mesh.material_override = mat
    return cloud_mesh

func _update_clouds(delta: float) -> void:
    cloud_uv_offset += Vector2(delta * 0.005, delta * 0.002)
    cloud_material.set_shader_parameter("uv_offset", cloud_uv_offset)
```

### Moon Phases

```
8 phases, cycling every game day:
  0: Full Moon (bright, round)
  1: Waning Gibbous
  2: Third Quarter
  3: Waning Crescent
  4: New Moon (dark)
  5: Waxing Crescent
  6: First Quarter
  7: Waxing Gibbous

Phase = game_day % 8
```

```gdscript
func _update_moon_phase(game_day: int) -> void:
    var phase: int = game_day % 8
    # Option A: 8 separate moon textures
    # Option B: Single atlas, UV offset by phase
    var col: int = phase % 4
    var row: int = phase / 4
    moon_material.set_shader_parameter("uv_offset", Vector2(col * 0.25, row * 0.5))
```

### Star Field

```gdscript
func _create_star_field() -> MeshInstance3D:
    # Sphere of point sprites at large radius
    # Or: large dome mesh with star texture
    # Stars only visible at night (alpha = 0 during day)

    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_POINTS)

    for _i in range(500):
        var dir := Vector3(randf() * 2 - 1, randf(), randf() * 2 - 1).normalized()
        var pos := dir * 300.0
        st.set_color(Color(1, 1, 1, randf_range(0.3, 1.0)))
        st.add_vertex(pos)

    var mesh := st.commit()
    var stars := MeshInstance3D.new()
    stars.mesh = mesh
    # Twinkle: shader with sin(time + vertex_id) modulating alpha
    return stars
```

### Weather System

```gdscript
enum WeatherState { CLEAR, RAIN, THUNDER, SNOW }
var current_weather := WeatherState.CLEAR
var weather_timer := 0.0
var weather_transition := 0.0  # 0=previous state, 1=current state

const MIN_WEATHER_DURATION := 300.0   # 5 minutes minimum
const MAX_WEATHER_DURATION := 1200.0  # 20 minutes maximum
const TRANSITION_TIME := 30.0         # 30 second transitions

func _update_weather(delta: float) -> void:
    weather_timer += delta

    if weather_timer >= current_duration:
        _transition_to_next_weather()

    # During transition: blend effects
    if weather_transition < 1.0:
        weather_transition += delta / TRANSITION_TIME
        _blend_weather_effects(weather_transition)

func _apply_weather_effects() -> void:
    match current_weather:
        WeatherState.CLEAR:
            rain_particles.emitting = false
            snow_particles.emitting = false
            sky_darkening = 0.0

        WeatherState.RAIN:
            rain_particles.emitting = true
            snow_particles.emitting = false
            sky_darkening = 0.3  # Darken sky 30%
            # Wet sound loop

        WeatherState.THUNDER:
            rain_particles.emitting = true
            rain_particles.amount = 3000  # Heavier rain
            sky_darkening = 0.5
            _maybe_spawn_lightning(delta)

        WeatherState.SNOW:
            snow_particles.emitting = true
            rain_particles.emitting = false
            sky_darkening = 0.2
```

### Lightning

```gdscript
var lightning_cooldown := 0.0

func _maybe_spawn_lightning(delta: float) -> void:
    lightning_cooldown -= delta
    if lightning_cooldown <= 0 and randf() < 0.002:  # ~0.2% per frame
        _spawn_lightning_strike()
        lightning_cooldown = 5.0  # Min 5s between strikes

func _spawn_lightning_strike() -> void:
    # Visual: bright white flash (brief DirectionalLight intensity spike)
    # Audio: thunder crack (delayed by distance / 340)
    # Damage: entities at strike point take 5 damage
    # Fire: set top block at strike point to fire (if flammable)
    # Position: random within 128 blocks of a player

    # Flash effect
    sun_light.light_energy = 10.0
    await get_tree().create_timer(0.1).timeout
    sun_light.light_energy = _normal_light_energy
```

## Files Modified

| File | Changes |
|------|---------|
| `sky_manager.gd` | Sky gradient, clouds, stars, sun/moon textures |
| `weather_system.gd` | Rain/thunder/snow states, lightning |
| `day_night_cycle.gd` | Moon phases, sun/moon mesh textures |

## Assets

| File | Purpose |
|------|---------|
| `assets/textures/sky/sun.png` | Sun texture |
| `assets/textures/sky/moon_phases.png` | 8 moon phase atlas |

## Acceptance Criteria

- [ ] Sky color transitions smoothly through day/night
- [ ] Sun disc visible during day
- [ ] Moon with 8 phases visible at night
- [ ] Stars twinkle at night
- [ ] Cloud layer scrolls slowly at y=192
- [ ] Rain: darkened sky, rain particles, wet sound
- [ ] Thunder: lightning flashes, thunder sound, strike damage
- [ ] Snow: white particles fall
- [ ] Weather transitions smoothly (30s blend)
- [ ] Weather cycles randomly with 5-20 min durations
- [ ] Fog color matches horizon for seamless distance fade
