class_name PokemonItemService
extends RefCounted

const GENERATED_ITEMS_DIR: String = "res://data/models/pokemon/generated/items/"
const CUSTOM_ITEMS_DIR: String = "res://data/models/pokemon/items/custom/"
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
	"held_black_belt": "fighting",
	"held_black_glasses": "dark",
	"held_hard_stone": "rock",
	"held_never_melt_ice": "ice",
	"held_poison_barb": "poison",
	"held_soft_sand": "ground",
	"held_spell_tag": "ghost",
	"held_dragon_scale": "dragon",
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
const RESIST_BERRIES: Dictionary = {
	"berry_occa": "fire",
	"berry_passho": "water",
	"berry_wacan": "electric",
	"berry_rindo": "grass",
	"berry_yache": "ice",
	"berry_chople": "fighting",
	"berry_kebia": "poison",
	"berry_shuca": "ground",
	"berry_coba": "flying",
	"berry_payapa": "psychic",
	"berry_tanga": "bug",
	"berry_charti": "rock",
	"berry_kasib": "ghost",
	"berry_haban": "dragon",
	"berry_colbur": "dark",
	"berry_babiri": "steel",
	"berry_roseli": "fairy",
	"berry_chilan": "normal",
}
const CHOICE_ITEMS: Array[String] = ["held_choice_band", "held_choice_specs", "held_choice_scarf"]
const HIT_REACTION_ITEMS: Dictionary = {"held_absorb_bulb": ["water", "special_attack"], "held_cell_battery": ["electric", "attack"], "held_luminous_moss": ["water", "special_defense"], "held_snowball": ["ice", "attack"]}
const CUSTAP_SPEED_MULTIPLIER: float = 100.0
const CATEGORY_REACTION_BERRIES: Dictionary = {"berry_kee": [PokemonMoveResource.CATEGORY_PHYSICAL, "defense"], "berry_maranga": [PokemonMoveResource.CATEGORY_SPECIAL, "special_defense"]}
const WEATHER_ROCKS: Dictionary = {"held_damp_rock": "rain", "held_heat_rock": "sunny", "held_smooth_rock": "sandstorm", "held_icy_rock": "hail"}
const FLINCH_ITEMS: Array[String] = ["held_kings_rock", "held_razor_fang"]
const SPECIES_ITEMS: Dictionary = {"held_light_ball": ["pikachu"], "held_thick_club": ["cubone", "marowak"]}
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
const CURE_BERRIES: Dictionary = {
	"berry_cheri": ["paralyze"],
	"berry_chesto": ["sleep"],
	"berry_pecha": ["poison", "poison_toxic"],
	"berry_rawst": ["burn"],
	"berry_aspear": ["freeze"],
	"berry_persim": ["confuse"],
	"berry_lum": ["paralyze", "sleep", "poison", "poison_toxic", "burn", "freeze", "confuse"],
}
const STATUS_CURE_TAGS: Array[String] = [TAG_REMOVE_STATE_STATUS, "PMDC.Dungeon.AddContextStateEvent, PMDC"]


static func load_item(item_id: String) -> PokemonItemResource:
	if item_id.is_empty():
		return null
	var path: String = "%s%s.tres" % [GENERATED_ITEMS_DIR, item_id]
	if not ResourceLoader.exists(path):
		path = "%s%s.tres" % [CUSTOM_ITEMS_DIR, item_id]
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


const STEAL_SOURCES: Array[String] = ["pickpocket", "magician", "steal", "knock_off", "switcheroo", "trick", "thief", "covet", "sticky_barb"]


static func items_disabled(stats: Stats) -> bool:
	return stats != null and (BattleIntrinsicService.natural_slugs_static(stats).has("klutz") or stats.battle_statuses.has("embargo"))


