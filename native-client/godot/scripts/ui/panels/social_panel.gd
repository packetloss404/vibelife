class_name SocialPanel extends Control

var main = null

# Sub-tab buttons
var tab_friends: Button
var tab_requests: Button
var tab_blocked: Button
var tab_messages: Button

# Content containers (one per sub-tab)
var friends_container: VBoxContainer
var requests_container: VBoxContainer
var blocked_container: VBoxContainer
var messages_container: VBoxContainer

# Presence status
var status_dropdown: OptionButton
var custom_status_input: LineEdit

# Add friend popup
var add_friend_popup: PanelContainer
var add_friend_input: LineEdit

# Message compose
var message_recipient_input: LineEdit
var message_body_input: TextEdit
var message_send_button: Button

# Scroll containers
var friends_scroll: ScrollContainer
var requests_scroll: ScrollContainer
var blocked_scroll: ScrollContainer
var messages_scroll: ScrollContainer

# Data
var friends_list: Array = []
var friend_requests: Array = []
var blocked_list: Array = []
var offline_messages: Array = []
var unread_count: int = 0
var active_tab: String = "friends"

# Refresh timer
var refresh_timer: Timer


func init(main_node) -> void:
	main = main_node
	name = "SocialPanel"
	visible = false
	_build_ui()
	# Start a refresh timer to poll friends/presence
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 15.0
	refresh_timer.timeout.connect(_refresh_data)
	add_child(refresh_timer)


func _build_ui() -> void:
	# Root panel fills parent
	set_anchors_preset(PRESET_FULL_RECT)

	var panel_bg := PanelContainer.new()
	panel_bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(panel_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel_bg.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root_vbox)

	# ── Header: title + presence status ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "Social"
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var status_label := Label.new()
	status_label.text = "Status:"
	header.add_child(status_label)

	status_dropdown = OptionButton.new()
	status_dropdown.add_item("Online")
	status_dropdown.add_item("Busy")
	status_dropdown.add_item("Away")
	status_dropdown.add_item("Invisible")
	status_dropdown.item_selected.connect(_on_status_changed)
	header.add_child(status_dropdown)

	custom_status_input = LineEdit.new()
	custom_status_input.placeholder_text = "Custom status..."
	custom_status_input.custom_minimum_size = Vector2(140, 0)
	custom_status_input.text_submitted.connect(func(_t: String): _on_status_changed(status_dropdown.selected))
	header.add_child(custom_status_input)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	# ── Sub-tab bar ──
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	root_vbox.add_child(tab_bar)

	tab_friends = Button.new()
	tab_friends.text = "Friends"
	tab_friends.pressed.connect(func(): _switch_tab("friends"))
	tab_bar.add_child(tab_friends)

	tab_requests = Button.new()
	tab_requests.text = "Requests"
	tab_requests.pressed.connect(func(): _switch_tab("requests"))
	tab_bar.add_child(tab_requests)

	tab_blocked = Button.new()
	tab_blocked.text = "Blocked"
	tab_blocked.pressed.connect(func(): _switch_tab("blocked"))
	tab_bar.add_child(tab_blocked)

	tab_messages = Button.new()
	tab_messages.text = "Messages"
	tab_messages.pressed.connect(func(): _switch_tab("messages"))
	tab_bar.add_child(tab_messages)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# ── Friends tab content ──
	friends_scroll = ScrollContainer.new()
	friends_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	friends_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(friends_scroll)

	var friends_vbox_wrapper := VBoxContainer.new()
	friends_vbox_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends_scroll.add_child(friends_vbox_wrapper)

	friends_container = VBoxContainer.new()
	friends_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends_container.add_theme_constant_override("separation", 4)
	friends_vbox_wrapper.add_child(friends_container)

	var add_friend_row := HBoxContainer.new()
	add_friend_row.add_theme_constant_override("separation", 6)
	friends_vbox_wrapper.add_child(add_friend_row)

	var add_friend_btn := Button.new()
	add_friend_btn.text = "Add Friend"
	add_friend_btn.pressed.connect(_show_add_friend_popup)
	add_friend_row.add_child(add_friend_btn)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_data)
	add_friend_row.add_child(refresh_btn)

	# ── Add friend popup (hidden by default) ──
	add_friend_popup = PanelContainer.new()
	add_friend_popup.visible = false
	friends_vbox_wrapper.add_child(add_friend_popup)

	var popup_margin := MarginContainer.new()
	popup_margin.add_theme_constant_override("margin_left", 8)
	popup_margin.add_theme_constant_override("margin_right", 8)
	popup_margin.add_theme_constant_override("margin_top", 8)
	popup_margin.add_theme_constant_override("margin_bottom", 8)
	add_friend_popup.add_child(popup_margin)

	var popup_vbox := VBoxContainer.new()
	popup_margin.add_child(popup_vbox)

	var popup_label := Label.new()
	popup_label.text = "Enter account ID:"
	popup_vbox.add_child(popup_label)

	add_friend_input = LineEdit.new()
	add_friend_input.placeholder_text = "Account ID"
	add_friend_input.text_submitted.connect(func(_t: String): _send_friend_request())
	popup_vbox.add_child(add_friend_input)

	var popup_btns := HBoxContainer.new()
	popup_btns.add_theme_constant_override("separation", 6)
	popup_vbox.add_child(popup_btns)

	var send_req_btn := Button.new()
	send_req_btn.text = "Send Request"
	send_req_btn.pressed.connect(_send_friend_request)
	popup_btns.add_child(send_req_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): add_friend_popup.visible = false)
	popup_btns.add_child(cancel_btn)

	# ── Requests tab content ──
	requests_scroll = ScrollContainer.new()
	requests_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	requests_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requests_scroll.visible = false
	root_vbox.add_child(requests_scroll)

	requests_container = VBoxContainer.new()
	requests_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requests_container.add_theme_constant_override("separation", 4)
	requests_scroll.add_child(requests_container)

	# ── Blocked tab content ──
	blocked_scroll = ScrollContainer.new()
	blocked_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blocked_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blocked_scroll.visible = false
	root_vbox.add_child(blocked_scroll)

	blocked_container = VBoxContainer.new()
	blocked_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blocked_container.add_theme_constant_override("separation", 4)
	blocked_scroll.add_child(blocked_container)

	# ── Messages tab content ──
	messages_scroll = ScrollContainer.new()
	messages_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages_scroll.visible = false
	root_vbox.add_child(messages_scroll)

	var messages_vbox_wrapper := VBoxContainer.new()
	messages_vbox_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages_scroll.add_child(messages_vbox_wrapper)

	messages_container = VBoxContainer.new()
	messages_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages_container.add_theme_constant_override("separation", 4)
	messages_vbox_wrapper.add_child(messages_container)

	# Compose message section
	var compose_sep := HSeparator.new()
	messages_vbox_wrapper.add_child(compose_sep)

	var compose_label := Label.new()
	compose_label.text = "Send Offline Message"
	messages_vbox_wrapper.add_child(compose_label)

	message_recipient_input = LineEdit.new()
	message_recipient_input.placeholder_text = "Recipient account ID"
	messages_vbox_wrapper.add_child(message_recipient_input)

	message_body_input = TextEdit.new()
	message_body_input.placeholder_text = "Type your message..."
	message_body_input.custom_minimum_size = Vector2(0, 60)
	messages_vbox_wrapper.add_child(message_body_input)

	message_send_button = Button.new()
	message_send_button.text = "Send Message"
	message_send_button.pressed.connect(_send_offline_message)
	messages_vbox_wrapper.add_child(message_send_button)


