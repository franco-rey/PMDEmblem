class_name Stats
extends Node

enum BattleStatus { ACTIVE, FAINTED }

const TURN_SKIP_STATUSES: Array[String] = ["flinch", "sleep", "freeze", "immobilized", "paused", "recharge"]
const DEFAULT_STATUS_PAYLOADS: Dictionary = {
	"aqua_ring": {"counter": 10, "hp_fraction": 8},
	"confuse": {"counter": 10},
	"encore": {"counter": 5},
	"flinch": {"counter": 2},
	"freeze": {"counter": 5},
	"heal_block": {"counter": 50},
	"ingrain": {"counter": 10, "hp_fraction": 6},
	"leech_seed": {"hp_fraction": 8},
	"bind": {"counter": 5, "hp_fraction": 8},
	"wrap": {"counter": 5, "hp_fraction": 8},
	"clamp": {"counter": 5, "hp_fraction": 8},
	"fire_spin": {"counter": 5, "hp_fraction": 8},
	"sand_tomb": {"counter": 5, "hp_fraction": 8},
	"whirlpool": {"counter": 5, "hp_fraction": 8},
	"magma_storm": {"counter": 5, "hp_fraction": 8},
	"infestation": {"counter": 5, "hp_fraction": 8},
	"light_screen": {"counter": 10},
	"lucky_chant": {"counter": 25},
	"mist": {"counter": 15},
	"paralyze": {"counter": 7, "recent": false, "skip_turn": false},
	"paused": {"counter": 2},
	"poison": {"counter": 6, "hp_fraction": 16},
	"poison_toxic": {"counter": 6, "hp_fraction": 16, "toxic_stage": 1},
	"recharge": {"counter": 3},
	"reflect": {"counter": 10},
	"safeguard": {"counter": 15},
	"sleep": {"counter": 5},
	"taunted": {"counter": 15},
	"perish_song": {"perish_left": 3},
	"yawning": {"counter": 2},
	"wish": {"counter": 2},
	"future_sight": {"counter": 3},
	"telekinesis": {"counter": 3},
	"magnet_rise": {"counter": 5},
	"stockpile": {"stacks": 1},
	"sleepless": {"counter": 3},
	"sure_shot": {"counter": 2},
	"outrage": {"counter": 3},
	"thrash": {"counter": 3},
	"petal_dance": {"counter": 3},
	"in_love": {"counter": 5},
	"rooted": {"counter": 3},
	"bide": {"counter": 2, "stored": 0},
	"cud_chew": {"counter": 1},
	"embargo": {"counter": 5},
	"decoy": {},
	"follow_me": {},
	"rage_powder": {},
	"fairy_lock": {"counter": 1},
}

var modifiers: Dictionary = {}
var override_name: String
var last_hit_move_type: String = ""
var same_move_streak: int = 0
var gender: int = 2
var weight_kg: float = 0.0
var transformed: bool = false
var last_attacker: Variant = null
var consumed_berry_id: String = ""
var choice_locked_item: String = ""
var expertise: String
var level: int = 1

var movement: int
var jump: int
var max_health: int
var curr_health: int
var sprite: String

var attack_power: int
var attack_range: int

var species_name: String = ""
var types: Array[String] = []
var hp_max: int = 0
var attack: int = 0
var defense: int = 0
var special_attack: int = 0
var special_defense: int = 0
var speed: int = 0
var move_slots: Array[PokemonMoveResource] = []
var current_pp: Array[int] = []
var pokemon_instance: PokemonInstanceResource = null
var battle_status: int = BattleStatus.ACTIVE
var battle_statuses: Dictionary = {}
var temporary_intrinsic_slugs: Array[String] = []
var intrinsic_override_active: bool = false
var stat_stages: Dictionary = {}
var proxy_stats: Dictionary = {}
var battle_speed_multiplier: float = 1.0
var last_used_move_id: String = ""
var last_used_move_index: int = -1
var last_consumed_item_id: String = ""


func init(stats: StatsResource) -> void:
	override_name = stats.override_name
	expertise = stats.expertise
	level = stats.level
	movement = stats.movement
	stats.set_jump()
	max_health = stats.max_health
	curr_health = max_health
	sprite = stats.sprite
	attack_power = stats.attack_power
	attack_range = stats.attack_range
	hp_max = max_health
	pokemon_instance = null
	battle_status = BattleStatus.ACTIVE
	reset_battle_modifiers()


