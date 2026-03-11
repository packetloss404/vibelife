class_name SpatialAudio extends RefCounted
## Handles spatial audio volume and panning calculations client-side.
## Uses inverse square falloff with configurable rolloff factor.
## NOTE: main.gd needs to call spatial_audio.init(self).

var main

const MAX_VOICE_DISTANCE = 30.0
const ROLLOFF_FACTOR = 2.0
const MIN_VOLUME = 0.0

func init(main_node) -> void:
	main = main_node

func calculate_volume(listener_pos: Vector3, speaker_pos: Vector3, max_distance: float = MAX_VOICE_DISTANCE) -> float:
	var distance = listener_pos.distance_to(speaker_pos)

	if distance <= 0.001:
		return 1.0

	if distance >= max_distance:
		return MIN_VOLUME

	# Inverse square falloff: volume = 1 / (1 + factor * (d / max_d)^2)
	var normalized = distance / max_distance
	var attenuation = 1.0 / (1.0 + ROLLOFF_FACTOR * normalized * normalized)

	return clampf(attenuation, MIN_VOLUME, 1.0)

func calculate_pan(listener_pos: Vector3, listener_forward: Vector3, speaker_pos: Vector3) -> float:
	var to_speaker = speaker_pos - listener_pos
	to_speaker.y = 0.0

	if to_speaker.length_squared() < 0.001:
		return 0.0

	to_speaker = to_speaker.normalized()

	var forward = listener_forward
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD

	forward = forward.normalized()

	# Right vector is cross product of up and forward
	var right = Vector3.UP.cross(forward).normalized()

	# Dot product with right vector gives panning: -1 left, +1 right
	var pan = to_speaker.dot(right)
	return clampf(pan, -1.0, 1.0)

func apply_spatial_audio(audio_player: Node, speaker_pos: Vector3) -> void:
	if main == null or audio_player == null:
		return

	var listener_pos = Vector3.ZERO
	var listener_forward = Vector3.FORWARD

	# Get listener position from camera
	if main.camera != null and is_instance_valid(main.camera):
		listener_pos = main.camera.global_position
		listener_forward = -main.camera.global_transform.basis.z

	var volume = calculate_volume(listener_pos, speaker_pos)
	var pan = calculate_pan(listener_pos, listener_forward, speaker_pos)

	# Convert volume to dB for Godot audio: linear_to_db
	if audio_player.has_method("set"):
		if volume <= MIN_VOLUME:
			audio_player.set("volume_db", -80.0)
		else:
			audio_player.set("volume_db", linear_to_db(volume))

	# Apply panning if the audio player supports it
	if audio_player.has_method("set") and audio_player.get("panning_strength") != null:
		# panning_strength 0.0 = center, map our -1..1 range
		# For AudioStreamPlayer, we use bus effects for panning
		pass

	# If it is an AudioStreamPlayer3D, set position directly
	if audio_player is AudioStreamPlayer3D:
		audio_player.global_position = speaker_pos
