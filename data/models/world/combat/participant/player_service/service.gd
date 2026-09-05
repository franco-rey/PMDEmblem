class_name TacticsPlayerService
extends RefCounted

var res: TacticsParticipantResource
var camera: TacticsCameraResource
var controls: TacticsControlsResource
var arena: TacticsArena


func _init(_res: TacticsParticipantResource, _camera: TacticsCameraResource, _controls: TacticsControlsResource, _arena: TacticsArena) -> void:
	res = _res
	camera = _camera
	controls = _controls
	arena = _arena


func toggle_enemy_stats(opponent_node: Node, other_node: Node = null) -> void:
	var enemy_pawns: Array = opponent_node.get_children() if opponent_node != null else []

	if res.display_opponent_stats:
		for p in enemy_pawns:
			if p is TacticsPawn:
				var alive: bool = (p as TacticsPawn).is_alive()
				p.res.pawn_hud_enabled = alive
				p.show_pawn_stats(alive)
		_hide_side_stats(other_node)
	else:
		_hide_side_stats(opponent_node)
		_hide_side_stats(other_node)


func _hide_side_stats(node: Node) -> void:
	if node == null:
		return
	for p in node.get_children():
		if p is TacticsPawn and p.res.pawn_hud_enabled:
			p.show_pawn_stats(false)
			p.res.pawn_hud_enabled = false


func is_pawn_configured(player: TacticsPlayer) -> bool:
	for pawn: TacticsPawn in player.get_children():
		if pawn is TacticsPawn:
			if not pawn.center():
				return false
	return true


func show_available_pawn_actions() -> void:
	controls.set_actions_menu_visibility(true, res.curr_pawn)
	arena.reset_all_tile_markers()
	if controls.preview_mode == TacticsControlsResource.PREVIEW_MOVEMENT:
		arena.mark_movement_preview(res.curr_pawn)
	else:
		arena.mark_hover_tile(res.curr_pawn.get_tile())


func show_available_movements() -> void:
	arena.reset_all_tile_markers()

	var p: TacticsPawn = res.curr_pawn
	if not p:
		return

	camera.target = p
	arena.process_surrounding_tiles(p.get_tile(), int(p.stats.movement), p.get_parent().get_children())
	arena.mark_reachable_tiles(p.get_tile(), p.stats.movement)
	res.stage = res.STAGE_SELECT_LOCATION


func display_attackable_targets() -> void:
	arena.reset_all_tile_markers()
	var p: TacticsPawn = res.curr_pawn
	if not p:
		return
	if p.stats.move_slots.size() > 0:
		var move_index: int = p.res.selected_move_index
		if move_index < 0:
			p.res.can_attack = false
			res.stage = res.STAGE_SHOW_ACTIONS
			return
		p.res.selected_move_index = move_index
		var move: PokemonMoveResource = p.stats.move_slots[move_index]
		p.stats.attack_range = max(1, move.tactical_range_value)

	res.display_opponent_stats = true

	camera.target = p
	if not _mark_move_targets(p):
		p.res.can_attack = false
		res.stage = res.STAGE_SHOW_ACTIONS
		return
	res.stage = res.STAGE_SELECT_ATTACK_TARGET


func _mark_move_targets(p: TacticsPawn) -> bool:
	if p == null or p.stats.move_slots.is_empty():
		arena.process_surrounding_tiles(p.get_tile(), float(p.stats.attack_range))
		arena.mark_attackable_tiles(p.get_tile(), float(p.stats.attack_range))
		return true
	var move_index: int = p.res.selected_move_index
	var move: PokemonMoveResource = p.stats.move_slots[move_index] if move_index >= 0 and move_index < p.stats.move_slots.size() else null
	if move == null:
		return false
	var units: Array[TacticsPawn] = []
	for child in p.get_parent().get_children():
		if child is TacticsPawn:
			units.append(child)
	if res.targets != null:
		for child in res.targets.get_children():
			if child is TacticsPawn and not units.has(child):
				units.append(child)
	var targets: Array[TacticsPawn] = Targeting.legal_targets_for_move(p, move, units)
	for target in targets:
		if target != null and target.get_tile() != null:
			target.get_tile().attackable = true
	return not targets.is_empty()


func move_pawn() -> void:
	var p: TacticsPawn = res.curr_pawn
	controls.set_actions_menu_visibility(false, p)
	if p.res.pathfinding_tilestack.is_empty():
		res.stage = res.STAGE_SELECT_PAWN if not p.can_act() else res.STAGE_SHOW_ACTIONS
