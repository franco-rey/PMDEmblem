class_name BattleActionResolver
extends RefCounted
## M6 move action orchestrator: PP, accuracy, target expansion, effects, logs.

const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"
const STATUS_COUNTER: String = "counter"
const STATUS_PROTECT: String = "protect"
const MOVE_FEINT: String = "feint"
const MOVE_FALSE_SWIPE: String = "false_swipe"

var damage_resolver := DamageResolver.new()
var animation_resolver := BattleAnimationResolver.new()
var intrinsic_service := BattleIntrinsicService.new()
var _fallback_rng := RandomNumberGenerator.new()


func _init() -> void:
	_fallback_rng.seed = 0


func execute(attacker: TacticsPawn, declared_target: TacticsPawn, move_index: int, battle_level: TacticsLevel = null) -> bool:
	if attacker == null or attacker.stats == null or not attacker.is_alive():
		return false
	var move: PokemonMoveResource = _move_for(attacker, move_index)
	var battle_log: BattleLog = battle_level.battle_log if battle_level != null else null
	if move == null:
		_append(battle_log, {
			"kind": "no_usable_move",
			"attacker": attacker,
			"slot_index": move_index,
		})
		return false
	if declared_target == null or not declared_target.is_alive():
		_append(battle_log, {
			"kind": "move_rejected",
			"attacker": attacker,
			"move_id": move.move_id,
			"slot_index": move_index,
			"reason": "no_target",
		})
		return false

	var targets: Array[TacticsPawn] = _expanded_targets(attacker, declared_target, move, battle_level)
	if targets.is_empty():
		_append(battle_log, {
			"kind": "move_rejected",
			"attacker": attacker,
			"move_id": move.move_id,
			"slot_index": move_index,
			"reason": "illegal_target",
		})
		return false

	var rng: RandomNumberGenerator = battle_level.battle_rng if battle_level != null else _fallback_rng
	var type_chart: TypeChartResource = battle_level.get_type_chart() if battle_level != null else _load_type_chart()
	_append(battle_log, {
		"kind": "move_used",
		"attacker": attacker,
		"move_id": move.move_id,
		"slot_index": move_index,
		"target_count": targets.size(),
	})
	animation_resolver.select_for_move(attacker, move, battle_log)

	attacker.stats.consume_pp(move_index)
	_append(battle_log, {
		"kind": "pp_decremented",
		"attacker": attacker,
		"move_id": move.move_id,
		"slot_index": move_index,
		"remaining": attacker.stats.current_pp[move_index] if move_index < attacker.stats.current_pp.size() else 0,
	})

	var hit_count: int = maxi(1, move.strike_count)
	if hit_count > 1:
		_append(battle_log, {
			"kind": "multi_hit_started",
			"attacker": attacker,
			"move_id": move.move_id,
			"hit_count": hit_count,
		})

	for hit_index in range(hit_count):
		for target in targets:
			if target == null or not target.is_alive():
				continue
			_resolve_one_target(attacker, target, move, hit_index, type_chart, rng, battle_log)
	if move.effect_records.is_empty() and not move.unsupported_effect_tags.is_empty():
		for unsupported_tag in move.unsupported_effect_tags:
			_append(battle_log, {
				"kind": "effect_unsupported",
				"attacker": attacker,
				"move_id": move.move_id,
				"source_event": unsupported_tag,
			})
	return true


