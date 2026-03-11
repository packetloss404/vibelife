class_name SocialManager extends RefCounted

var main = null
var friends_presence: Array = []
var activity_feed: Array = []

func init(main_node) -> void:
	main = main_node


func _get_base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _get_token() -> String:
	return main.session.get("token", "")


func set_status(status: String, custom_message: String = "") -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = "%s/api/presence/status" % _get_base_url()
	var body = JSON.stringify({
		"token": token,
		"status": status,
		"customMessage": custom_message
	})
	var headers = PackedStringArray(["Content-Type: application/json"])
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray):
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func load_friends_presence() -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = "%s/api/presence/friends?token=%s" % [_get_base_url(), token]
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("presences"):
				friends_presence = payload.presences
		http.queue_free()
	)
	http.request(url)


func load_activity_feed() -> void:
	var url = "%s/api/activity/feed?limit=20&offset=0" % _get_base_url()
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("activities"):
				activity_feed = payload.activities
		http.queue_free()
	)
	http.request(url)


func load_friends_feed() -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = "%s/api/activity/friends?token=%s&limit=20" % [_get_base_url(), token]
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("activities"):
				activity_feed = payload.activities
		http.queue_free()
	)
	http.request(url)


func like_activity(activity_id: String) -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = "%s/api/activity/%s/like" % [_get_base_url(), activity_id]
	var body = JSON.stringify({"token": token})
	var headers = PackedStringArray(["Content-Type: application/json"])
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray):
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
