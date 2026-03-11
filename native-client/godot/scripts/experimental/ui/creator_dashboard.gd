# Archived experimental module.
# Creator dashboard behavior is not wired into the primary Godot client.
# Provides asset pipeline submission, review status tracking,
# creator analytics, revenue sharing, and plugin management.
#
# Integration notes (DO NOT auto-apply to main.gd):
#   var creator_dashboard = CreatorDashboard.new()
#   creator_dashboard.init(self)
#
#   Add HTTPRequest nodes under $Network:
#     CreatorSubmitRequest, CreatorSubmissionsRequest, CreatorReviewQueueRequest,
#     CreatorReviewRequest, CreatorAnalyticsRequest, CreatorRevenueRequest,
#     CreatorPayoutRequest, CreatorPluginsRequest, CreatorPluginCreateRequest,
#     CreatorWebhooksRequest, CreatorWebhookCreateRequest

class_name CreatorDashboard
extends RefCounted

var main

# Cached state
var submissions: Array = []
var review_queue: Array = []
var analytics: Dictionary = {}
var revenue_data: Dictionary = {}
var plugins_list: Array = []
var webhooks_list: Array = []
var selected_submission_id = ""
var selected_plugin_id = ""

# Request node references (resolved on init)
var submit_request
var submissions_request
var review_queue_request
var review_request
var analytics_request
var revenue_request
var payout_request
var plugins_request
var plugin_create_request
var webhooks_request
var webhook_create_request


func init(main_node) -> void:
	main = main_node
	_bind_requests()


func _bind_requests() -> void:
	submit_request = _find_or_warn("CreatorSubmitRequest")
	submissions_request = _find_or_warn("CreatorSubmissionsRequest")
	review_queue_request = _find_or_warn("CreatorReviewQueueRequest")
	review_request = _find_or_warn("CreatorReviewRequest")
	analytics_request = _find_or_warn("CreatorAnalyticsRequest")
	revenue_request = _find_or_warn("CreatorRevenueRequest")
	payout_request = _find_or_warn("CreatorPayoutRequest")
	plugins_request = _find_or_warn("CreatorPluginsRequest")
	plugin_create_request = _find_or_warn("CreatorPluginCreateRequest")
	webhooks_request = _find_or_warn("CreatorWebhooksRequest")
	webhook_create_request = _find_or_warn("CreatorWebhookCreateRequest")

	if submit_request:
		submit_request.request_completed.connect(_on_submit_completed)
	if submissions_request:
		submissions_request.request_completed.connect(_on_submissions_completed)
	if review_queue_request:
		review_queue_request.request_completed.connect(_on_review_queue_completed)
	if review_request:
		review_request.request_completed.connect(_on_review_completed)
	if analytics_request:
		analytics_request.request_completed.connect(_on_analytics_completed)
	if revenue_request:
		revenue_request.request_completed.connect(_on_revenue_completed)
	if payout_request:
		payout_request.request_completed.connect(_on_payout_completed)
	if plugins_request:
		plugins_request.request_completed.connect(_on_plugins_completed)
	if plugin_create_request:
		plugin_create_request.request_completed.connect(_on_plugin_create_completed)
	if webhooks_request:
		webhooks_request.request_completed.connect(_on_webhooks_completed)
	if webhook_create_request:
		webhook_create_request.request_completed.connect(_on_webhook_create_completed)


func _find_or_warn(node_name: String):
	if not main:
		return null
	var node = main.get_node_or_null("Network/" + node_name)
	if not node:
		push_warning("CreatorDashboard: missing Network/%s node" % node_name)
	return node


func _base_url() -> String:
	return main.backend_url_input.text.rstrip("/")


func _auth_token() -> String:
	return main.session.get("token", "")


# ---------------------------------------------------------------------------
# Asset Pipeline — Submit
# ---------------------------------------------------------------------------

func submit_asset(
	asset_name: String,
	description: String,
	asset_type: String,
	source_format: String,
	source_url: String,
	file_size: int,
	tags: Array = [],
	thumbnail_url: String = ""
) -> void:
	if not submit_request:
		push_warning("CreatorDashboard: submit_request node missing")
		return
	var token = _auth_token()
	if token.is_empty():
		push_warning("CreatorDashboard: no auth token")
		return

	var body = {
		"token": token,
		"name": asset_name,
		"description": description,
		"assetType": asset_type,
		"sourceFormat": source_format,
		"sourceUrl": source_url,
		"fileSize": file_size,
		"tags": tags,
	}
	if not thumbnail_url.is_empty():
		body["thumbnailUrl"] = thumbnail_url

	var url = _base_url() + "/api/creator/assets/submit"
	var headers = ["Content-Type: application/json"]
	submit_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


