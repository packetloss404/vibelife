class_name EconomyPanel extends Control

var main = null

# Balance display
var balance_label: Label
var balance_value: int = 0
var balance_display: int = 0  # for animated count

# Send currency
var send_recipient_input: LineEdit
var send_amount_spin: SpinBox
var send_button: Button

# Transaction history
var transactions_container: VBoxContainer
var transactions_scroll: ScrollContainer

# Filter buttons
var filter_all_btn: Button
var filter_income_btn: Button
var filter_expenses_btn: Button
var active_filter: String = "all"

# Data
var transactions: Array = []

# Animation
var animating_balance: bool = false


func init(main_node) -> void:
	main = main_node
	name = "EconomyPanel"
	visible = false
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	var panel_bg := PanelContainer.new()
	panel_bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(panel_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel_bg.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# ── Header ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "Economy"
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	# ── Balance display ──
	var balance_panel := PanelContainer.new()
	balance_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(balance_panel)

	var balance_margin := MarginContainer.new()
	balance_margin.add_theme_constant_override("margin_left", 16)
	balance_margin.add_theme_constant_override("margin_right", 16)
	balance_margin.add_theme_constant_override("margin_top", 12)
	balance_margin.add_theme_constant_override("margin_bottom", 12)
	balance_panel.add_child(balance_margin)

	var balance_vbox := VBoxContainer.new()
	balance_vbox.add_theme_constant_override("separation", 4)
	balance_margin.add_child(balance_vbox)

	var balance_title := Label.new()
	balance_title.text = "Your Balance"
	balance_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	balance_vbox.add_child(balance_title)

	balance_label = Label.new()
	balance_label.text = "0 coins"
	balance_label.add_theme_font_size_override("font_size", 28)
	balance_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	balance_vbox.add_child(balance_label)

	# ── Send Currency Section ──
	var send_sep := HSeparator.new()
	root_vbox.add_child(send_sep)

	var send_label := Label.new()
	send_label.text = "Send Currency"
	send_label.add_theme_font_size_override("font_size", 16)
	root_vbox.add_child(send_label)

	var send_row := HBoxContainer.new()
	send_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(send_row)

	send_recipient_input = LineEdit.new()
	send_recipient_input.placeholder_text = "Recipient account ID"
	send_recipient_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_row.add_child(send_recipient_input)

	send_amount_spin = SpinBox.new()
	send_amount_spin.min_value = 1
	send_amount_spin.max_value = 999999
	send_amount_spin.value = 1
	send_amount_spin.step = 1
	send_amount_spin.custom_minimum_size = Vector2(100, 0)
	send_row.add_child(send_amount_spin)

	send_button = Button.new()
	send_button.text = "Send"
	send_button.pressed.connect(_on_send_currency)
	send_row.add_child(send_button)

	# ── Transaction History ──
	var tx_sep := HSeparator.new()
	root_vbox.add_child(tx_sep)

	var tx_header := HBoxContainer.new()
	tx_header.add_theme_constant_override("separation", 8)
	root_vbox.add_child(tx_header)

	var tx_title := Label.new()
	tx_title.text = "Transaction History"
	tx_title.add_theme_font_size_override("font_size", 16)
	tx_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx_header.add_child(tx_title)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_fetch_transactions)
	tx_header.add_child(refresh_btn)

	# Filter buttons
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 4)
	root_vbox.add_child(filter_row)

	filter_all_btn = Button.new()
	filter_all_btn.text = "[All]"
	filter_all_btn.pressed.connect(func(): _set_filter("all"))
	filter_row.add_child(filter_all_btn)

	filter_income_btn = Button.new()
	filter_income_btn.text = "Income"
	filter_income_btn.pressed.connect(func(): _set_filter("income"))
	filter_row.add_child(filter_income_btn)

	filter_expenses_btn = Button.new()
	filter_expenses_btn.text = "Expenses"
	filter_expenses_btn.pressed.connect(func(): _set_filter("expenses"))
	filter_row.add_child(filter_expenses_btn)

	# Scrollable transaction list
	transactions_scroll = ScrollContainer.new()
	transactions_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transactions_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(transactions_scroll)

	transactions_container = VBoxContainer.new()
	transactions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transactions_container.add_theme_constant_override("separation", 4)
	transactions_scroll.add_child(transactions_container)


func show_panel() -> void:
	visible = true
	_fetch_balance()
	_fetch_transactions()


func hide_panel() -> void:
	visible = false


func _get_base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _get_token() -> String:
	return main.session.get("token", "")


# ── Data Fetching ──────────────────────────────────────────────────────────

func _fetch_balance() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/currency/balance?token=%s" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("balance"):
				set_balance(int(payload.balance))
		http.queue_free()
	)
	http.request(url)


