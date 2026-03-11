class_name CreatorPanel
extends Control

## Creator Dashboard panel — asset submission, analytics, revenue, plugins.
## Visible only to accounts with the creator flag.

var main = null

# Sub-tab controls
var sub_tab_bar: HBoxContainer
var sub_content: Control
var active_sub_tab: String = ""
var sub_tabs: Dictionary = {}  # name -> { button: Button, content: Control }

# Submit tab
var submit_name_input: LineEdit
var submit_desc_input: LineEdit
var submit_category_select: OptionButton
var submit_file_input: LineEdit
var submit_button: Button
var submit_status_label: Label

# My Assets tab
var assets_list: ItemList
var assets_data: Array = []

# Analytics tab
var analytics_total_views: Label
var analytics_total_sales: Label
var analytics_total_revenue: Label
var analytics_breakdown_list: ItemList
var analytics_data: Array = []

# Revenue tab
var revenue_total_label: Label
var revenue_pending_label: Label
var payout_history_list: ItemList
var request_payout_button: Button
var payout_data: Array = []

# Plugins tab
var plugins_list: ItemList
var plugins_data: Array = []
var plugin_api_key_label: Label
var regenerate_key_button: Button
var selected_plugin_index: int = -1


func init(main_node) -> void:
	main = main_node
	name = "CreatorPanel"
	_build_ui()


func _get_base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _get_token() -> String:
	return main.session.get("token", "")


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 4)
	add_child(root_vbox)

	# Header
	var header := Label.new()
	header.text = "Creator Dashboard"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	root_vbox.add_child(header)

	# Sub-tab bar
	sub_tab_bar = HBoxContainer.new()
	sub_tab_bar.add_theme_constant_override("separation", 2)
	root_vbox.add_child(sub_tab_bar)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Content area
	sub_content = Control.new()
	sub_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(sub_content)

	# Build each sub-tab
	_build_submit_tab()
	_build_my_assets_tab()
	_build_analytics_tab()
	_build_revenue_tab()
	_build_plugins_tab()


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


# ── Submit Tab ─────────────────────────────────────────────────────────────

func _build_submit_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)

	var name_label := Label.new()
	name_label.text = "Asset Name:"
	panel.add_child(name_label)

	submit_name_input = LineEdit.new()
	submit_name_input.placeholder_text = "Enter asset name..."
	panel.add_child(submit_name_input)

	var desc_label := Label.new()
	desc_label.text = "Description:"
	panel.add_child(desc_label)

	submit_desc_input = LineEdit.new()
	submit_desc_input.placeholder_text = "Short description..."
	panel.add_child(submit_desc_input)

	var cat_label := Label.new()
	cat_label.text = "Category:"
	panel.add_child(cat_label)

	submit_category_select = OptionButton.new()
	for cat in ["model", "texture", "script", "audio", "animation", "particle", "other"]:
		submit_category_select.add_item(cat)
	panel.add_child(submit_category_select)

	var file_label := Label.new()
	file_label.text = "File Reference (asset path):"
	panel.add_child(file_label)

	submit_file_input = LineEdit.new()
	submit_file_input.placeholder_text = "/assets/models/my-asset.gltf"
	panel.add_child(submit_file_input)

	submit_button = Button.new()
	submit_button.text = "Submit Asset"
	submit_button.pressed.connect(_on_submit_asset)
	panel.add_child(submit_button)

	submit_status_label = Label.new()
	submit_status_label.text = ""
	submit_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	panel.add_child(submit_status_label)

	_register_sub_tab("Submit", panel)


func _on_submit_asset() -> void:
	var token := _get_token()
	if token.is_empty():
		submit_status_label.text = "Not logged in."
		return
	var asset_name := submit_name_input.text.strip_edges()
	var description := submit_desc_input.text.strip_edges()
	if asset_name.is_empty():
		submit_status_label.text = "Name is required."
		return

	var category := submit_category_select.get_item_text(submit_category_select.selected)
	var file_ref := submit_file_input.text.strip_edges()

	var url := "%s/api/creator/assets/submit" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"name": asset_name,
		"description": description,
		"category": category,
		"fileReference": file_ref
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray):
		var payload = JSON.parse_string(response_body.get_string_from_utf8())
		if response_code == 200 and payload:
			submit_status_label.text = "Submitted! Status: %s" % str(payload.get("submission", {}).get("status", "pending"))
			submit_name_input.clear()
			submit_desc_input.clear()
			submit_file_input.clear()
			load_my_assets()
		else:
			submit_status_label.text = "Submit failed: %s" % str(payload)
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	submit_status_label.text = "Submitting..."


