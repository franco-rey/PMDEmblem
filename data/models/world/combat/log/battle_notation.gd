class_name BattleNotation
extends RefCounted

const OUTPUT_DIR: String = "res://logs/debug/battles"
const INDENT: String = "  "
const STAT_TOKENS: Dictionary = {
	"attack": "atk",
	"defense": "def",
	"special_attack": "spa",
	"special_defense": "spd",
	"speed": "spe",
	"accuracy": "acc",
	"evasion": "eva",
}

var grid: NotationGrid = NotationGrid.new()
var lines: Array[String] = []
var turn_index: int = 0
var battle_label: String = "battle"
var battle_seed: int = 0
var context: Dictionary = {}
var _level: TacticsLevel = null
var _unit_ids: Dictionary = {}
var _known_tiles: Dictionary = {}
var _turn_pawn: TacticsPawn = null


var origin: Vector3i:
	get:
		return grid.origin


var columns: int:
	get:
		return grid.columns


var rows: int:
	get:
		return grid.rows


func setup(level: TacticsLevel, label: String, seed: int) -> void:
	_level = level
	battle_label = label if not label.is_empty() else "battle"
	battle_seed = seed
	context = level.notation_context.duplicate() if level != null else {}
	lines.clear()
	turn_index = 0
	_unit_ids.clear()
	_known_tiles.clear()
	_turn_pawn = null
	grid.setup(Targeting.arena_tile_keys(level))
	_assign_unit_ids(level)
	lines.append("[Notation %s]" % NotationParser.quote(NotationParser.VERSION))
	lines.append("[Battle %s]" % NotationParser.quote(battle_label))
	lines.append("[Seed %d]" % battle_seed)
	var map_id: String = String(context.get("map", ""))
	if not map_id.is_empty():
		lines.append("[Map %s]" % NotationParser.quote(map_id))
	var mode: String = String(context.get("mode", ""))
	if not mode.is_empty():
		lines.append("[Mode %s]" % mode)
	var code: String = String(context.get("code", ""))
	if not code.is_empty():
		lines.append("[Code %s]" % NotationParser.quote(code))
	lines.append("[Grid %s]" % grid.grid_span())
	lines.append("[Origin %d %d]" % [grid.origin.x, grid.origin.z])
	for terrain_line in grid.terrain_lines():
		lines.append(terrain_line)
	for pawn in level.units_on_map():
		lines.append(_unit_line(pawn))
		_known_tiles[pawn] = label_for_pawn(pawn)


func tile_label(key: Vector3i) -> String:
	return grid.label(key)


func label_for_pawn(pawn: TacticsPawn) -> String:
	if pawn == null or not is_instance_valid(pawn):
		return "?"
	var tile: TacticsTile = pawn.get_tile()
	if tile == null:
		return "?"
	return grid.label(Targeting._tile_key(tile))


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


func unit_id(value: Variant) -> String:
	var pawn: TacticsPawn = _pawn_of(value)
	if pawn == null:
		return "?"
	if not _unit_ids.has(pawn):
		_assign_unit_ids(_level)
	return String(_unit_ids.get(pawn, "?"))


func _pawn_of(value: Variant) -> TacticsPawn:
	if value is TacticsPawn and is_instance_valid(value):
		return value
	if value is Stats and is_instance_valid(value):
		var parent: Node = (value as Stats).get_parent()
		if parent is TacticsPawn:
			return parent
		for pawn in _unit_ids.keys():
			if is_instance_valid(pawn) and (pawn as TacticsPawn).stats == value:
				return pawn
	return null


func pawn_for_id(id: String) -> TacticsPawn:
	for pawn in _unit_ids.keys():
		if String(_unit_ids[pawn]) == id and is_instance_valid(pawn):
			return pawn
	return null


func unit_ref(value: Variant) -> String:
	if value is TacticsPawn:
		var pawn: TacticsPawn = value
		return "%s@%s" % [unit_id(pawn), label_for_pawn(pawn)]
	return "?"


