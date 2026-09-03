class_name BattleWeatherService
extends RefCounted

const DEFAULT_ROUNDS: int = 5
const CHIP_FRACTION: int = 16
const WEATHER_IDS: Array[String] = ["rain", "sunny", "sandstorm", "hail", "desolate_land", "primordial_sea", "delta_stream"]
const STRONG_WEATHER_IDS: Array[String] = ["desolate_land", "primordial_sea", "delta_stream"]
const TERRAIN_IDS: Array[String] = ["grassy_terrain", "electric_terrain", "misty_terrain", "psychic_terrain"]
const TERRAIN_LABELS: Dictionary = {"grassy_terrain": "Grassy Terrain", "electric_terrain": "Electric Terrain", "misty_terrain": "Misty Terrain", "psychic_terrain": "Psychic Terrain"}
const TERRAIN_START: Dictionary = {"grassy_terrain": "Grass grew to cover the battlefield!", "electric_terrain": "An electric current ran across the battlefield!", "misty_terrain": "Mist swirled around the battlefield!", "psychic_terrain": "The battlefield got weird!"}
const TERRAIN_END: Dictionary = {"grassy_terrain": "The grass disappeared from the battlefield.", "electric_terrain": "The electricity disappeared from the battlefield.", "misty_terrain": "The mist disappeared from the battlefield.", "psychic_terrain": "The weirdness disappeared from the battlefield."}
const ALIASES: Dictionary = {"sun": "sunny", "harsh_sun": "sunny", "heavy_rain": "rain", "sand": "sandstorm", "snow": "hail"}
const RULES: Dictionary = {
	"desolate_land": {
		"label": "Extremely harsh sunlight",
		"type_multipliers": {"fire": 1.5},
		"blocked_move_types": ["water"],
		"blocked_statuses": ["freeze"],
		"permanent": true,
		"start": "The sunlight turned extremely harsh!",
		"end": "The extremely harsh sunlight faded.",
		"overlay": "sunny",
	},
	"primordial_sea": {
		"label": "Heavy rain",
		"type_multipliers": {"water": 1.5},
		"blocked_move_types": ["fire"],
		"sure_hit_moves": ["thunder", "hurricane"],
		"permanent": true,
		"start": "A heavy rain began to fall!",
		"end": "The heavy rain has lifted.",
		"overlay": "rain",
	},
	"delta_stream": {
		"label": "Strong winds",
		"neutralize_flying_weakness": true,
		"permanent": true,
		"start": "Mysterious strong winds are protecting Flying-type Pokémon!",
		"end": "The mysterious strong winds have dissipated.",
		"overlay": "",
	},
	"rain": {
		"label": "Rain",
		"type_multipliers": {"water": 1.5, "fire": 0.5},
		"move_multipliers": {"solar_beam": 0.5, "solar_blade": 0.5},
		"sure_hit_moves": ["thunder", "hurricane"],
		"start": "It started to rain!",
		"end": "The rain stopped.",
		"overlay": "rain",
	},
	"sunny": {
		"label": "Harsh sunlight",
		"type_multipliers": {"fire": 1.5, "water": 0.5},
		"accuracy_overrides": {"thunder": 50, "hurricane": 50},
		"blocked_statuses": ["freeze"],
		"start": "The sunlight turned harsh!",
		"end": "The sunlight faded.",
		"overlay": "sunny",
	},
	"sandstorm": {
		"label": "Sandstorm",
		"chip_immune_types": ["rock", "ground", "steel"],
		"chip_immune_intrinsics": ["sand_veil", "sand_rush", "sand_force", "overcoat", "magic_guard"],
		"special_defense_types": ["rock"],
		"start": "A sandstorm brewed!",
		"end": "The sandstorm subsided.",
		"chip": "%s is buffeted by the sandstorm!",
		"overlay": "sandstorm",
	},
	"hail": {
		"label": "Hail",
		"chip_immune_types": ["ice"],
		"chip_immune_intrinsics": ["ice_body", "snow_cloak", "slush_rush", "overcoat", "magic_guard"],
		"start": "It started to hail!",
		"end": "The hail stopped.",
		"chip": "%s is buffeted by the hail!",
		"overlay": "hail",
	},
}


