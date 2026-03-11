class_name PetsPanel extends Control

var main

# My Pets list
var _pets_list: VBoxContainer
var _pets_scroll: ScrollContainer
var _pets_data: Array = []
var _selected_pet_index: int = -1

# Pet detail view
var _detail_container: VBoxContainer
var _detail_name_label: Label
var _detail_species_label: Label
var _detail_level_label: Label
var _detail_xp_bar: ProgressBar
var _detail_happiness_bar: ProgressBar
var _detail_energy_bar: ProgressBar
var _detail_happiness_label: Label
var _detail_energy_label: Label

# Action buttons
var _summon_btn: Button
var _dismiss_btn: Button
var _feed_btn: Button
var _play_btn: Button
var _pet_btn: Button
var _trick_select: OptionButton
var _trick_btn: Button

# Customization
var _rename_input: LineEdit
var _rename_btn: Button
var _body_color_picker: ColorPickerButton
var _accent_color_picker: ColorPickerButton
var _accessory_select: OptionButton
var _save_customize_btn: Button

# Adopt dialog
var _adopt_dialog: PanelContainer
var _adopt_species_grid: GridContainer
var _adopt_name_input: LineEdit
var _adopt_confirm_btn: Button
var _selected_species: String = ""
var _species_buttons: Dictionary = {}

# HTTP requests
var _list_request: HTTPRequest
var _customize_request: HTTPRequest

const SPECIES := ["cat", "dog", "bird", "bunny", "fox", "dragon", "slime", "owl"]
const TRICKS := ["sit", "jump", "spin", "roll_over", "wave", "play_dead", "fetch", "dance"]
const ACCESSORIES := ["none", "bow", "hat", "scarf", "collar", "wings", "crown"]
const SPECIES_COLORS := {
	"cat": Color(0.9, 0.7, 0.3),
	"dog": Color(0.6, 0.4, 0.2),
	"bird": Color(0.3, 0.7, 0.9),
	"bunny": Color(0.9, 0.85, 0.8),
	"fox": Color(0.9, 0.4, 0.1),
	"dragon": Color(0.4, 0.8, 0.3),
	"slime": Color(0.3, 0.9, 0.5),
	"owl": Color(0.5, 0.4, 0.3)
}


func init(main_node) -> void:
	main = main_node
	name = "PetsPanel"
	visible = false

	_list_request = HTTPRequest.new()
	_list_request.name = "PetsListRequest"
	_list_request.request_completed.connect(_on_pets_loaded)
	main.add_child(_list_request)

	_customize_request = HTTPRequest.new()
	_customize_request.name = "PetCustomizeRequest"
	_customize_request.request_completed.connect(_on_customize_completed)
	main.add_child(_customize_request)

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
	title.text = "Pets"
	title.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(title)

	# Main split: pets list on left, detail on right
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(split)

	# Left side: pet list
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(180, 0)
	split.add_child(left)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_pets)
	left.add_child(refresh_btn)

	_pets_scroll = ScrollContainer.new()
	_pets_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_pets_scroll)

	_pets_list = VBoxContainer.new()
	_pets_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pets_scroll.add_child(_pets_list)

	var adopt_btn := Button.new()
	adopt_btn.text = "Adopt New Pet"
	adopt_btn.custom_minimum_size = Vector2(0, 32)
	adopt_btn.pressed.connect(_show_adopt_dialog)
	left.add_child(adopt_btn)

	# Right side: detail view
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)

	_detail_container = VBoxContainer.new()
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_detail_container)

	_build_detail_view()
	_build_adopt_dialog()

	_detail_container.visible = false
	_adopt_dialog.visible = false


# ── Detail View ──────────────────────────────────────────────────────────

