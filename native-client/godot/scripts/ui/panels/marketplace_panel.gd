class_name MarketplacePanel extends Control

var main  # Reference to main node

# State
var cached_listings: Array = []
var cached_my_listings: Array = []
var cached_trades: Array = []
var current_tab := 0  # 0=Browse, 1=Sell, 2=My Listings, 3=Trades

# Root containers
var tab_bar: TabBar
var tab_content: Control
var browse_container: Control
var sell_container: Control
var my_listings_container: Control
var trades_container: Control

# Browse tab widgets
var search_input: LineEdit
var sort_select: OptionButton
var browse_scroll: ScrollContainer
var browse_grid: VBoxContainer
var detail_popup: PanelContainer
var detail_vbox: VBoxContainer

# Sell tab widgets
var sell_item_select: OptionButton
var sell_price_input: SpinBox
var sell_type_select: OptionButton
var sell_duration_input: SpinBox
var sell_duration_row: HBoxContainer
var sell_button: Button
var sell_status: Label

# My Listings tab widgets
var my_listings_scroll: ScrollContainer
var my_listings_vbox: VBoxContainer

# Trades tab widgets
var trades_scroll: ScrollContainer
var trades_vbox: VBoxContainer


func init(main_node) -> void:
	main = main_node
	name = "MarketplacePanel"
	visible = false
	_build_ui()


func _get_base_url() -> String:
	return main.backend_url_input.text.strip_edges().rstrip("/")


func _get_token() -> String:
	return main.session.get("token", "")


func _build_ui() -> void:
	# Main panel background
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(root_vbox)

	# Title
	var title := Label.new()
	title.text = "Marketplace"
	title.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(title)

	# Tab bar
	tab_bar = TabBar.new()
	tab_bar.add_tab("Browse")
	tab_bar.add_tab("Sell")
	tab_bar.add_tab("My Listings")
	tab_bar.add_tab("Trades")
	tab_bar.tab_changed.connect(_on_tab_changed)
	root_vbox.add_child(tab_bar)

	# Tab content area
	tab_content = Control.new()
	tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(tab_content)

	_build_browse_tab()
	_build_sell_tab()
	_build_my_listings_tab()
	_build_trades_tab()

	_show_tab(0)


# ── Browse Tab ───────────────────────────────────────────────────────────────

func _build_browse_tab() -> void:
	browse_container = VBoxContainer.new()
	browse_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	browse_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_content.add_child(browse_container)

	# Search + sort row
	var search_row := HBoxContainer.new()
	browse_container.add_child(search_row)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Search items..."
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_submitted.connect(func(_t): _refresh_browse())
	search_row.add_child(search_input)

	var search_btn := Button.new()
	search_btn.text = "Search"
	search_btn.pressed.connect(_refresh_browse)
	search_row.add_child(search_btn)

	sort_select = OptionButton.new()
	sort_select.add_item("Newest")
	sort_select.add_item("Price: Low-High")
	sort_select.add_item("Price: High-Low")
	sort_select.add_item("Ending Soon")
	sort_select.item_selected.connect(func(_i): _refresh_browse())
	search_row.add_child(sort_select)

	# Listings grid
	browse_scroll = ScrollContainer.new()
	browse_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browse_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse_container.add_child(browse_scroll)

	browse_grid = VBoxContainer.new()
	browse_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse_scroll.add_child(browse_grid)

	# Detail popup (hidden by default)
	detail_popup = PanelContainer.new()
	detail_popup.visible = false
	detail_popup.set_anchors_preset(Control.PRESET_CENTER)
	detail_popup.custom_minimum_size = Vector2(400, 300)
	detail_popup.z_index = 10
	add_child(detail_popup)

	detail_vbox = VBoxContainer.new()
	detail_popup.add_child(detail_vbox)


