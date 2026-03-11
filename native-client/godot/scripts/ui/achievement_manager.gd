class_name AchievementManager extends RefCounted

var main
var player_progress: Dictionary = {}
var achievements: Array = []
var leaderboard: Array = []
var daily_challenges: Array = []
var weekly_challenges: Array = []
var available_titles: Array = []

var _progress_request: HTTPRequest
var _challenges_request: HTTPRequest
var _leaderboard_request: HTTPRequest
var _titles_request: HTTPRequest
var _set_title_request: HTTPRequest
var _achievements_request: HTTPRequest


func init(main_node) -> void:
	main = main_node

	_progress_request = HTTPRequest.new()
	_progress_request.name = "ProgressRequest"
	main.add_child(_progress_request)
	_progress_request.request_completed.connect(_on_progress_loaded)

	_challenges_request = HTTPRequest.new()
	_challenges_request.name = "ChallengesRequest"
	main.add_child(_challenges_request)
	_challenges_request.request_completed.connect(_on_challenges_loaded)

	_leaderboard_request = HTTPRequest.new()
	_leaderboard_request.name = "LeaderboardRequest"
	main.add_child(_leaderboard_request)
	_leaderboard_request.request_completed.connect(_on_leaderboard_loaded)

	_titles_request = HTTPRequest.new()
	_titles_request.name = "TitlesRequest"
	main.add_child(_titles_request)
	_titles_request.request_completed.connect(_on_titles_loaded)

	_set_title_request = HTTPRequest.new()
	_set_title_request.name = "SetTitleRequest"
	main.add_child(_set_title_request)
	_set_title_request.request_completed.connect(_on_title_set)

	_achievements_request = HTTPRequest.new()
	_achievements_request.name = "AchievementsRequest"
	main.add_child(_achievements_request)
	_achievements_request.request_completed.connect(_on_achievements_loaded)


func _get_backend_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _get_token() -> String:
	return main.session.get("token", "")


func load_achievements() -> void:
	var url = "%s/api/achievements" % _get_backend_url()
	var error = _achievements_request.request(url)
	if error != OK:
		_append_chat("System: Failed to load achievements")


func load_progress() -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = "%s/api/progress?token=%s" % [_get_backend_url(), token]
	var error = _progress_request.request(url)
	if error != OK:
		_append_chat("System: Failed to load progress")


func load_challenges() -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = "%s/api/progress/challenges?token=%s" % [_get_backend_url(), token]
	var error = _challenges_request.request(url)
	if error != OK:
		_append_chat("System: Failed to load challenges")


func load_leaderboard(category: String = "") -> void:
	var url = "%s/api/leaderboard?limit=10" % _get_backend_url()
	if not category.is_empty():
		url += "&category=%s" % category
	var error = _leaderboard_request.request(url)
	if error != OK:
		_append_chat("System: Failed to load leaderboard")


func load_titles() -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = "%s/api/titles?token=%s" % [_get_backend_url(), token]
	var error = _titles_request.request(url)
	if error != OK:
		_append_chat("System: Failed to load titles")


func set_title(title: String) -> void:
	var token = _get_token()
	if token.is_empty():
		return
	var url = "%s/api/titles/set" % _get_backend_url()
	var body = JSON.stringify({"token": token, "title": title})
	var headers = ["Content-Type: application/json"]
	var error = _set_title_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_append_chat("System: Failed to set title")


func _on_achievements_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	achievements = payload.get("achievements", [])


func _on_progress_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	var new_progress = payload.get("progress", {})

	# Check for newly unlocked achievements by comparing with previous state
	var old_unlocked = player_progress.get("unlockedAchievements", []) as Array
	var new_unlocked = new_progress.get("unlockedAchievements", []) as Array

	for achievement_id in new_unlocked:
		if not old_unlocked.has(achievement_id):
			_notify_achievement_unlocked(achievement_id)

	player_progress = new_progress

	# Show level/xp in chat on first load
	if old_unlocked.size() == 0 and new_progress.has("level"):
		var level = new_progress.get("level", 1)
		var xp = new_progress.get("xp", 0)
		var title = new_progress.get("title", "Newcomer")
		_append_chat("System: Level %d | XP: %d | Title: %s" % [level, xp, title])


func _on_challenges_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	daily_challenges = payload.get("dailyChallenges", [])
	weekly_challenges = payload.get("weeklyChallenges", [])


func _on_leaderboard_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	leaderboard = payload.get("leaderboard", [])

	# Display leaderboard in chat
	_append_chat("--- Leaderboard ---")
	var rank = 1
	for entry in leaderboard:
		var account_id = entry.get("accountId", "???")
		var xp = entry.get("xp", 0)
		var level = entry.get("level", 1)
		var title = entry.get("title", "")
		_append_chat("#%d  Lvl %d  XP:%d  [%s]  %s" % [rank, level, xp, title, account_id.substr(0, 8)])
		rank += 1
	_append_chat("-------------------")


func _on_titles_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	available_titles = payload.get("titles", [])

	_append_chat("Available titles: %s" % ", ".join(available_titles))


func _on_title_set(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_append_chat("System: Could not set title")
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if payload == null:
		return
	var title = payload.get("title", "")
	_append_chat("System: Title set to '%s'" % title)

	# Reload progress to reflect updated title
	load_progress()


func _notify_achievement_unlocked(achievement_id: String) -> void:
	# Find the achievement name from the cached list
	var name = achievement_id
	for ach in achievements:
		if ach.get("id", "") == achievement_id:
			name = ach.get("name", achievement_id)
			break
	_append_chat("Achievement Unlocked: %s!" % name)


func _append_chat(text: String) -> void:
	if main and main.chat_log:
		main.chat_log.append_text(text + "\n")
