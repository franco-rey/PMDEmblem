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


const CURSOR_SHADOW_WIDTH: float = 30.0

var _cursor_shadow: Sprite3D = null


func _ensure_cursor_shadow() -> Sprite3D:
	if _cursor_shadow != null and is_instance_valid(_cursor_shadow):
		return _cursor_shadow
	var level: TacticsLevel = _level_node()
	if level == null:
		return null
	_cursor_shadow = Sprite3D.new()
	_cursor_shadow.name = "CursorShadow"
	_cursor_shadow.texture = TacticsPawnSprite._ground_shadow_texture()
	_cursor_shadow.axis = Vector3.AXIS_Y
	_cursor_shadow.pixel_size = 0.015625
	_cursor_shadow.shaded = false
	_cursor_shadow.transparent = true
	_cursor_shadow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_cursor_shadow.render_priority = -1
	_cursor_shadow.layers = 2
	_cursor_shadow.modulate = Color(0.0, 0.0, 0.0, 0.42)
	_cursor_shadow.scale = Vector3(CURSOR_SHADOW_WIDTH / 64.0, 1.0, CURSOR_SHADOW_WIDTH * 0.55 / 64.0)
	_cursor_shadow.visible = false
	level.add_child(_cursor_shadow)
	return _cursor_shadow


func show_cursor_shadow(tile: TacticsTile) -> void:
	var shadow: Sprite3D = _ensure_cursor_shadow()
	if shadow == null or tile == null:
		hide_cursor_shadow()
		return
	shadow.global_position = tile.global_position + Vector3(0.0, 0.03, 0.0)
	shadow.visible = true


func hide_cursor_shadow() -> void:
	if _cursor_shadow != null and is_instance_valid(_cursor_shadow):
		_cursor_shadow.visible = false


func cursor_shadow_visible() -> bool:
	return _cursor_shadow != null and is_instance_valid(_cursor_shadow) and _cursor_shadow.visible


func _keyboard_confirm() -> bool:
	return Input.is_action_just_pressed("ui_accept") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _mouse_confirm() -> bool:
	return Input.is_action_just_pressed("ui_accept") and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _nav_direction(ctrl: TacticsControls) -> Vector3i:
	var screen := Vector2.ZERO
	if Input.is_action_just_pressed("ui_right"):
		screen.x += 1.0
	if Input.is_action_just_pressed("ui_left"):
		screen.x -= 1.0
	if Input.is_action_just_pressed("ui_up"):
		screen.y += 1.0
	if Input.is_action_just_pressed("ui_down"):
		screen.y -= 1.0
	if screen == Vector2.ZERO:
		return Vector3i.ZERO
	return screen_to_grid(screen, ctrl.get_viewport().get_camera_3d() if ctrl != null and ctrl.is_inside_tree() else null)


static func screen_to_grid(screen: Vector2, camera: Camera3D) -> Vector3i:
	var right := Vector3(1, 0, 0)
	var forward := Vector3(0, 0, -1)
	if camera != null:
		right = Vector3(camera.global_transform.basis.x.x, 0.0, camera.global_transform.basis.x.z)
		forward = Vector3(-camera.global_transform.basis.z.x, 0.0, -camera.global_transform.basis.z.z)
		if right.length() < 0.001:
			right = Vector3(1, 0, 0)
		if forward.length() < 0.001:
			forward = Vector3(0, 0, -1)
	var world: Vector3 = right.normalized() * screen.x + forward.normalized() * screen.y
	if absf(world.x) >= absf(world.z):
		return Vector3i(1 if world.x > 0.0 else -1, 0, 0)
	return Vector3i(0, 0, 1 if world.z > 0.0 else -1)


func _tile_key(tile: TacticsTile) -> Vector3i:
	return Targeting._tile_key(tile)


func _tile_for_key(key: Variant) -> TacticsTile:
	if not (key is Vector3i):
		return null
	var keys: Dictionary = Targeting.arena_tile_keys(_level_node())
	var tile: Variant = keys.get(key, null)
	return tile if tile is TacticsTile else null


