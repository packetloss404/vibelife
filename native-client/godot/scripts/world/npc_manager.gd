# NPC Manager — Feature 19: AI NPCs for VibeLife
#
# INTEGRATION NOTES (do NOT auto-apply):
# - main.gd: Add the following to create and initialize this manager:
#     var npc_manager = NpcManager.new()
#     npc_manager.init(self)
#   Call npc_manager.process_tick(delta) from _process()
#   Call npc_manager.on_ws_message(parsed) in your WS message handler
#   Call npc_manager.cleanup() when leaving a region
#
# Uses main.backend_url_input.text.rstrip("/") for backend URL
# Uses main.session.get("token", "") for auth token

class_name NpcManager
extends RefCounted

var main

# NPC data keyed by npc id
var npc_data := {}
# 3D nodes keyed by npc id
var npc_nodes := {}
# Active dialogue state
var active_dialogue := {}
# Player quest states
var player_quests := {}
# Whether dialogue UI is open
var dialogue_open := false
# Interaction prompt target
var interaction_target := ""
# Quest tracker data
var tracked_quests: Array = []
# Tick accumulator for NPC animation
var anim_accumulator := 0.0

# HTTP request nodes (created dynamically)
var _npcs_request: HTTPRequest
var _interact_request: HTTPRequest
var _dialogue_request: HTTPRequest
var _quests_request: HTTPRequest
var _quest_complete_request: HTTPRequest
var _quest_progress_request: HTTPRequest
var _spawn_request: HTTPRequest

# UI elements (created dynamically)
var _dialogue_panel: PanelContainer
var _dialogue_label: RichTextLabel
var _dialogue_options_container: VBoxContainer
var _npc_name_label: Label
var _quest_tracker_panel: PanelContainer
var _quest_tracker_vbox: VBoxContainer
var _interaction_prompt: Label

const INTERACT_DISTANCE := 5.0
const NPC_BOB_SPEED := 2.0
const NPC_BOB_HEIGHT := 0.15
const NAME_TAG_OFFSET := Vector3(0, 2.5, 0)

func init(main_node) -> void:
	main = main_node
	_create_http_requests()
	_create_ui()
	_fetch_npcs()
	_fetch_quests()

func _create_http_requests() -> void:
	_npcs_request = HTTPRequest.new()
	_npcs_request.name = "NpcsRequest"
	main.add_child(_npcs_request)
	_npcs_request.request_completed.connect(_on_npcs_response)

	_interact_request = HTTPRequest.new()
	_interact_request.name = "NpcInteractRequest"
	main.add_child(_interact_request)
	_interact_request.request_completed.connect(_on_interact_response)

	_dialogue_request = HTTPRequest.new()
	_dialogue_request.name = "NpcDialogueRequest"
	main.add_child(_dialogue_request)
	_dialogue_request.request_completed.connect(_on_dialogue_response)

	_quests_request = HTTPRequest.new()
	_quests_request.name = "NpcQuestsRequest"
	main.add_child(_quests_request)
	_quests_request.request_completed.connect(_on_quests_response)

	_quest_complete_request = HTTPRequest.new()
	_quest_complete_request.name = "NpcQuestCompleteRequest"
	main.add_child(_quest_complete_request)
	_quest_complete_request.request_completed.connect(_on_quest_complete_response)

	_quest_progress_request = HTTPRequest.new()
	_quest_progress_request.name = "NpcQuestProgressRequest"
	main.add_child(_quest_progress_request)
	_quest_progress_request.request_completed.connect(_on_quest_progress_response)

	_spawn_request = HTTPRequest.new()
	_spawn_request.name = "NpcSpawnRequest"
	main.add_child(_spawn_request)
	_spawn_request.request_completed.connect(_on_spawn_response)

