class_name PokemonStatCalculator
extends RefCounted

const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 100
const STAT_KEYS: Array[String] = [
	"hp",
	"attack",
	"defense",
	"special_attack",
	"special_defense",
	"speed",
]
const NATURES: Dictionary = {
	"hardy": {},
	"lonely": {"up": "attack", "down": "defense"},
	"brave": {"up": "attack", "down": "speed"},
	"adamant": {"up": "attack", "down": "special_attack"},
	"naughty": {"up": "attack", "down": "special_defense"},
	"bold": {"up": "defense", "down": "attack"},
	"docile": {},
	"relaxed": {"up": "defense", "down": "speed"},
	"impish": {"up": "defense", "down": "special_attack"},
	"lax": {"up": "defense", "down": "special_defense"},
	"timid": {"up": "speed", "down": "attack"},
	"hasty": {"up": "speed", "down": "defense"},
	"serious": {},
	"jolly": {"up": "speed", "down": "special_attack"},
	"naive": {"up": "speed", "down": "special_defense"},
	"modest": {"up": "special_attack", "down": "attack"},
	"mild": {"up": "special_attack", "down": "defense"},
	"quiet": {"up": "special_attack", "down": "speed"},
	"bashful": {},
	"rash": {"up": "special_attack", "down": "special_defense"},
	"calm": {"up": "special_defense", "down": "attack"},
	"gentle": {"up": "special_defense", "down": "defense"},
	"sassy": {"up": "special_defense", "down": "speed"},
	"careful": {"up": "special_defense", "down": "special_attack"},
	"quirky": {},
}


static func calculate_for_instance(instance: PokemonInstanceResource) -> Dictionary:
	if instance == null:
		return _empty_stats()
	return calculate(
		instance.resolved_form(),
		instance.level,
		instance.nature_id,
		instance.permanent_modifiers,
		instance.held_item,
	)


static func calculate(
		form: PokemonFormResource,
		level: int,
		nature_id: String = "",
		permanent_modifiers: Dictionary = {},
		held_item: PokemonItemResource = null
) -> Dictionary:
	if form == null:
		return _empty_stats()
	var lv: int = clampi(level, MIN_LEVEL, MAX_LEVEL)
	var stats: Dictionary = {
		"hp": _hp_stat(form.base_hp, lv),
		"attack": _battle_stat(form.base_atk, lv),
		"defense": _battle_stat(form.base_def, lv),
		"special_attack": _battle_stat(form.base_spa, lv),
		"special_defense": _battle_stat(form.base_spd, lv),
		"speed": _battle_stat(form.base_speed, lv),
	}
	_apply_nature(stats, nature_id)
	_apply_flat_modifiers(stats, permanent_modifiers)
	_apply_held_modifiers(stats, held_item)
	for key in STAT_KEYS:
		stats[key] = maxi(1, int(stats.get(key, 1)))
	return stats


static func max_hp(instance: PokemonInstanceResource) -> int:
	return int(calculate_for_instance(instance).get("hp", 1))


static func nature_multiplier(nature_id: String, stat_id: String) -> float:
	var nature: Dictionary = NATURES.get(nature_id.to_lower(), {})
	var stat: String = _normalize_stat_id(stat_id)
	if stat.is_empty() or stat == "hp":
		return 1.0
	if String(nature.get("up", "")) == stat:
		return 1.1
	if String(nature.get("down", "")) == stat:
		return 0.9
	return 1.0


static func normalize_stat_id(stat_id: String) -> String:
	return _normalize_stat_id(stat_id)


static func _hp_stat(base: int, level: int) -> int:
	return int(floor((float(base * 2) * float(level)) / 100.0)) + level + 10


static func _battle_stat(base: int, level: int) -> int:
	return int(floor((float(base * 2) * float(level)) / 100.0)) + 5


static func _apply_nature(stats: Dictionary, nature_id: String) -> void:
	for key in STAT_KEYS:
		if key == "hp":
			continue
		stats[key] = int(floor(float(stats[key]) * nature_multiplier(nature_id, key)))


static func _apply_flat_modifiers(stats: Dictionary, modifiers: Dictionary) -> void:
	for raw_key in modifiers.keys():
		var key: String = _normalize_stat_id(String(raw_key))
		if key.is_empty():
			continue
		var value: Variant = modifiers[raw_key]
		if value is Array:
			for entry in value:
				if entry is Dictionary:
					stats[key] = int(stats.get(key, 0)) + int((entry as Dictionary).get("amount", 0))
				else:
					stats[key] = int(stats.get(key, 0)) + int(entry)
		else:
			stats[key] = int(stats.get(key, 0)) + int(value)


static func _apply_held_modifiers(stats: Dictionary, held_item: PokemonItemResource) -> void:
	if held_item == null:
		return
	for record in held_item.passive_effect_records:
		if String(record.get("family", "")) != "held_stat_modifier":
			continue
		var stat: String = _normalize_stat_id(String(record.get("stat", "")))
		if stat.is_empty():
			continue
		stats[stat] = int(stats.get(stat, 0)) + int(record.get("amount", 0))


static func _normalize_stat_id(stat_id: String) -> String:
	var key: String = stat_id.to_lower()
	if key.begins_with("mod_"):
		key = key.substr(4)
	match key:
		"hp", "max_hp":
			return "hp"
		"atk":
			return "attack"
		"def":
			return "defense"
		"spa", "special_atk", "specialattack":
			return "special_attack"
		"spd", "special_def", "specialdefense":
			return "special_defense"
		"spe":
			return "speed"
		"attack", "defense", "special_attack", "special_defense", "speed":
			return key
	return ""


static func _empty_stats() -> Dictionary:
	return {
		"hp": 1,
		"attack": 1,
		"defense": 1,
		"special_attack": 1,
		"special_defense": 1,
		"speed": 1,
	}