func _cursor_tile(ctrl: TacticsControls, flag: String) -> TacticsTile:
	var tile: TacticsTile = _tile_for_key(controls.cursor_key)
	if tile != null and tile.get(flag):
		return tile
	var pawn: TacticsPawn = participant.curr_pawn if participant.curr_pawn != null else ctrl.curr_pawn
	var home: TacticsTile = pawn.get_tile() if pawn != null else null
	controls.cursor_key = _tile_key(home) if home != null else null
	return home


func keyboard_move_cursor(direction: Vector3i, ctrl: TacticsControls, flag: String = "reachable") -> TacticsTile:
	controls.keyboard_mode = true
	var current: TacticsTile = _cursor_tile(ctrl, flag)
	if direction == Vector3i.ZERO:
		return current
	var current_key: Vector3i = _tile_key(current) if current != null else Vector3i.ZERO
	var best: TacticsTile = null
	var best_score: float = INF
	for tile in Targeting.arena_tile_keys(_level_node()).values():
		if not (tile is TacticsTile) or tile == current or not (tile as TacticsTile).get(flag):
			continue
		var delta: Vector3i = _tile_key(tile) - current_key
		var along: int = delta.x * direction.x + delta.z * direction.z
		if along <= 0:
			continue
		var perp: int = absi(delta.x * direction.z) + absi(delta.z * direction.x)
		var score: float = float(along) + float(perp) * 2.5
		if score < best_score:
			best_score = score
			best = tile
	if best != null:
		_disarm()
		controls.cursor_key = _tile_key(best)
		SoundPlayer.cue("ui.cursor")
		return best
	return current


func _arm(tile: TacticsTile) -> void:
	_disarm()
	if tile == null:
		return
	controls.armed_key = _tile_key(tile)
	arena.mark_committed(tile)


func _disarm() -> void:
	var previous: TacticsTile = _tile_for_key(controls.armed_key)
	if previous != null:
		previous.committed = false
	controls.armed_key = null


func _keyboard_confirm_tile(tile: TacticsTile) -> bool:
	if tile == null:
		return false
	controls.keyboard_mode = true
	if controls.armed_key is Vector3i and controls.armed_key == _tile_key(tile):
		_disarm()
		return true
	_arm(tile)
	return false


func keyboard_confirm_location(ctrl: TacticsControls) -> bool:
	var tile: TacticsTile = _cursor_tile(ctrl, "reachable")
	if tile == null or not tile.reachable:
		return false
	if not _keyboard_confirm_tile(tile):
		return false
	return _commit_location(tile, ctrl)


func _commit_location(tile: TacticsTile, ctrl: TacticsControls) -> bool:
	var active_pawn: TacticsPawn = participant.curr_pawn if participant.curr_pawn != null else ctrl.curr_pawn
	if active_pawn == null:
		return false
	active_pawn.res.pathfinding_tilestack = arena.get_pathfinding_tilestack(tile)
	arena.mark_committed(tile)
	SoundPlayer.cue("battle.move_commit")
	t_cam.target = tile
	controls.reset_keyboard_selection()
	hide_cursor_shadow()
	participant.stage = 4
	return true


func legal_targets(move: PokemonMoveResource) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	var pawn: TacticsPawn = participant.curr_pawn
	if pawn == null:
		return out
	var candidates: Array[TacticsPawn] = Targeting.legal_targets_for_move(pawn, move, _all_units_for_selection()) if move != null else []
	for candidate in candidates:
		if candidate != null and candidate.is_alive() and candidate.get_tile() != null and candidate.get_tile().attackable:
			out.append(candidate)
	out.sort_custom(func(a: TacticsPawn, b: TacticsPawn) -> bool: return a.name < b.name)
	return out