func _build_detail_view() -> void:
	# Pet info
	_detail_name_label = Label.new()
	_detail_name_label.text = "Pet Name"
	_detail_name_label.add_theme_font_size_override("font_size", 18)
	_detail_container.add_child(_detail_name_label)

	_detail_species_label = Label.new()
	_detail_species_label.text = "Species: --"
	_detail_species_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_detail_container.add_child(_detail_species_label)

	_detail_level_label = Label.new()
	_detail_level_label.text = "Level: -- | XP: --"
	_detail_container.add_child(_detail_level_label)

	# XP bar
	var xp_lbl := Label.new()
	xp_lbl.text = "XP:"
	xp_lbl.add_theme_font_size_override("font_size", 12)
	_detail_container.add_child(xp_lbl)
	_detail_xp_bar = ProgressBar.new()
	_detail_xp_bar.custom_minimum_size = Vector2(0, 14)
	_detail_xp_bar.show_percentage = false
	_detail_container.add_child(_detail_xp_bar)

	# Happiness
	var happy_row := HBoxContainer.new()
	_detail_container.add_child(happy_row)
	var happy_lbl := Label.new()
	happy_lbl.text = "Happiness:"
	happy_lbl.add_theme_font_size_override("font_size", 12)
	happy_row.add_child(happy_lbl)
	_detail_happiness_label = Label.new()
	_detail_happiness_label.text = "--"
	_detail_happiness_label.add_theme_font_size_override("font_size", 12)
	happy_row.add_child(_detail_happiness_label)
	_detail_happiness_bar = ProgressBar.new()
	_detail_happiness_bar.max_value = 100
	_detail_happiness_bar.custom_minimum_size = Vector2(0, 14)
	_detail_happiness_bar.show_percentage = false
	_detail_container.add_child(_detail_happiness_bar)

	# Energy
	var energy_row := HBoxContainer.new()
	_detail_container.add_child(energy_row)
	var energy_lbl := Label.new()
	energy_lbl.text = "Energy:"
	energy_lbl.add_theme_font_size_override("font_size", 12)
	energy_row.add_child(energy_lbl)
	_detail_energy_label = Label.new()
	_detail_energy_label.text = "--"
	_detail_energy_label.add_theme_font_size_override("font_size", 12)
	energy_row.add_child(_detail_energy_label)
	_detail_energy_bar = ProgressBar.new()
	_detail_energy_bar.max_value = 100
	_detail_energy_bar.custom_minimum_size = Vector2(0, 14)
	_detail_energy_bar.show_percentage = false
	_detail_container.add_child(_detail_energy_bar)

	var sep1 := HSeparator.new()
	_detail_container.add_child(sep1)

	# Action buttons
	var actions_label := Label.new()
	actions_label.text = "Actions"
	actions_label.add_theme_font_size_override("font_size", 15)
	_detail_container.add_child(actions_label)

	var action_row1 := HBoxContainer.new()
	_detail_container.add_child(action_row1)

	_summon_btn = Button.new()
	_summon_btn.text = "Summon"
	_summon_btn.pressed.connect(_on_summon_pressed)
	action_row1.add_child(_summon_btn)

	_dismiss_btn = Button.new()
	_dismiss_btn.text = "Dismiss"
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	action_row1.add_child(_dismiss_btn)

	_feed_btn = Button.new()
	_feed_btn.text = "Feed"
	_feed_btn.pressed.connect(_on_feed_pressed)
	action_row1.add_child(_feed_btn)

	var action_row2 := HBoxContainer.new()
	_detail_container.add_child(action_row2)

	_play_btn = Button.new()
	_play_btn.text = "Play"
	_play_btn.pressed.connect(_on_play_pressed)
	action_row2.add_child(_play_btn)

	_pet_btn = Button.new()
	_pet_btn.text = "Pet"
	_pet_btn.pressed.connect(_on_pet_pressed)
	action_row2.add_child(_pet_btn)

	# Trick row
	var trick_row := HBoxContainer.new()
	_detail_container.add_child(trick_row)

	_trick_select = OptionButton.new()
	for t in TRICKS:
		_trick_select.add_item(t.replace("_", " ").capitalize())
	_trick_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trick_row.add_child(_trick_select)

	_trick_btn = Button.new()
	_trick_btn.text = "Do Trick"
	_trick_btn.pressed.connect(_on_trick_pressed)
	trick_row.add_child(_trick_btn)

	var sep2 := HSeparator.new()
	_detail_container.add_child(sep2)

	# Customization
	var custom_label := Label.new()
	custom_label.text = "Customize"
	custom_label.add_theme_font_size_override("font_size", 15)
	_detail_container.add_child(custom_label)

	# Rename
	var rename_row := HBoxContainer.new()
	_detail_container.add_child(rename_row)
	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "New name..."
	_rename_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_row.add_child(_rename_input)
	_rename_btn = Button.new()
	_rename_btn.text = "Rename"
	_rename_btn.pressed.connect(_on_rename_pressed)
	rename_row.add_child(_rename_btn)

	# Colors
	var color_row := HBoxContainer.new()
	_detail_container.add_child(color_row)

	var body_lbl := Label.new()
	body_lbl.text = "Body:"
	color_row.add_child(body_lbl)
	_body_color_picker = ColorPickerButton.new()
	_body_color_picker.custom_minimum_size = Vector2(40, 30)
	_body_color_picker.color = Color.ORANGE
	color_row.add_child(_body_color_picker)

	var accent_lbl := Label.new()
	accent_lbl.text = "  Accent:"
	color_row.add_child(accent_lbl)
	_accent_color_picker = ColorPickerButton.new()
	_accent_color_picker.custom_minimum_size = Vector2(40, 30)
	_accent_color_picker.color = Color.RED
	color_row.add_child(_accent_color_picker)

	# Accessory
	var accessory_row := HBoxContainer.new()
	_detail_container.add_child(accessory_row)
	var acc_lbl := Label.new()
	acc_lbl.text = "Accessory:"
	accessory_row.add_child(acc_lbl)
	_accessory_select = OptionButton.new()
	for acc in ACCESSORIES:
		_accessory_select.add_item(acc.capitalize())
	_accessory_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accessory_row.add_child(_accessory_select)

	# Save customization button
	_save_customize_btn = Button.new()
	_save_customize_btn.text = "Save Customization"
	_save_customize_btn.custom_minimum_size = Vector2(0, 30)
	_save_customize_btn.pressed.connect(_on_save_customization)
	_detail_container.add_child(_save_customize_btn)


