class_name VoicePanelUI
extends Control

## Voice chat control panel for VibeLife.
## Join/Leave, Mute/Deafen toggles, participant list with speaking indicators.

var main  # reference to main node

# HTTP request nodes
var _join_request: HTTPRequest
var _leave_request: HTTPRequest
var _mute_request: HTTPRequest
var _deafen_request: HTTPRequest
var _participants_request: HTTPRequest

# State
var _connected := false
var _muted := false
var _deafened := false
var _participants: Array = []  # [{accountId, displayName, muted, speaking}]
var _speaking_ids: Dictionary = {}  # accountId -> bool

# UI references
var _join_leave_btn: Button
var _mute_btn: Button
var _deafen_btn: Button
var _status_label: Label
var _connection_label: Label
var _participants_scroll: ScrollContainer
var _participants_list: VBoxContainer
var _participant_rows: Dictionary = {}  # accountId -> {row, name_label, mic_icon, speaking_indicator}


func init(main_node) -> void:
	main = main_node
	name = "VoicePanelUI"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var canvas_layer = main.get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(self)

	# Create HTTP request nodes
	_join_request = _make_http("VoiceJoinReq", _on_join_response)
	_leave_request = _make_http("VoiceLeaveReq", _on_leave_response)
	_mute_request = _make_http("VoiceMuteReq", _on_mute_response)
	_deafen_request = _make_http("VoiceDeafenReq", _on_deafen_response)
	_participants_request = _make_http("VoiceParticipantsReq", _on_participants_loaded)

	_build_ui()


func _make_http(node_name: String, callback: Callable) -> HTTPRequest:
	var req := HTTPRequest.new()
	req.name = node_name
	main.add_child(req)
	req.request_completed.connect(callback)
	return req


func _base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _token() -> String:
	return main.session.get("token", "")


func _region_id() -> String:
	return main.session.get("regionId", "")


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.08, 0.1, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.name = "RootVBox"
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "Voice Chat"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	# Connection status
	_connection_label = Label.new()
	_connection_label.text = "Disconnected"
	_connection_label.add_theme_font_size_override("font_size", 14)
	_connection_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	root_vbox.add_child(_connection_label)

	# Controls row
	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(controls_row)

	# Join/Leave button
	_join_leave_btn = Button.new()
	_join_leave_btn.text = "Join Voice"
	_join_leave_btn.custom_minimum_size = Vector2(120, 36)
	_join_leave_btn.pressed.connect(_on_join_leave_pressed)
	controls_row.add_child(_join_leave_btn)

	_style_button(_join_leave_btn, Color(0.2, 0.5, 0.3))

	# Mute button
	_mute_btn = Button.new()
	_mute_btn.text = "[Mic] Mute"
	_mute_btn.custom_minimum_size = Vector2(100, 36)
	_mute_btn.disabled = true
	_mute_btn.pressed.connect(_on_mute_pressed)
	controls_row.add_child(_mute_btn)

	# Deafen button
	_deafen_btn = Button.new()
	_deafen_btn.text = "[Headphone] Deafen"
	_deafen_btn.custom_minimum_size = Vector2(140, 36)
	_deafen_btn.disabled = true
	_deafen_btn.pressed.connect(_on_deafen_pressed)
	controls_row.add_child(_deafen_btn)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	root_vbox.add_child(_status_label)

	# Separator
	var sep_label := Label.new()
	sep_label.text = "Participants"
	sep_label.add_theme_font_size_override("font_size", 16)
	sep_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	root_vbox.add_child(sep_label)

	# Participant list (scrollable)
	_participants_scroll = ScrollContainer.new()
	_participants_scroll.name = "ParticipantsScroll"
	_participants_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_participants_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_participants_scroll)

	_participants_list = VBoxContainer.new()
	_participants_list.name = "ParticipantsList"
	_participants_list.add_theme_constant_override("separation", 4)
	_participants_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_participants_scroll.add_child(_participants_list)


func _style_button(btn: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)


# ── Panel Visibility ─────────────────────────────────────────────────────────

func show_panel() -> void:
	visible = true
	if _connected:
		_load_participants()
	_update_ui_state()


# ── UI State Update ──────────────────────────────────────────────────────────

