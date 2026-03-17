class_name AchievementsPanel extends Control

var main
var _tab_bar: TabBar
var _content_stack: Control

# Achievement grid tab
var _category_filter: OptionButton
var _achievement_grid: VBoxContainer
var _xp_label: Label
var _level_label: Label

# Challenges tab
var _daily_section: VBoxContainer
var _weekly_section: VBoxContainer
var _daily_timer_label: Label
var _weekly_timer_label: Label
var _challenge_refresh_timer: float = 0.0
var _daily_expiry_time: float = 0.0
var _weekly_expiry_time: float = 0.0

# Leaderboard tab
var _leaderboard_category: OptionButton
var _leaderboard_list: VBoxContainer
var _leaderboard_count_select: OptionButton

# Titles tab
var _titles_list: VBoxContainer
var _active_title_label: Label

const CATEGORIES := ["All", "Explorer", "Builder", "Social", "Collector", "Warrior"]
const LEADERBOARD_CATEGORIES := ["xp", "builder", "social", "combat", "explorer", "collector"]
const LEADERBOARD_LIMITS := [10, 25, 50]


func init(main_node) -> void:
	main = main_node
	name = "AchievementsPanel"
	visible = false
	_build_ui()


func _build_ui() -> void:
	# Root panel styling
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
	title.text = "Achievements"
	title.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(title)

	# Tab bar
	_tab_bar = TabBar.new()
	_tab_bar.add_tab("Achievements")
	_tab_bar.add_tab("Challenges")
	_tab_bar.add_tab("Leaderboard")
	_tab_bar.add_tab("Titles")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	root_vbox.add_child(_tab_bar)

	# Content stack -- one child per tab, we toggle visibility
	_content_stack = Control.new()
	_content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_content_stack)

	_build_achievements_tab()
	_build_challenges_tab()
	_build_leaderboard_tab()
	_build_titles_tab()

	_on_tab_changed(0)


# ── Achievements Tab ─────────────────────────────────────────────────────

func _build_achievements_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "AchievementsTab"
	container.set_anchors_preset(PRESET_FULL_RECT)
	_content_stack.add_child(container)

	# XP / Level row
	var stats_row := HBoxContainer.new()
	container.add_child(stats_row)

	_level_label = Label.new()
	_level_label.text = "Level: --"
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(_level_label)

	_xp_label = Label.new()
	_xp_label.text = "XP: --"
	_xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(_xp_label)

	# Category filter
	var filter_row := HBoxContainer.new()
	container.add_child(filter_row)
	var filter_lbl := Label.new()
	filter_lbl.text = "Category:"
	filter_row.add_child(filter_lbl)

	_category_filter = OptionButton.new()
	for cat in CATEGORIES:
		_category_filter.add_item(cat)
	_category_filter.item_selected.connect(_on_category_changed)
	filter_row.add_child(_category_filter)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_achievements)
	filter_row.add_child(refresh_btn)

	# Scrollable achievement grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	container.add_child(scroll)

	_achievement_grid = VBoxContainer.new()
	_achievement_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_achievement_grid)


# ── Challenges Tab ───────────────────────────────────────────────────────

