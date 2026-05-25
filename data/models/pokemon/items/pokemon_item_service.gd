class_name PokemonItemService
extends RefCounted

const GENERATED_ITEMS_DIR: String = "res://data/models/pokemon/generated/items/"


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
		(result["unsupported"] as Array).append(String(tag))
	result["used"] = not (result["effects"] as Array).is_empty() or item.effect_records.is_empty()
	if item.is_consumable():
		_append(battle_log, {"kind": "item_used", "item_id": item.item_id, "target": target, "effects": result["effects"]})
	return result


static func equip_held_item(instance: PokemonInstanceResource, item: PokemonItemResource) -> bool:
	if instance == null or item == null or not item.is_holdable():
		return false
	instance.held_item = item
	return true


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
	if target is Stats:
		return (target as Stats).pokemon_instance
	return null


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
