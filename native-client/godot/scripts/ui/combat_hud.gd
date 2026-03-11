class_name CombatHUD
extends RefCounted

var main_node: Node3D
var hud_root: Control
var hp_bar: ProgressBar
var mana_bar: ProgressBar
var xp_bar: ProgressBar
var level_label: Label
var damage_container: Control
var death_overlay: ColorRect

var canvas_layer: CanvasLayer
var floating_numbers: Array = []  # [{label, velocity, lifetime, position_3d}]
var loot_notifications: Array = []  # [{control, lifetime}]
var loot_container: VBoxContainer


func init(main: Node3D) -> void:
	main_node = main

	# Create CanvasLayer for HUD
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "CombatHUDLayer"
	canvas_layer.layer = 10
	main_node.add_child(canvas_layer)

	# Root control
	hud_root = Control.new()
	hud_root.name = "CombatHUD"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(hud_root)

	_create_hp_bar()
	_create_mana_bar()
	_create_xp_bar()
	_create_level_label()
	_create_damage_container()
	_create_death_overlay()
	_create_loot_container()


func _create_hp_bar() -> void:
	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(300, 24)
	hp_bar.position = Vector2(-150, 20)  # Will be centered
	hp_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)

	# Style the bar red
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.8, 0.15, 0.15)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.1, 0.1)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("background", bg_style)

	# HP label overlay
	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "HP"
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_bar.add_child(hp_label)

	hud_root.add_child(hp_bar)


func _create_mana_bar() -> void:
	mana_bar = ProgressBar.new()
	mana_bar.name = "ManaBar"
	mana_bar.min_value = 0
	mana_bar.max_value = 100
	mana_bar.value = 100
	mana_bar.show_percentage = false
	mana_bar.custom_minimum_size = Vector2(250, 18)
	mana_bar.position = Vector2(-125, 50)
	mana_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.15, 0.3, 0.85)
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	mana_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.08, 0.15)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	mana_bar.add_theme_stylebox_override("background", bg_style)

	var mana_label := Label.new()
	mana_label.name = "ManaLabel"
	mana_label.text = "MP"
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mana_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	mana_label.add_theme_font_size_override("font_size", 10)
	mana_label.add_theme_color_override("font_color", Color.WHITE)
	mana_bar.add_child(mana_label)

	hud_root.add_child(mana_bar)


func _create_xp_bar() -> void:
	xp_bar = ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.min_value = 0
	xp_bar.max_value = 100
	xp_bar.value = 0
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(400, 10)
	xp_bar.position = Vector2(-200, -20)
	xp_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.9, 0.75, 0.1)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	xp_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.1, 0.05)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	xp_bar.add_theme_stylebox_override("background", bg_style)

	hud_root.add_child(xp_bar)


func _create_level_label() -> void:
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Lv. 1"
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	level_label.add_theme_constant_override("shadow_offset_x", 1)
	level_label.add_theme_constant_override("shadow_offset_y", 1)
	# Position to the left of HP bar
	level_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	level_label.position = Vector2(-210, 18)
	hud_root.add_child(level_label)


func _create_damage_container() -> void:
	damage_container = Control.new()
	damage_container.name = "DamageContainer"
	damage_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(damage_container)


func _create_death_overlay() -> void:
	death_overlay = ColorRect.new()
	death_overlay.name = "DeathOverlay"
	death_overlay.color = Color(0.5, 0.05, 0.05, 0.0)
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.visible = false

	var death_label := Label.new()
	death_label.name = "DeathLabel"
	death_label.text = "You Died"
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_label.add_theme_font_size_override("font_size", 64)
	death_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	death_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	death_label.add_theme_constant_override("shadow_offset_x", 3)
	death_label.add_theme_constant_override("shadow_offset_y", 3)
	death_label.modulate.a = 0.0
	death_overlay.add_child(death_label)

	hud_root.add_child(death_overlay)


func _create_loot_container() -> void:
	loot_container = VBoxContainer.new()
	loot_container.name = "LootContainer"
	loot_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	loot_container.position = Vector2(-150, -60)
	loot_container.custom_minimum_size = Vector2(300, 0)
	loot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(loot_container)


func update_stats(stats: Dictionary) -> void:
	if stats.has("hp") and stats.has("maxHp"):
		hp_bar.max_value = float(stats.maxHp)
		hp_bar.value = float(stats.hp)
		var hp_label := hp_bar.find_child("HPLabel", false, false)
		if hp_label and hp_label is Label:
			hp_label.text = "%d / %d" % [int(stats.hp), int(stats.maxHp)]

	if stats.has("mana") and stats.has("maxMana"):
		mana_bar.max_value = float(stats.maxMana)
		mana_bar.value = float(stats.mana)
		var mana_label := mana_bar.find_child("ManaLabel", false, false)
		if mana_label and mana_label is Label:
			mana_label.text = "%d / %d" % [int(stats.mana), int(stats.maxMana)]

	if stats.has("xp") and stats.has("xpToNextLevel"):
		xp_bar.max_value = float(stats.xpToNextLevel)
		xp_bar.value = float(stats.xp)

	if stats.has("level"):
		level_label.text = "Lv. %d" % int(stats.level)