func _update_ui_state() -> void:
	if _connected:
		_connection_label.text = "Connected"
		_connection_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		_join_leave_btn.text = "Leave Voice"
		_style_button(_join_leave_btn, Color(0.5, 0.2, 0.2))
		_mute_btn.disabled = false
		_deafen_btn.disabled = false
	else:
		_connection_label.text = "Disconnected"
		_connection_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
		_join_leave_btn.text = "Join Voice"
		_style_button(_join_leave_btn, Color(0.2, 0.5, 0.3))
		_mute_btn.disabled = true
		_deafen_btn.disabled = true

	# Mute state
	if _muted:
		_mute_btn.text = "[Mic OFF] Unmute"
		_style_button(_mute_btn, Color(0.6, 0.2, 0.2))
	else:
		_mute_btn.text = "[Mic] Mute"
		if not _mute_btn.disabled:
			_style_button(_mute_btn, Color(0.25, 0.25, 0.3))

	# Deafen state
	if _deafened:
		_deafen_btn.text = "[Headphone OFF] Undeafen"
		_style_button(_deafen_btn, Color(0.6, 0.2, 0.2))
	else:
		_deafen_btn.text = "[Headphone] Deafen"
		if not _deafen_btn.disabled:
			_style_button(_deafen_btn, Color(0.25, 0.25, 0.3))


# ── Actions ──────────────────────────────────────────────────────────────────

func _on_join_leave_pressed() -> void:
	if _connected:
		_leave_voice()
	else:
		_join_voice()


func _join_voice() -> void:
	var token := _token()
	var region := _region_id()
	if token.is_empty() or region.is_empty():
		_status_label.text = "Not in a region"
		return
	_status_label.text = "Joining..."
	var url := "%s/api/voice/join" % _base_url()
	var body := JSON.stringify({"token": token, "regionId": region})
	var headers := PackedStringArray(["Content-Type: application/json"])
	_join_request.request(url, headers, HTTPClient.METHOD_POST, body)


func _leave_voice() -> void:
	var token := _token()
	if token.is_empty():
		return
	_status_label.text = "Leaving..."
	var url := "%s/api/voice/leave" % _base_url()
	var body := JSON.stringify({"token": token})
	var headers := PackedStringArray(["Content-Type: application/json"])
	_leave_request.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_mute_pressed() -> void:
	var token := _token()
	if token.is_empty():
		return
	var url := "%s/api/voice/mute" % _base_url()
	var body := JSON.stringify({"token": token, "muted": not _muted})
	var headers := PackedStringArray(["Content-Type: application/json"])
	_mute_request.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_deafen_pressed() -> void:
	var token := _token()
	if token.is_empty():
		return
	var url := "%s/api/voice/deafen" % _base_url()
	var body := JSON.stringify({"token": token, "deafened": not _deafened})
	var headers := PackedStringArray(["Content-Type: application/json"])
	_deafen_request.request(url, headers, HTTPClient.METHOD_POST, body)


func _load_participants() -> void:
	var region := _region_id()
	if region.is_empty():
		return
	var url := "%s/api/voice/participants?regionId=%s" % [_base_url(), region]
	_participants_request.request(url, [], HTTPClient.METHOD_GET)


# ── HTTP Callbacks ───────────────────────────────────────────────────────────

func _on_join_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Failed to join voice"
		return
	_connected = true
	_muted = false
	_deafened = false
	_status_label.text = "Connected to voice channel"
	_update_ui_state()
	_load_participants()


func _on_leave_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Failed to leave voice"
		return
	_connected = false
	_muted = false
	_deafened = false
	_participants.clear()
	_speaking_ids.clear()
	_status_label.text = "Disconnected"
	_update_ui_state()
	_render_participants()


func _on_mute_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Mute toggle failed"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json != null:
		_muted = json.get("muted", not _muted)
	else:
		_muted = not _muted
	_status_label.text = "Muted" if _muted else "Unmuted"
	_update_ui_state()


func _on_deafen_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Deafen toggle failed"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json != null:
		_deafened = json.get("deafened", not _deafened)
	else:
		_deafened = not _deafened
	_status_label.text = "Deafened" if _deafened else "Undeafened"
	_update_ui_state()


func _on_participants_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_participants = json.get("participants", [])
	_render_participants()


# ── Participant List Rendering ───────────────────────────────────────────────

