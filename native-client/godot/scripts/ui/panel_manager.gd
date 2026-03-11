class_name PanelManager
extends Control

## Tabbed panel system that hosts feature panels in the right dock.
## Register tabs with register_tab(), switch with switch_to() or Ctrl+1-9.

signal tab_switched(tab_name: String)

var tabs: Dictionary = {}  # name -> { control: Control, button: Button, badge: int }
var tab_order: Array[String] = []
var active_tab: String = ""

var tab_bar: HBoxContainer
var content_area: Control


func _ready() -> void:
	# Build internal layout: tab bar on top, content area below
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# Tab bar container with scroll support
	var tab_scroll := ScrollContainer.new()
	tab_scroll.custom_minimum_size.y = 36
	tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(tab_scroll)

	tab_bar = HBoxContainer.new()
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.add_theme_constant_override("separation", 2)
	tab_scroll.add_child(tab_bar)

	# Separator line
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Content area fills the rest
	content_area = Control.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_area)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var key_event := event as InputEventKey
	if not key_event.ctrl_pressed:
		return
	# Ctrl+1 through Ctrl+9 for quick tab switching
	var key_num := -1
	match key_event.keycode:
		KEY_1: key_num = 0
		KEY_2: key_num = 1
		KEY_3: key_num = 2
		KEY_4: key_num = 3
		KEY_5: key_num = 4
		KEY_6: key_num = 5
		KEY_7: key_num = 6
		KEY_8: key_num = 7
		KEY_9: key_num = 8
	if key_num >= 0 and key_num < tab_order.size():
		switch_to(tab_order[key_num])
		get_viewport().set_input_as_handled()


func register_tab(tab_name: String, control: Control, _icon: String = "") -> void:
	if tabs.has(tab_name):
		return

	# Create tab button
	var btn := Button.new()
	btn.text = tab_name
	btn.toggle_mode = true
	btn.custom_minimum_size.x = 60
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): switch_to(tab_name))
	tab_bar.add_child(btn)

	# Add control to content area but hide it
	control.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	control.visible = false
	content_area.add_child(control)

	tabs[tab_name] = {
		"control": control,
		"button": btn,
		"badge": 0
	}
	tab_order.append(tab_name)

	# Auto-select first tab
	if tab_order.size() == 1:
		switch_to(tab_name)


func switch_to(tab_name: String) -> void:
	if not tabs.has(tab_name):
		return
	if active_tab == tab_name:
		return

	# Hide current
	if not active_tab.is_empty() and tabs.has(active_tab):
		tabs[active_tab].control.visible = false
		tabs[active_tab].button.button_pressed = false

	# Show new
	active_tab = tab_name
	tabs[active_tab].control.visible = true
	tabs[active_tab].button.button_pressed = true

	# Clear badge on switch
	set_badge(tab_name, 0)

	tab_switched.emit(tab_name)


func set_badge(tab_name: String, count: int) -> void:
	if not tabs.has(tab_name):
		return
	tabs[tab_name].badge = count
	var btn: Button = tabs[tab_name].button
	if count > 0:
		btn.text = "%s (%d)" % [tab_name, count]
	else:
		btn.text = tab_name


func get_active_panel() -> Control:
	if active_tab.is_empty() or not tabs.has(active_tab):
		return null
	return tabs[active_tab].control