func _on_submit_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("submission"):
		var sub = payload.submission
		submissions.append(sub)
		selected_submission_id = sub.get("id", "")
		_log("Asset submitted: %s (status: %s, conversion: %s)" % [
			sub.get("name", ""),
			sub.get("status", ""),
			sub.get("conversionStatus", ""),
		])
	else:
		_log("Asset submission failed: %s" % payload.get("error", "unknown error"))


# ---------------------------------------------------------------------------
# Asset Pipeline — List Own Submissions
# ---------------------------------------------------------------------------

func fetch_submissions() -> void:
	if not submissions_request:
		return
	var token = _auth_token()
	if token.is_empty():
		return

	var url = "%s/api/creator/assets/submissions?token=%s" % [_base_url(), token]
	submissions_request.request(url)


func _on_submissions_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("submissions"):
		submissions = payload.submissions
		_log("Loaded %d submissions" % submissions.size())
	else:
		_log("Failed to load submissions: %s" % payload.get("error", "unknown"))


# ---------------------------------------------------------------------------
# Asset Review Queue (Admin)
# ---------------------------------------------------------------------------

func fetch_review_queue(status_filter: String = "") -> void:
	if not review_queue_request:
		return
	var token = _auth_token()
	if token.is_empty():
		return

	var url = "%s/api/creator/assets/review?token=%s" % [_base_url(), token]
	if not status_filter.is_empty():
		url += "&status=%s" % status_filter
	review_queue_request.request(url)


func _on_review_queue_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("queue"):
		review_queue = payload.queue
		_log("Review queue loaded: %d items" % review_queue.size())
	else:
		_log("Failed to load review queue: %s" % payload.get("error", "admin access required"))


func review_asset(submission_id: String, decision: String, notes: String = "") -> void:
	if not review_request:
		return
	var token = _auth_token()
	if token.is_empty():
		return

	var body_data = {
		"token": token,
		"submissionId": submission_id,
		"decision": decision,
		"notes": notes,
	}
	var url = _base_url() + "/api/creator/assets/review"
	var headers = ["Content-Type: application/json"]
	review_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body_data))


func _on_review_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("submission"):
		var sub = payload.submission
		_log("Review complete: %s -> %s" % [sub.get("name", ""), sub.get("status", "")])
		# Refresh the queue
		fetch_review_queue()
	else:
		_log("Review failed: %s" % payload.get("error", "unknown"))


# ---------------------------------------------------------------------------
# Creator Analytics
# ---------------------------------------------------------------------------

func fetch_analytics(period_days: int = 30) -> void:
	if not analytics_request:
		return
	var token = _auth_token()
	if token.is_empty():
		return

	var url = "%s/api/creator/analytics?token=%s&periodDays=%d" % [_base_url(), token, period_days]
	analytics_request.request(url)


func _on_analytics_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("analytics"):
		analytics = payload.analytics
		_log("Analytics: %d assets, %d views, %d sales, %d revenue" % [
			analytics.get("totalAssets", 0),
			analytics.get("totalViews", 0),
			analytics.get("totalSales", 0),
			analytics.get("totalRevenue", 0),
		])
	else:
		_log("Failed to load analytics: %s" % payload.get("error", "unknown"))


func get_popular_items() -> Array:
	return analytics.get("popularItems", [])


func get_revenue_by_month() -> Array:
	return analytics.get("revenueByMonth", [])


# ---------------------------------------------------------------------------
# Revenue Sharing
# ---------------------------------------------------------------------------

func fetch_revenue() -> void:
	if not revenue_request:
		return
	var token = _auth_token()
	if token.is_empty():
		return

	var url = "%s/api/creator/revenue?token=%s" % [_base_url(), token]
	revenue_request.request(url)


func _on_revenue_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("revenue"):
		revenue_data = payload.revenue
		var split = revenue_data.get("split", {})
		_log("Revenue: pending=%s, lifetime=%s, split=%s/%s" % [
			str(revenue_data.get("pendingPayout", 0)),
			str(revenue_data.get("lifetimeEarnings", 0)),
			str(split.get("creatorPercent", 90)),
			str(split.get("platformPercent", 10)),
		])
	else:
		_log("Failed to load revenue: %s" % payload.get("error", "unknown"))


func request_payout(amount: float) -> void:
	if not payout_request:
		return
	var token = _auth_token()
	if token.is_empty():
		return

	var body_data = {
		"token": token,
		"amount": amount,
	}
	var url = _base_url() + "/api/creator/revenue/payouts"
	var headers = ["Content-Type: application/json"]
	payout_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body_data))


func _on_payout_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("payout"):
		var payout = payload.payout
		_log("Payout requested: %s (status: %s)" % [str(payout.get("amount", 0)), payout.get("status", "")])
		# Refresh revenue data
		fetch_revenue()
	else:
		_log("Payout failed: %s" % payload.get("error", "unknown"))


