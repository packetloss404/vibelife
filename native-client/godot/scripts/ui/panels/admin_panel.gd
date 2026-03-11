class_name AdminPanel
extends Control

## Admin panel — player bans, parcel management, object deletion, audit logs.
## Visible only to accounts with admin role.

var main = null

# Sub-tab controls
var sub_tab_bar: HBoxContainer
var sub_content: Control
var active_sub_tab: String = ""
var sub_tabs: Dictionary = {}

# Player ban tab
var ban_name_input: LineEdit
var ban_reason_input: LineEdit
var ban_duration_input: LineEdit
var ban_button: Button
var unban_button: Button
var ban_status_label: Label
var ban_check_button: Button

# Parcel tab
var parcel_id_input: LineEdit
var parcel_owner_input: LineEdit
var assign_parcel_button: Button
var release_parcel_button: Button
var parcel_status_label: Label

# Object tab
var object_id_input: LineEdit
var object_delete_reason_input: LineEdit
var delete_object_button: Button
var object_status_label: Label

# Audit log tab
var audit_log_list: RichTextLabel
var audit_filter_input: LineEdit
var audit_page: int = 0
var audit_prev_button: Button
var audit_next_button: Button
var audit_page_label: Label
var audit_data: Array = []


func init(main_node) -> void:
	main = main_node
	name = "AdminPanel"
	_build_ui()


func _get_base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _get_token() -> String:
	return main.session.get("token", "")


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 4)
	add_child(root_vbox)

	var header := Label.new()
	header.text = "Admin Panel"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	root_vbox.add_child(header)

	sub_tab_bar = HBoxContainer.new()
	sub_tab_bar.add_theme_constant_override("separation", 2)
	root_vbox.add_child(sub_tab_bar)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	sub_content = Control.new()
	sub_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(sub_content)

	_build_ban_tab()
	_build_parcel_tab()
	_build_object_tab()
	_build_audit_tab()


func _register_sub_tab(tab_name: String, control: Control) -> void:
	var btn := Button.new()
	btn.text = tab_name
	btn.toggle_mode = true
	btn.custom_minimum_size.x = 50
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): _switch_sub_tab(tab_name))
	sub_tab_bar.add_child(btn)

	control.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	control.visible = false
	sub_content.add_child(control)

	sub_tabs[tab_name] = {"button": btn, "content": control}

	if sub_tabs.size() == 1:
		_switch_sub_tab(tab_name)


func _switch_sub_tab(tab_name: String) -> void:
	if not sub_tabs.has(tab_name):
		return
	if active_sub_tab == tab_name:
		return
	if not active_sub_tab.is_empty() and sub_tabs.has(active_sub_tab):
		sub_tabs[active_sub_tab].content.visible = false
		sub_tabs[active_sub_tab].button.button_pressed = false
	active_sub_tab = tab_name
	sub_tabs[active_sub_tab].content.visible = true
	sub_tabs[active_sub_tab].button.button_pressed = true


# ── Player Ban Tab ─────────────────────────────────────────────────────────

func _build_ban_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Player Management"
	panel.add_child(title)

	var name_label := Label.new()
	name_label.text = "Player Name:"
	panel.add_child(name_label)

	ban_name_input = LineEdit.new()
	ban_name_input.placeholder_text = "Enter player display name..."
	panel.add_child(ban_name_input)

	var reason_label := Label.new()
	reason_label.text = "Reason:"
	panel.add_child(reason_label)

	ban_reason_input = LineEdit.new()
	ban_reason_input.placeholder_text = "Ban reason..."
	panel.add_child(ban_reason_input)

	var duration_label := Label.new()
	duration_label.text = "Duration (hours, 0 = permanent):"
	panel.add_child(duration_label)

	ban_duration_input = LineEdit.new()
	ban_duration_input.placeholder_text = "24"
	ban_duration_input.text = "24"
	panel.add_child(ban_duration_input)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	panel.add_child(btn_row)

	ban_button = Button.new()
	ban_button.text = "Ban Player"
	ban_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	ban_button.pressed.connect(_on_ban_player)
	btn_row.add_child(ban_button)

	unban_button = Button.new()
	unban_button.text = "Unban Player"
	unban_button.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	unban_button.pressed.connect(_on_unban_player)
	btn_row.add_child(unban_button)

	ban_check_button = Button.new()
	ban_check_button.text = "Check Ban Status"
	ban_check_button.pressed.connect(_on_check_ban_status)
	btn_row.add_child(ban_check_button)

	ban_status_label = Label.new()
	ban_status_label.text = ""
	ban_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	ban_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(ban_status_label)

	_register_sub_tab("Bans", panel)


