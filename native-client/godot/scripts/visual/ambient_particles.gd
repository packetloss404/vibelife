class_name AmbientParticles
extends RefCounted

## Spawns subtle ambient particle effects that adjust based on time of day.
## - Fireflies at night (warm glowing dots)
## - Dust motes during the day (soft floating specks)
## - Leaves in the wind (gentle drifting particles)
## Uses GPUParticles3D for performance.

var main  # reference to Main node

var fireflies: GPUParticles3D
var dust_motes: GPUParticles3D
var leaves: GPUParticles3D

var time_of_day := 0.35
var particles_root: Node3D


func init(main_node) -> void:
	main = main_node


func setup_particles() -> void:
	particles_root = Node3D.new()
	particles_root.name = "AmbientParticles"
	main.add_child(particles_root)

	_create_fireflies()
	_create_dust_motes()
	_create_leaves()

	# Set initial visibility
	update_time(time_of_day)


# ── Fireflies (night) ───────────────────────────────────────────────────────

func _create_fireflies() -> void:
	fireflies = GPUParticles3D.new()
	fireflies.name = "Fireflies"
	fireflies.amount = 40
	fireflies.lifetime = 4.0
	fireflies.emitting = false  # starts hidden, enabled at night
	fireflies.visibility_aabb = AABB(Vector3(-20, 0, -20), Vector3(40, 8, 40))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(15.0, 3.0, 15.0)

	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0.0, 0.0, 0.0)
	mat.damping_min = 1.0
	mat.damping_max = 2.0

	# Scale
	mat.scale_min = 0.04
	mat.scale_max = 0.08

	# Warm glow color
	mat.color = Color(0.9, 0.85, 0.3, 0.9)

	fireflies.process_material = mat

	# Simple mesh for the particle (small sphere)
	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = 0.05
	draw_mesh.height = 0.1
	draw_mesh.radial_segments = 4
	draw_mesh.rings = 2
	fireflies.draw_pass_1 = draw_mesh

	# Emissive material so fireflies glow
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = Color(1.0, 0.95, 0.4)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(1.0, 0.9, 0.3)
	draw_mat.emission_energy_multiplier = 3.0
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mesh.material = draw_mat

	particles_root.add_child(fireflies)


# ── Dust Motes (day) ────────────────────────────────────────────────────────

func _create_dust_motes() -> void:
	dust_motes = GPUParticles3D.new()
	dust_motes.name = "DustMotes"
	dust_motes.amount = 60
	dust_motes.lifetime = 6.0
	dust_motes.emitting = true
	dust_motes.visibility_aabb = AABB(Vector3(-20, 0, -20), Vector3(40, 10, 40))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(18.0, 5.0, 18.0)

	mat.direction = Vector3(0.3, 0.1, 0.2)
	mat.spread = 60.0
	mat.initial_velocity_min = 0.05
	mat.initial_velocity_max = 0.2
	mat.gravity = Vector3(0.0, -0.02, 0.0)

	mat.scale_min = 0.015
	mat.scale_max = 0.035

	# Soft warm dust color
	mat.color = Color(0.9, 0.85, 0.7, 0.35)

	dust_motes.process_material = mat

	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = 0.03
	draw_mesh.height = 0.06
	draw_mesh.radial_segments = 4
	draw_mesh.rings = 2
	dust_motes.draw_pass_1 = draw_mesh

	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = Color(1.0, 0.95, 0.85, 0.4)
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mesh.material = draw_mat

	particles_root.add_child(dust_motes)


# ── Leaves (wind) ────────────────────────────────────────────────────────────

func _create_leaves() -> void:
	leaves = GPUParticles3D.new()
	leaves.name = "Leaves"
	leaves.amount = 20
	leaves.lifetime = 5.0
	leaves.emitting = true
	leaves.visibility_aabb = AABB(Vector3(-25, 0, -25), Vector3(50, 12, 50))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(20.0, 2.0, 20.0)

	# Wind-driven direction
	mat.direction = Vector3(1.0, -0.3, 0.5)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.8
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0.0, -0.5, 0.0)

	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max = 90.0

	mat.scale_min = 0.04
	mat.scale_max = 0.08

	# Leaf green/brown mix
	mat.color = Color(0.5, 0.6, 0.3, 0.7)

	leaves.process_material = mat

	# Flat quad-ish mesh for leaf shape
	var draw_mesh := PlaneMesh.new()
	draw_mesh.size = Vector2(0.08, 0.05)
	leaves.draw_pass_1 = draw_mesh

	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = Color(0.45, 0.55, 0.25, 0.75)
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw_mesh.material = draw_mat

	# Offset leaves upward so they appear to fall from tree height
	leaves.position.y = 4.0

	particles_root.add_child(leaves)


# ── Time of Day Integration ─────────────────────────────────────────────────

func update_time(tod: float) -> void:
	## tod: 0.0 = midnight, 0.5 = noon
	time_of_day = tod

	# Sun altitude calculation (matches sky shader)
	var angle := (tod - 0.25) * TAU
	var sun_altitude := cos(angle)
	var day_factor := clampf((sun_altitude + 0.15) / 0.35, 0.0, 1.0)

	# Fireflies: visible at night (day_factor < 0.3)
	var firefly_vis := 1.0 - clampf((day_factor - 0.1) / 0.2, 0.0, 1.0)
	fireflies.emitting = firefly_vis > 0.1
	if fireflies.process_material is ParticleProcessMaterial:
		(fireflies.process_material as ParticleProcessMaterial).color.a = firefly_vis * 0.9

	# Dust motes: visible during day
	dust_motes.emitting = day_factor > 0.2
	if dust_motes.process_material is ParticleProcessMaterial:
		(dust_motes.process_material as ParticleProcessMaterial).color.a = day_factor * 0.35

	# Leaves: always on but reduced at night
	if leaves.process_material is ParticleProcessMaterial:
		(leaves.process_material as ParticleProcessMaterial).color.a = 0.3 + day_factor * 0.4


# ── Runtime Controls ────────────────────────────────────────────────────────

func set_wind_direction(dir: Vector3) -> void:
	## Adjust leaf drift direction to match wind.
	if leaves and leaves.process_material is ParticleProcessMaterial:
		var mat := leaves.process_material as ParticleProcessMaterial
		mat.direction = dir.normalized()


func set_firefly_count(count: int) -> void:
	if fireflies:
		fireflies.amount = clampi(count, 1, 200)


func set_dust_count(count: int) -> void:
	if dust_motes:
		dust_motes.amount = clampi(count, 1, 200)