func hp_ref(value: Variant) -> String:
	var pawn: TacticsPawn = _pawn_of(value)
	if pawn != null and pawn.stats != null:
		return "%d/%d" % [pawn.stats.curr_health, pawn.stats.max_health]
	return "?"


func species_slug(pawn: TacticsPawn) -> String:
	if pawn == null or pawn.stats == null or pawn.stats.pokemon_instance == null or pawn.stats.pokemon_instance.species == null:
		return unit_name(pawn).to_lower().replace(" ", "_")
	var slug: String = String(pawn.stats.pokemon_instance.species.species_id)
	return slug if not slug.is_empty() else unit_name(pawn).to_lower().replace(" ", "_")


func mark_turn_start(pawn: TacticsPawn) -> void:
	turn_index += 1
	_turn_pawn = pawn
	_known_tiles[pawn] = label_for_pawn(pawn)
	lines.append("T%d %s @%s" % [turn_index, unit_id(pawn), label_for_pawn(pawn)])


func mark_turn_end(pawn: TacticsPawn) -> void:
	_sync_position(pawn)
	lines.append(INDENT + "end")
	if _turn_pawn == pawn:
		_turn_pawn = null


func record(event: Dictionary) -> void:
	var kind: String = String(event.get("kind", ""))
	var actor: TacticsPawn = _pawn_of(event.get("attacker", event.get("unit", event.get("thrower", null))))
	if actor != null and kind != "forced_movement":
		_sync_position(actor)
	match kind:
		"move_used":
			var slot: int = int(event.get("slot_index", -1))
			var target: TacticsPawn = _pawn_of(event.get("target", null))
			var target_token: String = "-"
			if target != null:
				target_token = "self" if target == event.get("attacker") else unit_id(target)
			_action("atk %s %s %s" % ["-" if slot < 0 else str(slot + 1), String(event.get("move_id", "")), target_token])
		"damage_dealt":
			var tags: Array[String] = []
			var multiplier: float = float(event.get("multiplier", 1.0))
			if multiplier > 1.0:
				tags.append("se")
			elif multiplier > 0.0 and multiplier < 1.0:
				tags.append("nve")
			if bool(event.get("critical", false)):
				tags.append("crit")
			var weather: float = float(event.get("weather_multiplier", 1.0))
			if not is_equal_approx(weather, 1.0):
				tags.append("wx%s" % _number(weather))
			_action(_join(["hit", unit_id(event.get("defender")), "-%d" % int(event.get("amount", 0)), hp_ref(event.get("defender"))] + tags))
		"damage_prevented":
			_action("nfx %s %s" % [unit_id(event.get("defender")), _token(event.get("source", ""))])
		"miss":
			_action("miss %s" % unit_id(event.get("defender")))
		"status_applied":
			_action("st +%s %s" % [_token(event.get("status_id", "")), unit_id(event.get("unit"))])
		"status_removed":
			_action("st -%s %s" % [_token(event.get("status_id", "")), unit_id(event.get("unit"))])
		"status_blocked":
			_action("st %s %s blocked %s" % [_token(event.get("status_id", "")), unit_id(event.get("unit")), _token(event.get("reason", event.get("blocked_by", "")))])
		"status_tick":
			_action("tick %s %s -%d %s" % [_token(event.get("status_id", "")), unit_id(event.get("unit")), int(event.get("amount", 0)), hp_ref(event.get("unit"))])
		"stat_stage_changed":
			_action("stat %s %s %d>%d" % [unit_id(event.get("unit")), _stat_token(String(event.get("stat", ""))), int(event.get("before", 0)), int(event.get("after", 0))])
		"healed":
			_action("heal %s +%d %s" % [unit_id(event.get("unit")), int(event.get("amount", 0)), hp_ref(event.get("unit"))])
		"weather_started":
			_action("wx %s start %d" % [_token(event.get("condition_id", "")), int(event.get("rounds", 0))])
		"weather_tick":
			_action("wx %s left %d" % [_token(event.get("condition_id", "")), int(event.get("rounds", 0))])
		"weather_ended":
			_action("wx %s end %s" % [_token(event.get("condition_id", "")), _token(event.get("reason", ""))])
		"weather_failed":
			_action("wx %s same" % _token(event.get("condition_id", "")))
		"field_condition_applied":
			_action("fld +%s %s" % [_token(event.get("condition_id", "")), _token(event.get("scope", "field"))])
		"field_condition_ended":
			_action("fld -%s %s" % [_token(event.get("condition_id", "")), _token(event.get("scope", event.get("reason", "field")))])
		"hazard_placed":
			var refs: Array[String] = []
			for key in event.get("tiles", []):
				refs.append(grid.label(key))
			_action(_join(["hz", "+%s" % _token(event.get("hazard_id", "")), unit_id(event.get("unit"))] + refs))
		"hazard_triggered":
			_action("hz %s %s x%d" % [_token(event.get("hazard_id", "")), unit_id(event.get("unit")), int(event.get("layers", 1))])
		"hazard_absorbed":
			_action("hz %s %s absorbed" % [_token(event.get("hazard_id", "")), unit_id(event.get("unit"))])
		"hazards_cleared":
			_action("hz clear %s x%d %s" % [unit_id(event.get("unit")), int(event.get("count", 0)), _token(event.get("move_id", ""))])
		"forced_movement":
			var unit: TacticsPawn = _pawn_of(event.get("unit", null))
			if unit != null:
				var from: String = String(_known_tiles.get(unit, "?"))
				var raw_from: Variant = event.get("from", null)
				if raw_from is Vector3i:
					from = grid.label(raw_from)
				var to: String = label_for_pawn(unit)
				var raw_to: Variant = event.get("to", null)
				if raw_to is Vector3i:
					to = grid.label(raw_to)
				_known_tiles[unit] = to
				_action("push %s %s>%s %s" % [unit_id(unit), from, to, _token(event.get("mode", event.get("move_id", "")))])
		"unit_fainted":
			_action("ko %s" % unit_id(event.get("unit")))
		"turn_skipped":
			_action("skip %s %s" % [unit_id(event.get("unit", event.get("attacker"))), _token(event.get("status_id", event.get("reason", "")))])
		"move_rejected":
			_action("rej %s %s %s" % [unit_id(event.get("attacker")), _token(event.get("move_id", "")), _token(event.get("reason", ""))])
		"item_used":
			_action("item use %s %s" % [unit_id(event.get("target", event.get("unit"))), _token(event.get("item_id", ""))])
		"item_throw_started":
			var direction: Variant = event.get("direction", Vector3i.ZERO)
			var dir: Vector3i = direction if direction is Vector3i else Vector3i.ZERO
			_action("item throw %s %s %d,%d" % [unit_id(event.get("unit")), _token(event.get("item_id", "")), dir.x, dir.z])
		"item_hit_unit":
			_action("item hit %s %s by %s" % [unit_id(event.get("unit")), _token(event.get("item_id", "")), unit_id(event.get("thrower"))])
		"item_thrown":
			_action("item fling %s %s %s" % [unit_id(event.get("attacker")), _token(event.get("item_id", "")), _token(event.get("move_id", ""))])
		"item_landed":
			var tile: Variant = event.get("tile", null)
			_action("item land %s %s %s" % [_token(event.get("item_id", "")), grid.label(tile) if tile is Vector3i else "?", _token(event.get("source", ""))])
		"item_picked_up":
			var tile: Variant = event.get("tile", null)
			_action("item pick %s %s %s" % [unit_id(event.get("unit")), _token(event.get("item_id", "")), grid.label(tile) if tile is Vector3i else "?"])
		"item_action_rejected":
			_action("rej %s item:%s %s" % [unit_id(event.get("unit")), _token(event.get("item_id", "")), _token(event.get("reason", ""))])
		"held_item_consumed":
			_action("held consumed %s %s %s" % [unit_id(event.get("target")), _token(event.get("item_id", "")), _token(event.get("source", ""))])
		"held_item_knocked_off":
			_action("held knocked %s %s %s" % [unit_id(event.get("target")), _token(event.get("item_id", "")), _token(event.get("source", ""))])
		"held_item_stolen":
			_action("held stolen %s %s %s" % [unit_id(event.get("attacker")), unit_id(event.get("defender")), _token(event.get("item_id", ""))])
		"held_item_bestowed":
			_action("held bestowed %s %s %s" % [unit_id(event.get("attacker")), unit_id(event.get("defender")), _token(event.get("item_id", ""))])
		"held_item_landed":
			_action("held landed %s %s %s" % [unit_id(event.get("attacker")), unit_id(event.get("defender")), _token(event.get("item_id", ""))])