func show_damage_number(position_3d: Vector3, amount: int, is_critical: bool) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if is_critical:
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	else:
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))

	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	damage_container.add_child(label)

	floating_numbers.append({
		"label": label,
		"velocity": Vector2(randf_range(-30, 30), -120.0),
		"lifetime": 1.0,
		"position_3d": position_3d,
		"elapsed": 0.0,
	})


func show_death_overlay() -> void:
	death_overlay.visible = true
	death_overlay.color = Color(0.5, 0.05, 0.05, 0.0)

	var death_label := death_overlay.find_child("DeathLabel", false, false)

	var tween := hud_root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(death_overlay, "color", Color(0.5, 0.05, 0.05, 0.6), 0.8).set_ease(Tween.EASE_OUT)
	if death_label:
		tween.tween_property(death_label, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_OUT)

	# Auto-hide after 3 seconds
	tween.set_parallel(false)
	tween.tween_interval(2.0)
	tween.tween_property(death_overlay, "color", Color(0.5, 0.05, 0.05, 0.0), 0.5)
	if death_label:
		tween.tween_property(death_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		death_overlay.visible = false
	)


func show_level_up(new_level: int) -> void:
	var level_up_label := Label.new()
	level_up_label.name = "LevelUpLabel"
	level_up_label.text = "Level Up!\nLevel %d" % new_level
	level_up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_up_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_up_label.set_anchors_preset(Control.PRESET_CENTER)
	level_up_label.position = Vector2(-100, -40)
	level_up_label.custom_minimum_size = Vector2(200, 80)
	level_up_label.add_theme_font_size_override("font_size", 36)
	level_up_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	level_up_label.add_theme_color_override("font_shadow_color", Color(0.4, 0.3, 0.0, 0.8))
	level_up_label.add_theme_constant_override("shadow_offset_x", 2)
	level_up_label.add_theme_constant_override("shadow_offset_y", 2)
	level_up_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_up_label.scale = Vector2(0.5, 0.5)
	level_up_label.pivot_offset = Vector2(100, 40)
	level_up_label.modulate.a = 0.0

	hud_root.add_child(level_up_label)

	var tween := hud_root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(level_up_label, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(level_up_label, "modulate:a", 1.0, 0.3)
	tween.set_parallel(false)
	tween.tween_interval(1.5)
	tween.tween_property(level_up_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		level_up_label.queue_free()
	)


func show_loot_notification(items: Array) -> void:
	for item in items:
		var item_name: String = str(item.get("name", "Unknown"))
		var item_count: int = int(item.get("count", 1))

		var loot_label := Label.new()
		if item_count > 1:
			loot_label.text = "+ %s x%d" % [item_name, item_count]
		else:
			loot_label.text = "+ %s" % item_name
		loot_label.add_theme_font_size_override("font_size", 16)
		loot_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		loot_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		loot_label.add_theme_constant_override("shadow_offset_x", 1)
		loot_label.add_theme_constant_override("shadow_offset_y", 1)
		loot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		loot_label.modulate.a = 0.0

		loot_container.add_child(loot_label)

		# Fade in, hold, fade out
		var tween := hud_root.create_tween()
		tween.tween_property(loot_label, "modulate:a", 1.0, 0.2)
		tween.tween_interval(2.5)
		tween.tween_property(loot_label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func():
			loot_label.queue_free()
		)


func _process_hud(delta: float) -> void:
	var camera := main_node.get_viewport().get_camera_3d()
	if camera == null:
		return

	# Update floating damage numbers
	var expired: Array = []
	for i in range(floating_numbers.size()):
		var num: Dictionary = floating_numbers[i]
		var num_label: Label = num.label
		num.elapsed += delta
		num.lifetime -= delta

		if num.lifetime <= 0.0 or not is_instance_valid(num_label):
			if is_instance_valid(num_label):
				num_label.queue_free()
			expired.append(i)
			continue

		# Project 3D position to 2D screen
		var screen_pos := camera.unproject_position(num.position_3d)

		# Apply velocity (upward drift)
		var vel: Vector2 = num.velocity
		screen_pos += vel * num.elapsed

		num_label.position = screen_pos - num_label.size * 0.5

		# Fade out in the last 0.3s
		if num.lifetime < 0.3:
			num_label.modulate.a = num.lifetime / 0.3
		else:
			num_label.modulate.a = 1.0

		floating_numbers[i] = num

	# Remove expired numbers in reverse order
	expired.reverse()
	for idx in expired:
		floating_numbers.remove_at(idx)
