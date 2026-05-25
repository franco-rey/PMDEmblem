class_name TacticsControlsSelectionService
extends RefCounted

var participant: TacticsParticipantResource
var arena: TacticsArenaResource
var controls: TacticsControlsResource
var t_cam: TacticsCameraResource
var input_service: TacticsControlsInputService


func _init(_participant: TacticsParticipantResource, _arena: TacticsArenaResource, _controls: TacticsControlsResource, _t_cam: TacticsCameraResource, _input_service: TacticsControlsInputService) -> void:
	participant = _participant
	arena = _arena
	controls = _controls
	t_cam = _t_cam
	input_service = _input_service


func select_pawn(player: TacticsPlayer, ctrl: TacticsControls) -> void:
	arena.reset_all_tile_markers()
	if ctrl.curr_pawn:
		controls.set_actions_menu_visibility(false, participant.curr_pawn)
		ctrl.curr_pawn.show_pawn_stats(false)

	ctrl.curr_pawn = _select_hovered_pawn(ctrl)
	if not ctrl.curr_pawn:
		return
	else:
		ctrl.curr_pawn.show_pawn_stats(true)

	if Input.is_action_just_pressed("ui_accept") and ctrl.curr_pawn.can_act():
		if ctrl.curr_pawn in player.get_children():
			t_cam.target = ctrl.curr_pawn
			participant.curr_pawn = ctrl.curr_pawn
			controls.set_actions_menu_visibility(true, participant.curr_pawn)
			participant.stage = 1


func _select_hovered_pawn(ctrl: TacticsControls) -> PhysicsBody3D:
	var pawn: TacticsPawn = input_service.get_3d_canvas_mouse_position(2, ctrl)
	var tile: TacticsTile = input_service.get_3d_canvas_mouse_position(1, ctrl) if not pawn else pawn.get_tile()
	arena.mark_hover_tile(tile)
	return pawn if pawn else tile.get_tile_occupier() if tile else null


func _select_hovered_tile(ctrl: TacticsControls) -> TacticsTile:
	var pawn: TacticsPawn = input_service.get_3d_canvas_mouse_position(2, ctrl)
	var tile: TacticsTile = input_service.get_3d_canvas_mouse_position(1, ctrl) if not pawn else pawn.get_tile()
	arena.mark_hover_tile(tile)
	return tile


func select_new_location(ctrl: TacticsControls) -> void:
	var tile: TacticsTile = input_service.get_3d_canvas_mouse_position(1, ctrl)
	arena.mark_hover_tile(tile)
	if Input.is_action_just_pressed("ui_accept") and tile and tile.reachable:
		var active_pawn: TacticsPawn = participant.curr_pawn if participant.curr_pawn != null else ctrl.curr_pawn
		if active_pawn == null:
			return
		active_pawn.res.pathfinding_tilestack = arena.get_pathfinding_tilestack(tile)
		t_cam.target = tile
		participant.stage = 4


func select_pawn_to_attack(ctrl: TacticsControls) -> void:
	controls.set_actions_menu_visibility(true, participant.curr_pawn)
	(ctrl.serv.ui_service as TacticsUIService).set_move_picker_visibility(false, participant.curr_pawn, ctrl, [])
	if participant.attackable_pawn:
		controls.set_actions_menu_visibility(false, participant.attackable_pawn)
		participant.attackable_pawn.show_pawn_stats(false)
	var tile: TacticsTile = _select_hovered_tile(ctrl)
	participant.attackable_pawn = tile.get_tile_occupier() if tile and tile.attackable else null
	var move_index: int = participant.curr_pawn.res.selected_move_index if participant.curr_pawn != null else -1
	var move: PokemonMoveResource = _move_for_slot(participant.curr_pawn, move_index)
	if participant.attackable_pawn != null and (
			not (participant.attackable_pawn is TacticsPawn)
			or not (participant.attackable_pawn as TacticsPawn).is_alive()
	):
		participant.attackable_pawn = null
	if participant.attackable_pawn != null and participant.curr_pawn.stats.move_slots.size() > 0:
		if move != null and not Targeting.is_target_legal(participant.curr_pawn, participant.attackable_pawn, move):
			participant.attackable_pawn = null
	if participant.attackable_pawn:
		controls.set_actions_menu_visibility(true, participant.attackable_pawn)
		participant.attackable_pawn.show_pawn_stats(true)
	if Input.is_action_just_pressed("ui_accept") and tile and tile.attackable and participant.attackable_pawn:
		if move != null:
			_log_move_selected(participant.curr_pawn, move, move_index)
		t_cam.target = participant.attackable_pawn
		participant.stage = 7


func player_wants_to_move() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	if controls != null:
		controls.clear_hover_preview()
	participant.stage = 2


func player_wants_to_cancel() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	if controls != null:
		controls.clear_hover_preview()
	if participant.stage in [participant.STAGE_DISPLAY_TARGETS, participant.STAGE_SELECT_ATTACK_TARGET] and _has_pokemon_moves(participant.curr_pawn):
		participant.stage = participant.STAGE_SELECT_MOVE
	elif participant.stage == participant.STAGE_SELECT_MOVE:
		participant.stage = participant.STAGE_SHOW_ACTIONS
	else:
		participant.stage = 1 if participant.stage > 1 else 0


func player_wants_to_wait() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	if controls != null:
		controls.clear_hover_preview()
	participant.curr_pawn.end_pawn_turn()
	participant.stage = 0


