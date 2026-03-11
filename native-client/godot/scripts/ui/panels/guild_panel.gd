class_name GuildPanel extends Control

var main  # Reference to main node

# State
var current_guild: Dictionary = {}  # Empty = no guild
var current_guild_id := ""
var my_groups: Array = []
var guild_members: Array = []
var treasury_balance := 0
var treasury_history: Array = []
var alliances: Array = []
var my_role := "member"  # member, officer, owner

# Root containers
var no_guild_container: VBoxContainer
var in_guild_container: VBoxContainer
var guild_tab_bar: TabBar
var guild_tab_content: Control

# No-guild widgets
var create_name_input: LineEdit
var create_desc_input: LineEdit
var create_button: Button
var browse_guilds_scroll: ScrollContainer
var browse_guilds_vbox: VBoxContainer
var no_guild_status: Label

# Guild header widgets
var guild_name_label: Label
var guild_member_count_label: Label
var guild_desc_label: Label
var leave_button: Button

# Sub-tab containers
var members_container: VBoxContainer
var treasury_container: VBoxContainer
var settings_container: VBoxContainer
var alliances_container: VBoxContainer

# Members tab
var members_scroll: ScrollContainer
var members_vbox: VBoxContainer
var invite_input: LineEdit
var invite_button: Button

# Treasury tab
var treasury_balance_label: Label
var deposit_input: SpinBox
var deposit_button: Button
var withdraw_input: SpinBox
var withdraw_button: Button
var treasury_history_scroll: ScrollContainer
var treasury_history_vbox: VBoxContainer

# Settings tab
var settings_desc_input: TextEdit
var save_desc_button: Button
var emblem_color_picker: ColorPickerButton
var banner_color_picker: ColorPickerButton
var save_emblem_button: Button
var save_banner_button: Button
var settings_status: Label

# Alliances tab
var alliances_scroll: ScrollContainer
var alliances_vbox: VBoxContainer
var alliance_target_input: LineEdit
var alliance_send_button: Button

# Chat channel selector (injected into main chat area)
var chat_channel_select: OptionButton


func init(main_node) -> void:
	main = main_node
	name = "GuildPanel"
	visible = false
	_build_ui()
	_build_chat_channel_selector()


func _get_base_url() -> String:
	return main.backend_url_input.text.strip_edges().rstrip("/")


func _get_token() -> String:
	return main.session.get("token", "")


func _get_account_id() -> String:
	return main.session.get("accountId", "")


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(root_vbox)

	# Title
	var title := Label.new()
	title.text = "Guild"
	title.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(title)

	# No-guild state
	_build_no_guild_state(root_vbox)

	# In-guild state
	_build_in_guild_state(root_vbox)

	# Start with no-guild visible
	no_guild_container.visible = true
	in_guild_container.visible = false


# ── No Guild State ───────────────────────────────────────────────────────────

func _build_no_guild_state(parent: VBoxContainer) -> void:
	no_guild_container = VBoxContainer.new()
	no_guild_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(no_guild_container)

	# Create guild section
	var create_header := Label.new()
	create_header.text = "Create a Guild"
	create_header.add_theme_font_size_override("font_size", 16)
	no_guild_container.add_child(create_header)

	var name_row := HBoxContainer.new()
	no_guild_container.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_lbl.custom_minimum_size.x = 90
	name_row.add_child(name_lbl)
	create_name_input = LineEdit.new()
	create_name_input.placeholder_text = "Guild name..."
	create_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(create_name_input)

	var desc_row := HBoxContainer.new()
	no_guild_container.add_child(desc_row)
	var desc_lbl := Label.new()
	desc_lbl.text = "Description:"
	desc_lbl.custom_minimum_size.x = 90
	desc_row.add_child(desc_lbl)
	create_desc_input = LineEdit.new()
	create_desc_input.placeholder_text = "Guild description..."
	create_desc_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_row.add_child(create_desc_input)

	create_button = Button.new()
	create_button.text = "Create Guild"
	create_button.pressed.connect(_create_guild)
	no_guild_container.add_child(create_button)

	no_guild_status = Label.new()
	no_guild_status.text = ""
	no_guild_container.add_child(no_guild_status)

	# Separator
	var sep := HSeparator.new()
	no_guild_container.add_child(sep)

	# Browse guilds
	var browse_row := HBoxContainer.new()
	no_guild_container.add_child(browse_row)

	var browse_header := Label.new()
	browse_header.text = "Browse Guilds"
	browse_header.add_theme_font_size_override("font_size", 16)
	browse_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse_row.add_child(browse_header)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_my_groups)
	browse_row.add_child(refresh_btn)

	browse_guilds_scroll = ScrollContainer.new()
	browse_guilds_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browse_guilds_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_guild_container.add_child(browse_guilds_scroll)

	browse_guilds_vbox = VBoxContainer.new()
	browse_guilds_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse_guilds_scroll.add_child(browse_guilds_vbox)