func _resolve_one_target(
		attacker: TacticsPawn,
		target: TacticsPawn,
		move: PokemonMoveResource,
		hit_index: int,
		type_chart: TypeChartResource,
		rng: RandomNumberGenerator,
		battle_log: BattleLog
) -> void:
	var was_active: bool = target.stats.is_active()
	var hit: bool = AccuracyResolver.roll(move, rng)
	if not hit:
		_append(battle_log, {
			"kind": "miss",
			"attacker": attacker,
			"defender": target,
			"move_id": move.move_id,
			"hit_index": hit_index,
		})
		animation_resolver.select_reaction(target, move, "miss", battle_log)
		return

	if _handle_protection(attacker, target, move, battle_log):
		return

	var effectiveness: float = damage_resolver._effectiveness(move, target.stats, type_chart)
	var stab: bool = type_chart.is_stab(move.type, attacker.stats.types) if type_chart != null else false
	var damage: int = 0
	if _should_apply_formula_damage(move):
		var extra_multiplier: float = intrinsic_service.before_damage_multiplier(attacker.stats, move, battle_log, attacker)
		damage = damage_resolver.calculate_damage(attacker.stats, target.stats, move, effectiveness, stab, extra_multiplier)

	var damage_done: int = 0
	if damage > 0:
		damage_done = _apply_damage(attacker, target, move, damage, battle_log, {
			"kind": "damage_dealt",
			"hit_index": hit_index,
			"multiplier": effectiveness,
			"stab": stab,
		})

	for record in _records_for_runtime(move):
		_apply_effect_record(record, attacker, target, move, damage_done, rng, battle_log)

	_apply_counter(attacker, target, move, damage_done, battle_log)

	if was_active and not target.stats.is_active():
		target.res.hurt_remaining = 0.0
		_append(battle_log, {
			"kind": "unit_fainted",
			"unit": target,
			"move_id": move.move_id,
		})
		animation_resolver.select_reaction(target, move, "faint", battle_log)


func _apply_effect_record(
		record: Dictionary,
		attacker: TacticsPawn,
		target: TacticsPawn,
		move: PokemonMoveResource,
		damage_done: int,
		rng: RandomNumberGenerator,
		battle_log: BattleLog
) -> void:
	var family: String = String(record.get("family", ""))
	if family == "damage" or family == "multi_hit":
		return
	var chance: int = int(record.get("chance", 100))
	if chance < 100:
		var roll: float = rng.randf() * 100.0
		if roll >= float(chance):
			_append(battle_log, {
				"kind": "effect_missed",
				"attacker": attacker,
				"defender": target,
				"move_id": move.move_id,
				"effect_family": family,
				"chance": chance,
				"roll": roll,
			})
			return
	var recipient: TacticsPawn = _recipient_for(record, attacker, target)
	if recipient == null or recipient.stats == null:
		return
	match family:
		"status":
			var status_id: String = String(record.get("status_id", ""))
			if status_id.is_empty():
				return
			var payload: Dictionary = {"move_id": move.move_id, "source_event": record.get("source_event", "")}
			recipient.stats.apply_battle_status(status_id, payload)
			_append(battle_log, {
				"kind": "status_applied",
				"unit": recipient,
				"move_id": move.move_id,
				"status_id": status_id,
			})
		"status_remove":
			var remove_id: String = String(record.get("status_id", ""))
			if remove_id.is_empty():
				return
			var removed: Dictionary = recipient.stats.remove_battle_status(remove_id)
			if not removed.is_empty():
				_append(battle_log, {
					"kind": "status_removed",
					"unit": recipient,
					"move_id": move.move_id,
					"status_id": remove_id,
				})
		"stat_stage":
			var change: Dictionary = recipient.stats.change_stat_stage(String(record.get("stat", "")), int(record.get("delta", 0)))
			if not change.is_empty():
				_append(battle_log, {
					"kind": "stat_stage_changed",
					"unit": recipient,
					"move_id": move.move_id,
					"stat": change["stat"],
					"before": change["before"],
					"after": change["after"],
					"delta": change["delta"],
				})
		"heal":
			var amount: int = _heal_amount(record, recipient)
			if amount <= 0:
				return
			var before: int = recipient.stats.curr_health
			recipient.stats.apply_to_curr_health(amount)
			_append(battle_log, {
				"kind": "healed",
				"unit": recipient,
				"move_id": move.move_id,
				"amount": recipient.stats.curr_health - before,
				"before": before,
				"after": recipient.stats.curr_health,
			})
		"drain":
			var drain_amount: int = int(floor(float(damage_done) * float(record.get("fraction", 0.5))))
			if drain_amount > 0:
				var before_heal: int = attacker.stats.curr_health
				attacker.stats.apply_to_curr_health(drain_amount)
				_append(battle_log, {
					"kind": "healed",
					"unit": attacker,
					"move_id": move.move_id,
					"amount": attacker.stats.curr_health - before_heal,
					"before": before_heal,
					"after": attacker.stats.curr_health,
					"source": "drain",
				})
		"recoil":
			var recoil: int = _recoil_amount(record, attacker)
			if recoil > 0:
				var attacker_was_active: bool = attacker.stats.is_active()
				attacker.stats.apply_to_curr_health(-recoil)
				_append(battle_log, {
					"kind": "damage_dealt",
					"attacker": attacker,
					"defender": attacker,
					"move_id": move.move_id,
					"amount": recoil,
					"source": "recoil",
				})
				if attacker != target and attacker_was_active and not attacker.stats.is_active():
					_append(battle_log, {
						"kind": "unit_fainted",
						"unit": attacker,
						"move_id": move.move_id,
						"source": "recoil",
					})
					animation_resolver.select_reaction(attacker, move, "faint", battle_log)
		"fixed_damage":
			var fixed: int = int(record.get("amount", 0))
			if fixed > 0:
				_apply_damage(attacker, recipient, move, fixed, battle_log, {
					"kind": "damage_dealt",
					"source": "fixed_damage",
				})
		"percent_damage":
			var pct_damage: int = int(floor(float(recipient.stats.max_health) * float(record.get("percent", 0.0))))
			if pct_damage > 0:
				_apply_damage(attacker, recipient, move, pct_damage, battle_log, {
					"kind": "damage_dealt",
					"source": "percent_damage",
				})
		_:
			_append(battle_log, {
				"kind": "effect_unsupported",
				"attacker": attacker,
				"defender": target,
				"move_id": move.move_id,
				"effect_family": family,
				"source_event": record.get("source_event", ""),
			})


