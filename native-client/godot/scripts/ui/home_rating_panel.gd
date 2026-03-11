class_name HomeRatingPanel extends RefCounted

var main
var _rate_request: HTTPRequest
var _featured_request: HTTPRequest
var _favorite_request: HTTPRequest
var _pending_parcel_id := ""
var featured_homes: Array = []

func init(main_node) -> void:
	main = main_node
	_rate_request = HTTPRequest.new()
	_rate_request.request_completed.connect(_on_rate_completed)
	main.add_child(_rate_request)
	_featured_request = HTTPRequest.new()
	_featured_request.request_completed.connect(_on_featured_completed)
	main.add_child(_featured_request)
	_favorite_request = HTTPRequest.new()
	_favorite_request.request_completed.connect(_on_favorite_completed)
	main.add_child(_favorite_request)


func show_rating_prompt(parcel_id: String) -> void:
	_pending_parcel_id = parcel_id
	var session = main.session
	if session.is_empty():
		return
	# Programmatic prompt — append a chat message inviting the user to rate
	var msg := "You are visiting a home! Rate it 1-5 by typing: /rate %s <1-5>" % parcel_id
	if main.has_method("_append_chat"):
		main._append_chat("System", msg)
	elif main.chat_log != null:
		main.chat_log.append_text("\n[color=yellow]%s[/color]" % msg)


func rate_home(parcel_id: String, rating: int) -> void:
	var session = main.session
	if session.is_empty():
		return
	var token = session.get("token", "")
	if token == "":
		return
	var clamped = int(clampf(float(rating), 1.0, 5.0))
	var url = "%s/api/homes/rate" % main.backend_url_input.text.rstrip("/")
	var body = JSON.stringify({"token": token, "parcelId": parcel_id, "rating": clamped})
	var headers = ["Content-Type: application/json"]
	_rate_request.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_rate_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("HomeRatingPanel: rate request failed with code %d" % response_code)
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	var avg = json.get("averageRating", 0)
	var total = json.get("totalRatings", 0)
	var msg := "Home rated! Average: %.1f (%d ratings)" % [float(avg), int(total)]
	if main.chat_log != null:
		main.chat_log.append_text("\n[color=green]%s[/color]" % msg)


func load_featured_homes() -> void:
	var url = "%s/api/homes/featured?limit=10" % main.backend_url_input.text.rstrip("/")
	_featured_request.request(url)


func _on_featured_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("HomeRatingPanel: featured request failed with code %d" % response_code)
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	featured_homes = json.get("homes", [])
	if main.chat_log != null and featured_homes.size() > 0:
		main.chat_log.append_text("\n[color=cyan]--- Featured Homes ---[/color]")
		for home in featured_homes:
			var name_str = home.get("parcelName", "Unknown")
			var owner_str = home.get("ownerDisplayName", "Unknown")
			var avg_str = "%.1f" % float(home.get("averageRating", 0))
			var visitors_str = str(int(home.get("visitorCount", 0)))
			main.chat_log.append_text("\n  %s by %s — Rating: %s, Visitors: %s" % [name_str, owner_str, avg_str, visitors_str])


func toggle_favorite(parcel_id: String) -> void:
	var session = main.session
	if session.is_empty():
		return
	var token = session.get("token", "")
	if token == "":
		return
	var url = "%s/api/homes/favorite" % main.backend_url_input.text.rstrip("/")
	var body = JSON.stringify({"token": token, "parcelId": parcel_id})
	var headers = ["Content-Type: application/json"]
	_favorite_request.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_favorite_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("HomeRatingPanel: favorite request failed with code %d" % response_code)
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	var favorited = json.get("favorited", false)
	var msg := "Home favorited!" if favorited else "Home unfavorited."
	if main.chat_log != null:
		main.chat_log.append_text("\n[color=yellow]%s[/color]" % msg)