static func take_held_item(target: Variant, battle_log: BattleLog = null, source: String = "") -> PokemonItemResource:
	var instance: PokemonInstanceResource = _target_instance(target)
	if instance == null or instance.held_item == null:
		return null
	if STEAL_SOURCES.has(source):
		var holder_stats: Stats = _target_stats(target)
		if holder_stats != null and (BattleIntrinsicService.natural_slugs_static(holder_stats).has("sticky_hold") or (BattleIntrinsicService.natural_slugs_static(holder_stats).has("multitype") and instance.held_item.item_id.ends_with("_plate"))):
			_append(battle_log, {"kind": "held_item_protected", "target": target, "item_id": instance.held_item.item_id, "source": source})
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
		if target is TacticsPawn and item.item_id.begins_with("berry_"):
			var ops: BattleStateOps = BattleStateOps.for_pawn(target, battle_log)
			if ops.intrinsic_service != null:
				ops.intrinsic_service.on_berry_consumed(target, item.item_id, battle_log)
				if ops.intrinsic_service.intrinsic_slugs_for((target as TacticsPawn).stats).has("cud_chew"):
					ops.apply_status(target, "cud_chew", {"item_id": item.item_id}, {"kind": "intrinsic", "intrinsic_id": "cud_chew", "skip_rules": true})
			_symbiosis_pass(target, battle_log)
	return item


static func _symbiosis_pass(target: TacticsPawn, battle_log: BattleLog) -> void:
	var ops: BattleStateOps = BattleStateOps.for_pawn(target, battle_log)
	if ops.battle_level == null or ops.intrinsic_service == null or held_item_for(target.stats) != null:
		return
	for ally in ops.battle_level.units_on_map():
		if ally == target or ally.stats == null or not ally.stats.is_active() or ops.battle_level.are_foes(target, ally):
			continue
		if ops.intrinsic_service.intrinsic_slugs_for(ally.stats).has("symbiosis") and held_item_for(ally.stats) != null:
			var passed: PokemonItemResource = take_held_item(ally, battle_log, "symbiosis")
			if passed != null and give_held_item(target, passed, battle_log, "symbiosis"):
				_append(battle_log, {"kind": "intrinsic_triggered", "hook": "symbiosis", "unit": ally, "intrinsic_id": "symbiosis", "item_id": passed.item_id})
			return


static func cud_chew(pawn: TacticsPawn, item_id: String, battle_log: BattleLog = null) -> void:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active() or item_id.is_empty():
		return
	var ops: BattleStateOps = BattleStateOps.for_pawn(pawn, battle_log)
	if item_id == "berry_sitrus":
		ops.heal(pawn, maxi(1, int(floor(float(pawn.stats.max_health) / 4.0))), {"kind": "held_item", "item_id": item_id})
	elif item_id == "berry_oran":
		ops.heal(pawn, 10, {"kind": "held_item", "item_id": item_id})
	elif CURE_BERRIES.has(item_id):
		for status_id in CURE_BERRIES[item_id]:
			if pawn.stats.battle_statuses.has(String(status_id)):
				ops.remove_status(pawn, String(status_id), {"source": "held_item", "item_id": item_id})
	elif PINCH_BERRY_STAGES.has(item_id):
		var pair: Array = PINCH_BERRY_STAGES[item_id]
		ops.change_stat_stage(pawn, String(pair[0]), int(pair[1]), {"kind": "held_item", "item_id": item_id})
	else:
		return
	_append(battle_log, {"kind": "intrinsic_triggered", "hook": "cud_chew", "unit": pawn, "intrinsic_id": "cud_chew", "item_id": item_id})


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
	stats.battle_speed_multiplier = 1.0
	_apply_speed_multiplier(stats, null, battle_log)
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


static func held_damage_multiplier(attacker: Stats, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null, effectiveness: float = 1.0) -> float:
	if attacker == null or move == null or attacker.pokemon_instance == null or attacker.pokemon_instance.held_item == null:
		return 1.0
	if items_disabled(attacker):
		return 1.0
	var item: PokemonItemResource = attacker.pokemon_instance.held_item
	var multiplier: float = 1.0
	if item.item_id == "held_life_orb" and move.is_damaging():
		multiplier *= 1.3
	if TYPE_BOOST_ITEMS.has(item.item_id) and String(TYPE_BOOST_ITEMS[item.item_id]) == move.type:
		multiplier *= 1.2
	if item.item_id == "held_choice_band" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		multiplier *= 1.5
	if item.item_id == "held_choice_specs" and move.category == PokemonMoveResource.CATEGORY_SPECIAL:
		multiplier *= 1.5
	if item.item_id == "held_expert_belt" and effectiveness > 1.0:
		multiplier *= 1.2
	if item.item_id == "held_metronome" and move.is_damaging() and attacker.same_move_streak > 1:
		multiplier *= 1.0 + 0.2 * float(mini(attacker.same_move_streak - 1, 5))
	if item.item_id == "held_muscle_band" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		multiplier *= 1.1
	if item.item_id == "held_wise_glasses" and move.category == PokemonMoveResource.CATEGORY_SPECIAL:
		multiplier *= 1.1
	if item.item_id == "held_punching_glove" and move.has_flag("fist"):
		multiplier *= 1.1
	if SPECIES_ITEMS.has(item.item_id) and _species_matches(attacker, SPECIES_ITEMS[item.item_id]) and move.is_damaging():
		multiplier *= 2.0
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


