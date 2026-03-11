# =============================================================================
# MobileCompanion — Feature 16: Mobile Companion App (Godot client module)
# =============================================================================
# Handles mobile-specific API calls from the Godot desktop client, allowing
# the desktop client to interact with mobile companion features such as:
#   - Mobile session management
#   - Push notification registration
#   - Notification preferences
#   - Dashboard / feed retrieval
#   - Quick actions (teleport, message, send currency)
#   - Lightweight world sync for companion display
#
# Usage in main.gd:
#   var mobile_companion = MobileCompanion.new()
#   mobile_companion.init(self)
#   mobile_companion.fetch_dashboard()
# =============================================================================

class_name MobileCompanion
extends RefCounted

signal dashboard_received(dashboard: Dictionary)
signal feed_received(feed: Array)
signal friends_received(friends: Array, online_statuses: Dictionary)
signal inventory_received(inventory: Array)
signal marketplace_received(listings: Array)
signal regions_received(regions: Array)
signal notifications_received(notifications: Array, unread_count: int)
signal world_snapshot_received(world: Dictionary)
signal world_sync_received(sync_data: Dictionary)
signal session_created(session: Dictionary)
signal session_destroyed()
signal push_token_registered(result: Dictionary)
signal notification_preferences_received(preferences: Dictionary)
signal quick_teleport_completed(ok: bool, region_id: String)
signal quick_message_sent(ok: bool)
signal currency_sent(ok: bool, balance: int)
signal request_failed(endpoint: String, error: String)

var main

# HTTP request nodes created at init
var _dashboard_request: HTTPRequest
var _feed_request: HTTPRequest
var _friends_request: HTTPRequest
var _inventory_request: HTTPRequest
var _marketplace_request: HTTPRequest
var _regions_request: HTTPRequest
var _notifications_request: HTTPRequest
var _world_request: HTTPRequest
var _world_sync_request: HTTPRequest
var _session_request: HTTPRequest
var _session_delete_request: HTTPRequest
var _push_token_request: HTTPRequest
var _notif_prefs_get_request: HTTPRequest
var _notif_prefs_patch_request: HTTPRequest
var _notif_read_request: HTTPRequest
var _notif_read_all_request: HTTPRequest
var _quick_teleport_request: HTTPRequest
var _quick_message_request: HTTPRequest
var _quick_currency_request: HTTPRequest

# Polling timer for lightweight sync
var _sync_timer: Timer
var _sync_enabled := false
var _sync_interval := 5.0

# Cached data
var cached_dashboard: Dictionary = {}
var cached_feed: Array = []
var cached_friends: Array = []
var cached_online_statuses: Dictionary = {}
var cached_notifications: Array = []
var cached_unread_count := 0


func init(main_node) -> void:
	main = main_node
	_create_http_requests()