# ── My Assets Tab ──────────────────────────────────────────────────────────

func _build_my_assets_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "My Submitted Assets"
	panel.add_child(title)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(load_my_assets)
	panel.add_child(refresh_btn)

	assets_list = ItemList.new()
	assets_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	assets_list.custom_minimum_size.y = 120
	panel.add_child(assets_list)

	_register_sub_tab("My Assets", panel)


func load_my_assets() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/creator/assets/submissions?token=%s" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("submissions"):
				assets_data = payload.submissions
				_render_assets_list()
		http.queue_free()
	)
	http.request(url)


func _render_assets_list() -> void:
	assets_list.clear()
	for asset in assets_data:
		var status: String = str(asset.get("status", "pending"))
		var badge := ""
		match status:
			"approved":
				badge = "[OK]"
			"rejected":
				badge = "[X]"
			_:
				badge = "[...]"
		var views := int(asset.get("views", 0))
		var sales := int(asset.get("sales", 0))
		assets_list.add_item("%s %s  views:%d  sales:%d" % [badge, str(asset.get("name", "")), views, sales])


# ── Analytics Tab ──────────────────────────────────────────────────────────

func _build_analytics_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Creator Analytics"
	panel.add_child(title)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Analytics"
	refresh_btn.pressed.connect(load_analytics)
	panel.add_child(refresh_btn)

	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 16)
	panel.add_child(summary_row)

	analytics_total_views = Label.new()
	analytics_total_views.text = "Views: 0"
	summary_row.add_child(analytics_total_views)

	analytics_total_sales = Label.new()
	analytics_total_sales.text = "Sales: 0"
	summary_row.add_child(analytics_total_sales)

	analytics_total_revenue = Label.new()
	analytics_total_revenue.text = "Revenue: 0"
	analytics_total_revenue.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	summary_row.add_child(analytics_total_revenue)

	var breakdown_label := Label.new()
	breakdown_label.text = "Per-Asset Breakdown:"
	panel.add_child(breakdown_label)

	analytics_breakdown_list = ItemList.new()
	analytics_breakdown_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	analytics_breakdown_list.custom_minimum_size.y = 100
	panel.add_child(analytics_breakdown_list)

	_register_sub_tab("Analytics", panel)


func load_analytics() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/creator/analytics?token=%s" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload:
				analytics_total_views.text = "Views: %d" % int(payload.get("totalViews", 0))
				analytics_total_sales.text = "Sales: %d" % int(payload.get("totalSales", 0))
				analytics_total_revenue.text = "Revenue: %d" % int(payload.get("totalRevenue", 0))
				analytics_data = payload.get("assets", [])
				_render_analytics_breakdown()
		http.queue_free()
	)
	http.request(url)


func _render_analytics_breakdown() -> void:
	analytics_breakdown_list.clear()
	for asset in analytics_data:
		analytics_breakdown_list.add_item("%s  views:%d  sales:%d  rev:%d" % [
			str(asset.get("name", "")),
			int(asset.get("views", 0)),
			int(asset.get("sales", 0)),
			int(asset.get("revenue", 0))
		])


# ── Revenue Tab ────────────────────────────────────────────────────────────

func _build_revenue_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Revenue & Payouts"
	panel.add_child(title)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Revenue"
	refresh_btn.pressed.connect(load_revenue)
	panel.add_child(refresh_btn)

	revenue_total_label = Label.new()
	revenue_total_label.text = "Total Earned: 0"
	revenue_total_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	panel.add_child(revenue_total_label)

	revenue_pending_label = Label.new()
	revenue_pending_label.text = "Pending Payout: 0"
	revenue_pending_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	panel.add_child(revenue_pending_label)

	request_payout_button = Button.new()
	request_payout_button.text = "Request Payout"
	request_payout_button.pressed.connect(_on_request_payout)
	panel.add_child(request_payout_button)

	var history_label := Label.new()
	history_label.text = "Payout History:"
	panel.add_child(history_label)

	payout_history_list = ItemList.new()
	payout_history_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	payout_history_list.custom_minimum_size.y = 100
	panel.add_child(payout_history_list)

	_register_sub_tab("Revenue", panel)