func _create_ui() -> void:
	# Dialogue panel — centered overlay for NPC conversations
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.name = "NpcDialoguePanel"
	_dialogue_panel.visible = false
	_dialogue_panel.custom_minimum_size = Vector2(500, 300)
	_dialogue_panel.anchor_left = 0.25
	_dialogue_panel.anchor_right = 0.75
	_dialogue_panel.anchor_top = 0.55
	_dialogue_panel.anchor_bottom = 0.95
	_dialogue_panel.offset_left = 0
	_dialogue_panel.offset_right = 0
	_dialogue_panel.offset_top = 0
	_dialogue_panel.offset_bottom = 0

	var dialogue_vbox = VBoxContainer.new()
	dialogue_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_panel.add_child(dialogue_vbox)

	_npc_name_label = Label.new()
	_npc_name_label.name = "NpcNameLabel"
	_npc_name_label.add_theme_font_size_override("font_size", 18)
	_npc_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_vbox.add_child(_npc_name_label)

	var separator = HSeparator.new()
	dialogue_vbox.add_child(separator)

	_dialogue_label = RichTextLabel.new()
	_dialogue_label.name = "NpcDialogueText"
	_dialogue_label.bbcode_enabled = true
	_dialogue_label.fit_content = true
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_label.custom_minimum_size = Vector2(0, 80)
	dialogue_vbox.add_child(_dialogue_label)

	var options_separator = HSeparator.new()
	dialogue_vbox.add_child(options_separator)

	_dialogue_options_container = VBoxContainer.new()
	_dialogue_options_container.name = "DialogueOptions"
	dialogue_vbox.add_child(_dialogue_options_container)

	var close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close_dialogue)
	dialogue_vbox.add_child(close_button)

	var canvas = main.get_node("CanvasLayer")
	if canvas:
		canvas.add_child(_dialogue_panel)

	# Interaction prompt — floating text when near an NPC
	_interaction_prompt = Label.new()
	_interaction_prompt.name = "NpcInteractionPrompt"
	_interaction_prompt.visible = false
	_interaction_prompt.text = "[E] Talk"
	_interaction_prompt.add_theme_font_size_override("font_size", 16)
	_interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_prompt.anchor_left = 0.4
	_interaction_prompt.anchor_right = 0.6
	_interaction_prompt.anchor_top = 0.45
	_interaction_prompt.anchor_bottom = 0.5
	if canvas:
		canvas.add_child(_interaction_prompt)

	# Quest tracker — small panel in top-right
	_quest_tracker_panel = PanelContainer.new()
	_quest_tracker_panel.name = "QuestTrackerPanel"
	_quest_tracker_panel.visible = false
	_quest_tracker_panel.anchor_left = 0.75
	_quest_tracker_panel.anchor_right = 0.99
	_quest_tracker_panel.anchor_top = 0.01
	_quest_tracker_panel.anchor_bottom = 0.3
	_quest_tracker_panel.offset_left = 0
	_quest_tracker_panel.offset_right = 0
	_quest_tracker_panel.offset_top = 0
	_quest_tracker_panel.offset_bottom = 0

	_quest_tracker_vbox = VBoxContainer.new()
	_quest_tracker_panel.add_child(_quest_tracker_vbox)

	var tracker_title = Label.new()
	tracker_title.text = "Active Quests"
	tracker_title.add_theme_font_size_override("font_size", 14)
	tracker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_tracker_vbox.add_child(tracker_title)

	if canvas:
		canvas.add_child(_quest_tracker_panel)

# ---------------------------------------------------------------------------
# Process tick — called from main._process(delta)
# ---------------------------------------------------------------------------

func process_tick(delta: float) -> void:
	anim_accumulator += delta

	_animate_npcs(delta)
	_check_interaction_proximity()
	_handle_interaction_input()

func _animate_npcs(_delta: float) -> void:
	for npc_id in npc_nodes:
		var node = npc_nodes[npc_id]
		if not is_instance_valid(node):
			continue

		var data = npc_data.get(npc_id, {})
		var base_y = data.get("y", 0.0)

		# Gentle bobbing animation
		var bob = sin(anim_accumulator * NPC_BOB_SPEED + npc_id.hash() * 0.1) * NPC_BOB_HEIGHT
		node.position.y = base_y + bob

		# Smooth position interpolation toward server position
		var target_x = data.get("x", node.position.x)
		var target_z = data.get("z", node.position.z)
		node.position.x = lerp(node.position.x, float(target_x), 0.1)
		node.position.z = lerp(node.position.z, float(target_z), 0.1)

