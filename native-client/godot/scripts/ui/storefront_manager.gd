class_name StorefrontManager extends RefCounted

var main

var storefronts: Array = []
var trending_items: Array = []
var commissions: Array = []
var my_storefront: Dictionary = {}

signal storefronts_loaded(storefronts: Array)
signal trending_loaded(items: Array)
signal storefront_created(storefront: Dictionary)
signal commission_created(commission: Dictionary)
signal commission_completed(commission: Dictionary)

func init(main_node) -> void:
	main = main_node


func _get_base_url() -> String:
	return main.backend_url_input.text.strip_edges()


func _get_token() -> String:
	var session = main.session
	if session.has("token"):
		return session["token"]
	return ""


func create_storefront(shop_name: String, description: String, banner_color: String) -> void:
	var url = _get_base_url() + "/api/storefronts"
	var token = _get_token()
	if token.is_empty():
		return

	var body = JSON.stringify({
		"token": token,
		"shopName": shop_name,
		"description": description,
		"bannerColor": banner_color
	})

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body_bytes: PackedByteArray):
		if code == 200:
			var json = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.has("storefront"):
				my_storefront = json["storefront"]
				storefront_created.emit(my_storefront)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func load_storefronts(sort: String = "") -> void:
	var url = _get_base_url() + "/api/storefronts"
	if not sort.is_empty():
		url += "?sort=" + sort

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body_bytes: PackedByteArray):
		if code == 200:
			var json = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.has("storefronts"):
				storefronts = json["storefronts"]
				storefronts_loaded.emit(storefronts)
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func load_trending(limit: int = 10) -> void:
	var url = _get_base_url() + "/api/marketplace/trending?limit=" + str(limit)

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body_bytes: PackedByteArray):
		if code == 200:
			var json = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.has("items"):
				trending_items = json["items"]
				trending_loaded.emit(trending_items)
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func create_commission(builder_account_id: String, description: String, budget: float) -> void:
	var url = _get_base_url() + "/api/commissions"
	var token = _get_token()
	if token.is_empty():
		return

	var body = JSON.stringify({
		"token": token,
		"builderAccountId": builder_account_id,
		"description": description,
		"budget": budget
	})

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body_bytes: PackedByteArray):
		if code == 200:
			var json = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.has("commission"):
				var commission = json["commission"]
				commissions.append(commission)
				commission_created.emit(commission)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func complete_commission(commission_id: String) -> void:
	var url = _get_base_url() + "/api/commissions/" + commission_id + "/complete"
	var token = _get_token()
	if token.is_empty():
		return

	var body = JSON.stringify({"token": token})

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body_bytes: PackedByteArray):
		if code == 200:
			var json = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.has("commission"):
				var commission = json["commission"]
				commission_completed.emit(commission)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func load_commissions() -> void:
	var url = _get_base_url() + "/api/commissions?token=" + _get_token()
	var token = _get_token()
	if token.is_empty():
		return

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body_bytes: PackedByteArray):
		if code == 200:
			var json = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json and json.has("commissions"):
				commissions = json["commissions"]
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)