# ── Adopt Dialog ─────────────────────────────────────────────────────────

func _build_adopt_dialog() -> void:
	_adopt_dialog = PanelContainer.new()
	_adopt_dialog.name = "AdoptDialog"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.16, 0.98)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.4, 0.6, 0.8, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_adopt_dialog.add_theme_stylebox_override("panel", style)
	add_child(_adopt_dialog)

	var vbox := VBoxContainer.new()
	_adopt_dialog.add_child(vbox)

	var header := Label.new()
	header.text = "Adopt a Pet"
	header.add_theme_font_size_override("font_size", 18)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var species_lbl := Label.new()
	species_lbl.text = "Choose a species:"
	vbox.add_child(species_lbl)

	_adopt_species_grid = GridContainer.new()
	_adopt_species_grid.columns = 4
	vbox.add_child(_adopt_species_grid)

	for species in SPECIES:
		var btn := Button.new()
		btn.text = species.capitalize()
		btn.custom_minimum_size = Vector2(80, 40)
		btn.toggle_mode = true
		var captured := species
		btn.pressed.connect(func(): _select_species(captured))
		_adopt_species_grid.add_child(btn)
		_species_buttons[species] = btn

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var name_lbl := Label.new()
	name_lbl.text = "Name your pet:"
	vbox.add_child(name_lbl)

	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	_adopt_name_input = LineEdit.new()
	_adopt_name_input.placeholder_text = "Enter a name..."
	_adopt_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_adopt_name_input)

	var random_btn := Button.new()
	random_btn.text = "Random"
	random_btn.pressed.connect(_generate_random_name)
	name_row.add_child(random_btn)

	var btn_row := HBoxContainer.new()
	vbox.add_child(btn_row)

	_adopt_confirm_btn = Button.new()
	_adopt_confirm_btn.text = "Adopt!"
	_adopt_confirm_btn.custom_minimum_size = Vector2(100, 32)
	_adopt_confirm_btn.pressed.connect(_confirm_adopt)
	btn_row.add_child(_adopt_confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 32)
	cancel_btn.pressed.connect(func(): _adopt_dialog.visible = false)
	btn_row.add_child(cancel_btn)