func _fetch_transactions() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var url := "%s/api/currency/transactions?token=%s&limit=50" % [_get_base_url(), token]
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(body.get_string_from_utf8())
			if payload and payload.has("transactions"):
				transactions = payload.transactions
				_render_transactions()
		http.queue_free()
	)
	http.request(url)


# ── Balance Animation ──────────────────────────────────────────────────────

func set_balance(new_balance: int) -> void:
	balance_value = new_balance
	main.currency_balance = new_balance
	# Update the HUD label in TopBar
	if main.has_method("_update_currency_hud"):
		main._update_currency_hud()
	animating_balance = true


func _process(delta: float) -> void:
	if animating_balance:
		if balance_display != balance_value:
			var diff := balance_value - balance_display
			var step := int(max(1, abs(diff) * delta * 5.0))
			if diff > 0:
				balance_display = mini(balance_display + step, balance_value)
			else:
				balance_display = maxi(balance_display - step, balance_value)
			balance_label.text = "%d coins" % balance_display
			# Color flash
			if diff > 0:
				balance_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
			else:
				balance_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		else:
			animating_balance = false
			balance_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))


# ── Rendering ──────────────────────────────────────────────────────────────

func _set_filter(filter: String) -> void:
	active_filter = filter
	filter_all_btn.text = "[All]" if filter == "all" else "All"
	filter_income_btn.text = "[Income]" if filter == "income" else "Income"
	filter_expenses_btn.text = "[Expenses]" if filter == "expenses" else "Expenses"
	_render_transactions()


func _render_transactions() -> void:
	for child in transactions_container.get_children():
		child.queue_free()

	if transactions.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No transactions yet."
		transactions_container.add_child(empty_label)
		return

	for tx in transactions:
		var amount: int = int(tx.get("amount", 0))
		var tx_type: String = tx.get("type", "")

		# Apply filter
		if active_filter == "income" and amount < 0:
			continue
		if active_filter == "expenses" and amount >= 0:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 28)
		transactions_container.add_child(row)

		# Type icon/label
		var type_label := Label.new()
		type_label.custom_minimum_size = Vector2(80, 0)
		var type_icon := ""
		match tx_type:
			"gift":
				type_icon = "[Gift]"
			"purchase", "buy":
				type_icon = "[Buy]"
			"sale", "sell":
				type_icon = "[Sell]"
			"loot":
				type_icon = "[Loot]"
			"death_penalty":
				type_icon = "[Death]"
			"tax":
				type_icon = "[Tax]"
			_:
				type_icon = "[%s]" % tx_type.capitalize()
		type_label.text = type_icon
		type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		row.add_child(type_label)

		# Amount (green for positive, red for negative)
		var amount_label := Label.new()
		amount_label.custom_minimum_size = Vector2(80, 0)
		if amount >= 0:
			amount_label.text = "+%d" % amount
			amount_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.2))
		else:
			amount_label.text = "%d" % amount
			amount_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		row.add_child(amount_label)

		# Description
		var desc_label := Label.new()
		desc_label.text = tx.get("description", "")
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(desc_label)

		# Timestamp
		var time_label := Label.new()
		time_label.text = _format_timestamp(tx.get("createdAt", tx.get("timestamp", "")))
		time_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(time_label)


# ── Actions ────────────────────────────────────────────────────────────────

func _on_send_currency() -> void:
	var token := _get_token()
	if token.is_empty():
		return
	var recipient := send_recipient_input.text.strip_edges()
	if recipient.is_empty():
		main._append_chat("System: Enter a recipient account ID")
		return
	var amount := int(send_amount_spin.value)
	if amount <= 0:
		main._append_chat("System: Amount must be positive")
		return
	if amount > balance_value:
		main._append_chat("System: Insufficient funds (balance: %d)" % balance_value)
		return

	var url := "%s/api/currency/send" % _get_base_url()
	var body := JSON.stringify({
		"token": token,
		"toAccountId": recipient,
		"amount": amount,
		"description": "gift"
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, resp_body: PackedByteArray):
		if response_code == 200:
			var payload = JSON.parse_string(resp_body.get_string_from_utf8())
			if payload and payload.has("balance"):
				set_balance(int(payload.balance))
			main._append_chat("System: Sent %d coins to %s" % [amount, recipient])
			send_recipient_input.text = ""
			send_amount_spin.value = 1
			_fetch_transactions()
		else:
			main._append_chat("System: Failed to send currency (insufficient funds?)")
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _format_timestamp(iso_string: String) -> String:
	if iso_string.is_empty():
		return ""
	var t_pos := iso_string.find("T")
	if t_pos < 0:
		return ""
	var time_part := iso_string.substr(t_pos + 1)
	if time_part.length() >= 5:
		return time_part.substr(0, 5)
	return time_part
