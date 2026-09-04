class_name TacticsPawnCombatService
extends RefCounted

const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"

var damage_resolver := DamageResolver.new()
var action_resolver := BattleActionResolver.new()
var _fallback_rng := RandomNumberGenerator.new()


func _init() -> void:
	_fallback_rng.seed = 0


func attack_target_pawn(pawn: TacticsPawn, target_pawn: TacticsPawn, delta: float) -> bool:
	if pawn == null or target_pawn == null or not pawn.is_alive() or not target_pawn.is_alive():
		if pawn != null and pawn.res.presentation_locked:
			if not _presentation_finished(pawn, delta):
				return false
			pawn.res.wait_delay = 0.0
			pawn.res.presentation_locked = false
		return true

	pawn.serv.movement.look_at_direction(pawn, target_pawn.global_position - pawn.global_position)

	if pawn.res.can_attack and pawn.res.wait_delay > TacticsPawnResource.MIN_TIME_FOR_ATTACK / 4.0:
		var move_index: int = _selected_move_index(pawn, target_pawn)
		var move: PokemonMoveResource = _selected_move_for(pawn, move_index)
		if move == null:
			if pawn.stats.move_slots.is_empty() or pawn.res.use_legacy_attack_fallback:
				_apply_legacy_attack(pawn, target_pawn)
			else:
				_log_event(pawn, {
					"kind": "no_usable_move",
					"attacker": pawn,
				})
			pawn.res.use_legacy_attack_fallback = false
			pawn.res.set_attacking(false)
		else:
			pawn.res.selected_move_index = move_index
			pawn.res.use_legacy_attack_fallback = false
			action_resolver.execute(pawn, target_pawn, move_index, _battle_level(pawn))
			pawn.res.set_attacking(false)
			pawn.res.presentation_locked = true
			pawn.res.presentation_wait = 0.0

		if DebugLog.debug_enabled:
			print_rich("[color=pink]Attacked ", target_pawn, ".[/color]")

	if pawn.res.wait_delay < TacticsPawnResource.MIN_TIME_FOR_ATTACK:
		pawn.res.wait_delay += delta
		return false

	if pawn.res.presentation_locked and not _presentation_finished(pawn, delta):
		return false

	pawn.res.wait_delay = 0.0
	pawn.res.presentation_locked = false
	return true


func perform_intent(pawn: TacticsPawn, intent: BattleActionIntent, delta: float) -> bool:
	if pawn == null or intent == null or not pawn.is_alive():
		return true
	if intent.kind == BattleActionIntent.KIND_MOVE:
		return attack_target_pawn(pawn, intent.target, delta)
	if pawn.res.can_attack and not pawn.res.intent_executed and pawn.res.wait_delay > TacticsPawnResource.MIN_TIME_FOR_ATTACK / 4.0:
		if intent.direction != Vector3i.ZERO:
			pawn.serv.movement.look_at_direction_8(pawn, Vector3(float(intent.direction.x), 0.0, float(intent.direction.z)))
		elif intent.target != null and intent.target != pawn:
			pawn.serv.movement.look_at_direction_8(pawn, intent.target.global_position - pawn.global_position)
		var result: Dictionary = action_resolver.execute_intent(intent, _battle_level(pawn))
		pawn.res.intent_executed = true
		_log_event(pawn, {"kind": "item_action_executed", "attacker": pawn, "item_id": intent.item_id, "action": intent.kind, "ok": bool(result.get("ok", false)), "reason": String(result.get("reason", ""))})
		pawn.res.set_attacking(false)
		pawn.res.presentation_locked = true
		pawn.res.presentation_wait = 0.0

	if pawn.res.wait_delay < TacticsPawnResource.MIN_TIME_FOR_ATTACK:
		pawn.res.wait_delay += delta
		return false

	if pawn.res.presentation_locked and not _presentation_finished(pawn, delta):
		return false

	pawn.res.wait_delay = 0.0
	pawn.res.presentation_locked = false
	pawn.res.intent_executed = false
	return true


func _presentation_finished(pawn: TacticsPawn, delta: float) -> bool:
	var battle_level: TacticsLevel = _battle_level(pawn)
	if battle_level == null or battle_level.presentation_runner == null:
		return true
	pawn.res.presentation_wait += delta
	if pawn.res.presentation_wait > TacticsPawnResource.PRESENTATION_TIMEOUT:
		battle_level.presentation_runner.cancel_all("attack_wait_timeout")
		return true
	return not battle_level.presentation_runner.is_busy()


