class_name BattleMoveSpecials
extends RefCounted

const CHARGING: Dictionary = {
	"solar_beam": {"sun_skips": true},
	"solar_blade": {"sun_skips": true},
	"fly": {"invulnerable": "airborne"},
	"bounce": {"invulnerable": "airborne"},
	"dig": {"invulnerable": "underground"},
	"dive": {"invulnerable": "underwater"},
	"phantom_force": {"invulnerable": "vanished"},
	"shadow_force": {"invulnerable": "vanished"},
	"skull_bash": {"charge_stat": ["defense", 1]},
	"meteor_beam": {"charge_stat": ["special_attack", 1]},
	"sky_attack": {},
	"razor_wind": {},
	"freeze_shock": {},
	"ice_burst": {},
	"geomancy": {"release_stats": [["special_attack", 2], ["special_defense", 2], ["speed", 2]]},
}
const INVULNERABLE_STATUSES: Array[String] = ["airborne", "underground", "underwater", "vanished"]
const INVULNERABLE_EXCEPTIONS: Dictionary = {
	"airborne": ["gust", "twister", "thunder", "hurricane", "sky_uppercut", "smack_down", "thousand_arrows"],
	"underground": ["earthquake", "magnitude", "fissure"],
	"underwater": ["surf", "whirlpool"],
	"vanished": [],
}
const SELF_FAINT_MOVES: Array[String] = ["explosion", "self_destruct", "memento", "final_gambit"]
const RECHARGE_MOVES: Array[String] = ["hyper_beam", "giga_impact", "roar_of_time", "blast_burn", "hydro_cannon", "frenzy_plant", "rock_wrecker", "prismatic_laser", "eternabeam"]
const CRASH_MOVES: Array[String] = ["high_jump_kick", "jump_kick"]
const TIP_POWER_DASH_MOVES: Dictionary = {"rollout": 4, "ice_ball": 4}
const FLING_POWER: Dictionary = {"held_iron_ball": 130, "held_hard_stone": 100, "held_sticky_barb": 80, "held_assault_vest": 80, "held_flame_orb": 30, "held_toxic_orb": 30, "held_life_orb": 30, "held_metronome": 30, "held_shell_bell": 30, "held_expert_belt": 10, "held_choice_band": 10, "held_choice_specs": 10, "held_choice_scarf": 10, "held_big_root": 10, "held_ring_target": 10, "held_wide_lens": 10, "held_scope_lens": 30, "held_black_belt": 30, "held_black_glasses": 30, "held_charcoal": 30, "held_dragon_scale": 30, "held_magnet": 30, "held_metal_coat": 30, "held_miracle_seed": 30, "held_mystic_water": 30, "held_never_melt_ice": 30, "held_poison_barb": 70, "held_sharp_beak": 50, "held_silk_scarf": 10, "held_silver_powder": 10, "held_soft_sand": 10, "held_spell_tag": 30, "held_twisted_spoon": 30, "held_binding_band": 30, "held_grip_claw": 90}
const FLING_STATUS: Dictionary = {"held_flame_orb": "burn", "held_toxic_orb": "poison_toxic", "held_light_ball": "paralyze", "held_kings_rock": "flinch", "held_razor_fang": "flinch"}
const PASSABLE_STATUSES: Array[String] = ["focus_energy", "aqua_ring", "ingrain", "leech_seed", "magnet_rise", "telekinesis", "perish_song", "confuse", "curse", "embargo", "heal_block", "lock_on", "sure_shot", "substitute"]
const WEIGHT_TARGET_MOVES: Array[String] = ["low_kick", "grass_knot"]
const WEIGHT_RATIO_MOVES: Array[String] = ["heavy_slam", "heat_crash"]
const TYPE_CHANGE_MOVES: Dictionary = {
	"soak": {"target": "set", "types": ["water"]},
	"magic_powder": {"target": "set", "types": ["psychic"]},
	"trick_or_treat": {"target": "add", "types": ["ghost"]},
	"forests_curse": {"target": "add", "types": ["grass"]},
	"camouflage": {"self": "set", "types": ["normal"]},
	"reflect_type": {"self": "copy"},
}
const SPORT_MOVES: Dictionary = {"mud_sport": "electric", "water_sport": "fire"}
const ALL_STATS: Array[String] = ["attack", "defense", "special_attack", "special_defense", "speed", "accuracy", "evasion"]
const MULTI_HIT_WEIGHTS: Array[int] = [35, 35, 15, 15]


