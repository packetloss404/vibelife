class_name BasePanel
extends Control

## Abstract base class for all feature panels.
## Provides HTTP helpers, token/URL access, toast shortcuts, and standard layout.

var main  # Reference to main node (Node3D)

# Standard layout containers — subclasses add content to body_container
var header_container: HBoxContainer
var body_container: VBoxContainer
var footer_container: HBoxContainer
var scroll_container: ScrollContainer
var loading_spinner: Label
var error_label: Label


func init(main_node) -> void:
	main = main_node
	_build_layout()
	_panel_ready()


func _build_layout() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	root_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	# Header
	header_container = HBoxContainer.new()
	header_container.add_theme_constant_override("separation", 8)
	root_vbox.add_child(header_container)

	# Error label (hidden by default)
	error_label = Label.new()
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.visible = false
	error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	root_vbox.add_child(error_label)

	# Loading spinner (hidden by default)
	loading_spinner = Label.new()
	loading_spinner.text = "Loading..."
	loading_spinner.visible = false
	root_vbox.add_child(loading_spinner)

	# Scrollable body
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll_container)

	body_container = VBoxContainer.new()
	body_container.size_flags_horizontal = SIZE_EXPAND_FILL
	body_container.size_flags_vertical = SIZE_EXPAND_FILL
	body_container.add_theme_constant_override("separation", 6)
	scroll_container.add_child(body_container)

	# Footer
	footer_container = HBoxContainer.new()
	footer_container.add_theme_constant_override("separation", 8)
	root_vbox.add_child(footer_container)


## Override in subclasses to set up panel-specific UI after layout is built.
func _panel_ready() -> void:
	pass


func _get_base_url() -> String:
	if main and main.backend_url:
		return main.backend_url
	return "http://127.0.0.1:3000"


func _get_token() -> String:
	if main and main.session is Dictionary:
		return main.session.get("token", "")
	return ""


## Make an HTTP request and return the parsed JSON response.
## Returns an empty dictionary on failure.
func _make_request(method: String, path: String, body: Dictionary = {}) -> Dictionary:
	_show_loading(true)
	_show_error("")

	var request := HTTPRequest.new()
	add_child(request)

	var url := "%s%s" % [_get_base_url(), path]
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http_method: int
	match method.to_upper():
		"GET": http_method = HTTPClient.METHOD_GET
		"POST": http_method = HTTPClient.METHOD_POST
		"PUT": http_method = HTTPClient.METHOD_PUT
		"DELETE": http_method = HTTPClient.METHOD_DELETE
		"PATCH": http_method = HTTPClient.METHOD_PATCH
		_: http_method = HTTPClient.METHOD_GET

	var body_text := ""
	if not body.is_empty():
		# Always include token if available
		if not body.has("token") and not _get_token().is_empty():
			body["token"] = _get_token()
		body_text = JSON.stringify(body)
	elif http_method != HTTPClient.METHOD_GET:
		body_text = JSON.stringify({"token": _get_token()})

	var error: int
	if body_text.is_empty():
		error = request.request(url, headers, http_method)
	else:
		error = request.request(url, headers, http_method, body_text)

	if error != OK:
		_show_loading(false)
		_show_error("Request failed: %s" % error)
		request.queue_free()
		return {}

	var result = await request.request_completed
	request.queue_free()
	_show_loading(false)

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	if response_code < 200 or response_code >= 300:
		_show_error("Server returned %d" % response_code)
		return {}

	var parsed = JSON.parse_string(response_body.get_string_from_utf8())
	if parsed is Dictionary:
		return parsed
	return {}


func _show_loading(is_loading: bool) -> void:
	if loading_spinner:
		loading_spinner.visible = is_loading


func _show_error(message: String) -> void:
	if error_label:
		error_label.text = message
		error_label.visible = not message.is_empty()


func _show_toast(message: String, type: String = "info") -> void:
	if main and main.has_node("CanvasLayer/UI/ToastManager"):
		main.get_node("CanvasLayer/UI/ToastManager").show_toast(message, type)


## Called when a WebSocket event arrives. Override in subclasses to handle events.
func _on_ws_event(event_type: String, data: Dictionary) -> void:
	pass
