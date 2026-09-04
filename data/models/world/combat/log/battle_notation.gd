class_name BattleNotation
extends RefCounted

const OUTPUT_DIR: String = "res://logs/debug/battles"

var origin: Vector3i = Vector3i.ZERO
var columns: int = 0
var rows: int = 0
var lines: Array[String] = []
var turn_index: int = 0
var battle_label: String = "battle"
var battle_seed: int = 0
var _level: TacticsLevel = null
var _turn_start_tiles: Dictionary = {}


func setup(level: TacticsLevel, label: String, seed: int) -> void:
	_level = level
	battle_label = label if not label.is_empty() else "battle"
	battle_seed = seed
	lines.clear()
	turn_index = 0
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var min_x: int = 0
	var min_z: int = 0
	var max_x: int = 0
	var max_z: int = 0
	var first: bool = true
	for key in keys.keys():
		var k: Vector3i = key
		if first:
			min_x = k.x
			max_x = k.x
			min_z = k.z
			max_z = k.z
			first = false
		min_x = mini(min_x, k.x)
		max_x = maxi(max_x, k.x)
		min_z = mini(min_z, k.z)
		max_z = maxi(max_z, k.z)
	origin = Vector3i(min_x, 0, min_z)
	columns = max_x - min_x + 1
	rows = max_z - min_z + 1
	lines.append("# PMDEmblem battle %s seed %d" % [battle_label, battle_seed])
	lines.append("# grid %d columns x %d rows; A1 is world tile x=%d z=%d; columns are letters (x), rows are numbers (z)" % [columns, rows, min_x, min_z])
	for pawn in level.units_on_map():
		lines.append("setup %s %s L%d HP %d/%d at %s" % [side_tag(pawn), unit_name(pawn), pawn.stats.level if pawn.stats != null else 0, pawn.stats.curr_health if pawn.stats != null else 0, pawn.stats.max_health if pawn.stats != null else 0, label_for_pawn(pawn)])


func tile_label(key: Vector3i) -> String:
	var col: int = key.x - origin.x
	var row: int = key.z - origin.z + 1
	var letters: String = ""
	var n: int = col
	while true:
		letters = String.chr(65 + (n % 26)) + letters
		n = int(n / 26) - 1
		if n < 0:
			break
	return "%s%d" % [letters, row]


func label_for_pawn(pawn: TacticsPawn) -> String:
	if pawn == null or not is_instance_valid(pawn):
		return "?"
	var tile: TacticsTile = pawn.get_tile()
	if tile == null:
		return "?"
	return tile_label(Targeting._tile_key(tile))


func side_tag(pawn: TacticsPawn) -> String:
	if _level == null or pawn == null:
		return "?"
	if _level.player != null and _level.player.is_ancestor_of(pawn):
		return "P"
	if _level.opponent != null and _level.opponent.is_ancestor_of(pawn):
		return "E"
	return "N"


func unit_name(pawn: TacticsPawn) -> String:
	return BattleMessageCatalog.unit_name(pawn)


func unit_ref(value: Variant) -> String:
	if value is TacticsPawn:
		var pawn: TacticsPawn = value
		return "%s%s@%s" % [side_tag(pawn), unit_name(pawn), label_for_pawn(pawn)]
	return "?"


func hp_ref(value: Variant) -> String:
	if value is TacticsPawn and (value as TacticsPawn).stats != null:
		return "%d/%d" % [(value as TacticsPawn).stats.curr_health, (value as TacticsPawn).stats.max_health]
	return "?"


func mark_turn_start(pawn: TacticsPawn) -> void:
	turn_index += 1
	_turn_start_tiles[pawn] = label_for_pawn(pawn)
	lines.append("T%d %s" % [turn_index, unit_ref(pawn)])


func mark_turn_end(pawn: TacticsPawn) -> void:
	var from: String = String(_turn_start_tiles.get(pawn, ""))
	var to: String = label_for_pawn(pawn)
	if not from.is_empty() and from != to:
		lines.append("  move %s %s>%s" % [unit_name(pawn), from, to])
	_turn_start_tiles.erase(pawn)