func load_revenue() -> void:
	var token := _get_token()
	if token.is_empty():
		return

	# Load revenue summary
	var url := "%s/api/creator/revenue?token=%s" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload:
				revenue_total_label.text = "Total Earned: %d" % int(payload.get("totalEarned", 0))
				revenue_pending_label.text = "Pending Payout: %d" % int(payload.get("pendingPayout", 0))
		http.queue_free()
	)
	http.request(url)

	# Load payout history
	var payouts_url := "%s/api/creator/revenue/payouts?token=%s" % [_get_base_url(), token]
	var http2 := HTTPRequest.new()
	main.add_child(http2)
	http2.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("payouts"):
				payout_data = payload.payouts
				_render_payout_history()
		http2.queue_free()
	)
	http2.request(payouts_url)


func _render_payout_history() -> void:
	payout_history_list.clear()
	for payout in payout_data:
		payout_history_list.add_item("%s  amount:%d  status:%s" % [
			str(payout.get("createdAt", "")),
			int(payout.get("amount", 0)),
			str(payout.get("status", ""))
		])


func _on_request_payout() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/creator/revenue/payouts" % _get_base_url()
	var body := JSON.stringify({"token": token})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray):
		var payload = JSON.parse_string(response_body.get_string_from_utf8())
		if response_code == 200 and payload:
			revenue_pending_label.text = "Payout requested!"
			load_revenue()
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


# ── Plugins Tab ────────────────────────────────────────────────────────────

func _build_plugins_tab() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Registered Plugins"
	panel.add_child(title)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Plugins"
	refresh_btn.pressed.connect(load_plugins)
	panel.add_child(refresh_btn)

	plugins_list = ItemList.new()
	plugins_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plugins_list.custom_minimum_size.y = 80
	plugins_list.item_selected.connect(_on_plugin_selected)
	panel.add_child(plugins_list)

	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 8)
	panel.add_child(key_row)

	var key_title := Label.new()
	key_title.text = "API Key:"
	key_row.add_child(key_title)

	plugin_api_key_label = Label.new()
	plugin_api_key_label.text = "********"
	plugin_api_key_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	plugin_api_key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(plugin_api_key_label)

	regenerate_key_button = Button.new()
	regenerate_key_button.text = "Regenerate Key"
	regenerate_key_button.pressed.connect(_on_regenerate_key)
	panel.add_child(regenerate_key_button)

	_register_sub_tab("Plugins", panel)


func load_plugins() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/creator/plugins?token=%s" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("plugins"):
				plugins_data = payload.plugins
				_render_plugins_list()
		http.queue_free()
	)
	http.request(url)


func _render_plugins_list() -> void:
	plugins_list.clear()
	selected_plugin_index = -1
	plugin_api_key_label.text = "********"
	for plugin in plugins_data:
		plugins_list.add_item("%s  [%s]" % [str(plugin.get("name", "")), str(plugin.get("status", "active"))])


func _on_plugin_selected(index: int) -> void:
	selected_plugin_index = index
	if index >= 0 and index < plugins_data.size():
		var key: String = str(plugins_data[index].get("apiKey", ""))
		if key.length() > 8:
			plugin_api_key_label.text = "%s...%s" % [key.substr(0, 4), key.substr(key.length() - 4)]
		else:
			plugin_api_key_label.text = "********"


func _on_regenerate_key() -> void:
	if selected_plugin_index < 0 or selected_plugin_index >= plugins_data.size():
		return
	var plugin_id: String = str(plugins_data[selected_plugin_index].get("id", ""))
	if plugin_id.is_empty():
		return
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/creator/plugins/%s/regenerate-key" % [_get_base_url(), plugin_id]
	var body := JSON.stringify({"token": token})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(response_body.get_string_from_utf8())
			if payload and payload.has("apiKey"):
				plugin_api_key_label.text = str(payload.apiKey)
			load_plugins()
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
