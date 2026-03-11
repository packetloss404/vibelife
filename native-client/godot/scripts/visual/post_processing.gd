class_name PostProcessing
extends RefCounted
## Configures WorldEnvironment post-processing effects for the lo-fi aesthetic.
## Attach to the WorldEnvironment node via main.gd to apply bloom, tonemap,
## SSAO, fog, and depth of field programmatically.

var world_env: WorldEnvironment
var environment: Environment

# Quality preset: "low", "medium", "high"
var quality_preset := "medium"


func init(p_world_env: WorldEnvironment) -> void:
	world_env = p_world_env
	environment = world_env.environment
	if environment == null:
		environment = Environment.new()
		world_env.environment = environment
	apply_all()


func apply_all() -> void:
	_apply_tonemap()
	_apply_bloom()
	_apply_ssao()
	_apply_fog()
	_apply_dof()
	_apply_adjustments()


# ── Tonemap ──────────────────────────────────────────────────────────────────

func _apply_tonemap() -> void:
	# ACES Filmic for warm, cinematic lo-fi look
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0


# ── Bloom ────────────────────────────────────────────────────────────────────

func _apply_bloom() -> void:
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.15
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.glow_hdr_threshold = 0.85
	environment.glow_hdr_scale = 2.0

	# Per-level intensities: subtle at small scales, stronger at large
	environment.set_glow_level(0, 0.0)   # finest detail - off
	environment.set_glow_level(1, 0.4)
	environment.set_glow_level(2, 0.7)
	environment.set_glow_level(3, 1.0)
	environment.set_glow_level(4, 0.8)
	environment.set_glow_level(5, 0.5)
	environment.set_glow_level(6, 0.3)


# ── SSAO ─────────────────────────────────────────────────────────────────────

func _apply_ssao() -> void:
	environment.ssao_enabled = true
	environment.ssao_radius = 1.5
	environment.ssao_intensity = 1.2
	environment.ssao_power = 1.8
	environment.ssao_detail = 0.5
	environment.ssao_horizon = 0.06
	environment.ssao_sharpness = 0.9
	environment.ssao_light_affect = 0.3


# ── Volumetric Fog ───────────────────────────────────────────────────────────

func _apply_fog() -> void:
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.85, 0.78, 0.65) # warm tint
	environment.fog_light_energy = 0.4
	environment.fog_sun_scatter = 0.3
	environment.fog_density = 0.003
	# Depth fog: gradual fade into distance
	environment.fog_aerial_perspective = 0.4
	environment.fog_sky_affect = 0.3


# ── Depth of Field ───────────────────────────────────────────────────────────

func _apply_dof() -> void:
	# DOF in Godot 4.6 is controlled via CameraAttributes on Camera3D.
	# Apply it there if a camera is available at runtime.
	pass


# ── Color Adjustments ────────────────────────────────────────────────────────

func _apply_adjustments() -> void:
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.9 # slightly desaturated for lo-fi feel


# ── Runtime API ──────────────────────────────────────────────────────────────

func set_bloom_intensity(value: float) -> void:
	environment.glow_intensity = clampf(value, 0.0, 2.0)


func set_fog_density(value: float) -> void:
	environment.fog_density = clampf(value, 0.0, 0.05)


func set_fog_color(color: Color) -> void:
	environment.fog_light_color = color


func set_dof_far_distance(value: float) -> void:
	environment.dof_blur_far_distance = value


func set_ssao_enabled(enabled: bool) -> void:
	environment.ssao_enabled = enabled


func set_quality(preset: String) -> void:
	quality_preset = preset
	match preset:
		"low":
			environment.ssao_enabled = false
			environment.glow_enabled = true
			environment.glow_intensity = 0.3
			environment.dof_blur_far_enabled = false
		"medium":
			apply_all()
		"high":
			apply_all()
			environment.ssao_radius = 2.0
			environment.ssao_intensity = 1.5
			environment.glow_intensity = 0.8
