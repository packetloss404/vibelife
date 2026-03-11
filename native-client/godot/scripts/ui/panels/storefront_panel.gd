class_name StorefrontPanel
extends Control

## Storefront browsing, rating, commissions, and personal storefront management.

var main = null

# Sub-tab controls
var sub_tab_bar: HBoxContainer
var sub_content: Control
var active_sub_tab: String = ""
var sub_tabs: Dictionary = {}

# Browse tab
var storefronts_list: ItemList
var storefronts_data: Array = []
var selected_storefront_index: int = -1
var storefront_detail_label: Label
var storefront_items_list: ItemList
var storefront_items_data: Array = []
var rate_row: HBoxContainer
var rate_buttons: Array = []  # 5 star buttons

# Trending tab
var trending_list: ItemList
var trending_data: Array = []

# My Storefront tab
var my_storefront_name_input: LineEdit
var my_storefront_desc_input: LineEdit
var create_storefront_button: Button
var update_storefront_button: Button
var my_storefront_status: Label
var my_items_list: ItemList
var add_item_input: LineEdit
var add_item_price_input: LineEdit
var add_item_button: Button
var my_storefront_data: Dictionary = {}

# Commissions tab
var commission_desc_input: LineEdit
var commission_budget_input: LineEdit
var commission_deadline_input: LineEdit
var create_commission_button: Button
var commissions_list: ItemList
var commissions_data: Array = []
var commission_status_label: Label
var selected_commission_index: int = -1
var accept_commission_button: Button
var complete_commission_button: Button


func init(main_node) -> void:
	main = main_node
	name = "StorefrontPanel"
	_build_ui()


func _get_base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _get_token() -> String:
	return main.session.get("token", "")


func _get_account_id() -> String:
	return main.session.get("accountId", "")


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 4)
	add_child(root_vbox)

	var header := Label.new()
	header.text = "Storefronts"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	root_vbox.add_child(header)

	sub_tab_bar = HBoxContainer.new()
	sub_tab_bar.add_theme_constant_override("separation", 2)
	root_vbox.add_child(sub_tab_bar)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	sub_content = Control.new()
	sub_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(sub_content)

	_build_browse_tab()
	_build_trending_tab()
	_build_my_storefront_tab()
	_build_commissions_tab()


func _register_sub_tab(tab_name: String, control: Control) -> void:
	var btn := Button.new()
	btn.text = tab_name
	btn.toggle_mode = true
	btn.custom_minimum_size.x = 50
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): _switch_sub_tab(tab_name))
	sub_tab_bar.add_child(btn)

	control.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	control.visible = false
	sub_content.add_child(control)

	sub_tabs[tab_name] = {"button": btn, "content": control}

	if sub_tabs.size() == 1:
		_switch_sub_tab(tab_name)


func _switch_sub_tab(tab_name: String) -> void:
	if not sub_tabs.has(tab_name):
		return
	if active_sub_tab == tab_name:
		return
	if not active_sub_tab.is_empty() and sub_tabs.has(active_sub_tab):
		sub_tabs[active_sub_tab].content.visible = false
		sub_tabs[active_sub_tab].button.button_pressed = false
	active_sub_tab = tab_name
	sub_tabs[active_sub_tab].content.visible = true
	sub_tabs[active_sub_tab].button.button_pressed = true


# ── Browse Tab ─────────────────────────────────────────────────────────────

func _build_browse_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Storefronts"
	refresh_btn.pressed.connect(load_storefronts)
	panel.add_child(refresh_btn)

	storefronts_list = ItemList.new()
	storefronts_list.custom_minimum_size.y = 80
	storefronts_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	storefronts_list.item_selected.connect(_on_storefront_selected)
	panel.add_child(storefronts_list)

	storefront_detail_label = Label.new()
	storefront_detail_label.text = "Select a storefront to view details"
	storefront_detail_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	panel.add_child(storefront_detail_label)

	storefront_items_list = ItemList.new()
	storefront_items_list.custom_minimum_size.y = 60
	panel.add_child(storefront_items_list)

	# Rating row
	var rate_label := Label.new()
	rate_label.text = "Rate this storefront:"
	panel.add_child(rate_label)

	rate_row = HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 4)
	panel.add_child(rate_row)

	for i in range(1, 6):
		var star_btn := Button.new()
		star_btn.text = str(i)
		star_btn.custom_minimum_size = Vector2(36, 30)
		var rating := i
		star_btn.pressed.connect(func(): _rate_storefront(rating))
		rate_row.add_child(star_btn)
		rate_buttons.append(star_btn)

	_register_sub_tab("Browse", panel)


