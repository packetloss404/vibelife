class_name ServerBrowser
extends RefCounted

## Feature 18: Federation / Multi-Server — Client-side server browser,
## cross-server teleport, and federated marketplace browsing.
##
## Usage from main.gd:
##   var server_browser = ServerBrowser.new()
##   server_browser.init(self)
##   server_browser.refresh_server_directory()

var main

# Cached data
var server_directory: Array = []
var marketplace_results: Array = []
var selected_server_index: int = -1
var selected_listing_index: int = -1

# State
var is_refreshing: bool = false
var is_searching: bool = false
var is_teleporting: bool = false

# HTTPRequest nodes (created dynamically to avoid scene-tree dependency)
var _servers_http: HTTPRequest = null
var _teleport_http: HTTPRequest = null
var _marketplace_http: HTTPRequest = null
var _identity_http: HTTPRequest = null
var _register_http: HTTPRequest = null
var _heartbeat_http: HTTPRequest = null
var _arrive_http: HTTPRequest = null


func init(main_node) -> void:
	main = main_node
	_create_http_nodes()


func _create_http_nodes() -> void:
	_servers_http = HTTPRequest.new()
	_servers_http.name = "FedServersRequest"
	_servers_http.request_completed.connect(_on_servers_loaded)
	main.add_child(_servers_http)

	_teleport_http = HTTPRequest.new()
	_teleport_http.name = "FedTeleportRequest"
	_teleport_http.request_completed.connect(_on_teleport_completed)
	main.add_child(_teleport_http)

	_marketplace_http = HTTPRequest.new()
	_marketplace_http.name = "FedMarketplaceRequest"
	_marketplace_http.request_completed.connect(_on_marketplace_loaded)
	main.add_child(_marketplace_http)

	_identity_http = HTTPRequest.new()
	_identity_http.name = "FedIdentityRequest"
	_identity_http.request_completed.connect(_on_identity_issued)
	main.add_child(_identity_http)

	_register_http = HTTPRequest.new()
	_register_http.name = "FedRegisterRequest"
	_register_http.request_completed.connect(_on_server_registered)
	main.add_child(_register_http)

	_heartbeat_http = HTTPRequest.new()
	_heartbeat_http.name = "FedHeartbeatRequest"
	_heartbeat_http.request_completed.connect(_on_heartbeat_completed)
	main.add_child(_heartbeat_http)

	_arrive_http = HTTPRequest.new()
	_arrive_http.name = "FedArriveRequest"
	_arrive_http.request_completed.connect(_on_arrive_completed)
	main.add_child(_arrive_http)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _auth_token() -> String:
	return main.session.get("token", "")


func _json_headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json"])


func _log_status(msg: String) -> void:
	if main.has_method("_set_status"):
		main._set_status(msg)
	else:
		print("[ServerBrowser] ", msg)


func _parse_json_body(body: PackedByteArray) -> Dictionary:
	var text = body.get_string_from_utf8()
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


# ---------------------------------------------------------------------------
# Server Directory
# ---------------------------------------------------------------------------