func _refresh_browse() -> void:
	var url := _get_base_url() + "/api/marketplace"
	var query_parts: Array = []

	var search_text := search_input.text.strip_edges()
	if not search_text.is_empty():
		query_parts.append("search=" + search_text.uri_encode())

	var sort_idx := sort_select.selected
	var sort_values := ["newest", "price_asc", "price_desc", "ending_soon"]
	if sort_idx >= 0 and sort_idx < sort_values.size():
		query_parts.append("sort=" + sort_values[sort_idx])

	if query_parts.size() > 0:
		url += "?" + "&".join(query_parts)

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("listings"):
			cached_listings = json["listings"]
			_render_browse_listings()
		else:
			main._append_chat("[Market] Failed to load listings")
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _render_browse_listings() -> void:
	# Clear existing entries
	for child in browse_grid.get_children():
		child.queue_free()

	if cached_listings.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No listings found."
		browse_grid.add_child(empty_label)
		return

	for listing in cached_listings:
		var entry := _create_listing_entry(listing)
		browse_grid.add_child(entry)


func _create_listing_entry(listing: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 60)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Item name
	var name_label := Label.new()
	name_label.text = listing.get("itemName", "Unknown Item")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	# Type badge
	var type_label := Label.new()
	var listing_type: String = listing.get("listingType", "fixed")
	type_label.text = "[AUCTION]" if listing_type == "auction" else "[FIXED]"
	hbox.add_child(type_label)

	# Price
	var price_label := Label.new()
	price_label.text = "%d coins" % int(listing.get("price", 0))
	hbox.add_child(price_label)

	# Seller
	var seller_label := Label.new()
	seller_label.text = "by %s" % listing.get("sellerName", "Unknown")
	hbox.add_child(seller_label)

	# Action button
	if listing_type == "fixed":
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		var lid: String = listing.get("id", "")
		buy_btn.pressed.connect(func(): _buy_listing(lid))
		hbox.add_child(buy_btn)
	else:
		var bid_btn := Button.new()
		bid_btn.text = "Bid"
		var lid: String = listing.get("id", "")
		bid_btn.pressed.connect(func(): _show_bid_popup(lid, listing))
		hbox.add_child(bid_btn)

	# Detail button
	var detail_btn := Button.new()
	detail_btn.text = "Details"
	detail_btn.pressed.connect(func(): _show_listing_detail(listing))
	hbox.add_child(detail_btn)

	return panel


func _buy_listing(listing_id: String) -> void:
	var url := _get_base_url() + "/api/marketplace/" + listing_id + "/buy"
	var body := JSON.stringify({"token": _get_token()})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Market] Purchase successful!")
			_refresh_browse()
		else:
			var err: String = json.get("error", "Purchase failed") if json else "Purchase failed"
			main._append_chat("[Market] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _show_bid_popup(listing_id: String, listing: Dictionary) -> void:
	# Reuse the detail popup for bidding
	_clear_detail_popup()
	detail_popup.visible = true

	var title := Label.new()
	title.text = "Place Bid: %s" % listing.get("itemName", "Item")
	title.add_theme_font_size_override("font_size", 16)
	detail_vbox.add_child(title)

	var current_bid_label := Label.new()
	current_bid_label.text = "Current bid: %d coins" % int(listing.get("currentBid", listing.get("price", 0)))
	detail_vbox.add_child(current_bid_label)

	var bid_input := SpinBox.new()
	bid_input.min_value = 1
	bid_input.max_value = 999999
	bid_input.value = int(listing.get("currentBid", listing.get("price", 0))) + 1
	detail_vbox.add_child(bid_input)

	var btn_row := HBoxContainer.new()
	detail_vbox.add_child(btn_row)

	var place_bid_btn := Button.new()
	place_bid_btn.text = "Place Bid"
	place_bid_btn.pressed.connect(func():
		_place_bid(listing_id, int(bid_input.value))
		detail_popup.visible = false
	)
	btn_row.add_child(place_bid_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): detail_popup.visible = false)
	btn_row.add_child(cancel_btn)


