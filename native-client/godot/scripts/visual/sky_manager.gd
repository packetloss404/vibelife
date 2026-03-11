class_name SkyManager
extends RefCounted

## Manages the dynamic sky shader on the WorldEnvironment node.
## Provides update_time() for day/night cycle integration and
## runtime control of cloud/star parameters.

var main  # reference to Main node

var sky_material: ShaderMaterial
var environment: Environment
var time_of_day := 0.35  # default: mid-morning


func init(main_node) -> void:
	main = main_node


func setup_sky() -> void:
	var world_env := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not world_env:
		push_warning("SkyManager: WorldEnvironment node not found")
		return

	environment = world_env.environment
	if not environment:
		environment = Environment.new()
		world_env.environment = environment

	var shader := load("res://shaders/sky_atmosphere.gdshader") as Shader
	if not shader:
		push_warning("SkyManager: sky_atmosphere.gdshader not found, keeping default sky")
		return

	sky_material = ShaderMaterial.new()
	sky_material.shader = shader

	# Set initial uniforms
	sky_material.set_shader_parameter("time_of_day", time_of_day)
	sky_material.set_shader_parameter("cloud_speed", 0.02)
	sky_material.set_shader_parameter("cloud_density", 0.45)
	sky_material.set_shader_parameter("cloud_coverage", 0.5)
	sky_material.set_shader_parameter("star_brightness", 1.0)
	sky_material.set_shader_parameter("star_density", 0.5)
	sky_material.set_shader_parameter("rayleigh_strength", 1.0)
	sky_material.set_shader_parameter("sun_size", 0.02)
	sky_material.set_shader_parameter("sun_intensity", 5.0)
	sky_material.set_shader_parameter("warm_tint", Color(1.04, 0.98, 0.93))
	sky_material.set_shader_parameter("tint_strength", 0.2)

	# Create Sky resource with the shader material
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_REALTIME  # needed for TIME uniform in shader

	# Apply to environment
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.2

	# Update sun light direction to match
	_sync_sun_direction()


# ── Day/Night Cycle Integration ──────────────────────────────────────────────

func set_shader_time(new_time: float) -> void:
	## Lightweight update: only sets the shader uniform for time of day.
	## Use this when another system (e.g. DayNightCycle) already controls
	## the sun direction and ambient light.
	time_of_day = clampf(new_time, 0.0, 1.0)
	if sky_material:
		sky_material.set_shader_parameter("time_of_day", time_of_day)


func update_time(new_time: float) -> void:
	## Full update: sets shader time AND syncs sun + ambient light.
	## Use this as standalone (when no DayNightCycle is present).
	time_of_day = clampf(new_time, 0.0, 1.0)
	if sky_material:
		sky_material.set_shader_parameter("time_of_day", time_of_day)
	_sync_sun_direction()
	_update_ambient_light()


func _sync_sun_direction() -> void:
	## Keep the DirectionalLight3D (Sun) pointing in the same direction as
	## the shader's computed sun position.
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if not sun:
		return

	# Match the shader's sun arc: angle = (time - 0.25) * TAU
	var angle := (time_of_day - 0.25) * TAU
	var sun_dir := Vector3(sin(angle) * 0.3, -cos(angle), sin(angle) * 0.8).normalized()

	# DirectionalLight3D shines along -Z in its local space, so we make it
	# look in the sun_dir direction (the light comes FROM the sun toward origin)
	sun.look_at(sun.global_position + sun_dir, Vector3.UP)

	# Adjust light energy based on sun altitude
	var sun_altitude := -sun_dir.y  # positive when sun is up
	var day_factor := smoothstep(-0.15, 0.2, sun_altitude)
	sun.light_energy = lerpf(0.05, 2.0, day_factor)

	# Warm color at sunset/sunrise
	var sunset_factor := smoothstep(0.2, 0.0, abs(sun_altitude)) * smoothstep(-0.15, 0.0, sun_altitude)
	var base_color := Color.WHITE
	var sunset_color := Color(1.0, 0.7, 0.45)
	sun.light_color = base_color.lerp(sunset_color, sunset_factor * 0.6)


func _update_ambient_light() -> void:
	if not environment:
		return
	# Shift ambient light color/energy with time of day
	var angle := (time_of_day - 0.25) * TAU
	var sun_altitude := cos(angle)
	var day_factor := smoothstep(-0.15, 0.2, sun_altitude)

	var day_ambient := Color(0.55, 0.73, 0.80)
	var night_ambient := Color(0.08, 0.1, 0.18)
	environment.ambient_light_color = night_ambient.lerp(day_ambient, day_factor)
	environment.ambient_light_energy = lerpf(0.3, 1.2, day_factor)


func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ── Cloud Controls ───────────────────────────────────────────────────────────

func set_cloud_speed(speed: float) -> void:
	if sky_material:
		sky_material.set_shader_parameter("cloud_speed", speed)


func set_cloud_density(density: float) -> void:
	if sky_material:
		sky_material.set_shader_parameter("cloud_density", density)


func set_cloud_coverage(coverage: float) -> void:
	if sky_material:
		sky_material.set_shader_parameter("cloud_coverage", coverage)


# ── Star Controls ────────────────────────────────────────────────────────────

func set_star_brightness(brightness: float) -> void:
	if sky_material:
		sky_material.set_shader_parameter("star_brightness", brightness)


func set_star_density(density: float) -> void:
	if sky_material:
		sky_material.set_shader_parameter("star_density", density)


# ── Atmosphere Controls ──────────────────────────────────────────────────────

func set_rayleigh_strength(strength: float) -> void:
	if sky_material:
		sky_material.set_shader_parameter("rayleigh_strength", strength)