func _build_challenges_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "ChallengesTab"
	container.set_anchors_preset(PRESET_FULL_RECT)
	_content_stack.add_child(container)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Challenges"
	refresh_btn.pressed.connect(_refresh_challenges)
	container.add_child(refresh_btn)

	# Daily
	var daily_header := HBoxContainer.new()
	container.add_child(daily_header)
	var daily_lbl := Label.new()
	daily_lbl.text = "Daily Challenges"
	daily_lbl.add_theme_font_size_override("font_size", 16)
	daily_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	daily_header.add_child(daily_lbl)
	_daily_timer_label = Label.new()
	_daily_timer_label.text = "Resets in: --:--:--"
	daily_header.add_child(_daily_timer_label)

	var daily_scroll := ScrollContainer.new()
	daily_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	daily_scroll.custom_minimum_size = Vector2(0, 140)
	container.add_child(daily_scroll)
	_daily_section = VBoxContainer.new()
	_daily_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	daily_scroll.add_child(_daily_section)

	# Weekly
	var weekly_header := HBoxContainer.new()
	container.add_child(weekly_header)
	var weekly_lbl := Label.new()
	weekly_lbl.text = "Weekly Challenges"
	weekly_lbl.add_theme_font_size_override("font_size", 16)
	weekly_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weekly_header.add_child(weekly_lbl)
	_weekly_timer_label = Label.new()
	_weekly_timer_label.text = "Resets in: --:--:--"
	weekly_header.add_child(_weekly_timer_label)

	var weekly_scroll := ScrollContainer.new()
	weekly_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weekly_scroll.custom_minimum_size = Vector2(0, 140)
	container.add_child(weekly_scroll)
	_weekly_section = VBoxContainer.new()
	_weekly_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weekly_scroll.add_child(_weekly_section)


# ── Leaderboard Tab ──────────────────────────────────────────────────────

func _build_leaderboard_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "LeaderboardTab"
	container.set_anchors_preset(PRESET_FULL_RECT)
	_content_stack.add_child(container)

	var filter_row := HBoxContainer.new()
	container.add_child(filter_row)

	var cat_lbl := Label.new()
	cat_lbl.text = "Category:"
	filter_row.add_child(cat_lbl)

	_leaderboard_category = OptionButton.new()
	for cat in LEADERBOARD_CATEGORIES:
		_leaderboard_category.add_item(cat.capitalize())
	filter_row.add_child(_leaderboard_category)

	var count_lbl := Label.new()
	count_lbl.text = "  Show:"
	filter_row.add_child(count_lbl)

	_leaderboard_count_select = OptionButton.new()
	for n in LEADERBOARD_LIMITS:
		_leaderboard_count_select.add_item("Top %d" % n)
	filter_row.add_child(_leaderboard_count_select)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_refresh_leaderboard)
	filter_row.add_child(load_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	container.add_child(scroll)

	_leaderboard_list = VBoxContainer.new()
	_leaderboard_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_leaderboard_list)


# ── Titles Tab ───────────────────────────────────────────────────────────

func _build_titles_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "TitlesTab"
	container.set_anchors_preset(PRESET_FULL_RECT)
	_content_stack.add_child(container)

	_active_title_label = Label.new()
	_active_title_label.text = "Active Title: --"
	_active_title_label.add_theme_font_size_override("font_size", 16)
	container.add_child(_active_title_label)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Titles"
	refresh_btn.pressed.connect(_refresh_titles)
	container.add_child(refresh_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	container.add_child(scroll)

	_titles_list = VBoxContainer.new()
	_titles_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_titles_list)


# ── Tab Switching ────────────────────────────────────────────────────────

func _on_tab_changed(index: int) -> void:
	for i in _content_stack.get_child_count():
		_content_stack.get_child(i).visible = (i == index)
	# Auto-load data when switching
	match index:
		0: _refresh_achievements()
		1: _refresh_challenges()
		2: _refresh_leaderboard()
		3: _refresh_titles()


# ── Data Loading ─────────────────────────────────────────────────────────

func _refresh_achievements() -> void:
	if main == null or main.achievement_mgr == null:
		return
	main.achievement_mgr.load_achievements()
	main.achievement_mgr.load_progress()
	# Wait a short time for HTTP responses, then render
	await main.get_tree().create_timer(0.5).timeout
	_render_achievements()


func _refresh_challenges() -> void:
	if main == null or main.achievement_mgr == null:
		return
	main.achievement_mgr.load_challenges()
	await main.get_tree().create_timer(0.5).timeout
	_render_challenges()


func _refresh_leaderboard() -> void:
	if main == null or main.achievement_mgr == null:
		return
	var cat_index: int = _leaderboard_category.selected if _leaderboard_category != null else 0
	var category: String = LEADERBOARD_CATEGORIES[cat_index] if cat_index >= 0 and cat_index < LEADERBOARD_CATEGORIES.size() else ""
	main.achievement_mgr.load_leaderboard(category)
	await main.get_tree().create_timer(0.5).timeout
	_render_leaderboard()