func _create_http_requests() -> void:
	_dashboard_request = HTTPRequest.new()
	_dashboard_request.request_completed.connect(_on_dashboard_completed)
	main.add_child(_dashboard_request)

	_feed_request = HTTPRequest.new()
	_feed_request.request_completed.connect(_on_feed_completed)
	main.add_child(_feed_request)

	_friends_request = HTTPRequest.new()
	_friends_request.request_completed.connect(_on_friends_completed)
	main.add_child(_friends_request)

	_inventory_request = HTTPRequest.new()
	_inventory_request.request_completed.connect(_on_inventory_completed)
	main.add_child(_inventory_request)

	_marketplace_request = HTTPRequest.new()
	_marketplace_request.request_completed.connect(_on_marketplace_completed)
	main.add_child(_marketplace_request)

	_regions_request = HTTPRequest.new()
	_regions_request.request_completed.connect(_on_regions_completed)
	main.add_child(_regions_request)

	_notifications_request = HTTPRequest.new()
	_notifications_request.request_completed.connect(_on_notifications_completed)
	main.add_child(_notifications_request)

	_world_request = HTTPRequest.new()
	_world_request.request_completed.connect(_on_world_completed)
	main.add_child(_world_request)

	_world_sync_request = HTTPRequest.new()
	_world_sync_request.request_completed.connect(_on_world_sync_completed)
	main.add_child(_world_sync_request)

	_session_request = HTTPRequest.new()
	_session_request.request_completed.connect(_on_session_completed)
	main.add_child(_session_request)

	_session_delete_request = HTTPRequest.new()
	_session_delete_request.request_completed.connect(_on_session_delete_completed)
	main.add_child(_session_delete_request)

	_push_token_request = HTTPRequest.new()
	_push_token_request.request_completed.connect(_on_push_token_completed)
	main.add_child(_push_token_request)

	_notif_prefs_get_request = HTTPRequest.new()
	_notif_prefs_get_request.request_completed.connect(_on_notif_prefs_get_completed)
	main.add_child(_notif_prefs_get_request)

	_notif_prefs_patch_request = HTTPRequest.new()
	_notif_prefs_patch_request.request_completed.connect(_on_notif_prefs_patch_completed)
	main.add_child(_notif_prefs_patch_request)

	_notif_read_request = HTTPRequest.new()
	_notif_read_request.request_completed.connect(_on_notif_read_completed)
	main.add_child(_notif_read_request)

	_notif_read_all_request = HTTPRequest.new()
	_notif_read_all_request.request_completed.connect(_on_notif_read_all_completed)
	main.add_child(_notif_read_all_request)

	_quick_teleport_request = HTTPRequest.new()
	_quick_teleport_request.request_completed.connect(_on_quick_teleport_completed)
	main.add_child(_quick_teleport_request)

	_quick_message_request = HTTPRequest.new()
	_quick_message_request.request_completed.connect(_on_quick_message_completed)
	main.add_child(_quick_message_request)

	_quick_currency_request = HTTPRequest.new()
	_quick_currency_request.request_completed.connect(_on_quick_currency_completed)
	main.add_child(_quick_currency_request)

	# Create sync timer
	_sync_timer = Timer.new()
	_sync_timer.wait_time = _sync_interval
	_sync_timer.one_shot = false
	_sync_timer.timeout.connect(_on_sync_timer_timeout)
	main.add_child(_sync_timer)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _get_token() -> String:
	return main.session.get("token", "")


func _make_headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json"])


func _parse_json_body(body: PackedByteArray) -> Dictionary:
	var text = body.get_string_from_utf8()
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _parse_json_array(body: PackedByteArray, key: String) -> Array:
	var data = _parse_json_body(body)
	var value = data.get(key, [])
	if value is Array:
		return value
	return []


# ---------------------------------------------------------------------------
# Mobile session management
# ---------------------------------------------------------------------------

func create_mobile_session(platform: String = "unknown") -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/session", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/session"
	var payload = JSON.stringify({"token": token, "platform": platform})
	_session_request.request(url, _make_headers(), HTTPClient.METHOD_POST, payload)


func get_mobile_session() -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/session", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/session?token=" + token
	_session_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func destroy_mobile_session() -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = _get_base_url() + "/api/mobile/session"
	var payload = JSON.stringify({"token": token})
	_session_delete_request.request(url, _make_headers(), HTTPClient.METHOD_DELETE, payload)


func _on_session_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/session", "HTTP " + str(response_code))
		return
	var data = _parse_json_body(body)
	var session = data.get("session", {})
	if session is Dictionary:
		session_created.emit(session)


func _on_session_delete_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code == 200:
		session_destroyed.emit()


# ---------------------------------------------------------------------------
# Push notification token
# ---------------------------------------------------------------------------

func register_push_token(platform: String, push_token: String) -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/push-token", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/push-token"
	var payload = JSON.stringify({"token": token, "platform": platform, "pushToken": push_token})
	_push_token_request.request(url, _make_headers(), HTTPClient.METHOD_POST, payload)


func _on_push_token_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/push-token", "HTTP " + str(response_code))
		return
	var data = _parse_json_body(body)
	var result = data.get("pushToken", {})
	if result is Dictionary:
		push_token_registered.emit(result)


# ---------------------------------------------------------------------------
# Notification preferences
# ---------------------------------------------------------------------------

func fetch_notification_preferences() -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/notifications/preferences", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/notifications/preferences?token=" + token
	_notif_prefs_get_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func update_notification_preferences(updates: Dictionary) -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/notifications/preferences", "no active session token")
		return
	updates["token"] = token
	var url = _get_base_url() + "/api/mobile/notifications/preferences"
	var payload = JSON.stringify(updates)
	_notif_prefs_patch_request.request(url, _make_headers(), HTTPClient.METHOD_PATCH, payload)