static func held_defense_multiplier(defender: Stats, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null, effectiveness: float = 1.0) -> float:
	if defender == null or move == null or defender.pokemon_instance == null or defender.pokemon_instance.held_item == null:
		return 1.0
	if items_disabled(defender):
		return 1.0
	var item: PokemonItemResource = defender.pokemon_instance.held_item
	var multiplier: float = 1.0
	if item.item_id == "held_assault_vest" and move.category == PokemonMoveResource.CATEGORY_SPECIAL:
		multiplier = 2.0 / 3.0
	elif item.item_id == "held_eviolite" and defender.pokemon_instance.species != null and not defender.pokemon_instance.species.evolutions.is_empty():
		multiplier = 2.0 / 3.0
	elif RESIST_BERRIES.has(item.item_id) and String(RESIST_BERRIES[item.item_id]) == move.type and move.is_damaging() and (effectiveness > 1.0 or item.item_id == "berry_chilan"):
		multiplier = 0.5
		consume_held_item(pawn if pawn != null else defender, battle_log, "resist_berry")
	if is_equal_approx(multiplier, 1.0):
		return 1.0
	_append(battle_log, {
		"kind": "held_item_triggered",
		"item_id": item.item_id,
		"unit": pawn,
		"move_id": move.move_id,
		"hook": "defense_multiplier",
		"multiplier": multiplier,
	})
	return multiplier


static func after_damage_dealt(attacker: TacticsPawn, move: PokemonMoveResource, damage_done: int, battle_log: BattleLog = null) -> void:
	if attacker == null or attacker.stats == null or damage_done <= 0 or attacker.stats.pokemon_instance == null or attacker.stats.pokemon_instance.held_item == null or items_disabled(attacker.stats):
		return
	var item: PokemonItemResource = attacker.stats.pokemon_instance.held_item
	if item.item_id == "held_shell_bell" and move.is_damaging():
		BattleStateOps.for_pawn(attacker, battle_log).heal(attacker, maxi(1, int(floor(float(damage_done) / 8.0))), {"kind": "held_item", "item_id": item.item_id, "move": move})
		return
	if item.item_id != "held_life_orb" or not move.is_damaging():
		return
	var recoil: int = maxi(1, int(floor(float(attacker.stats.max_health) / 10.0)))
	BattleStateOps.for_pawn(attacker, battle_log).damage(attacker, recoil, {"kind": "held_item", "attacker": attacker, "move": move, "item_id": item.item_id, "event": {"source": "held_item"}})


