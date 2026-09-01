class_name PokemonItemService
extends RefCounted

const GENERATED_ITEMS_DIR: String = "res://data/models/pokemon/generated/items/"
const TAG_REMOVE_STATE_STATUS: String = "PMDC.Dungeon.RemoveStateStatusBattleEvent, PMDC"
const TAG_STATUS_STACK: String = "PMDC.Dungeon.StatusStackBattleEvent, PMDC"
const TAG_STATUS_BATTLE: String = "PMDC.Dungeon.StatusBattleEvent, PMDC"
const TYPE_BOOST_ITEMS: Dictionary = {
	"held_charcoal": "fire",
	"held_magnet": "electric",
	"held_metal_coat": "steel",
	"held_miracle_seed": "grass",
	"held_mystic_water": "water",
	"held_sharp_beak": "flying",
	"held_silk_scarf": "normal",
	"held_silver_powder": "bug",
	"held_twisted_spoon": "psychic",
}
const TYPE_RESIST_ITEMS: Dictionary = {
	"held_blank_plate": "normal",
	"held_draco_plate": "dragon",
	"held_dread_plate": "dark",
	"held_earth_plate": "ground",
	"held_fist_plate": "fighting",
	"held_flame_plate": "fire",
	"held_icicle_plate": "ice",
	"held_insect_plate": "bug",
	"held_iron_plate": "steel",
	"held_meadow_plate": "grass",
	"held_mind_plate": "psychic",
	"held_pixie_plate": "fairy",
	"held_sky_plate": "flying",
	"held_splash_plate": "water",
	"held_spooky_plate": "ghost",
	"held_stone_plate": "rock",
	"held_toxic_plate": "poison",
	"held_zap_plate": "electric",
}
const X_ITEM_STAGES: Dictionary = {
	"medicine_x_accuracy": ["accuracy", 2],
	"medicine_x_attack": ["attack", 2],
	"medicine_x_defense": ["defense", 2],
	"medicine_x_sp_atk": ["special_attack", 2],
	"medicine_x_sp_def": ["special_defense", 2],
	"medicine_x_speed": ["speed", 2],
}
const PINCH_BERRY_STAGES: Dictionary = {
	"berry_apicot": ["special_defense", 12],
	"berry_ganlon": ["defense", 12],
	"berry_liechi": ["attack", 12],
	"berry_micle": ["accuracy", 12],
	"berry_petaya": ["special_attack", 12],
	"berry_salac": ["speed", 12],
}
const STATUS_CURE_TAGS: Array[String] = [TAG_REMOVE_STATE_STATUS, "PMDC.Dungeon.AddContextStateEvent, PMDC"]