func finish(result: int) -> void:
	var winner: String = "player" if result == 1 else ("enemy" if result == 2 else "none")
	lines.append("result %s turns=%d code=%d" % [winner, turn_index, result])
	for pawn in (_level.units_on_map() if _level != null else []):
		lines.append("final %s %s @%s" % [unit_id(pawn), hp_ref(pawn), label_for_pawn(pawn)])


func text() -> String:
	return "\n".join(lines)


func output_path() -> String:
	return "%s/%s_seed%d.pmdn" % [OUTPUT_DIR, battle_label.validate_filename(), battle_seed]


static func clear_output_dir() -> int:
	var dir_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var removed: int = 0
	for file in dir.get_files():
		if (file.ends_with(".log") or file.ends_with(".pmdn")) and dir.remove(file) == OK:
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


func _assign_unit_ids(level: TacticsLevel) -> void:
	if level == null:
		return
	_unit_ids.clear()
	for side in [["P", level.player], ["E", level.opponent]]:
		var parent: Node = side[1]
		if parent == null:
			continue
		var index: int = 0
		for child in parent.get_children():
			if child is TacticsPawn:
				index += 1
				_unit_ids[child] = "%s%d" % [String(side[0]), index]


func _unit_line(pawn: TacticsPawn) -> String:
	var stats: Stats = pawn.stats
	var tokens: Array[String] = ["unit", unit_id(pawn), species_slug(pawn)]
	if stats != null:
		tokens.append("L%d" % stats.level)
		tokens.append(hp_ref(pawn))
	tokens.append("@%s" % label_for_pawn(pawn))
	var instance: PokemonInstanceResource = stats.pokemon_instance if stats != null else null
	if instance != null:
		tokens.append("ctl=%s" % ("player" if instance.control_type == PokemonInstanceResource.ControlType.PLAYER else "cpu"))
		if instance.held_item != null and not instance.held_item.item_id.is_empty():
			tokens.append("item=%s" % _token(instance.held_item.item_id))
		var ability: String = String(instance.ability_override)
		if ability.is_empty() and stats != null:
			var natural: Array[String] = BattleIntrinsicService.natural_slugs_static(stats)
			if not natural.is_empty():
				ability = natural[0]
		if not ability.is_empty():
			tokens.append("ability=%s" % _token(ability))
	if stats != null:
		var moves: Array[String] = []
		for move in stats.move_slots:
			if move != null:
				moves.append(_token(move.move_id))
		if not moves.is_empty():
			tokens.append("moves=%s" % ",".join(moves))
	return " ".join(tokens)


func _sync_position(pawn: TacticsPawn) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	var now: String = label_for_pawn(pawn)
	if now == "?":
		return
	var before: String = String(_known_tiles.get(pawn, ""))
	if before.is_empty():
		_known_tiles[pawn] = now
		return
	if before != now:
		_known_tiles[pawn] = now
		if pawn == _turn_pawn:
			_action("mv %s>%s" % [before, now])


func _action(text: String) -> void:
	lines.append(INDENT + text)


static func _token(value: Variant) -> String:
	var text: String = String(value).strip_edges()
	if text.is_empty():
		return "-"
	return text.replace(" ", "_")


static func _stat_token(stat: String) -> String:
	return String(STAT_TOKENS.get(stat, stat))


static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return ("%.2f" % value).rstrip("0")


static func _join(tokens: Array) -> String:
	var out: PackedStringArray = []
	for token in tokens:
		out.append(String(token))
	return " ".join(out)