static func after_hit_taken(defender: TacticsPawn, attacker: TacticsPawn, move: PokemonMoveResource, damage_done: int, effectiveness: float, battle_log: BattleLog = null) -> void:
	if defender == null or defender.stats == null or attacker == null or attacker.stats == null or move == null or damage_done <= 0:
		return
	var item: PokemonItemResource = held_item_for(defender.stats)
	if item == null or items_disabled(defender.stats):
		return
	var ops: BattleStateOps = BattleStateOps.for_pawn(defender, battle_log)
	if HIT_REACTION_ITEMS.has(item.item_id) and move.type == String(HIT_REACTION_ITEMS[item.item_id][0]) and defender.stats.is_active():
		consume_held_item(defender, battle_log, "on_hit")
		ops.change_stat_stage(defender, String(HIT_REACTION_ITEMS[item.item_id][1]), 1, {"kind": "held_item", "item_id": item.item_id})
		_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": defender, "hook": "on_hit_stat"})
		return
	if CATEGORY_REACTION_BERRIES.has(item.item_id) and move.category == int(CATEGORY_REACTION_BERRIES[item.item_id][0]) and defender.stats.is_active():
		consume_held_item(defender, battle_log, "on_hit")
		ops.change_stat_stage(defender, String(CATEGORY_REACTION_BERRIES[item.item_id][1]), 1, {"kind": "held_item", "item_id": item.item_id})
		_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": defender, "hook": "on_hit_stat"})
		return
	match item.item_id:
		"held_rocky_helmet":
			if move.has_flag("contact") and attacker != defender and attacker.stats.is_active() and not _contact_shielded(attacker.stats, move):
				ops.damage(attacker, maxi(1, int(floor(float(attacker.stats.max_health) / 6.0))), {"kind": "held_item", "attacker": defender, "move": move, "item_id": item.item_id, "event": {"source": "held_item"}})
				_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": defender, "hook": "contact_recoil"})
		"held_weakness_policy":
			if effectiveness > 1.0 and defender.stats.is_active():
				consume_held_item(defender, battle_log, "on_hit")
				ops.change_stat_stage(defender, "attack", 2, {"kind": "held_item", "item_id": item.item_id})
				ops.change_stat_stage(defender, "special_attack", 2, {"kind": "held_item", "item_id": item.item_id})
				_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": defender, "hook": "on_hit_stat"})
		"held_air_balloon":
			consume_held_item(defender, battle_log, "popped")
			_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": defender, "hook": "popped"})
		"held_red_card":
			if attacker != defender and attacker.stats.is_active() and ops.battle_level != null:
				consume_held_item(defender, battle_log, "on_hit")
				_knock_back(defender, attacker, 2, ops.battle_level, battle_log, item.item_id)
		"berry_jaboca", "berry_rowap":
			var wanted: int = PokemonMoveResource.CATEGORY_PHYSICAL if item.item_id == "berry_jaboca" else PokemonMoveResource.CATEGORY_SPECIAL
			if move.category == wanted and attacker != defender and attacker.stats.is_active():
				consume_held_item(defender, battle_log, "on_hit")
				ops.damage(attacker, maxi(1, int(floor(float(attacker.stats.max_health) / 8.0))), {"kind": "held_item", "attacker": defender, "move": move, "item_id": item.item_id, "event": {"source": "held_item"}})
				_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": defender, "hook": "on_hit_recoil"})
		"berry_enigma":
			if effectiveness > 1.0 and defender.stats.is_active():
				consume_held_item(defender, battle_log, "on_hit")
				ops.heal(defender, maxi(1, int(floor(float(defender.stats.max_health) / 4.0))), {"kind": "held_item", "item_id": item.item_id, "move": move})
				_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": defender, "hook": "on_hit_heal"})
		"held_sticky_barb":
			if move.has_flag("contact") and attacker != defender and held_item_for(attacker.stats) == null and attacker.stats.is_active():
				var barb: PokemonItemResource = take_held_item(defender, battle_log, "sticky_barb")
				if barb != null:
					give_held_item(attacker, barb, battle_log, "sticky_barb")
					_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": attacker, "hook": "sticky_barb_transfer"})


static func apply_speed_multipliers(units: Array[BattleUnit], battle_log: BattleLog = null) -> void:
	for unit in units:
		if unit == null or unit.stats == null or not unit.stats.is_active():
			continue
		_apply_speed_multiplier(unit.stats, unit.pawn, battle_log)


static func _apply_speed_multiplier(stats: Stats, pawn: TacticsPawn, battle_log: BattleLog) -> void:
	var item: PokemonItemResource = held_item_for(stats)
	if item == null or items_disabled(stats):
		return
	match item.item_id:
		"held_iron_ball":
			stats.battle_speed_multiplier *= 0.5
		"held_lagging_tail":
			stats.battle_speed_multiplier *= 0.1
		"berry_custap":
			if pawn == null or stats.curr_health <= 0:
				return
			var ops: BattleStateOps = BattleStateOps.for_pawn(pawn, battle_log)
			var fraction: float = ops.intrinsic_service.berry_threshold_fraction(stats) if ops.intrinsic_service != null else 0.25
			if stats.curr_health > int(floor(float(stats.max_health) * fraction)):
				return
			if ops.intrinsic_service != null and ops.intrinsic_service.berries_blocked_for(pawn):
				return
			consume_held_item(pawn, battle_log, "threshold")
			stats.battle_speed_multiplier *= CUSTAP_SPEED_MULTIPLIER
			_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": pawn, "hook": "acts_first"})


