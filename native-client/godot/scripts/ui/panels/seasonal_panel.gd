class_name SeasonalPanel
extends Control

## Seasonal content browser panel for VibeLife.
## Current season header, items grid with rarity, collect, progress, achievements, leaderboard.

var main  # reference to main node

# HTTP request nodes
var _season_request: HTTPRequest
var _items_request: HTTPRequest
var _collect_request: HTTPRequest
var _progress_request: HTTPRequest
var _achievements_request: HTTPRequest
var _leaderboard_request: HTTPRequest

# State
var _current_season := ""
var _active_holidays: Array = []
var _items: Array = []
var _collected_ids: Array = []
var _progress_data: Dictionary = {}
var _achievements: Array = []
var _leaderboard: Array = []
var _current_tab := 0  # 0=Items, 1=Achievements, 2=Leaderboard

# UI references
var _season_header_label: Label
var _holiday_label: Label
var _tab_buttons: Array = []
var _progress_bar: ProgressBar
var _progress_label: Label
var _items_scroll: ScrollContainer
var _items_grid: GridContainer
var _achievements_scroll: ScrollContainer
var _achievements_list: VBoxContainer
var _leaderboard_scroll: ScrollContainer
var _leaderboard_list: VBoxContainer
var _status_label: Label

const SEASON_ICONS := {
	"spring": "* Spring",
	"summer": "~ Summer",
	"autumn": "# Autumn",
	"winter": "o Winter",
}

const RARITY_COLORS := {
	"common": Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.3, 0.8, 0.3),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.7, 0.3, 0.9),
	"legendary": Color(1.0, 0.7, 0.1),
}

const SEASON_COLORS := {
	"spring": Color(0.9, 0.6, 0.7),
	"summer": Color(1.0, 0.85, 0.3),
	"autumn": Color(0.9, 0.5, 0.15),
	"winter": Color(0.7, 0.85, 1.0),
}


func init(main_node) -> void:
	main = main_node
	name = "SeasonalPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var canvas_layer = main.get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(self)

	# Create HTTP request nodes
	_season_request = _make_http("SeasonalPanelSeasonReq", _on_season_loaded)
	_items_request = _make_http("SeasonalPanelItemsReq", _on_items_loaded)
	_collect_request = _make_http("SeasonalPanelCollectReq", _on_collect_response)
	_progress_request = _make_http("SeasonalPanelProgressReq", _on_progress_loaded)
	_achievements_request = _make_http("SeasonalPanelAchievReq", _on_achievements_loaded)
	_leaderboard_request = _make_http("SeasonalPanelLeaderReq", _on_leaderboard_loaded)

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


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.09, 0.09, 0.11, 0.95)
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
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root_vbox.add_child(header)

	_season_header_label = Label.new()
	_season_header_label.text = "Seasonal"
	_season_header_label.add_theme_font_size_override("font_size", 24)
	_season_header_label.add_theme_color_override("font_color", Color.WHITE)
	_season_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_season_header_label)

	_holiday_label = Label.new()
	_holiday_label.text = ""
	_holiday_label.add_theme_font_size_override("font_size", 14)
	_holiday_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	header.add_child(_holiday_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	# Collection progress bar
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(progress_row)

	var prog_label := Label.new()
	prog_label.text = "Collection:"
	prog_label.add_theme_font_size_override("font_size", 13)
	prog_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	progress_row.add_child(prog_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(200, 20)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.7, 0.4)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	_progress_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	_progress_bar.add_theme_stylebox_override("background", bg_style)

	progress_row.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.text = "0 / 0"
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_progress_label.custom_minimum_size = Vector2(60, 0)
	progress_row.add_child(_progress_label)

	# Tab row
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	root_vbox.add_child(tab_row)

	var tab_names := ["Items", "Achievements", "Leaderboard"]
	for i in range(tab_names.size()):
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(110, 30)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		var idx := i
		btn.pressed.connect(func(): _switch_tab(idx))
		tab_row.add_child(btn)
		_tab_buttons.append(btn)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	root_vbox.add_child(_status_label)

	# Items grid (scrollable)
	_items_scroll = ScrollContainer.new()
	_items_scroll.name = "ItemsScroll"
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_items_scroll)

	_items_grid = GridContainer.new()
	_items_grid.name = "ItemsGrid"
	_items_grid.columns = 4
	_items_grid.add_theme_constant_override("h_separation", 8)
	_items_grid.add_theme_constant_override("v_separation", 8)
	_items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.add_child(_items_grid)

	# Achievements list (scrollable, hidden by default)
	_achievements_scroll = ScrollContainer.new()
	_achievements_scroll.name = "AchievementsScroll"
	_achievements_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_achievements_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievements_scroll.visible = false
	root_vbox.add_child(_achievements_scroll)

	_achievements_list = VBoxContainer.new()
	_achievements_list.name = "AchievementsList"
	_achievements_list.add_theme_constant_override("separation", 6)
	_achievements_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievements_scroll.add_child(_achievements_list)

	# Leaderboard list (scrollable, hidden by default)
	_leaderboard_scroll = ScrollContainer.new()
	_leaderboard_scroll.name = "LeaderboardScroll"
	_leaderboard_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_leaderboard_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leaderboard_scroll.visible = false
	root_vbox.add_child(_leaderboard_scroll)

	_leaderboard_list = VBoxContainer.new()
	_leaderboard_list.name = "LeaderboardList"
	_leaderboard_list.add_theme_constant_override("separation", 4)
	_leaderboard_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leaderboard_scroll.add_child(_leaderboard_list)