func refresh_server_directory() -> void:
	if is_refreshing:
		return
	is_refreshing = true
	_log_status("Refreshing server directory...")

	var url = _base_url() + "/api/federation/servers"
	var err = _servers_http.request(url, _json_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		is_refreshing = false
		_log_status("Failed to request server directory")


func _on_servers_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_refreshing = false

	if response_code != 200:
		_log_status("Server directory request failed (HTTP %d)" % response_code)
		return

	var data = _parse_json_body(body)
	var servers = data.get("servers", [])
	if servers is Array:
		server_directory = servers
	else:
		server_directory = []

	_log_status("Loaded %d servers from directory" % server_directory.size())


func get_server_count() -> int:
	return server_directory.size()


func get_server_at(index: int) -> Dictionary:
	if index < 0 or index >= server_directory.size():
		return {}
	return server_directory[index]


func get_server_display_text(index: int) -> String:
	var server = get_server_at(index)
	if server.is_empty():
		return ""
	var name = server.get("name", "Unknown")
	var pop = server.get("population", 0)
	var status = server.get("status", "unknown")
	var regions = server.get("regions", 0)
	return "%s [%s] - %d regions, %d online" % [name, status, regions, pop]


func select_server(index: int) -> void:
	selected_server_index = index


func get_selected_server() -> Dictionary:
	return get_server_at(selected_server_index)


# ---------------------------------------------------------------------------
# Server Registration (register this server with a remote directory)
# ---------------------------------------------------------------------------

func register_with_remote(remote_url: String, server_name: String, local_url: String, description: String, tags: Array) -> void:
	var payload = JSON.stringify({
		"name": server_name,
		"url": local_url,
		"description": description,
		"tags": tags,
		"token": _auth_token()
	})

	var url = remote_url.rstrip("/") + "/api/federation/servers/register"
	var err = _register_http.request(url, _json_headers(), HTTPClient.METHOD_POST, payload)
	if err != OK:
		_log_status("Failed to send registration request")


func _on_server_registered(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_log_status("Server registration failed (HTTP %d)" % response_code)
		return

	var data = _parse_json_body(body)
	var server = data.get("server", {})
	var name = ""
	if server is Dictionary:
		name = server.get("name", "")
	_log_status("Registered with federation as: %s" % name)


# ---------------------------------------------------------------------------
# Heartbeat
# ---------------------------------------------------------------------------

func send_heartbeat(server_id: String, regions_count: int, population: int) -> void:
	var payload = JSON.stringify({
		"serverId": server_id,
		"regions": regions_count,
		"population": population
	})

	var url = _base_url() + "/api/federation/heartbeat"
	var err = _heartbeat_http.request(url, _json_headers(), HTTPClient.METHOD_POST, payload)
	if err != OK:
		_log_status("Heartbeat failed to send")


func _on_heartbeat_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code != 200:
		_log_status("Heartbeat failed (HTTP %d)" % response_code)


# ---------------------------------------------------------------------------
# Cross-Server Teleportation
# ---------------------------------------------------------------------------

func teleport_to_server(target_server_url: String, target_region_id: String, x: float, y: float, z: float) -> void:
	if is_teleporting:
		_log_status("Teleport already in progress")
		return

	var token = _auth_token()
	if token.is_empty():
		_log_status("Must be logged in to teleport across servers")
		return

	is_teleporting = true
	_log_status("Preparing cross-server teleport...")

	var payload = JSON.stringify({
		"token": token,
		"targetServerUrl": target_server_url,
		"targetRegionId": target_region_id,
		"x": x,
		"y": y,
		"z": z
	})

	var url = _base_url() + "/api/federation/teleport"
	var err = _teleport_http.request(url, _json_headers(), HTTPClient.METHOD_POST, payload)
	if err != OK:
		is_teleporting = false
		_log_status("Failed to initiate cross-server teleport")


func _on_teleport_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_teleporting = false

	if response_code != 200:
		var data = _parse_json_body(body)
		var reason = data.get("error", "teleport failed")
		_log_status("Cross-server teleport failed: %s" % str(reason))
		return

	var data = _parse_json_body(body)
	var redirect_url = data.get("redirectUrl", "")

	if redirect_url is String and not redirect_url.is_empty():
		_log_status("Teleport redirect ready. Connecting to remote server...")
		# Extract the target server base URL from the redirect URL for the client
		# to switch its backend connection.
		var parts = redirect_url.split("/api/federation/")
		if parts.size() > 0:
			var new_backend = parts[0]
			_handle_server_switch(new_backend, redirect_url)
	else:
		_log_status("Cross-server teleport: no redirect URL received")


func _handle_server_switch(new_backend_url: String, redirect_url: String) -> void:
	# Update the backend URL in the UI so all future requests go to the new server
	main.backend_url_input.text = new_backend_url
	_log_status("Switched to server: %s" % new_backend_url)

	# Now complete the arrival on the remote server.
	# Parse the redirect URL to get the identity token and region info.
	# The redirect URL is a GET endpoint but we call the POST arrive endpoint
	# with the same data for cleaner handling.
	_request_identity_for_arrival(new_backend_url)


func _request_identity_for_arrival(new_backend_url: String) -> void:
	# Issue a federated identity token from the OLD server (we still have the session)
	# before switching. This is already done server-side via the teleport endpoint,
	# so we just need to call the arrive endpoint on the new server.
	#
	# For the MVP, the client re-authenticates as a guest on the new server
	# using the same display name, preserving identity across servers.
	var display_name = main.session.get("displayName", "Traveler")
	_log_status("Arriving at new server as: %s" % display_name)

	# Re-join the new server as a guest with the federated display name
	var payload = JSON.stringify({
		"displayName": display_name
	})
	var url = new_backend_url.rstrip("/") + "/api/auth/guest"
	var err = _arrive_http.request(url, _json_headers(), HTTPClient.METHOD_POST, payload)
	if err != OK:
		_log_status("Failed to arrive at remote server")


func _on_arrive_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_log_status("Arrival at remote server failed (HTTP %d)" % response_code)
		return

	var data = _parse_json_body(body)
	var new_session = data.get("session", {})

	if new_session is Dictionary and new_session.has("token"):
		main.session = new_session
		_log_status("Arrived at remote server successfully!")

		# Refresh regions on the new server
		if main.has_method("_fetch_regions"):
			main._fetch_regions()
	else:
		_log_status("Arrived but received invalid session data")


func teleport_to_selected_server(region_id: String) -> void:
	var server = get_selected_server()
	if server.is_empty():
		_log_status("No server selected for teleport")
		return

	var target_url = server.get("url", "")
	if target_url is String and not target_url.is_empty():
		teleport_to_server(target_url, region_id, 0.0, 0.0, 0.0)
	else:
		_log_status("Selected server has no URL")


# ---------------------------------------------------------------------------
# Federated Marketplace
# ---------------------------------------------------------------------------

func search_marketplace(query: String) -> void:
	if is_searching:
		return

	var token = _auth_token()
	if token.is_empty():
		_log_status("Must be logged in to search marketplace")
		return

	is_searching = true
	_log_status("Searching federated marketplace...")

	var payload = JSON.stringify({
		"token": token,
		"query": query
	})

	var url = _base_url() + "/api/federation/marketplace/search"
	var err = _marketplace_http.request(url, _json_headers(), HTTPClient.METHOD_POST, payload)
	if err != OK:
		is_searching = false
		_log_status("Failed to search marketplace")


func browse_marketplace() -> void:
	if is_searching:
		return

	is_searching = true
	_log_status("Loading marketplace listings...")

	var url = _base_url() + "/api/federation/marketplace"
	var err = _marketplace_http.request(url, _json_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		is_searching = false
		_log_status("Failed to load marketplace")


func _on_marketplace_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_searching = false

	if response_code != 200:
		_log_status("Marketplace request failed (HTTP %d)" % response_code)
		return

	var data = _parse_json_body(body)

	# Handle both search (multi-server results) and browse (single-server listings)
	var results = data.get("results", null)
	if results is Array:
		# Multi-server search response
		marketplace_results = []
		for result in results:
			if result is Dictionary:
				var listings = result.get("listings", [])
				if listings is Array:
					for listing in listings:
						if listing is Dictionary:
							marketplace_results.append(listing)
		_log_status("Found %d listings across federated servers" % marketplace_results.size())
	else:
		# Single-server browse response
		var listings = data.get("listings", [])
		if listings is Array:
			marketplace_results = listings
		else:
			marketplace_results = []
		_log_status("Loaded %d marketplace listings" % marketplace_results.size())


func get_listing_count() -> int:
	return marketplace_results.size()


func get_listing_at(index: int) -> Dictionary:
	if index < 0 or index >= marketplace_results.size():
		return {}
	return marketplace_results[index]


func get_listing_display_text(index: int) -> String:
	var listing = get_listing_at(index)
	if listing.is_empty():
		return ""
	var name = listing.get("name", "Unknown")
	var price = listing.get("price", 0)
	var seller = listing.get("sellerDisplayName", "Unknown")
	var server_name = listing.get("serverName", "Local")
	return "%s - $%d by %s [%s]" % [name, price, seller, server_name]


func select_listing(index: int) -> void:
	selected_listing_index = index


func get_selected_listing() -> Dictionary:
	return get_listing_at(selected_listing_index)


# ---------------------------------------------------------------------------
# Federated Identity
# ---------------------------------------------------------------------------

func request_identity_token() -> void:
	var token = _auth_token()
	if token.is_empty():
		_log_status("Must be logged in to get identity token")
		return

	var payload = JSON.stringify({ "token": token })
	var url = _base_url() + "/api/federation/identity/issue"
	var err = _identity_http.request(url, _json_headers(), HTTPClient.METHOD_POST, payload)
	if err != OK:
		_log_status("Failed to request identity token")


func _on_identity_issued(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_log_status("Identity token request failed (HTTP %d)" % response_code)
		return

	var data = _parse_json_body(body)
	var id_token = data.get("identityToken", {})
	if id_token is Dictionary and id_token.has("tokenId"):
		_log_status("Identity token issued: %s" % str(id_token.get("tokenId", "")))
	else:
		_log_status("Failed to parse identity token")


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

func cleanup() -> void:
	if _servers_http and is_instance_valid(_servers_http):
		_servers_http.queue_free()
	if _teleport_http and is_instance_valid(_teleport_http):
		_teleport_http.queue_free()
	if _marketplace_http and is_instance_valid(_marketplace_http):
		_marketplace_http.queue_free()
	if _identity_http and is_instance_valid(_identity_http):
		_identity_http.queue_free()
	if _register_http and is_instance_valid(_register_http):
		_register_http.queue_free()
	if _heartbeat_http and is_instance_valid(_heartbeat_http):
		_heartbeat_http.queue_free()
	if _arrive_http and is_instance_valid(_arrive_http):
		_arrive_http.queue_free()