func _records_for_runtime(move: PokemonMoveResource) -> Array[Dictionary]:
	if move.effect_records.is_empty() and move.is_damaging():
		return [{
			"family": "damage",
			"target": "hit_target",
			"source_event": "PMDC.Dungeon.DamageFormulaEvent, PMDC",
		}]
	return move.effect_records


func _handle_protection(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog) -> bool:
	if attacker == null or target == null or attacker == target or target.stats == null:
		return false
	if not target.stats.battle_statuses.has(STATUS_PROTECT):
		return false
	if move.move_id == MOVE_FEINT:
		_remove_status_with_log(target, STATUS_PROTECT, move.move_id, "protection_broken", battle_log)
		_append(battle_log, {
			"kind": "protection_broken",
			"attacker": attacker,
			"defender": target,
			"move_id": move.move_id,
		})
		return false
	_remove_status_with_log(target, STATUS_PROTECT, move.move_id, "blocked", battle_log)
	_append(battle_log, {
		"kind": "move_blocked",
		"attacker": attacker,
		"defender": target,
		"move_id": move.move_id,
		"status_id": STATUS_PROTECT,
	})
	animation_resolver.select_reaction(target, move, "miss", battle_log)
	return true


func _apply_counter(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, damage_done: int, battle_log: BattleLog) -> void:
	if attacker == null or target == null or attacker == target or target.stats == null or attacker.stats == null:
		return
	if damage_done <= 0 or move.category != PokemonMoveResource.CATEGORY_PHYSICAL:
		return
	if not target.stats.is_active() or not target.stats.battle_statuses.has(STATUS_COUNTER):
		return
	_remove_status_with_log(target, STATUS_COUNTER, move.move_id, "counter_triggered", battle_log)
	var reflected_damage: int = damage_done * 2
	var attacker_was_active: bool = attacker.stats.is_active()
	var applied: int = _apply_damage(target, attacker, move, reflected_damage, battle_log, {
		"kind": "damage_dealt",
		"source": STATUS_COUNTER,
		"source_move_id": move.move_id,
	})
	if applied <= 0:
		return
	_append(battle_log, {
		"kind": "counter_triggered",
		"attacker": target,
		"defender": attacker,
		"move_id": move.move_id,
		"amount": applied,
	})
	if attacker_was_active and not attacker.stats.is_active():
		_append(battle_log, {
			"kind": "unit_fainted",
			"unit": attacker,
			"move_id": move.move_id,
			"source": STATUS_COUNTER,
		})
		animation_resolver.select_reaction(attacker, move, "faint", battle_log)