func record(event: Dictionary) -> void:
	var kind: String = String(event.get("kind", ""))
	match kind:
		"move_used":
			lines.append("  %s uses %s (targets %d)" % [unit_ref(event.get("attacker")), BattleMessageCatalog.move_label(String(event.get("move_id", ""))), int(event.get("target_count", 0))])
		"damage_dealt":
			var tags: Array[String] = []
			var multiplier: float = float(event.get("multiplier", 1.0))
			if bool(event.get("critical", false)):
				tags.append("crit")
			if multiplier > 1.0:
				tags.append("super")
			elif multiplier > 0.0 and multiplier < 1.0:
				tags.append("resisted")
			if float(event.get("weather_multiplier", 1.0)) != 1.0:
				tags.append("weather x%.1f" % float(event.get("weather_multiplier", 1.0)))
			lines.append("  hit %s -%d HP -> %s%s" % [unit_ref(event.get("defender")), int(event.get("amount", 0)), hp_ref(event.get("defender")), (" [" + ", ".join(tags) + "]") if not tags.is_empty() else ""])
		"damage_prevented":
			lines.append("  no effect on %s (%s)" % [unit_ref(event.get("defender")), String(event.get("source", ""))])
		"miss":
			lines.append("  miss %s" % unit_ref(event.get("defender")))
		"status_applied":
			lines.append("  status +%s %s" % [String(event.get("status_id", "")), unit_ref(event.get("unit"))])
		"status_removed":
			lines.append("  status -%s %s" % [String(event.get("status_id", "")), unit_ref(event.get("unit"))])
		"status_blocked":
			lines.append("  status %s blocked on %s (%s)" % [String(event.get("status_id", "")), unit_ref(event.get("unit")), String(event.get("reason", event.get("blocked_by", "")))])
		"status_tick":
			lines.append("  tick %s %s -%d HP -> %s" % [String(event.get("status_id", "")), unit_ref(event.get("unit")), int(event.get("amount", 0)), hp_ref(event.get("unit"))])
		"stat_stage_changed":
			lines.append("  stat %s %s %d>%d" % [unit_ref(event.get("unit")), String(event.get("stat", "")), int(event.get("before", 0)), int(event.get("after", 0))])
		"healed":
			lines.append("  heal %s +%d HP -> %s" % [unit_ref(event.get("unit")), int(event.get("amount", 0)), hp_ref(event.get("unit"))])
		"weather_started":
			lines.append("  weather %s for %d rounds" % [String(event.get("condition_id", "")), int(event.get("rounds", 0))])
		"weather_tick":
			lines.append("  weather %s %d rounds left" % [String(event.get("condition_id", "")), int(event.get("rounds", 0))])
		"weather_ended":
			lines.append("  weather %s ended (%s)" % [String(event.get("condition_id", "")), String(event.get("reason", ""))])
		"weather_failed":
			lines.append("  weather unchanged (%s already active)" % String(event.get("condition_id", "")))
		"field_condition_applied":
			lines.append("  field +%s (%s)" % [String(event.get("condition_id", "")), String(event.get("scope", "field"))])
		"hazard_placed":
			var refs: Array[String] = []
			for key in event.get("tiles", []):
				refs.append(tile_label(key))
			lines.append("  hazard +%s %s by %s" % [String(event.get("hazard_id", "")), " ".join(refs), unit_ref(event.get("unit"))])
		"hazard_triggered":
			lines.append("  hazard %s x%d on %s" % [String(event.get("hazard_id", "")), int(event.get("layers", 1)), unit_ref(event.get("unit"))])
		"hazard_absorbed":
			lines.append("  hazard %s absorbed by %s" % [String(event.get("hazard_id", "")), unit_ref(event.get("unit"))])
		"hazards_cleared":
			lines.append("  hazards cleared x%d by %s (%s)" % [int(event.get("count", 0)), unit_ref(event.get("unit")), String(event.get("move_id", ""))])
		"unit_fainted":
			lines.append("  faint %s" % unit_ref(event.get("unit")))
		"turn_skipped":
			lines.append("  skip %s (%s)" % [unit_ref(event.get("unit", event.get("attacker"))), String(event.get("status_id", event.get("reason", "")))])
		"move_rejected":
			lines.append("  rejected %s %s (%s)" % [unit_ref(event.get("attacker")), String(event.get("move_id", "")), String(event.get("reason", ""))])
		"item_used", "item_thrown", "item_landed", "item_picked_up", "held_item_landed", "held_item_stolen", "held_item_bestowed", "item_action_rejected":
			var who: Variant = event.get("unit", event.get("attacker", event.get("thrower", null)))
			lines.append("  %s %s %s" % [kind.replace("_", " "), unit_ref(who) if who is TacticsPawn else "", String(event.get("item_id", event.get("item", "")))])
		"battle_ended":
			lines.append("end result=%s" % str(event.get("result", "")))


func finish(result: int) -> void:
	lines.append("# battle over: %s after %d turns" % ["player wins" if result == 1 else ("enemy wins" if result == 2 else "result %d" % result), turn_index])
	for pawn in (_level.units_on_map() if _level != null else []):
		lines.append("final %s %s HP %s at %s" % [side_tag(pawn), unit_name(pawn), hp_ref(pawn), label_for_pawn(pawn)])


func text() -> String:
	return "\n".join(lines)


func output_path() -> String:
	return "%s/%s_seed%d.log" % [OUTPUT_DIR, battle_label.validate_filename(), battle_seed]


static func clear_output_dir() -> int:
	var dir_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var removed: int = 0
	for file in dir.get_files():
		if file.ends_with(".log") and dir.remove(file) == OK:
			removed += 1
	return removed


func save() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var path: String = output_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(text() + "\n")
	file.close()
	return path
