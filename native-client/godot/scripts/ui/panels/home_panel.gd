class_name HomePanel extends Control

var main
var _tab_bar: TabBar
var _content_stack: Control

# My Home tab
var _home_info_label: Label
var _privacy_select: OptionButton
var _visitor_count_label: Label
var _avg_rating_label: Label

# Featured tab
var _featured_list: VBoxContainer
var _featured_data: Array = []

# Favorites tab
var _favorites_list: VBoxContainer
var _favorites_data: Array = []

# Rating dialog
var _rating_dialog: PanelContainer
var _rating_stars: Array = []  # Array of Button
var _rating_parcel_id: String = ""
var _selected_rating: int = 0
var _rating_avg_label: Label

# HTTP requests
var _favorites_request: HTTPRequest
var _featured_request: HTTPRequest
var _visitors_request: HTTPRequest
var _ratings_request: HTTPRequest

const PRIVACY_OPTIONS := ["public", "friends", "private"]


func init(main_node) -> void:
	main = main_node
	name = "HomePanel"
	visible = false

	_favorites_request = HTTPRequest.new()
	_favorites_request.name = "HomeFavoritesRequest"
	_favorites_request.request_completed.connect(_on_favorites_loaded)
	main.add_child(_favorites_request)

	_featured_request = HTTPRequest.new()
	_featured_request.name = "HomeFeaturedPanelRequest"
	_featured_request.request_completed.connect(_on_featured_loaded)
	main.add_child(_featured_request)

	_visitors_request = HTTPRequest.new()
	_visitors_request.name = "HomeVisitorsRequest"
	_visitors_request.request_completed.connect(_on_visitors_loaded)
	main.add_child(_visitors_request)

	_ratings_request = HTTPRequest.new()
	_ratings_request.name = "HomeRatingsRequest"
	_ratings_request.request_completed.connect(_on_ratings_loaded)
	main.add_child(_ratings_request)

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
	title.text = "Home"
	title.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(title)

	# Tab bar
	_tab_bar = TabBar.new()
	_tab_bar.add_tab("My Home")
	_tab_bar.add_tab("Featured Homes")
	_tab_bar.add_tab("Favorites")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	root_vbox.add_child(_tab_bar)

	_content_stack = Control.new()
	_content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_content_stack)

	_build_my_home_tab()
	_build_featured_tab()
	_build_favorites_tab()
	_build_rating_dialog()

	_on_tab_changed(0)


# ── My Home Tab ──────────────────────────────────────────────────────────