static func on_turn_started(pawn: TacticsPawn, battle_log: BattleLog = null) -> void:
	if pawn == null or pawn.stats == null or not pawn.stats.is_active():
		return
	var item: PokemonItemResource = held_item_for(pawn.stats)
	if item == null or items_disabled(pawn.stats):
		return
	var ops: BattleStateOps = BattleStateOps.for_pawn(pawn, battle_log)
	match item.item_id:
		"held_leftovers":
			if pawn.stats.curr_health < pawn.stats.max_health:
				ops.heal(pawn, maxi(1, int(floor(float(pawn.stats.max_health) / 16.0))), {"kind": "held_item", "item_id": item.item_id})
		"held_black_sludge":
			if pawn.stats.types.has("poison"):
				if pawn.stats.curr_health < pawn.stats.max_health:
					ops.heal(pawn, maxi(1, int(floor(float(pawn.stats.max_health) / 16.0))), {"kind": "held_item", "item_id": item.item_id})
			else:
				ops.damage(pawn, maxi(1, int(floor(float(pawn.stats.max_health) / 8.0))), {"kind": "held_item", "attacker": pawn, "item_id": item.item_id, "event": {"source": "held_item"}})
		"held_white_herb":
			var lowered: Array = []
			for stat in pawn.stats.stat_stages.keys():
				if int(pawn.stats.stat_stages[stat]) < 0:
					lowered.append(stat)
			if not lowered.is_empty():
				for stat in lowered:
					pawn.stats.stat_stages.erase(stat)
				consume_held_item(pawn, battle_log, "restore")
				_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": pawn, "hook": "stat_restore", "stats": lowered})
		"held_mental_herb":
			for status_id in ["in_love", "taunted", "encore", "torment", "disable"]:
				if pawn.stats.battle_statuses.has(status_id):
					ops.remove_status(pawn, status_id, {"source": "held_item", "item_id": item.item_id})
					consume_held_item(pawn, battle_log, "cure")
					_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": pawn, "hook": "status_cure", "status_id": status_id})
					break
		"held_sticky_barb":
			ops.damage(pawn, maxi(1, int(floor(float(pawn.stats.max_health) / 8.0))), {"kind": "held_item", "attacker": pawn, "item_id": item.item_id, "event": {"source": "held_item"}})
			_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": pawn, "hook": "turn_damage"})
		"held_flame_orb":
			if not _has_major_status(pawn.stats):
				var burned: Dictionary = ops.apply_status(pawn, "burn", {"source": "held_item"}, {"kind": "held_item", "item_id": item.item_id, "source": "held_item"})
				if bool(burned.get("applied", false)):
					_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": pawn, "hook": "turn_status", "status_id": "burn"})
		"held_toxic_orb":
			if not _has_major_status(pawn.stats):
				var poisoned: Dictionary = ops.apply_status(pawn, "poison_toxic", {"source": "held_item"}, {"kind": "held_item", "item_id": item.item_id, "source": "held_item"})
				if bool(poisoned.get("applied", false)):
					_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": pawn, "hook": "turn_status", "status_id": "poison_toxic"})
		"berry_leppa":
			for i in range(pawn.stats.current_pp.size()):
				if int(pawn.stats.current_pp[i]) <= 0 and pawn.stats.move_slots[i] != null:
					pawn.stats.current_pp[i] = mini(pawn.stats.move_slots[i].pp, 10)
					consume_held_item(pawn, battle_log, "pp_restore")
					_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": pawn, "hook": "pp_restore", "slot_index": i})
					break


static func blocks_move(stats: Stats, move: PokemonMoveResource) -> String:
	if stats == null or move == null or items_disabled(stats):
		return ""
	var item: PokemonItemResource = held_item_for(stats)
	if item == null:
		return ""
	if CHOICE_ITEMS.has(item.item_id) and not stats.last_used_move_id.is_empty() and stats.last_used_move_id != move.move_id and stats.choice_locked_item == item.item_id:
		return "choice_locked"
	if item.item_id == "held_assault_vest" and move.category == PokemonMoveResource.CATEGORY_STATUS:
		return "assault_vest"
	return ""


static func note_move_used(stats: Stats) -> void:
	if stats == null:
		return
	var item: PokemonItemResource = held_item_for(stats)
	stats.choice_locked_item = item.item_id if item != null and CHOICE_ITEMS.has(item.item_id) else ""


