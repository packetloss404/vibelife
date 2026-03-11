class_name SeasonalManager extends RefCounted

## SeasonalManager — handles seasonal content: themes, items, decorations, particles.
## Usage: var sm = SeasonalManager.new(); sm.init(main_node)
## NOTE: main.gd needs: var seasonal_manager = SeasonalManager.new() and seasonal_manager.init(self) in _ready()

var main
var current_season = ""
var active_holidays = []
var collected_items = []
var seasonal_items = []
var seasonal_progress = {}
var seasonal_particles_node = null

var _season_request: HTTPRequest = null
var _items_request: HTTPRequest = null
var _collect_request: HTTPRequest = null
var _progress_request: HTTPRequest = null
var _decorations_request: HTTPRequest = null
var _theme_request: HTTPRequest = null

func init(main_node) -> void:
	main = main_node

	_season_request = HTTPRequest.new()
	_season_request.name = "SeasonalSeasonRequest"
	main.add_child(_season_request)
	_season_request.request_completed.connect(_on_season_loaded)

	_items_request = HTTPRequest.new()
	_items_request.name = "SeasonalItemsRequest"
	main.add_child(_items_request)
	_items_request.request_completed.connect(_on_items_loaded)

	_collect_request = HTTPRequest.new()
	_collect_request.name = "SeasonalCollectRequest"
	main.add_child(_collect_request)
	_collect_request.request_completed.connect(_on_item_collected)

	_progress_request = HTTPRequest.new()
	_progress_request.name = "SeasonalProgressRequest"
	main.add_child(_progress_request)
	_progress_request.request_completed.connect(_on_progress_loaded)

	_decorations_request = HTTPRequest.new()
	_decorations_request.name = "SeasonalDecorationsRequest"
	main.add_child(_decorations_request)
	_decorations_request.request_completed.connect(_on_decorations_loaded)

	_theme_request = HTTPRequest.new()
	_theme_request.name = "SeasonalThemeRequest"
	main.add_child(_theme_request)
	_theme_request.request_completed.connect(_on_theme_loaded)


func _base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _token() -> String:
	return main.session.get("token", "")


# ---- Public API ----

func load_season() -> void:
	var url = _base_url() + "/api/seasonal/current"
	_season_request.request(url, [], HTTPClient.METHOD_GET)


func load_items(season_filter: String = "") -> void:
	var url = _base_url() + "/api/seasonal/items"
	if season_filter != "":
		url += "?season=" + season_filter
	_items_request.request(url, [], HTTPClient.METHOD_GET)


func collect_item(item_id: String) -> void:
	var url = _base_url() + "/api/seasonal/items/" + item_id + "/collect"
	var body = JSON.stringify({"token": _token()})
	var headers = ["Content-Type: application/json"]
	_collect_request.request(url, headers, HTTPClient.METHOD_POST, body)


func load_progress() -> void:
	var url = _base_url() + "/api/seasonal/progress?token=" + _token()
	_progress_request.request(url, [], HTTPClient.METHOD_GET)


func load_decorations(region_id: String) -> void:
	var url = _base_url() + "/api/seasonal/decorations?regionId=" + region_id
	_decorations_request.request(url, [], HTTPClient.METHOD_GET)


func load_theme(region_id: String) -> void:
	var url = _base_url() + "/api/seasonal/theme/" + region_id
	_theme_request.request(url, [], HTTPClient.METHOD_GET)


func apply_seasonal_theme(theme_data: Dictionary) -> void:
	var season = theme_data.get("season", "")
	if season == "":
		return

	# Adjust environment fog color
	var env = main.get_viewport().world_3d.environment
	if env == null:
		env = Environment.new()
		main.get_viewport().world_3d.environment = env

	var fog_color = _hex_to_color(theme_data.get("fogColor", "#ffffff"))
	var sun_color = _hex_to_color(theme_data.get("sunColor", "#ffffff"))
	var sky_tint = _hex_to_color(theme_data.get("skyTint", "#87ceeb"))
	var ambient_intensity = theme_data.get("ambientIntensity", 0.5)

	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = 0.002
	env.ambient_light_color = sky_tint
	env.ambient_light_energy = ambient_intensity

	# Adjust sun / directional light if present
	var sun = _find_directional_light(main)
	if sun != null:
		sun.light_color = sun_color

	# Spawn seasonal ambient particles
	_spawn_seasonal_particles(season)


# ---- Particle System ----