func load_storefronts() -> void:
	var url := "%s/api/storefronts" % _get_base_url()
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("storefronts"):
				storefronts_data = payload.storefronts
				_render_storefronts_list()
		http.queue_free()
	)
	http.request(url)


func _render_storefronts_list() -> void:
	storefronts_list.clear()
	selected_storefront_index = -1
	for sf in storefronts_data:
		var rating_val: float = float(sf.get("rating", 0))
		var star_text := "%.1f" % rating_val
		storefronts_list.add_item("%s  [%s stars]  by %s" % [
			str(sf.get("name", "Unnamed")),
			star_text,
			str(sf.get("ownerName", ""))
		])


func _on_storefront_selected(index: int) -> void:
	selected_storefront_index = index
	if index < 0 or index >= storefronts_data.size():
		return
	var sf: Dictionary = storefronts_data[index]
	storefront_detail_label.text = "%s - %s\nRating: %.1f | Items: %d" % [
		str(sf.get("name", "")),
		str(sf.get("description", "")),
		float(sf.get("rating", 0)),
		int(sf.get("itemCount", 0))
	]
	# Load storefront items
	var account_id: String = str(sf.get("accountId", ""))
	if not account_id.is_empty():
		_load_storefront_items(account_id)


func _load_storefront_items(account_id: String) -> void:
	var url := "%s/api/storefronts/%s" % [_get_base_url(), account_id]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("storefront"):
				storefront_items_data = payload.storefront.get("items", [])
				_render_storefront_items()
		http.queue_free()
	)
	http.request(url)


func _render_storefront_items() -> void:
	storefront_items_list.clear()
	for item in storefront_items_data:
		storefront_items_list.add_item("%s  price:%d" % [
			str(item.get("name", "")),
			int(item.get("price", 0))
		])


func _rate_storefront(rating: int) -> void:
	if selected_storefront_index < 0 or selected_storefront_index >= storefronts_data.size():
		return
	var token := _get_token()
	if token.is_empty():
		return
	var account_id: String = str(storefronts_data[selected_storefront_index].get("accountId", ""))
	if account_id.is_empty():
		return
	var url := "%s/api/storefronts/%s/rate" % [_get_base_url(), account_id]
	var body := JSON.stringify({"token": token, "rating": rating})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			storefront_detail_label.text += "\nRated %d stars!" % rating
			load_storefronts()
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


# ── Trending Tab ───────────────────────────────────────────────────────────

func _build_trending_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Trending Items"
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	panel.add_child(title)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Trending"
	refresh_btn.pressed.connect(load_trending)
	panel.add_child(refresh_btn)

	trending_list = ItemList.new()
	trending_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trending_list.custom_minimum_size.y = 120
	panel.add_child(trending_list)

	_register_sub_tab("Trending", panel)


func load_trending() -> void:
	var url := "%s/api/marketplace/trending" % _get_base_url()
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("items"):
				trending_data = payload.items
				_render_trending()
		http.queue_free()
	)
	http.request(url)


func _render_trending() -> void:
	trending_list.clear()
	for item in trending_data:
		trending_list.add_item("%s  price:%d  seller:%s" % [
			str(item.get("name", "")),
			int(item.get("price", 0)),
			str(item.get("sellerName", ""))
		])


# ── My Storefront Tab ─────────────────────────────────────────────────────

