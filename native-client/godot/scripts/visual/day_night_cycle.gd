class_name DayNightCycle
extends RefCounted
## Smoothly transitions sun position, color, energy, sky colors, ambient light,
## and fog color over a configurable day/night cycle.

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial

# Time of day: 0.0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk
var time_of_day := 0.35 # start mid-morning

# Cycle duration in real seconds (default: 600s = 10 minutes per full day)
var cycle_duration := 600.0

# Pause the cycle (for editor or cutscene use)
var paused := false

# Sun orbit parameters
var sun_latitude := 35.0 # degrees from equator (affects arc height)

# ── Color presets for key times of day ───────────────────────────────────────

# Sun light color at key times [midnight, dawn, noon, dusk]
const SUN_COLORS: Array[Color] = [
	Color(0.15, 0.15, 0.3),    # midnight: dim blue
	Color(1.0, 0.6, 0.35),     # dawn: warm orange
	Color(1.0, 0.97, 0.88),    # noon: warm white
	Color(1.0, 0.45, 0.2),     # dusk: deep orange
]

# Sun energy at key times
const SUN_ENERGIES: Array[float] = [
	0.05,   # midnight
	0.9,    # dawn
	2.0,    # noon
	0.8,    # dusk
]

# Sky top color at key times
const SKY_TOP_COLORS: Array[Color] = [
	Color(0.02, 0.02, 0.08),      # midnight: dark
	Color(0.35, 0.5, 0.75),       # dawn: pale blue-purple
	Color(0.42, 0.76, 1.0),       # noon: bright blue
	Color(0.25, 0.25, 0.55),      # dusk: purple-blue
]

# Sky horizon color at key times
const SKY_HORIZON_COLORS: Array[Color] = [
	Color(0.03, 0.03, 0.06),      # midnight
	Color(0.95, 0.55, 0.3),       # dawn: orange glow
	Color(0.12, 0.26, 0.34),      # noon
	Color(0.9, 0.4, 0.2),         # dusk: orange-red
]

# Ambient light color at key times
const AMBIENT_COLORS: Array[Color] = [
	Color(0.08, 0.1, 0.2),        # midnight: cool blue
	Color(0.45, 0.4, 0.5),        # dawn: lavender
	Color(0.55, 0.73, 0.8),       # noon: sky blue
	Color(0.4, 0.3, 0.35),        # dusk: warm muted
]

# Ambient energy at key times
const AMBIENT_ENERGIES: Array[float] = [
	0.15,   # midnight
	0.6,    # dawn
	1.2,    # noon
	0.5,    # dusk
]

# Fog color at key times
const FOG_COLORS: Array[Color] = [
	Color(0.05, 0.05, 0.1),       # midnight
	Color(0.8, 0.6, 0.45),        # dawn: warm
	Color(0.85, 0.78, 0.65),      # noon: warm haze
	Color(0.75, 0.45, 0.3),       # dusk: orange
]


func init(p_sun: DirectionalLight3D, p_environment: Environment) -> void:
	sun = p_sun
	environment = p_environment
	# Grab or create sky material
	if environment.sky != null and environment.sky is Sky:
		var sky_res = environment.sky as Sky
		if sky_res.sky_material is ProceduralSkyMaterial:
			sky_material = sky_res.sky_material as ProceduralSkyMaterial
	if sky_material == null:
		sky_material = ProceduralSkyMaterial.new()
		if environment.sky == null:
			var sky_res = Sky.new()
			sky_res.sky_material = sky_material
			environment.sky = sky_res
		elif environment.sky is Sky:
			(environment.sky as Sky).sky_material = sky_material
	_apply_time()


func update(delta: float) -> void:
	if paused:
		return
	time_of_day += delta / cycle_duration
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	_apply_time()


## Set time directly (0.0 = midnight, 0.5 = noon)
func set_time(t: float) -> void:
	time_of_day = fmod(t, 1.0)
	_apply_time()


