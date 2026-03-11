class_name ToastManager
extends Control

## Notification system that shows floating toasts stacked from bottom-right.
## Toasts auto-dismiss after 4 seconds. Max 5 visible at once.

const MAX_VISIBLE := 5
const DISMISS_TIME := 4.0
const TOAST_HEIGHT := 40.0
const TOAST_MARGIN := 8.0
const TOAST_WIDTH := 300.0

var active_toasts: Array = []  # Array of { panel: PanelContainer, timer: float, type: String }

# Color scheme per type
var type_colors := {
	"info": Color(0.2, 0.4, 0.8, 0.9),
	"success": Color(0.2, 0.7, 0.3, 0.9),
	"warning": Color(0.85, 0.65, 0.1, 0.9),
	"error": Color(0.85, 0.2, 0.2, 0.9),
}


func _ready() -> void:
	# ToastManager should not block input to things behind it
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _process(delta: float) -> void:
	# Tick down toast timers
	var i := active_toasts.size() - 1
	while i >= 0:
		active_toasts[i].timer -= delta
		if active_toasts[i].timer <= 0:
			_remove_toast(i)
		elif active_toasts[i].timer < 0.5:
			# Fade out in last 0.5s
			active_toasts[i].panel.modulate.a = active_toasts[i].timer / 0.5
		i -= 1


func show_toast(message: String, type: String = "info") -> void:
	# Enforce max visible
	while active_toasts.size() >= MAX_VISIBLE:
		_remove_toast(0)

	var toast_panel := PanelContainer.new()
	toast_panel.custom_minimum_size = Vector2(TOAST_WIDTH, TOAST_HEIGHT)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Style the panel with a colored background
	var style := StyleBoxFlat.new()
	var bg_color: Color = type_colors.get(type, type_colors["info"])
	style.bg_color = bg_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	toast_panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color.WHITE)
	toast_panel.add_child(label)

	# Click to dismiss
	toast_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			var idx := -1
			for j in active_toasts.size():
				if active_toasts[j].panel == toast_panel:
					idx = j
					break
			if idx >= 0:
				_remove_toast(idx)
	)

	add_child(toast_panel)
	active_toasts.append({
		"panel": toast_panel,
		"timer": DISMISS_TIME,
		"type": type
	})

	_reposition_toasts()


func _remove_toast(index: int) -> void:
	if index < 0 or index >= active_toasts.size():
		return
	var toast_data: Dictionary = active_toasts[index]
	toast_data.panel.queue_free()
	active_toasts.remove_at(index)
	_reposition_toasts()


func _reposition_toasts() -> void:
	# Stack from bottom-right, newest at bottom
	var viewport_size := get_viewport_rect().size
	for i in active_toasts.size():
		var toast: PanelContainer = active_toasts[i].panel
		var y_offset := (active_toasts.size() - 1 - i) * (TOAST_HEIGHT + TOAST_MARGIN)
		toast.position = Vector2(
			viewport_size.x - TOAST_WIDTH - TOAST_MARGIN,
			viewport_size.y - TOAST_HEIGHT - TOAST_MARGIN - y_offset
		)