func _build_my_storefront_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "My Storefront"
	panel.add_child(title)

	var name_label := Label.new()
	name_label.text = "Storefront Name:"
	panel.add_child(name_label)

	my_storefront_name_input = LineEdit.new()
	my_storefront_name_input.placeholder_text = "My awesome shop"
	panel.add_child(my_storefront_name_input)

	var desc_label := Label.new()
	desc_label.text = "Description:"
	panel.add_child(desc_label)

	my_storefront_desc_input = LineEdit.new()
	my_storefront_desc_input.placeholder_text = "What we sell..."
	panel.add_child(my_storefront_desc_input)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	panel.add_child(btn_row)

	create_storefront_button = Button.new()
	create_storefront_button.text = "Create"
	create_storefront_button.pressed.connect(_on_create_storefront)
	btn_row.add_child(create_storefront_button)

	update_storefront_button = Button.new()
	update_storefront_button.text = "Update"
	update_storefront_button.pressed.connect(_on_update_storefront)
	btn_row.add_child(update_storefront_button)

	my_storefront_status = Label.new()
	my_storefront_status.text = ""
	my_storefront_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	panel.add_child(my_storefront_status)

	var items_header := Label.new()
	items_header.text = "My Items:"
	panel.add_child(items_header)

	my_items_list = ItemList.new()
	my_items_list.custom_minimum_size.y = 60
	panel.add_child(my_items_list)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 4)
	panel.add_child(add_row)

	add_item_input = LineEdit.new()
	add_item_input.placeholder_text = "Item ID"
	add_item_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(add_item_input)

	add_item_price_input = LineEdit.new()
	add_item_price_input.placeholder_text = "Price"
	add_item_price_input.custom_minimum_size.x = 60
	add_row.add_child(add_item_price_input)

	add_item_button = Button.new()
	add_item_button.text = "Add"
	add_item_button.pressed.connect(_on_add_item)
	add_row.add_child(add_item_button)

	_register_sub_tab("My Shop", panel)


func load_my_storefront() -> void:
	var account_id := _get_account_id()
	if account_id.is_empty():
		return
	var url := "%s/api/storefronts/%s" % [_get_base_url(), account_id]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("storefront"):
				my_storefront_data = payload.storefront
				my_storefront_name_input.text = str(my_storefront_data.get("name", ""))
				my_storefront_desc_input.text = str(my_storefront_data.get("description", ""))
				var items: Array = my_storefront_data.get("items", [])
				my_items_list.clear()
				for item in items:
					my_items_list.add_item("%s  price:%d" % [str(item.get("name", "")), int(item.get("price", 0))])
				my_storefront_status.text = "Storefront loaded"
		http.queue_free()
	)
	http.request(url)


func _on_create_storefront() -> void:
	var token := _get_token()
	if token.is_empty():
		my_storefront_status.text = "Not logged in."
		return
	var sf_name := my_storefront_name_input.text.strip_edges()
	if sf_name.is_empty():
		my_storefront_status.text = "Name required."
		return
	var url := "%s/api/storefronts" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"name": sf_name,
		"description": my_storefront_desc_input.text.strip_edges()
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray):
		if response_code == 200:
			my_storefront_status.text = "Storefront created!"
			load_my_storefront()
		else:
			var payload = JSON.parse_string(response_body.get_string_from_utf8())
			my_storefront_status.text = "Failed: %s" % str(payload)
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_update_storefront() -> void:
	var token := _get_token()
	if token.is_empty():
		my_storefront_status.text = "Not logged in."
		return
	var url := "%s/api/storefronts" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"name": my_storefront_name_input.text.strip_edges(),
		"description": my_storefront_desc_input.text.strip_edges()
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			my_storefront_status.text = "Storefront updated!"
		else:
			my_storefront_status.text = "Update failed"
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, body)


func _on_add_item() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var item_id := add_item_input.text.strip_edges()
	var price_text := add_item_price_input.text.strip_edges()
	if item_id.is_empty() or price_text.is_empty():
		my_storefront_status.text = "Item ID and price required."
		return
	# Use the storefront update endpoint to add items
	var url := "%s/api/storefronts" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"addItem": {"itemId": item_id, "price": int(price_text)}
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			add_item_input.clear()
			add_item_price_input.clear()
			my_storefront_status.text = "Item added!"
			load_my_storefront()
		else:
			my_storefront_status.text = "Failed to add item"
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, body)


# ── Commissions Tab ────────────────────────────────────────────────────────

