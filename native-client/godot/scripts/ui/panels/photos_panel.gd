class_name PhotosPanel
extends Control

## Photography gallery panel for VibeLife.
## Sub-tabs: My Photos, Feed, Featured.
## Photo detail view with likes, comments, and camera mode toggle.

var main  # reference to main node

# HTTP request nodes
var _photos_request: HTTPRequest
var _feed_request: HTTPRequest
var _featured_request: HTTPRequest
var _detail_request: HTTPRequest
var _like_request: HTTPRequest
var _comment_request: HTTPRequest
var _delete_request: HTTPRequest

# State
var _current_tab := 0  # 0=My Photos, 1=Feed, 2=Featured
var _photos: Array = []
var _feed_photos: Array = []
var _featured_photos: Array = []
var _detail_photo: Dictionary = {}
var _showing_detail := false

# UI references
var _tab_buttons: Array = []  # [Button, Button, Button]
var _grid_scroll: ScrollContainer
var _grid_container: GridContainer
var _detail_panel: VBoxContainer
var _detail_title: Label
var _detail_desc: Label
var _detail_photographer: Label
var _detail_filter_badge: Label
var _detail_likes_btn: Button
var _detail_likes_count: Label
var _detail_comments_scroll: ScrollContainer
var _detail_comments_list: VBoxContainer
var _detail_comment_input: LineEdit
var _detail_comment_send: Button
var _detail_back_btn: Button
var _detail_delete_btn: Button
var _camera_toggle_btn: Button
var _filter_bar: HBoxContainer
var _status_label: Label

const RARITY_COLORS := {
	"common": Color(0.7, 0.7, 0.7),
	"uncommon": Color(0.3, 0.8, 0.3),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.7, 0.3, 0.9),
	"legendary": Color(1.0, 0.7, 0.1),
}

const FILTER_NAMES := ["none", "vintage", "noir", "warm", "cool", "dreamy", "pixel", "posterize"]


func init(main_node) -> void:
	main = main_node
	name = "PhotosPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Add to existing CanvasLayer
	var canvas_layer = main.get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(self)

	# Create HTTP request nodes
	_photos_request = _make_http("PhotosMyRequest", _on_my_photos_loaded)
	_feed_request = _make_http("PhotosFeedRequest", _on_feed_loaded)
	_featured_request = _make_http("PhotosFeaturedRequest", _on_featured_loaded)
	_detail_request = _make_http("PhotosDetailRequest", _on_detail_loaded)
	_like_request = _make_http("PhotosLikeRequest", _on_like_response)
	_comment_request = _make_http("PhotosCommentRequest", _on_comment_response)
	_delete_request = _make_http("PhotosDeleteRequest", _on_delete_response)

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
	# Dark background panel
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.1, 0.1, 0.12, 0.95)
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

	# Header row: title + close + camera toggle
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "Photos"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_camera_toggle_btn = Button.new()
	_camera_toggle_btn.text = "[C] Camera Mode"
	_camera_toggle_btn.custom_minimum_size = Vector2(150, 32)
	_camera_toggle_btn.pressed.connect(_on_camera_toggle)
	header.add_child(_camera_toggle_btn)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	# Tab row
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	root_vbox.add_child(tab_row)

	var tab_names := ["My Photos", "Feed", "Featured"]
	for i in range(tab_names.size()):
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(100, 30)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		var idx: int = i
		btn.pressed.connect(func(): _switch_tab(idx))
		tab_row.add_child(btn)
		_tab_buttons.append(btn)

	# Filter bar (for camera mode context, always visible in panel)
	_filter_bar = HBoxContainer.new()
	_filter_bar.name = "FilterBar"
	_filter_bar.add_theme_constant_override("separation", 4)
	root_vbox.add_child(_filter_bar)

	var filter_label := Label.new()
	filter_label.text = "Filters:"
	filter_label.add_theme_font_size_override("font_size", 13)
	filter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_filter_bar.add_child(filter_label)

	for filter_name in FILTER_NAMES:
		var fbtn := Button.new()
		fbtn.text = filter_name.capitalize()
		fbtn.custom_minimum_size = Vector2(70, 26)
		fbtn.add_theme_font_size_override("font_size", 11)
		var fname: String = filter_name
		fbtn.pressed.connect(func(): _apply_filter(fname))
		_filter_bar.add_child(fbtn)

	# Status label
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	root_vbox.add_child(_status_label)

	# Grid view (scrollable photo grid)
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.name = "GridScroll"
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_grid_scroll)

	_grid_container = GridContainer.new()
	_grid_container.name = "GridContainer"
	_grid_container.columns = 4
	_grid_container.add_theme_constant_override("h_separation", 8)
	_grid_container.add_theme_constant_override("v_separation", 8)
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.add_child(_grid_container)

	# Detail view (hidden by default)
	_detail_panel = VBoxContainer.new()
	_detail_panel.name = "DetailPanel"
	_detail_panel.visible = false
	_detail_panel.add_theme_constant_override("separation", 8)
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_detail_panel)

	_build_detail_view()