func player_wants_to_skip_turn() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	if controls != null:
		controls.clear_hover_preview()
	participant.skip_turn()


func player_wants_to_attack() -> void:
	if controls != null:
		controls.clear_hover_preview()
	if participant.curr_pawn != null and participant.curr_pawn.stats.move_slots.size() > 0:
		if participant.curr_pawn.stats.first_usable_move_index(false) < 0:
			participant.curr_pawn.res.can_attack = false
			participant.stage = 1
			return
		participant.stage = participant.STAGE_SELECT_MOVE
		return
	participant.stage = participant.STAGE_DISPLAY_TARGETS


func select_move(ctrl: TacticsControls) -> void:
	controls.set_actions_menu_visibility(false, participant.curr_pawn)
	var units: Array[TacticsPawn] = _all_units_for_selection()
	(ctrl.serv.ui_service as TacticsUIService).set_move_picker_visibility(true, participant.curr_pawn, ctrl, units)
	_update_move_picker_preview()


func refresh_hover_preview() -> void:
	match participant.stage:
		participant.STAGE_SHOW_ACTIONS:
			_update_actions_preview()
		participant.STAGE_SELECT_MOVE:
			_update_move_picker_preview()


func player_wants_to_select_move(slot_index: int) -> void:
	var pawn: TacticsPawn = participant.curr_pawn
	if pawn == null or pawn.stats == null:
		return
	if slot_index < 0 or slot_index >= pawn.stats.move_slots.size():
		return
	var move: PokemonMoveResource = _move_for_slot(pawn, slot_index)
	if move == null or not pawn.stats.has_pp(slot_index):
		return
	if not Targeting.has_legal_target(pawn, move, _all_units_for_selection()):
		return
	pawn.res.selected_move_index = slot_index
	if controls != null:
		controls.clear_hover_preview()
	if _should_auto_confirm_self_target(pawn, move):
		_log_move_selected(pawn, move, slot_index)
		participant.attackable_pawn = pawn
		if t_cam != null:
			t_cam.target = pawn
		participant.stage = participant.STAGE_ATTACK
		return
	participant.stage = participant.STAGE_DISPLAY_TARGETS


func _has_pokemon_moves(pawn: TacticsPawn) -> bool:
	return pawn != null and pawn.stats != null and not pawn.stats.move_slots.is_empty()


func _move_for_slot(pawn: TacticsPawn, slot_index: int) -> PokemonMoveResource:
	if pawn == null or pawn.stats == null or slot_index < 0 or slot_index >= pawn.stats.move_slots.size():
		return null
	return pawn.stats.move_slots[slot_index]


func _should_auto_confirm_self_target(pawn: TacticsPawn, move: PokemonMoveResource) -> bool:
	return pawn != null and move != null and move.can_target_self() and not move.can_target_allies() and not move.can_target_foes()


func _update_move_picker_preview() -> void:
	var arena_node: TacticsArena = _arena_node()
	if arena_node == null:
		return
	arena_node.reset_all_tile_markers()
	var pawn: TacticsPawn = participant.curr_pawn
	if pawn == null:
		return
	if controls != null and controls.preview_mode == TacticsControlsResource.PREVIEW_MOVE_SLOT:
		var slot_index: int = controls.preview_move_slot_index
		var move: PokemonMoveResource = pawn.stats.move_slots[slot_index] if slot_index >= 0 and slot_index < pawn.stats.move_slots.size() else null
		if move != null:
			arena_node.mark_move_range_preview(pawn, move)
			arena_node.mark_hover_tile(pawn.get_tile())
			return
	var enemies: Array[TacticsPawn] = []
	if participant.targets != null:
		for child: Node in participant.targets.get_children():
			if child is TacticsPawn:
				enemies.append(child as TacticsPawn)
	arena_node.mark_unit_tiles_attackable(enemies)
	arena_node.mark_hover_tile(pawn.get_tile())


func _update_actions_preview() -> void:
	var arena_node: TacticsArena = _arena_node()
	if arena_node == null:
		return
	arena_node.reset_all_tile_markers()
	var pawn: TacticsPawn = participant.curr_pawn
	if pawn == null:
		return
	if controls != null and controls.preview_mode == TacticsControlsResource.PREVIEW_MOVEMENT:
		arena_node.mark_movement_preview(pawn)
	else:
		arena_node.mark_hover_tile(pawn.get_tile())


func _arena_node() -> TacticsArena:
	var node: Node = participant.curr_pawn
	while node != null:
		if node is TacticsLevel:
			var level: TacticsLevel = node as TacticsLevel
			return level.arena
		node = node.get_parent()
	return null


func _all_units_for_selection() -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	if participant.curr_pawn != null and participant.curr_pawn.get_parent() != null:
		for child: Node in participant.curr_pawn.get_parent().get_children():
			if child is TacticsPawn:
				out.append(child)
	if participant.targets != null:
		for child: Node in participant.targets.get_children():
			if child is TacticsPawn and not out.has(child):
				out.append(child)
	out.sort_custom(func(a: TacticsPawn, b: TacticsPawn) -> bool: return a.name < b.name)
	return out


func _log_move_selected(pawn: TacticsPawn, move: PokemonMoveResource, slot_index: int) -> void:
	var node: Node = pawn
	while node != null:
		if node is TacticsLevel:
			var level: TacticsLevel = node as TacticsLevel
			level.battle_log.append({
				"kind": "move_selected",
				"attacker": pawn,
				"move_id": move.move_id,
				"slot_index": slot_index,
			})
			return
		node = node.get_parent()