# ── Data Loading ─────────────────────────────────────────────────────────

func _refresh_pets() -> void:
	if main == null:
		return
	var token: String = main.session.get("token", "")
	if token.is_empty():
		return
	var url := "%s/api/pets?token=%s" % [_base_url(), token]
	_list_request.request(url)


func _on_pets_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	_pets_data = payload.get("pets", [])
	_render_pets_list()


func _on_customize_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_append_chat("System: Pet customization failed.")
		return
	_append_chat("System: Pet customized successfully!")
	_refresh_pets()


# ── Rendering ────────────────────────────────────────────────────────────

func _render_pets_list() -> void:
	for child in _pets_list.get_children():
		child.queue_free()

	if _pets_data.is_empty():
		var lbl := Label.new()
		lbl.text = "No pets yet. Adopt one!"
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_pets_list.add_child(lbl)
		_detail_container.visible = false
		return

	var active_pet_id: String = main.pet_mgr.my_pet_id if main.pet_mgr != null else ""

	for i in _pets_data.size():
		var pet: Dictionary = _pets_data[i]
		var pet_id: String = pet.get("id", "")
		var is_active: bool = (pet_id == active_pet_id)

		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.3, 0.2, 0.9) if is_active else Color(0.15, 0.15, 0.2, 0.9)
		if _selected_pet_index == i:
			style.border_color = Color(0.4, 0.7, 1.0, 0.9)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
		style.set_corner_radius_all(4)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", style)
		_pets_list.add_child(card)

		var hbox := HBoxContainer.new()
		card.add_child(hbox)

		# Species icon (colored square)
		var icon := ColorRect.new()
		icon.color = SPECIES_COLORS.get(pet.get("species", "cat"), Color.GRAY)
		icon.custom_minimum_size = Vector2(24, 24)
		hbox.add_child(icon)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var name_lbl := Label.new()
		var display_text := pet.get("name", "Pet")
		if is_active:
			display_text += " (Active)"
		name_lbl.text = display_text
		name_lbl.add_theme_font_size_override("font_size", 13)
		info_vbox.add_child(name_lbl)

		var species_lbl := Label.new()
		species_lbl.text = "%s | Lv.%d" % [str(pet.get("species", "?")).capitalize(), int(pet.get("level", 1))]
		species_lbl.add_theme_font_size_override("font_size", 11)
		species_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		info_vbox.add_child(species_lbl)

		# Mini happiness/energy bars
		var happy_bar := ProgressBar.new()
		happy_bar.max_value = 100
		happy_bar.value = float(pet.get("happiness", 50))
		happy_bar.custom_minimum_size = Vector2(0, 8)
		happy_bar.show_percentage = false
		info_vbox.add_child(happy_bar)

		var energy_bar := ProgressBar.new()
		energy_bar.max_value = 100
		energy_bar.value = float(pet.get("energy", 50))
		energy_bar.custom_minimum_size = Vector2(0, 8)
		energy_bar.show_percentage = false
		info_vbox.add_child(energy_bar)

		# Make card clickable
		var click_btn := Button.new()
		click_btn.text = ">"
		click_btn.custom_minimum_size = Vector2(24, 0)
		var captured_i := i
		click_btn.pressed.connect(func(): _select_pet(captured_i))
		hbox.add_child(click_btn)

	# Auto-select first if none selected
	if _selected_pet_index >= 0 and _selected_pet_index < _pets_data.size():
		_show_pet_detail(_pets_data[_selected_pet_index])