func _build_my_home_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "MyHomeTab"
	container.set_anchors_preset(PRESET_FULL_RECT)
	_content_stack.add_child(container)

	# Home info
	_home_info_label = Label.new()
	_home_info_label.text = "Home: Not set"
	_home_info_label.add_theme_font_size_override("font_size", 15)
	container.add_child(_home_info_label)

	# Stats row
	var stats_row := HBoxContainer.new()
	container.add_child(stats_row)

	_visitor_count_label = Label.new()
	_visitor_count_label.text = "Visitors: --"
	_visitor_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visitor_count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_row.add_child(_visitor_count_label)

	_avg_rating_label = Label.new()
	_avg_rating_label.text = "Rating: --"
	_avg_rating_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	stats_row.add_child(_avg_rating_label)

	var sep1 := HSeparator.new()
	container.add_child(sep1)

	# Action buttons
	var actions_label := Label.new()
	actions_label.text = "Actions"
	actions_label.add_theme_font_size_override("font_size", 15)
	container.add_child(actions_label)

	var action_row := HBoxContainer.new()
	container.add_child(action_row)

	var set_home_btn := Button.new()
	set_home_btn.text = "Set Home"
	set_home_btn.tooltip_text = "Set your current parcel as your home"
	set_home_btn.custom_minimum_size = Vector2(100, 32)
	set_home_btn.pressed.connect(_on_set_home)
	action_row.add_child(set_home_btn)

	var teleport_btn := Button.new()
	teleport_btn.text = "Teleport Home"
	teleport_btn.custom_minimum_size = Vector2(120, 32)
	teleport_btn.pressed.connect(_on_teleport_home)
	action_row.add_child(teleport_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Home"
	clear_btn.custom_minimum_size = Vector2(100, 32)
	clear_btn.pressed.connect(_on_clear_home)
	action_row.add_child(clear_btn)

	var sep2 := HSeparator.new()
	container.add_child(sep2)

	# Privacy
	var privacy_row := HBoxContainer.new()
	container.add_child(privacy_row)

	var privacy_lbl := Label.new()
	privacy_lbl.text = "Privacy:"
	privacy_row.add_child(privacy_lbl)

	_privacy_select = OptionButton.new()
	_privacy_select.add_item("Public")
	_privacy_select.add_item("Friends Only")
	_privacy_select.add_item("Private")
	_privacy_select.item_selected.connect(_on_privacy_changed)
	privacy_row.add_child(_privacy_select)

	var sep3 := HSeparator.new()
	container.add_child(sep3)

	# Refresh button
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Home Info"
	refresh_btn.pressed.connect(_refresh_home_info)
	container.add_child(refresh_btn)


# ── Featured Homes Tab ───────────────────────────────────────────────────

func _build_featured_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "FeaturedTab"
	container.set_anchors_preset(PRESET_FULL_RECT)
	_content_stack.add_child(container)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Featured"
	refresh_btn.pressed.connect(_refresh_featured)
	container.add_child(refresh_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	container.add_child(scroll)

	_featured_list = VBoxContainer.new()
	_featured_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_featured_list)


# ── Favorites Tab ────────────────────────────────────────────────────────

func _build_favorites_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "FavoritesTab"
	container.set_anchors_preset(PRESET_FULL_RECT)
	_content_stack.add_child(container)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Favorites"
	refresh_btn.pressed.connect(_refresh_favorites)
	container.add_child(refresh_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	container.add_child(scroll)

	_favorites_list = VBoxContainer.new()
	_favorites_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_favorites_list)


# ── Rating Dialog ────────────────────────────────────────────────────────

func _build_rating_dialog() -> void:
	_rating_dialog = PanelContainer.new()
	_rating_dialog.name = "RatingDialog"
	_rating_dialog.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.16, 0.98)
	style.set_corner_radius_all(8)
	style.border_color = Color(1.0, 0.84, 0.0, 0.6)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_rating_dialog.add_theme_stylebox_override("panel", style)
	add_child(_rating_dialog)

	var vbox := VBoxContainer.new()
	_rating_dialog.add_child(vbox)

	var header := Label.new()
	header.text = "Rate This Home"
	header.add_theme_font_size_override("font_size", 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	_rating_avg_label = Label.new()
	_rating_avg_label.text = "Current average: --"
	_rating_avg_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_rating_avg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_rating_avg_label)

	# Star buttons row
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(stars_row)

	_rating_stars.clear()
	for i in range(1, 6):
		var star_btn := Button.new()
		star_btn.text = "*"
		star_btn.custom_minimum_size = Vector2(40, 36)
		star_btn.add_theme_font_size_override("font_size", 20)
		var captured_i: int = i
		star_btn.pressed.connect(func(): _set_rating(captured_i))
		stars_row.add_child(star_btn)
		_rating_stars.append(star_btn)

	# Action row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var submit_btn := Button.new()
	submit_btn.text = "Submit Rating"
	submit_btn.custom_minimum_size = Vector2(120, 30)
	submit_btn.pressed.connect(_submit_rating)
	btn_row.add_child(submit_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 30)
	cancel_btn.pressed.connect(func(): _rating_dialog.visible = false)
	btn_row.add_child(cancel_btn)


# ── Tab Switching ────────────────────────────────────────────────────────

func _on_tab_changed(index: int) -> void:
	for i in _content_stack.get_child_count():
		_content_stack.get_child(i).visible = (i == index)
	match index:
		0: _refresh_home_info()
		1: _refresh_featured()
		2: _refresh_favorites()


# ── Data Loading ─────────────────────────────────────────────────────────

