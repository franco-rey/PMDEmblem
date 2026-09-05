extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var accept_keys: Array[int] = []
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventKey:
			accept_keys.append((event as InputEventKey).physical_keycode)
	_assert_true(accept_keys.has(KEY_ENTER) and accept_keys.has(KEY_SPACE) and accept_keys.has(KEY_KP_ENTER), "Enter, keypad Enter and Space all confirm")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	_assert_true(TacticsControlsSelectionService.screen_to_grid(Vector2(1, 0), camera) == Vector3i(1, 0, 0) and TacticsControlsSelectionService.screen_to_grid(Vector2(0, 1), camera) == Vector3i(0, 0, -1), "arrow keys map to grid directions relative to the camera")
	camera.rotate_y(PI * 0.5)
	_assert_true(TacticsControlsSelectionService.screen_to_grid(Vector2(1, 0), camera) == Vector3i(0, 0, -1), "a rotated camera turns the mapping with it")
	camera.queue_free()
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=9 mode=pvp p=0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember:blaze|0001_bulbasaur@50:tackle:overgrow")
	_assert_true(ok, "battle launches for the keyboard checks")
	if not ok:
		_finish()
		return
	var level: TacticsLevel = driver.level
	var main: Node = driver.main
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var res: TacticsParticipantResource = level.participant.res
	var pikachu: TacticsPawn = level.notation.pawn_for_id("P1")
	frames = 0
	while (res.curr_pawn != pikachu or res.stage != res.STAGE_SHOW_ACTIONS) and frames < 600:
		await physics_frame
		frames += 1
	_assert_true(res.curr_pawn == pikachu and res.stage == res.STAGE_SHOW_ACTIONS, "Pikachu's turn reaches the action menu")
	var ctrl: TacticsControls = main.get_node("TacticsControls")
	var controls: TacticsControlsResource = ctrl.controls
	var selection: TacticsControlsSelectionService = ctrl.serv.pawn_selection_service
	var move_button: Button = ctrl.get_act("Move")
	_assert_true(move_button != null and move_button.has_focus(), "the Move button holds focus so arrows walk the action menu")
	ctrl._player_wants_to_move()
	frames = 0
	while res.stage != res.STAGE_SELECT_LOCATION and frames < 120:
		await physics_frame
		frames += 1
	_assert_true(res.stage == res.STAGE_SELECT_LOCATION, "Move opens location selection")
	var actions_box: Control = ctrl.get_node("HBox/Actions")
	var focus_owner: Control = ctrl.get_viewport().gui_get_focus_owner()
	_assert_true(focus_owner == null or not actions_box.is_ancestor_of(focus_owner), "the action menu releases focus while a square is being chosen so Enter cannot fire a menu button")
	var left_bound: bool = false
	for event in InputMap.action_get_events("ui_left"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_LEFT:
			left_bound = true
	_assert_true(left_bound, "the Left arrow is bound to ui_left")
	var home: TacticsTile = pikachu.get_tile()
	var moved: TacticsTile = selection.keyboard_move_cursor(Vector3i(1, 0, 0), ctrl, "reachable")
	if moved == home:
		moved = selection.keyboard_move_cursor(Vector3i(0, 0, 1), ctrl, "reachable")
	if moved == home:
		moved = selection.keyboard_move_cursor(Vector3i(-1, 0, 0), ctrl, "reachable")
	if moved == home:
		moved = selection.keyboard_move_cursor(Vector3i(0, 0, -1), ctrl, "reachable")
	_assert_true(controls.keyboard_mode and moved != null and moved != home and moved.reachable, "an arrow press moves the keyboard cursor onto a reachable square")
	selection.select_new_location(ctrl)
	_assert_true(selection.cursor_shadow_visible() and selection._cursor_shadow.global_position.distance_to(moved.global_position) < 0.1, "the keyboard cursor casts the pawn shadow on the destination square")
	var first: bool = selection.keyboard_confirm_location(ctrl)
	_assert_true(not first and moved.committed and res.stage == res.STAGE_SELECT_LOCATION, "the first confirm only highlights the square")
	var second: bool = selection.keyboard_confirm_location(ctrl)
	_assert_true(second and res.stage == res.STAGE_MOVE_PAWN and not pikachu.res.pathfinding_tilestack.is_empty(), "the second confirm commits the move")
	frames = 0
	while res.stage != res.STAGE_SHOW_ACTIONS and frames < 900:
		await physics_frame
		frames += 1
	_assert_true(res.stage == res.STAGE_SHOW_ACTIONS and res.curr_pawn == pikachu, "the menu returns after the walk")
	await physics_frame
	await physics_frame
	var owner_after: Control = ctrl.get_viewport().gui_get_focus_owner()
	_assert_true(owner_after != null and actions_box.is_ancestor_of(owner_after), "focus returns to the action menu for arrow navigation")
	pikachu.stats.move_slots[0].tactical_range_value = 40
	pikachu.stats.move_slots[1].tactical_range_value = 40
	ctrl._player_wants_to_attack()
	frames = 0
	while res.stage != res.STAGE_SELECT_MOVE and frames < 60:
		await physics_frame
		frames += 1
	var picker: Control = ctrl.find_child("MovePicker", true, false)
	var picker_cancel: Button = picker.get_node("Cancel") as Button
	selection.select_move(ctrl)
	await physics_frame
	picker_cancel.grab_focus()
	selection.select_move(ctrl)
	await physics_frame
	selection.select_move(ctrl)
	_assert_true(ctrl.get_viewport().gui_get_focus_owner() == picker_cancel, "the move picker keeps the button the arrows moved focus to (%s)" % str(ctrl.get_viewport().gui_get_focus_owner()))
	selection.player_wants_to_select_move(0)
	frames = 0
	while res.stage != res.STAGE_SELECT_ATTACK_TARGET and frames < 120:
		await physics_frame
		frames += 1
	_assert_true(res.stage == res.STAGE_SELECT_ATTACK_TARGET, "picking Thunderbolt opens target selection")
	await physics_frame
	var move_visible: bool = (ctrl.get_act("Move") as Button).visible
	var cancel_visible: bool = (ctrl.get_act("Cancel") as Button).visible
	_assert_true(not move_visible and cancel_visible, "only Cancel stays on the action menu while a target is chosen")
	var move: PokemonMoveResource = pikachu.stats.move_slots[0]
	var targets: Array[TacticsPawn] = selection.legal_targets(move)
	_assert_true(targets.size() >= 1, "Thunderbolt has legal targets from the new square (%d)" % targets.size())
	var first_target: TacticsPawn = selection.keyboard_cycle_target(0, ctrl)
	await physics_frame
	_assert_true(first_target != null and res.attackable_pawn == first_target, "keyboard targeting selects the first legal target")
	if targets.size() >= 2:
		var next_target: TacticsPawn = selection.keyboard_cycle_target(1, ctrl)
		await physics_frame
		_assert_true(next_target != first_target and res.attackable_pawn == next_target, "D cycles to the next target")
		selection.keyboard_cycle_target(-1, ctrl)
		await physics_frame
		_assert_true(res.attackable_pawn == first_target, "A cycles back")
	_assert_true(controls.lock_horizontal_pan, "A and D do not pan the camera while choosing a target")
	var armed: bool = selection.keyboard_confirm_target(ctrl)
	var target_tile: TacticsTile = res.attackable_pawn.get_tile()
	_assert_true(not armed and target_tile.committed and res.stage == res.STAGE_SELECT_ATTACK_TARGET, "the first confirm highlights the target")
	var hud_stage_pin: bool = level.hud._targeting_stage()
	_assert_true(hud_stage_pin, "clicks do not pin the inspector while a target is being chosen")
	var fired: bool = selection.keyboard_confirm_target(ctrl)
	_assert_true(fired and res.stage == res.STAGE_ATTACK and not selection.cursor_shadow_visible(), "the second confirm fires the move and clears the cursor shadow")
	_finish()


func _finish() -> void:
	if failures > 0:
		push_error("smoke: keyboard_controls failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: keyboard_controls clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
