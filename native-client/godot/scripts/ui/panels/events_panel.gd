class_name EventsPanel extends Control

var main
var _tab_bar: TabBar
var _content_stack: Control

# Upcoming events tab
var _events_list: VBoxContainer
var _events_scroll: ScrollContainer

# Create event dialog
var _create_dialog: PanelContainer
var _create_name_input: LineEdit
var _create_type_select: OptionButton
var _create_description_input: TextEdit
var _create_date_input: LineEdit
var _create_time_input: LineEdit
var _create_recurring_select: OptionButton
var _create_max_attendees_input: LineEdit
var _create_prizes_input: LineEdit

# My events tab
var _my_events_list: VBoxContainer

# Expanded event detail
var _expanded_event_id: String = ""

const EVENT_TYPES := ["build_competition", "dance_party", "concert", "workshop", "tour", "meetup", "roleplay", "pvp_tournament", "custom"]
const EVENT_TYPE_ICONS := {
	"build_competition": "[B]",
	"dance_party": "[D]",
	"concert": "[C]",
	"workshop": "[W]",
	"tour": "[T]",
	"meetup": "[M]",
	"roleplay": "[R]",
	"pvp_tournament": "[P]",
	"custom": "[*]"
}
const RECURRING_OPTIONS := ["None", "Daily", "Weekly", "Monthly"]


func init(main_node) -> void:
	main = main_node
	name = "EventsPanel"
	visible = false
	_build_ui()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_child(root_vbox)

	# Title
	var title := Label.new()
	title.text = "Events"
	title.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(title)

	# Tab bar
	_tab_bar = TabBar.new()
	_tab_bar.add_tab("Upcoming")
	_tab_bar.add_tab("Create Event")
	_tab_bar.add_tab("My Events")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	root_vbox.add_child(_tab_bar)

	_content_stack = Control.new()
	_content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_content_stack)

	_build_upcoming_tab()
	_build_create_tab()
	_build_my_events_tab()

	_on_tab_changed(0)


# ── Upcoming Events Tab ──────────────────────────────────────────────────