func get_pending_payout() -> float:
	return revenue_data.get("pendingPayout", 0.0)


func get_lifetime_earnings() -> float:
	return revenue_data.get("lifetimeEarnings", 0.0)


func get_revenue_split() -> Dictionary:
	return revenue_data.get("split", {})


func get_payouts() -> Array:
	return revenue_data.get("payouts", [])


# ---------------------------------------------------------------------------
# SDK — Plugin Registry
# ---------------------------------------------------------------------------

func fetch_plugins() -> void:
	if not plugins_request:
		return
	var token = _auth_token()
	if token.is_empty():
		return

	var url = "%s/api/creator/plugins?token=%s" % [_base_url(), token]
	plugins_request.request(url)


func _on_plugins_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("plugins"):
		plugins_list = payload.plugins
		_log("Loaded %d plugins" % plugins_list.size())
	else:
		_log("Failed to load plugins: %s" % payload.get("error", "unknown"))


func create_plugin(plugin_name: String, description: String = "", permissions: Array = []) -> void:
	if not plugin_create_request:
		return
	var token = _auth_token()
	if token.is_empty():
		return

	var body_data = {
		"token": token,
		"name": plugin_name,
		"description": description,
		"permissions": permissions,
	}
	var url = _base_url() + "/api/creator/plugins"
	var headers = ["Content-Type: application/json"]
	plugin_create_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body_data))


func _on_plugin_create_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("plugin"):
		var plugin = payload.plugin
		plugins_list.append(plugin)
		selected_plugin_id = plugin.get("id", "")
		_log("Plugin created: %s (key: %s)" % [plugin.get("name", ""), plugin.get("apiKey", "").left(12) + "..."])
	else:
		_log("Plugin creation failed: %s" % payload.get("error", "unknown"))


func get_plugin_api_key(plugin_id: String) -> String:
	for p in plugins_list:
		if p.get("id", "") == plugin_id:
			return p.get("apiKey", "")
	return ""


# ---------------------------------------------------------------------------
# SDK — Webhooks
# ---------------------------------------------------------------------------

func fetch_webhooks() -> void:
	if not webhooks_request:
		return
	var token = _auth_token()
	if token.is_empty():
		return

	var url = "%s/api/creator/webhooks?token=%s" % [_base_url(), token]
	webhooks_request.request(url)


func _on_webhooks_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("webhooks"):
		webhooks_list = payload.webhooks
		_log("Loaded %d webhooks" % webhooks_list.size())
	else:
		_log("Failed to load webhooks: %s" % payload.get("error", "unknown"))


func create_webhook(webhook_url: String, events: Array, plugin_id: String = "") -> void:
	if not webhook_create_request:
		return
	var token = _auth_token()
	if token.is_empty():
		return

	var body_data = {
		"token": token,
		"url": webhook_url,
		"events": events,
	}
	if not plugin_id.is_empty():
		body_data["pluginId"] = plugin_id

	var url = _base_url() + "/api/creator/webhooks"
	var headers = ["Content-Type: application/json"]
	webhook_create_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body_data))


func _on_webhook_create_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload = _parse_json(body)
	if response_code == 200 and payload.has("webhook"):
		var wh = payload.webhook
		webhooks_list.append(wh)
		_log("Webhook created: %s listening for %d events" % [wh.get("url", ""), wh.get("events", []).size()])
	else:
		_log("Webhook creation failed: %s" % payload.get("error", "unknown"))


# ---------------------------------------------------------------------------
# Convenience: Full Dashboard Refresh
# ---------------------------------------------------------------------------

func refresh_all() -> void:
	fetch_submissions()
	fetch_analytics()
	fetch_revenue()
	fetch_plugins()
	fetch_webhooks()


# ---------------------------------------------------------------------------
# Summary Helpers (for UI display)
# ---------------------------------------------------------------------------

func get_submission_count_by_status(status: String) -> int:
	var count = 0
	for s in submissions:
		if s.get("status", "") == status:
			count += 1
	return count


func get_pending_count() -> int:
	return get_submission_count_by_status("pending")


func get_approved_count() -> int:
	return get_submission_count_by_status("approved")


func get_conversion_status(submission_id: String) -> String:
	for s in submissions:
		if s.get("id", "") == submission_id:
			return s.get("conversionStatus", "unknown")
	return "unknown"


func get_active_plugins_count() -> int:
	var count = 0
	for p in plugins_list:
		if p.get("enabled", false):
			count += 1
	return count


func get_active_webhooks_count() -> int:
	var count = 0
	for w in webhooks_list:
		if w.get("enabled", false):
			count += 1
	return count


# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

func _parse_json(body: PackedByteArray) -> Dictionary:
	var text = body.get_string_from_utf8()
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _log(message: String) -> void:
	print("[CreatorDashboard] %s" % message)
