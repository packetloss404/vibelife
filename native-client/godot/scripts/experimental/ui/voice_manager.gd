class_name VoiceManager extends RefCounted
## Archived experimental module.
## mute/deafen state, spatial audio volume calculation, and WebSocket
## signaling events for WebRTC peer connections.
##
## Usage in main.gd:
##   var voice_manager = VoiceManager.new()
##   voice_manager.init(self)

# -- Untyped reference to the main scene node --
var main

# -- Local voice state --
var is_in_voice = false
var is_muted = false
var is_deafened = false
var is_push_to_talk = false
var is_speaking = false

# -- Channel state returned by the server --
var current_region_id = ""
var channel_id = ""
var ice_servers = []        # Array of { urls, username?, credential? }
var participants = {}       # accountId -> participant dict

# -- Spatial audio constants --
const SPATIAL_MAX_RANGE := 30.0

# -- HTTP request node (created on init) --
var _voice_http: HTTPRequest = null

# -- Pending request tracking --
var _pending_action = ""

func init(main_node) -> void:
	main = main_node
	_voice_http = HTTPRequest.new()
	main.add_child(_voice_http)
	_voice_http.request_completed.connect(_on_request_completed)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Join voice chat for the given region. Sends POST /api/voice/join.
func join_voice(region_id: String) -> void:
	if is_in_voice:
		return
	current_region_id = region_id
	var url = main.backend_url_input.text.rstrip("/") + "/api/voice/join"
	var body = JSON.stringify({
		"token": main.session.get("token", ""),
		"regionId": region_id
	})
	_pending_action = "join"
	_voice_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


## Leave voice chat. Sends POST /api/voice/leave.
func leave_voice() -> void:
	if not is_in_voice:
		return
	var url = main.backend_url_input.text.rstrip("/") + "/api/voice/leave"
	var body = JSON.stringify({
		"token": main.session.get("token", ""),
		"regionId": current_region_id
	})
	_pending_action = "leave"
	_voice_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


## Toggle local mute and notify the server.
func toggle_mute() -> void:
	is_muted = not is_muted
	if not is_in_voice:
		return
	var url = main.backend_url_input.text.rstrip("/") + "/api/voice/mute"
	var body = JSON.stringify({
		"token": main.session.get("token", ""),
		"regionId": current_region_id,
		"muted": is_muted
	})
	_pending_action = "mute"
	_voice_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


## Toggle local deafen and notify the server.
func toggle_deafen() -> void:
	is_deafened = not is_deafened
	if is_deafened:
		is_muted = true
	if not is_in_voice:
		return
	var url = main.backend_url_input.text.rstrip("/") + "/api/voice/deafen"
	var body = JSON.stringify({
		"token": main.session.get("token", ""),
		"regionId": current_region_id,
		"deafened": is_deafened
	})
	_pending_action = "deafen"
	_voice_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


# ---------------------------------------------------------------------------
# Spatial Audio
# ---------------------------------------------------------------------------

## Calculate volume for each speaker based on distance from the local avatar.
## `avatars` is a Dictionary of avatarId -> { position: Vector3, accountId: ... }
## Returns a Dictionary of accountId -> float (0.0 - 1.0).
func update_spatial_volumes(listener_pos: Vector3, avatars: Dictionary) -> Dictionary:
	var volumes = {}
	for account_id in participants:
		if not avatars.has(account_id):
			volumes[account_id] = 0.0
			continue
		var speaker_pos = avatars[account_id]
		var distance = listener_pos.distance_to(speaker_pos)
		if distance <= 0.0:
			volumes[account_id] = 1.0
		elif distance >= SPATIAL_MAX_RANGE:
			volumes[account_id] = 0.0
		else:
			var ratio = distance / SPATIAL_MAX_RANGE
			volumes[account_id] = maxf(0.0, 1.0 - ratio * ratio)
	return volumes


# ---------------------------------------------------------------------------
# WebSocket event handlers — called from main.gd ws message handler
# ---------------------------------------------------------------------------