func _place_bid(listing_id: String, amount: int) -> void:
	var url := _get_base_url() + "/api/marketplace/" + listing_id + "/bid"
	var body := JSON.stringify({"token": _get_token(), "amount": amount})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Market] Bid placed: %d coins" % amount)
			_refresh_browse()
		else:
			var err: String = json.get("error", "Bid failed") if json else "Bid failed"
			main._append_chat("[Market] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _show_listing_detail(listing: Dictionary) -> void:
	_clear_detail_popup()
	detail_popup.visible = true

	var title := Label.new()
	title.text = listing.get("itemName", "Unknown Item")
	title.add_theme_font_size_override("font_size", 18)
	detail_vbox.add_child(title)

	var type_label := Label.new()
	var listing_type: String = listing.get("listingType", "fixed")
	type_label.text = "Type: %s" % listing_type.capitalize()
	detail_vbox.add_child(type_label)

	var price_label := Label.new()
	price_label.text = "Price: %d coins" % int(listing.get("price", 0))
	detail_vbox.add_child(price_label)

	var seller_label := Label.new()
	seller_label.text = "Seller: %s" % listing.get("sellerName", "Unknown")
	detail_vbox.add_child(seller_label)

	if listing_type == "auction":
		var bid_label := Label.new()
		bid_label.text = "Current bid: %d coins" % int(listing.get("currentBid", listing.get("price", 0)))
		detail_vbox.add_child(bid_label)

		var end_label := Label.new()
		end_label.text = "Ends: %s" % listing.get("auctionEndTime", "N/A")
		detail_vbox.add_child(end_label)

	# Price history link
	var history_btn := Button.new()
	history_btn.text = "View Price History"
	var item_name: String = listing.get("itemName", "")
	history_btn.pressed.connect(func(): _fetch_price_history(item_name))
	detail_vbox.add_child(history_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): detail_popup.visible = false)
	detail_vbox.add_child(close_btn)


func _fetch_price_history(item_name: String) -> void:
	var url := _get_base_url() + "/api/marketplace/prices/" + item_name.uri_encode()

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("prices"):
			var prices: Array = json["prices"]
			if prices.is_empty():
				main._append_chat("[Market] No price history for %s" % item_name)
			else:
				main._append_chat("[Market] Price history for %s:" % item_name)
				for entry in prices.slice(0, 10):
					main._append_chat("  %d coins - %s" % [int(entry.get("price", 0)), entry.get("date", "")])
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _clear_detail_popup() -> void:
	for child in detail_vbox.get_children():
		child.queue_free()


# ── Sell Tab ─────────────────────────────────────────────────────────────────

