class_name TypeChartResource
extends Resource
## Pokemon type chart sourced from PMDODump's `Universal.json`.
##
## PMDODump's chart is a two-step lookup:
##
## 1. `matchup_levels[att][def]` returns an effectiveness *level* in {0, 3, 4, 5}
##    (immune / not-very-effective / neutral / super-effective).
## 2. To get a damage multiplier, sum the levels of both defender types and
##    look the sum up in `effectiveness_table`. The neutral total for a
##    mono-typed defender is `level(att, def) + level(att, "none") = lvl + 4`
##    because the matchup row for `"none"` is uniformly 4. PMD's neutral
##    divisor is `effectiveness_table[8]` (NRM * 2).
##
## The multiplier helpers below mirror PMD's `GetDualEffectiveness` semantics so
## the M2 damage resolver can call them directly.

const DEFAULT_NEUTRAL_MULTIPLIER: float = 1.0
## PMD effectiveness level constants (`PMDC/Dungeon/GameEffects/ElementEffectEvent.cs`).
const LEVEL_IMMUNE: int = 0
const LEVEL_NOT_VERY_EFFECTIVE: int = 3
const LEVEL_NEUTRAL: int = 4
const LEVEL_SUPER_EFFECTIVE: int = 5

@export var type_list: Array[String] = []
## Maps lowercase type slug ("fighting", "ghost", "none") -> index in `type_list`.
@export var type_index: Dictionary = {}
## The 11-entry PMD `Effectiveness` array. Indexed by the *sum* of two
## defender-type levels (0..10), produces the numerator of the damage multiplier.
@export var effectiveness_table: PackedFloat32Array = PackedFloat32Array()
## Index in `effectiveness_table` representing dual-type neutral (LEVEL_NEUTRAL * 2 = 8).
## Acts as the divisor when converting raw Effectiveness values to multipliers.
@export var neutral_index: int = 8
## Flat row-major attacker x defender grid of effectiveness *levels* (one byte each).
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


## Damage multiplier for `attacker_type` hitting a single-typed `defender_type`.
## Equivalent to `get_effectiveness_dual(attacker_type, defender_type, "none")`.
func get_effectiveness(attacker_type: String, defender_type: String) -> float:
	return get_effectiveness_dual(attacker_type, defender_type, "none")


## Damage multiplier for `attacker_type` hitting a defender with up to two
## types. Empty string or "none" for `defender_type2` is treated as mono-type
## (PMD's `none` row in the matrix is uniformly NEUTRAL).
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


## Returns the raw single-type effectiveness level (0/3/4/5). Used by the M2
## damage resolver if it wants to make decisions based on level rather than the
## final multiplier.
func get_level(attacker_type: String, defender_type: String) -> int:
	var att: int = get_type_index(attacker_type)
	var def: int = get_type_index(defender_type)
	return _level(att, def)


## True if `attacker_type` matches either of the user's types (Same Type Attack
## Bonus). M1 only ships the predicate; the actual bonus multiplier is M2.
func is_stab(attacker_type: String, user_types: Array) -> bool:
	var key: String = attacker_type.to_lower()
	for t in user_types:
		if String(t).to_lower() == key:
			return true
	return false


func type_count() -> int:
	return type_list.size()
