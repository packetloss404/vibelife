class_name HomeManager extends RefCounted

var main

var _set_home_request: HTTPRequest
var _teleport_home_request: HTTPRequest
var _privacy_request: HTTPRequest
var _clear_home_request: HTTPRequest
var _get_home_request: HTTPRequest


func init(main_node) -> void:
	main = main_node
	_set_home_request = HTTPRequest.new()
	_set_home_request.name = "SetHomeRequest"
	_set_home_request.request_completed.connect(_on_set_home_completed)
	main.add_child(_set_home_request)

	_teleport_home_request = HTTPRequest.new()
	_teleport_home_request.name = "TeleportHomeRequest"
	_teleport_home_request.request_completed.connect(_on_teleport_home_completed)
	main.add_child(_teleport_home_request)

	_privacy_request = HTTPRequest.new()
	_privacy_request.name = "HomePrivacyRequest"
	_privacy_request.request_completed.connect(_on_privacy_completed)
	main.add_child(_privacy_request)

	_clear_home_request = HTTPRequest.new()
	_clear_home_request.name = "ClearHomeRequest"
	_clear_home_request.request_completed.connect(_on_clear_home_completed)
	main.add_child(_clear_home_request)

	_get_home_request = HTTPRequest.new()
	_get_home_request.name = "GetHomeRequest"
	_get_home_request.request_completed.connect(_on_get_home_completed)
	main.add_child(_get_home_request)


func set_home(parcel_id: String) -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		main._append_chat("[Home] Not connected.")
		return
	var url = "%s/api/homes/set" % main.backend_url_input.text.rstrip("/")
	var body = JSON.stringify({"token": token, "parcelId": parcel_id})
	var headers = PackedStringArray(["Content-Type: application/json"])
	_set_home_request.request(url, headers, HTTPClient.METHOD_POST, body)


func teleport_home() -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		main._append_chat("[Home] Not connected.")
		return
	var url = "%s/api/homes/teleport" % main.backend_url_input.text.rstrip("/")
	var body = JSON.stringify({"token": token})
	var headers = PackedStringArray(["Content-Type: application/json"])
	_teleport_home_request.request(url, headers, HTTPClient.METHOD_POST, body)


func set_privacy(privacy: String) -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		main._append_chat("[Home] Not connected.")
		return
	if privacy not in ["public", "friends", "private"]:
		main._append_chat("[Home] Privacy must be public, friends, or private.")
		return
	var url = "%s/api/homes/privacy" % main.backend_url_input.text.rstrip("/")
	var body = JSON.stringify({"token": token, "privacy": privacy})
	var headers = PackedStringArray(["Content-Type: application/json"])
	_privacy_request.request(url, headers, HTTPClient.METHOD_POST, body)


func clear_home() -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		main._append_chat("[Home] Not connected.")
		return
	var url = "%s/api/homes" % main.backend_url_input.text.rstrip("/")
	var body = JSON.stringify({"token": token})
	var headers = PackedStringArray(["Content-Type: application/json"])
	_clear_home_request.request(url, headers, HTTPClient.METHOD_DELETE, body)


func get_home() -> void:
	var token = main.session.get("token", "")
	if token.is_empty():
		main._append_chat("[Home] Not connected.")
		return
	var url = "%s/api/homes?token=%s" % [main.backend_url_input.text.rstrip("/"), token]
	_get_home_request.request(url)


func _on_set_home_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var err = JSON.parse_string(body.get_string_from_utf8())
		var msg = err.get("error", "unknown error") if err else "request failed"
		main._append_chat("[Home] Set home failed: %s" % msg)
		return
	main._append_chat("[Home] Home parcel set successfully!")


func _on_teleport_home_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var err = JSON.parse_string(body.get_string_from_utf8())
		var msg = err.get("error", "unknown error") if err else "request failed"
		main._append_chat("[Home] Teleport home failed: %s" % msg)
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	main._append_chat("[Home] Teleporting home...")
	# If a new session was returned (cross-region teleport), update it
	if payload.has("session") and payload.session != null:
		main.session = payload.session
	# Reconnect WebSocket to load the region
	main._connect_websocket()


func _on_privacy_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var err = JSON.parse_string(body.get_string_from_utf8())
		var msg = err.get("error", "unknown error") if err else "request failed"
		main._append_chat("[Home] Set privacy failed: %s" % msg)
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	var privacy = payload.home.get("privacy", "public")
	main._append_chat("[Home] Privacy set to: %s" % privacy)


func _on_clear_home_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var err = JSON.parse_string(body.get_string_from_utf8())
		var msg = err.get("error", "unknown error") if err else "request failed"
		main._append_chat("[Home] Clear home failed: %s" % msg)
		return
	main._append_chat("[Home] Home cleared.")


func _on_get_home_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		main._append_chat("[Home] Could not fetch home info.")
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	var home = payload.get("home", null)
	if home == null:
		main._append_chat("[Home] No home set.")
	else:
		main._append_chat("[Home] Home parcel: %s (privacy: %s)" % [home.parcelId, home.privacy])
