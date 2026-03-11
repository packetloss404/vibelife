class_name GuildManager
extends RefCounted

var main  # reference to main node (untyped to avoid Variant issues)


func init(main_node) -> void:
	main = main_node


func load_guild_details(group_id: String) -> void:
	var request := HTTPRequest.new()
	main.add_child(request)
	var url := "%s/api/groups/%s/details" % [main.backend_url_input.text.rstrip("/"), group_id]
	if request.request(url) == OK:
		var result = await request.request_completed
		var response_code: int = result[1]
		if response_code == 200:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			if payload and payload.has("details"):
				main._append_chat("[Guild] Loaded details for group %s" % group_id)
		else:
			main._append_chat("[Guild] Failed to load guild details.")
	request.queue_free()


func assign_parcel(group_id: String, parcel_id: String) -> void:
	var request := HTTPRequest.new()
	main.add_child(request)
	var url := "%s/api/groups/%s/parcels" % [main.backend_url_input.text.rstrip("/"), group_id]
	var body := JSON.stringify({
		"token": main.session.get("token", ""),
		"parcelId": parcel_id
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result = await request.request_completed
		var response_code: int = result[1]
		if response_code == 200:
			main._append_chat("[Guild] Parcel assigned to group.")
		else:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			var err_msg = "Failed"
			if payload and payload.has("error"):
				err_msg = payload.error
			main._append_chat("[Guild] Assign parcel failed: %s" % err_msg)
	request.queue_free()


func deposit_treasury(group_id: String, amount: int) -> void:
	var request := HTTPRequest.new()
	main.add_child(request)
	var url := "%s/api/groups/%s/treasury/deposit" % [main.backend_url_input.text.rstrip("/"), group_id]
	var body := JSON.stringify({
		"token": main.session.get("token", ""),
		"amount": amount
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result = await request.request_completed
		var response_code: int = result[1]
		if response_code == 200:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			var treasury_bal = payload.get("treasury", 0) if payload else 0
			main._append_chat("[Guild] Deposited %d. Treasury: %d" % [amount, treasury_bal])
		else:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			var err_msg = "Failed"
			if payload and payload.has("error"):
				err_msg = payload.error
			main._append_chat("[Guild] Deposit failed: %s" % err_msg)
	request.queue_free()


func withdraw_treasury(group_id: String, amount: int) -> void:
	var request := HTTPRequest.new()
	main.add_child(request)
	var url := "%s/api/groups/%s/treasury/withdraw" % [main.backend_url_input.text.rstrip("/"), group_id]
	var body := JSON.stringify({
		"token": main.session.get("token", ""),
		"amount": amount
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result = await request.request_completed
		var response_code: int = result[1]
		if response_code == 200:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			var treasury_bal = payload.get("treasury", 0) if payload else 0
			main._append_chat("[Guild] Withdrew %d. Treasury: %d" % [amount, treasury_bal])
		else:
			var payload = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			var err_msg = "Failed"
			if payload and payload.has("error"):
				err_msg = payload.error
			main._append_chat("[Guild] Withdraw failed: %s" % err_msg)
	request.queue_free()


func set_member_role(group_id: String, account_id: String, role: String) -> void:
	var request := HTTPRequest.new()
	main.add_child(request)
	var url := "%s/api/groups/%s/members/%s/role" % [main.backend_url_input.text.rstrip("/"), group_id, account_id]
	var body := JSON.stringify({
		"token": main.session.get("token", ""),
		"role": role
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	if request.request(url, headers, HTTPClient.METHOD_PATCH, body) == OK:
		var result = await request.request_completed
		var response_code: int = result[1]
		if response_code == 200:
			main._append_chat("[Guild] Role updated to %s." % role)
		else:
			main._append_chat("[Guild] Failed to update role.")
	request.queue_free()


func set_emblem(group_id: String, color: String, icon: String) -> void:
	var request := HTTPRequest.new()
	main.add_child(request)
	var url := "%s/api/groups/%s/emblem" % [main.backend_url_input.text.rstrip("/"), group_id]
	var body := JSON.stringify({
		"token": main.session.get("token", ""),
		"color": color,
		"icon": icon
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	if request.request(url, headers, HTTPClient.METHOD_PATCH, body) == OK:
		var result = await request.request_completed
		var response_code: int = result[1]
		if response_code == 200:
			main._append_chat("[Guild] Emblem updated.")
		else:
			main._append_chat("[Guild] Failed to update emblem.")
	request.queue_free()


func propose_alliance(group_id: String, target_group_id: String) -> void:
	var request := HTTPRequest.new()
	main.add_child(request)
	var url := "%s/api/groups/%s/alliances" % [main.backend_url_input.text.rstrip("/"), group_id]
	var body := JSON.stringify({
		"token": main.session.get("token", ""),
		"targetGroupId": target_group_id
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	if request.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result = await request.request_completed
		var response_code: int = result[1]
		if response_code == 200:
			main._append_chat("[Guild] Alliance proposed.")
		else:
			main._append_chat("[Guild] Alliance proposal failed.")
	request.queue_free()


func send_group_chat(group_id: String, message: String) -> void:
	if main.websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		main._append_chat("[Guild] WebSocket not connected.")
		return
	main.websocket.send_text(JSON.stringify({
		"type": "group_chat",
		"groupId": group_id,
		"message": message
	}))