func _build_detail_view() -> void:
	# Back button
	_detail_back_btn = Button.new()
	_detail_back_btn.text = "< Back to Grid"
	_detail_back_btn.custom_minimum_size = Vector2(120, 28)
	_detail_back_btn.pressed.connect(_close_detail)
	_detail_panel.add_child(_detail_back_btn)

	# Photo placeholder (large)
	var photo_placeholder := ColorRect.new()
	photo_placeholder.name = "PhotoPreview"
	photo_placeholder.color = Color(0.2, 0.2, 0.25)
	photo_placeholder.custom_minimum_size = Vector2(400, 250)
	_detail_panel.add_child(photo_placeholder)

	var preview_label := Label.new()
	preview_label.text = "[Photo Preview]"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	photo_placeholder.add_child(preview_label)

	# Title
	_detail_title = Label.new()
	_detail_title.text = "Photo Title"
	_detail_title.add_theme_font_size_override("font_size", 20)
	_detail_title.add_theme_color_override("font_color", Color.WHITE)
	_detail_panel.add_child(_detail_title)

	# Description
	_detail_desc = Label.new()
	_detail_desc.text = ""
	_detail_desc.add_theme_font_size_override("font_size", 14)
	_detail_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_panel.add_child(_detail_desc)

	# Photographer + filter badge row
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	_detail_panel.add_child(info_row)

	_detail_photographer = Label.new()
	_detail_photographer.text = "by Unknown"
	_detail_photographer.add_theme_font_size_override("font_size", 13)
	_detail_photographer.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	info_row.add_child(_detail_photographer)

	_detail_filter_badge = Label.new()
	_detail_filter_badge.text = ""
	_detail_filter_badge.add_theme_font_size_override("font_size", 12)
	_detail_filter_badge.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	info_row.add_child(_detail_filter_badge)

	# Like row
	var like_row := HBoxContainer.new()
	like_row.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(like_row)

	_detail_likes_btn = Button.new()
	_detail_likes_btn.text = "<3 Like"
	_detail_likes_btn.custom_minimum_size = Vector2(80, 28)
	_detail_likes_btn.pressed.connect(_on_like_pressed)
	like_row.add_child(_detail_likes_btn)

	_detail_likes_count = Label.new()
	_detail_likes_count.text = "0 likes"
	_detail_likes_count.add_theme_font_size_override("font_size", 14)
	_detail_likes_count.add_theme_color_override("font_color", Color(1.0, 0.4, 0.5))
	like_row.add_child(_detail_likes_count)

	_detail_delete_btn = Button.new()
	_detail_delete_btn.text = "Delete"
	_detail_delete_btn.custom_minimum_size = Vector2(80, 28)
	_detail_delete_btn.visible = false
	_detail_delete_btn.pressed.connect(_on_delete_pressed)
	like_row.add_child(_detail_delete_btn)

	# Comments section
	var comments_label := Label.new()
	comments_label.text = "Comments"
	comments_label.add_theme_font_size_override("font_size", 15)
	comments_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_detail_panel.add_child(comments_label)

	_detail_comments_scroll = ScrollContainer.new()
	_detail_comments_scroll.custom_minimum_size = Vector2(0, 120)
	_detail_comments_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(_detail_comments_scroll)

	_detail_comments_list = VBoxContainer.new()
	_detail_comments_list.add_theme_constant_override("separation", 4)
	_detail_comments_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_comments_scroll.add_child(_detail_comments_list)

	# Comment input row
	var comment_row := HBoxContainer.new()
	comment_row.add_theme_constant_override("separation", 6)
	_detail_panel.add_child(comment_row)

	_detail_comment_input = LineEdit.new()
	_detail_comment_input.placeholder_text = "Add a comment..."
	_detail_comment_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_comment_input.custom_minimum_size = Vector2(0, 30)
	_detail_comment_input.text_submitted.connect(func(_t: String): _on_comment_send())
	comment_row.add_child(_detail_comment_input)

	_detail_comment_send = Button.new()
	_detail_comment_send.text = "Send"
	_detail_comment_send.custom_minimum_size = Vector2(60, 30)
	_detail_comment_send.pressed.connect(_on_comment_send)
	comment_row.add_child(_detail_comment_send)


# ── Tab Switching ────────────────────────────────────────────────────────────

func _switch_tab(index: int) -> void:
	_current_tab = index
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].button_pressed = (i == index)

	_close_detail()

	match index:
		0:
			_load_my_photos()
		1:
			_load_feed()
		2:
			_load_featured()


func show_panel() -> void:
	visible = true
	_switch_tab(_current_tab)