func _refresh_titles() -> void:
	if main == null or main.achievement_mgr == null:
		return
	main.achievement_mgr.load_titles()
	main.achievement_mgr.load_progress()
	await main.get_tree().create_timer(0.5).timeout
	_render_titles()


# ── Rendering ────────────────────────────────────────────────────────────

func _render_achievements() -> void:
	# Clear grid
	for child in _achievement_grid.get_children():
		child.queue_free()

	var mgr = main.achievement_mgr
	var progress = mgr.player_progress
	var unlocked: Array = progress.get("unlockedAchievements", [])
	var counters: Dictionary = progress.get("counters", {})

	# Update stats
	_level_label.text = "Level: %d" % int(progress.get("level", 1))
	_xp_label.text = "XP: %d" % int(progress.get("xp", 0))

	# Filter by category
	var selected_cat: String = CATEGORIES[_category_filter.selected] if _category_filter.selected >= 0 else "All"

	for ach in mgr.achievements:
		var cat: String = ach.get("category", "")
		if selected_cat != "All" and cat.to_lower() != selected_cat.to_lower():
			continue

		var ach_id: String = ach.get("id", "")
		var is_unlocked: bool = unlocked.has(ach_id)
		var current: int = int(counters.get(ach.get("counter", ""), 0))
		var required: int = int(ach.get("threshold", 1))
		var xp_reward: int = int(ach.get("xp", 0))

		_add_achievement_card(ach, is_unlocked, current, required, xp_reward)


func _add_achievement_card(ach: Dictionary, is_unlocked: bool, current: int, required: int, xp_reward: int) -> void:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.2, 0.3, 0.2, 0.9) if is_unlocked else Color(0.15, 0.15, 0.15, 0.9)
	card_style.set_corner_radius_all(6)
	card_style.content_margin_left = 8
	card_style.content_margin_right = 8
	card_style.content_margin_top = 6
	card_style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", card_style)
	_achievement_grid.add_child(card)

	var hbox := HBoxContainer.new()
	card.add_child(hbox)

	# Status icon
	var status_icon := Label.new()
	if is_unlocked:
		status_icon.text = "[OK]"
		status_icon.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_icon.text = "[  ]"
		status_icon.add_theme_color_override("font_color", Color.GRAY)
	status_icon.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(status_icon)

	# Info column
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = ach.get("name", "Unknown")
	if not is_unlocked:
		name_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = ach.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(desc_lbl)

	# Progress bar
	var progress_bar := ProgressBar.new()
	progress_bar.max_value = required
	progress_bar.value = mini(current, required)
	progress_bar.custom_minimum_size = Vector2(0, 16)
	progress_bar.show_percentage = false
	info_vbox.add_child(progress_bar)

	var progress_lbl := Label.new()
	progress_lbl.text = "%d / %d" % [mini(current, required), required]
	progress_lbl.add_theme_font_size_override("font_size", 11)
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_vbox.add_child(progress_lbl)

	# XP reward
	var xp_lbl := Label.new()
	xp_lbl.text = "+%d XP" % xp_reward
	xp_lbl.add_theme_color_override("font_color", Color.YELLOW)
	xp_lbl.custom_minimum_size = Vector2(70, 0)
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(xp_lbl)