func _on_ban_player() -> void:
	var token := _get_token()
	if token.is_empty():
		ban_status_label.text = "Not logged in."
		return
	var player_name := ban_name_input.text.strip_edges()
	if player_name.is_empty():
		ban_status_label.text = "Player name required."
		return
	var reason := ban_reason_input.text.strip_edges()
	var duration_hours := int(ban_duration_input.text.strip_edges()) if not ban_duration_input.text.strip_edges().is_empty() else 24

	var url := "%s/api/admin/ban" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"displayName": player_name,
		"reason": reason,
		"durationHours": duration_hours
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray):
		var payload = JSON.parse_string(response_body.get_string_from_utf8())
		if response_code == 200:
			ban_status_label.text = "Player '%s' banned for %d hours." % [player_name, duration_hours]
		else:
			ban_status_label.text = "Ban failed: %s" % str(payload)
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	ban_status_label.text = "Banning..."


func _on_unban_player() -> void:
	var token := _get_token()
	if token.is_empty():
		ban_status_label.text = "Not logged in."
		return
	var player_name := ban_name_input.text.strip_edges()
	if player_name.is_empty():
		ban_status_label.text = "Player name required."
		return
	var url := "%s/api/admin/ban" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"displayName": player_name
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray):
		var payload = JSON.parse_string(response_body.get_string_from_utf8())
		if response_code == 200:
			ban_status_label.text = "Player '%s' unbanned." % player_name
		else:
			ban_status_label.text = "Unban failed: %s" % str(payload)
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_DELETE, body)
	ban_status_label.text = "Unbanning..."


func _on_check_ban_status() -> void:
	var token := _get_token()
	if token.is_empty():
		ban_status_label.text = "Not logged in."
		return
	var url := "%s/api/avatar/ban/status?token=%s" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload:
				var banned: bool = payload.get("banned", false)
				if banned:
					ban_status_label.text = "BANNED until %s. Reason: %s" % [
						str(payload.get("expiresAt", "permanent")),
						str(payload.get("reason", "none"))
					]
				else:
					ban_status_label.text = "Not currently banned."
		http.queue_free()
	)
	http.request(url)


# ── Parcel Management Tab ─────────────────────────────────────────────────

func _build_parcel_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Parcel Management"
	panel.add_child(title)

	var parcel_label := Label.new()
	parcel_label.text = "Parcel ID:"
	panel.add_child(parcel_label)

	parcel_id_input = LineEdit.new()
	parcel_id_input.placeholder_text = "Enter parcel ID..."
	panel.add_child(parcel_id_input)

	var owner_label := Label.new()
	owner_label.text = "Assign to Account Name:"
	panel.add_child(owner_label)

	parcel_owner_input = LineEdit.new()
	parcel_owner_input.placeholder_text = "Account display name..."
	panel.add_child(parcel_owner_input)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	panel.add_child(btn_row)

	assign_parcel_button = Button.new()
	assign_parcel_button.text = "Assign Owner"
	assign_parcel_button.pressed.connect(_on_assign_parcel)
	btn_row.add_child(assign_parcel_button)

	release_parcel_button = Button.new()
	release_parcel_button.text = "Force Release"
	release_parcel_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	release_parcel_button.pressed.connect(_on_release_parcel)
	btn_row.add_child(release_parcel_button)

	parcel_status_label = Label.new()
	parcel_status_label.text = ""
	parcel_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	panel.add_child(parcel_status_label)

	_register_sub_tab("Parcels", panel)


func _on_assign_parcel() -> void:
	var token := _get_token()
	if token.is_empty():
		parcel_status_label.text = "Not logged in."
		return
	var parcel_id := parcel_id_input.text.strip_edges()
	var owner_name := parcel_owner_input.text.strip_edges()
	if parcel_id.is_empty() or owner_name.is_empty():
		parcel_status_label.text = "Parcel ID and owner name required."
		return
	var url := "%s/api/admin/parcels/assign" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"parcelId": parcel_id,
		"ownerDisplayName": owner_name
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray):
		if response_code == 200:
			parcel_status_label.text = "Parcel '%s' assigned to '%s'." % [parcel_id, owner_name]
		else:
			var payload = JSON.parse_string(response_body.get_string_from_utf8())
			parcel_status_label.text = "Assign failed: %s" % str(payload)
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_release_parcel() -> void:
	var token := _get_token()
	if token.is_empty():
		parcel_status_label.text = "Not logged in."
		return
	var parcel_id := parcel_id_input.text.strip_edges()
	if parcel_id.is_empty():
		parcel_status_label.text = "Parcel ID required."
		return
	var url := "%s/api/admin/parcels/assign" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"parcelId": parcel_id,
		"ownerDisplayName": "",
		"release": true
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray):
		if response_code == 200:
			parcel_status_label.text = "Parcel '%s' released." % parcel_id
		else:
			var payload = JSON.parse_string(response_body.get_string_from_utf8())
			parcel_status_label.text = "Release failed: %s" % str(payload)
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