func _build_sell_tab() -> void:
	sell_container = VBoxContainer.new()
	sell_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	sell_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_content.add_child(sell_container)

	var header := Label.new()
	header.text = "List an Item for Sale"
	header.add_theme_font_size_override("font_size", 16)
	sell_container.add_child(header)

	# Item selector
	var item_row := HBoxContainer.new()
	sell_container.add_child(item_row)
	var item_label := Label.new()
	item_label.text = "Item:"
	item_label.custom_minimum_size.x = 100
	item_row.add_child(item_label)
	sell_item_select = OptionButton.new()
	sell_item_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_row.add_child(sell_item_select)

	# Price input
	var price_row := HBoxContainer.new()
	sell_container.add_child(price_row)
	var price_label := Label.new()
	price_label.text = "Price:"
	price_label.custom_minimum_size.x = 100
	price_row.add_child(price_label)
	sell_price_input = SpinBox.new()
	sell_price_input.min_value = 1
	sell_price_input.max_value = 999999
	sell_price_input.value = 100
	sell_price_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_row.add_child(sell_price_input)

	# Listing type
	var type_row := HBoxContainer.new()
	sell_container.add_child(type_row)
	var type_label := Label.new()
	type_label.text = "Type:"
	type_label.custom_minimum_size.x = 100
	type_row.add_child(type_label)
	sell_type_select = OptionButton.new()
	sell_type_select.add_item("Fixed Price")
	sell_type_select.add_item("Auction")
	sell_type_select.item_selected.connect(_on_sell_type_changed)
	type_row.add_child(sell_type_select)

	# Auction duration (hidden by default)
	sell_duration_row = HBoxContainer.new()
	sell_duration_row.visible = false
	sell_container.add_child(sell_duration_row)
	var dur_label := Label.new()
	dur_label.text = "Duration (hrs):"
	dur_label.custom_minimum_size.x = 100
	sell_duration_row.add_child(dur_label)
	sell_duration_input = SpinBox.new()
	sell_duration_input.min_value = 1
	sell_duration_input.max_value = 168
	sell_duration_input.value = 24
	sell_duration_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_duration_row.add_child(sell_duration_input)

	# List button
	sell_button = Button.new()
	sell_button.text = "List Item"
	sell_button.pressed.connect(_on_list_item)
	sell_container.add_child(sell_button)

	# Status
	sell_status = Label.new()
	sell_status.text = ""
	sell_container.add_child(sell_status)


func _on_sell_type_changed(idx: int) -> void:
	sell_duration_row.visible = (idx == 1)  # Show duration for auctions


func _populate_sell_inventory() -> void:
	sell_item_select.clear()
	for item in main.inventory:
		sell_item_select.add_item("%s (%s)" % [item.get("name", "?"), item.get("kind", "?")])


func _on_list_item() -> void:
	if main.inventory.is_empty():
		sell_status.text = "No items in inventory."
		return

	var selected_idx := sell_item_select.selected
	if selected_idx < 0 or selected_idx >= main.inventory.size():
		sell_status.text = "Select an item first."
		return

	var item: Dictionary = main.inventory[selected_idx]
	var item_id: String = item.get("id", "")
	var price := int(sell_price_input.value)
	var listing_type := "fixed" if sell_type_select.selected == 0 else "auction"
	var auction_end_time := ""

	if listing_type == "auction":
		# Calculate end time from duration hours
		var hours := int(sell_duration_input.value)
		var unix_now := int(Time.get_unix_time_from_system())
		var end_unix := unix_now + hours * 3600
		var end_dt := Time.get_datetime_dict_from_unix_time(end_unix)
		auction_end_time = "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
			end_dt.year, end_dt.month, end_dt.day,
			end_dt.hour, end_dt.minute, end_dt.second
		]

	var url := _get_base_url() + "/api/marketplace/list"
	var body_dict := {
		"token": _get_token(),
		"itemId": item_id,
		"price": price,
		"listingType": listing_type,
	}
	if not auction_end_time.is_empty():
		body_dict["auctionEndTime"] = auction_end_time

	var body := JSON.stringify(body_dict)

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("listing"):
			sell_status.text = "Listed: %s" % json["listing"].get("itemName", "item")
			main._append_chat("[Market] Item listed successfully!")
		else:
			var err: String = json.get("error", "Listing failed") if json else "Listing failed"
			sell_status.text = err
			main._append_chat("[Market] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


# ── My Listings Tab ──────────────────────────────────────────────────────────

func _build_my_listings_tab() -> void:
	my_listings_container = VBoxContainer.new()
	my_listings_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	my_listings_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_content.add_child(my_listings_container)

	var header_row := HBoxContainer.new()
	my_listings_container.add_child(header_row)

	var header := Label.new()
	header.text = "My Active Listings"
	header.add_theme_font_size_override("font_size", 16)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_my_listings)
	header_row.add_child(refresh_btn)

	my_listings_scroll = ScrollContainer.new()
	my_listings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	my_listings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_listings_container.add_child(my_listings_scroll)

	my_listings_vbox = VBoxContainer.new()
	my_listings_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_listings_scroll.add_child(my_listings_vbox)