static func load_item(item_id: String) -> PokemonItemResource:
	if item_id.is_empty():
		return null
	var path: String = "%s%s.tres" % [GENERATED_ITEMS_DIR, item_id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PokemonItemResource


static func use_item(
		item: PokemonItemResource,
		target: Variant,
		bag: PokemonBagResource = null,
		battle_log: BattleLog = null,
		options: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"used": false,
		"item_id": item.item_id if item != null else "",
		"effects": [],
		"unsupported": [],
	}
	if item == null:
		result["reason"] = "missing_item"
		return result
	if bag != null and bool(options.get("consume_from_bag", true)):
		if not bag.remove_item(item, 1):
			result["reason"] = "item_not_in_bag"
			return result
	var instance: PokemonInstanceResource = _target_instance(target)
	var stats: Stats = target as Stats if target is Stats else null
	for record in item.effect_records:
		var effect: Dictionary = _apply_effect_record(item, record, instance, stats, options, battle_log)
		if effect.is_empty():
			(result["unsupported"] as Array).append(record)
		else:
			(result["effects"] as Array).append(effect)
	for tag in item.unsupported_effect_tags:
		var unsupported_effect: Dictionary = _apply_unsupported_effect_tag(item, String(tag), instance, stats, options, battle_log)
		if unsupported_effect.is_empty():
			(result["unsupported"] as Array).append(String(tag))
		else:
			(result["effects"] as Array).append(unsupported_effect)
	result["used"] = not (result["effects"] as Array).is_empty() or item.effect_records.is_empty()
	if item.is_consumable():
		_append(battle_log, {"kind": "item_used", "item_id": item.item_id, "target": target, "effects": result["effects"]})
	return result


static func equip_held_item(instance: PokemonInstanceResource, item: PokemonItemResource) -> bool:
	if instance == null or item == null or not _can_be_held(item):
		return false
	instance.held_item = item
	return true


static func held_item_for(target: Variant) -> PokemonItemResource:
	var instance: PokemonInstanceResource = _target_instance(target)
	return instance.held_item if instance != null else null


static func give_held_item(target: Variant, item: PokemonItemResource, battle_log: BattleLog = null, source: String = "") -> bool:
	var instance: PokemonInstanceResource = _target_instance(target)
	if instance == null or item == null or not _can_be_held(item):
		return false
	var before: String = instance.held_item.item_id if instance.held_item != null else ""
	instance.held_item = item
	_append(battle_log, {"kind": "held_item_changed", "target": target, "before_item_id": before, "after_item_id": item.item_id, "source": source})
	return true


static func take_held_item(target: Variant, battle_log: BattleLog = null, source: String = "") -> PokemonItemResource:
	var instance: PokemonInstanceResource = _target_instance(target)
	if instance == null or instance.held_item == null:
		return null
	var item: PokemonItemResource = instance.held_item
	instance.held_item = null
	_append(battle_log, {"kind": "held_item_removed", "target": target, "item_id": item.item_id, "source": source})
	return item


static func swap_held_items(first: Variant, second: Variant, battle_log: BattleLog = null, source: String = "") -> bool:
	var first_instance: PokemonInstanceResource = _target_instance(first)
	var second_instance: PokemonInstanceResource = _target_instance(second)
	if first_instance == null or second_instance == null:
		return false
	var first_item: PokemonItemResource = first_instance.held_item
	first_instance.held_item = second_instance.held_item
	second_instance.held_item = first_item
	_append(battle_log, {
		"kind": "held_items_swapped",
		"first": first,
		"second": second,
		"first_item_id": first_instance.held_item.item_id if first_instance.held_item != null else "",
		"second_item_id": second_instance.held_item.item_id if second_instance.held_item != null else "",
		"source": source,
	})
	return true


static func consume_held_item(target: Variant, battle_log: BattleLog = null, source: String = "") -> PokemonItemResource:
	var item: PokemonItemResource = take_held_item(target, battle_log, source)
	if item != null:
		var stats: Stats = _target_stats(target)
		if stats != null:
			stats.last_consumed_item_id = item.item_id
		_append(battle_log, {"kind": "held_item_consumed", "target": target, "item_id": item.item_id, "source": source})
	return item


static func knock_off_held_item(target: Variant, battle_log: BattleLog = null, source: String = "") -> PokemonItemResource:
	var item: PokemonItemResource = take_held_item(target, battle_log, source)
	if item != null:
		_append(battle_log, {"kind": "held_item_knocked_off", "target": target, "item_id": item.item_id, "source": source})
	return item


static func apply_held_effects_to_stats(stats: Stats, battle_log: BattleLog = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if stats == null or stats.pokemon_instance == null or stats.pokemon_instance.held_item == null:
		return out
	var calculated: Dictionary = PokemonStatCalculator.calculate_for_instance(stats.pokemon_instance)
	for record in stats.pokemon_instance.held_item.passive_effect_records:
		if String(record.get("family", "")) != "held_stat_modifier":
			continue
		var stat: String = PokemonStatCalculator.normalize_stat_id(String(record.get("stat", "")))
		var target_value: int = int(calculated.get(stat, 0))
		var old_value: int = 0
		match stat:
			"attack":
				old_value = stats.attack
				stats.attack = target_value
			"defense":
				old_value = stats.defense
				stats.defense = target_value
			"special_attack":
				old_value = stats.special_attack
				stats.special_attack = target_value
			"special_defense":
				old_value = stats.special_defense
				stats.special_defense = target_value
			"speed":
				old_value = stats.speed
				stats.speed = target_value
			"hp":
				old_value = stats.max_health
				stats.hp_max = target_value
				stats.max_health = target_value
				stats.curr_health = mini(stats.curr_health + maxi(0, target_value - old_value), stats.max_health)
			_:
				continue
		var amount: int = target_value - old_value
		if amount == 0:
			continue
		var event: Dictionary = {
			"kind": "item_passive_applied",
			"item_id": stats.pokemon_instance.held_item.item_id,
			"stat": stat,
			"amount": amount,
		}
		out.append(event)
		_append(battle_log, event)
	return out


static func held_damage_multiplier(attacker: Stats, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null) -> float:
	if attacker == null or move == null or attacker.pokemon_instance == null or attacker.pokemon_instance.held_item == null:
		return 1.0
	var item: PokemonItemResource = attacker.pokemon_instance.held_item
	var multiplier: float = 1.0
	if item.item_id == "held_life_orb" and move.is_damaging():
		multiplier *= 1.3
	elif TYPE_BOOST_ITEMS.has(item.item_id) and String(TYPE_BOOST_ITEMS[item.item_id]) == move.type:
		multiplier *= 1.2
	if is_equal_approx(multiplier, 1.0):
		return 1.0
	_append(battle_log, {
		"kind": "held_item_triggered",
		"item_id": item.item_id,
		"unit": pawn,
		"move_id": move.move_id,
		"hook": "damage_multiplier",
		"multiplier": multiplier,
	})
	return multiplier


static func held_defense_multiplier(defender: Stats, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null) -> float:
	if defender == null or move == null or defender.pokemon_instance == null or defender.pokemon_instance.held_item == null:
		return 1.0
	var item: PokemonItemResource = defender.pokemon_instance.held_item
	if not TYPE_RESIST_ITEMS.has(item.item_id) or String(TYPE_RESIST_ITEMS[item.item_id]) != move.type:
		return 1.0
	_append(battle_log, {
		"kind": "held_item_triggered",
		"item_id": item.item_id,
		"unit": pawn,
		"move_id": move.move_id,
		"hook": "defense_multiplier",
		"multiplier": 0.5,
	})
	return 0.5


static func after_damage_dealt(attacker: TacticsPawn, move: PokemonMoveResource, damage_done: int, battle_log: BattleLog = null) -> void:
	if attacker == null or attacker.stats == null or damage_done <= 0 or attacker.stats.pokemon_instance == null or attacker.stats.pokemon_instance.held_item == null:
		return
	var item: PokemonItemResource = attacker.stats.pokemon_instance.held_item
	if item.item_id != "held_life_orb" or not move.is_damaging():
		return
	var recoil: int = maxi(1, int(floor(float(attacker.stats.max_health) / 10.0)))
	var before: int = attacker.stats.curr_health
	attacker.stats.apply_to_curr_health(-recoil)
	_append(battle_log, {
		"kind": "damage_dealt",
		"attacker": attacker,
		"defender": attacker,
		"move_id": move.move_id,
		"amount": before - attacker.stats.curr_health,
		"source": "held_item",
		"item_id": item.item_id,
	})


static func try_trigger_held_threshold(target: TacticsPawn, battle_log: BattleLog = null) -> bool:
	if target == null or target.stats == null or target.stats.pokemon_instance == null or target.stats.pokemon_instance.held_item == null:
		return false
	var item: PokemonItemResource = target.stats.pokemon_instance.held_item
	if target.stats.curr_health <= 0 or target.stats.curr_health > int(floor(float(target.stats.max_health) / 4.0)):
		return false
	if PINCH_BERRY_STAGES.has(item.item_id):
		var pair: Array = PINCH_BERRY_STAGES[item.item_id]
		var change: Dictionary = target.stats.change_stat_stage(String(pair[0]), int(pair[1]))
		consume_held_item(target.stats, battle_log, "threshold")
		_append(battle_log, {
			"kind": "held_item_triggered",
			"item_id": item.item_id,
			"unit": target,
			"hook": "threshold_stat_stage",
			"stat": change.get("stat", String(pair[0])),
			"delta": change.get("delta", int(pair[1])),
		})
		return true
	if item.item_id == "berry_oran" or item.item_id == "berry_sitrus":
		var before: int = target.stats.curr_health
		target.stats.apply_to_curr_health(maxi(1, int(floor(float(target.stats.max_health) / 4.0))))
		consume_held_item(target.stats, battle_log, "threshold")
		_append(battle_log, {
			"kind": "held_item_triggered",
			"item_id": item.item_id,
			"unit": target,
			"hook": "threshold_heal",
			"amount": target.stats.curr_health - before,
		})
		return true
	return false


static func validation_report(limit: int = 0) -> Dictionary:
	var item_count: int = 0
	var supported: int = 0
	var unsupported: int = 0
	var held_passives: int = 0
	var categories: Dictionary = {}
	for item in _all_items(limit):
		item_count += 1
		categories[item.category] = int(categories.get(item.category, 0)) + 1
		if not item.effect_records.is_empty():
			supported += 1
		if not item.unsupported_effect_tags.is_empty():
			unsupported += 1
		if not item.passive_effect_records.is_empty():
			held_passives += 1
	return {
		"items": item_count,
		"items_with_supported_effects": supported,
		"items_with_unsupported_effects": unsupported,
		"held_passive_items": held_passives,
		"categories": categories,
	}


static func _apply_effect_record(
		item: PokemonItemResource,
		record: Dictionary,
		instance: PokemonInstanceResource,
		stats: Stats,
		options: Dictionary,
		battle_log: BattleLog
) -> Dictionary:
	var family: String = String(record.get("family", ""))
	match family:
		"heal":
			return _heal(item, record, instance, stats, battle_log)
		"restore_pp":
			return _restore_pp(item, record, instance, stats, battle_log)
		"permanent_stat":
			return _permanent_stat(item, record, instance, stats, battle_log)
		"level_change":
			return _level_change(item, record, instance, stats, options, battle_log)
		"teach_move":
			return _teach_move(item, record, instance, options, battle_log)
	return {}


static func _apply_unsupported_effect_tag(
		item: PokemonItemResource,
		tag: String,
		instance: PokemonInstanceResource,
		stats: Stats,
		_options: Dictionary,
		battle_log: BattleLog
) -> Dictionary:
	if tag == TAG_STATUS_STACK:
		return _apply_item_stat_stage(item, stats, battle_log)
	if tag == TAG_REMOVE_STATE_STATUS or (STATUS_CURE_TAGS.has(tag) and _is_curer_item(item)):
		var cure: Dictionary = _cure_battle_statuses(item, stats, battle_log)
		return cure if not cure.is_empty() else {"family": "cure_statuses", "statuses": []}
	if tag == TAG_STATUS_BATTLE:
		return _apply_item_status(item, stats, battle_log)
	return {}


static func _apply_item_stat_stage(item: PokemonItemResource, stats: Stats, battle_log: BattleLog) -> Dictionary:
	if stats == null:
		return {}
	var pair: Array = []
	if X_ITEM_STAGES.has(item.item_id):
		pair = X_ITEM_STAGES[item.item_id]
	elif PINCH_BERRY_STAGES.has(item.item_id):
		pair = PINCH_BERRY_STAGES[item.item_id]
	else:
		return {}
	var change: Dictionary = stats.change_stat_stage(String(pair[0]), int(pair[1]))
	if change.is_empty():
		return {}
	_append(battle_log, {"kind": "item_stat_stage_changed", "item_id": item.item_id, "stat": change["stat"], "delta": change["delta"], "after": change["after"]})
	return {"family": "stat_stage", "stat": change["stat"], "delta": change["delta"], "after": change["after"]}


static func _cure_battle_statuses(item: PokemonItemResource, stats: Stats, battle_log: BattleLog) -> Dictionary:
	if stats == null:
		return {}
	var removed: Array[String] = []
	for raw_status in stats.battle_statuses.keys():
		removed.append(String(raw_status))
	for status_id in removed:
		stats.remove_battle_status(status_id)
	if removed.is_empty():
		return {}
	_append(battle_log, {"kind": "item_status_cured", "item_id": item.item_id, "statuses": removed})
	return {"family": "cure_statuses", "statuses": removed}


static func _apply_item_status(item: PokemonItemResource, stats: Stats, battle_log: BattleLog) -> Dictionary:
	if stats == null:
		return {}
	if item.item_id == "berry_sitrus":
		stats.apply_battle_status("aqua_ring", {"source": "item", "item_id": item.item_id, "counter": 4, "hp_fraction": 8})
		_append(battle_log, {"kind": "status_applied", "item_id": item.item_id, "status_id": "aqua_ring", "source": "item"})
		return {"family": "status", "status_id": "aqua_ring"}
	return {}


static func _heal(item: PokemonItemResource, record: Dictionary, instance: PokemonInstanceResource, stats: Stats, battle_log: BattleLog) -> Dictionary:
	var max_hp: int = stats.max_health if stats != null else PokemonStatCalculator.max_hp(instance)
	var before: int = stats.curr_health if stats != null else (max_hp if instance.current_hp == PokemonInstanceResource.CURRENT_HP_AUTO else instance.current_hp)
	var amount: int = int(record.get("amount", 0))
	if amount <= 0:
		var numerator: int = int(record.get("numerator", 1))
		var denominator: int = maxi(1, int(record.get("denominator", 1)))
		amount = int(floor(float(max_hp) * float(numerator) / float(denominator)))
	var after: int = clampi(before + amount, 0, max_hp)
	if stats != null:
		stats.curr_health = after
		if stats.curr_health > 0 and not stats.is_active():
			stats.battle_status = Stats.BattleStatus.ACTIVE
	elif instance != null:
		instance.current_hp = after
	_append(battle_log, {"kind": "item_healed", "item_id": item.item_id, "amount": after - before, "before": before, "after": after})
	return {"family": "heal", "amount": after - before, "before": before, "after": after}


static func _restore_pp(item: PokemonItemResource, record: Dictionary, instance: PokemonInstanceResource, stats: Stats, battle_log: BattleLog) -> Dictionary:
	var amount: int = int(record.get("amount", -1))
	var restored: int = 0
	var moves: Array[PokemonMoveResource] = stats.move_slots if stats != null else (instance.move_slots if instance != null else [])
	var pp: Array[int] = stats.current_pp if stats != null else (instance.pp_state if instance != null else [])
	while pp.size() < moves.size():
		pp.append(0)
	for i in range(moves.size()):
		var move: PokemonMoveResource = moves[i]
		if move == null:
			continue
		var before: int = int(pp[i])
		var after: int = move.pp if amount < 0 else mini(move.pp, before + amount)
		pp[i] = after
		restored += after - before
	if stats != null:
		stats.current_pp = pp
	elif instance != null:
		instance.pp_state = pp
	_append(battle_log, {"kind": "item_pp_restored", "item_id": item.item_id, "amount": restored})
	return {"family": "restore_pp", "amount": restored}


static func _permanent_stat(item: PokemonItemResource, record: Dictionary, instance: PokemonInstanceResource, stats: Stats, battle_log: BattleLog) -> Dictionary:
	if instance == null and stats != null:
		instance = stats.pokemon_instance
	if instance == null:
		return {}
	var stat: String = PokemonStatCalculator.normalize_stat_id(String(record.get("stat", "")))
	var amount: int = int(record.get("amount", 1))
	if stat.is_empty():
		return {}
	instance.permanent_modifiers[stat] = int(instance.permanent_modifiers.get(stat, 0)) + amount
	if stats != null:
		match stat:
			"hp":
				stats.hp_max += amount
				stats.max_health += amount
				stats.curr_health += amount
			"attack":
				stats.attack += amount
			"defense":
				stats.defense += amount
			"special_attack":
				stats.special_attack += amount
			"special_defense":
				stats.special_defense += amount
			"speed":
				stats.speed += amount
	_append(battle_log, {"kind": "item_permanent_stat_changed", "item_id": item.item_id, "stat": stat, "amount": amount})
	return {"family": "permanent_stat", "stat": stat, "amount": amount}


static func _level_change(item: PokemonItemResource, record: Dictionary, instance: PokemonInstanceResource, stats: Stats, options: Dictionary, battle_log: BattleLog) -> Dictionary:
	if instance == null and stats != null:
		instance = stats.pokemon_instance
	if instance == null:
		return {}
	var old_level: int = instance.level
	var target_level: int = clampi(old_level + int(record.get("levels", 1)), PokemonExperienceService.MIN_LEVEL, PokemonExperienceService.MAX_LEVEL)
	var needed_xp: int = PokemonExperienceService.xp_for_level(instance.resolved_form(), target_level) - maxi(instance.experience, PokemonExperienceService.xp_for_level(instance.resolved_form(), old_level))
	var xp_result: Dictionary = PokemonExperienceService.apply_xp(instance, maxi(0, needed_xp), options.get("replacement_choices", {}))
	if stats != null:
		stats.init_from_pokemon(instance)
	_append(battle_log, {"kind": "item_level_changed", "item_id": item.item_id, "old_level": old_level, "new_level": instance.level})
	return {"family": "level_change", "old_level": old_level, "new_level": instance.level, "xp_result": xp_result}


static func _teach_move(item: PokemonItemResource, record: Dictionary, instance: PokemonInstanceResource, options: Dictionary, battle_log: BattleLog) -> Dictionary:
	if instance == null:
		return {}
	var move_id: String = String(record.get("move_id", ""))
	var learn_result: Dictionary = PokemonLearnsetService.apply_new_moves(instance, [move_id], options.get("replacement_choices", {}))
	_append(battle_log, {"kind": "item_move_taught", "item_id": item.item_id, "move_id": move_id, "result": learn_result})
	return {"family": "teach_move", "move_id": move_id, "result": learn_result}


static func _target_instance(target: Variant) -> PokemonInstanceResource:
	if target is PokemonInstanceResource:
		return target as PokemonInstanceResource
	if target is TacticsPawn:
		var pawn: TacticsPawn = target as TacticsPawn
		return pawn.stats.pokemon_instance if pawn.stats != null else null
	if target is Stats:
		return (target as Stats).pokemon_instance
	return null


static func _target_stats(target: Variant) -> Stats:
	if target is Stats:
		return target as Stats
	if target is TacticsPawn:
		return (target as TacticsPawn).stats
	return null


static func _can_be_held(item: PokemonItemResource) -> bool:
	if item == null:
		return false
	return item.is_holdable() or item.category == "berry" or item.category == "seed" or item.category == "medicine"


static func _is_curer_item(item: PokemonItemResource) -> bool:
	if item == null:
		return false
	return item.item_states.has("PMDC.Dungeon.CurerState, PMDC") or item.item_id == "berry_lum" or item.item_id == "medicine_full_heal"


static func _all_items(limit: int = 0) -> Array[PokemonItemResource]:
	var out: Array[PokemonItemResource] = []
	var dir: DirAccess = DirAccess.open(GENERATED_ITEMS_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".tres"):
			var item: PokemonItemResource = load("%s%s" % [GENERATED_ITEMS_DIR, filename]) as PokemonItemResource
			if item != null:
				out.append(item)
				if limit > 0 and out.size() >= limit:
					break
		filename = dir.get_next()
	dir.list_dir_end()
	return out


static func _append(battle_log: BattleLog, event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)