func _create_guild() -> void:
	var guild_name := create_name_input.text.strip_edges()
	var guild_desc := create_desc_input.text.strip_edges()

	if guild_name.is_empty():
		no_guild_status.text = "Guild name is required."
		return

	var url := _get_base_url() + "/api/groups"
	var body := JSON.stringify({
		"token": _get_token(),
		"name": guild_name,
		"description": guild_desc
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("group"):
			current_guild = json["group"]
			current_guild_id = current_guild.get("id", "")
			my_role = "owner"
			main._append_chat("[Guild] Created guild: %s" % guild_name)
			_switch_to_guild_view()
		else:
			var err := json.get("error", "Failed to create guild") if json else "Failed to create guild"
			no_guild_status.text = err
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _refresh_my_groups() -> void:
	var url := _get_base_url() + "/api/groups?token=" + _get_token()

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("groups"):
			my_groups = json["groups"]
			if my_groups.size() > 0:
				# User is in a guild - switch to guild view with first group
				current_guild = my_groups[0]
				current_guild_id = current_guild.get("id", "")
				_load_guild_details()
				_switch_to_guild_view()
			else:
				_render_browse_guilds()
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _render_browse_guilds() -> void:
	for child in browse_guilds_vbox.get_children():
		child.queue_free()

	if my_groups.is_empty():
		var empty := Label.new()
		empty.text = "You are not in any guild. Create one above!"
		browse_guilds_vbox.add_child(empty)
		return

	for group in my_groups:
		var entry := PanelContainer.new()
		entry.custom_minimum_size = Vector2(0, 50)
		browse_guilds_vbox.add_child(entry)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		entry.add_child(hbox)

		var name_label := Label.new()
		name_label.text = group.get("name", "Unknown Guild")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)

		var join_btn := Button.new()
		join_btn.text = "View"
		var gid: String = group.get("id", "")
		join_btn.pressed.connect(func():
			current_guild = group
			current_guild_id = gid
			_load_guild_details()
			_switch_to_guild_view()
		)
		hbox.add_child(join_btn)


# ── In Guild State ───────────────────────────────────────────────────────────

func _build_in_guild_state(parent: VBoxContainer) -> void:
	in_guild_container = VBoxContainer.new()
	in_guild_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(in_guild_container)

	# Guild header
	var header_panel := PanelContainer.new()
	in_guild_container.add_child(header_panel)

	var header_vbox := VBoxContainer.new()
	header_panel.add_child(header_vbox)

	var header_row := HBoxContainer.new()
	header_vbox.add_child(header_row)

	guild_name_label = Label.new()
	guild_name_label.text = "Guild Name"
	guild_name_label.add_theme_font_size_override("font_size", 18)
	guild_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(guild_name_label)

	guild_member_count_label = Label.new()
	guild_member_count_label.text = "0 members"
	header_row.add_child(guild_member_count_label)

	leave_button = Button.new()
	leave_button.text = "Leave Guild"
	leave_button.pressed.connect(_leave_guild)
	header_row.add_child(leave_button)

	guild_desc_label = Label.new()
	guild_desc_label.text = ""
	guild_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	header_vbox.add_child(guild_desc_label)

	# Sub-tabs
	guild_tab_bar = TabBar.new()
	guild_tab_bar.add_tab("Members")
	guild_tab_bar.add_tab("Treasury")
	guild_tab_bar.add_tab("Settings")
	guild_tab_bar.add_tab("Alliances")
	guild_tab_bar.tab_changed.connect(_on_guild_tab_changed)
	in_guild_container.add_child(guild_tab_bar)

	guild_tab_content = Control.new()
	guild_tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guild_tab_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	in_guild_container.add_child(guild_tab_content)

	_build_members_tab()
	_build_treasury_tab()
	_build_settings_tab()
	_build_alliances_tab()


func _switch_to_guild_view() -> void:
	no_guild_container.visible = false
	in_guild_container.visible = true
	_update_guild_header()
	_on_guild_tab_changed(0)


func _switch_to_no_guild_view() -> void:
	current_guild = {}
	current_guild_id = ""
	my_role = "member"
	in_guild_container.visible = false
	no_guild_container.visible = true
	_refresh_my_groups()


func _update_guild_header() -> void:
	guild_name_label.text = current_guild.get("name", "Guild")
	guild_desc_label.text = current_guild.get("description", "")
	guild_member_count_label.text = "%d members" % guild_members.size()


func _load_guild_details() -> void:
	if current_guild_id.is_empty():
		return

	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/details"

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("details"):
			var details: Dictionary = json["details"]
			current_guild.merge(details, true)
			_update_guild_header()
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _leave_guild() -> void:
	if current_guild_id.is_empty():
		return

	var url := _get_base_url() + "/api/groups/members"
	var body := JSON.stringify({
		"token": _get_token(),
		"groupId": current_guild_id,
		"memberAccountId": _get_account_id()
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Guild] You left the guild.")
			_switch_to_no_guild_view()
		else:
			var err := json.get("error", "Failed to leave") if json else "Failed to leave"
			main._append_chat("[Guild] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_DELETE, body)


# ── Members Tab ──────────────────────────────────────────────────────────────

func _build_members_tab() -> void:
	members_container = VBoxContainer.new()
	members_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	members_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guild_tab_content.add_child(members_container)

	# Invite row
	var invite_row := HBoxContainer.new()
	members_container.add_child(invite_row)

	invite_input = LineEdit.new()
	invite_input.placeholder_text = "Player account ID to invite..."
	invite_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invite_row.add_child(invite_input)

	invite_button = Button.new()
	invite_button.text = "Invite"
	invite_button.pressed.connect(_invite_member)
	invite_row.add_child(invite_button)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_members)
	invite_row.add_child(refresh_btn)

	# Member list
	members_scroll = ScrollContainer.new()
	members_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	members_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	members_container.add_child(members_scroll)

	members_vbox = VBoxContainer.new()
	members_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	members_scroll.add_child(members_vbox)


func _refresh_members() -> void:
	if current_guild_id.is_empty():
		return

	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/members?token=" + _get_token()

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("members"):
			guild_members = json["members"]
			_determine_my_role()
			_render_members()
			_update_guild_header()
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _determine_my_role() -> void:
	var my_id := _get_account_id()
	my_role = "member"
	for member in guild_members:
		if member.get("accountId", "") == my_id:
			my_role = member.get("role", "member")
			break


func _render_members() -> void:
	for child in members_vbox.get_children():
		child.queue_free()

	if guild_members.is_empty():
		var empty := Label.new()
		empty.text = "No members loaded."
		members_vbox.add_child(empty)
		return

	var role_icons := {"owner": "[Crown]", "officer": "[Shield]", "member": "[User]"}
	var can_manage := (my_role == "owner" or my_role == "officer")

	for member in guild_members:
		var entry := PanelContainer.new()
		entry.custom_minimum_size = Vector2(0, 45)
		members_vbox.add_child(entry)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		entry.add_child(hbox)

		# Role badge
		var role_label := Label.new()
		var member_role: String = member.get("role", "member")
		role_label.text = role_icons.get(member_role, "[?]")
		hbox.add_child(role_label)

		# Name
		var name_label := Label.new()
		name_label.text = member.get("displayName", "Unknown")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)

		# Role text
		var role_text := Label.new()
		role_text.text = member_role.capitalize()
		hbox.add_child(role_text)

		var member_id: String = member.get("accountId", "")
		var is_self := (member_id == _get_account_id())

		# Management buttons (only for officers+ and not self)
		if can_manage and not is_self and member_role != "owner":
			if my_role == "owner":
				if member_role == "member":
					var promote_btn := Button.new()
					promote_btn.text = "Promote"
					promote_btn.pressed.connect(func(): _set_member_role(member_id, "officer"))
					hbox.add_child(promote_btn)
				elif member_role == "officer":
					var demote_btn := Button.new()
					demote_btn.text = "Demote"
					demote_btn.pressed.connect(func(): _set_member_role(member_id, "member"))
					hbox.add_child(demote_btn)

			var kick_btn := Button.new()
			kick_btn.text = "Kick"
			kick_btn.pressed.connect(func(): _kick_member(member_id))
			hbox.add_child(kick_btn)


func _set_member_role(account_id: String, role: String) -> void:
	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/members/" + account_id + "/role"
	var body := JSON.stringify({
		"token": _get_token(),
		"role": role
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Guild] Role updated to %s" % role)
			_refresh_members()
		else:
			main._append_chat("[Guild] Failed to update role.")
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, body)


func _kick_member(account_id: String) -> void:
	var url := _get_base_url() + "/api/groups/members"
	var body := JSON.stringify({
		"token": _get_token(),
		"groupId": current_guild_id,
		"memberAccountId": account_id
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Guild] Member removed.")
			_refresh_members()
		else:
			main._append_chat("[Guild] Failed to kick member.")
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_DELETE, body)


func _invite_member() -> void:
	var member_id := invite_input.text.strip_edges()
	if member_id.is_empty():
		return

	var url := _get_base_url() + "/api/groups/members"
	var body := JSON.stringify({
		"token": _get_token(),
		"groupId": current_guild_id,
		"memberAccountId": member_id,
		"role": "member"
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Guild] Member invited.")
			invite_input.clear()
			_refresh_members()
		else:
			var err := json.get("error", "Invite failed") if json else "Invite failed"
			main._append_chat("[Guild] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


# ── Treasury Tab ─────────────────────────────────────────────────────────────

func _build_treasury_tab() -> void:
	treasury_container = VBoxContainer.new()
	treasury_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	treasury_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guild_tab_content.add_child(treasury_container)

	# Balance display
	treasury_balance_label = Label.new()
	treasury_balance_label.text = "Treasury Balance: 0 coins"
	treasury_balance_label.add_theme_font_size_override("font_size", 16)
	treasury_container.add_child(treasury_balance_label)

	# Deposit row
	var deposit_row := HBoxContainer.new()
	treasury_container.add_child(deposit_row)
	var deposit_lbl := Label.new()
	deposit_lbl.text = "Deposit:"
	deposit_lbl.custom_minimum_size.x = 80
	deposit_row.add_child(deposit_lbl)
	deposit_input = SpinBox.new()
	deposit_input.min_value = 1
	deposit_input.max_value = 999999
	deposit_input.value = 100
	deposit_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deposit_row.add_child(deposit_input)
	deposit_button = Button.new()
	deposit_button.text = "Deposit"
	deposit_button.pressed.connect(_deposit_treasury)
	deposit_row.add_child(deposit_button)

	# Withdraw row (owner/officer only - visibility managed in _show_guild_tab)
	var withdraw_row := HBoxContainer.new()
	withdraw_row.name = "WithdrawRow"
	treasury_container.add_child(withdraw_row)
	var withdraw_lbl := Label.new()
	withdraw_lbl.text = "Withdraw:"
	withdraw_lbl.custom_minimum_size.x = 80
	withdraw_row.add_child(withdraw_lbl)
	withdraw_input = SpinBox.new()
	withdraw_input.min_value = 1
	withdraw_input.max_value = 999999
	withdraw_input.value = 100
	withdraw_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	withdraw_row.add_child(withdraw_input)
	withdraw_button = Button.new()
	withdraw_button.text = "Withdraw"
	withdraw_button.pressed.connect(_withdraw_treasury)
	withdraw_row.add_child(withdraw_button)

	var sep := HSeparator.new()
	treasury_container.add_child(sep)

	# Transaction history
	var history_header := Label.new()
	history_header.text = "Transaction History"
	history_header.add_theme_font_size_override("font_size", 14)
	treasury_container.add_child(history_header)

	treasury_history_scroll = ScrollContainer.new()
	treasury_history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	treasury_history_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	treasury_container.add_child(treasury_history_scroll)

	treasury_history_vbox = VBoxContainer.new()
	treasury_history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	treasury_history_scroll.add_child(treasury_history_vbox)


func _deposit_treasury() -> void:
	if current_guild_id.is_empty():
		return

	var amount := int(deposit_input.value)
	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/treasury/deposit"
	var body := JSON.stringify({
		"token": _get_token(),
		"amount": amount
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			treasury_balance = json.get("treasury", treasury_balance)
			treasury_balance_label.text = "Treasury Balance: %d coins" % treasury_balance
			main._append_chat("[Guild] Deposited %d coins." % amount)
		else:
			var err := json.get("error", "Deposit failed") if json else "Deposit failed"
			main._append_chat("[Guild] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _withdraw_treasury() -> void:
	if current_guild_id.is_empty():
		return

	var amount := int(withdraw_input.value)
	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/treasury/withdraw"
	var body := JSON.stringify({
		"token": _get_token(),
		"amount": amount
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			treasury_balance = json.get("treasury", treasury_balance)
			treasury_balance_label.text = "Treasury Balance: %d coins" % treasury_balance
			main._append_chat("[Guild] Withdrew %d coins." % amount)
		else:
			var err := json.get("error", "Withdraw failed") if json else "Withdraw failed"
			main._append_chat("[Guild] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _refresh_treasury() -> void:
	if current_guild_id.is_empty():
		return

	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/treasury"

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json:
			treasury_balance = json.get("balance", 0)
			treasury_balance_label.text = "Treasury Balance: %d coins" % treasury_balance
			treasury_history = json.get("history", [])
			_render_treasury_history()
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _render_treasury_history() -> void:
	for child in treasury_history_vbox.get_children():
		child.queue_free()

	if treasury_history.is_empty():
		var empty := Label.new()
		empty.text = "No transactions yet."
		treasury_history_vbox.add_child(empty)
		return

	for entry in treasury_history:
		var label := Label.new()
		var tx_type: String = entry.get("type", "unknown")
		var tx_amount: int = entry.get("amount", 0)
		var tx_by: String = entry.get("accountId", "unknown")
		var tx_date: String = entry.get("date", "")
		label.text = "%s: %s%d coins by %s (%s)" % [
			tx_type.capitalize(),
			"+" if tx_type == "deposit" else "-",
			tx_amount,
			tx_by,
			tx_date
		]
		treasury_history_vbox.add_child(label)


# ── Settings Tab ─────────────────────────────────────────────────────────────

func _build_settings_tab() -> void:
	settings_container = VBoxContainer.new()
	settings_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guild_tab_content.add_child(settings_container)

	var settings_header := Label.new()
	settings_header.text = "Guild Settings"
	settings_header.add_theme_font_size_override("font_size", 16)
	settings_container.add_child(settings_header)

	# Description editor
	var desc_lbl := Label.new()
	desc_lbl.text = "Description:"
	settings_container.add_child(desc_lbl)

	settings_desc_input = TextEdit.new()
	settings_desc_input.custom_minimum_size = Vector2(0, 80)
	settings_desc_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_container.add_child(settings_desc_input)

	save_desc_button = Button.new()
	save_desc_button.text = "Save Description"
	save_desc_button.pressed.connect(_save_description)
	settings_container.add_child(save_desc_button)

	var sep1 := HSeparator.new()
	settings_container.add_child(sep1)

	# Emblem color
	var emblem_row := HBoxContainer.new()
	settings_container.add_child(emblem_row)
	var emblem_lbl := Label.new()
	emblem_lbl.text = "Emblem Color:"
	emblem_lbl.custom_minimum_size.x = 120
	emblem_row.add_child(emblem_lbl)
	emblem_color_picker = ColorPickerButton.new()
	emblem_color_picker.custom_minimum_size = Vector2(60, 30)
	emblem_color_picker.color = Color.BLUE
	emblem_row.add_child(emblem_color_picker)
	save_emblem_button = Button.new()
	save_emblem_button.text = "Save Emblem"
	save_emblem_button.pressed.connect(_save_emblem)
	emblem_row.add_child(save_emblem_button)

	# Banner color
	var banner_row := HBoxContainer.new()
	settings_container.add_child(banner_row)
	var banner_lbl := Label.new()
	banner_lbl.text = "Banner Color:"
	banner_lbl.custom_minimum_size.x = 120
	banner_row.add_child(banner_lbl)
	banner_color_picker = ColorPickerButton.new()
	banner_color_picker.custom_minimum_size = Vector2(60, 30)
	banner_color_picker.color = Color.RED
	banner_row.add_child(banner_color_picker)
	save_banner_button = Button.new()
	save_banner_button.text = "Save Banner"
	save_banner_button.pressed.connect(_save_banner)
	banner_row.add_child(save_banner_button)

	settings_status = Label.new()
	settings_status.text = ""
	settings_container.add_child(settings_status)


func _save_description() -> void:
	if current_guild_id.is_empty():
		return

	var new_desc := settings_desc_input.text.strip_edges()
	# Use the banner endpoint to update description text
	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/banner"
	var body := JSON.stringify({
		"token": _get_token(),
		"text": new_desc
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			settings_status.text = "Description saved."
			current_guild["description"] = new_desc
			guild_desc_label.text = new_desc
		else:
			settings_status.text = "Failed to save description."
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, body)


func _save_emblem() -> void:
	if current_guild_id.is_empty():
		return

	var color_hex := emblem_color_picker.color.to_html(false)
	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/emblem"
	var body := JSON.stringify({
		"token": _get_token(),
		"color": color_hex,
		"icon": "shield"  # default icon
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			settings_status.text = "Emblem updated."
		else:
			settings_status.text = "Failed to update emblem."
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, body)


func _save_banner() -> void:
	if current_guild_id.is_empty():
		return

	var color_hex := banner_color_picker.color.to_html(false)
	# We use the banner endpoint with color text to store the banner color
	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/banner"
	var body := JSON.stringify({
		"token": _get_token(),
		"text": "banner_color:" + color_hex
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			settings_status.text = "Banner color saved."
		else:
			settings_status.text = "Failed to save banner."
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, body)


# ── Alliances Tab ────────────────────────────────────────────────────────────

func _build_alliances_tab() -> void:
	alliances_container = VBoxContainer.new()
	alliances_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	alliances_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guild_tab_content.add_child(alliances_container)

	var header := Label.new()
	header.text = "Alliances"
	header.add_theme_font_size_override("font_size", 16)
	alliances_container.add_child(header)

	# Send alliance request
	var request_row := HBoxContainer.new()
	alliances_container.add_child(request_row)

	alliance_target_input = LineEdit.new()
	alliance_target_input.placeholder_text = "Target guild ID..."
	alliance_target_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	request_row.add_child(alliance_target_input)

	alliance_send_button = Button.new()
	alliance_send_button.text = "Send Request"
	alliance_send_button.pressed.connect(_send_alliance_request)
	request_row.add_child(alliance_send_button)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_alliances)
	request_row.add_child(refresh_btn)

	var sep := HSeparator.new()
	alliances_container.add_child(sep)

	# Alliance list
	alliances_scroll = ScrollContainer.new()
	alliances_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	alliances_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alliances_container.add_child(alliances_scroll)

	alliances_vbox = VBoxContainer.new()
	alliances_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alliances_scroll.add_child(alliances_vbox)


func _send_alliance_request() -> void:
	var target_id := alliance_target_input.text.strip_edges()
	if target_id.is_empty() or current_guild_id.is_empty():
		return

	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/alliances"
	var body := JSON.stringify({
		"token": _get_token(),
		"targetGroupId": target_id
	})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Guild] Alliance request sent.")
			alliance_target_input.clear()
			_refresh_alliances()
		else:
			var err := json.get("error", "Request failed") if json else "Request failed"
			main._append_chat("[Guild] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _refresh_alliances() -> void:
	if current_guild_id.is_empty():
		return

	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/alliances"

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("alliances"):
			alliances = json["alliances"]
			_render_alliances()
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _render_alliances() -> void:
	for child in alliances_vbox.get_children():
		child.queue_free()

	if alliances.is_empty():
		var empty := Label.new()
		empty.text = "No alliances."
		alliances_vbox.add_child(empty)
		return

	for alliance in alliances:
		var entry := PanelContainer.new()
		entry.custom_minimum_size = Vector2(0, 45)
		alliances_vbox.add_child(entry)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		entry.add_child(hbox)

		var name_label := Label.new()
		var ally_name: String = alliance.get("groupName", alliance.get("targetGroupId", "Unknown"))
		name_label.text = ally_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)

		var status_lbl := Label.new()
		var alliance_status: String = alliance.get("status", "pending")
		status_lbl.text = alliance_status.capitalize()
		hbox.add_child(status_lbl)

		var ally_id: String = alliance.get("targetGroupId", alliance.get("allyGroupId", ""))

		# Accept button for pending incoming alliances
		if alliance_status == "pending" and alliance.get("targetGroupId", "") == current_guild_id:
			var accept_btn := Button.new()
			accept_btn.text = "Accept"
			var source_id: String = alliance.get("sourceGroupId", ally_id)
			accept_btn.pressed.connect(func(): _accept_alliance(source_id))
			hbox.add_child(accept_btn)

		# Dissolve button for active alliances
		if alliance_status == "active" and (my_role == "owner" or my_role == "officer"):
			var dissolve_btn := Button.new()
			dissolve_btn.text = "Dissolve"
			dissolve_btn.pressed.connect(func(): _dissolve_alliance(ally_id))
			hbox.add_child(dissolve_btn)


func _accept_alliance(source_group_id: String) -> void:
	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/alliances/" + source_group_id + "/accept"
	var body := JSON.stringify({"token": _get_token()})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Guild] Alliance accepted!")
			_refresh_alliances()
		else:
			main._append_chat("[Guild] Failed to accept alliance.")
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _dissolve_alliance(ally_group_id: String) -> void:
	var url := _get_base_url() + "/api/groups/" + current_guild_id + "/alliances/" + ally_group_id
	var body := JSON.stringify({"token": _get_token()})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Guild] Alliance dissolved.")
			_refresh_alliances()
		else:
			main._append_chat("[Guild] Failed to dissolve alliance.")
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_DELETE, body)


# ── Guild Sub-Tab Switching ──────────────────────────────────────────────────

func _on_guild_tab_changed(tab_idx: int) -> void:
	_show_guild_tab(tab_idx)


func _show_guild_tab(tab_idx: int) -> void:
	members_container.visible = (tab_idx == 0)
	treasury_container.visible = (tab_idx == 1)
	settings_container.visible = (tab_idx == 2)
	alliances_container.visible = (tab_idx == 3)

	# Restrict withdraw to owner/officer
	var withdraw_row := treasury_container.get_node_or_null("WithdrawRow")
	if withdraw_row:
		withdraw_row.visible = (my_role == "owner" or my_role == "officer")

	# Restrict settings to owner/officer
	if settings_container:
		save_desc_button.visible = (my_role == "owner" or my_role == "officer")
		save_emblem_button.visible = (my_role == "owner" or my_role == "officer")
		save_banner_button.visible = (my_role == "owner" or my_role == "officer")

	match tab_idx:
		0: _refresh_members()
		1: _refresh_treasury()
		2:
			settings_desc_input.text = current_guild.get("description", "")
		3: _refresh_alliances()


# ── Group Chat Integration ───────────────────────────────────────────────────

func _build_chat_channel_selector() -> void:
	# Add a channel selector before the chat input row in the main UI
	chat_channel_select = OptionButton.new()
	chat_channel_select.add_item("Region")
	chat_channel_select.add_item("Guild")
	chat_channel_select.custom_minimum_size = Vector2(90, 0)

	# Insert into the chat input row if it exists
	var chat_input_row = main.chat_input.get_parent()
	if chat_input_row:
		chat_input_row.add_child(chat_channel_select)
		chat_input_row.move_child(chat_channel_select, 0)


func get_selected_chat_channel() -> String:
	if chat_channel_select.selected == 1:
		return "guild"
	return "region"


func send_guild_chat(message: String) -> void:
	if current_guild_id.is_empty():
		main._append_chat("[Guild] You are not in a guild.")
		return
	main.guild_mgr.send_group_chat(current_guild_id, message)


func handle_group_chat_event(data: Dictionary) -> void:
	var sender: String = data.get("senderName", "Unknown")
	var message: String = data.get("message", "")
	var guild_name: String = data.get("groupName", "Guild")
	main._append_chat("[%s] %s: %s" % [guild_name, sender, message])


# ── Public API ───────────────────────────────────────────────────────────────

func show_panel() -> void:
	visible = true
	if current_guild_id.is_empty():
		_refresh_my_groups()
	else:
		_load_guild_details()
		_show_guild_tab(guild_tab_bar.current_tab)


func hide_panel() -> void:
	visible = false
