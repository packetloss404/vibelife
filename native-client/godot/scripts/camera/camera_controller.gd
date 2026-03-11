class_name CameraController
extends RefCounted

var camera_rig: Node3D
var camera: Camera3D
var yaw := 0.0
var pitch := 0.45
var orbiting := false


func init(rig: Node3D, cam: Camera3D) -> void:
	camera_rig = rig
	camera = cam


func update(delta: float, avatar_position: Vector3) -> void:
	var target := avatar_position + Vector3(0, 2.5, 0)
	var cam_distance := camera.position.z
	var desired := target + Vector3(
		sin(yaw) * cos(pitch) * cam_distance,
		sin(pitch) * cam_distance + 2.0,
		cos(yaw) * cos(pitch) * cam_distance
	)
	camera_rig.position = camera_rig.position.lerp(desired, minf(1.0, delta * 6.0))
	camera.look_at(target)


func handle_orbit(relative: Vector2, sensitivity: float, invert: bool) -> void:
	var invert_factor := -1.0 if invert else 1.0
	yaw -= relative.x * 0.005 * sensitivity
	pitch = clamp(pitch - relative.y * 0.004 * sensitivity * invert_factor, 0.15, 1.1)