func pre_execute(resolver: BattleActionResolver, attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, targets: Array[TacticsPawn], battle_level: TacticsLevel, battle_log: BattleLog, rng: RandomNumberGenerator) -> bool:
	var ops: BattleStateOps = resolver._ops(battle_level, battle_log)
	var id: String = move.move_id
	if CHARGING.has(id) and _handle_charging(resolver, attacker, target, move, battle_level, battle_log):
		return true
	if TIP_POWER_DASH_MOVES.has(id):
		_resolve_tip_dash(resolver, attacker, target, move, int(TIP_POWER_DASH_MOVES[id]), battle_level, battle_log, rng)
		return true
	if id == "fling":
		var flung: PokemonItemResource = PokemonItemService.held_item_for(attacker.stats)
		if flung == null or PokemonItemService.items_disabled(attacker.stats):
			_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": id, "reason": "no_item"})
			return true
		var power: int = int(FLING_POWER.get(flung.item_id, 10))
		if flung.item_id.ends_with("_plate"):
			power = 90
		PokemonItemService.consume_held_item(attacker, battle_log, "fling")
		_append(battle_log, {"kind": "item_thrown", "attacker": attacker, "item_id": flung.item_id, "move_id": id})
		var flung_move: PokemonMoveResource = move.duplicate()
		flung_move.base_power = power
		flung_move.category = PokemonMoveResource.CATEGORY_PHYSICAL
		flung_move.set_meta("fling_item", flung.item_id)
		var kept_tags: Array[String] = []
		for tag in flung_move.unsupported_effect_tags:
			if not String(tag).contains("MaxHPDamageEvent"):
				kept_tags.append(String(tag))
		flung_move.unsupported_effect_tags = kept_tags
		for hit_target in targets:
			var before: int = hit_target.stats.curr_health
			resolver._resolve_one_target(attacker, hit_target, flung_move, 0, battle_level.get_type_chart() if battle_level != null else null, rng, battle_log, battle_level)
			if hit_target.stats.curr_health < before and FLING_STATUS.has(flung.item_id) and hit_target.stats.is_active():
				ops.apply_status(hit_target, String(FLING_STATUS[flung.item_id]), {"source": "fling"}, {"kind": "status", "attacker": attacker, "move": move})
			elif hit_target.stats.curr_health < before and flung.item_id.begins_with("berry_") and hit_target.stats.is_active():
				PokemonItemService.cud_chew(hit_target, flung.item_id, battle_log)
		return true
	if id == "teleport":
		if battle_level == null:
			return true
		var destination: Vector3i = resolver._random_free_key(attacker, rng, battle_level)
		if destination == Vector3i.ZERO and resolver._unit_key(attacker) != Vector3i.ZERO:
			_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": id, "reason": "no_free_tile"})
			return true
		resolver._move_unit_to_key(attacker, destination, move, "teleport", battle_level, battle_log, "warp")
		return true
	if id == "me_first" and target != null and target.stats != null and target != attacker:
		var strongest: PokemonMoveResource = null
		for slot in target.stats.move_slots:
			if slot != null and slot.is_damaging() and (strongest == null or slot.base_power > strongest.base_power):
				strongest = slot
		if strongest == null:
			_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": id, "reason": "no_move_to_copy"})
			return true
		var boosted: PokemonMoveResource = strongest.duplicate()
		boosted.base_power = int(floor(float(strongest.base_power) * 1.5))
		_append(battle_log, {"kind": "move_copied", "attacker": attacker, "defender": target, "move_id": id, "copied_move_id": strongest.move_id})
		resolver._resolve_one_target(attacker, target, boosted, 0, battle_level.get_type_chart() if battle_level != null else null, rng, battle_log, battle_level)
		return true
	if id == "bide":
		if attacker.stats.battle_statuses.has("bide"):
			if battle_level != null:
				battle_level.release_bide(attacker)
			return true
		ops.apply_status(attacker, "bide", {}, {"kind": "move", "move": move, "skip_rules": true})
		_append(battle_log, {"kind": "status_triggered", "unit": attacker, "status_id": "bide", "phase": "start"})
		return true
	if id == "transform" and target != null and target.stats != null and target != attacker:
		if attacker.stats.transform_into(target.stats, resolver.intrinsic_service.intrinsic_slugs_for(target.stats)):
			_append(battle_log, {"kind": "transformed", "unit": attacker, "defender": target, "move_id": id})
		else:
			_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": id, "reason": "no_effect"})
		return true
	if id == "baton_pass":
		if target == null or target == attacker or target.stats == null:
			_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": id, "reason": "needs_target"})
			return true
		for stat in attacker.stats.stat_stages.keys():
			var delta: int = int(attacker.stats.stat_stages[stat])
			if delta != 0:
				ops.change_stat_stage(target, String(stat), delta, {"kind": "move", "attacker": attacker, "move": move, "skip_rules": true})
		attacker.stats.stat_stages = {}
		for status_id in PASSABLE_STATUSES:
			if attacker.stats.battle_statuses.has(status_id):
				var payload: Dictionary = (attacker.stats.battle_statuses[status_id] as Dictionary).duplicate(true)
				ops.remove_status(attacker, status_id, {"source": "baton_pass"})
				ops.apply_status(target, status_id, payload, {"kind": "move", "attacker": attacker, "move": move, "skip_rules": true})
		_append(battle_log, {"kind": "baton_passed", "attacker": attacker, "defender": target, "move_id": id})
		return true
	if id == "topsy_turvy" and target != null and target.stats != null:
		var inverted: Dictionary = {}
		for stat in target.stats.stat_stages.keys():
			inverted[stat] = -int(target.stats.stat_stages[stat])
		target.stats.stat_stages = inverted
		_append(battle_log, {"kind": "stats_inverted", "attacker": attacker, "defender": target, "move_id": id})
		return true
	if id == "mat_block":
		for ally in _active_allies(attacker, battle_level):
			ops.apply_status(ally, "mat_block", {}, {"kind": "move", "move": move, "skip_rules": true})
		return true
	if id == "snatch":
		ops.apply_status(attacker, "snatch", {}, {"kind": "move", "move": move, "skip_rules": true})
		return true
	if id == "substitute":
		var cost: int = maxi(1, int(floor(float(attacker.stats.max_health) / 4.0)))
		if attacker.stats.battle_statuses.has("decoy") or attacker.stats.curr_health <= cost:
			_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": id, "reason": "no_effect"})
			return true
		ops.damage(attacker, cost, {"kind": "move_cost", "attacker": attacker, "move": move})
		ops.apply_status(attacker, "decoy", {"hp": cost}, {"kind": "move", "move": move, "skip_rules": true})
		return true
	if id == "fairy_lock" and battle_level != null:
		for unit in battle_level.units_on_map():
			if unit.stats != null and unit.stats.is_active():
				ops.apply_status(unit, "rooted", {"counter": 2}, {"kind": "move", "attacker": attacker, "move": move, "skip_rules": true})
		_append(battle_log, {"kind": "status_applied", "unit": attacker, "status_id": "fairy_lock", "move_id": id})
		return true
	if id == "follow_me" or id == "rage_powder":
		ops.apply_status(attacker, id, {}, {"kind": "move", "move": move, "skip_rules": true})
		return true
	if id == "rototiller" and battle_level != null:
		battle_level.clear_hazards(attacker, false, id)
		for ally in _active_allies(attacker, battle_level):
			if ally.stats.types.has("grass") and battle_level.is_grounded(ally):
				ops.change_stat_stage(ally, "attack", 1, {"kind": "move", "attacker": attacker, "move": move})
				ops.change_stat_stage(ally, "special_attack", 1, {"kind": "move", "attacker": attacker, "move": move})
		return true
	if id == "seismic_toss" or id == "final_gambit":
		for hit_target in targets:
			var amount: int = _special_damage_amount(attacker, hit_target, id, rng)
			if amount <= 0:
				_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": id, "reason": "no_effect"})
				continue
			_resolve_fixed_hit(resolver, attacker, hit_target, move, amount, battle_level, battle_log, rng)
		return true
	if id == "beat_up":
		var allies: Array[TacticsPawn] = _active_allies(attacker, battle_level)
		for ally in allies:
			var copy: PokemonMoveResource = move.duplicate()
			copy.base_power = int(floor(float(ally.stats.raw_battle_stat("attack")) / 10.0)) + 5
			resolver._resolve_one_target(attacker, target, copy, 0, battle_level.get_type_chart() if battle_level != null else null, rng, battle_log, battle_level)
			if not target.stats.is_active():
				break
		return true
	if id == "acupressure" and target != null and target.stats != null:
		var candidates: Array[String] = []
		for stat in ALL_STATS:
			if target.stats.get_stat_stage(stat) < 6:
				candidates.append(stat)
		if candidates.is_empty():
			_append(battle_log, {"kind": "move_rejected", "attacker": attacker, "move_id": id, "reason": "no_effect"})
			return true
		ops.change_stat_stage(target, candidates[rng.randi_range(0, candidates.size() - 1)], 2, {"kind": "move", "attacker": attacker, "move": move})
		return true
	if TYPE_CHANGE_MOVES.has(id):
		var rule: Dictionary = TYPE_CHANGE_MOVES[id]
		if rule.has("self"):
			var new_types: Array[String] = []
			if String(rule["self"]) == "copy" and target != null and target.stats != null:
				new_types = target.stats.types.duplicate()
			else:
				for type_id in rule.get("types", []):
					new_types.append(String(type_id))
			attacker.stats.types = new_types
			_append(battle_log, {"kind": "type_changed", "unit": attacker, "types": new_types, "source": "move", "move_id": id})
		elif target != null and target.stats != null:
			if not _accuracy_roll(resolver, attacker, target, move, rng):
				_append(battle_log, {"kind": "miss", "attacker": attacker, "defender": target, "move_id": id, "hit_index": 0})
				return true
			var next_types: Array[String] = []
			if String(rule["target"]) == "add":
				next_types = target.stats.types.duplicate()
			for type_id in rule.get("types", []):
				if not next_types.has(String(type_id)):
					next_types.append(String(type_id))
			target.stats.types = next_types
			_append(battle_log, {"kind": "type_changed", "unit": target, "types": next_types, "source": "move", "move_id": id})
		return true
	if SPORT_MOVES.has(id) and battle_level != null:
		battle_level.set_battle_condition(id, {"counter": 5, "move_id": id, "attacker": attacker.name})
		_append(battle_log, {"kind": "field_condition_applied", "condition_id": id, "move_id": id, "attacker": attacker, "rounds": 5})
		return true
	return false


