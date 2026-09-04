class_name TypeChartResource
extends Resource

const DEFAULT_NEUTRAL_MULTIPLIER: float = 1.0
const LEVEL_IMMUNE: int = 0
const LEVEL_NOT_VERY_EFFECTIVE: int = 3
const LEVEL_NEUTRAL: int = 4
const LEVEL_SUPER_EFFECTIVE: int = 5

@export var type_list: Array[String] = []
@export var type_index: Dictionary = {}
@export var effectiveness_table: PackedFloat32Array = PackedFloat32Array()
@export var neutral_index: int = 8
@export var matchup_levels: PackedByteArray = PackedByteArray()


func get_type_index(type_slug: String) -> int:
	var key: String = type_slug.to_lower()
	if type_index.has(key):
		return int(type_index[key])
	return -1


func _level(attacker_idx: int, defender_idx: int) -> int:
	if attacker_idx < 0 or defender_idx < 0:
		return LEVEL_NEUTRAL
	var row_size: int = type_list.size()
	if row_size <= 0:
		return LEVEL_NEUTRAL
	var flat_idx: int = attacker_idx * row_size + defender_idx
	if flat_idx < 0 or flat_idx >= matchup_levels.size():
		return LEVEL_NEUTRAL
	return matchup_levels[flat_idx]


func get_effectiveness(attacker_type: String, defender_type: String) -> float:
	return get_effectiveness_dual(attacker_type, defender_type, "none")


func get_effectiveness_dual(attacker_type: String, defender_type1: String, defender_type2: String) -> float:
	if effectiveness_table.is_empty():
		return DEFAULT_NEUTRAL_MULTIPLIER
	var att: int = get_type_index(attacker_type)
	if att < 0:
		return DEFAULT_NEUTRAL_MULTIPLIER
	var def1: int = get_type_index(defender_type1)
	var def2_slug: String = defender_type2 if not defender_type2.is_empty() else "none"
	var def2: int = get_type_index(def2_slug)
	if def1 < 0:
		def1 = get_type_index("none")
	if def2 < 0:
		def2 = get_type_index("none")
	return _level_multiplier(_level(att, def1)) * _level_multiplier(_level(att, def2))


func get_effectiveness_dual_ignoring_immunity(attacker_type: String, defender_type1: String, defender_type2: String) -> float:
	var att: int = get_type_index(attacker_type)
	if att < 0:
		return DEFAULT_NEUTRAL_MULTIPLIER
	var def1: int = get_type_index(defender_type1)
	var def2: int = get_type_index(defender_type2 if not defender_type2.is_empty() else "none")
	var total: float = 1.0
	for level in [_level(att, def1 if def1 >= 0 else get_type_index("none")), _level(att, def2 if def2 >= 0 else get_type_index("none"))]:
		total *= 1.0 if level == LEVEL_IMMUNE else _level_multiplier(level)
	return total


static func _level_multiplier(level: int) -> float:
	match level:
		LEVEL_IMMUNE:
			return 0.0
		LEVEL_NOT_VERY_EFFECTIVE:
			return 0.5
		LEVEL_SUPER_EFFECTIVE:
			return 2.0
		_:
			return 1.0


func get_level(attacker_type: String, defender_type: String) -> int:
	var att: int = get_type_index(attacker_type)
	var def: int = get_type_index(defender_type)
	return _level(att, def)


func is_stab(attacker_type: String, user_types: Array) -> bool:
	var key: String = attacker_type.to_lower()
	for t in user_types:
		if String(t).to_lower() == key:
			return true
	return false


func type_count() -> int:
	return type_list.size()