# ── Tab Switching ────────────────────────────────────────────────────────────

func _switch_tab(index: int) -> void:
	_current_tab = index
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].button_pressed = (i == index)

	_items_scroll.visible = (index == 0)
	_achievements_scroll.visible = (index == 1)
	_leaderboard_scroll.visible = (index == 2)

	match index:
		0:
			_load_items()
		1:
			_load_achievements()
		2:
			_load_leaderboard()


func show_panel() -> void:
	visible = true
	_load_season()
	_load_progress()
	_switch_tab(_current_tab)


# ── Data Loading ─────────────────────────────────────────────────────────────

func _load_season() -> void:
	var url := "%s/api/seasonal/current" % _base_url()
	_season_request.request(url, [], HTTPClient.METHOD_GET)


func _load_items() -> void:
	_status_label.text = "Loading items..."
	var url := "%s/api/seasonal/items" % _base_url()
	_items_request.request(url, [], HTTPClient.METHOD_GET)


func _load_progress() -> void:
	var token := _token()
	if token.is_empty():
		return
	var url := "%s/api/seasonal/progress?token=%s" % [_base_url(), token]
	_progress_request.request(url, [], HTTPClient.METHOD_GET)


func _load_achievements() -> void:
	_status_label.text = "Loading achievements..."
	var url := "%s/api/seasonal/achievements" % _base_url()
	_achievements_request.request(url, [], HTTPClient.METHOD_GET)


func _load_leaderboard() -> void:
	_status_label.text = "Loading leaderboard..."
	var url := "%s/api/seasonal/leaderboard" % _base_url()
	_leaderboard_request.request(url, [], HTTPClient.METHOD_GET)


func _collect_item(item_id: String) -> void:
	var token := _token()
	if token.is_empty():
		_status_label.text = "Not logged in"
		return
	var url := "%s/api/seasonal/items/%s/collect" % [_base_url(), item_id]
	var body := JSON.stringify({"token": token})
	var headers := PackedStringArray(["Content-Type: application/json"])
	_collect_request.request(url, headers, HTTPClient.METHOD_POST, body)


# ── HTTP Callbacks ───────────────────────────────────────────────────────────

func _on_season_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_current_season = json.get("season", "")
	_active_holidays = json.get("holidays", [])

	# Update header
	var display_name: String = SEASON_ICONS.get(_current_season, _current_season.capitalize())
	var season_color: Color = SEASON_COLORS.get(_current_season, Color.WHITE)
	_season_header_label.text = display_name
	_season_header_label.add_theme_color_override("font_color", season_color)

	if _active_holidays.size() > 0:
		var holiday_names: Array = []
		for h in _active_holidays:
			if h is Dictionary:
				holiday_names.append(h.get("name", ""))
			else:
				holiday_names.append(str(h))
		_holiday_label.text = "Active: %s" % ", ".join(holiday_names)
	else:
		_holiday_label.text = ""

	# Sync with seasonal_mgr
	if main.seasonal_mgr:
		main.seasonal_mgr.current_season = _current_season
		main.seasonal_mgr.active_holidays = _active_holidays