func on_miss(resolver: BattleActionResolver, attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if CRASH_MOVES.has(move.move_id) and attacker != null and attacker.stats != null and attacker.stats.is_active():
		var crash: int = maxi(1, int(floor(float(attacker.stats.max_health) / 2.0)))
		_append(battle_log, {"kind": "crash_damage", "attacker": attacker, "move_id": move.move_id, "amount": crash})
		var outcome: Dictionary = resolver._ops(battle_level, battle_log).damage(attacker, crash, {"kind": "crash", "attacker": attacker, "move": move})
		if bool(outcome.get("fainted", false)):
			resolver.animation_resolver.select_reaction(attacker, move, "faint", battle_log)


func after_hit(resolver: BattleActionResolver, attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, damage_done: int, was_active: bool, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if attacker == null or target == null or move == null:
		return
	var id: String = move.move_id
	if id == "fell_stinger" and was_active and not target.stats.is_active():
		resolver._ops(battle_level, battle_log).change_stat_stage(attacker, "attack", 3, {"kind": "move", "attacker": attacker, "move": move})
	if battle_level != null and battle_level.multiverse.enabled and target != attacker and target.stats.is_active() and attacker.stats.is_active():
		var travellers: String = String(battle_level.multiverse.travel_rule(id).get("travellers", ""))
		var declared: TacticsPawn = battle_level.multiverse.declared_target
		if (travellers == "both" or travellers == "target") and (declared == null or not is_instance_valid(declared) or declared == target):
			battle_level.multiverse.request_travel(id, attacker, target)


func after_move(resolver: BattleActionResolver, attacker: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or move == null:
		return
	if SELF_FAINT_MOVES.has(move.move_id) and attacker.stats.is_active():
		var outcome: Dictionary = resolver._ops(battle_level, battle_log).damage(attacker, attacker.stats.curr_health, {"kind": "self_faint", "attacker": attacker, "move": move})
		if bool(outcome.get("fainted", false)):
			resolver.animation_resolver.select_reaction(attacker, move, "faint", battle_log)
	if RECHARGE_MOVES.has(move.move_id) and attacker.stats.is_active():
		resolver._ops(battle_level, battle_log).apply_status(attacker, "recharge", {"counter": 1}, {"kind": "move", "move": move, "skip_rules": true})
	if battle_level != null and battle_level.multiverse.enabled and attacker.stats.is_active() and String(battle_level.multiverse.travel_rule(move.move_id).get("travellers", "")) == "user" and not bool(battle_level.multiverse.travel_rule(move.move_id).get("strike", false)):
		battle_level.multiverse.request_travel(move.move_id, attacker, attacker)


func target_invulnerable(target: TacticsPawn, move: PokemonMoveResource) -> String:
	if target == null or target.stats == null or move == null:
		return ""
	for status_id in INVULNERABLE_STATUSES:
		if target.stats.battle_statuses.has(status_id) and not (INVULNERABLE_EXCEPTIONS[status_id] as Array).has(move.move_id):
			return status_id
	return ""


func charging_lock(attacker: TacticsPawn, move: PokemonMoveResource) -> bool:
	if attacker == null or attacker.stats == null:
		return false
	if not attacker.stats.battle_statuses.has("charging"):
		return false
	var payload: Dictionary = attacker.stats.battle_statuses.get("charging", {})
	return String(payload.get("move_id", "")) != move.move_id


func power_multiplier(attacker: TacticsPawn, move: PokemonMoveResource) -> float:
	if attacker == null or attacker.stats == null or move == null:
		return 1.0
	if TIP_POWER_DASH_MOVES.has(move.move_id) and move.has_meta("tip_power"):
		return float(move.get_meta("tip_power"))
	if WEIGHT_TARGET_MOVES.has(move.move_id) and move.has_meta("weight_power"):
		return float(move.get_meta("weight_power")) / float(maxi(1, move.base_power))
	if WEIGHT_RATIO_MOVES.has(move.move_id) and move.has_meta("weight_power"):
		return float(move.get_meta("weight_power")) / float(maxi(1, move.base_power))
	return 1.0


func weight_of(stats: Stats, intrinsic_service: BattleIntrinsicService) -> float:
	if stats == null:
		return 0.0
	var weight: float = stats.weight_kg
	var slugs: Array[String] = intrinsic_service.intrinsic_slugs_for(stats) if intrinsic_service != null else []
	if slugs.has("heavy_metal"):
		weight *= 2.0
	elif slugs.has("light_metal"):
		weight *= 0.5
	var item: PokemonItemResource = PokemonItemService.held_item_for(stats)
	if item != null and item.item_id == "held_float_stone":
		weight *= 0.5
	return weight


static func weight_power(kg: float) -> int:
	if kg < 10.0:
		return 20
	if kg < 25.0:
		return 40
	if kg < 50.0:
		return 60
	if kg < 100.0:
		return 80
	if kg < 200.0:
		return 100
	return 120


static func weight_ratio_power(user_kg: float, target_kg: float) -> int:
	var ratio: float = user_kg / maxf(0.1, target_kg)
	if ratio >= 5.0:
		return 120
	if ratio >= 4.0:
		return 100
	if ratio >= 3.0:
		return 80
	if ratio >= 2.0:
		return 60
	return 40


func prepare_weight_move(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, intrinsic_service: BattleIntrinsicService) -> PokemonMoveResource:
	if move == null or target == null or target.stats == null or attacker == null or attacker.stats == null:
		return move
	if WEIGHT_TARGET_MOVES.has(move.move_id):
		var copy: PokemonMoveResource = move.duplicate()
		copy.set_meta("weight_power", weight_power(weight_of(target.stats, intrinsic_service)))
		return copy
	if WEIGHT_RATIO_MOVES.has(move.move_id):
		var copy: PokemonMoveResource = move.duplicate()
		copy.set_meta("weight_power", weight_ratio_power(weight_of(attacker.stats, intrinsic_service), weight_of(target.stats, intrinsic_service)))
		return copy
	return move


func hit_count(intrinsic_service: BattleIntrinsicService, attacker: TacticsPawn, move: PokemonMoveResource, rng: RandomNumberGenerator) -> int:
	var base: int = maxi(1, move.strike_count)
	if base == 1 and move.is_damaging() and intrinsic_service != null and attacker != null and intrinsic_service.intrinsic_slugs_for(attacker.stats).has("parental_bond"):
		return 2
	if base != 5:
		return base
	var random_multi: bool = false
	for record in move.effect_records:
		if String(record.get("family", "")) == "multi_hit" and int((record.get("params", {}) as Dictionary).get("hit_count", 0)) == 5:
			random_multi = true
	if not random_multi:
		return base
	if intrinsic_service != null and attacker != null and intrinsic_service.intrinsic_slugs_for(attacker.stats).has("skill_link"):
		return 5
	var item: PokemonItemResource = PokemonItemService.held_item_for(attacker)
	if item != null and item.item_id == "held_loaded_dice":
		return 4 + (1 if rng.randf() < 0.5 else 0)
	var roll: int = rng.randi_range(1, 100)
	var total: int = 0
	for i in range(MULTI_HIT_WEIGHTS.size()):
		total += MULTI_HIT_WEIGHTS[i]
		if roll <= total:
			return 2 + i
	return 5


func sport_multiplier(move: PokemonMoveResource, battle_level: TacticsLevel) -> float:
	if move == null or battle_level == null:
		return 1.0
	for sport_id in SPORT_MOVES.keys():
		if move.type == String(SPORT_MOVES[sport_id]) and battle_level.has_battle_condition(String(sport_id)):
			return 1.0 / 3.0
	return 1.0


func _handle_charging(resolver: BattleActionResolver, attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel, battle_log: BattleLog) -> bool:
	var ops: BattleStateOps = resolver._ops(battle_level, battle_log)
	var rule: Dictionary = CHARGING[move.move_id]
	if attacker.stats.battle_statuses.has("charging"):
		ops.remove_status(attacker, "charging", {"source": "released"})
		for status_id in INVULNERABLE_STATUSES:
			if attacker.stats.battle_statuses.has(status_id):
				ops.remove_status(attacker, status_id, {"source": "released"})
		for entry in rule.get("release_stats", []):
			ops.change_stat_stage(attacker, String(entry[0]), int(entry[1]), {"kind": "move", "attacker": attacker, "move": move})
		return false
	if bool(rule.get("sun_skips", false)) and battle_level != null and battle_level.effective_weather() == "sunny":
		return false
	var herb: PokemonItemResource = PokemonItemService.held_item_for(attacker)
	if herb != null and herb.item_id == "held_power_herb":
		PokemonItemService.consume_held_item(attacker, battle_log, "power_herb")
		for entry in rule.get("release_stats", []):
			ops.change_stat_stage(attacker, String(entry[0]), int(entry[1]), {"kind": "move", "attacker": attacker, "move": move})
		return false
	ops.apply_status(attacker, "charging", {"move_id": move.move_id, "target_unit": target}, {"kind": "move", "move": move, "skip_rules": true})
	var invulnerable: String = String(rule.get("invulnerable", ""))
	if not invulnerable.is_empty():
		ops.apply_status(attacker, invulnerable, {"move_id": move.move_id}, {"kind": "move", "move": move, "skip_rules": true})
	if rule.has("charge_stat"):
		ops.change_stat_stage(attacker, String(rule["charge_stat"][0]), int(rule["charge_stat"][1]), {"kind": "move", "attacker": attacker, "move": move})
	_append(battle_log, {"kind": "move_charging", "attacker": attacker, "move_id": move.move_id, "status_id": invulnerable})
	return true


func _resolve_fixed_hit(resolver: BattleActionResolver, attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, amount: int, battle_level: TacticsLevel, battle_log: BattleLog, rng: RandomNumberGenerator, sure: bool = false) -> void:
	if target == null or target.stats == null or not target.stats.is_active():
		return
	if not sure and not _accuracy_roll(resolver, attacker, target, move, rng):
		_append(battle_log, {"kind": "miss", "attacker": attacker, "defender": target, "move_id": move.move_id, "hit_index": 0})
		resolver.animation_resolver.select_reaction(target, move, "miss", battle_log)
		on_miss(resolver, attacker, target, move, battle_level, battle_log)
		return
	if resolver._handle_protection(attacker, target, move, battle_log):
		return
	var chart: TypeChartResource = battle_level.get_type_chart() if battle_level != null else resolver._load_type_chart()
	if move.move_id != "final_gambit" and resolver.damage_resolver._effectiveness(move, target.stats, chart) <= 0.0:
		_append(battle_log, {"kind": "damage_prevented", "unit": target, "defender": target, "attacker": attacker, "move_id": move.move_id, "source": "type"})
		resolver.animation_resolver.select_reaction(target, move, "miss", battle_log)
		return
	var was_active: bool = target.stats.is_active()
	var done: int = resolver._apply_damage(attacker, target, move, amount, battle_log, {"kind": "damage_dealt", "source": "special_damage", "hit_index": 0, "multiplier": 1.0})
	if was_active and not target.stats.is_active():
		resolver.animation_resolver.select_reaction(target, move, "faint", battle_log)
		resolver.intrinsic_service.on_knockout(attacker, target, move, battle_log)
	elif done > 0:
		resolver.animation_resolver.select_reaction(target, move, "hurt", battle_log)


func _special_damage_amount(attacker: TacticsPawn, target: TacticsPawn, id: String, rng: RandomNumberGenerator) -> int:
	if target == null or target.stats == null:
		return 0
	if id == "seismic_toss":
		return maxi(1, attacker.stats.level)
	if id == "final_gambit":
		return maxi(1, attacker.stats.curr_health)
	return 0


func _accuracy_roll(resolver: BattleActionResolver, attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, rng: RandomNumberGenerator) -> bool:
	if move.is_sure_hit() or move.accuracy <= 0 or resolver.intrinsic_service.sure_hit(attacker.stats, target.stats):
		return true
	var multiplier: float = resolver.intrinsic_service.accuracy_multiplier(attacker, target, move, null) * resolver._stage_accuracy_multiplier(attacker, target, move)
	return rng.randf() * 100.0 < float(move.accuracy) * multiplier


func _active_allies(attacker: TacticsPawn, battle_level: TacticsLevel) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	if battle_level == null:
		out.append(attacker)
		return out
	for unit in battle_level.units_on_map():
		if unit.stats != null and unit.stats.is_active() and not battle_level.are_foes(attacker, unit):
			out.append(unit)
	if out.is_empty():
		out.append(attacker)
	return out


func _append(battle_log: BattleLog, event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)


func _resolve_tip_dash(resolver: BattleActionResolver, attacker: TacticsPawn, declared: TacticsPawn, move: PokemonMoveResource, range_tiles: int, battle_level: TacticsLevel, battle_log: BattleLog, rng: RandomNumberGenerator) -> void:
	if battle_level == null:
		return
	var direction: Vector3i = Vector3i.ZERO
	if declared != null and declared != attacker:
		direction = Targeting.direction_between_keys(resolver._unit_key(attacker), resolver._unit_key(declared))
	if direction == Vector3i.ZERO:
		direction = TacticsPawnMovementService.snap_direction_8(Vector3.FORWARD.rotated(Vector3.UP, attacker.rotation.y - PI))
	if direction == Vector3i.ZERO:
		return
	var current: Vector3i = resolver._unit_key(attacker)
	var steps: int = 0
	var hit_unit: TacticsPawn = null
	var units: Array[TacticsPawn] = battle_level.units_on_map()
	for step in range(range_tiles):
		var next: Vector3i = current + direction
		var occupant: TacticsPawn = Targeting.unit_at_key(next, units)
		if occupant != null and occupant != attacker and occupant.stats != null and occupant.stats.is_active():
			hit_unit = occupant
			steps += 1
			break
		if not resolver._is_free_key(next, attacker, battle_level):
			break
		current = next
		steps += 1
	var origin: Vector3i = resolver._unit_key(attacker)
	if current != origin:
		var from_world: Vector3 = attacker.global_position
		attacker.serv.movement.look_at_direction_8(attacker, Vector3(float(direction.x), 0.0, float(direction.z)))
		resolver._set_unit_key(attacker, current, battle_level)
		if resolver.animation_resolver.runner != null:
			var pose: Dictionary = attacker.character.resolve_source_state("Attack") if attacker.character != null else {}
			resolver.animation_resolver.runner.run_dash(attacker, from_world, attacker.global_position, String(pose.get("state", "attack")), 0.12 * float(maxi(1, steps)))
		_append(battle_log, {"kind": "forced_movement", "move_id": move.move_id, "mode": "dash", "unit": attacker, "from": origin, "to": current, "steps": current.distance_to(origin) if false else steps - (1 if hit_unit != null else 0)})
		battle_level.on_pawn_reached_tile(attacker, attacker.global_position)
	if hit_unit == null:
		_append(battle_log, {"kind": "miss", "attacker": attacker, "defender": declared if declared != null else attacker, "move_id": move.move_id, "hit_index": 0, "reason": "dash_no_target"})
		return
	var powered: PokemonMoveResource = move.duplicate()
	powered.set_meta("tip_power", float(1 << maxi(0, steps - 1)))
	resolver._resolve_one_target(attacker, hit_unit, powered, 0, battle_level.get_type_chart(), rng, battle_log, battle_level)