func _build_upcoming_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "UpcomingTab"
	container.set_anchors_preset(PRESET_FULL_RECT)
	_content_stack.add_child(container)

	var top_row := HBoxContainer.new()
	container.add_child(top_row)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_upcoming)
	top_row.add_child(refresh_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	_events_scroll = ScrollContainer.new()
	_events_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_events_scroll.custom_minimum_size = Vector2(0, 350)
	container.add_child(_events_scroll)

	_events_list = VBoxContainer.new()
	_events_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_events_scroll.add_child(_events_list)


# ── Create Event Tab ─────────────────────────────────────────────────────

func _build_create_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "CreateTab"
	container.set_anchors_preset(PRESET_FULL_RECT)
	_content_stack.add_child(container)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	# Event Name
	var name_lbl := Label.new()
	name_lbl.text = "Event Name:"
	form.add_child(name_lbl)
	_create_name_input = LineEdit.new()
	_create_name_input.placeholder_text = "Enter event name..."
	form.add_child(_create_name_input)

	# Type
	var type_lbl := Label.new()
	type_lbl.text = "Event Type:"
	form.add_child(type_lbl)
	_create_type_select = OptionButton.new()
	for t in EVENT_TYPES:
		_create_type_select.add_item(t.replace("_", " ").capitalize())
	form.add_child(_create_type_select)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = "Description:"
	form.add_child(desc_lbl)
	_create_description_input = TextEdit.new()
	_create_description_input.placeholder_text = "Describe your event..."
	_create_description_input.custom_minimum_size = Vector2(0, 60)
	form.add_child(_create_description_input)

	# Date
	var date_lbl := Label.new()
	date_lbl.text = "Date (YYYY-MM-DD):"
	form.add_child(date_lbl)
	_create_date_input = LineEdit.new()
	_create_date_input.placeholder_text = "2026-03-15"
	# Default to today
	var today := Time.get_date_dict_from_system()
	_create_date_input.text = "%04d-%02d-%02d" % [today.year, today.month, today.day]
	form.add_child(_create_date_input)

	# Time
	var time_lbl := Label.new()
	time_lbl.text = "Time (HH:MM):"
	form.add_child(time_lbl)
	_create_time_input = LineEdit.new()
	_create_time_input.placeholder_text = "18:00"
	_create_time_input.text = "18:00"
	form.add_child(_create_time_input)

	# Recurring
	var recur_lbl := Label.new()
	recur_lbl.text = "Recurring:"
	form.add_child(recur_lbl)
	_create_recurring_select = OptionButton.new()
	for opt in RECURRING_OPTIONS:
		_create_recurring_select.add_item(opt)
	form.add_child(_create_recurring_select)

	# Max attendees
	var max_lbl := Label.new()
	max_lbl.text = "Max Attendees (optional):"
	form.add_child(max_lbl)
	_create_max_attendees_input = LineEdit.new()
	_create_max_attendees_input.placeholder_text = "Leave empty for unlimited"
	form.add_child(_create_max_attendees_input)

	# Prizes
	var prizes_lbl := Label.new()
	prizes_lbl.text = "Prizes (optional):"
	form.add_child(prizes_lbl)
	_create_prizes_input = LineEdit.new()
	_create_prizes_input.placeholder_text = "Describe any prizes..."
	form.add_child(_create_prizes_input)

	# Submit button
	var submit_btn := Button.new()
	submit_btn.text = "Create Event"
	submit_btn.custom_minimum_size = Vector2(0, 36)
	submit_btn.pressed.connect(_submit_create_event)
	form.add_child(submit_btn)


# ── My Events Tab ────────────────────────────────────────────────────────

func _build_my_events_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "MyEventsTab"
	container.set_anchors_preset(PRESET_FULL_RECT)
	_content_stack.add_child(container)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh My Events"
	refresh_btn.pressed.connect(_refresh_my_events)
	container.add_child(refresh_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	container.add_child(scroll)

	_my_events_list = VBoxContainer.new()
	_my_events_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_my_events_list)


# ── Tab Switching ────────────────────────────────────────────────────────

func _on_tab_changed(index: int) -> void:
	for i in _content_stack.get_child_count():
		_content_stack.get_child(i).visible = (i == index)
	match index:
		0: _refresh_upcoming()
		2: _refresh_my_events()


# ── Data Loading ─────────────────────────────────────────────────────────

func _refresh_upcoming() -> void:
	if main == null or main.event_mgr == null:
		return
	main.event_mgr.load_upcoming_events()
	await main.get_tree().create_timer(0.5).timeout
	_render_upcoming()


func _refresh_my_events() -> void:
	if main == null or main.event_mgr == null:
		return
	# Load all events, then filter by creator on client side
	main.event_mgr.load_upcoming_events()
	await main.get_tree().create_timer(0.5).timeout
	_render_my_events()


# ── Rendering ────────────────────────────────────────────────────────────

func _render_upcoming() -> void:
	for child in _events_list.get_children():
		child.queue_free()

	var events: Array = main.event_mgr.cached_events if main.event_mgr != null else []

	if events.is_empty():
		var lbl := Label.new()
		lbl.text = "No upcoming events."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_events_list.add_child(lbl)
		return

	for ev in events:
		_add_event_card(_events_list, ev, false)


func _render_my_events() -> void:
	for child in _my_events_list.get_children():
		child.queue_free()

	var events: Array = main.event_mgr.cached_events if main.event_mgr != null else []
	var my_account_id: String = main.session.get("accountId", "")

	var my_created: Array = []
	var my_rsvpd: Array = []

	for ev in events:
		if ev.get("creatorId", "") == my_account_id:
			my_created.append(ev)
		var rsvps: Array = ev.get("rsvps", [])
		if rsvps.has(my_account_id):
			my_rsvpd.append(ev)

	# Created by me
	var created_header := Label.new()
	created_header.text = "Events I Created"
	created_header.add_theme_font_size_override("font_size", 16)
	_my_events_list.add_child(created_header)

	if my_created.is_empty():
		var lbl := Label.new()
		lbl.text = "You haven't created any events."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_my_events_list.add_child(lbl)
	else:
		for ev in my_created:
			_add_event_card(_my_events_list, ev, true)

	var sep := HSeparator.new()
	_my_events_list.add_child(sep)

	# RSVP'd
	var rsvp_header := Label.new()
	rsvp_header.text = "Events I RSVP'd To"
	rsvp_header.add_theme_font_size_override("font_size", 16)
	_my_events_list.add_child(rsvp_header)

	if my_rsvpd.is_empty():
		var lbl := Label.new()
		lbl.text = "You haven't RSVP'd to any events."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_my_events_list.add_child(lbl)
	else:
		for ev in my_rsvpd:
			_add_event_card(_my_events_list, ev, false)


func _add_event_card(parent: VBoxContainer, ev: Dictionary, show_cancel: bool) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.22, 0.9)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	# Top row: type icon, name, time
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var event_type: String = ev.get("type", "custom")
	var icon_text: String = EVENT_TYPE_ICONS.get(event_type, "[*]")

	var icon_lbl := Label.new()
	icon_lbl.text = icon_text
	icon_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	icon_lbl.custom_minimum_size = Vector2(30, 0)
	top_row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = ev.get("name", "Unnamed Event")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	top_row.add_child(name_lbl)

	var time_lbl := Label.new()
	var start_time: String = ev.get("startTime", "")
	time_lbl.text = _format_event_time(start_time)
	time_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	top_row.add_child(time_lbl)

	# Info row: region, RSVP count, creator
	var info_row := HBoxContainer.new()
	vbox.add_child(info_row)

	var region_lbl := Label.new()
	region_lbl.text = "Region: %s" % ev.get("regionId", "?")
	region_lbl.add_theme_font_size_override("font_size", 12)
	region_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	region_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(region_lbl)

	var rsvps: Array = ev.get("rsvps", [])
	var rsvp_count_lbl := Label.new()
	rsvp_count_lbl.text = "%d attending" % rsvps.size()
	rsvp_count_lbl.add_theme_font_size_override("font_size", 12)
	rsvp_count_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	info_row.add_child(rsvp_count_lbl)

	# Action row: RSVP button, expand, cancel
	var action_row := HBoxContainer.new()
	vbox.add_child(action_row)

	var event_id: String = ev.get("id", "")
	var my_account_id: String = main.session.get("accountId", "")
	var is_rsvpd: bool = rsvps.has(my_account_id)

	var rsvp_btn := Button.new()
	rsvp_btn.text = "Going" if is_rsvpd else "RSVP"
	if is_rsvpd:
		rsvp_btn.add_theme_color_override("font_color", Color.GREEN)
	var captured_id := event_id
	rsvp_btn.pressed.connect(func(): _rsvp_event(captured_id))
	action_row.add_child(rsvp_btn)

	var expand_btn := Button.new()
	expand_btn.text = "Details"
	expand_btn.pressed.connect(func(): _toggle_event_detail(vbox, ev))
	action_row.add_child(expand_btn)

	if show_cancel:
		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel Event"
		cancel_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		cancel_btn.pressed.connect(func(): _cancel_event(captured_id))
		action_row.add_child(cancel_btn)