func keyboard_cycle_target(step: int, ctrl: TacticsControls) -> TacticsPawn:
	controls.keyboard_mode = true
	if step != 0:
		SoundPlayer.cue("battle.target_cycle")
	var move: PokemonMoveResource = _move_for_slot(participant.curr_pawn, participant.curr_pawn.res.selected_move_index if participant.curr_pawn != null else -1)
	var targets: Array[TacticsPawn] = legal_targets(move)
	if targets.is_empty():
		return null
	if not (controls.cursor_key is Vector3i) and participant.attackable_pawn != null and targets.has(participant.attackable_pawn):
		controls.target_index = targets.find(participant.attackable_pawn)
	controls.target_index = posmod(controls.target_index + step, targets.size())
	_disarm()
	var target: TacticsPawn = targets[controls.target_index]
	controls.cursor_key = _tile_key(target.get_tile())
	return target


func keyboard_confirm_target(ctrl: TacticsControls) -> bool:
	var tile: TacticsTile = _tile_for_key(controls.cursor_key)
	if tile == null or not tile.attackable or participant.attackable_pawn == null:
		return false
	if not _keyboard_confirm_tile(tile):
		return false
	return _commit_target(tile)


func _commit_target(tile: TacticsTile) -> bool:
	var move_index: int = participant.curr_pawn.res.selected_move_index if participant.curr_pawn != null else -1
	var move: PokemonMoveResource = _move_for_slot(participant.curr_pawn, move_index)
	if move != null:
		_log_move_selected(participant.curr_pawn, move, move_index)
	arena.mark_committed(tile)
	SoundPlayer.cue("battle.target_commit")
	t_cam.target = participant.attackable_pawn
	controls.reset_keyboard_selection()
	participant.stage = 7
	return true


func _target_cycle_step() -> int:
	var step: int = 0
	if Input.is_action_just_pressed("camera_right") or Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_up"):
		step += 1
	if Input.is_action_just_pressed("camera_left") or Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_down"):
		step -= 1
	return step


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
	var direction: Vector3i = _nav_direction(ctrl)
	if direction != Vector3i.ZERO:
		keyboard_move_cursor(direction, ctrl, "reachable")
	var tile: TacticsTile = _cursor_tile(ctrl, "reachable") if controls.keyboard_mode else input_service.get_3d_canvas_mouse_position(1, ctrl)
	arena.mark_hover_tile(tile)
	arena.mark_path_preview(tile)
	if controls.keyboard_mode and tile != null and tile.reachable:
		show_cursor_shadow(tile)
	else:
		hide_cursor_shadow()
	if controls.armed_key is Vector3i and (tile == null or controls.armed_key != _tile_key(tile)):
		_disarm()
	if _mouse_confirm() and tile and tile.reachable:
		_commit_location(tile, ctrl)
	elif _keyboard_confirm():
		if tile != null and tile.reachable:
			controls.cursor_key = _tile_key(tile)
		keyboard_confirm_location(ctrl)


func select_pawn_to_attack(ctrl: TacticsControls) -> void:
	controls.set_actions_menu_visibility(true, participant.curr_pawn)
	(ctrl.serv.ui_service as TacticsUIService).set_move_picker_visibility(false, participant.curr_pawn, ctrl, [])
	if participant.attackable_pawn:
		controls.set_actions_menu_visibility(false, participant.attackable_pawn)
		participant.attackable_pawn.show_pawn_stats(false)
	var step: int = _target_cycle_step()
	if step != 0:
		keyboard_cycle_target(step, ctrl)
	var tile: TacticsTile
	if controls.keyboard_mode:
		tile = _tile_for_key(controls.cursor_key)
		if tile == null:
			var first: TacticsPawn = keyboard_cycle_target(0, ctrl)
			tile = first.get_tile() if first != null else null
		arena.mark_hover_tile(tile)
	else:
		tile = _select_hovered_tile(ctrl)
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
	if controls.armed_key is Vector3i and (tile == null or controls.armed_key != _tile_key(tile)):
		_disarm()
	if _mouse_confirm() and tile and tile.attackable and participant.attackable_pawn:
		_commit_target(tile)
	elif _keyboard_confirm() and tile and tile.attackable and participant.attackable_pawn:
		controls.cursor_key = _tile_key(tile)
		keyboard_confirm_target(ctrl)


func player_wants_to_move() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	if controls != null:
		controls.clear_hover_preview()
		controls.reset_keyboard_selection()
	participant.stage = 2


