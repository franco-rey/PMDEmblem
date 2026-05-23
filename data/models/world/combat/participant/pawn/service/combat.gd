class_name TacticsPawnCombatService
extends RefCounted
## Service class for managing combat actions of pawns in the tactics game

const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"

var damage_resolver := DamageResolver.new()
var _fallback_rng := RandomNumberGenerator.new()


func _init() -> void:
	_fallback_rng.seed = 0


## Executes an attack from one pawn to another
##
## @param pawn: The attacking TacticsPawn
## @param target_pawn: The TacticsPawn being attacked
## @param delta: Time elapsed since the last frame
## @return: Whether the attack was completed
func attack_target_pawn(pawn: TacticsPawn, target_pawn: TacticsPawn, delta: float) -> bool:
	if pawn == null or target_pawn == null or not pawn.is_alive() or not target_pawn.is_alive():
		return true

	# Make the attacking pawn face the target
	pawn.serv.movement.look_at_direction(pawn, target_pawn.global_position - pawn.global_position)
	
	# Check if the pawn can attack and enough time has passed for the attack animation
	if pawn.res.can_attack and pawn.res.wait_delay > TacticsPawnResource.MIN_TIME_FOR_ATTACK / 4.0:
		var move_index: int = _selected_move_index(pawn)
		var move: PokemonMoveResource = _selected_move_for(pawn, move_index)
		if move == null:
			if pawn.stats.move_slots.is_empty() or pawn.res.use_legacy_attack_fallback:
				_apply_legacy_attack(pawn, target_pawn)
			else:
				_log_event(pawn, {
					"kind": "move_rejected",
					"attacker": pawn,
					"reason": "no_pp",
				})
			pawn.res.use_legacy_attack_fallback = false
			pawn.res.set_attacking(false)
		else:
			pawn.res.selected_move_index = move_index
			pawn.res.use_legacy_attack_fallback = false
			_resolve_pokemon_attack(pawn, target_pawn, move, move_index)
			pawn.res.set_attacking(false)

		# Print debug information if debug mode is enabled
		if DebugLog.debug_enabled:
			print_rich("[color=pink]Attacked ", target_pawn, ".[/color]")
	
	# If the minimum time for attack hasn't passed, increment the wait delay
	if pawn.res.wait_delay < TacticsPawnResource.MIN_TIME_FOR_ATTACK:
		pawn.res.wait_delay += delta
		return false
	
	# Reset the wait delay and return true to indicate the attack is complete
	pawn.res.wait_delay = 0.0
	return true


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


func _selected_move_index(pawn: TacticsPawn) -> int:
	var selected: int = pawn.res.selected_move_index
	if pawn.stats.has_pp(selected):
		return selected
	var fallback: int = pawn.stats.first_usable_move_index(false)
	return fallback


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


func _log_event(pawn: TacticsPawn, event: Dictionary) -> void:
	var battle_level: TacticsLevel = _battle_level(pawn)
	_append(battle_level.battle_log if battle_level != null else null, event)


func _append(battle_log: BattleLog, event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)