func show_panel() -> void:
	visible = true
	_refresh_data()
	refresh_timer.start()


func hide_panel() -> void:
	visible = false
	refresh_timer.stop()


func _switch_tab(tab_name: String) -> void:
	active_tab = tab_name
	friends_scroll.visible = tab_name == "friends"
	requests_scroll.visible = tab_name == "requests"
	blocked_scroll.visible = tab_name == "blocked"
	messages_scroll.visible = tab_name == "messages"

	# Bold the active tab
	tab_friends.text = "[Friends]" if tab_name == "friends" else "Friends"
	tab_requests.text = "[Requests]" if tab_name == "requests" else "Requests"
	tab_blocked.text = "[Blocked]" if tab_name == "blocked" else "Blocked"
	tab_messages.text = "[Messages]" if tab_name == "messages" else "Messages"

	if tab_name == "messages":
		_fetch_offline_messages()


func _get_base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _get_token() -> String:
	return main.session.get("token", "")


# ── Data fetching ──────────────────────────────────────────────────────────

func _refresh_data() -> void:
	_fetch_friends()
	_fetch_friends_presence()
	if active_tab == "messages":
		_fetch_offline_messages()


func _fetch_friends() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/friends?token=%s" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("friends"):
				friends_list.clear()
				friend_requests.clear()
				blocked_list.clear()
				for f in payload.friends:
					var status_str: String = f.get("status", "accepted")
					if status_str == "accepted":
						friends_list.append(f)
					elif status_str == "pending":
						friend_requests.append(f)
					elif status_str == "blocked":
						blocked_list.append(f)
				_render_friends()
				_render_requests()
				_render_blocked()
		http.queue_free()
	)
	http.request(url)


func _fetch_friends_presence() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/presence/friends?token=%s" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("presences"):
				main.social_mgr.friends_presence = payload.presences
				_render_friends()
		http.queue_free()
	)
	http.request(url)