func _render_participants() -> void:
	for child in _participants_list.get_children():
		child.queue_free()
	_participant_rows.clear()

	if _participants.is_empty():
		var empty := Label.new()
		empty.text = "No participants" if _connected else "Join voice to see participants"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_participants_list.add_child(empty)
		return

	for participant in _participants:
		var row := _create_participant_row(participant)
		_participants_list.add_child(row)


func _create_participant_row(participant: Dictionary) -> Control:
	var account_id: String = participant.get("accountId", "")
	var display_name: String = participant.get("displayName", "Unknown")
	var is_muted: bool = participant.get("muted", false)
	var is_speaking: bool = _speaking_ids.get(account_id, false)

	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 36)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_style := StyleBoxFlat.new()
	if is_speaking:
		row_style.bg_color = Color(0.1, 0.22, 0.1)
		row_style.border_color = Color(0.3, 0.8, 0.3, 0.5)
		row_style.border_width_left = 3
	else:
		row_style.bg_color = Color(0.12, 0.12, 0.15)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row_style.content_margin_left = 10
	row_style.content_margin_right = 10
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	# Speaking indicator (green dot when speaking)
	var speaking_indicator := ColorRect.new()
	speaking_indicator.custom_minimum_size = Vector2(10, 10)
	if is_speaking:
		speaking_indicator.color = Color(0.2, 0.9, 0.2)
	else:
		speaking_indicator.color = Color(0.3, 0.3, 0.3)
	hbox.add_child(speaking_indicator)

	# Mic icon
	var mic_icon := Label.new()
	if is_muted:
		mic_icon.text = "[X]"
		mic_icon.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	else:
		mic_icon.text = "[M]"
		mic_icon.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	mic_icon.add_theme_font_size_override("font_size", 14)
	hbox.add_child(mic_icon)

	# Display name
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	# Distance indicator (placeholder)
	var distance_label := Label.new()
	distance_label.text = "nearby"
	distance_label.add_theme_font_size_override("font_size", 11)
	distance_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hbox.add_child(distance_label)

	# Store row references for live updates
	_participant_rows[account_id] = {
		"row": row_panel,
		"name_label": name_label,
		"mic_icon": mic_icon,
		"speaking_indicator": speaking_indicator,
		"row_style": row_style,
	}

	return row_panel


# ── WS Event Handlers ───────────────────────────────────────────────────────

func on_participant_joined(message: Dictionary) -> void:
	## Handle voice:participant_joined WS event.
	var account_id: String = message.get("accountId", "")
	var display_name: String = message.get("displayName", "Unknown")

	# Add to participants list if not already present
	var found := false
	for p in _participants:
		if p.get("accountId", "") == account_id:
			found = true
			break
	if not found:
		_participants.append({
			"accountId": account_id,
			"displayName": display_name,
			"muted": false,
		})

	if visible:
		_render_participants()


func on_participant_left(message: Dictionary) -> void:
	## Handle voice:participant_left WS event.
	var account_id: String = message.get("accountId", "")

	_participants = _participants.filter(func(p): return p.get("accountId", "") != account_id)
	_speaking_ids.erase(account_id)
	_participant_rows.erase(account_id)

	if visible:
		_render_participants()


func on_speaking_changed(message: Dictionary) -> void:
	## Handle voice:speaking_changed WS event. Updates speaking indicator.
	var account_id: String = message.get("accountId", "")
	var is_speaking: bool = message.get("speaking", false)

	_speaking_ids[account_id] = is_speaking

	# Live-update the speaking indicator without full re-render
	if _participant_rows.has(account_id):
		var row_data: Dictionary = _participant_rows[account_id]
		var indicator: ColorRect = row_data.get("speaking_indicator")
		var style: StyleBoxFlat = row_data.get("row_style")

		if indicator and is_instance_valid(indicator):
			if is_speaking:
				indicator.color = Color(0.2, 0.9, 0.2)
			else:
				indicator.color = Color(0.3, 0.3, 0.3)

		if style:
			if is_speaking:
				style.bg_color = Color(0.1, 0.22, 0.1)
				style.border_color = Color(0.3, 0.8, 0.3, 0.5)
				style.border_width_left = 3
			else:
				style.bg_color = Color(0.12, 0.12, 0.15)
				style.border_color = Color(0, 0, 0, 0)
				style.border_width_left = 0