func _on_items_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Failed to load items"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_items = json.get("items", [])
	_status_label.text = "%d seasonal items" % _items.size()
	_render_items_grid()


func _on_collect_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Collection failed"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	if json.get("ok", false):
		_status_label.text = "Item collected!"
		# Refresh progress and items
		_load_progress()
		_load_items()
	else:
		_status_label.text = json.get("error", "Collection failed")


func _on_progress_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_progress_data = json.get("progress", {})
	_collected_ids = _progress_data.get("itemsCollected", [])

	var collected_count: int = _collected_ids.size()
	var total_count: int = _progress_data.get("totalItems", _items.size())
	if total_count == 0:
		total_count = maxi(_items.size(), 1)

	_progress_bar.max_value = total_count
	_progress_bar.value = collected_count
	_progress_label.text = "%d / %d" % [collected_count, total_count]

	# Re-render items to update collected status
	if _current_tab == 0 and _items.size() > 0:
		_render_items_grid()


func _on_achievements_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Failed to load achievements"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_achievements = json.get("achievements", [])
	_status_label.text = "%d seasonal achievements" % _achievements.size()
	_render_achievements()


func _on_leaderboard_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Failed to load leaderboard"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_leaderboard = json.get("leaderboard", [])
	_status_label.text = "%d entries" % _leaderboard.size()
	_render_leaderboard()


# ── Items Grid Rendering ────────────────────────────────────────────────────

func _render_items_grid() -> void:
	for child in _items_grid.get_children():
		child.queue_free()

	if _items.is_empty():
		var empty := Label.new()
		empty.text = "No seasonal items available"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_items_grid.add_child(empty)
		return

	for item in _items:
		var card := _create_item_card(item)
		_items_grid.add_child(card)


func _create_item_card(item: Dictionary) -> Control:
	var item_id: String = item.get("id", "")
	var item_name: String = item.get("name", "Unknown")
	var rarity: String = item.get("rarity", "common")
	var item_type: String = item.get("type", "")
	var is_collected: bool = _collected_ids.has(item_id)

	var rarity_color: Color = RARITY_COLORS.get(rarity, Color(0.5, 0.5, 0.5))

	# Card container with rarity-colored border
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 150)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.13, 0.13, 0.16)
	card_style.border_color = rarity_color
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.content_margin_left = 8
	card_style.content_margin_right = 8
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8

	if is_collected:
		card_style.bg_color = Color(0.1, 0.18, 0.1)

	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Item icon placeholder
	var icon := ColorRect.new()
	icon.color = rarity_color.lerp(Color(0.2, 0.2, 0.2), 0.6)
	icon.custom_minimum_size = Vector2(60, 60)
	vbox.add_child(icon)

	var icon_label := Label.new()
	icon_label.text = item_name.substr(0, 2).to_upper()
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_label.add_theme_font_size_override("font_size", 18)
	icon_label.add_theme_color_override("font_color", rarity_color)
	icon.add_child(icon_label)

	# Name
	var name_label := Label.new()
	name_label.text = item_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(120, 0)
	vbox.add_child(name_label)

	# Rarity + type row
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 4)
	vbox.add_child(info_row)

	var rarity_label := Label.new()
	rarity_label.text = rarity.capitalize()
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	info_row.add_child(rarity_label)

	if not item_type.is_empty():
		var type_label := Label.new()
		type_label.text = "[%s]" % item_type
		type_label.add_theme_font_size_override("font_size", 10)
		type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		info_row.add_child(type_label)

	# Collect button or checkmark
	if is_collected:
		var check := Label.new()
		check.text = "[Collected]"
		check.add_theme_font_size_override("font_size", 11)
		check.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		vbox.add_child(check)
	else:
		var collect_btn := Button.new()
		collect_btn.text = "Collect"
		collect_btn.custom_minimum_size = Vector2(80, 24)
		var iid := item_id
		collect_btn.pressed.connect(func(): _collect_item(iid))
		vbox.add_child(collect_btn)

	return card


