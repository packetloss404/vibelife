class_name BlockPalette
extends RefCounted

# Block type data: id -> {name, color, transparent, hardness}
var block_types: Dictionary = {}

func _init() -> void:
	# Default palette
	register_block(0, "air", Color(0, 0, 0, 0), true, 0.0)
	register_block(1, "stone", Color(0.5, 0.5, 0.5), false, 3.0)
	register_block(2, "dirt", Color(0.55, 0.35, 0.2), false, 1.0)
	register_block(3, "grass", Color(0.3, 0.65, 0.2), false, 1.0)
	register_block(4, "wood", Color(0.55, 0.35, 0.15), false, 2.0)
	register_block(5, "sand", Color(0.85, 0.78, 0.55), false, 0.8)
	register_block(6, "water", Color(0.2, 0.4, 0.8, 0.6), true, 0.0)
	register_block(7, "ore_iron", Color(0.6, 0.55, 0.5), false, 4.0)
	register_block(8, "ore_gold", Color(0.85, 0.75, 0.2), false, 4.0)
	register_block(9, "ore_crystal", Color(0.6, 0.3, 0.9), false, 5.0)
	register_block(10, "leaves", Color(0.2, 0.55, 0.15, 0.9), true, 0.5)
	register_block(11, "glass", Color(0.8, 0.9, 1.0, 0.3), true, 1.0)
	register_block(12, "brick", Color(0.7, 0.3, 0.25), false, 3.0)

func register_block(id: int, name: String, color: Color, transparent: bool, hardness: float) -> void:
	block_types[id] = {"name": name, "color": color, "transparent": transparent, "hardness": hardness}

func get_block_color(id: int) -> Color:
	if block_types.has(id):
		return block_types[id].color
	return Color.MAGENTA

func is_transparent(id: int) -> bool:
	if block_types.has(id):
		return block_types[id].transparent
	return false

func is_solid(id: int) -> bool:
	return id != 0 and not is_transparent(id)

func sync_from_server(server_types: Array) -> void:
	for bt in server_types:
		var color := Color(bt.get("color", "#ff00ff"))
		register_block(int(bt.id), str(bt.name), color, bool(bt.get("transparent", false)), float(bt.get("hardness", 1.0)))