## Get a human-readable time string (e.g. "14:30")
func get_time_string() -> String:
	var hours := int(time_of_day * 24.0)
	var minutes := int(fmod(time_of_day * 24.0 * 60.0, 60.0))
	return "%02d:%02d" % [hours, minutes]


## Returns a phase name: "night", "dawn", "day", "dusk"
func get_phase() -> String:
	if time_of_day < 0.2 or time_of_day >= 0.85:
		return "night"
	elif time_of_day < 0.3:
		return "dawn"
	elif time_of_day < 0.7:
		return "day"
	else:
		return "dusk"


# ── Internal ─────────────────────────────────────────────────────────────────

func _apply_time() -> void:
	_update_sun_transform()
	_update_sun_light()
	_update_sky()
	_update_ambient()
	_update_fog()


func _update_sun_transform() -> void:
	if sun == null:
		return
	# Sun angle: 0.0 time = below horizon (midnight), 0.5 = directly overhead (noon)
	# Map time_of_day to an angle. The sun rises at ~0.25 and sets at ~0.75.
	var sun_angle := (time_of_day - 0.25) * TAU  # full rotation
	var altitude := sin(sun_angle) * deg_to_rad(90.0 - sun_latitude * 0.5)
	var azimuth := cos(sun_angle) * deg_to_rad(45.0)

	# Position the sun at a distance
	var sun_dir := Vector3(
		cos(altitude) * sin(azimuth),
		sin(altitude),
		cos(altitude) * cos(azimuth)
	).normalized()

	sun.position = sun_dir * 50.0
	if sun_dir.y > -0.1:
		sun.look_at(Vector3.ZERO, Vector3.UP)
	# Below horizon: point downward so shadow doesn't flip
	sun.visible = sun_dir.y > -0.05


func _update_sun_light() -> void:
	if sun == null:
		return
	sun.light_color = _sample_gradient(SUN_COLORS)
	sun.light_energy = _sample_float_gradient(SUN_ENERGIES)


func _update_sky() -> void:
	if sky_material == null:
		return
	sky_material.sky_top_color = _sample_gradient(SKY_TOP_COLORS)
	sky_material.sky_horizon_color = _sample_gradient(SKY_HORIZON_COLORS)
	# Ground follows sky but darker
	sky_material.ground_bottom_color = _sample_gradient(SKY_TOP_COLORS) * 0.15


func _update_ambient() -> void:
	if environment == null:
		return
	environment.ambient_light_color = _sample_gradient(AMBIENT_COLORS)
	environment.ambient_light_energy = _sample_float_gradient(AMBIENT_ENERGIES)


func _update_fog() -> void:
	if environment == null or not environment.fog_enabled:
		return
	environment.fog_light_color = _sample_gradient(FOG_COLORS)
	# Increase fog density slightly at dawn/dusk for atmosphere
	var phase := get_phase()
	match phase:
		"dawn", "dusk":
			environment.fog_density = 0.005
		"night":
			environment.fog_density = 0.004
		_:
			environment.fog_density = 0.003


# ── Gradient sampling utilities ──────────────────────────────────────────────

## Sample a 4-stop color gradient. Stops are at t=0.0, 0.25, 0.5, 0.75.
func _sample_gradient(colors: Array[Color]) -> Color:
	var t := time_of_day * 4.0 # 0..4
	var idx := int(t) % 4
	var next_idx := (idx + 1) % 4
	var frac := t - floorf(t)
	# Smooth interpolation
	frac = frac * frac * (3.0 - 2.0 * frac)
	return colors[idx].lerp(colors[next_idx], frac)


func _sample_float_gradient(values: Array[float]) -> float:
	var t := time_of_day * 4.0
	var idx := int(t) % 4
	var next_idx := (idx + 1) % 4
	var frac := t - floorf(t)
	frac = frac * frac * (3.0 - 2.0 * frac)
	return lerpf(values[idx], values[next_idx], frac)