func _spawn_seasonal_particles(season: String) -> void:
	# Remove previous particles
	if seasonal_particles_node != null and is_instance_valid(seasonal_particles_node):
		seasonal_particles_node.queue_free()
		seasonal_particles_node = null

	var particles = GPUParticles3D.new()
	particles.name = "SeasonalParticles"
	particles.emitting = true
	particles.amount = 200
	particles.lifetime = 6.0
	particles.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 20, 60))

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 25.0
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.5
	material.gravity = Vector3(0, -0.8, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(25, 0.5, 25)

	match season:
		"spring":
			# Cherry blossom petals — pink, light, drifting
			material.gravity = Vector3(0.3, -0.4, 0.2)
			material.initial_velocity_min = 0.3
			material.initial_velocity_max = 0.8
			material.spread = 45.0
			particles.amount = 150
			particles.lifetime = 8.0
			material.color = Color(1.0, 0.7, 0.8, 0.8)
		"summer":
			# Fireflies — yellowish, slow, floating upward occasionally
			material.gravity = Vector3(0, 0.05, 0)
			material.initial_velocity_min = 0.1
			material.initial_velocity_max = 0.4
			material.spread = 180.0
			particles.amount = 80
			particles.lifetime = 4.0
			material.color = Color(1.0, 1.0, 0.4, 0.9)
		"autumn":
			# Falling leaves — orange/brown, swaying
			material.gravity = Vector3(0.5, -0.6, 0.3)
			material.initial_velocity_min = 0.2
			material.initial_velocity_max = 0.7
			material.spread = 40.0
			particles.amount = 120
			particles.lifetime = 10.0
			material.color = Color(0.9, 0.5, 0.1, 0.85)
		"winter":
			# Snowflakes — white, gentle drift
			material.gravity = Vector3(0.1, -0.5, 0.05)
			material.initial_velocity_min = 0.2
			material.initial_velocity_max = 0.6
			material.spread = 30.0
			particles.amount = 250
			particles.lifetime = 7.0
			material.color = Color(1.0, 1.0, 1.0, 0.9)

	particles.process_material = material

	# Add a simple quad mesh as the draw pass
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	var mesh_material = StandardMaterial3D.new()
	mesh_material.albedo_color = material.color
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mesh_material
	particles.draw_pass_1 = mesh

	# Position above the camera
	particles.position = Vector3(0, 12, 0)

	main.add_child(particles)
	seasonal_particles_node = particles


# ---- Callbacks ----

func _on_season_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	current_season = json.get("season", "")
	active_holidays = json.get("holidays", [])


func _on_items_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	seasonal_items = json.get("items", [])


func _on_item_collected(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	if json.get("ok", false):
		# Refresh progress after collecting
		load_progress()


func _on_progress_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	seasonal_progress = json.get("progress", {})
	collected_items = seasonal_progress.get("itemsCollected", [])


func _on_decorations_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	var decorations = json.get("decorations", [])
	_render_decorations(decorations)


func _on_theme_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	var theme = json.get("theme", {})
	if theme.size() > 0:
		apply_seasonal_theme(theme)


# ---- Helpers ----

func _render_decorations(decorations: Array) -> void:
	# Placeholder: create simple marker meshes for seasonal decorations
	for deco in decorations:
		var marker = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.5, 0.5, 0.5)
		var mat = StandardMaterial3D.new()
		match deco.get("season", ""):
			"spring":
				mat.albedo_color = Color(1.0, 0.7, 0.8)
			"summer":
				mat.albedo_color = Color(1.0, 0.9, 0.3)
			"autumn":
				mat.albedo_color = Color(0.9, 0.5, 0.1)
			"winter":
				mat.albedo_color = Color(0.8, 0.9, 1.0)
			_:
				mat.albedo_color = Color(0.7, 0.7, 0.7)
		box.material = mat
		marker.mesh = box
		marker.name = "SeasonalDeco_" + str(deco.get("id", ""))
		main.add_child(marker)


func _hex_to_color(hex: String) -> Color:
	if hex.begins_with("#"):
		hex = hex.substr(1)
	if hex.length() != 6:
		return Color.WHITE
	var r = hex.substr(0, 2).hex_to_int() / 255.0
	var g = hex.substr(2, 2).hex_to_int() / 255.0
	var b = hex.substr(4, 2).hex_to_int() / 255.0
	return Color(r, g, b)


func _find_directional_light(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node as DirectionalLight3D
	for child in node.get_children():
		var found = _find_directional_light(child)
		if found != null:
			return found
	return null
