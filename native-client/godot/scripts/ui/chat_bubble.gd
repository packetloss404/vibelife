class_name ChatBubble extends RefCounted

var main
var active_bubbles: Dictionary = {}
var active_typing: Dictionary = {}

const BUBBLE_OFFSET := Vector3(0, 2.5, 0)
const BUBBLE_DURATION := 5.0
const TYPING_TIMEOUT := 3.0
const MAX_LINE_WIDTH := 30

var _typing_debounce_timer: Timer = null
var _is_typing_sent := false


func init(main_node) -> void:
	main = main_node
	_typing_debounce_timer = Timer.new()
	_typing_debounce_timer.one_shot = true
	_typing_debounce_timer.wait_time = 1.0
	_typing_debounce_timer.timeout.connect(_on_typing_debounce_timeout)
	main.add_child(_typing_debounce_timer)


func show_bubble(avatar_id: String, message: String) -> void:
	_remove_bubble(avatar_id)
	_remove_typing(avatar_id)

	var avatar_node = main.avatars.avatar_nodes.get(avatar_id, null)
	if avatar_node == null:
		return

	var label := Label3D.new()
	label.name = "ChatBubble"
	label.text = _wrap_text(message)
	label.position = BUBBLE_OFFSET + Vector3(0, 0.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.005
	label.outline_size = 12
	label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.7)
	label.no_depth_test = true
	label.fixed_size = false

	avatar_node.add_child(label)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = BUBBLE_DURATION
	timer.timeout.connect(_on_bubble_timeout.bind(avatar_id, timer))
	main.add_child(timer)
	timer.start()

	active_bubbles[avatar_id] = {"label": label, "timer": timer}


func show_typing(avatar_id: String, typing: bool) -> void:
	if typing:
		_remove_typing(avatar_id)

		var avatar_node = main.avatars.avatar_nodes.get(avatar_id, null)
		if avatar_node == null:
			return

		var label := Label3D.new()
		label.name = "TypingIndicator"
		label.text = "..."
		label.position = BUBBLE_OFFSET + Vector3(0, 0.6, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.pixel_size = 0.005
		label.outline_size = 12
		label.modulate = Color(0.8, 0.8, 0.8, 0.9)
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.5)
		label.no_depth_test = true

		avatar_node.add_child(label)

		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = TYPING_TIMEOUT
		timer.timeout.connect(_on_typing_timeout.bind(avatar_id, timer))
		main.add_child(timer)
		timer.start()

		active_typing[avatar_id] = {"label": label, "timer": timer}
	else:
		_remove_typing(avatar_id)


func on_chat_input_changed(new_text: String) -> void:
	if new_text.is_empty():
		if _is_typing_sent:
			_send_typing(false)
		_typing_debounce_timer.stop()
		return

	if not _is_typing_sent:
		_send_typing(true)

	_typing_debounce_timer.start()


func _send_typing(typing: bool) -> void:
	if main.websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	main.websocket.send_text(JSON.stringify({
		"type": "typing",
		"typing": typing
	}))
	_is_typing_sent = typing


func _on_typing_debounce_timeout() -> void:
	if _is_typing_sent:
		_send_typing(false)


func _on_bubble_timeout(avatar_id: String, timer: Timer) -> void:
	timer.queue_free()
	_remove_bubble(avatar_id)


func _on_typing_timeout(avatar_id: String, timer: Timer) -> void:
	timer.queue_free()
	_remove_typing(avatar_id)


func _remove_bubble(avatar_id: String) -> void:
	if not active_bubbles.has(avatar_id):
		return
	var entry = active_bubbles[avatar_id]
	var label = entry.label
	var timer = entry.timer
	if is_instance_valid(label):
		label.queue_free()
	if is_instance_valid(timer):
		timer.queue_free()
	active_bubbles.erase(avatar_id)


func _remove_typing(avatar_id: String) -> void:
	if not active_typing.has(avatar_id):
		return
	var entry = active_typing[avatar_id]
	var label = entry.label
	var timer = entry.timer
	if is_instance_valid(label):
		label.queue_free()
	if is_instance_valid(timer):
		timer.queue_free()
	active_typing.erase(avatar_id)


func _wrap_text(message: String) -> String:
	if message.length() <= MAX_LINE_WIDTH:
		return message
	var result := ""
	var line_length := 0
	var words := message.split(" ")
	for word in words:
		if line_length > 0 and line_length + word.length() + 1 > MAX_LINE_WIDTH:
			result += "\n"
			line_length = 0
		if line_length > 0:
			result += " "
			line_length += 1
		result += word
		line_length += word.length()
	return result


func cleanup_avatar(avatar_id: String) -> void:
	_remove_bubble(avatar_id)
	_remove_typing(avatar_id)
