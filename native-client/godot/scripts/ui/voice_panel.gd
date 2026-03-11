class_name VoicePanel extends RefCounted
## Voice chat control panel — manages UI state for voice controls.
## Handles join/leave, mute/deafen, push-to-talk, and volume.
## NOTE: main.gd needs to call voice_panel.init(self) and
##       voice_panel._input(event) from its own _input callback.

var main

var is_connected = false
var is_muted = false
var is_deafened = false
var is_push_to_talk = false
var voice_volume = 1.0
var push_to_talk_active = false

const PTT_KEY = KEY_V
const MIN_VOLUME = 0.0
const MAX_VOLUME = 1.0

signal voice_joined(region_id: String)
signal voice_left()
signal mute_changed(muted: bool)
signal deafen_changed(deafened: bool)
signal ptt_changed(active: bool)
signal volume_changed(volume: float)
signal speaking_state_changed(is_speaking: bool)

func init(main_node) -> void:
	main = main_node

func join_voice() -> void:
	if is_connected:
		return
	if main == null:
		return

	is_connected = true
	is_muted = false
	is_deafened = false
	push_to_talk_active = false

	# Send join request to server
	var base_url = main.backend_url_input.text.rstrip("/")
	var session = main.get("session")
	if session != null:
		var region_id = session.get("regionId", "")
		voice_joined.emit(region_id)

func leave_voice() -> void:
	if not is_connected:
		return

	is_connected = false
	is_muted = false
	is_deafened = false
	push_to_talk_active = false
	voice_left.emit()
	speaking_state_changed.emit(false)

func toggle_mute() -> void:
	if not is_connected:
		return

	is_muted = not is_muted

	# Unmute deafen if we're unmuting
	if not is_muted and is_deafened:
		is_deafened = false
		deafen_changed.emit(false)

	mute_changed.emit(is_muted)

	# If muted, stop transmitting
	if is_muted:
		speaking_state_changed.emit(false)

func toggle_deafen() -> void:
	if not is_connected:
		return

	is_deafened = not is_deafened

	# Deafen implies mute
	if is_deafened and not is_muted:
		is_muted = true
		mute_changed.emit(true)

	deafen_changed.emit(is_deafened)

	if is_deafened:
		speaking_state_changed.emit(false)

func toggle_push_to_talk() -> void:
	is_push_to_talk = not is_push_to_talk
	push_to_talk_active = false
	ptt_changed.emit(is_push_to_talk)

	# When switching to PTT, stop transmitting until key is held
	if is_push_to_talk:
		speaking_state_changed.emit(false)

func set_voice_volume(volume: float) -> void:
	voice_volume = clampf(volume, MIN_VOLUME, MAX_VOLUME)
	volume_changed.emit(voice_volume)

func get_voice_status() -> String:
	if not is_connected:
		return "Disconnected"
	if is_deafened:
		return "Deafened"
	if is_muted:
		return "Muted"
	return "Connected"

func is_transmitting() -> bool:
	if not is_connected:
		return false
	if is_muted or is_deafened:
		return false
	if is_push_to_talk:
		return push_to_talk_active
	return true

func _input(event: InputEvent) -> void:
	if not is_connected or not is_push_to_talk:
		return

	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.keycode == PTT_KEY:
			var was_active = push_to_talk_active

			if key_event.pressed and not key_event.echo:
				push_to_talk_active = true
			elif not key_event.pressed:
				push_to_talk_active = false

			if push_to_talk_active != was_active:
				if not is_muted and not is_deafened:
					speaking_state_changed.emit(push_to_talk_active)