func _fetch_offline_messages() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/messages/offline?token=%s" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("messages"):
				offline_messages = payload.messages
				unread_count = 0
				for msg in offline_messages:
					if not msg.get("read", false):
						unread_count += 1
				_render_messages()
				_update_messages_badge()
		http.queue_free()
	)
	http.request(url)


# ── Rendering ──────────────────────────────────────────────────────────────

func _render_friends() -> void:
	# Clear existing entries
	for child in friends_container.get_children():
		child.queue_free()

	if friends_list.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No friends yet. Add someone!"
		friends_container.add_child(empty_label)
		return

	var presences: Array = main.social_mgr.friends_presence
	for friend_data in friends_list:
		var row := _create_friend_row(friend_data, presences)
		friends_container.add_child(row)


func _create_friend_row(friend_data: Dictionary, presences: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 32)

	# Status indicator dot
	var status_dot := ColorRect.new()
	status_dot.custom_minimum_size = Vector2(12, 12)
	status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Determine presence color
	var presence_status := "offline"
	var friend_id: String = friend_data.get("friendAccountId", friend_data.get("accountId", ""))
	for p in presences:
		if p.get("accountId", "") == friend_id:
			presence_status = p.get("status", "offline")
			break

	match presence_status:
		"online":
			status_dot.color = Color(0.2, 0.85, 0.2)  # green
		"busy":
			status_dot.color = Color(0.9, 0.2, 0.2)  # red
		"away":
			status_dot.color = Color(0.95, 0.75, 0.1)  # yellow
		_:
			status_dot.color = Color(0.5, 0.5, 0.5)  # gray (offline/invisible)

	row.add_child(status_dot)

	# Name label
	var name_label := Label.new()
	name_label.text = friend_data.get("displayName", friend_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Region label
	var region_label := Label.new()
	for p in presences:
		if p.get("accountId", "") == friend_id:
			region_label.text = p.get("region", "")
			break
	region_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	row.add_child(region_label)

	# Unfriend button
	var unfriend_btn := Button.new()
	unfriend_btn.text = "Unfriend"
	unfriend_btn.pressed.connect(func(): _remove_friend(friend_id))
	row.add_child(unfriend_btn)

	# Block button
	var block_btn := Button.new()
	block_btn.text = "Block"
	block_btn.pressed.connect(func(): _block_account(friend_id))
	row.add_child(block_btn)

	return row


func _render_requests() -> void:
	for child in requests_container.get_children():
		child.queue_free()

	if friend_requests.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No pending friend requests."
		requests_container.add_child(empty_label)
		return

	for req in friend_requests:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 32)

		var name_label := Label.new()
		var req_id: String = req.get("friendAccountId", req.get("accountId", ""))
		name_label.text = req.get("displayName", req_id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var accept_btn := Button.new()
		accept_btn.text = "Accept"
		accept_btn.pressed.connect(func(): _accept_friend_request(req_id))
		row.add_child(accept_btn)

		var decline_btn := Button.new()
		decline_btn.text = "Decline"
		decline_btn.pressed.connect(func(): _remove_friend(req_id))
		row.add_child(decline_btn)

		requests_container.add_child(row)


func _render_blocked() -> void:
	for child in blocked_container.get_children():
		child.queue_free()

	if blocked_list.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No blocked accounts."
		blocked_container.add_child(empty_label)
		return

	for blocked in blocked_list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 32)

		var name_label := Label.new()
		var blocked_id: String = blocked.get("blockedAccountId", blocked.get("accountId", ""))
		name_label.text = blocked.get("displayName", blocked_id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var unblock_btn := Button.new()
		unblock_btn.text = "Unblock"
		unblock_btn.pressed.connect(func(): _unblock_account(blocked_id))
		row.add_child(unblock_btn)

		blocked_container.add_child(row)


func _render_messages() -> void:
	for child in messages_container.get_children():
		child.queue_free()

	if offline_messages.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No offline messages."
		messages_container.add_child(empty_label)
		return

	for msg in offline_messages:
		var msg_panel := PanelContainer.new()
		msg_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		messages_container.add_child(msg_panel)

		var msg_margin := MarginContainer.new()
		msg_margin.add_theme_constant_override("margin_left", 6)
		msg_margin.add_theme_constant_override("margin_right", 6)
		msg_margin.add_theme_constant_override("margin_top", 4)
		msg_margin.add_theme_constant_override("margin_bottom", 4)
		msg_panel.add_child(msg_margin)

		var msg_vbox := VBoxContainer.new()
		msg_margin.add_child(msg_vbox)

		# Header: sender + timestamp + read status
		var msg_header := HBoxContainer.new()
		msg_header.add_theme_constant_override("separation", 8)
		msg_vbox.add_child(msg_header)

		var sender_label := Label.new()
		sender_label.text = "From: %s" % msg.get("fromDisplayName", msg.get("fromAccountId", "Unknown"))
		sender_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		msg_header.add_child(sender_label)

		var read_indicator := Label.new()
		if msg.get("read", false):
			read_indicator.text = "(read)"
			read_indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			read_indicator.text = "(NEW)"
			read_indicator.add_theme_color_override("font_color", Color(0.2, 0.85, 0.2))
		msg_header.add_child(read_indicator)

		var time_label := Label.new()
		time_label.text = _format_timestamp(msg.get("createdAt", ""))
		time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		msg_header.add_child(time_label)

		# Body
		var body_label := Label.new()
		body_label.text = msg.get("message", "")
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		msg_vbox.add_child(body_label)

		# Action buttons
		var msg_actions := HBoxContainer.new()
		msg_actions.add_theme_constant_override("separation", 6)
		msg_vbox.add_child(msg_actions)

		if not msg.get("read", false):
			var mark_read_btn := Button.new()
			mark_read_btn.text = "Mark Read"
			var msg_id: String = msg.get("id", msg.get("messageId", ""))
			mark_read_btn.pressed.connect(func(): _mark_message_read(msg_id))
			msg_actions.add_child(mark_read_btn)

		var reply_btn := Button.new()
		reply_btn.text = "Reply"
		var from_id: String = msg.get("fromAccountId", "")
		reply_btn.pressed.connect(func(): _prepare_reply(from_id))
		msg_actions.add_child(reply_btn)


func _update_messages_badge() -> void:
	if unread_count > 0:
		tab_messages.text = "Messages (%d)" % unread_count
	else:
		tab_messages.text = "Messages"


# ── Actions ────────────────────────────────────────────────────────────────

func _show_add_friend_popup() -> void:
	add_friend_popup.visible = true
	add_friend_input.text = ""
	add_friend_input.grab_focus()


func _send_friend_request() -> void:
	var friend_id := add_friend_input.text.strip_edges()
	if friend_id.is_empty():
		return
	var token := _get_token()
	if token.is_empty():
		return
	add_friend_popup.visible = false

	var url := "%s/api/friends" % _get_base_url()
	var body := JSON.stringify({"token": token, "friendAccountId": friend_id})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			main._append_chat("System: Friend request sent to %s" % friend_id)
		else:
			main._append_chat("System: Failed to send friend request")
		_fetch_friends()
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _accept_friend_request(friend_id: String) -> void:
	# Accepting is the same as adding (backend handles mutual accept)
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/friends" % _get_base_url()
	var body := JSON.stringify({"token": token, "friendAccountId": friend_id})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			main._append_chat("System: Friend request accepted")
		_fetch_friends()
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _remove_friend(friend_id: String) -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/friends" % _get_base_url()
	var body := JSON.stringify({"token": token, "friendAccountId": friend_id})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			main._append_chat("System: Friend removed")
		_fetch_friends()
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_DELETE, body)