func init_from_pokemon(instance: PokemonInstanceResource) -> void:
	pokemon_instance = instance
	if instance == null:
		push_error("Stats.init_from_pokemon called with null instance")
		return
	battle_status = BattleStatus.ACTIVE
	reset_battle_modifiers()

	var species: PokemonSpeciesResource = instance.species
	var form: PokemonFormResource = instance.resolved_form() if species != null else null

	level = max(1, instance.level)
	override_name = instance.nickname
	species_name = species.canonical_name if species != null else ""
	expertise = species_name if not species_name.is_empty() else (
		species.species_id.capitalize() if species != null else ""
	)

	if form != null:
		types = form.types()
		var calculated: Dictionary = PokemonStatCalculator.calculate_for_instance(instance)
		hp_max = int(calculated.get("hp", 1))
		max_health = hp_max
		attack = int(calculated.get("attack", 1))
		defense = int(calculated.get("defense", 1))
		special_attack = int(calculated.get("special_attack", 1))
		special_defense = int(calculated.get("special_defense", 1))
		speed = int(calculated.get("speed", 1))
		attack_power = int(maxi(attack, special_attack) / 5.0)
		sprite = form.sprite_set.idle_path if form.sprite_set != null else ""
		weight_kg = form.weight
		gender = instance.gender if instance.gender >= 0 else _roll_gender(form, instance)
	else:
		types = []
		hp_max = 1
		max_health = 1
		attack = 0
		defense = 0
		special_attack = 0
		special_defense = 0
		speed = 0
		attack_power = 1
		sprite = ""
	curr_health = hp_max if instance.current_hp == PokemonInstanceResource.CURRENT_HP_AUTO else instance.current_hp
	if curr_health <= 0:
		battle_status = BattleStatus.FAINTED

	movement = instance.movement_override if instance.movement_override > 0 else 4
	jump = int(floor(movement / 2.0))

	move_slots = []
	current_pp = []
	for i in range(instance.move_slots.size()):
		var move: PokemonMoveResource = instance.move_slots[i]
		if move == null:
			continue
		move_slots.append(move)
		var pp: int = move.pp
		if i < instance.pp_state.size():
			pp = int(instance.pp_state[i])
		current_pp.append(pp)

	if not move_slots.is_empty():
		attack_range = max(1, move_slots[0].tactical_range_value)
	else:
		attack_range = 1