func _refresh_home_info() -> void:
	if main == null or main.home_mgr == null:
		return
	main.home_mgr.get_home()
	await main.get_tree().create_timer(0.5).timeout
	# The home_mgr prints to chat; we also try to update UI from session
	_update_home_display()


func _refresh_featured() -> void:
	if main == null:
		return
	var url := "%s/api/homes/featured?limit=10" % _base_url()
	_featured_request.request(url)


func _refresh_favorites() -> void:
	if main == null:
		return
	var token: String = main.session.get("token", "")
	if token.is_empty():
		return
	var url := "%s/api/homes/favorites?token=%s" % [_base_url(), token]
	_favorites_request.request(url)


func _on_featured_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	_featured_data = payload.get("homes", [])
	_render_featured()


func _on_favorites_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	_favorites_data = payload.get("homes", payload.get("favorites", []))
	_render_favorites()


func _on_visitors_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	var count: int = int(payload.get("visitorCount", payload.get("count", 0)))
	_visitor_count_label.text = "Visitors: %d" % count


func _on_ratings_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	var avg: float = float(payload.get("averageRating", 0))
	var total: int = int(payload.get("totalRatings", 0))
	_avg_rating_label.text = "Rating: %.1f (%d)" % [avg, total]
	_rating_avg_label.text = "Current average: %.1f (%d ratings)" % [avg, total]


# ── Rendering ────────────────────────────────────────────────────────────

func _update_home_display() -> void:
	# Try to read from session or a cached value
	# The HomeManager currently logs to chat, so this is best-effort
	_home_info_label.text = "Home: Use 'Refresh Home Info' to check status"


func _render_featured() -> void:
	for child in _featured_list.get_children():
		child.queue_free()

	if _featured_data.is_empty():
		var lbl := Label.new()
		lbl.text = "No featured homes found."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_featured_list.add_child(lbl)
		return

	for home in _featured_data:
		_add_home_card(_featured_list, home, true)


func _render_favorites() -> void:
	for child in _favorites_list.get_children():
		child.queue_free()

	if _favorites_data.is_empty():
		var lbl := Label.new()
		lbl.text = "No favorite homes yet."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_favorites_list.add_child(lbl)
		return

	for home in _favorites_data:
		_add_home_card(_favorites_list, home, false)


func _add_home_card(parent: VBoxContainer, home: Dictionary, show_favorite: bool) -> void:
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

	# Top row: name, owner
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var name_lbl := Label.new()
	name_lbl.text = home.get("parcelName", home.get("name", "Unknown Home"))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	top_row.add_child(name_lbl)

	var owner_lbl := Label.new()
	owner_lbl.text = "by %s" % home.get("ownerDisplayName", home.get("owner", "Unknown"))
	owner_lbl.add_theme_font_size_override("font_size", 12)
	owner_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	top_row.add_child(owner_lbl)

	# Stats row: rating, visitors
	var stats_row := HBoxContainer.new()
	vbox.add_child(stats_row)

	var avg_rating: float = float(home.get("averageRating", 0))
	var star_text := _render_star_text(avg_rating)
	var rating_lbl := Label.new()
	rating_lbl.text = "%s (%.1f)" % [star_text, avg_rating]
	rating_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	rating_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(rating_lbl)

	var visitors: int = int(home.get("visitorCount", home.get("visitors", 0)))
	var visitors_lbl := Label.new()
	visitors_lbl.text = "%d visitors" % visitors
	visitors_lbl.add_theme_font_size_override("font_size", 12)
	visitors_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_row.add_child(visitors_lbl)

	# Action row
	var action_row := HBoxContainer.new()
	vbox.add_child(action_row)

	var parcel_id: String = home.get("parcelId", "")

	var visit_btn := Button.new()
	visit_btn.text = "Visit"
	var captured_parcel: String = parcel_id
	visit_btn.pressed.connect(func(): _visit_home(captured_parcel))
	action_row.add_child(visit_btn)

	var rate_btn := Button.new()
	rate_btn.text = "Rate"
	rate_btn.pressed.connect(func(): _show_rating_dialog(captured_parcel))
	action_row.add_child(rate_btn)

	if show_favorite:
		var fav_btn := Button.new()
		fav_btn.text = "<3 Favorite"
		fav_btn.pressed.connect(func(): _toggle_favorite(captured_parcel))
		action_row.add_child(fav_btn)
	else:
		var unfav_btn := Button.new()
		unfav_btn.text = "Unfavorite"
		unfav_btn.pressed.connect(func(): _toggle_favorite(captured_parcel))
		action_row.add_child(unfav_btn)


