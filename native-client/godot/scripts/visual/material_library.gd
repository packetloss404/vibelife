class_name MaterialLibrary
extends RefCounted

## Provides named PBR materials for the 6 build asset types, replacing the
## plain single-color StandardMaterial3D currently used in ObjectManager.
## Each material uses proper PBR settings (roughness, metallic, emission, etc.)
## tuned for the lo-fi chill aesthetic.

var main  # reference to Main node

# Cached materials keyed by name
var materials := {}


func init(main_node) -> void:
	main = main_node
	_build_library()


func _build_library() -> void:
	materials["wood"] = _make_wood()
	materials["stone"] = _make_stone()
	materials["metal"] = _make_metal()
	materials["glass"] = _make_glass()
	materials["foliage"] = _make_foliage()
	materials["water"] = _make_water()
	materials["emissive"] = _make_emissive()

	# Asset-specific materials (match the 6 build assets)
	materials["tower"] = _make_tower()
	materials["hall"] = _make_hall()
	materials["tree_trunk"] = _make_tree_trunk()
	materials["tree_canopy"] = _make_tree_canopy()
	materials["bench"] = _make_bench()
	materials["lantern_post"] = _make_lantern_post()
	materials["lantern_light"] = _make_lantern_light()
	materials["crate"] = _make_crate()


# ── Core Material Types ─────────────────────────────────────────────────────

func _make_wood() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("a7724f")
	mat.roughness = 0.85
	mat.metallic = 0.0
	mat.metallic_specular = 0.2
	mat.normal_scale = 0.5
	# Subtle subsurface tint for warmth
	mat.backlight_enabled = true
	mat.backlight = Color(0.3, 0.15, 0.05)
	return mat


func _make_stone() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8a8580")
	mat.roughness = 0.92
	mat.metallic = 0.0
	mat.metallic_specular = 0.15
	return mat


func _make_metal() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("7ea4b3")
	mat.roughness = 0.35
	mat.metallic = 0.7
	mat.metallic_specular = 0.6
	# Subtle rim highlight
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.3
	return mat


func _make_glass() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.92, 0.95, 0.35)
	mat.roughness = 0.05
	mat.metallic = 0.0
	mat.metallic_specular = 0.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.refraction_enabled = true
	mat.refraction_scale = 0.02
	# Fresnel-like rim
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.rim_tint = 0.0
	return mat


func _make_foliage() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("79ca92")
	mat.roughness = 0.88
	mat.metallic = 0.0
	mat.metallic_specular = 0.1
	# Two-sided for leaves
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Backlight for translucency
	mat.backlight_enabled = true
	mat.backlight = Color(0.2, 0.45, 0.15)
	return mat


func _make_water() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 0.6, 0.7)
	mat.roughness = 0.05
	mat.metallic = 0.15
	mat.metallic_specular = 0.7
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Subtle rim for water edge highlight
	mat.rim_enabled = true
	mat.rim = 0.4
	mat.rim_tint = 0.2
	return mat


func _make_emissive() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8cecff")
	mat.roughness = 0.5
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = Color("8cecff")
	mat.emission_energy_multiplier = 2.0
	return mat


# ── Asset-Specific Materials ────────────────────────────────────────────────

func _make_tower() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c7d3d9")
	mat.roughness = 0.75
	mat.metallic = 0.15
	mat.metallic_specular = 0.35
	# Slight blue tint rim for sci-fi feel
	mat.rim_enabled = true
	mat.rim = 0.2
	mat.rim_tint = 0.4
	return mat


func _make_hall() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d6d2c8")
	mat.roughness = 0.82
	mat.metallic = 0.0
	mat.metallic_specular = 0.2
	# Warm stone look
	mat.backlight_enabled = true
	mat.backlight = Color(0.12, 0.08, 0.04)
	return mat


func _make_tree_trunk() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("5b4634")
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.metallic_specular = 0.1
	mat.backlight_enabled = true
	mat.backlight = Color(0.15, 0.08, 0.03)
	return mat


func _make_tree_canopy() -> StandardMaterial3D:
	var mat := _make_foliage()
	mat.albedo_color = Color("79ca92")
	return mat


func _make_bench() -> StandardMaterial3D:
	var mat := _make_wood()
	mat.albedo_color = Color("a7724f")
	return mat


func _make_lantern_post() -> StandardMaterial3D:
	var mat := _make_metal()
	mat.albedo_color = Color("7ea4b3")
	return mat


func _make_lantern_light() -> StandardMaterial3D:
	var mat := _make_emissive()
	mat.albedo_color = Color("8cecff")
	mat.emission = Color("8cecff")
	mat.emission_energy_multiplier = 1.5
	return mat


func _make_crate() -> StandardMaterial3D:
	var mat := _make_wood()
	mat.albedo_color = Color("7f6147")
	mat.roughness = 0.88
	return mat


# ── Public API ───────────────────────────────────────────────────────────────

func get_material(material_name: String) -> StandardMaterial3D:
	## Returns a duplicate of the named material so each object gets its own
	## instance (needed for per-object emission toggling on selection).
	if materials.has(material_name):
		return (materials[material_name] as StandardMaterial3D).duplicate()
	push_warning("MaterialLibrary: unknown material '%s'" % material_name)
	return _make_fallback()


func get_material_for_asset(asset: String) -> StandardMaterial3D:
	## Given an asset path string (e.g. "/assets/models/park-bench.gltf"),
	## returns the appropriate PBR material.
	if asset.contains("tower"):
		return get_material("tower")
	elif asset.contains("hall"):
		return get_material("hall")
	elif asset.contains("bench"):
		return get_material("bench")
	elif asset.contains("lantern"):
		return get_material("lantern_post")
	elif asset.contains("crate"):
		return get_material("crate")
	elif asset.contains("tree"):
		return get_material("foliage")
	return get_material("stone")


func get_trunk_material() -> StandardMaterial3D:
	return get_material("tree_trunk")


func get_canopy_material() -> StandardMaterial3D:
	return get_material("tree_canopy")


func get_lantern_light_material() -> StandardMaterial3D:
	return get_material("lantern_light")


func _make_fallback() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.6, 0.6)
	mat.roughness = 0.85
	return mat