func _refresh_my_listings() -> void:
	var url := _get_base_url() + "/api/marketplace/history?token=" + _get_token()

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("listings"):
			cached_my_listings = json["listings"]
			_render_my_listings()
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _render_my_listings() -> void:
	for child in my_listings_vbox.get_children():
		child.queue_free()

	if cached_my_listings.is_empty():
		var empty_label := Label.new()
		empty_label.text = "You have no active listings."
		my_listings_vbox.add_child(empty_label)
		return

	for listing in cached_my_listings:
		var entry := PanelContainer.new()
		entry.custom_minimum_size = Vector2(0, 50)
		my_listings_vbox.add_child(entry)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		entry.add_child(hbox)

		var name_label := Label.new()
		name_label.text = listing.get("itemName", "Unknown")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)

		var price_label := Label.new()
		price_label.text = "%d coins" % int(listing.get("price", 0))
		hbox.add_child(price_label)

		var type_label := Label.new()
		var lt: String = listing.get("listingType", "fixed")
		type_label.text = lt.capitalize()
		hbox.add_child(type_label)

		var status_label_node := Label.new()
		status_label_node.text = listing.get("status", "active")
		hbox.add_child(status_label_node)

		if listing.get("status", "active") == "active":
			var cancel_btn := Button.new()
			cancel_btn.text = "Cancel"
			var lid: String = listing.get("id", "")
			cancel_btn.pressed.connect(func(): _cancel_listing(lid))
			hbox.add_child(cancel_btn)


func _cancel_listing(listing_id: String) -> void:
	var url := _get_base_url() + "/api/marketplace/" + listing_id
	var body := JSON.stringify({"token": _get_token()})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Market] Listing cancelled.")
			_refresh_my_listings()
		else:
			var err: String = json.get("error", "Cancel failed") if json else "Cancel failed"
			main._append_chat("[Market] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_DELETE, body)


# ── Trades Tab ───────────────────────────────────────────────────────────────

func _build_trades_tab() -> void:
	trades_container = VBoxContainer.new()
	trades_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	trades_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_content.add_child(trades_container)

	var header_row := HBoxContainer.new()
	trades_container.add_child(header_row)

	var header := Label.new()
	header.text = "Trade Offers"
	header.add_theme_font_size_override("font_size", 16)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_trades)
	header_row.add_child(refresh_btn)

	trades_scroll = ScrollContainer.new()
	trades_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trades_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trades_container.add_child(trades_scroll)

	trades_vbox = VBoxContainer.new()
	trades_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trades_scroll.add_child(trades_vbox)


func _refresh_trades() -> void:
	var url := _get_base_url() + "/api/trades?token=" + _get_token()

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.has("trades"):
			cached_trades = json["trades"]
			_render_trades()
		http.queue_free()
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _render_trades() -> void:
	for child in trades_vbox.get_children():
		child.queue_free()

	if cached_trades.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No pending trade offers."
		trades_vbox.add_child(empty_label)
		return

	var my_account_id: String = main.session.get("accountId", "")

	# Separate into incoming and outgoing
	var incoming: Array = []
	var outgoing: Array = []
	for trade in cached_trades:
		if trade.get("toAccountId", "") == my_account_id:
			incoming.append(trade)
		else:
			outgoing.append(trade)

	if not incoming.is_empty():
		var incoming_header := Label.new()
		incoming_header.text = "Incoming Offers"
		incoming_header.add_theme_font_size_override("font_size", 14)
		trades_vbox.add_child(incoming_header)

		for trade in incoming:
			var entry := _create_trade_entry(trade, true)
			trades_vbox.add_child(entry)

	if not outgoing.is_empty():
		var outgoing_header := Label.new()
		outgoing_header.text = "Outgoing Offers"
		outgoing_header.add_theme_font_size_override("font_size", 14)
		trades_vbox.add_child(outgoing_header)

		for trade in outgoing:
			var entry := _create_trade_entry(trade, false)
			trades_vbox.add_child(entry)