func _check_interaction_proximity() -> void:
	if dialogue_open:
		_interaction_prompt.visible = false
		return

	var my_avatar_id = main.session.get("avatarId", "")
	var my_state = main.avatar_states.get(my_avatar_id, {})
	if my_state.is_empty():
		_interaction_prompt.visible = false
		interaction_target = ""
		return

	var my_pos = Vector3(
		float(my_state.get("x", 0)),
		float(my_state.get("y", 0)),
		float(my_state.get("z", 0))
	)

	var closest_id := ""
	var closest_dist := INTERACT_DISTANCE + 1.0

	for npc_id in npc_data:
		var data = npc_data[npc_id]
		var npc_pos = Vector3(
			float(data.get("x", 0)),
			float(data.get("y", 0)),
			float(data.get("z", 0))
		)
		var dist = my_pos.distance_to(npc_pos)
		if dist < closest_dist and dist <= INTERACT_DISTANCE:
			closest_dist = dist
			closest_id = npc_id

	if closest_id != "":
		var npc_name = npc_data[closest_id].get("displayName", "NPC")
		_interaction_prompt.text = "[E] Talk to " + str(npc_name)
		_interaction_prompt.visible = true
		interaction_target = closest_id
	else:
		_interaction_prompt.visible = false
		interaction_target = ""

func _handle_interaction_input() -> void:
	if Input.is_action_just_pressed("ui_text_indent") or Input.is_key_pressed(KEY_E):
		if dialogue_open:
			return
		if interaction_target != "":
			_start_interaction(interaction_target)

# ---------------------------------------------------------------------------
# NPC rendering
# ---------------------------------------------------------------------------

func _create_npc_node(npc_id: String, data: Dictionary) -> Node3D:
	var root = Node3D.new()
	root.name = "NPC_" + npc_id.substr(0, 8)

	var appearance = data.get("appearance", {})
	var body_color_hex = appearance.get("bodyColor", "#7ec8a0")
	var accent_color_hex = appearance.get("accentColor", "#5da87a")
	var head_color_hex = appearance.get("headColor", "#f5deb3")
	var tag_color_hex = appearance.get("nameTagColor", "#aaddaa")

	# Body — capsule
	var body_mesh = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.2
	body_mesh.mesh = capsule
	body_mesh.position = Vector3(0, 0.7, 0)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color.html(body_color_hex)
	body_mat.emission_enabled = true
	body_mat.emission = Color.html(body_color_hex) * 0.2
	body_mat.emission_energy_multiplier = 0.3
	body_mesh.material_override = body_mat
	root.add_child(body_mesh)

	# Head — sphere
	var head_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	head_mesh.mesh = sphere
	head_mesh.position = Vector3(0, 1.5, 0)
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color.html(head_color_hex)
	head_mesh.material_override = head_mat
	root.add_child(head_mesh)

	# Accent ring (belt/sash) to distinguish NPC type
	var ring_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.35
	ring_mesh.mesh = torus
	ring_mesh.position = Vector3(0, 0.6, 0)
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color.html(accent_color_hex)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color.html(accent_color_hex) * 0.4
	ring_mat.emission_energy_multiplier = 0.5
	ring_mesh.material_override = ring_mat
	root.add_child(ring_mesh)

	# NPC type indicator — small floating icon above head
	var npc_type = data.get("npcType", "ambient")
	var indicator = MeshInstance3D.new()
	indicator.name = "TypeIndicator"
	if npc_type == "shopkeeper":
		var box = BoxMesh.new()
		box.size = Vector3(0.15, 0.15, 0.15)
		indicator.mesh = box
	elif npc_type == "quest-giver":
		var prism = PrismMesh.new()
		prism.size = Vector3(0.2, 0.2, 0.2)
		indicator.mesh = prism
	elif npc_type == "tour-guide":
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.0
		cyl.bottom_radius = 0.12
		cyl.height = 0.2
		indicator.mesh = cyl
	else:
		var small_sphere = SphereMesh.new()
		small_sphere.radius = 0.08
		small_sphere.height = 0.16
		indicator.mesh = small_sphere

	indicator.position = Vector3(0, 2.0, 0)
	var indicator_mat = StandardMaterial3D.new()
	indicator_mat.albedo_color = Color.html(tag_color_hex)
	indicator_mat.emission_enabled = true
	indicator_mat.emission = Color.html(tag_color_hex)
	indicator_mat.emission_energy_multiplier = 1.0
	indicator.material_override = indicator_mat
	root.add_child(indicator)

	# Name tag label (3D)
	var name_tag = Label3D.new()
	name_tag.name = "NameTag"
	name_tag.text = data.get("displayName", "NPC")
	name_tag.font_size = 32
	name_tag.modulate = Color.html(tag_color_hex)
	name_tag.position = NAME_TAG_OFFSET
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.no_depth_test = true
	root.add_child(name_tag)

	# Set initial position
	root.position = Vector3(
		float(data.get("x", 0)),
		float(data.get("y", 0)),
		float(data.get("z", 0))
	)

	return root

