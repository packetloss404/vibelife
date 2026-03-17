class_name ChatController
extends RefCounted

var main  # reference to main node

# Color constants for message formatting
const COLOR_SYSTEM := Color("ffcc00")
const COLOR_WHISPER := Color("cc66ff")
const COLOR_NORMAL := Color("ffffff")
const COLOR_TIMESTAMP := Color("888888")

# Typing indicator
var _typing_timer := 0.0
var _is_typing := false
const TYPING_DEBOUNCE := 2.0


func init(main_node) -> void:
	main = main_node


func fetch_chat_history() -> void:
	if main.session.is_empty():
		return
	var request := HTTPRequest.new()
	main.add_child(request)
	var url := "%s/api/regions/%s/chat-history" % [main.backend_url, main.session.regionId]
	if request.request(url) == OK:
		var result = await request.request_completed
		var response_code: int = result[1]
		if response_code == 200:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			if payload and payload.has("messages"):
				for msg in payload.messages:
					_append_formatted_message(msg)
	request.queue_free()


func handle_chat_input(text: String) -> void:
	if text.is_empty():
		return
	if main.websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		main.status_label.text = "Chat unavailable until region WebSocket connects."
		return

	# Whisper command: /w username message
	if text.begins_with("/w "):
		var parts := text.substr(3).strip_edges()
		var space_idx := parts.find(" ")
		if space_idx > 0:
			var target_name := parts.substr(0, space_idx)
			var whisper_msg := parts.substr(space_idx + 1).strip_edges()
			if not whisper_msg.is_empty():
				main.websocket.send_text(JSON.stringify({
					"type": "whisper",
					"targetDisplayName": target_name,
					"message": whisper_msg
				}))
				main.chat_input.clear()
				return
		main.status_label.text = "Usage: /w <username> <message>"
		return

	# Regular chat message
	main.websocket.send_text(JSON.stringify({
		"type": "chat",
		"message": text
	}))
	main.chat_input.clear()


func handle_chat_event(message: Dictionary) -> void:
	var _channel: String = message.get("channel", "region")
	var display_name: String = message.get("displayName", "Unknown")
	var text: String = message.get("message", "")
	var created_at: String = message.get("createdAt", "")
	var avatar_id: String = message.get("avatarId", "")

	var timestamp := _format_timestamp(created_at)

	if avatar_id == "system":
		_append_colored("[%s] [System] %s" % [timestamp, text], COLOR_SYSTEM)
	else:
		_append_colored("[%s] %s: %s" % [timestamp, display_name, text], COLOR_NORMAL)


func handle_whisper_event(message: Dictionary) -> void:
	var from_name: String = message.get("fromDisplayName", "Unknown")
	var to_name: String = message.get("toDisplayName", "Unknown")
	var text: String = message.get("message", "")
	var created_at: String = message.get("createdAt", "")
	var timestamp := _format_timestamp(created_at)

	var my_avatar_id: String = main.session.get("avatarId", "")
	var from_avatar_id: String = message.get("fromAvatarId", "")

	if from_avatar_id == my_avatar_id:
		_append_colored("[%s] [whisper to %s] %s" % [timestamp, to_name, text], COLOR_WHISPER)
	else:
		_append_colored("[%s] [whisper from %s] %s" % [timestamp, from_name, text], COLOR_WHISPER)


func handle_snapshot_chat_history(messages: Array) -> void:
	for msg in messages:
		_append_formatted_message(msg)


func update_typing_indicator(delta: float) -> void:
	if _is_typing:
		_typing_timer -= delta
		if _typing_timer <= 0.0:
			_is_typing = false


func on_chat_text_changed(_new_text: String) -> void:
	if not _is_typing and main.websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_is_typing = true
		_typing_timer = TYPING_DEBOUNCE


func _append_formatted_message(msg: Dictionary) -> void:
	var channel: String = msg.get("channel", "region")
	var display_name: String = msg.get("displayName", "Unknown")
	var text: String = msg.get("message", "")
	var created_at: String = msg.get("createdAt", "")
	var avatar_id: String = msg.get("avatarId", "")
	var timestamp := _format_timestamp(created_at)

	if avatar_id == "system":
		_append_colored("[%s] [System] %s" % [timestamp, text], COLOR_SYSTEM)
	elif channel == "whisper":
		_append_colored("[%s] [whisper] %s: %s" % [timestamp, display_name, text], COLOR_WHISPER)
	else:
		_append_colored("[%s] %s: %s" % [timestamp, display_name, text], COLOR_NORMAL)


func _append_colored(text: String, color: Color) -> void:
	main.chat_log.push_color(color)
	main.chat_log.append_text(text + "\n")
	main.chat_log.pop()


func _format_timestamp(iso_string: String) -> String:
	if iso_string.is_empty():
		return ""
	# Extract HH:MM from ISO timestamp
	var t_pos := iso_string.find("T")
	if t_pos < 0:
		return ""
	var time_part := iso_string.substr(t_pos + 1)
	if time_part.length() >= 5:
		return time_part.substr(0, 5)
	return time_part
