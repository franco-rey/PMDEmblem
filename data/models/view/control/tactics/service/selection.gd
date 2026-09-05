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


func select_pawn(player: Node3D, ctrl: TacticsControls) -> void:
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
	arena.mark_path_preview(tile)
	if Input.is_action_just_pressed("ui_accept") and tile and tile.reachable:
		var active_pawn: TacticsPawn = participant.curr_pawn if participant.curr_pawn != null else ctrl.curr_pawn
		if active_pawn == null:
			return
		active_pawn.res.pathfinding_tilestack = arena.get_pathfinding_tilestack(tile)
		arena.mark_committed(tile)
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
		arena.mark_committed(tile)
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
	if participant.stage == participant.STAGE_SELECT_THROW_TARGET:
		participant.pending_intent = null
		participant.throw_options = []
		participant.attackable_pawn = null
		participant.stage = participant.STAGE_SELECT_ITEM_ACTION
	elif participant.stage == participant.STAGE_SELECT_ITEM_ACTION:
		participant.pending_intent = null
		participant.stage = participant.STAGE_SHOW_ACTIONS
	elif participant.stage in [participant.STAGE_DISPLAY_TARGETS, participant.STAGE_SELECT_ATTACK_TARGET] and _has_pokemon_moves(participant.curr_pawn):
		participant.stage = participant.STAGE_SELECT_MOVE
	elif participant.stage == participant.STAGE_SELECT_MOVE:
		participant.stage = participant.STAGE_SHOW_ACTIONS
	else:
		participant.stage = 1 if participant.stage > 1 else 0


func player_wants_to_use_item() -> void:
	if controls != null:
		controls.clear_hover_preview()
	var pawn: TacticsPawn = participant.curr_pawn
	if pawn == null or pawn.stats == null or PokemonItemService.held_item_for(pawn.stats) == null or not pawn.res.can_attack:
		return
	participant.pending_intent = null
	participant.throw_options = []
	participant.stage = participant.STAGE_SELECT_ITEM_ACTION


func select_item_action(ctrl: TacticsControls) -> void:
	controls.set_actions_menu_visibility(false, participant.curr_pawn)
	(ctrl.serv.ui_service as TacticsUIService).set_item_picker_visibility(true, participant.curr_pawn, ctrl)
	_update_actions_preview()


func player_wants_to_select_item_use() -> void:
	var pawn: TacticsPawn = participant.curr_pawn
	if pawn == null or pawn.stats == null:
		return
	var item: PokemonItemResource = PokemonItemService.held_item_for(pawn.stats)
	if item == null:
		return
	var entry: Dictionary = BattleItemCatalog.entry_for(item.item_id)
	if not bool(entry.get("can_use", false)):
		return
	if controls != null:
		controls.clear_hover_preview()
	participant.pending_intent = BattleActionIntent.use_item(pawn, item.item_id)
	participant.attackable_pawn = pawn
	_log_item_action_selected(pawn, participant.pending_intent)
	if t_cam != null:
		t_cam.target = pawn
	participant.stage = participant.STAGE_ITEM_ACTION


func player_wants_to_select_item_throw() -> void:
	var pawn: TacticsPawn = participant.curr_pawn
	if pawn == null or pawn.stats == null:
		return
	var item: PokemonItemResource = PokemonItemService.held_item_for(pawn.stats)
	if item == null:
		return
	var options: Array[Dictionary] = Targeting.throw_options(pawn, _throw_range(item), _all_units_for_selection(), Targeting.arena_tile_keys(_level_node()))
	if options.is_empty():
		return
	if controls != null:
		controls.clear_hover_preview()
	participant.throw_options = options
	participant.pending_intent = null
	participant.attackable_pawn = null
	participant.stage = participant.STAGE_SELECT_THROW_TARGET