func player_wants_to_cancel() -> void:
	var pawn: TacticsPawn = participant.curr_pawn
	if participant.stage == participant.STAGE_SHOW_ACTIONS and pawn != null and pawn.res != null and pawn.res.can_move and pawn.res.can_attack:
		var menu: Node = pawn.get_tree().root.find_child("PauseMenu", true, false) if pawn.is_inside_tree() else null
		if menu != null and menu.has_method("open"):
			menu.call("open")
			return
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	if controls != null:
		controls.clear_hover_preview()
		controls.reset_keyboard_selection()
	hide_cursor_shadow()
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
	var throw_step: int = _target_cycle_step()
	if throw_step != 0 and not participant.throw_options.is_empty():
		controls.keyboard_mode = true
		controls.target_index = posmod(controls.target_index + throw_step, participant.throw_options.size())
		_disarm()
		var option_path: Array = participant.throw_options[controls.target_index].get("path", [])
		controls.cursor_key = option_path[option_path.size() - 1] if not option_path.is_empty() else null
	var hovered: TacticsTile = _tile_for_key(controls.cursor_key) if controls.keyboard_mode else _select_hovered_tile(ctrl)
	if controls.keyboard_mode:
		arena.mark_hover_tile(hovered)
	var chosen: Dictionary = _throw_option_for_tile(hovered)
	var hit_unit: TacticsPawn = chosen.get("hit_unit", null) as TacticsPawn if not chosen.is_empty() else null
	if hit_unit != null and hit_unit.is_alive():
		participant.attackable_pawn = hit_unit
		controls.set_actions_menu_visibility(true, hit_unit)
		hit_unit.show_pawn_stats(true)
	if controls.armed_key is Vector3i and (hovered == null or controls.armed_key != _tile_key(hovered)):
		_disarm()
	var throw_confirmed: bool = _mouse_confirm() and hovered != null and hovered.attackable and not chosen.is_empty()
	if not throw_confirmed and _keyboard_confirm() and hovered != null and hovered.attackable and not chosen.is_empty():
		throw_confirmed = _keyboard_confirm_tile(hovered)
	if throw_confirmed:
		controls.reset_keyboard_selection()
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
	SoundPlayer.cue("battle.end_turn")
	participant.curr_pawn.end_pawn_turn()
	participant.stage = 0


func player_wants_to_skip_turn() -> void:
	SoundPlayer.cue("battle.end_turn")
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


func select_travel(ctrl: TacticsControls) -> void:
	controls.set_actions_menu_visibility(false, participant.curr_pawn)
	(ctrl.serv.ui_service as TacticsUIService).set_move_picker_visibility(false, participant.curr_pawn, ctrl, [])
	var level: TacticsLevel = _level_node()
	if level == null or level.multiverse.pending_travel.is_empty():
		(ctrl.serv.ui_service as TacticsUIService).set_travel_picker_visibility(false, ctrl, {})
		participant.stage = participant.STAGE_SELECT_PAWN
		return
	(ctrl.serv.ui_service as TacticsUIService).set_travel_picker_visibility(true, ctrl, level.multiverse.pending_travel)


func player_wants_to_travel(option_index: int) -> void:
	var level: TacticsLevel = _level_node()
	if level == null:
		return
	if participant.stage != participant.STAGE_SELECT_TRAVEL:
		return
	if level.multiverse.commit_travel(option_index):
		return
	player_wants_to_cancel_travel()


func player_wants_to_cancel_travel() -> void:
	var level: TacticsLevel = _level_node()
	var pawn: TacticsPawn = participant.curr_pawn
	if level != null:
		var move_id: String = String(level.multiverse.pending_travel.get("move_id", ""))
		level.multiverse.cancel_travel()
		if bool(level.multiverse.travel_rule(move_id).get("strike", false)) and pawn != null and level.release_charge(pawn):
			return
	participant.stage = participant.STAGE_SHOW_ACTIONS if pawn != null and pawn.can_act() else participant.STAGE_SELECT_PAWN


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
		controls.reset_keyboard_selection()
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