func _apply_damage(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource, requested_damage: int, battle_log: BattleLog, event: Dictionary) -> int:
	if defender == null or defender.stats == null or requested_damage <= 0:
		return 0
	var amount: int = _capped_damage(move, defender, requested_damage)
	if amount <= 0:
		return 0
	defender.stats.apply_to_curr_health(-amount)
	defender.res.hurt_remaining = TacticsPawnResource.HURT_DURATION
	var payload: Dictionary = event.duplicate(true)
	payload["attacker"] = attacker
	payload["defender"] = defender
	payload["move_id"] = move.move_id
	payload["amount"] = amount
	_append(battle_log, payload)
	animation_resolver.select_reaction(defender, move, "receive_damage", battle_log)
	return amount


func _capped_damage(move: PokemonMoveResource, defender: TacticsPawn, requested_damage: int) -> int:
	if move != null and move.move_id == MOVE_FALSE_SWIPE and defender != null and defender.stats != null:
		return mini(requested_damage, maxi(0, defender.stats.curr_health - 1))
	return requested_damage


func _remove_status_with_log(unit: TacticsPawn, status_id: String, move_id: String, source: String, battle_log: BattleLog) -> void:
	var removed: Dictionary = unit.stats.remove_battle_status(status_id) if unit != null and unit.stats != null else {}
	if removed.is_empty():
		return
	_append(battle_log, {
		"kind": "status_removed",
		"unit": unit,
		"move_id": move_id,
		"status_id": status_id,
		"source": source,
	})


func _should_apply_formula_damage(move: PokemonMoveResource) -> bool:
	if move == null or not move.is_damaging():
		return false
	if move.effect_records.is_empty():
		return true
	for record in move.effect_records:
		if String(record.get("family", "")) == "damage":
			return true
	return false


func _recipient_for(record: Dictionary, attacker: TacticsPawn, target: TacticsPawn) -> TacticsPawn:
	match String(record.get("target", "hit_target")):
		"self":
			return attacker
		_:
			return target


func _heal_amount(record: Dictionary, recipient: TacticsPawn) -> int:
	var amount: int = int(record.get("amount", 0))
	if amount > 0:
		return amount
	var divisor: int = int(record.get("hp_divisor", 0))
	if divisor > 0:
		return maxi(1, int(floor(float(recipient.stats.max_health) / float(divisor))))
	var percent: float = float(record.get("percent", 0.0))
	if percent > 0.0:
		return maxi(1, int(floor(float(recipient.stats.max_health) * percent)))
	return 0


func _recoil_amount(record: Dictionary, attacker: TacticsPawn) -> int:
	var fraction: int = int(record.get("fraction", 0))
	if fraction > 0:
		var source_hp: int = attacker.stats.max_health if bool(record.get("max_hp", true)) else attacker.stats.curr_health
		return maxi(1, int(floor(float(source_hp) / float(fraction))))
	return int(record.get("amount", 0))


func _expanded_targets(attacker: TacticsPawn, declared_target: TacticsPawn, move: PokemonMoveResource, battle_level: TacticsLevel) -> Array[TacticsPawn]:
	if move.tactical_range_kind in [PokemonMoveResource.TacticalRangeKind.AREA, PokemonMoveResource.TacticalRangeKind.LINE]:
		return Targeting.legal_targets_for_move(attacker, move, _all_units_for(attacker, battle_level))
	if Targeting.alignment_allows(attacker, declared_target, move):
		return [declared_target]
	return []


func _all_units_for(attacker: TacticsPawn, battle_level: TacticsLevel) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	if battle_level != null and battle_level.player != null and battle_level.opponent != null:
		for node in [battle_level.player, battle_level.opponent]:
			for child in node.get_children():
				if child is TacticsPawn:
					out.append(child)
	else:
		var root: Node = attacker.get_tree().current_scene if attacker != null and attacker.get_tree() != null else null
		if root != null:
			for child in root.find_children("*", "TacticsPawn", true, false):
				if child is TacticsPawn:
					out.append(child)
	out.sort_custom(func(a: TacticsPawn, b: TacticsPawn) -> bool: return a.name < b.name)
	return out


func _move_for(attacker: TacticsPawn, move_index: int) -> PokemonMoveResource:
	if attacker == null or attacker.stats == null:
		return null
	if move_index < 0 or move_index >= attacker.stats.move_slots.size():
		return null
	if not attacker.stats.has_pp(move_index):
		return null
	return attacker.stats.move_slots[move_index]


func _load_type_chart() -> TypeChartResource:
	return load(TYPE_CHART_PATH) as TypeChartResource


func _append(battle_log: BattleLog, event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)