# ── Object Management Tab ─────────────────────────────────────────────────

func _build_object_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Object Management"
	panel.add_child(title)

	var id_label := Label.new()
	id_label.text = "Object ID:"
	panel.add_child(id_label)

	object_id_input = LineEdit.new()
	object_id_input.placeholder_text = "Enter object ID..."
	panel.add_child(object_id_input)

	var reason_label := Label.new()
	reason_label.text = "Deletion Reason:"
	panel.add_child(reason_label)

	object_delete_reason_input = LineEdit.new()
	object_delete_reason_input.placeholder_text = "Reason for deletion..."
	panel.add_child(object_delete_reason_input)

	delete_object_button = Button.new()
	delete_object_button.text = "Delete Object"
	delete_object_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	delete_object_button.pressed.connect(_on_delete_object)
	panel.add_child(delete_object_button)

	object_status_label = Label.new()
	object_status_label.text = ""
	object_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	panel.add_child(object_status_label)

	_register_sub_tab("Objects", panel)


func _on_delete_object() -> void:
	var token := _get_token()
	if token.is_empty():
		object_status_label.text = "Not logged in."
		return
	var obj_id := object_id_input.text.strip_edges()
	if obj_id.is_empty():
		object_status_label.text = "Object ID required."
		return
	var reason := object_delete_reason_input.text.strip_edges()
	var url := "%s/api/admin/objects/delete" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"objectId": obj_id,
		"reason": reason
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray):
		if response_code == 200:
			object_status_label.text = "Object '%s' deleted." % obj_id
			object_id_input.clear()
			object_delete_reason_input.clear()
		else:
			var payload = JSON.parse_string(response_body.get_string_from_utf8())
			object_status_label.text = "Delete failed: %s" % str(payload)
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


# ── Audit Log Tab ──────────────────────────────────────────────────────────

func _build_audit_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Audit Log"
	panel.add_child(title)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 4)
	panel.add_child(filter_row)

	audit_filter_input = LineEdit.new()
	audit_filter_input.placeholder_text = "Filter by action or account..."
	audit_filter_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(audit_filter_input)

	var refresh_btn := Button.new()
	refresh_btn.text = "Search"
	refresh_btn.pressed.connect(func(): audit_page = 0; load_audit_logs())
	filter_row.add_child(refresh_btn)

	audit_log_list = RichTextLabel.new()
	audit_log_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	audit_log_list.custom_minimum_size.y = 140
	audit_log_list.bbcode_enabled = true
	audit_log_list.scroll_following = true
	panel.add_child(audit_log_list)

	var page_row := HBoxContainer.new()
	page_row.add_theme_constant_override("separation", 8)
	panel.add_child(page_row)

	audit_prev_button = Button.new()
	audit_prev_button.text = "< Prev"
	audit_prev_button.pressed.connect(func():
		if audit_page > 0:
			audit_page -= 1
			load_audit_logs()
	)
	page_row.add_child(audit_prev_button)

	audit_page_label = Label.new()
	audit_page_label.text = "Page 1"
	page_row.add_child(audit_page_label)

	audit_next_button = Button.new()
	audit_next_button.text = "Next >"
	audit_next_button.pressed.connect(func():
		audit_page += 1
		load_audit_logs()
	)
	page_row.add_child(audit_next_button)

	_register_sub_tab("Audit Log", panel)


func load_audit_logs() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var filter := audit_filter_input.text.strip_edges()
	var limit := 50
	var offset := audit_page * limit
	var url := "%s/api/admin/audit-logs?token=%s&limit=%d&offset=%d" % [_get_base_url(), token, limit, offset]
	if not filter.is_empty():
		url += "&filter=%s" % filter.uri_encode()

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("logs"):
				audit_data = payload.logs
				_render_audit_logs()
		http.queue_free()
	)
	http.request(url)
	audit_page_label.text = "Page %d" % (audit_page + 1)


func _render_audit_logs() -> void:
	audit_log_list.clear()
	if audit_data.is_empty():
		audit_log_list.append_text("[color=gray]No audit log entries found.[/color]\n")
		return
	for entry in audit_data:
		var timestamp: String = str(entry.get("timestamp", ""))
		var actor: String = str(entry.get("actor", ""))
		var action: String = str(entry.get("action", ""))
		var target: String = str(entry.get("target", ""))
		var details: String = str(entry.get("details", ""))

		# Format with colors for readability
		audit_log_list.append_text("[color=gray]%s[/color] " % timestamp)
		audit_log_list.append_text("[color=cyan]%s[/color] " % actor)
		audit_log_list.append_text("[color=yellow]%s[/color] " % action)
		if not target.is_empty():
			audit_log_list.append_text("-> [color=white]%s[/color] " % target)
		if not details.is_empty():
			audit_log_list.append_text("[color=gray](%s)[/color]" % details)
		audit_log_list.append_text("\n")