func _build_commissions_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Commissions"
	title.add_theme_color_override("font_color", Color(0.9, 0.6, 1.0))
	panel.add_child(title)

	var create_label := Label.new()
	create_label.text = "Create Commission:"
	panel.add_child(create_label)

	commission_desc_input = LineEdit.new()
	commission_desc_input.placeholder_text = "Describe what you need..."
	panel.add_child(commission_desc_input)

	var budget_row := HBoxContainer.new()
	budget_row.add_theme_constant_override("separation", 4)
	panel.add_child(budget_row)

	commission_budget_input = LineEdit.new()
	commission_budget_input.placeholder_text = "Budget"
	commission_budget_input.custom_minimum_size.x = 80
	budget_row.add_child(commission_budget_input)

	commission_deadline_input = LineEdit.new()
	commission_deadline_input.placeholder_text = "Deadline (days)"
	commission_deadline_input.custom_minimum_size.x = 100
	budget_row.add_child(commission_deadline_input)

	create_commission_button = Button.new()
	create_commission_button.text = "Create"
	create_commission_button.pressed.connect(_on_create_commission)
	budget_row.add_child(create_commission_button)

	commission_status_label = Label.new()
	commission_status_label.text = ""
	commission_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	panel.add_child(commission_status_label)

	var sep := HSeparator.new()
	panel.add_child(sep)

	var list_header := HBoxContainer.new()
	list_header.add_theme_constant_override("separation", 4)
	panel.add_child(list_header)

	var list_label := Label.new()
	list_label.text = "Commissions:"
	list_header.add_child(list_label)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(load_commissions)
	list_header.add_child(refresh_btn)

	commissions_list = ItemList.new()
	commissions_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	commissions_list.custom_minimum_size.y = 80
	commissions_list.item_selected.connect(_on_commission_selected)
	panel.add_child(commissions_list)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 4)
	panel.add_child(action_row)

	accept_commission_button = Button.new()
	accept_commission_button.text = "Accept"
	accept_commission_button.pressed.connect(_on_accept_commission)
	action_row.add_child(accept_commission_button)

	complete_commission_button = Button.new()
	complete_commission_button.text = "Complete"
	complete_commission_button.pressed.connect(_on_complete_commission)
	action_row.add_child(complete_commission_button)

	_register_sub_tab("Commissions", panel)


func load_commissions() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/commissions?token=%s" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("commissions"):
				commissions_data = payload.commissions
				_render_commissions()
		http.queue_free()
	)
	http.request(url)


func _render_commissions() -> void:
	commissions_list.clear()
	selected_commission_index = -1
	for c in commissions_data:
		var status: String = str(c.get("status", "open"))
		commissions_list.add_item("[%s] %s  budget:%d" % [
			status.to_upper(),
			str(c.get("description", "")),
			int(c.get("budget", 0))
		])


func _on_commission_selected(index: int) -> void:
	selected_commission_index = index


func _on_create_commission() -> void:
	var token := _get_token()
	if token.is_empty():
		commission_status_label.text = "Not logged in."
		return
	var desc := commission_desc_input.text.strip_edges()
	if desc.is_empty():
		commission_status_label.text = "Description required."
		return
	var budget := int(commission_budget_input.text.strip_edges()) if not commission_budget_input.text.strip_edges().is_empty() else 0
	var deadline := int(commission_deadline_input.text.strip_edges()) if not commission_deadline_input.text.strip_edges().is_empty() else 7

	var url := "%s/api/commissions" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"description": desc,
		"budget": budget,
		"deadlineDays": deadline
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			commission_status_label.text = "Commission created!"
			commission_desc_input.clear()
			commission_budget_input.clear()
			commission_deadline_input.clear()
			load_commissions()
		else:
			commission_status_label.text = "Failed to create commission"
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_accept_commission() -> void:
	if selected_commission_index < 0 or selected_commission_index >= commissions_data.size():
		return
	var token := _get_token()
	if token.is_empty():
		return
	var commission_id: String = str(commissions_data[selected_commission_index].get("id", ""))
	if commission_id.is_empty():
		return
	var url := "%s/api/commissions/%s/accept" % [_get_base_url(), commission_id]
	var body := JSON.stringify({"token": token})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			commission_status_label.text = "Commission accepted!"
			load_commissions()
		else:
			commission_status_label.text = "Failed to accept"
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_complete_commission() -> void:
	if selected_commission_index < 0 or selected_commission_index >= commissions_data.size():
		return
	var token := _get_token()
	if token.is_empty():
		return
	var commission_id: String = str(commissions_data[selected_commission_index].get("id", ""))
	if commission_id.is_empty():
		return
	var url := "%s/api/commissions/%s/complete" % [_get_base_url(), commission_id]
	var body := JSON.stringify({"token": token})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			commission_status_label.text = "Commission completed!"
			load_commissions()
		else:
			commission_status_label.text = "Failed to complete"
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