func _select_pet(index: int) -> void:
	_selected_pet_index = index
	_render_pets_list()
	if index >= 0 and index < _pets_data.size():
		_show_pet_detail(_pets_data[index])


func _show_pet_detail(pet: Dictionary) -> void:
	_detail_container.visible = true

	_detail_name_label.text = pet.get("name", "Pet")
	_detail_species_label.text = "Species: %s" % str(pet.get("species", "unknown")).capitalize()

	var level: int = int(pet.get("level", 1))
	var xp: int = int(pet.get("xp", 0))
	_detail_level_label.text = "Level: %d | XP: %d" % [level, xp]

	# XP bar (approximate -- each level needs level*100 xp)
	var xp_needed: int = level * 100
	_detail_xp_bar.max_value = xp_needed
	_detail_xp_bar.value = xp % xp_needed if xp_needed > 0 else 0

	var happiness: float = float(pet.get("happiness", 50))
	var energy: float = float(pet.get("energy", 50))
	_detail_happiness_bar.value = happiness
	_detail_happiness_label.text = "%d%%" % int(happiness)
	_detail_energy_bar.value = energy
	_detail_energy_label.text = "%d%%" % int(energy)

	# Customization defaults
	_rename_input.text = pet.get("name", "")
	_body_color_picker.color = Color.from_string(pet.get("color", "#f5a623"), Color.ORANGE)
	_accent_color_picker.color = Color.from_string(pet.get("accentColor", "#d0021b"), Color.RED)

	var current_accessory: String = pet.get("accessory", "none")
	for j in ACCESSORIES.size():
		if ACCESSORIES[j] == current_accessory:
			_accessory_select.selected = j
			break

	# Set tricks dropdown based on learned tricks
	var learned_tricks: Array = pet.get("tricks", [])
	_trick_select.clear()
	if learned_tricks.is_empty():
		for t in TRICKS:
			_trick_select.add_item(t.replace("_", " ").capitalize())
	else:
		for t in learned_tricks:
			_trick_select.add_item(str(t).replace("_", " ").capitalize())


# ── Actions ──────────────────────────────────────────────────────────────

func _get_selected_pet_id() -> String:
	if _selected_pet_index < 0 or _selected_pet_index >= _pets_data.size():
		return ""
	return _pets_data[_selected_pet_index].get("id", "")


func _on_summon_pressed() -> void:
	var pet_id := _get_selected_pet_id()
	if pet_id.is_empty() or main.pet_mgr == null:
		return
	main.pet_mgr.summon_pet(pet_id)
	_append_chat("System: Summoning pet...")
	await main.get_tree().create_timer(0.5).timeout
	_refresh_pets()


func _on_dismiss_pressed() -> void:
	if main.pet_mgr == null:
		return
	main.pet_mgr.dismiss_pet()
	_append_chat("System: Dismissing pet...")
	await main.get_tree().create_timer(0.5).timeout
	_refresh_pets()


func _on_feed_pressed() -> void:
	if main.pet_mgr == null or _get_selected_pet_id().is_empty():
		return
	main.pet_mgr.feed_pet()
	_append_chat("System: Feeding pet...")
	await main.get_tree().create_timer(0.5).timeout
	_refresh_pets()


func _on_play_pressed() -> void:
	if main.pet_mgr == null or _get_selected_pet_id().is_empty():
		return
	main.pet_mgr.play_with_pet()
	_append_chat("System: Playing with pet...")
	await main.get_tree().create_timer(0.5).timeout
	_refresh_pets()


