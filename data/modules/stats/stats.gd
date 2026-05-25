class_name Stats
extends Node

enum BattleStatus { ACTIVE, FAINTED }

var modifiers: Dictionary = {}
var override_name: String
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
var stat_stages: Dictionary = {}


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


func reset_battle_modifiers() -> void:
	battle_statuses = {}
	temporary_intrinsic_slugs = []
	stat_stages = {}


func set_temporary_intrinsic(intrinsic_id: String, _payload: Dictionary = {}) -> void:
	var key: String = intrinsic_id.strip_edges().to_lower()
	if key.is_empty() or key == "none":
		return
	temporary_intrinsic_slugs = [key]


func apply_battle_status(status_id: String, payload: Dictionary = {}) -> Dictionary:
	if status_id.is_empty():
		return {}
	var before: Variant = battle_statuses.get(status_id, null)
	battle_statuses[status_id] = payload.duplicate(true)
	return {
		"status_id": status_id,
		"before": before,
		"after": battle_statuses[status_id],
	}


func remove_battle_status(status_id: String) -> Dictionary:
	if status_id.is_empty() or not battle_statuses.has(status_id):
		return {}
	var before: Variant = battle_statuses[status_id]
	battle_statuses.erase(status_id)
	return {
		"status_id": status_id,
		"before": before,
		"after": null,
	}


func change_stat_stage(stat_id: String, delta: int) -> Dictionary:
	var normalized: String = _normalize_stat_id(stat_id)
	if normalized.is_empty():
		return {}
	var before: int = int(stat_stages.get(normalized, 0))
	var after: int = clampi(before + delta, -6, 6)
	stat_stages[normalized] = after
	return {
		"stat": normalized,
		"before": before,
		"after": after,
		"delta": after - before,
	}


func get_stat_stage(stat_id: String) -> int:
	var normalized: String = _normalize_stat_id(stat_id)
	return int(stat_stages.get(normalized, 0)) if not normalized.is_empty() else 0


func battle_stat(stat_id: String) -> int:
	var normalized: String = _normalize_stat_id(stat_id)
	var base_value: int = _base_stat_value(normalized)
	if base_value <= 0:
		return base_value
	return maxi(1, int(floor(float(base_value) * _stage_multiplier(get_stat_stage(normalized)))))


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