# ── Actions ──────────────────────────────────────────────────────────────

func _on_set_home() -> void:
	if main == null or main.home_mgr == null:
		return
	# Determine current parcel from build controller or parcels manager
	var parcel_id: String = ""
	if main.parcels_mgr != null:
		var active_parcel = main.parcels_mgr.get("active_parcel_id")
		if active_parcel != null:
			parcel_id = str(active_parcel)
	if parcel_id.is_empty():
		# Fallback: try to get from session
		parcel_id = main.session.get("parcelId", "")
	if parcel_id.is_empty():
		_append_chat("System: Stand on a parcel to set it as your home.")
		return
	main.home_mgr.set_home(parcel_id)


func _on_teleport_home() -> void:
	if main == null or main.home_mgr == null:
		return
	main.home_mgr.teleport_home()


func _on_clear_home() -> void:
	if main == null or main.home_mgr == null:
		return
	main.home_mgr.clear_home()


func _on_privacy_changed(index: int) -> void:
	if main == null or main.home_mgr == null:
		return
	if index < 0 or index >= PRIVACY_OPTIONS.size():
		return
	main.home_mgr.set_privacy(PRIVACY_OPTIONS[index])


func _visit_home(parcel_id: String) -> void:
	if main == null or main.home_mgr == null:
		return
	# Teleport to someone else's home by visiting the parcel
	# We reuse the teleport mechanism: set the target region and parcel
	_append_chat("System: Visiting home at parcel %s..." % parcel_id)
	# Use a direct REST call if available, otherwise inform user
	var token: String = main.session.get("token", "")
	if token.is_empty():
		return
	var url := "%s/api/homes/teleport" % _base_url()
	var body := JSON.stringify({"token": token, "parcelId": parcel_id})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b):
		http.queue_free()
		_append_chat("System: Teleport request sent.")
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _toggle_favorite(parcel_id: String) -> void:
	if main == null or main.home_rating == null:
		return
	main.home_rating.toggle_favorite(parcel_id)
	await main.get_tree().create_timer(0.5).timeout
	# Refresh the appropriate list
	if _tab_bar.current_tab == 1:
		_refresh_featured()
	elif _tab_bar.current_tab == 2:
		_refresh_favorites()


func _show_rating_dialog(parcel_id: String) -> void:
	_rating_parcel_id = parcel_id
	_selected_rating = 0
	_update_star_display()
	_rating_dialog.visible = true
	# Load current ratings for this parcel
	var url := "%s/api/homes/%s/ratings" % [_base_url(), parcel_id]
	_ratings_request.request(url)


func _set_rating(stars: int) -> void:
	_selected_rating = stars
	_update_star_display()


func _update_star_display() -> void:
	for i in _rating_stars.size():
		var star_btn: Button = _rating_stars[i]
		if i < _selected_rating:
			star_btn.text = "[*]"
			star_btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		else:
			star_btn.text = "[ ]"
			star_btn.remove_theme_color_override("font_color")


func _submit_rating() -> void:
	if _rating_parcel_id.is_empty() or _selected_rating < 1:
		_append_chat("System: Please select a rating (1-5 stars).")
		return
	if main == null or main.home_rating == null:
		return
	main.home_rating.rate_home(_rating_parcel_id, _selected_rating)
	_rating_dialog.visible = false
	_append_chat("System: Rating submitted!")


# ── Helpers ──────────────────────────────────────────────────────────────

func _render_star_text(avg: float) -> String:
	var full := int(avg)
	var result := ""
	for i in range(full):
		result += "*"
	for i in range(5 - full):
		result += "."
	return result


func _base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


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