func _on_pet_pressed() -> void:
	if main.pet_mgr == null or _get_selected_pet_id().is_empty():
		return
	main.pet_mgr.pet_pet()
	_append_chat("System: Petting pet...")
	await main.get_tree().create_timer(0.5).timeout
	_refresh_pets()


func _on_trick_pressed() -> void:
	if main.pet_mgr == null or _get_selected_pet_id().is_empty():
		return
	var trick_index := _trick_select.selected
	if trick_index < 0:
		return
	# Get the actual trick name from the pet's learned tricks or TRICKS array
	var pet := _pets_data[_selected_pet_index]
	var learned_tricks: Array = pet.get("tricks", [])
	var trick_name: String
	if not learned_tricks.is_empty() and trick_index < learned_tricks.size():
		trick_name = str(learned_tricks[trick_index])
	elif trick_index < TRICKS.size():
		trick_name = TRICKS[trick_index]
	else:
		return
	main.pet_mgr.perform_trick(trick_name)
	_append_chat("System: Pet performs %s!" % trick_name.replace("_", " "))


func _on_rename_pressed() -> void:
	var pet_id := _get_selected_pet_id()
	if pet_id.is_empty():
		return
	var new_name := _rename_input.text.strip_edges()
	if new_name.is_empty():
		return
	_send_customize(pet_id, {"name": new_name})


func _on_save_customization() -> void:
	var pet_id := _get_selected_pet_id()
	if pet_id.is_empty():
		return
	var acc_index := _accessory_select.selected
	var accessory := ACCESSORIES[acc_index] if acc_index >= 0 and acc_index < ACCESSORIES.size() else "none"
	_send_customize(pet_id, {
		"color": "#" + _body_color_picker.color.to_html(false),
		"accentColor": "#" + _accent_color_picker.color.to_html(false),
		"accessory": accessory
	})


func _send_customize(pet_id: String, data: Dictionary) -> void:
	var token: String = main.session.get("token", "")
	if token.is_empty():
		return
	var payload := data.duplicate()
	payload["token"] = token
	var url := "%s/api/pets/%s" % [_base_url(), pet_id]
	var body := JSON.stringify(payload)
	var headers := PackedStringArray(["Content-Type: application/json"])
	_customize_request.request(url, headers, HTTPClient.METHOD_PATCH, body)


# ── Adopt Dialog ─────────────────────────────────────────────────────────

func _show_adopt_dialog() -> void:
	_adopt_dialog.visible = true
	_selected_species = ""
	_adopt_name_input.clear()
	# Reset all species buttons
	for species in _species_buttons:
		_species_buttons[species].button_pressed = false


func _select_species(species: String) -> void:
	_selected_species = species
	# Unpress all others
	for s in _species_buttons:
		_species_buttons[s].button_pressed = (s == species)


func _generate_random_name() -> void:
	var names := ["Buddy", "Luna", "Mochi", "Shadow", "Pepper", "Cleo",
		"Ziggy", "Patches", "Spark", "Cocoa", "Nimbus", "Ember",
		"Pixel", "Nova", "Whiskers", "Sunny", "Frost", "Biscuit"]
	_adopt_name_input.text = names[randi() % names.size()]


func _confirm_adopt() -> void:
	if _selected_species.is_empty():
		_append_chat("System: Please select a species.")
		return
	var pet_name := _adopt_name_input.text.strip_edges()
	if pet_name.is_empty():
		_append_chat("System: Please enter a name for your pet.")
		return
	if main.pet_mgr == null:
		return
	main.pet_mgr.adopt_pet(pet_name, _selected_species)
	_adopt_dialog.visible = false
	_append_chat("System: Adopting %s the %s..." % [pet_name, _selected_species])
	await main.get_tree().create_timer(0.5).timeout
	_refresh_pets()


# ── Helpers ──────────────────────────────────────────────────────────────

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