static func survive_hit(unit: TacticsPawn, amount: int, battle_log: BattleLog = null) -> int:
	if unit == null or unit.stats == null or amount < unit.stats.curr_health or items_disabled(unit.stats):
		return amount
	var item: PokemonItemResource = held_item_for(unit.stats)
	if item == null:
		return amount
	if item.item_id == "held_focus_sash" and unit.stats.curr_health >= unit.stats.max_health:
		consume_held_item(unit, battle_log, "endure")
		_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": unit, "hook": "endure"})
		return unit.stats.curr_health - 1
	if item.item_id == "held_focus_band":
		var ops: BattleStateOps = BattleStateOps.for_pawn(unit, battle_log)
		var rng: RandomNumberGenerator = ops.battle_level.battle_rng if ops.battle_level != null else RandomNumberGenerator.new()
		if rng.randi_range(1, 100) <= 10:
			_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": unit, "hook": "endure"})
			return unit.stats.curr_health - 1
	return amount


static func target_accuracy_multiplier(defender: Stats) -> float:
	var item: PokemonItemResource = held_item_for(defender)
	if item == null or items_disabled(defender):
		return 1.0
	return 0.9 if item.item_id == "held_bright_powder" else 1.0


static func flinch_chance(attacker: Stats, move: PokemonMoveResource) -> int:
	var item: PokemonItemResource = held_item_for(attacker)
	if item == null or move == null or not move.is_damaging() or items_disabled(attacker):
		return 0
	return 10 if FLINCH_ITEMS.has(item.item_id) else 0


static func weather_rounds_for(setter: Stats, weather_id: String) -> int:
	var item: PokemonItemResource = held_item_for(setter)
	if item == null or items_disabled(setter):
		return 0
	return 8 if WEATHER_ROCKS.has(item.item_id) and String(WEATHER_ROCKS[item.item_id]) == weather_id else 0


static func screen_rounds_for(setter: Stats) -> int:
	var item: PokemonItemResource = held_item_for(setter)
	if item == null or items_disabled(setter):
		return 0
	return 8 if item.item_id == "held_light_clay" else 0


static func ignores_hazards(stats: Stats) -> bool:
	var item: PokemonItemResource = held_item_for(stats)
	return item != null and not items_disabled(stats) and (item.item_id == "held_heavy_duty_boots" or item.item_id == "held_air_balloon")


static func floats(stats: Stats) -> bool:
	var item: PokemonItemResource = held_item_for(stats)
	return item != null and not items_disabled(stats) and item.item_id == "held_air_balloon"


static func blocks_powder(stats: Stats) -> bool:
	var item: PokemonItemResource = held_item_for(stats)
	return item != null and not items_disabled(stats) and item.item_id == "held_safety_goggles"


static func ignores_weather(stats: Stats) -> bool:
	var item: PokemonItemResource = held_item_for(stats)
	return item != null and not items_disabled(stats) and (item.item_id == "held_safety_goggles" or item.item_id == "held_utility_umbrella")


static func blocks_additional_effects(stats: Stats) -> bool:
	var item: PokemonItemResource = held_item_for(stats)
	return item != null and not items_disabled(stats) and item.item_id == "held_covert_cloak"


static func blocks_foe_stat_drops(stats: Stats) -> bool:
	var item: PokemonItemResource = held_item_for(stats)
	return item != null and not items_disabled(stats) and item.item_id == "held_clear_amulet"


static func _contact_shielded(attacker: Stats, move: PokemonMoveResource) -> bool:
	var item: PokemonItemResource = held_item_for(attacker)
	if item == null or items_disabled(attacker):
		return false
	return item.item_id == "held_protective_pads" or (item.item_id == "held_punching_glove" and move != null and move.has_flag("fist"))


static func contact_shielded(attacker: Stats, move: PokemonMoveResource) -> bool:
	return _contact_shielded(attacker, move)


static func zoom_lens_multiplier(attacker: Stats, defender: Stats) -> float:
	var item: PokemonItemResource = held_item_for(attacker)
	if item == null or items_disabled(attacker) or defender == null:
		return 1.0
	return 1.2 if item.item_id == "held_zoom_lens" and attacker.battle_stat("speed") < defender.battle_stat("speed") else 1.0