func _resolve_pokemon_attack(pawn: TacticsPawn, target_pawn: TacticsPawn, move: PokemonMoveResource, move_index: int) -> void:
	var battle_level: TacticsLevel = _battle_level(pawn)
	var battle_log: BattleLog = battle_level.battle_log if battle_level != null else null
	var rng: RandomNumberGenerator = battle_level.battle_rng if battle_level != null else _fallback_rng
	var type_chart: TypeChartResource = battle_level.get_type_chart() if battle_level != null else _load_type_chart()

	_append(battle_log, {
		"kind": "move_used",
		"attacker": pawn,
		"move_id": move.move_id,
	})

	var was_active: bool = target_pawn.stats.is_active()
	var result: DamageResult = damage_resolver.resolve(pawn.stats, target_pawn.stats, move, type_chart, rng)
	pawn.stats.consume_pp(move_index)
	_append(battle_log, {
		"kind": "pp_decremented",
		"attacker": pawn,
		"move_id": move.move_id,
		"remaining": pawn.stats.current_pp[move_index] if move_index < pawn.stats.current_pp.size() else 0,
	})

	if not result.hit:
		_append(battle_log, {
			"kind": "miss",
			"attacker": pawn,
			"defender": target_pawn,
			"move_id": move.move_id,
		})
		return

	if result.damage > 0:
		target_pawn.stats.apply_to_curr_health(-result.damage)
		target_pawn.res.hurt_remaining = TacticsPawnResource.HURT_DURATION

	_append(battle_log, {
		"kind": "damage_dealt",
		"attacker": pawn,
		"defender": target_pawn,
		"move_id": move.move_id,
		"amount": result.damage,
		"multiplier": result.effectiveness,
		"stab": result.stab,
		"critical": result.is_critical,
	})

	if was_active and not target_pawn.stats.is_active():
		target_pawn.res.hurt_remaining = 0.0
		_append(battle_log, {
			"kind": "unit_fainted",
			"unit": target_pawn,
		})


func _apply_legacy_attack(pawn: TacticsPawn, target_pawn: TacticsPawn) -> void:
	var battle_level: TacticsLevel = _battle_level(pawn)
	var battle_log: BattleLog = battle_level.battle_log if battle_level != null else null
	var was_active: bool = target_pawn.stats.is_active()
	target_pawn.stats.apply_to_curr_health(-pawn.stats.attack_power)
	target_pawn.res.hurt_remaining = TacticsPawnResource.HURT_DURATION
	_append(battle_log, {
		"kind": "damage_dealt",
		"attacker": pawn,
		"defender": target_pawn,
		"move_id": "legacy_attack",
		"amount": pawn.stats.attack_power,
		"multiplier": 1.0,
		"stab": false,
	})
	if was_active and not target_pawn.stats.is_active():
		target_pawn.res.hurt_remaining = 0.0
		_append(battle_log, {
			"kind": "unit_fainted",
			"unit": target_pawn,
		})


func _selected_move_index(pawn: TacticsPawn, target_pawn: TacticsPawn) -> int:
	var selected: int = pawn.res.selected_move_index
	if pawn.stats.has_pp(selected) and _move_can_use_on_target(pawn, target_pawn, pawn.stats.move_slots[selected]):
		return selected
	for i in range(pawn.stats.move_slots.size()):
		if not pawn.stats.has_pp(i):
			continue
		if _move_can_use_on_target(pawn, target_pawn, pawn.stats.move_slots[i]):
			return i
	return -1


func _move_can_use_on_target(pawn: TacticsPawn, target_pawn: TacticsPawn, move: PokemonMoveResource) -> bool:
	if pawn == null or target_pawn == null or move == null:
		return false
	if move.tactical_range_kind in [PokemonMoveResource.TacticalRangeKind.AREA, PokemonMoveResource.TacticalRangeKind.LINE]:
		return Targeting.has_legal_target(pawn, move, _battle_units_for(pawn))
	return Targeting.alignment_allows(pawn, target_pawn, move)


func _selected_move_for(pawn: TacticsPawn, move_index: int) -> PokemonMoveResource:
	if move_index < 0 or move_index >= pawn.stats.move_slots.size():
		return null
	if not pawn.stats.has_pp(move_index):
		return null
	return pawn.stats.move_slots[move_index]


func _load_type_chart() -> TypeChartResource:
	return load(TYPE_CHART_PATH) as TypeChartResource


func _battle_level(pawn: TacticsPawn) -> TacticsLevel:
	var node: Node = pawn
	while node != null:
		if node is TacticsLevel:
			return node as TacticsLevel
		node = node.get_parent()
	return null


func _battle_units_for(pawn: TacticsPawn) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	var battle_level: TacticsLevel = _battle_level(pawn)
	if battle_level != null and battle_level.player != null and battle_level.opponent != null:
		for team in [battle_level.player, battle_level.opponent]:
			for child in team.get_children():
				if child is TacticsPawn:
					out.append(child as TacticsPawn)
	return out


func _log_event(pawn: TacticsPawn, event: Dictionary) -> void:
	var battle_level: TacticsLevel = _battle_level(pawn)
	_append(battle_level.battle_log if battle_level != null else null, event)


func _append(battle_log: BattleLog, event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)