## Call when a "voice:participant_joined" event arrives via WebSocket.
func handle_participant_joined(data: Dictionary) -> void:
	var participant = data.get("participant", {})
	var account_id = participant.get("accountId", "")
	if account_id == "":
		return
	participants[account_id] = participant

	# --- WebRTC stub ---
	# At this point we would create a new WebRTCPeerConnection for the
	# remote participant:
	#   var peer = WebRTCPeerConnection.new()
	#   peer.initialize({ "iceServers": ice_servers })
	#   peer.session_description_created.connect(_on_sdp_created.bind(account_id))
	#   peer.ice_candidate_created.connect(_on_ice_candidate.bind(account_id))
	#   peer.create_offer()
	# The SDP offer would then be sent to the server via a "voice:offer"
	# WebSocket command for relay to the target peer.


## Call when a "voice:participant_left" event arrives via WebSocket.
func handle_participant_left(data: Dictionary) -> void:
	var account_id = data.get("accountId", "")
	if participants.has(account_id):
		participants.erase(account_id)
	# --- WebRTC stub ---
	# We would close and remove the WebRTCPeerConnection for this account:
	#   if _peer_connections.has(account_id):
	#       _peer_connections[account_id].close()
	#       _peer_connections.erase(account_id)


## Call when a "voice:speaking_changed" event arrives via WebSocket.
func handle_speaking_changed(data: Dictionary) -> void:
	var account_id = data.get("accountId", "")
	var speaking = data.get("speaking", false)
	if participants.has(account_id):
		participants[account_id]["speaking"] = speaking


## Call when a "voice:offer" signaling message arrives (relayed by server).
func handle_voice_offer(data: Dictionary) -> void:
	var from_account_id = data.get("fromAccountId", "")
	var _sdp = data.get("sdp", "")
	# --- WebRTC stub ---
	# We would set the remote description and create an answer:
	#   var peer = _get_or_create_peer(from_account_id)
	#   peer.set_remote_description("offer", sdp)
	#   peer.create_answer()
	# The answer SDP is sent back via "voice:answer" WebSocket command.
	pass


## Call when a "voice:answer" signaling message arrives (relayed by server).
func handle_voice_answer(data: Dictionary) -> void:
	var from_account_id = data.get("fromAccountId", "")
	var _sdp = data.get("sdp", "")
	# --- WebRTC stub ---
	# We would set the remote description on the existing peer:
	#   if _peer_connections.has(from_account_id):
	#       _peer_connections[from_account_id].set_remote_description("answer", sdp)
	pass


## Call when a "voice:ice_candidate" signaling message arrives.
func handle_ice_candidate(data: Dictionary) -> void:
	var from_account_id = data.get("fromAccountId", "")
	var _candidate = data.get("candidate", {})
	# --- WebRTC stub ---
	# We would add the ICE candidate to the peer connection:
	#   if _peer_connections.has(from_account_id):
	#       _peer_connections[from_account_id].add_ice_candidate(
	#           candidate.get("sdpMid", ""),
	#           candidate.get("sdpMLineIndex", 0),
	#           candidate.get("candidate", "")
	#       )
	pass


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action = _pending_action
	_pending_action = ""

	if response_code < 200 or response_code >= 300:
		push_warning("VoiceManager: %s request failed with status %d" % [action, response_code])
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return

	if action == "join":
		is_in_voice = true
		channel_id = json.get("channelId", "")
		ice_servers = json.get("iceServers", [])
		var server_participants = json.get("participants", [])
		participants.clear()
		for p in server_participants:
			var aid = p.get("accountId", "")
			if aid != "":
				participants[aid] = p

	elif action == "leave":
		_reset_voice_state()

	# mute/deafen responses are informational — local state already updated


func _reset_voice_state() -> void:
	is_in_voice = false
	is_muted = false
	is_deafened = false
	is_speaking = false
	channel_id = ""
	current_region_id = ""
	ice_servers = []
	participants.clear()
	# --- WebRTC stub ---
	# We would close all peer connections:
	#   for account_id in _peer_connections:
	#       _peer_connections[account_id].close()
	#   _peer_connections.clear()


## Convenience: call from main.gd on disconnect/region-change to clean up.
func cleanup() -> void:
	if is_in_voice:
		leave_voice()
	_reset_voice_state()