# ── Data Loading ─────────────────────────────────────────────────────────────

func _load_my_photos() -> void:
	var token := _token()
	if token.is_empty():
		_status_label.text = "Not logged in"
		return
	var account_id: String = main.session.get("accountId", "")
	if account_id.is_empty():
		_status_label.text = "No account"
		return
	_status_label.text = "Loading photos..."
	var url := "%s/api/photos/gallery/%s?limit=50" % [_base_url(), account_id]
	_photos_request.request(url, [], HTTPClient.METHOD_GET)


func _load_feed() -> void:
	_status_label.text = "Loading feed..."
	var url := "%s/api/photos/feed" % _base_url()
	_feed_request.request(url, [], HTTPClient.METHOD_GET)


func _load_featured() -> void:
	_status_label.text = "Loading featured..."
	var url := "%s/api/photos/featured" % _base_url()
	_featured_request.request(url, [], HTTPClient.METHOD_GET)


func _load_photo_detail(photo_id: String) -> void:
	_status_label.text = "Loading photo..."
	var url := "%s/api/photos/%s" % [_base_url(), photo_id]
	_detail_request.request(url, [], HTTPClient.METHOD_GET)


# ── HTTP Callbacks ───────────────────────────────────────────────────────────

func _on_my_photos_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Failed to load photos"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_photos = json.get("photos", [])
	_status_label.text = "%d photos" % _photos.size()
	_render_grid(_photos)


func _on_feed_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Failed to load feed"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_feed_photos = json.get("photos", [])
	_status_label.text = "%d photos in feed" % _feed_photos.size()
	_render_grid(_feed_photos)


func _on_featured_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Failed to load featured"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_featured_photos = json.get("photos", [])
	_status_label.text = "%d featured photos" % _featured_photos.size()
	_render_grid(_featured_photos)


func _on_detail_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Failed to load photo detail"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_detail_photo = json.get("photo", json)
	_show_detail(_detail_photo)


func _on_like_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Like failed"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	var likes_count: int = json.get("likesCount", 0)
	var liked: bool = json.get("liked", false)
	_detail_likes_count.text = "%d likes" % likes_count
	_detail_likes_btn.text = "</3 Unlike" if liked else "<3 Like"
	_status_label.text = "Liked!" if liked else "Unliked"


func _on_comment_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Comment failed"
		return
	_status_label.text = "Comment added"
	_detail_comment_input.text = ""
	# Refresh detail to show new comment
	var photo_id: String = _detail_photo.get("id", "")
	if not photo_id.is_empty():
		_load_photo_detail(photo_id)


func _on_delete_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Delete failed"
		return
	_status_label.text = "Photo deleted"
	_close_detail()
	# Refresh current tab
	_switch_tab(_current_tab)


# ── Grid Rendering ───────────────────────────────────────────────────────────

func _render_grid(photos: Array) -> void:
	# Clear existing grid items
	for child in _grid_container.get_children():
		child.queue_free()

	if photos.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No photos yet"
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_grid_container.add_child(empty_label)
		return

	for photo in photos:
		var card := _create_photo_card(photo)
		_grid_container.add_child(card)


func _create_photo_card(photo: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(140, 160)
	card.add_theme_constant_override("separation", 4)

	# Thumbnail placeholder
	var thumb := ColorRect.new()
	thumb.color = Color(0.25, 0.25, 0.3)
	thumb.custom_minimum_size = Vector2(140, 105)

	# Filter tint on thumbnail
	var filter_name: String = photo.get("filter", "none")
	if filter_name != "none" and filter_name != "":
		var tint := _get_filter_color(filter_name)
		thumb.color = thumb.color.lerp(tint, 0.3)

	card.add_child(thumb)

	# Thumbnail label overlay
	var thumb_label := Label.new()
	thumb_label.text = "[Photo]"
	thumb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thumb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thumb_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb_label.add_theme_font_size_override("font_size", 11)
	thumb_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	thumb.add_child(thumb_label)

	# Title
	var title_label := Label.new()
	title_label.text = photo.get("title", "Untitled")
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.custom_minimum_size = Vector2(140, 0)
	card.add_child(title_label)

	# Likes count
	var likes: Array = photo.get("likes", [])
	var like_label := Label.new()
	like_label.text = "<3 %d" % likes.size()
	like_label.add_theme_font_size_override("font_size", 11)
	like_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.5))
	card.add_child(like_label)

	# Click handler via a transparent button overlay
	var click_btn := Button.new()
	click_btn.text = ""
	click_btn.flat = true
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var photo_id: String = photo.get("id", "")
	click_btn.pressed.connect(func(): _on_photo_clicked(photo_id))
	thumb.add_child(click_btn)

	return card


# ── Detail View ──────────────────────────────────────────────────────────────