func select_throw_target(ctrl: TacticsControls) -> void:
	controls.set_actions_menu_visibility(false, participant.curr_pawn)
	(ctrl.serv.ui_service as TacticsUIService).set_item_picker_visibility(false, participant.curr_pawn, ctrl)
	var pawn: TacticsPawn = participant.curr_pawn
	var arena_node: TacticsArena = _arena_node()
	if pawn == null or arena_node == null:
		return
	if participant.attackable_pawn != null:
		controls.set_actions_menu_visibility(false, participant.attackable_pawn)
		participant.attackable_pawn.show_pawn_stats(false)
		participant.attackable_pawn = null
	arena_node.reset_all_tile_markers()
	var keys: Dictionary = Targeting.arena_tile_keys(_level_node())
	for option in participant.throw_options:
		for key in option.get("path", []):
			var tile: Variant = keys.get(key, null)
			if tile is TacticsTile:
				(tile as TacticsTile).attackable = true
	var hovered: TacticsTile = _select_hovered_tile(ctrl)
	var chosen: Dictionary = _throw_option_for_tile(hovered)
	var hit_unit: TacticsPawn = chosen.get("hit_unit", null) as TacticsPawn if not chosen.is_empty() else null
	if hit_unit != null and hit_unit.is_alive():
		participant.attackable_pawn = hit_unit
		controls.set_actions_menu_visibility(true, hit_unit)
		hit_unit.show_pawn_stats(true)
	if Input.is_action_just_pressed("ui_accept") and hovered != null and hovered.attackable and not chosen.is_empty():
		var item: PokemonItemResource = PokemonItemService.held_item_for(pawn.stats)
		if item == null:
			participant.stage = participant.STAGE_SHOW_ACTIONS
			return
		participant.pending_intent = BattleActionIntent.throw_item(pawn, item.item_id, chosen.get("direction", Vector3i.ZERO), hit_unit)
		_log_item_action_selected(pawn, participant.pending_intent)
		if t_cam != null:
			t_cam.target = hit_unit if hit_unit != null else hovered
		participant.stage = participant.STAGE_ITEM_ACTION


func _throw_option_for_tile(tile: TacticsTile) -> Dictionary:
	if tile == null:
		return {}
	var key: Vector3i = Targeting._tile_key(tile)
	for option in participant.throw_options:
		var path: Array = option.get("path", [])
		if path.has(key):
			return option
	return {}


func _throw_range(item: PokemonItemResource) -> int:
	var presentation: ActionPresentationCatalog = ActionPresentationCatalog.shared()
	var entry: Dictionary = presentation.item(item.item_id)
	var throw_spec: Dictionary = entry.get("throw", {}) if entry.get("throw", null) is Dictionary else {}
	var params: Dictionary = throw_spec.get("params", {}) if throw_spec.get("params", null) is Dictionary else {}
	if params.has("range"):
		return int(params["range"])
	var defaults: Dictionary = presentation.throw_defaults.get("projectile", {}) if presentation.throw_defaults.get("projectile", null) is Dictionary else {}
	return int(defaults.get("range", 8))


func _level_node() -> TacticsLevel:
	var node: Node = participant.curr_pawn
	while node != null:
		if node is TacticsLevel:
			return node as TacticsLevel
		node = node.get_parent()
	return null


func _log_item_action_selected(pawn: TacticsPawn, intent: BattleActionIntent) -> void:
	var level: TacticsLevel = _level_node()
	if level == null or intent == null:
		return
	level.battle_log.append({
		"kind": "item_action_selected",
		"attacker": pawn,
		"item_id": intent.item_id,
		"action": intent.kind,
		"direction": intent.direction,
	})


func player_wants_to_wait() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	if controls != null:
		controls.clear_hover_preview()
	if _release_charge_first():
		return
	participant.curr_pawn.end_pawn_turn()
	participant.stage = 0


func player_wants_to_skip_turn() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	if controls != null:
		controls.clear_hover_preview()
	if _release_charge_first():
		return
	participant.skip_turn()


func _release_charge_first() -> bool:
	var level: TacticsLevel = _level_node()
	if level == null or participant.curr_pawn == null:
		return false
	if level.release_charge(participant.curr_pawn):
		controls.set_actions_menu_visibility(false, participant.curr_pawn)
		return true
	return false


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