# ── Achievements Rendering ───────────────────────────────────────────────────

func _render_achievements() -> void:
	for child in _achievements_list.get_children():
		child.queue_free()

	if _achievements.is_empty():
		var empty := Label.new()
		empty.text = "No seasonal achievements"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_achievements_list.add_child(empty)
		return

	for ach in _achievements:
		var row := _create_achievement_row(ach)
		_achievements_list.add_child(row)


func _create_achievement_row(ach: Dictionary) -> Control:
	var ach_name: String = ach.get("name", "Unknown")
	var ach_desc: String = ach.get("description", "")
	var ach_unlocked: bool = ach.get("unlocked", false)
	var ach_progress: int = ach.get("progress", 0)
	var ach_target: int = ach.get("target", 1)

	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.12, 0.15, 0.12) if ach_unlocked else Color(0.12, 0.12, 0.14)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row_style.content_margin_left = 10
	row_style.content_margin_right = 10
	row_style.content_margin_top = 6
	row_style.content_margin_bottom = 6
	row_panel.add_theme_stylebox_override("panel", row_style)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row_panel.add_child(hbox)

	# Icon placeholder
	var icon := Label.new()
	icon.text = "[*]" if ach_unlocked else "[ ]"
	icon.add_theme_font_size_override("font_size", 16)
	icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if ach_unlocked else Color(0.4, 0.4, 0.4))
	hbox.add_child(icon)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = ach_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE if ach_unlocked else Color(0.7, 0.7, 0.7))
	info_vbox.add_child(name_label)

	if not ach_desc.is_empty():
		var desc_label := Label.new()
		desc_label.text = ach_desc
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(desc_label)

	# Progress
	var progress_text := Label.new()
	if ach_unlocked:
		progress_text.text = "Completed"
		progress_text.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		progress_text.text = "%d / %d" % [ach_progress, ach_target]
		progress_text.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	progress_text.add_theme_font_size_override("font_size", 12)
	hbox.add_child(progress_text)

	return row_panel


# ── Leaderboard Rendering ───────────────────────────────────────────────────

func _render_leaderboard() -> void:
	for child in _leaderboard_list.get_children():
		child.queue_free()

	if _leaderboard.is_empty():
		var empty := Label.new()
		empty.text = "No leaderboard data"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_leaderboard_list.add_child(empty)
		return

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	_leaderboard_list.add_child(header)

	var rank_h := Label.new()
	rank_h.text = "Rank"
	rank_h.add_theme_font_size_override("font_size", 13)
	rank_h.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	rank_h.custom_minimum_size = Vector2(50, 0)
	header.add_child(rank_h)

	var name_h := Label.new()
	name_h.text = "Player"
	name_h.add_theme_font_size_override("font_size", 13)
	name_h.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	name_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_h)

	var score_h := Label.new()
	score_h.text = "Items"
	score_h.add_theme_font_size_override("font_size", 13)
	score_h.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	score_h.custom_minimum_size = Vector2(60, 0)
	header.add_child(score_h)

	# Entries
	for i in range(_leaderboard.size()):
		var entry: Dictionary = _leaderboard[i]
		var rank: int = entry.get("rank", i + 1)
		var player_name: String = entry.get("displayName", "Unknown")
		var items_count: int = entry.get("itemsCollected", 0)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		# Rank with medal colors for top 3
		var rank_label := Label.new()
		rank_label.text = "#%d" % rank
		rank_label.add_theme_font_size_override("font_size", 14)
		rank_label.custom_minimum_size = Vector2(50, 0)
		match rank:
			1: rank_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			2: rank_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
			3: rank_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
			_: rank_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(rank_label)

		var name_label := Label.new()
		name_label.text = player_name
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var score_label := Label.new()
		score_label.text = str(items_count)
		score_label.add_theme_font_size_override("font_size", 14)
		score_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
		score_label.custom_minimum_size = Vector2(60, 0)
		row.add_child(score_label)

		_leaderboard_list.add_child(row)