static func after_move_used(attacker: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog = null) -> void:
	if attacker == null or attacker.stats == null or move == null or items_disabled(attacker.stats):
		return
	var item: PokemonItemResource = held_item_for(attacker.stats)
	if item != null and item.item_id == "held_throat_spray" and move.has_flag("sound"):
		consume_held_item(attacker, battle_log, "sound")
		BattleStateOps.for_pawn(attacker, battle_log).change_stat_stage(attacker, "special_attack", 1, {"kind": "held_item", "item_id": item.item_id})
		_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": attacker, "hook": "sound_boost"})


static func on_miss(attacker: TacticsPawn, battle_log: BattleLog = null) -> void:
	if attacker == null or attacker.stats == null or items_disabled(attacker.stats):
		return
	var item: PokemonItemResource = held_item_for(attacker.stats)
	if item != null and item.item_id == "held_blunder_policy":
		consume_held_item(attacker, battle_log, "miss")
		BattleStateOps.for_pawn(attacker, battle_log).change_stat_stage(attacker, "speed", 2, {"kind": "held_item", "item_id": item.item_id})
		_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": attacker, "hook": "miss_boost"})


static func on_intimidated(unit: TacticsPawn, battle_log: BattleLog = null) -> void:
	if unit == null or unit.stats == null or items_disabled(unit.stats):
		return
	var item: PokemonItemResource = held_item_for(unit.stats)
	if item != null and item.item_id == "held_adrenaline_orb":
		consume_held_item(unit, battle_log, "intimidated")
		BattleStateOps.for_pawn(unit, battle_log).change_stat_stage(unit, "speed", 1, {"kind": "held_item", "item_id": item.item_id})
		_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": unit, "hook": "adrenaline"})


static func on_infatuated(unit: TacticsPawn, attacker: TacticsPawn, battle_log: BattleLog = null) -> void:
	if unit == null or unit.stats == null or attacker == null or attacker.stats == null or items_disabled(unit.stats):
		return
	var item: PokemonItemResource = held_item_for(unit.stats)
	if item != null and item.item_id == "held_destiny_knot" and not attacker.stats.battle_statuses.has("in_love"):
		BattleStateOps.for_pawn(unit, battle_log).apply_status(attacker, "in_love", {"source": "destiny_knot"}, {"kind": "held_item", "item_id": item.item_id, "attacker": unit})
		_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": unit, "hook": "destiny_knot"})


static func mirror_herb(unit: TacticsPawn, stat_id: String, delta: int, battle_log: BattleLog = null) -> void:
	if unit == null or unit.stats == null or delta <= 0 or items_disabled(unit.stats):
		return
	var item: PokemonItemResource = held_item_for(unit.stats)
	if item != null and item.item_id == "held_mirror_herb":
		consume_held_item(unit, battle_log, "mirror")
		BattleStateOps.for_pawn(unit, battle_log).change_stat_stage(unit, stat_id, delta, {"kind": "held_item", "item_id": item.item_id})
		_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": unit, "hook": "mirror"})


static func _species_matches(stats: Stats, names: Array) -> bool:
	if stats == null or stats.pokemon_instance == null or stats.pokemon_instance.species == null:
		return false
	for name in names:
		if stats.pokemon_instance.species.species_id.ends_with(String(name)):
			return true
	return false


static func _knock_back(defender: TacticsPawn, attacker: TacticsPawn, tiles: int, level: TacticsLevel, battle_log: BattleLog, item_id: String) -> void:
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var from: Vector3i = Targeting._tile_key(defender.get_tile())
	var current: Vector3i = Targeting._tile_key(attacker.get_tile())
	var direction: Vector3i = Targeting.direction_between_keys(from, current)
	if direction == Vector3i.ZERO:
		return
	var occupied: Dictionary = {}
	for unit in level.units_on_map():
		if unit.stats != null and unit.stats.is_active() and unit != attacker:
			occupied[Targeting._tile_key(unit.get_tile())] = true
	var moved: int = 0
	for step in range(tiles):
		var next: Vector3i = current + direction
		if not keys.has(next) or occupied.has(next):
			break
		current = next
		moved += 1
	if moved <= 0:
		return
	var tile: TacticsTile = keys[current]
	var ray: RayCast3D = attacker.get_node_or_null("Tile") as RayCast3D
	attacker.global_position = tile.global_position + Vector3.UP * 0.05
	if ray != null:
		ray.force_raycast_update()
	if attacker.has_method("center"):
		attacker.center()
	if ray != null:
		ray.force_raycast_update()
	if attacker.res != null:
		attacker.res.pathfinding_tilestack.clear()
	_append(battle_log, {"kind": "forced_movement", "unit": attacker, "mode": "knockback", "to": current, "item_id": item_id, "move_id": ""})
	level.on_pawn_reached_tile(attacker, attacker.global_position)


