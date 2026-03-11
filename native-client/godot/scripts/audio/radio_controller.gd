class_name RadioController
extends RefCounted

var main  # reference to main node
var current_station_id := ""
var current_station_name := ""
var current_track_name := ""
var stations: Array = []


func init(main_node) -> void:
	main = main_node


func tune_station(station_id: String) -> void:
	if main.websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	main.websocket.send_text(JSON.stringify({
		"type": "radio:tune",
		"stationId": station_id
	}))


func skip_track() -> void:
	if main.websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	main.websocket.send_text(JSON.stringify({
		"type": "radio:skip"
	}))


func handle_radio_changed(message: Dictionary) -> void:
	current_station_id = message.get("stationId", "")
	current_station_name = message.get("stationName", "")
	current_track_name = message.get("trackName", "")


func get_station_display() -> String:
	if current_station_name.is_empty():
		return "No station"
	return "%s - %s" % [current_station_name, current_track_name]


func set_stations(station_list: Array) -> void:
	stations = station_list
	if not stations.is_empty() and current_station_id.is_empty():
		current_station_id = stations[0].get("id", "")
		current_station_name = stations[0].get("name", "")
		var tracks: Array = stations[0].get("tracks", [])
		var current_index: int = stations[0].get("currentTrack", 0)
		if current_index < tracks.size():
			current_track_name = tracks[current_index]


func get_station_names() -> Array:
	var names: Array = []
	for station in stations:
		names.append(station.get("name", "Unknown"))
	return names


func get_station_id_at(index: int) -> String:
	if index < 0 or index >= stations.size():
		return ""
	return stations[index].get("id", "")