func _get_npcs_parent() -> Node3D:
	# Place NPCs under the Avatars root or a dedicated root
	if main.has_node("Avatars"):
		return main.get_node("Avatars")
	return main

func _sync_npc_nodes() -> void:
	var parent = _get_npcs_parent()

	# Remove nodes for NPCs that no longer exist
	var to_remove: Array = []
	for npc_id in npc_nodes:
		if not npc_data.has(npc_id):
			to_remove.append(npc_id)

	for npc_id in to_remove:
		var node = npc_nodes[npc_id]
		if is_instance_valid(node):
			node.queue_free()
		npc_nodes.erase(npc_id)

	# Create nodes for new NPCs
	for npc_id in npc_data:
		if not npc_nodes.has(npc_id):
			var node = _create_npc_node(npc_id, npc_data[npc_id])
			parent.add_child(node)
			npc_nodes[npc_id] = node

# ---------------------------------------------------------------------------
# WebSocket message handling
# ---------------------------------------------------------------------------

func on_ws_message(parsed: Dictionary) -> void:
	var msg_type = parsed.get("type", "")

	if msg_type == "chat":
		var avatar_id = parsed.get("avatarId", "")
		if avatar_id == "npc:tick":
			# NPC position update batch
			var message_text = parsed.get("message", "")
			var tick_data = JSON.parse_string(message_text)
			if tick_data is Dictionary and tick_data.has("npcPositions"):
				_handle_npc_tick(tick_data["npcPositions"])

func _handle_npc_tick(positions: Array) -> void:
	for entry in positions:
		if not entry is Dictionary:
			continue
		var npc_id = entry.get("id", "")
		if npc_id == "":
			continue

		if npc_data.has(npc_id):
			# Update position data
			npc_data[npc_id]["x"] = entry.get("x", npc_data[npc_id].get("x", 0))
			npc_data[npc_id]["y"] = entry.get("y", npc_data[npc_id].get("y", 0))
			npc_data[npc_id]["z"] = entry.get("z", npc_data[npc_id].get("z", 0))
			npc_data[npc_id]["behaviorState"] = entry.get("behaviorState", "idle")
		else:
			# New NPC appeared — add it
			npc_data[npc_id] = entry
			_sync_npc_nodes()

# ---------------------------------------------------------------------------
# HTTP: Fetch NPCs
# ---------------------------------------------------------------------------

func _fetch_npcs() -> void:
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")
	if token == "":
		return
	var url = base_url + "/api/npcs?token=" + token
	_npcs_request.request(url, [], HTTPClient.METHOD_GET)

func _on_npcs_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return
	var npcs_array = parsed.get("npcs", [])
	npc_data.clear()
	for npc in npcs_array:
		if not npc is Dictionary:
			continue
		var npc_id = npc.get("id", "")
		if npc_id != "":
			npc_data[npc_id] = npc
	_sync_npc_nodes()

# ---------------------------------------------------------------------------
# HTTP: Interact with NPC
# ---------------------------------------------------------------------------

func _start_interaction(npc_id: String) -> void:
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")
	if token == "":
		return
	var url = base_url + "/api/npcs/" + npc_id + "/interact"
	var payload = JSON.stringify({"token": token})
	_interact_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)

func _on_interact_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return

	active_dialogue = parsed
	_show_dialogue(parsed)

