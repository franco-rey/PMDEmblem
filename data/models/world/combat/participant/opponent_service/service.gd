class_name TacticsOpponentService
extends RefCounted

var res: TacticsParticipantResource
var camera: TacticsCameraResource
var controls: TacticsControlsResource
var arena: TacticsArena
var minimum_viable_ai := MinimumViableAI.new()
var type_chart: TypeChartResource = load("res://data/models/pokemon/generated/types/type_chart.tres") as TypeChartResource


func _init(_res: TacticsParticipantResource, _camera: TacticsCameraResource, _controls: TacticsControlsResource, _arena: TacticsArena) -> void:
	res = _res
	camera = _camera
	controls = _controls
	arena = _arena


func is_pawn_configured(opponent: Node3D) -> bool:
	for pawn: TacticsPawn in opponent.get_children():
		if not pawn.center():
			return false
	return true


func choose_pawn(opponent: Node3D) -> void:
	arena.reset_all_tile_markers()
	for p: TacticsPawn in opponent.get_children():
		if p.can_act() and p.is_alive():
			res.curr_pawn = p
			p.res.selected_move_index = p.stats.first_usable_move_index(false)
			p.res.use_legacy_attack_fallback = false
			res.stage = res.STAGE_SHOW_ACTIONS
			return


func chase_nearest_enemy(opponent: Node3D, player_node: Node) -> void:
	if res.curr_pawn.res.can_move:
		arena.reset_all_tile_markers()
		arena.process_surrounding_tiles(res.curr_pawn.get_tile(), res.curr_pawn.stats.movement, opponent.get_children())
		arena.mark_reachable_tiles(res.curr_pawn.get_tile(), res.curr_pawn.stats.movement)

		var action: AIAction = minimum_viable_ai.choose_action(
			res.curr_pawn,
			opponent.get_children(),
			player_node.get_children(),
			type_chart
		)
		if action.move_index >= 0:
			res.curr_pawn.res.selected_move_index = action.move_index
			if action.move_index < res.curr_pawn.stats.move_slots.size():
				var move: PokemonMoveResource = res.curr_pawn.stats.move_slots[action.move_index]
				res.curr_pawn.stats.attack_range = max(1, move.tactical_range_value)
		var to: TacticsTile = arena.get_nearest_target_adjacent_tile(res.curr_pawn, player_node.get_children())
		res.curr_pawn.res.pathfinding_tilestack = arena.get_pathfinding_tilestack(to)
		camera.target = to
		if DebugLog.debug_enabled:
			print_rich("[color=orange]", res.curr_pawn, " moving to [i]", to, "[/i][/color]")
			print_rich("[color=orange]Through: [i]", res.curr_pawn.res.pathfinding_tilestack, "[/i][/color]")
			print_rich("[color=cyan]Camera target updated to destination tile.[/color]")
		res.stage = res.STAGE_SHOW_MOVEMENTS
	elif res.curr_pawn.is_alive() and res.curr_pawn.res.can_attack:
		var action: AIAction = minimum_viable_ai.choose_action(
			res.curr_pawn,
			opponent.get_children(),
			player_node.get_children(),
			type_chart
		)
		if action.move_index >= 0:
			res.curr_pawn.res.selected_move_index = action.move_index
			if action.move_index < res.curr_pawn.stats.move_slots.size():
				var held_move: PokemonMoveResource = res.curr_pawn.stats.move_slots[action.move_index]
				res.curr_pawn.stats.attack_range = max(1, held_move.tactical_range_value)
		if DebugLog.debug_enabled:
			print_rich("[color=orange]", res.curr_pawn, " cannot move this turn; attacking in place.[/color]")
		res.stage = res.STAGE_SELECT_LOCATION
	else:
		if DebugLog.debug_enabled:
			print_rich("[color=orange]", res.curr_pawn, " can neither move nor attack; ending its turn.[/color]")
		res.curr_pawn.end_pawn_turn()
		res.stage = res.STAGE_SELECT_PAWN


func is_pawn_done_moving() -> void:
	if res.curr_pawn.res.pathfinding_tilestack.is_empty():
		if DebugLog.debug_enabled:
			print_rich("[color=orange]Pawn is done moving.[/color]")
		res.stage = res.STAGE_SELECT_LOCATION


func choose_pawn_to_attack() -> void:
	arena.reset_all_tile_markers()
	var move_index: int = res.curr_pawn.res.selected_move_index
	var move: PokemonMoveResource = res.curr_pawn.stats.move_slots[move_index] if move_index >= 0 and move_index < res.curr_pawn.stats.move_slots.size() else null
	var range_value: int = max(1, move.tactical_range_value) if move != null else res.curr_pawn.stats.attack_range
	arena.process_surrounding_tiles(res.curr_pawn.get_tile(), range_value)
	arena.mark_attackable_tiles(res.curr_pawn.get_tile(), range_value)

	var action: AIAction = minimum_viable_ai.choose_action(
		res.curr_pawn,
		res.curr_pawn.get_parent().get_children(),
		res.targets.get_children(),
		type_chart,
		_level_for(res.curr_pawn)
	)
	res.pending_intent = null
	if action.intent != null and action.intent.is_item_action():
		res.curr_pawn.res.use_legacy_attack_fallback = false
		res.pending_intent = action.intent
		res.attackable_pawn = action.target_unit
		_log_item_intent(res.curr_pawn, action.intent)
	elif action.move_index >= 0:
		res.curr_pawn.res.selected_move_index = action.move_index
		res.curr_pawn.res.use_legacy_attack_fallback = false
		res.attackable_pawn = action.target_unit
	else:
		res.curr_pawn.res.use_legacy_attack_fallback = false
		res.attackable_pawn = null
		_log_no_usable_move(res.curr_pawn)
	if res.attackable_pawn:
		if DebugLog.debug_enabled:
			print_rich("[color=orange]Weakest target detected:", res.attackable_pawn, "[/color]")
		controls.set_actions_menu_visibility(true, res.attackable_pawn)
		camera.target = res.attackable_pawn
	else:
		if DebugLog.debug_enabled:
			print_rich("[color=orange]No target detected.[/color]")

	res.stage = res.STAGE_MOVE_PAWN


func _level_for(pawn: TacticsPawn) -> TacticsLevel:
	var node: Node = pawn
	while node != null:
		if node is TacticsLevel:
			return node as TacticsLevel
		node = node.get_parent()
	return null


func _log_item_intent(pawn: TacticsPawn, intent: BattleActionIntent) -> void:
	var level: TacticsLevel = _level_for(pawn)
	if level == null:
		return
	level.battle_log.append({
		"kind": "item_action_selected",
		"attacker": pawn,
		"item_id": intent.item_id,
		"action": intent.kind,
		"direction": intent.direction,
		"source": "ai",
	})


func _log_no_usable_move(pawn: TacticsPawn) -> void:
	if pawn == null:
		return
	var node: Node = pawn
	while node != null:
		if node is TacticsLevel:
			(node as TacticsLevel).battle_log.append({
				"kind": "no_usable_move",
				"attacker": pawn,
			})
			return
		node = node.get_parent()