func has_pp(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= current_pp.size():
		return false
	return current_pp[slot_index] > 0


func consume_pp(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= current_pp.size():
		return
	current_pp[slot_index] = maxi(0, current_pp[slot_index] - 1)


func refill_all_pp() -> void:
	current_pp.clear()
	for move: PokemonMoveResource in move_slots:
		current_pp.append(move.pp if move != null else 0)


func first_usable_move_index(require_damaging: bool = false) -> int:
	for i in range(move_slots.size()):
		var move: PokemonMoveResource = move_slots[i]
		if move == null:
			continue
		if require_damaging and not move.is_damaging():
			continue
		if has_pp(i):
			return i
	return -1


func _roll_gender(form: PokemonFormResource, instance: PokemonInstanceResource) -> int:
	var weights: Vector3i = form.gender_weights
	var total: int = weights.x + weights.y + weights.z
	if total <= 0:
		return 2
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%s:%d:%d" % [instance.species.species_id if instance.species != null else "", instance.form_index, instance.nickname, instance.level, instance.team])
	var roll: int = rng.randi_range(1, total)
	if roll <= weights.x:
		return 0
	if roll <= weights.x + weights.y:
		return 1
	return 2


func change_form(form_index: int) -> bool:
	if pokemon_instance == null or pokemon_instance.species == null:
		return false
	if form_index < 0 or form_index >= pokemon_instance.species.forms.size() or form_index == pokemon_instance.form_index:
		return false
	var ratio: float = float(curr_health) / float(maxi(1, max_health))
	pokemon_instance.form_index = form_index
	var form: PokemonFormResource = pokemon_instance.resolved_form()
	if form == null:
		return false
	var calculated: Dictionary = PokemonStatCalculator.calculate_for_instance(pokemon_instance)
	hp_max = int(calculated.get("hp", 1))
	max_health = hp_max
	attack = int(calculated.get("attack", 1))
	defense = int(calculated.get("defense", 1))
	special_attack = int(calculated.get("special_attack", 1))
	special_defense = int(calculated.get("special_defense", 1))
	speed = int(calculated.get("speed", 1))
	types = form.types()
	weight_kg = form.weight
	curr_health = clampi(int(round(float(max_health) * ratio)), 1 if ratio > 0.0 else 0, max_health)
	return true


func transform_into(other: Stats, other_intrinsics: Array[String]) -> bool:
	if other == null or other == self or transformed:
		return false
	types = other.types.duplicate()
	for stat in ["attack", "defense", "special_attack", "special_defense", "speed"]:
		proxy_stats[stat] = other.raw_battle_stat(stat)
	stat_stages = other.stat_stages.duplicate(true)
	move_slots = other.move_slots.duplicate()
	current_pp = []
	for move in move_slots:
		current_pp.append(mini(5, move.pp) if move != null else 0)
	var copied: Array[String] = []
	for slug in other_intrinsics:
		copied.append(String(slug))
	temporary_intrinsic_slugs = copied
	intrinsic_override_active = true
	weight_kg = other.weight_kg
	transformed = true
	return true


func reset_battle_modifiers() -> void:
	battle_statuses = {}
	transformed = false
	last_attacker = null
	consumed_berry_id = ""
	temporary_intrinsic_slugs = []
	intrinsic_override_active = false
	stat_stages = {}
	proxy_stats = {}
	battle_speed_multiplier = 1.0
	last_used_move_id = ""
	last_used_move_index = -1
	last_consumed_item_id = ""


func set_temporary_intrinsic(intrinsic_id: String, _payload: Dictionary = {}) -> void:
	var key: String = intrinsic_id.strip_edges().to_lower()
	if key.is_empty():
		return
	set_temporary_intrinsics([key], _payload)


func set_temporary_intrinsics(intrinsic_ids: Array, _payload: Dictionary = {}) -> void:
	intrinsic_override_active = true
	temporary_intrinsic_slugs = []
	for raw_id in intrinsic_ids:
		var key: String = String(raw_id).strip_edges().to_lower()
		if key.is_empty() or key == "none" or temporary_intrinsic_slugs.has(key):
			continue
		temporary_intrinsic_slugs.append(key)


func clear_temporary_intrinsics() -> void:
	intrinsic_override_active = false
	temporary_intrinsic_slugs = []


func apply_battle_status(status_id: String, payload: Dictionary = {}) -> Dictionary:
	var normalized: String = status_id.strip_edges().to_lower()
	if normalized.is_empty():
		return {}
	var before: Variant = battle_statuses.get(normalized, null)
	var next_payload: Dictionary = _default_status_payload(normalized)
	for key in payload.keys():
		next_payload[key] = payload[key]
	battle_statuses[normalized] = next_payload
	return {
		"status_id": normalized,
		"before": before,
		"after": battle_statuses[normalized],
	}


func remove_battle_status(status_id: String) -> Dictionary:
	var normalized: String = status_id.strip_edges().to_lower()
	if normalized.is_empty() or not battle_statuses.has(normalized):
		return {}
	var before: Variant = battle_statuses[normalized]
	battle_statuses.erase(normalized)
	return {
		"status_id": normalized,
		"before": before,
		"after": null,
	}


func record_move_use(move_id: String, slot_index: int) -> void:
	same_move_streak = same_move_streak + 1 if move_id == last_used_move_id and not move_id.is_empty() else 1
	last_used_move_id = move_id
	last_used_move_index = slot_index


func _default_status_payload(status_id: String) -> Dictionary:
	if DEFAULT_STATUS_PAYLOADS.has(status_id):
		return (DEFAULT_STATUS_PAYLOADS[status_id] as Dictionary).duplicate(true)
	return {}


func consume_turn_skip_status() -> Dictionary:
	for status_id in TURN_SKIP_STATUSES:
		if not battle_statuses.has(status_id):
			continue
		if status_id == "flinch":
			remove_battle_status(status_id)
			return {"status_id": status_id, "removed": true}
		return {"status_id": status_id, "removed": false}
	if battle_statuses.has("paralyze"):
		var payload: Variant = battle_statuses.get("paralyze", {})
		if payload is Dictionary and bool((payload as Dictionary).get("skip_turn", false)):
			var next_payload: Dictionary = (payload as Dictionary).duplicate(true)
			next_payload["skip_turn"] = false
			battle_statuses["paralyze"] = next_payload
			return {"status_id": "paralyze", "removed": false, "payload_updated": true}
	if battle_statuses.has("full_paralysis"):
		remove_battle_status("full_paralysis")
		return {"status_id": "full_paralysis", "removed": true}
	return {}


func change_stat_stage(stat_id: String, delta: int) -> Dictionary:
	var normalized: String = _normalize_stat_id(stat_id)
	if normalized.is_empty():
		return {}
	var before: int = int(stat_stages.get(normalized, 0))
	var after: int = clampi(before + delta, -6, 6)
	_write_stat_stage(normalized, after)
	return {
		"stat": normalized,
		"before": before,
		"after": after,
		"delta": after - before,
	}


func set_stat_stage(stat_id: String, value: int) -> Dictionary:
	var normalized: String = _normalize_stat_id(stat_id)
	if normalized.is_empty():
		return {}
	var before: int = int(stat_stages.get(normalized, 0))
	var after: int = clampi(value, -6, 6)
	_write_stat_stage(normalized, after)
	return {
		"stat": normalized,
		"before": before,
		"after": after,
		"delta": after - before,
	}


func get_stat_stage(stat_id: String) -> int:
	var normalized: String = _normalize_stat_id(stat_id)
	return int(stat_stages.get(normalized, 0)) if not normalized.is_empty() else 0


func set_proxy_stat(stat_id: String, value: int) -> Dictionary:
	var normalized: String = _normalize_stat_id(stat_id)
	if normalized.is_empty():
		return {}
	var before: int = raw_battle_stat(normalized)
	var after: int = maxi(1, value)
	proxy_stats[normalized] = after
	return {
		"stat": normalized,
		"before": before,
		"after": after,
		"delta": after - before,
	}


func raw_battle_stat(stat_id: String) -> int:
	var normalized: String = _normalize_stat_id(stat_id)
	if normalized.is_empty():
		return 0
	if proxy_stats.has(normalized):
		return int(proxy_stats[normalized])
	return _base_stat_value(normalized)


func battle_stat(stat_id: String) -> int:
	var normalized: String = _normalize_stat_id(stat_id)
	var base_value: int = raw_battle_stat(normalized)
	if base_value <= 0:
		return base_value
	var value: int = maxi(1, int(floor(float(base_value) * _stage_multiplier(get_stat_stage(normalized)))))
	if normalized == "speed":
		value = maxi(1, int(floor(float(value) * battle_speed_multiplier)))
	return value


func _write_stat_stage(stat_id: String, value: int) -> void:
	if value == 0:
		stat_stages.erase(stat_id)
	else:
		stat_stages[stat_id] = value


func _normalize_stat_id(stat_id: String) -> String:
	var key: String = stat_id.to_lower()
	if key.begins_with("mod_"):
		key = key.substr(4)
	match key:
		"atk": return "attack"
		"def": return "defense"
		"spa", "special_atk", "specialattack": return "special_attack"
		"spd", "special_def", "specialdefense": return "special_defense"
		"spe": return "speed"
		"attack", "defense", "special_attack", "special_defense", "speed", "accuracy", "evasion":
			return key
	return ""


func _base_stat_value(stat_id: String) -> int:
	match stat_id:
		"attack": return attack
		"defense": return defense
		"special_attack": return special_attack
		"special_defense": return special_defense
		"speed": return speed
		"accuracy", "evasion": return 100
	return 0


func _stage_multiplier(stage: int) -> float:
	var clamped: int = clampi(stage, -6, 6)
	if clamped >= 0:
		return float(2 + clamped) / 2.0
	return 2.0 / float(2 - clamped)


func is_active() -> bool:
	return battle_status == BattleStatus.ACTIVE


func apply_to_curr_health(new: int) -> void:
	print("Target initial health: ", curr_health, " - Health delta: ", new)
	curr_health = clamp(curr_health + new, 0, max_health)
	if curr_health <= 0:
		battle_status = BattleStatus.FAINTED
	elif battle_status == BattleStatus.FAINTED:
		battle_status = BattleStatus.ACTIVE
	print("Target final health: ", curr_health)