func _show_dialogue(data: Dictionary) -> void:
	dialogue_open = true
	_dialogue_panel.visible = true

	var npc_name = data.get("displayName", "NPC")
	_npc_name_label.text = npc_name

	var dialogue = data.get("dialogue", {})
	var npc_text = dialogue.get("npcText", "...")
	_dialogue_label.text = "[color=#e8e8e8]" + str(npc_text) + "[/color]"

	# Clear old options
	for child in _dialogue_options_container.get_children():
		child.queue_free()

	var options = dialogue.get("options", [])
	if options.size() == 0:
		# End of conversation — show a close prompt
		var end_label = Label.new()
		end_label.text = "(End of conversation)"
		end_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_dialogue_options_container.add_child(end_label)
	else:
		for option in options:
			if not option is Dictionary:
				continue
			var btn = Button.new()
			btn.text = str(option.get("text", "..."))
			var option_id = option.get("id", "")
			var npc_id = data.get("npcId", active_dialogue.get("npcId", ""))
			btn.pressed.connect(_on_dialogue_option_selected.bind(npc_id, option_id))
			_dialogue_options_container.add_child(btn)

func _on_dialogue_option_selected(npc_id: String, option_id: String) -> void:
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")
	if token == "":
		return
	var url = base_url + "/api/npcs/" + npc_id + "/dialogue"
	var payload = JSON.stringify({"token": token, "optionId": option_id})
	_dialogue_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)

func _on_dialogue_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_close_dialogue()
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_close_dialogue()
		return

	var ended = parsed.get("ended", false)
	var action = parsed.get("action", null)

	# Handle any dialogue actions
	if action is Dictionary:
		_handle_dialogue_action(action)

	if ended:
		# Show the final text briefly, then close
		var dialogue = parsed.get("dialogue", {})
		var npc_text = dialogue.get("npcText", "Farewell!")
		_dialogue_label.text = "[color=#e8e8e8]" + str(npc_text) + "[/color]"
		for child in _dialogue_options_container.get_children():
			child.queue_free()
		var end_label = Label.new()
		end_label.text = "(End of conversation)"
		end_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_dialogue_options_container.add_child(end_label)
	else:
		# Update dialogue with the npcId from active_dialogue
		var display_data = parsed.duplicate()
		if not display_data.has("npcId"):
			display_data["npcId"] = parsed.get("npcId", active_dialogue.get("npcId", ""))
		if not display_data.has("displayName"):
			display_data["displayName"] = active_dialogue.get("displayName", "NPC")
		active_dialogue.merge(display_data, true)
		_show_dialogue(active_dialogue)

func _handle_dialogue_action(action: Dictionary) -> void:
	var action_type = action.get("type", "")
	match action_type:
		"give_quest":
			# Refresh quests after accepting
			_fetch_quests()
		"open_shop":
			# Signal to main that the shop should open
			if main.has_method("_on_npc_open_shop"):
				main.call("_on_npc_open_shop")
		"give_currency":
			# Refresh currency display
			pass
		"teleport":
			var payload = action.get("payload", {})
			var target_region = payload.get("regionId", "")
			if target_region != "" and main.has_method("_teleport_to_region"):
				main.call("_teleport_to_region", target_region)

func _close_dialogue() -> void:
	dialogue_open = false
	_dialogue_panel.visible = false
	active_dialogue = {}

# ---------------------------------------------------------------------------
# HTTP: Quests
# ---------------------------------------------------------------------------

func _fetch_quests() -> void:
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")
	if token == "":
		return
	var url = base_url + "/api/npcs/quests?token=" + token
	_quests_request.request(url, [], HTTPClient.METHOD_GET)

func _on_quests_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return

	var quests = parsed.get("quests", {})
	var active = quests.get("active", [])
	var completed = quests.get("completed", [])

	player_quests = parsed.get("quests", {})
	tracked_quests = active

	_update_quest_tracker(active)