func _render_challenges() -> void:
	# Clear
	for child in _daily_section.get_children():
		child.queue_free()
	for child in _weekly_section.get_children():
		child.queue_free()

	var mgr = main.achievement_mgr

	if mgr.daily_challenges.is_empty():
		var lbl := Label.new()
		lbl.text = "No daily challenges available."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_daily_section.add_child(lbl)
	else:
		for ch in mgr.daily_challenges:
			_add_challenge_card(_daily_section, ch)
		# Track expiry for countdown
		if mgr.daily_challenges.size() > 0:
			var expires = mgr.daily_challenges[0].get("expiresAt", "")
			_daily_expiry_time = _parse_iso_to_unix(expires)

	if mgr.weekly_challenges.is_empty():
		var lbl := Label.new()
		lbl.text = "No weekly challenges available."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_weekly_section.add_child(lbl)
	else:
		for ch in mgr.weekly_challenges:
			_add_challenge_card(_weekly_section, ch)
		if mgr.weekly_challenges.size() > 0:
			var expires = mgr.weekly_challenges[0].get("expiresAt", "")
			_weekly_expiry_time = _parse_iso_to_unix(expires)


func _add_challenge_card(parent: VBoxContainer, challenge: Dictionary) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var completed: bool = challenge.get("completed", false)
	style.bg_color = Color(0.15, 0.25, 0.15, 0.9) if completed else Color(0.18, 0.18, 0.22, 0.9)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var desc_lbl := Label.new()
	desc_lbl.text = challenge.get("description", "Challenge")
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if completed:
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	top_row.add_child(desc_lbl)

	var status_lbl := Label.new()
	status_lbl.text = "[DONE]" if completed else ""
	status_lbl.add_theme_color_override("font_color", Color.GREEN)
	top_row.add_child(status_lbl)

	var xp_lbl := Label.new()
	xp_lbl.text = "+%d XP" % int(challenge.get("xp", 0))
	xp_lbl.add_theme_color_override("font_color", Color.YELLOW)
	top_row.add_child(xp_lbl)

	# Progress bar
	var current: int = int(challenge.get("current", 0))
	var required: int = int(challenge.get("required", 1))
	var bar := ProgressBar.new()
	bar.max_value = required
	bar.value = mini(current, required)
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	vbox.add_child(bar)

	var prog_lbl := Label.new()
	prog_lbl.text = "%d / %d" % [mini(current, required), required]
	prog_lbl.add_theme_font_size_override("font_size", 11)
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(prog_lbl)


func _render_leaderboard() -> void:
	for child in _leaderboard_list.get_children():
		child.queue_free()

	var mgr = main.achievement_mgr
	if mgr.leaderboard.is_empty():
		var lbl := Label.new()
		lbl.text = "No leaderboard data."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_leaderboard_list.add_child(lbl)
		return

	# Header row
	var header := HBoxContainer.new()
	_leaderboard_list.add_child(header)
	for col_name in ["Rank", "Player", "Level", "XP", "Title"]:
		var lbl := Label.new()
		lbl.text = col_name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
		header.add_child(lbl)

	var sep := HSeparator.new()
	_leaderboard_list.add_child(sep)

	var my_account_id: String = main.session.get("accountId", "")
	var rank := 1

	for entry in mgr.leaderboard:
		var account_id: String = str(entry.get("accountId", "???"))
		var display_name: String = str(entry.get("displayName", account_id.substr(0, 8)))
		var level: int = int(entry.get("level", 1))
		var xp: int = int(entry.get("xp", 0))
		var title_str: String = str(entry.get("title", ""))

		var row := HBoxContainer.new()
		var is_me: bool = account_id == my_account_id

		# Special styling for top 3 and current player
		var row_color := Color.WHITE
		if rank == 1:
			row_color = Color(1.0, 0.84, 0.0)  # Gold
		elif rank == 2:
			row_color = Color(0.75, 0.75, 0.75)  # Silver
		elif rank == 3:
			row_color = Color(0.8, 0.5, 0.2)  # Bronze
		if is_me:
			row_color = Color(0.4, 0.8, 1.0)  # Highlight

		var rank_lbl := Label.new()
		rank_lbl.text = "#%d" % rank
		rank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rank_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = display_name + (" (You)" if is_me else "")
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(name_lbl)

		var lvl_lbl := Label.new()
		lvl_lbl.text = str(level)
		lvl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lvl_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(lvl_lbl)

		var xp_lbl := Label.new()
		xp_lbl.text = str(xp)
		xp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(xp_lbl)

		var title_lbl := Label.new()
		title_lbl.text = title_str
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.add_theme_color_override("font_color", row_color)
		row.add_child(title_lbl)

		_leaderboard_list.add_child(row)
		rank += 1


