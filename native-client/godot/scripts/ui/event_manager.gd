class_name EventManager extends RefCounted

var main
var cached_events: Array = []

var _create_request: HTTPRequest
var _list_request: HTTPRequest
var _upcoming_request: HTTPRequest
var _rsvp_request: HTTPRequest
var _cancel_request: HTTPRequest


func init(main_node) -> void:
	main = main_node
	_create_request = HTTPRequest.new()
	_create_request.name = "EventCreateRequest"
	_create_request.request_completed.connect(_on_create_completed)
	main.add_child(_create_request)

	_list_request = HTTPRequest.new()
	_list_request.name = "EventListRequest"
	_list_request.request_completed.connect(_on_list_completed)
	main.add_child(_list_request)

	_upcoming_request = HTTPRequest.new()
	_upcoming_request.name = "EventUpcomingRequest"
	_upcoming_request.request_completed.connect(_on_upcoming_completed)
	main.add_child(_upcoming_request)

	_rsvp_request = HTTPRequest.new()
	_rsvp_request.name = "EventRsvpRequest"
	_rsvp_request.request_completed.connect(_on_rsvp_completed)
	main.add_child(_rsvp_request)

	_cancel_request = HTTPRequest.new()
	_cancel_request.name = "EventCancelRequest"
	_cancel_request.request_completed.connect(_on_cancel_completed)
	main.add_child(_cancel_request)


func _get_base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func create_event(data: Dictionary) -> void:
	var session = main.session
	if session.is_empty():
		return
	var payload = data.duplicate()
	payload["token"] = session.get("token", "")
	var body := JSON.stringify(payload)
	var url := "%s/api/events" % _get_base_url()
	_create_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func load_events(region_id: String) -> void:
	var url := "%s/api/events?regionId=%s&upcoming=true" % [_get_base_url(), region_id]
	_list_request.request(url)


func load_upcoming_events() -> void:
	var url := "%s/api/events/upcoming?limit=10" % _get_base_url()
	_upcoming_request.request(url)


func rsvp_event(event_id: String) -> void:
	var session = main.session
	if session.is_empty():
		return
	var body := JSON.stringify({"token": session.get("token", "")})
	var url := "%s/api/events/%s/rsvp" % [_get_base_url(), event_id]
	_rsvp_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func cancel_event(event_id: String) -> void:
	var session = main.session
	if session.is_empty():
		return
	var body := JSON.stringify({"token": session.get("token", "")})
	var url := "%s/api/events/%s" % [_get_base_url(), event_id]
	_cancel_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_DELETE, body)


func _on_create_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		main._append_chat("System: failed to create event")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed.has("event"):
		return
	main._append_chat("System: event '%s' created" % parsed.event.get("name", ""))


func _on_list_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed.has("events"):
		return
	cached_events = parsed.events


func _on_upcoming_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed.has("events"):
		return
	cached_events = parsed.events


func _on_rsvp_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		main._append_chat("System: RSVP failed")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed.has("event"):
		return
	main._append_chat("System: RSVP toggled for '%s'" % parsed.event.get("name", ""))


func _on_cancel_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code != 200:
		main._append_chat("System: failed to cancel event")
		return
	main._append_chat("System: event cancelled")