func _update_quest_tracker(active_quests: Array) -> void:
	# Clear existing quest entries (keep the title label)
	var children = _quest_tracker_vbox.get_children()
	for i in range(1, children.size()):
		children[i].queue_free()

	if active_quests.size() == 0:
		_quest_tracker_panel.visible = false
		return

	_quest_tracker_panel.visible = true

	for quest in active_quests:
		if not quest is Dictionary:
			continue

		var quest_label = RichTextLabel.new()
		quest_label.bbcode_enabled = true
		quest_label.fit_content = true
		quest_label.custom_minimum_size = Vector2(0, 40)
		quest_label.scroll_active = false

		var quest_id = quest.get("questId", "")
		var objectives = quest.get("objectives", [])
		var text = "[b]Quest[/b]\n"

		for obj in objectives:
			if not obj is Dictionary:
				continue
			var desc = obj.get("description", "???")
			var current = obj.get("current", 0)
			var required = obj.get("required", 1)
			var done = current >= required
			if done:
				text += "[color=#88ff88]✓ " + str(desc) + " (" + str(current) + "/" + str(required) + ")[/color]\n"
			else:
				text += "[color=#ffcc88]○ " + str(desc) + " (" + str(current) + "/" + str(required) + ")[/color]\n"

		quest_label.text = text

		# Add complete button if all objectives done
		var all_done := true
		for obj in objectives:
			if obj is Dictionary:
				if int(obj.get("current", 0)) < int(obj.get("required", 1)):
					all_done = false
					break

		_quest_tracker_vbox.add_child(quest_label)

		if all_done:
			var complete_btn = Button.new()
			complete_btn.text = "Complete Quest"
			complete_btn.pressed.connect(_complete_quest.bind(quest_id))
			_quest_tracker_vbox.add_child(complete_btn)

func _complete_quest(quest_id: String) -> void:
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")
	if token == "":
		return
	var url = base_url + "/api/npcs/quests/" + quest_id + "/complete"
	var payload = JSON.stringify({"token": token})
	_quest_complete_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)

func _on_quest_complete_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return

	var rewards = parsed.get("rewards", [])
	# Show reward notification in chat
	for reward in rewards:
		if reward is Dictionary:
			var desc = reward.get("description", "a reward")
			_append_chat("[color=#ffd700]Quest reward: " + str(desc) + "[/color]")

	# Refresh quest list
	_fetch_quests()

func report_progress(objective_type: String, target: String, increment: int = 1) -> void:
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")
	if token == "":
		return
	var url = base_url + "/api/npcs/quests/progress"
	var payload = JSON.stringify({
		"token": token,
		"objectiveType": objective_type,
		"target": target,
		"increment": increment
	})
	_quest_progress_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)

func _on_quest_progress_response(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	# Silently refresh quests after progress report
	_fetch_quests()

# ---------------------------------------------------------------------------
# HTTP: Spawn NPC (admin)
# ---------------------------------------------------------------------------

func spawn_npc(region_id: String, display_name: String, npc_type: String, x: float, y: float, z: float) -> void:
	var base_url = main.backend_url_input.text.rstrip("/")
	var token = main.session.get("token", "")
	if token == "":
		return
	var url = base_url + "/api/npcs/spawn"
	var payload = JSON.stringify({
		"token": token,
		"regionId": region_id,
		"displayName": display_name,
		"npcType": npc_type,
		"x": x,
		"y": y,
		"z": z
	})
	_spawn_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)

func _on_spawn_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_append_chat("[color=#ff4444]Failed to spawn NPC.[/color]")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary and parsed.has("npc"):
		var npc = parsed["npc"]
		var npc_id = npc.get("id", "")
		if npc_id != "":
			npc_data[npc_id] = npc
			_sync_npc_nodes()
			_append_chat("[color=#88ff88]Spawned NPC: " + str(npc.get("displayName", "")) + "[/color]")

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

func _append_chat(bbcode_text: String) -> void:
	if main.has_node("CanvasLayer/UI/RightDock/RightMargin/RightVBox/ChatLog"):
		var chat_log = main.get_node("CanvasLayer/UI/RightDock/RightMargin/RightVBox/ChatLog")
		if chat_log is RichTextLabel:
			chat_log.append_text(bbcode_text + "\n")

func cleanup() -> void:
	# Remove all NPC nodes
	for npc_id in npc_nodes:
		var node = npc_nodes[npc_id]
		if is_instance_valid(node):
			node.queue_free()
	npc_nodes.clear()
	npc_data.clear()
	active_dialogue.clear()
	dialogue_open = false
	interaction_target = ""
	_dialogue_panel.visible = false
	_interaction_prompt.visible = false
	_quest_tracker_panel.visible = false

	# Remove HTTP request nodes
	for req in [_npcs_request, _interact_request, _dialogue_request,
				_quests_request, _quest_complete_request, _quest_progress_request,
				_spawn_request]:
		if is_instance_valid(req):
			req.queue_free()

func refresh() -> void:
	_fetch_npcs()
	_fetch_quests()