func _render_titles() -> void:
	for child in _titles_list.get_children():
		child.queue_free()

	var mgr = main.achievement_mgr
	var progress = mgr.player_progress
	var active_title: String = str(progress.get("title", ""))
	_active_title_label.text = "Active Title: %s" % (active_title if not active_title.is_empty() else "None")

	if mgr.available_titles.is_empty():
		var lbl := Label.new()
		lbl.text = "No titles unlocked yet."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_titles_list.add_child(lbl)
		return

	for title_name in mgr.available_titles:
		var is_active: bool = (title_name == active_title)

		var row := HBoxContainer.new()
		_titles_list.add_child(row)

		var title_lbl := Label.new()
		title_lbl.text = title_name
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_active:
			title_lbl.add_theme_color_override("font_color", Color.GREEN)
		row.add_child(title_lbl)

		if is_active:
			var equipped_lbl := Label.new()
			equipped_lbl.text = "(Active)"
			equipped_lbl.add_theme_color_override("font_color", Color.GREEN)
			row.add_child(equipped_lbl)
		else:
			var equip_btn := Button.new()
			equip_btn.text = "Set Active"
			equip_btn.custom_minimum_size = Vector2(90, 0)
			var captured_title: String = title_name
			equip_btn.pressed.connect(func(): _set_active_title(captured_title))
			row.add_child(equip_btn)


# ── Actions ──────────────────────────────────────────────────────────────

func _on_category_changed(_index: int) -> void:
	_render_achievements()


func _set_active_title(title_name: String) -> void:
	if main == null or main.achievement_mgr == null:
		return
	main.achievement_mgr.set_title(title_name)
	await main.get_tree().create_timer(0.5).timeout
	_refresh_titles()


# ── Timer Countdown (call from _process in parent) ──────────────────────

func update_timers(delta: float) -> void:
	if not visible:
		return
	if _tab_bar == null or _tab_bar.current_tab != 1:
		return
	_challenge_refresh_timer += delta
	if _challenge_refresh_timer < 1.0:
		return
	_challenge_refresh_timer = 0.0

	var now := Time.get_unix_time_from_system()
	if _daily_expiry_time > 0:
		var remaining := _daily_expiry_time - now
		if remaining > 0:
			_daily_timer_label.text = "Resets in: %s" % _format_duration(remaining)
		else:
			_daily_timer_label.text = "Resets in: Refreshing..."
			_daily_expiry_time = 0.0
			_refresh_challenges()

	if _weekly_expiry_time > 0:
		var remaining := _weekly_expiry_time - now
		if remaining > 0:
			_weekly_timer_label.text = "Resets in: %s" % _format_duration(remaining)
		else:
			_weekly_timer_label.text = "Resets in: Refreshing..."
			_weekly_expiry_time = 0.0
			_refresh_challenges()


# ── Helpers ──────────────────────────────────────────────────────────────

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


func _format_duration(seconds: float) -> String:
	var total := int(seconds)
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	return "%02d:%02d:%02d" % [h, m, s]


func _parse_iso_to_unix(iso_string: String) -> float:
	# Parse an ISO 8601 datetime string to Unix timestamp
	# Expected format: "2026-03-11T23:59:59Z" or similar
	if iso_string.is_empty():
		return 0.0
	# Strip trailing Z and split
	var cleaned := iso_string.replace("Z", "").replace("z", "")
	var dt_parts := cleaned.split("T")
	if dt_parts.size() < 2:
		return 0.0
	var date_parts := dt_parts[0].split("-")
	var time_parts := dt_parts[1].split(":")
	if date_parts.size() < 3 or time_parts.size() < 3:
		return 0.0
	var dt := {
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": int(float(time_parts[2]))
	}
	return Time.get_unix_time_from_datetime_dict(dt)
