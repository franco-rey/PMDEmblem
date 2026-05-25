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
	var lvl1: int = _level(att, def1)
	var lvl2: int = _level(att, def2)
	var combined: int = lvl1 + lvl2
	if combined < 0 or combined >= effectiveness_table.size():
		return DEFAULT_NEUTRAL_MULTIPLIER
	var divisor: float = float(effectiveness_table[neutral_index]) if neutral_index < effectiveness_table.size() else 0.0
	if divisor <= 0.0:
		return DEFAULT_NEUTRAL_MULTIPLIER
	return float(effectiveness_table[combined]) / divisor


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
