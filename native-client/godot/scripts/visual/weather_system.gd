class_name WeatherSystem extends RefCounted

var main
var current_weather := "clear"
var rain_particles: GPUParticles3D = null
var wind_particles: GPUParticles3D = null
var base_fog_density := 0.01


func init(main_node) -> void:
	main = main_node


func set_weather(type: String) -> void:
	current_weather = type
	_clear_weather_effects()

	match type:
		"foggy":
			_apply_foggy()
		"rainy":
			_apply_rainy()
		"windy":
			_apply_windy()
		"clear", _:
			_apply_clear()


func _clear_weather_effects() -> void:
	if rain_particles != null and is_instance_valid(rain_particles):
		rain_particles.queue_free()
		rain_particles = null
	if wind_particles != null and is_instance_valid(wind_particles):
		wind_particles.queue_free()
		wind_particles = null


func _apply_clear() -> void:
	var env = _get_environment()
	if env:
		env.fog_density = base_fog_density
		env.volumetric_fog_enabled = false


func _apply_foggy() -> void:
	var env = _get_environment()
	if env:
		env.fog_enabled = true
		env.fog_density = base_fog_density * 3.0


func _apply_rainy() -> void:
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "WeatherRain"
	rain_particles.amount = 2000
	rain_particles.lifetime = 1.5
	rain_particles.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 30, 60))
	rain_particles.emitting = true

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 5.0
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 24.0
	material.gravity = Vector3(0, -9.8, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(30, 0.5, 30)
	material.color = Color(0.6, 0.65, 0.75, 0.5)
	rain_particles.process_material = material

	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.02, 0.4, 0.02)
	var mesh_material = StandardMaterial3D.new()
	mesh_material.albedo_color = Color(0.6, 0.65, 0.75, 0.5)
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mesh_material
	rain_particles.draw_pass_1 = mesh

	rain_particles.position = Vector3(0, 15, 0)
	main.add_child(rain_particles)

	var env = _get_environment()
	if env:
		env.fog_enabled = true
		env.fog_density = base_fog_density * 2.0


func _apply_windy() -> void:
	wind_particles = GPUParticles3D.new()
	wind_particles.name = "WeatherWind"
	wind_particles.amount = 300
	wind_particles.lifetime = 4.0
	wind_particles.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 20, 60))
	wind_particles.emitting = true

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(1, 0.1, 0.3).normalized()
	material.spread = 20.0
	material.initial_velocity_min = 4.0
	material.initial_velocity_max = 8.0
	material.gravity = Vector3(0, -0.5, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(25, 8, 25)
	material.color = Color(0.85, 0.82, 0.75, 0.4)
	material.scale_min = 0.5
	material.scale_max = 1.5
	rain_particles = null
	wind_particles.process_material = material

	var mesh = SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	var mesh_material = StandardMaterial3D.new()
	mesh_material.albedo_color = Color(0.85, 0.82, 0.75, 0.4)
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mesh_material
	wind_particles.draw_pass_1 = mesh

	wind_particles.position = Vector3(0, 4, 0)
	main.add_child(wind_particles)

	var env = _get_environment()
	if env:
		env.fog_enabled = true
		env.fog_density = base_fog_density * 1.5


func set_base_fog_density(density: float) -> void:
	base_fog_density = density


func _get_environment() -> Environment:
	var camera = main.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if camera and camera.environment:
		return camera.environment

	var world_env = main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		return world_env.environment

	var viewport = main.get_viewport()
	if viewport:
		var world = viewport.world_3d
		if world and world.environment:
			return world.environment

	return null