static func normalize(condition_id: String) -> String:
	var key: String = condition_id.strip_edges().to_lower()
	if ALIASES.has(key):
		key = String(ALIASES[key])
	return key if WEATHER_IDS.has(key) else ""


static func is_weather(condition_id: String) -> bool:
	return not normalize(condition_id).is_empty()


static func rules(weather_id: String) -> Dictionary:
	var key: String = normalize(weather_id)
	return (RULES[key] as Dictionary) if not key.is_empty() else {}


static func label(weather_id: String) -> String:
	return String(rules(weather_id).get("label", weather_id.capitalize()))


static func damage_multiplier(weather_id: String, move: PokemonMoveResource, target_types: Array) -> float:
	var rule: Dictionary = rules(weather_id)
	if rule.is_empty() or move == null:
		return 1.0
	var multiplier: float = 1.0
	var type_multipliers: Dictionary = rule.get("type_multipliers", {})
	if type_multipliers.has(move.type):
		multiplier *= float(type_multipliers[move.type])
	var move_multipliers: Dictionary = rule.get("move_multipliers", {})
	if move_multipliers.has(move.move_id):
		multiplier *= float(move_multipliers[move.move_id])
	if move.category == PokemonMoveResource.CATEGORY_SPECIAL:
		for type_id in rule.get("special_defense_types", []):
			if target_types.has(String(type_id)):
				multiplier /= 1.5
				break
	return multiplier


static func is_permanent(weather_id: String) -> bool:
	return bool(rules(weather_id).get("permanent", false))


static func blocks_move(weather_id: String, move: PokemonMoveResource) -> bool:
	if move == null or not move.is_damaging():
		return false
	return (rules(weather_id).get("blocked_move_types", []) as Array).has(move.type)


static func neutralizes_flying_weakness(weather_id: String) -> bool:
	return bool(rules(weather_id).get("neutralize_flying_weakness", false))


static func is_terrain(condition_id: String) -> bool:
	return TERRAIN_IDS.has(condition_id.strip_edges().to_lower())


static func terrain_start_message(terrain_id: String) -> String:
	return String(TERRAIN_START.get(terrain_id, "The terrain changed!"))


static func terrain_end_message(terrain_id: String) -> String:
	return String(TERRAIN_END.get(terrain_id, "The terrain returned to normal."))


static func accuracy_override(weather_id: String, move: PokemonMoveResource) -> int:
	var rule: Dictionary = rules(weather_id)
	if rule.is_empty() or move == null:
		return -1
	if (rule.get("sure_hit_moves", []) as Array).has(move.move_id):
		return 100
	var overrides: Dictionary = rule.get("accuracy_overrides", {})
	if overrides.has(move.move_id):
		return int(overrides[move.move_id])
	return -1


static func blocks_status(weather_id: String, status_id: String) -> bool:
	return (rules(weather_id).get("blocked_statuses", []) as Array).has(status_id.strip_edges().to_lower())


static func chip_fraction(weather_id: String, unit_types: Array, intrinsic_slugs: Array) -> int:
	var rule: Dictionary = rules(weather_id)
	if rule.is_empty() or not rule.has("chip"):
		return 0
	for type_id in rule.get("chip_immune_types", []):
		if unit_types.has(String(type_id)):
			return 0
	for slug in rule.get("chip_immune_intrinsics", []):
		if intrinsic_slugs.has(String(slug)):
			return 0
	return CHIP_FRACTION


static func weather_heal_fraction(weather_id: String) -> Vector2i:
	var key: String = normalize(weather_id)
	if key.is_empty():
		return Vector2i(1, 2)
	if key == "sunny":
		return Vector2i(2, 3)
	return Vector2i(1, 4)


static func chip_message(weather_id: String, unit_name: String) -> String:
	var rule: Dictionary = rules(weather_id)
	if not rule.has("chip"):
		return ""
	return String(rule["chip"]) % unit_name


static func start_message(weather_id: String) -> String:
	return String(rules(weather_id).get("start", ""))


static func end_message(weather_id: String) -> String:
	return String(rules(weather_id).get("end", ""))
