class_name SessionCoordinator
extends RefCounted

const WS_SNAPSHOT := "snapshot"

## Emitted for every WebSocket event so panels can subscribe and filter by type.
signal ws_event_received(event_type: String, data: Dictionary)

var main


func init(main_node) -> void:
	main = main_node


func fetch_regions() -> void:
	main.status_label.text = "Fetching regions..."
	main.status_pill.text = "Loading regions"
	main.region_select.clear()
	var url := "%s/api/regions" % main.backend_url
	var error: int = main.regions_request.request(url)
	if error != OK:
		main.status_label.text = "Region request failed: %s" % error


func on_regions_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		main.status_label.text = "Region request returned %s" % response_code
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	main.regions = payload.get("regions", [])
	main.region_select.clear()
	for region in main.regions:
		main.region_select.add_item("%s - %s/%s" % [region.name, region.population, region.capacity])
	main.status_label.text = "Ready to join."
	main.status_pill.text = "Ready"
	main._save_login_state()
	main._apply_client_settings()


func join_world() -> void:
	if main.regions.is_empty():
		main.status_label.text = "No regions available yet."
		return
	var chosen_region: Dictionary = main.regions[main.region_select.selected]
	var auth_modes := ["guest", "register", "login"]
	var auth_mode = auth_modes[main.auth_mode_select.selected]
	var body := JSON.stringify({
		"displayName": main.display_name_input.text,
		"regionId": chosen_region.id,
		"password": main.password_input.text
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := "%s/api/auth/%s" % [main.backend_url, auth_mode]
	var error: int = main.auth_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		main.status_label.text = "Auth request failed: %s" % error


func on_auth_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		main.status_label.text = "Join request returned %s" % response_code
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	main.session = payload.get("session", {})
	main.avatars.avatar_states.clear()
	main.avatars.avatar_states[payload.avatar.avatarId] = payload.avatar
	main.status_label.text = "Connected as %s" % main.session.displayName
	main.status_pill.text = "Connected"
	main._save_login_state()
	main._apply_client_settings()
	main.inventory = payload.get("inventory", [])
	main.parcels_mgr.parcels = payload.get("parcels", [])
	main._render_inventory()
	main.parcels_mgr.render_parcels()
	await main.parcels_mgr.load_admin_audit_logs()
	_apply_region_biome(main.session.regionId)
	main._append_chat("System: joined %s" % main.session.regionId)
	# Auto-collapse sidebar after joining to give more viewport space
	if not main._sidebar_collapsed:
		main._toggle_sidebar()
	main.voxel_mgr.configure(main.session.regionId, main.session.token, main.backend_url)
	# Fetch currency balance on login
	main._fetch_currency_balance()
	await load_region_scene(main.session.regionId)
	await load_region_objects(main.session.regionId)
	main.avatars.sync_avatars()
	connect_websocket()


func _apply_region_biome(region_id: String) -> void:
	var biome_data = {}
	for region in main.regions:
		if region.get("id", "") == region_id:
			biome_data = region.get("biome", {})
			break
	if not biome_data.is_empty():
		main.biome_mgr.apply_biome(biome_data)
		var fog_density = biome_data.get("fogDensity", 0.01)
		main.weather.set_base_fog_density(float(fog_density))
		var weather_type = biome_data.get("weatherType", "clear")
		main.weather.set_weather(str(weather_type))


func load_region_scene(region_id: String) -> void:
	for child in main.static_world.get_children():
		child.queue_free()
	var url := "%s/scenes/%s.json" % [main.backend_url, region_id]
	var error: int = main.scene_request.request(url)
	if error != OK:
		main.status_label.text = "Scene request failed: %s" % error
		return
	await main.scene_request.request_completed


func on_scene_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		main.status_label.text = "Scene request returned %s" % response_code
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	main.objects.load_scene_assets(payload)


func load_region_objects(region_id: String) -> void:
	var url := "%s/api/regions/%s/objects" % [main.backend_url, region_id]
	var error: int = main.objects_request.request(url)
	if error != OK:
		main.status_label.text = "Objects request failed: %s" % error
		return
	await main.objects_request.request_completed


func on_objects_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		main.status_label.text = "Objects request returned %s" % response_code
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	main.objects.sync_objects(payload.get("objects", []))
	main.build.update_selection_state()


func connect_websocket() -> void:
	if main.websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		main.websocket.close()
	main.websocket = WebSocketPeer.new()
	var base: String = main.backend_url_input.text.rstrip("/")
	var ws_url: String = base.replace("http://", "ws://").replace("https://", "wss://")
	ws_url += "/ws/regions/%s?token=%s&lastSequence=%s" % [main.session.regionId, main.session.token, str(main.last_sequence)]
	var error: int = main.websocket.connect_to_url(ws_url)
	if error != OK:
		main.status_label.text = "WebSocket failed: %s" % error
		main.status_pill.text = "Socket failed"


func poll_websocket() -> void:
	if main.websocket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		if not main.session.is_empty():
			main.status_pill.text = "Disconnected"
		return
	main.websocket.poll()
	if main.websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if main.status_pill.text != "Online":
			main.status_pill.text = "Online"
	while main.websocket.get_available_packet_count() > 0:
		var payload = JSON.parse_string(main.websocket.get_packet().get_string_from_utf8())
		handle_socket_message(payload)


func handle_socket_message(message: Dictionary) -> void:
	var event_type: String = message.get("type", "")
	# Emit signal for all events so panels can subscribe
	ws_event_received.emit(event_type, message)

	match event_type:
		WS_SNAPSHOT:
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			main.avatars.avatar_states.clear()
			for avatar in message.get("avatars", []):
				main.avatars.avatar_states[avatar.avatarId] = avatar
			main.parcels_mgr.parcels = message.get("parcels", main.parcels_mgr.parcels)
			main.avatars.sync_avatars()
			main.objects.sync_objects(message.get("objects", []))
			if main.enemy_renderer and message.has("enemies"):
				main.enemy_renderer.sync_enemies(message.get("enemies", []))
			if main.combat_hud and message.has("combatStats"):
				main.combat_hud.update_stats(message.combatStats)
			for chat_entry in message.get("chatHistory", []):
				var ts: String = main._format_chat_timestamp(chat_entry.get("createdAt", ""))
				var chat_msg: String = str(chat_entry.get("message", ""))
				# Skip raw JSON data in system messages (e.g. NPC spawn data)
				if chat_msg.begins_with("{") or chat_msg.begins_with("["):
					continue
				if chat_entry.get("avatarId", "") == "system":
					main._append_chat("[%s] [System] %s" % [ts, chat_msg])
				else:
					main._append_chat("[%s] %s: %s" % [ts, chat_entry.get("displayName", ""), chat_msg])
		"avatar:joined", "avatar:moved", "avatar:updated":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			var avatar = message.avatar
			main.avatars.avatar_states[avatar.avatarId] = avatar
			main.avatars.sync_avatars()
		"parcel:updated":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			main.parcels_mgr.update_parcel_from_event(message.parcel)
			main.parcels_mgr.render_parcels()
			main.parcels_mgr.claim_button_state()
		"avatar:left":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			main.chat_bubbles.cleanup_avatar(message.avatarId)
			main.avatars.avatar_states.erase(message.avatarId)
			main.avatars.sync_avatars()
		"chat":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			var ts: String = main._format_chat_timestamp(message.get("createdAt", ""))
			if message.get("avatarId", "") == "system":
				main._append_chat("[%s] [System] %s" % [ts, message.message])
			else:
				main._append_chat("[%s] %s: %s" % [ts, message.displayName, message.message])
			main.chat_bubbles.show_bubble(message.get("avatarId", ""), message.get("message", ""))
		"avatar:typing":
			main.chat_bubbles.show_typing(message.get("avatarId", ""), message.get("typing", false))
		"chat:history":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			for entry in message.get("messages", []):
				var hist_ts: String = main._format_chat_timestamp(entry.get("createdAt", ""))
				main._append_chat("[%s] %s: %s" % [hist_ts, entry.get("displayName", ""), entry.get("message", "")])
		"whisper":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			var whisper_ts: String = main._format_chat_timestamp(message.get("createdAt", ""))
			var from_id: String = message.get("fromAvatarId", "")
			var my_avatar_id: String = main.session.get("avatarId", "")
			if from_id == my_avatar_id:
				main._append_chat("[%s] [whisper to %s] %s" % [whisper_ts, message.get("toDisplayName", ""), message.message])
			else:
				main._append_chat("[%s] [whisper from %s] %s" % [whisper_ts, message.get("fromDisplayName", ""), message.message])
		"object:created", "object:updated":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			main.objects.sync_single_object(message.object)
		"object:deleted":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			if main.objects.object_nodes.has(message.objectId):
				main.objects.object_nodes[message.objectId].queue_free()
				main.objects.object_nodes.erase(message.objectId)
		"radio:changed":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			main.radio.handle_radio_changed(message)
			main._append_chat("Radio: Now playing %s on %s" % [message.get("trackName", ""), message.get("stationName", "")])
		"avatar:emote":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			var emote_avatar_id: String = message.get("avatarId", "")
			var emote_name: String = message.get("emoteName", "")
			var emote_display: String = message.get("displayName", "")
			main.avatars.handle_emote_event(emote_avatar_id, emote_name)
			main._append_chat("%s performs %s" % [emote_display, emote_name])
		"emote:combo":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			main.emote_panel.handle_emote_combo(message)
		"avatar:sit":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			main.avatars.handle_sit(str(message.avatarId), str(message.objectId), message.position)
		"avatar:stand":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			main.avatars.handle_stand(str(message.avatarId))
		"voxel:block_placed":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			if main.voxel_mgr:
				main.voxel_mgr.apply_block_delta(int(message.x), int(message.y), int(message.z), int(message.blockTypeId))
		"voxel:block_broken":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			if main.voxel_mgr:
				main.voxel_mgr.apply_block_delta(int(message.x), int(message.y), int(message.z), 0)
		"combat:damage":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			if main.enemy_renderer:
				main.enemy_renderer.update_enemy_health(str(message.targetId), int(message.targetHp), int(message.targetMaxHp))
			if main.combat_hud:
				var target_pos := Vector3(0, 2, 0)
				if main.enemy_renderer and main.enemy_renderer.enemy_nodes.has(str(message.targetId)):
					target_pos = main.enemy_renderer.enemy_nodes[str(message.targetId)].global_position + Vector3(0, 1.5, 0)
				main.combat_hud.show_damage_number(target_pos, int(message.damage), bool(message.get("critical", false)))
		"combat:death":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			var dead_account: String = message.get("accountId", "")
			if dead_account == main.session.get("accountId", ""):
				if main.combat_hud:
					main.combat_hud.show_death_overlay()
				main._append_chat("System: You died! Respawning...")
				# Refresh currency after death penalty
				main._fetch_currency_balance()
			else:
				main._append_chat("System: A player has fallen!")
		"combat:respawn":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"combat:loot":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			var loot_account: String = message.get("accountId", "")
			if loot_account == main.session.get("accountId", ""):
				var loot_items: Array = message.get("items", [])
				var loot_currency: int = int(message.get("currency", 0))
				if main.combat_hud:
					main.combat_hud.show_loot_notification(loot_items)
				main._append_chat("System: Looted %d currency" % loot_currency)
				# Update currency HUD after loot
				main.currency_balance += loot_currency
				main._update_currency_hud()
				if main.economy_panel:
					main.economy_panel.set_balance(main.currency_balance)
		"combat:level_up":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			var levelup_account: String = message.get("accountId", "")
			if levelup_account == main.session.get("accountId", ""):
				if main.combat_hud:
					main.combat_hud.show_level_up(int(message.newLevel))
				main._append_chat("System: Level up! You are now level %d" % int(message.newLevel))
		"enemy:spawned":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			if main.enemy_renderer:
				main.enemy_renderer.sync_enemies([message.enemy])
		"enemy:moved":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			if main.enemy_renderer:
				main.enemy_renderer.sync_enemies(message.get("enemies", []))
		"enemy:despawned":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			if main.enemy_renderer:
				main.enemy_renderer.play_death_animation(str(message.enemyId))
		# ── Previously-ignored event types ───────────────────────────
		# These are now routed via ws_event_received signal so panels can handle them.
		"pet:summoned":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"pet:dismissed":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"pet:trick":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"pet:state_updated":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"media:created":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"media:updated":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"media:removed":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"voice:participant_joined":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"voice:participant_left":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"voice:speaking_changed":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"group:chat":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"home:doorbell":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"event:started":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"event:ended":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
		"npc:positions":
			main.last_sequence = maxi(main.last_sequence, int(message.get("sequence", 0)))
			# NPC position updates handled silently (future: render NPC avatars)