func _on_notif_prefs_get_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/notifications/preferences", "HTTP " + str(response_code))
		return
	var data = _parse_json_body(body)
	var prefs = data.get("preferences", {})
	if prefs is Dictionary:
		notification_preferences_received.emit(prefs)


func _on_notif_prefs_patch_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/notifications/preferences", "HTTP " + str(response_code))
		return
	var data = _parse_json_body(body)
	var prefs = data.get("preferences", {})
	if prefs is Dictionary:
		notification_preferences_received.emit(prefs)


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

func fetch_notifications(limit: int = 50, unread_only: bool = false) -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/notifications", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/notifications?token=" + token + "&limit=" + str(limit)
	if unread_only:
		url += "&unreadOnly=true"
	_notifications_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func mark_notification_read(notification_id: String) -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = _get_base_url() + "/api/mobile/notifications/read"
	var payload = JSON.stringify({"token": token, "notificationId": notification_id})
	_notif_read_request.request(url, _make_headers(), HTTPClient.METHOD_PATCH, payload)


func mark_all_notifications_read() -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = _get_base_url() + "/api/mobile/notifications/read-all"
	var payload = JSON.stringify({"token": token})
	_notif_read_all_request.request(url, _make_headers(), HTTPClient.METHOD_POST, payload)


func _on_notifications_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/notifications", "HTTP " + str(response_code))
		return
	var data = _parse_json_body(body)
	var notifs = data.get("notifications", [])
	var unread = data.get("unreadCount", 0)
	if notifs is Array:
		cached_notifications = notifs
		cached_unread_count = int(unread)
		notifications_received.emit(notifs, int(unread))


func _on_notif_read_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	# Silently handled; optionally refresh notifications
	pass


func _on_notif_read_all_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	cached_unread_count = 0
	# Optionally refresh
	pass


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

func fetch_dashboard() -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/dashboard", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/dashboard?token=" + token
	_dashboard_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func _on_dashboard_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/dashboard", "HTTP " + str(response_code))
		return
	var data = _parse_json_body(body)
	var dashboard = data.get("dashboard", {})
	if dashboard is Dictionary:
		cached_dashboard = dashboard
		dashboard_received.emit(dashboard)


# ---------------------------------------------------------------------------
# Activity feed
# ---------------------------------------------------------------------------

func fetch_feed(limit: int = 30) -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/feed", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/feed?token=" + token + "&limit=" + str(limit)
	_feed_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func _on_feed_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/feed", "HTTP " + str(response_code))
		return
	var data = _parse_json_body(body)
	var feed = data.get("feed", [])
	if feed is Array:
		cached_feed = feed
		feed_received.emit(feed)


# ---------------------------------------------------------------------------
# Friends (with online status)
# ---------------------------------------------------------------------------

func fetch_friends() -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/friends", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/friends?token=" + token
	_friends_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func _on_friends_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/friends", "HTTP " + str(response_code))
		return
	var data = _parse_json_body(body)
	var friends = data.get("friends", [])
	var statuses = data.get("onlineStatuses", {})
	if friends is Array:
		cached_friends = friends
		if statuses is Dictionary:
			cached_online_statuses = statuses
		friends_received.emit(friends, cached_online_statuses)


# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

func fetch_inventory() -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/inventory", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/inventory?token=" + token
	_inventory_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func _on_inventory_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/inventory", "HTTP " + str(response_code))
		return
	var items = _parse_json_array(body, "inventory")
	inventory_received.emit(items)


# ---------------------------------------------------------------------------
# Marketplace
# ---------------------------------------------------------------------------

func fetch_marketplace(limit: int = 50) -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/marketplace", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/marketplace?token=" + token + "&limit=" + str(limit)
	_marketplace_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func _on_marketplace_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/marketplace", "HTTP " + str(response_code))
		return
	var listings = _parse_json_array(body, "listings")
	marketplace_received.emit(listings)


# ---------------------------------------------------------------------------
# Regions
# ---------------------------------------------------------------------------

func fetch_regions() -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/regions", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/regions?token=" + token
	_regions_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func _on_regions_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/regions", "HTTP " + str(response_code))
		return
	var data = _parse_json_body(body)
	var region_list = data.get("regions", [])
	if region_list is Array:
		regions_received.emit(region_list)


