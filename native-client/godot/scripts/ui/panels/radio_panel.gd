class_name RadioPanel
extends Control

## Radio station picker panel for VibeLife.
## Station list with genre labels, now-playing display, skip, and volume slider.

var main  # reference to main node

# HTTP request nodes
var _stations_request: HTTPRequest

# State
var _stations: Array = []
var _current_station_id := ""

# UI references
var _station_list_scroll: ScrollContainer
var _station_list_vbox: VBoxContainer
var _now_playing_label: Label
var _station_name_label: Label
var _track_name_label: Label
var _skip_btn: Button
var _volume_slider: HSlider
var _volume_label: Label
var _status_label: Label
var _station_buttons: Array = []  # Array of {button: Button, id: String}


func init(main_node) -> void:
	main = main_node
	name = "RadioPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Add to existing CanvasLayer
	var canvas_layer = main.get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(self)

	# Create HTTP request nodes
	_stations_request = HTTPRequest.new()
	_stations_request.name = "RadioStationsRequest"
	main.add_child(_stations_request)
	_stations_request.request_completed.connect(_on_stations_loaded)

	_build_ui()


func _base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.08, 0.12, 0.95)
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

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "Radio"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	# Now Playing section
	var np_container := VBoxContainer.new()
	np_container.add_theme_constant_override("separation", 4)
	root_vbox.add_child(np_container)

	# Now playing background
	var np_bg := PanelContainer.new()
	np_bg.custom_minimum_size = Vector2(0, 80)
	var np_style := StyleBoxFlat.new()
	np_style.bg_color = Color(0.12, 0.12, 0.18)
	np_style.corner_radius_top_left = 6
	np_style.corner_radius_top_right = 6
	np_style.corner_radius_bottom_left = 6
	np_style.corner_radius_bottom_right = 6
	np_style.content_margin_left = 12
	np_style.content_margin_right = 12
	np_style.content_margin_top = 8
	np_style.content_margin_bottom = 8
	np_bg.add_theme_stylebox_override("panel", np_style)
	np_container.add_child(np_bg)

	var np_vbox := VBoxContainer.new()
	np_vbox.add_theme_constant_override("separation", 4)
	np_bg.add_child(np_vbox)

	_now_playing_label = Label.new()
	_now_playing_label.text = "NOW PLAYING"
	_now_playing_label.add_theme_font_size_override("font_size", 11)
	_now_playing_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	np_vbox.add_child(_now_playing_label)

	_station_name_label = Label.new()
	_station_name_label.text = "No Station"
	_station_name_label.add_theme_font_size_override("font_size", 18)
	_station_name_label.add_theme_color_override("font_color", Color.WHITE)
	np_vbox.add_child(_station_name_label)

	_track_name_label = Label.new()
	_track_name_label.text = "---"
	_track_name_label.add_theme_font_size_override("font_size", 14)
	_track_name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_track_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	np_vbox.add_child(_track_name_label)

	# Controls row: skip + volume
	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 12)
	root_vbox.add_child(controls_row)

	_skip_btn = Button.new()
	_skip_btn.text = ">> Skip"
	_skip_btn.custom_minimum_size = Vector2(80, 32)
	_skip_btn.pressed.connect(_on_skip_pressed)
	controls_row.add_child(_skip_btn)

	var vol_label := Label.new()
	vol_label.text = "Vol:"
	vol_label.add_theme_font_size_override("font_size", 13)
	vol_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	controls_row.add_child(vol_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = 0.8
	_volume_slider.custom_minimum_size = Vector2(120, 20)
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.value_changed.connect(_on_volume_changed)
	controls_row.add_child(_volume_slider)

	_volume_label = Label.new()
	_volume_label.text = "80%"
	_volume_label.add_theme_font_size_override("font_size", 12)
	_volume_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_volume_label.custom_minimum_size = Vector2(40, 0)
	controls_row.add_child(_volume_label)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	root_vbox.add_child(_status_label)

	# Separator label
	var stations_header := Label.new()
	stations_header.text = "Stations"
	stations_header.add_theme_font_size_override("font_size", 16)
	stations_header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	root_vbox.add_child(stations_header)

	# Station list (scrollable)
	_station_list_scroll = ScrollContainer.new()
	_station_list_scroll.name = "StationListScroll"
	_station_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_station_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_station_list_scroll)

	_station_list_vbox = VBoxContainer.new()
	_station_list_vbox.name = "StationListVBox"
	_station_list_vbox.add_theme_constant_override("separation", 6)
	_station_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_station_list_scroll.add_child(_station_list_vbox)


# ── Panel Visibility ─────────────────────────────────────────────────────────

func show_panel() -> void:
	visible = true
	_load_stations()
	_update_now_playing()


# ── Data Loading ─────────────────────────────────────────────────────────────

func _load_stations() -> void:
	_status_label.text = "Loading stations..."
	var url := "%s/api/radio/stations" % _base_url()
	_stations_request.request(url, [], HTTPClient.METHOD_GET)


