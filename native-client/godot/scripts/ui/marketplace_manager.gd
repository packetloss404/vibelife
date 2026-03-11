class_name MarketplaceManager extends RefCounted

var main
var cached_listings: Array = []


func init(main_node) -> void:
	main = main_node


func _get_base_url() -> String:
	return main.backend_url_input.text.strip_edges()


func _get_token() -> String:
	return main.session.get("token", "")


func list_item(item_id: String, price: int, listing_type: String = "fixed", auction_end_time: String = "") -> void:
	var url = _get_base_url() + "/api/marketplace/list"
	var body = {
		"token": _get_token(),
		"itemId": item_id,
		"price": price,
		"listingType": listing_type,
	}
	if auction_end_time != "":
		body["auctionEndTime"] = auction_end_time

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("listing"):
			print("[Marketplace] Listed item: ", json["listing"].get("itemName", ""))
		else:
			print("[Marketplace] Failed to list item: ", json)
		http.queue_free()
	)
	var json_body = JSON.stringify(body)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_body)


func browse_marketplace(filters: Dictionary = {}) -> void:
	var url = _get_base_url() + "/api/marketplace"
	var query_parts: Array = []
	if filters.has("kind") and filters["kind"] != "":
		query_parts.append("kind=" + str(filters["kind"]))
	if filters.has("minPrice"):
		query_parts.append("minPrice=" + str(filters["minPrice"]))
	if filters.has("maxPrice"):
		query_parts.append("maxPrice=" + str(filters["maxPrice"]))
	if filters.has("sort") and filters["sort"] != "":
		query_parts.append("sort=" + str(filters["sort"]))
	if query_parts.size() > 0:
		url += "?" + "&".join(query_parts)

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("listings"):
			cached_listings = json["listings"]
			print("[Marketplace] Loaded ", cached_listings.size(), " listings")
		else:
			print("[Marketplace] Failed to browse: ", json)
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func buy_item(listing_id: String) -> void:
	var url = _get_base_url() + "/api/marketplace/" + listing_id + "/buy"
	var body = {"token": _get_token()}

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			print("[Marketplace] Purchase successful")
			browse_marketplace()
		else:
			print("[Marketplace] Purchase failed: ", json)
		http.queue_free()
	)
	var json_body = JSON.stringify(body)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_body)


func place_bid(listing_id: String, amount: int) -> void:
	var url = _get_base_url() + "/api/marketplace/" + listing_id + "/bid"
	var body = {"token": _get_token(), "amount": amount}

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			print("[Marketplace] Bid placed successfully")
			browse_marketplace()
		else:
			print("[Marketplace] Bid failed: ", json)
		http.queue_free()
	)
	var json_body = JSON.stringify(body)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_body)


func cancel_listing(listing_id: String) -> void:
	var url = _get_base_url() + "/api/marketplace/" + listing_id
	var body = {"token": _get_token()}

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			print("[Marketplace] Listing cancelled")
			browse_marketplace()
		else:
			print("[Marketplace] Cancel failed: ", json)
		http.queue_free()
	)
	var json_body = JSON.stringify(body)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_DELETE, json_body)


func create_trade(to_account_id: String, offered_items: Array, offered_currency: int, requested_items: Array, requested_currency: int) -> void:
	var url = _get_base_url() + "/api/trades"
	var body = {
		"token": _get_token(),
		"toAccountId": to_account_id,
		"offeredItems": offered_items,
		"offeredCurrency": offered_currency,
		"requestedItems": requested_items,
		"requestedCurrency": requested_currency,
	}

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("trade"):
			print("[Marketplace] Trade offer created: ", json["trade"].get("id", ""))
		else:
			print("[Marketplace] Trade creation failed: ", json)
		http.queue_free()
	)
	var json_body = JSON.stringify(body)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_body)


func accept_trade(trade_id: String) -> void:
	var url = _get_base_url() + "/api/trades/" + trade_id + "/accept"
	var body = {"token": _get_token()}

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			print("[Marketplace] Trade accepted")
		else:
			print("[Marketplace] Trade accept failed: ", json)
		http.queue_free()
	)
	var json_body = JSON.stringify(body)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_body)


func decline_trade(trade_id: String) -> void:
	var url = _get_base_url() + "/api/trades/" + trade_id + "/decline"
	var body = {"token": _get_token()}

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			print("[Marketplace] Trade declined")
		else:
			print("[Marketplace] Trade decline failed: ", json)
		http.queue_free()
	)
	var json_body = JSON.stringify(body)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_body)


func get_pending_trades() -> void:
	var url = _get_base_url() + "/api/trades?token=" + _get_token()

	var http = HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("trades"):
			print("[Marketplace] Pending trades: ", json["trades"].size())
		else:
			print("[Marketplace] Failed to get trades: ", json)
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)