func _on_photo_clicked(photo_id: String) -> void:
	if photo_id.is_empty():
		return
	_load_photo_detail(photo_id)


func _show_detail(photo: Dictionary) -> void:
	_showing_detail = true
	_grid_scroll.visible = false
	_detail_panel.visible = true

	_detail_title.text = photo.get("title", "Untitled")
	_detail_desc.text = photo.get("description", "")
	_detail_photographer.text = "by %s" % photo.get("displayName", photo.get("accountId", "Unknown"))

	var filter_name: String = photo.get("filter", "none")
	if filter_name != "none" and not filter_name.is_empty():
		_detail_filter_badge.text = "Filter: %s" % filter_name.capitalize()
	else:
		_detail_filter_badge.text = ""

	var likes: Array = photo.get("likes", [])
	_detail_likes_count.text = "%d likes" % likes.size()

	# Check if current user liked this photo
	var my_account: String = main.session.get("accountId", "")
	var i_liked := false
	for like_id in likes:
		if str(like_id) == my_account:
			i_liked = true
			break
	_detail_likes_btn.text = "</3 Unlike" if i_liked else "<3 Like"

	# Show delete button only for own photos
	var owner_id: String = photo.get("accountId", "")
	_detail_delete_btn.visible = (owner_id == my_account and not my_account.is_empty())

	# Render comments
	_render_comments(photo.get("comments", []))


func _render_comments(comments: Array) -> void:
	for child in _detail_comments_list.get_children():
		child.queue_free()

	if comments.is_empty():
		var no_comments := Label.new()
		no_comments.text = "No comments yet"
		no_comments.add_theme_font_size_override("font_size", 12)
		no_comments.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_detail_comments_list.add_child(no_comments)
		return

	for comment in comments:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var author := Label.new()
		author.text = "%s:" % comment.get("displayName", "Unknown")
		author.add_theme_font_size_override("font_size", 12)
		author.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		author.custom_minimum_size = Vector2(80, 0)
		row.add_child(author)

		var text := Label.new()
		text.text = comment.get("text", "")
		text.add_theme_font_size_override("font_size", 12)
		text.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)

		_detail_comments_list.add_child(row)


func _close_detail() -> void:
	_showing_detail = false
	_grid_scroll.visible = true
	_detail_panel.visible = false


# ── Actions ──────────────────────────────────────────────────────────────────

func _on_like_pressed() -> void:
	var photo_id: String = _detail_photo.get("id", "")
	if photo_id.is_empty() or _token().is_empty():
		return
	var url := "%s/api/photos/%s/like" % [_base_url(), photo_id]
	var body := JSON.stringify({"token": _token()})
	var headers := PackedStringArray(["Content-Type: application/json"])
	_like_request.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_comment_send() -> void:
	var photo_id: String = _detail_photo.get("id", "")
	var comment_text := _detail_comment_input.text.strip_edges()
	if photo_id.is_empty() or comment_text.is_empty() or _token().is_empty():
		return
	var url := "%s/api/photos/%s/comment" % [_base_url(), photo_id]
	var body := JSON.stringify({"token": _token(), "text": comment_text})
	var headers := PackedStringArray(["Content-Type: application/json"])
	_comment_request.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_delete_pressed() -> void:
	var photo_id: String = _detail_photo.get("id", "")
	if photo_id.is_empty() or _token().is_empty():
		return
	var url := "%s/api/photos/%s?token=%s" % [_base_url(), photo_id, _token()]
	_delete_request.request(url, [], HTTPClient.METHOD_DELETE)


func _on_camera_toggle() -> void:
	if main.camera_mgr:
		if main.camera_mgr.is_camera_mode:
			main.camera_mgr.exit_camera_mode()
			_camera_toggle_btn.text = "[C] Camera Mode"
		else:
			main.camera_mgr.enter_camera_mode()
			_camera_toggle_btn.text = "[C] Exit Camera"
			visible = false  # Hide panel when entering camera mode


func _apply_filter(filter_name: String) -> void:
	if main.camera_mgr:
		main.camera_mgr.set_filter(filter_name)
		_status_label.text = "Filter: %s" % filter_name.capitalize()


func handle_camera_key() -> void:
	## Call from main._unhandled_input when C is pressed to toggle camera mode.
	_on_camera_toggle()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_filter_color(filter_name: String) -> Color:
	match filter_name:
		"vintage": return Color(0.6, 0.4, 0.2)
		"noir": return Color(0.15, 0.15, 0.15)
		"warm": return Color(0.8, 0.4, 0.1)
		"cool": return Color(0.1, 0.3, 0.8)
		"dreamy": return Color(0.8, 0.6, 0.9)
		"pixel": return Color(0.0, 0.5, 0.0)
		"posterize": return Color(0.5, 0.0, 0.5)
		_: return Color(0.25, 0.25, 0.3)