func _toggle_event_detail(parent_vbox: VBoxContainer, ev: Dictionary) -> void:
	# Check if detail is already shown (last child is a detail panel)
	var last_child = parent_vbox.get_child(parent_vbox.get_child_count() - 1)
	if last_child.name == "EventDetail":
		last_child.queue_free()
		return

	# Add detail panel
	var detail := VBoxContainer.new()
	detail.name = "EventDetail"

	var sep := HSeparator.new()
	detail.add_child(sep)

	var desc := ev.get("description", "No description provided.")
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	detail.add_child(desc_lbl)

	var creator_lbl := Label.new()
	creator_lbl.text = "Created by: %s" % ev.get("creatorDisplayName", ev.get("creatorId", "Unknown"))
	creator_lbl.add_theme_font_size_override("font_size", 12)
	creator_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	detail.add_child(creator_lbl)

	var prizes: String = ev.get("prizes", "")
	if not prizes.is_empty():
		var prizes_lbl := Label.new()
		prizes_lbl.text = "Prizes: %s" % prizes
		prizes_lbl.add_theme_font_size_override("font_size", 12)
		prizes_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		detail.add_child(prizes_lbl)

	parent_vbox.add_child(detail)


# ── Actions ──────────────────────────────────────────────────────────────

func _submit_create_event() -> void:
	if main == null or main.event_mgr == null:
		return

	var event_name := _create_name_input.text.strip_edges()
	if event_name.is_empty():
		_append_chat("System: Event name is required.")
		return

	var type_index := _create_type_select.selected
	var event_type := EVENT_TYPES[type_index] if type_index >= 0 and type_index < EVENT_TYPES.size() else "custom"

	var description := _create_description_input.text.strip_edges()
	var date_str := _create_date_input.text.strip_edges()
	var time_str := _create_time_input.text.strip_edges()

	var start_time := "%sT%s:00Z" % [date_str, time_str]

	var recurring_index := _create_recurring_select.selected
	var recurring := RECURRING_OPTIONS[recurring_index].to_lower() if recurring_index > 0 else ""

	var region_id: String = main.session.get("regionId", "")

	var data: Dictionary = {
		"name": event_name,
		"type": event_type,
		"description": description,
		"startTime": start_time,
		"regionId": region_id
	}

	if not recurring.is_empty() and recurring != "none":
		data["recurring"] = recurring

	var max_attendees := _create_max_attendees_input.text.strip_edges()
	if not max_attendees.is_empty() and max_attendees.is_valid_int():
		data["maxAttendees"] = int(max_attendees)

	var prizes := _create_prizes_input.text.strip_edges()
	if not prizes.is_empty():
		data["prizes"] = prizes

	main.event_mgr.create_event(data)
	_append_chat("System: Creating event '%s'..." % event_name)

	# Clear form
	_create_name_input.clear()
	_create_description_input.clear()
	_create_prizes_input.clear()
	_create_max_attendees_input.clear()


func _rsvp_event(event_id: String) -> void:
	if main == null or main.event_mgr == null:
		return
	main.event_mgr.rsvp_event(event_id)
	await main.get_tree().create_timer(0.5).timeout
	_refresh_upcoming()


func _cancel_event(event_id: String) -> void:
	if main == null or main.event_mgr == null:
		return
	main.event_mgr.cancel_event(event_id)
	await main.get_tree().create_timer(0.5).timeout
	_refresh_my_events()


# ── Helpers ──────────────────────────────────────────────────────────────

func _format_event_time(iso_string: String) -> String:
	if iso_string.is_empty():
		return "TBD"
	var cleaned := iso_string.replace("Z", "").replace("z", "")
	var parts := cleaned.split("T")
	if parts.size() < 2:
		return iso_string
	var date_str := parts[0]
	var time_str := parts[1]
	if time_str.length() >= 5:
		time_str = time_str.substr(0, 5)
	return "%s %s" % [date_str, time_str]


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	return style


func _append_chat(text: String) -> void:
	if main and main.chat_log:
		main.chat_log.append_text(text + "\n")