func _on_stations_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_status_label.text = "Failed to load stations"
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	_stations = json.get("stations", [])

	# Also update the radio controller's station list
	if main.radio:
		main.radio.set_stations(_stations)

	_status_label.text = "%d stations available" % _stations.size()
	_render_station_list()


# ── Station List Rendering ───────────────────────────────────────────────────

func _render_station_list() -> void:
	# Clear existing
	for child in _station_list_vbox.get_children():
		child.queue_free()
	_station_buttons.clear()

	_current_station_id = ""
	if main.radio:
		_current_station_id = main.radio.current_station_id

	for station in _stations:
		var station_id: String = station.get("id", "")
		var station_name: String = station.get("name", "Unknown")
		var genre: String = station.get("genre", "")
		var track_count: int = station.get("tracks", []).size()
		var is_current := (station_id == _current_station_id)

		# Station row
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 40)

		# Station row background
		var row_bg := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		if is_current:
			row_style.bg_color = Color(0.15, 0.25, 0.15)
		else:
			row_style.bg_color = Color(0.12, 0.12, 0.15)
		row_style.corner_radius_top_left = 4
		row_style.corner_radius_top_right = 4
		row_style.corner_radius_bottom_left = 4
		row_style.corner_radius_bottom_right = 4
		row_style.content_margin_left = 8
		row_style.content_margin_right = 8
		row_style.content_margin_top = 4
		row_style.content_margin_bottom = 4
		row_bg.add_theme_stylebox_override("panel", row_style)
		row_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var inner_row := HBoxContainer.new()
		inner_row.add_theme_constant_override("separation", 8)
		row_bg.add_child(inner_row)

		# Station name
		var name_label := Label.new()
		name_label.text = station_name
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color.WHITE if is_current else Color(0.85, 0.85, 0.85))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner_row.add_child(name_label)

		# Genre badge
		if not genre.is_empty():
			var genre_label := Label.new()
			genre_label.text = "[%s]" % genre
			genre_label.add_theme_font_size_override("font_size", 11)
			genre_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
			inner_row.add_child(genre_label)

		# Track count
		var count_label := Label.new()
		count_label.text = "%d tracks" % track_count
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		inner_row.add_child(count_label)

		# Currently playing indicator
		if is_current:
			var playing_label := Label.new()
			playing_label.text = ">> Playing"
			playing_label.add_theme_font_size_override("font_size", 11)
			playing_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			inner_row.add_child(playing_label)

		# Tune button
		var tune_btn := Button.new()
		tune_btn.text = "Tune" if not is_current else "Tuned"
		tune_btn.custom_minimum_size = Vector2(60, 28)
		tune_btn.disabled = is_current
		var sid := station_id
		tune_btn.pressed.connect(func(): _on_tune_pressed(sid))
		inner_row.add_child(tune_btn)

		_station_list_vbox.add_child(row_bg)
		_station_buttons.append({"button": tune_btn, "id": station_id})


# ── Now Playing Update ───────────────────────────────────────────────────────

func _update_now_playing() -> void:
	if main.radio:
		_station_name_label.text = main.radio.current_station_name if not main.radio.current_station_name.is_empty() else "No Station"
		_track_name_label.text = main.radio.current_track_name if not main.radio.current_track_name.is_empty() else "---"
	else:
		_station_name_label.text = "No Station"
		_track_name_label.text = "---"


func on_radio_changed(message: Dictionary) -> void:
	## Called when the radio:changed WS event arrives. Updates the panel display.
	if main.radio:
		main.radio.handle_radio_changed(message)
	_update_now_playing()

	# Re-highlight the current station in the list
	_current_station_id = message.get("stationId", "")
	if visible:
		_render_station_list()


# ── Actions ──────────────────────────────────────────────────────────────────

func _on_tune_pressed(station_id: String) -> void:
	if main.radio:
		main.radio.tune_station(station_id)
	_current_station_id = station_id
	_status_label.text = "Tuning..."
	# Optimistically update now-playing from local station data
	for station in _stations:
		if station.get("id", "") == station_id:
			_station_name_label.text = station.get("name", "Unknown")
			var tracks: Array = station.get("tracks", [])
			var current_idx: int = station.get("currentTrack", 0)
			if current_idx < tracks.size():
				_track_name_label.text = str(tracks[current_idx])
			break
	_render_station_list()


func _on_skip_pressed() -> void:
	if main.radio:
		main.radio.skip_track()
	_status_label.text = "Skipping..."


func _on_volume_changed(value: float) -> void:
	_volume_label.text = "%d%%" % int(value * 100.0)
	# Apply volume to any AudioStreamPlayer nodes used for radio playback
	var db_value := linear_to_db(value)
	var radio_player := main.get_node_or_null("RadioPlayer") as AudioStreamPlayer
	if radio_player:
		radio_player.volume_db = db_value