func _block_account(account_id: String) -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/friends/block" % _get_base_url()
	var body := JSON.stringify({"token": token, "blockedAccountId": account_id})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			main._append_chat("System: Account blocked")
		_fetch_friends()
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _unblock_account(account_id: String) -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/friends/block" % _get_base_url()
	var body := JSON.stringify({"token": token, "blockedAccountId": account_id})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			main._append_chat("System: Account unblocked")
		_fetch_friends()
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_DELETE, body)


func _on_status_changed(index: int) -> void:
	var statuses := ["online", "busy", "away", "invisible"]
	if index >= 0 and index < statuses.size():
		main.social_mgr.set_status(statuses[index], custom_status_input.text.strip_edges())


func _mark_message_read(message_id: String) -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/messages/offline/read" % _get_base_url()
	var body := JSON.stringify({"token": token, "messageId": message_id})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray):
		_fetch_offline_messages()
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, body)


func _send_offline_message() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var to_id := message_recipient_input.text.strip_edges()
	var msg_text := message_body_input.text.strip_edges()
	if to_id.is_empty() or msg_text.is_empty():
		return

	var url := "%s/api/messages/offline" % _get_base_url()
	var body := JSON.stringify({"token": token, "toAccountId": to_id, "message": msg_text})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			main._append_chat("System: Offline message sent")
			message_recipient_input.text = ""
			message_body_input.text = ""
			_fetch_offline_messages()
		else:
			main._append_chat("System: Failed to send offline message")
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _prepare_reply(from_account_id: String) -> void:
	message_recipient_input.text = from_account_id
	message_body_input.grab_focus()


func _format_timestamp(iso_string: String) -> String:
	if iso_string.is_empty():
		return ""
	var t_pos := iso_string.find("T")
	if t_pos < 0:
		return ""
	var time_part := iso_string.substr(t_pos + 1)
	if time_part.length() >= 5:
		return time_part.substr(0, 5)
	return time_part
