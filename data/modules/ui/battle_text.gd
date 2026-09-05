class_name BattleText
extends RefCounted

const PATH: String = "res://data/models/pokemon/generated/manifests/battle_text.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed


static func _entry(table: String, id: String) -> Dictionary:
	_load()
	var group: Variant = _data.get(table, {})
	if group is Dictionary and (group as Dictionary).has(id):
		return (group as Dictionary)[id]
	return {}


static func ability_name(id: String) -> String:
	var name: String = String(_entry("intrinsics", id).get("name", ""))
	return name if not name.is_empty() else id.capitalize()


static func ability_description(id: String) -> String:
	return String(_entry("intrinsics", id).get("description", ""))


static func status_description(id: String) -> String:
	var direct: String = String(_entry("statuses", id).get("description", ""))
	if not direct.is_empty():
		return direct
	return String(_entry("map_statuses", id).get("description", ""))


static func condition_description(id: String) -> String:
	var text: String = String(_entry("map_statuses", id).get("description", ""))
	if text.is_empty():
		text = String(_entry("map_statuses", id.replace("_terrain", "").replace("_weather", "")).get("description", ""))
	return text


static func move_summary(move: PokemonMoveResource) -> String:
	if move == null:
		return ""
	var category: String = "Status"
	match move.category:
		PokemonMoveResource.CATEGORY_PHYSICAL:
			category = "Physical"
		PokemonMoveResource.CATEGORY_SPECIAL:
			category = "Special"
	var line: String = "%s  %s" % [move.type.capitalize(), category]
	if move.base_power > 0:
		line += "  Pow %d" % move.base_power
	line += "  Acc %s" % ("%d%%" % move.accuracy if move.accuracy > 0 else "--")
	line += "  PP %d" % move.pp
	var description: String = String(move.description).strip_edges()
	return line if description.is_empty() else "%s\n%s" % [line, description]


static func item_description(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	var item: PokemonItemResource = PokemonItemService.load_item(item_id)
	return String(item.description).strip_edges() if item != null else ""
