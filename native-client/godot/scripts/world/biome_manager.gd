class_name BiomeManager extends RefCounted

var main


func init(main_node) -> void:
	main = main_node


func apply_biome(biome: Dictionary) -> void:
	if biome.is_empty():
		return

	_apply_fog(biome)
	_apply_ambient(biome)
	_apply_sun(biome)
	_apply_terrain_colors(biome)
	_apply_particles(biome)
	_apply_sky_tint(biome)


func _apply_fog(biome: Dictionary) -> void:
	var env = _get_environment()
	if env == null:
		return

	var fog_color_hex = biome.get("fogColor", "#aaaaaa")
	var fog_density = biome.get("fogDensity", 0.01)

	env.fog_enabled = true
	env.fog_light_color = Color(fog_color_hex)
	env.fog_density = float(fog_density)


func _apply_ambient(biome: Dictionary) -> void:
	var env = _get_environment()
	if env == null:
		return

	var ambient_color_hex = biome.get("ambientColor", "#ffffff")
	var ambient_energy = biome.get("ambientEnergy", 0.5)

	env.ambient_light_color = Color(ambient_color_hex)
	env.ambient_light_energy = float(ambient_energy)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR


func _apply_sun(biome: Dictionary) -> void:
	var sun = main.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		return

	var sun_color_hex = biome.get("sunColor", "#ffffff")
	var sun_energy = biome.get("sunEnergy", 1.0)

	sun.light_color = Color(sun_color_hex)
	sun.light_energy = float(sun_energy)


func _apply_terrain_colors(biome: Dictionary) -> void:
	var terrain_colors = biome.get("terrainColors", {})
	if terrain_colors is Dictionary and not terrain_colors.is_empty():
		var ground = main.get_node_or_null("Ground") as MeshInstance3D
		if ground == null:
			return

		var material = ground.material_override
		if material == null:
			material = ground.get_active_material(0)

		if material is ShaderMaterial:
			var shader_mat = material as ShaderMaterial
			if terrain_colors.has("grass"):
				shader_mat.set_shader_parameter("grass_color", Color(terrain_colors.grass))
			if terrain_colors.has("dirt"):
				shader_mat.set_shader_parameter("dirt_color", Color(terrain_colors.dirt))
			if terrain_colors.has("sand"):
				shader_mat.set_shader_parameter("sand_color", Color(terrain_colors.sand))
			if terrain_colors.has("stone"):
				shader_mat.set_shader_parameter("stone_color", Color(terrain_colors.stone))
		elif material is StandardMaterial3D:
			var grass_hex = terrain_colors.get("grass", "#4da060")
			(material as StandardMaterial3D).albedo_color = Color(grass_hex)


func _apply_particles(biome: Dictionary) -> void:
	var particle_type = biome.get("particleType", "fireflies")
	var particles_node = main.get_node_or_null("AmbientParticles")
	if particles_node == null:
		return

	if particles_node.has_method("set_particle_type"):
		particles_node.set_particle_type(str(particle_type))


func _apply_sky_tint(biome: Dictionary) -> void:
	var sky_tint_hex = biome.get("skyTint", "#ffffff")
	var env = _get_environment()
	if env == null:
		return

	if env.sky and env.sky.sky_material is ShaderMaterial:
		var sky_shader = env.sky.sky_material as ShaderMaterial
		sky_shader.set_shader_parameter("sky_tint", Color(sky_tint_hex))
	elif env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
		sky_mat.sky_top_color = Color(sky_tint_hex)
		sky_mat.sky_horizon_color = Color(sky_tint_hex).lerp(Color.WHITE, 0.3)

	var sky_mgr_node = main.get_node_or_null("SkyManager")
	if sky_mgr_node != null and sky_mgr_node.has_method("set_tint"):
		sky_mgr_node.set_tint(Color(sky_tint_hex))


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

	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env_node = WorldEnvironment.new()
	world_env_node.name = "WorldEnvironment"
	world_env_node.environment = env
	main.add_child(world_env_node)
	return env