func _create_trade_entry(trade: Dictionary, is_incoming: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Trade summary
	var summary := Label.new()
	var offered_items: Array = trade.get("offeredItems", [])
	var offered_currency: int = trade.get("offeredCurrency", 0)
	var requested_items: Array = trade.get("requestedItems", [])
	var requested_currency: int = trade.get("requestedCurrency", 0)

	var offer_str := ""
	if not offered_items.is_empty():
		offer_str += "%d items" % offered_items.size()
	if offered_currency > 0:
		if not offer_str.is_empty():
			offer_str += " + "
		offer_str += "%d coins" % offered_currency
	if offer_str.is_empty():
		offer_str = "nothing"

	var request_str := ""
	if not requested_items.is_empty():
		request_str += "%d items" % requested_items.size()
	if requested_currency > 0:
		if not request_str.is_empty():
			request_str += " + "
		request_str += "%d coins" % requested_currency
	if request_str.is_empty():
		request_str = "nothing"

	if is_incoming:
		summary.text = "Offering: %s  |  Requesting: %s" % [offer_str, request_str]
	else:
		summary.text = "You offer: %s  |  You request: %s" % [offer_str, request_str]
	vbox.add_child(summary)

	var status_label := Label.new()
	status_label.text = "Status: %s" % trade.get("status", "pending")
	vbox.add_child(status_label)

	# Action buttons
	var btn_row := HBoxContainer.new()
	vbox.add_child(btn_row)

	var trade_id: String = trade.get("id", "")
	var trade_status: String = trade.get("status", "pending")

	if is_incoming and trade_status == "pending":
		var accept_btn := Button.new()
		accept_btn.text = "Accept"
		accept_btn.pressed.connect(func(): _accept_trade(trade_id))
		btn_row.add_child(accept_btn)

		var decline_btn := Button.new()
		decline_btn.text = "Decline"
		decline_btn.pressed.connect(func(): _decline_trade(trade_id))
		btn_row.add_child(decline_btn)

	return panel


func _accept_trade(trade_id: String) -> void:
	var url := _get_base_url() + "/api/trades/" + trade_id + "/accept"
	var body := JSON.stringify({"token": _get_token()})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Market] Trade accepted!")
			_refresh_trades()
		else:
			var err: String = json.get("error", "Accept failed") if json else "Accept failed"
			main._append_chat("[Market] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _decline_trade(trade_id: String) -> void:
	var url := _get_base_url() + "/api/trades/" + trade_id + "/decline"
	var body := JSON.stringify({"token": _get_token()})

	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, response_body):
		var json = JSON.parse_string(response_body.get_string_from_utf8())
		if json and json.get("ok", false):
			main._append_chat("[Market] Trade declined.")
			_refresh_trades()
		else:
			var err: String = json.get("error", "Decline failed") if json else "Decline failed"
			main._append_chat("[Market] %s" % err)
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


# ── Tab Switching ────────────────────────────────────────────────────────────

func _on_tab_changed(tab_idx: int) -> void:
	current_tab = tab_idx
	_show_tab(tab_idx)


func _show_tab(tab_idx: int) -> void:
	browse_container.visible = (tab_idx == 0)
	sell_container.visible = (tab_idx == 1)
	my_listings_container.visible = (tab_idx == 2)
	trades_container.visible = (tab_idx == 3)

	# Auto-refresh on tab switch
	match tab_idx:
		0: _refresh_browse()
		1: _populate_sell_inventory()
		2: _refresh_my_listings()
		3: _refresh_trades()


# ── Public API ───────────────────────────────────────────────────────────────

func show_panel() -> void:
	visible = true
	_show_tab(current_tab)


func hide_panel() -> void:
	visible = false
	detail_popup.visible = false