static func crit_stage_bonus(stats: Stats) -> int:
	var item: PokemonItemResource = held_item_for(stats)
	return 1 if item != null and item.item_id == "held_scope_lens" else 0


static func accuracy_multiplier(stats: Stats) -> float:
	var item: PokemonItemResource = held_item_for(stats)
	return 1.1 if item != null and item.item_id == "held_wide_lens" else 1.0


static func drain_multiplier(stats: Stats) -> float:
	var item: PokemonItemResource = held_item_for(stats)
	return 1.3 if item != null and item.item_id == "held_big_root" else 1.0


static func ignores_type_immunity(stats: Stats) -> bool:
	var item: PokemonItemResource = held_item_for(stats)
	return item != null and item.item_id == "held_ring_target"


static func grounds_holder(stats: Stats) -> bool:
	var item: PokemonItemResource = held_item_for(stats)
	return item != null and item.item_id == "held_iron_ball"


static func _has_major_status(stats: Stats) -> bool:
	for status_id in ["burn", "poison", "poison_toxic", "paralyze", "sleep", "freeze"]:
		if stats.battle_statuses.has(status_id):
			return true
	return false


static func try_cure_on_status(target: TacticsPawn, status_id: String, battle_log: BattleLog = null) -> bool:
	if target == null or target.stats == null or target.stats.pokemon_instance == null or target.stats.pokemon_instance.held_item == null:
		return false
	var item: PokemonItemResource = target.stats.pokemon_instance.held_item
	if not CURE_BERRIES.has(item.item_id) or not (CURE_BERRIES[item.item_id] as Array).has(status_id) or items_disabled(target.stats):
		return false
	var ops: BattleStateOps = BattleStateOps.for_pawn(target, battle_log)
	if ops.intrinsic_service != null and ops.intrinsic_service.berries_blocked_for(target):
		return false
	if not target.stats.battle_statuses.has(status_id):
		return false
	ops.remove_status(target, status_id, {"source": "held_item", "item_id": item.item_id})
	consume_held_item(target, battle_log, "status_cure")
	_append(battle_log, {"kind": "held_item_triggered", "item_id": item.item_id, "unit": target, "hook": "status_cure", "status_id": status_id})
	return true


static func try_trigger_held_threshold(target: TacticsPawn, battle_log: BattleLog = null) -> bool:
	if target == null or target.stats == null or target.stats.pokemon_instance == null or target.stats.pokemon_instance.held_item == null:
		return false
	var item: PokemonItemResource = target.stats.pokemon_instance.held_item
	if items_disabled(target.stats):
		return false
	var ops: BattleStateOps = BattleStateOps.for_pawn(target, battle_log)
	var fraction: float = ops.intrinsic_service.berry_threshold_fraction(target.stats) if ops.intrinsic_service != null else 0.25
	if item.item_id == "berry_oran" or item.item_id == "berry_sitrus":
		fraction = 0.5
	if target.stats.curr_health <= 0 or target.stats.curr_health > int(floor(float(target.stats.max_health) * fraction)):
		return false
	if item.item_id.begins_with("berry_") and ops.intrinsic_service != null and ops.intrinsic_service.berries_blocked_for(target):
		return false
	if PINCH_BERRY_STAGES.has(item.item_id):
		var pair: Array = PINCH_BERRY_STAGES[item.item_id]
		var change: Dictionary = target.stats.change_stat_stage(String(pair[0]), int(pair[1]))
		consume_held_item(target, battle_log, "threshold")
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
		var heal_amount: int = 10 if item.item_id == "berry_oran" else maxi(1, int(floor(float(target.stats.max_health) / 4.0)))
		BattleStateOps.for_pawn(target, battle_log).heal(target, heal_amount, {"kind": "held_item", "item_id": item.item_id, "threshold": false})
		consume_held_item(target, battle_log, "threshold")
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