# ---------------------------------------------------------------------------
# World snapshot and sync
# ---------------------------------------------------------------------------

func fetch_world_snapshot() -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/world", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/world?token=" + token
	_world_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func fetch_world_sync() -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = _get_base_url() + "/api/mobile/world/sync?token=" + token
	_world_sync_request.request(url, _make_headers(), HTTPClient.METHOD_GET)


func start_sync_polling(interval: float = 5.0) -> void:
	_sync_interval = interval
	_sync_timer.wait_time = _sync_interval
	_sync_enabled = true
	_sync_timer.start()


func stop_sync_polling() -> void:
	_sync_enabled = false
	_sync_timer.stop()


func _on_sync_timer_timeout() -> void:
	if _sync_enabled:
		fetch_world_sync()


func _on_world_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		request_failed.emit("mobile/world", "HTTP " + str(response_code))
		return
	var data = _parse_json_body(body)
	var world = data.get("world", {})
	if world is Dictionary:
		world_snapshot_received.emit(world)


func _on_world_sync_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		# Silently fail sync polls to avoid flooding errors
		return
	var data = _parse_json_body(body)
	var sync_data = data.get("sync", {})
	if sync_data is Dictionary:
		world_sync_received.emit(sync_data)


# ---------------------------------------------------------------------------
# Quick actions
# ---------------------------------------------------------------------------

func quick_teleport(region_id: String, x: float = 0.0, y: float = 0.0, z: float = 0.0) -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/quick-actions/teleport", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/quick-actions/teleport"
	var payload = JSON.stringify({"token": token, "regionId": region_id, "x": x, "y": y, "z": z})
	_quick_teleport_request.request(url, _make_headers(), HTTPClient.METHOD_POST, payload)


func quick_message(to_account_id: String, message: String) -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/quick-actions/message", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/quick-actions/message"
	var payload = JSON.stringify({"token": token, "toAccountId": to_account_id, "message": message})
	_quick_message_request.request(url, _make_headers(), HTTPClient.METHOD_POST, payload)


func quick_send_currency(to_account_id: String, amount: int, description: String = "mobile gift") -> void:
	var token = _get_token()
	if token.is_empty():
		request_failed.emit("mobile/quick-actions/send-currency", "no active session token")
		return
	var url = _get_base_url() + "/api/mobile/quick-actions/send-currency"
	var payload = JSON.stringify({
		"token": token,
		"toAccountId": to_account_id,
		"amount": amount,
		"description": description
	})
	_quick_currency_request.request(url, _make_headers(), HTTPClient.METHOD_POST, payload)


func _on_quick_teleport_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var data = _parse_json_body(body)
		var error_msg = data.get("error", "teleport failed")
		request_failed.emit("mobile/quick-actions/teleport", str(error_msg))
		quick_teleport_completed.emit(false, "")
		return
	var data = _parse_json_body(body)
	var region_id = data.get("regionId", "")
	quick_teleport_completed.emit(true, str(region_id))


func _on_quick_message_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var data = _parse_json_body(body)
		var error_msg = data.get("error", "message failed")
		request_failed.emit("mobile/quick-actions/message", str(error_msg))
		quick_message_sent.emit(false)
		return
	quick_message_sent.emit(true)


func _on_quick_currency_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var data = _parse_json_body(body)
		var error_msg = data.get("error", "send failed")
		request_failed.emit("mobile/quick-actions/send-currency", str(error_msg))
		currency_sent.emit(false, 0)
		return
	var data = _parse_json_body(body)
	var balance = data.get("balance", 0)
	currency_sent.emit(true, int(balance))


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

func cleanup() -> void:
	stop_sync_polling()
	if is_instance_valid(_sync_timer):
		_sync_timer.queue_free()
	var requests: Array = [
		_dashboard_request, _feed_request, _friends_request,
		_inventory_request, _marketplace_request, _regions_request,
		_notifications_request, _world_request, _world_sync_request,
		_session_request, _session_delete_request, _push_token_request,
		_notif_prefs_get_request, _notif_prefs_patch_request,
		_notif_read_request, _notif_read_all_request,
		_quick_teleport_request, _quick_message_request, _quick_currency_request
	]
	for req in requests:
		if is_instance_valid(req):
			req.queue_free()
