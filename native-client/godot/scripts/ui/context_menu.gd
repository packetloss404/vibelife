class_name ContextMenuManager
extends Control

## Right-click context menus for avatars, objects, and parcels.

var main = null
var popup: PopupMenu
var current_context: String = ""  # "avatar", "object", "parcel"
var current_data: Dictionary = {}

# Menu item IDs
const MENU_PROFILE := 0
const MENU_WHISPER := 1
const MENU_TRADE := 2
const MENU_ADD_FRIEND := 3
const MENU_BLOCK := 4
const MENU_INTERACT := 10
const MENU_INFO := 11
const MENU_REPORT := 12
const MENU_CLAIM := 20
const MENU_RATE_HOME := 21
const MENU_VISIT_OWNER := 22


func init(main_node) -> void:
	main = main_node
	name = "ContextMenuManager"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	popup = PopupMenu.new()
	popup.name = "ContextPopup"
	popup.id_pressed.connect(_on_menu_item_selected)
	add_child(popup)


func show_avatar_menu(screen_position: Vector2, avatar_data: Dictionary) -> void:
	current_context = "avatar"
	current_data = avatar_data
	popup.clear()
	popup.add_item("Profile", MENU_PROFILE)
	popup.add_item("Whisper", MENU_WHISPER)
	popup.add_item("Trade", MENU_TRADE)
	popup.add_separator()
	popup.add_item("Add Friend", MENU_ADD_FRIEND)
	popup.add_item("Block", MENU_BLOCK)
	popup.position = Vector2i(int(screen_position.x), int(screen_position.y))
	popup.popup()


func show_object_menu(screen_position: Vector2, object_data: Dictionary) -> void:
	current_context = "object"
	current_data = object_data
	popup.clear()
	popup.add_item("Interact", MENU_INTERACT)
	popup.add_item("Info", MENU_INFO)
	popup.add_separator()
	popup.add_item("Report", MENU_REPORT)
	popup.position = Vector2i(int(screen_position.x), int(screen_position.y))
	popup.popup()


func show_parcel_menu(screen_position: Vector2, parcel_data: Dictionary) -> void:
	current_context = "parcel"
	current_data = parcel_data
	popup.clear()
	popup.add_item("Claim", MENU_CLAIM)
	popup.add_item("Rate Home", MENU_RATE_HOME)
	popup.add_item("Visit Owner", MENU_VISIT_OWNER)
	popup.position = Vector2i(int(screen_position.x), int(screen_position.y))
	popup.popup()


func _on_menu_item_selected(id: int) -> void:
	match current_context:
		"avatar":
			_handle_avatar_action(id)
		"object":
			_handle_object_action(id)
		"parcel":
			_handle_parcel_action(id)


func _handle_avatar_action(id: int) -> void:
	var avatar_id: String = str(current_data.get("avatarId", ""))
	var display_name: String = str(current_data.get("displayName", ""))
	var account_id: String = str(current_data.get("accountId", ""))

	match id:
		MENU_PROFILE:
			main._append_chat("System: Viewing profile of %s" % display_name)
		MENU_WHISPER:
			# Pre-fill chat input with whisper command
			if main.chat_input:
				main.chat_input.text = "/w %s " % display_name
				main.chat_input.grab_focus()
				main.chat_input.caret_column = main.chat_input.text.length()
		MENU_TRADE:
			if main.marketplace_mgr and not account_id.is_empty():
				main._append_chat("System: Opening trade with %s..." % display_name)
				main.marketplace_mgr.create_trade(account_id, [], 0, [], 0)
		MENU_ADD_FRIEND:
			_send_friend_request(account_id, display_name)
		MENU_BLOCK:
			_block_player(account_id, display_name)


func _handle_object_action(id: int) -> void:
	var object_id: String = str(current_data.get("objectId", ""))
	var asset_ref: String = str(current_data.get("assetRef", ""))

	match id:
		MENU_INTERACT:
			if main.interactive_mgr:
				main.interactive_mgr.interact(object_id)
			main._append_chat("System: Interacting with object")
		MENU_INFO:
			main._append_chat("System: Object ID: %s, Asset: %s" % [object_id, asset_ref])
		MENU_REPORT:
			main._append_chat("System: Object reported.")


func _handle_parcel_action(id: int) -> void:
	var parcel_id: String = str(current_data.get("parcelId", ""))
	var owner_name: String = str(current_data.get("ownerName", ""))

	match id:
		MENU_CLAIM:
			main.parcels_mgr.claim_active_parcel()
		MENU_RATE_HOME:
			if main.home_rating:
				main._append_chat("System: Rating home on parcel %s" % parcel_id)
		MENU_VISIT_OWNER:
			if not owner_name.is_empty():
				main._append_chat("System: Visiting %s's home" % owner_name)


func _send_friend_request(account_id: String, display_name: String) -> void:
	var token := main.session.get("token", "")
	if token.is_empty():
		return
	var url := "%s/api/social/friend-request" % main.backend_url
	var body := JSON.stringify({"token": token, "targetAccountId": account_id})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			main._append_chat("System: Friend request sent to %s" % display_name)
		else:
			main._append_chat("System: Failed to send friend request")
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


func _block_player(account_id: String, display_name: String) -> void:
	var token := main.session.get("token", "")
	if token.is_empty():
		return
	var url := "%s/api/social/block" % main.backend_url
	var body := JSON.stringify({"token": token, "targetAccountId": account_id})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	main.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		if response_code == 200:
			main._append_chat("System: Blocked %s" % display_name)
		else:
			main._append_chat("System: Failed to block player")
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)


## Attempt to identify what was right-clicked and show the appropriate menu.
## Called from main.gd on right-click when not in build mode.
func handle_right_click(screen_pos: Vector2) -> bool:
	var camera := main.camera as Camera3D
	if camera == null:
		return false

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0
	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return false

	var collider := result.get("collider")
	if collider == null:
		return false

	# Check if it is an avatar
	var node := collider as Node
	while node != null:
		if node.has_meta("avatar_id"):
			var av_id: String = str(node.get_meta("avatar_id"))
			var av_data: Dictionary = main.avatars.avatar_states.get(av_id, {})
			if not av_data.is_empty():
				show_avatar_menu(screen_pos, av_data)
				return true

		if node.has_meta("object_id"):
			var obj_id: String = str(node.get_meta("object_id"))
			show_object_menu(screen_pos, {"objectId": obj_id})
			return true

		if node.has_meta("parcel_id"):
			var p_id: String = str(node.get_meta("parcel_id"))
			var owner_n: String = str(node.get_meta("owner_name")) if node.has_meta("owner_name") else ""
			show_parcel_menu(screen_pos, {"parcelId": p_id, "ownerName": owner_n})
			return true

		node = node.get_parent()

	return false
