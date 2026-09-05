extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(code: Key) -> void:
	_key(code, true)
	await physics_frame
	_key(code, false)
	await physics_frame


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=9 mode=pvp p=0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember:blaze|0001_bulbasaur@50:tackle:overgrow")
	_assert_true(ok, "battle launches for the input event checks")
	if not ok:
		_finish()
		return
	var level: TacticsLevel = driver.level
	var main: Node = driver.main
	var res: TacticsParticipantResource = level.participant.res
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var pikachu: TacticsPawn = level.notation.pawn_for_id("P1")
	frames = 0
	while (res.curr_pawn != pikachu or res.stage != res.STAGE_SHOW_ACTIONS) and frames < 600:
		await physics_frame
		frames += 1
	var ctrl: TacticsControls = main.get_node("TacticsControls")
	var controls: TacticsControlsResource = ctrl.controls
	var selection: TacticsControlsSelectionService = ctrl.serv.pawn_selection_service
	await physics_frame
	var owner: Control = ctrl.get_viewport().gui_get_focus_owner()
	_assert_true(owner == ctrl.get_act("Move"), "Move holds focus at the action menu")
	await _tap(KEY_DOWN)
	owner = ctrl.get_viewport().gui_get_focus_owner()
	_assert_true(owner == ctrl.get_act("Attack"), "a Down key event moves focus to Attack (%s)" % str(owner))
	await _tap(KEY_UP)
	await _tap(KEY_ENTER)
	frames = 0
	while res.stage != res.STAGE_SELECT_LOCATION and frames < 60:
		await physics_frame
		frames += 1
	_assert_true(res.stage == res.STAGE_SELECT_LOCATION, "Enter on Move opens square selection through a real key event")
	var home: TacticsTile = pikachu.get_tile()
	var moved_key: Variant = null
	for code in [KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP]:
		await _tap(code)
		if controls.cursor_key is Vector3i and controls.cursor_key != Targeting._tile_key(home):
			moved_key = controls.cursor_key
			break
	_assert_true(controls.keyboard_mode and moved_key is Vector3i, "an arrow key event moves the keyboard cursor")
	await _tap(KEY_ENTER)
	var armed: bool = controls.armed_key is Vector3i and res.stage == res.STAGE_SELECT_LOCATION
	_assert_true(armed, "the first Enter arms the square without moving")
	await _tap(KEY_ENTER)
	frames = 0
	while res.stage != res.STAGE_MOVE_PAWN and frames < 30:
		await physics_frame
		frames += 1
	_assert_true(res.stage == res.STAGE_MOVE_PAWN, "the second Enter commits the move")
	frames = 0
	while res.stage != res.STAGE_SHOW_ACTIONS and frames < 900:
		await physics_frame
		frames += 1
	_assert_true(res.stage == res.STAGE_SHOW_ACTIONS, "the menu returns after the walk")
	pikachu.stats.move_slots[0].tactical_range_value = 40
	await physics_frame
	await physics_frame
	owner = ctrl.get_viewport().gui_get_focus_owner()
	_assert_true(owner != null and ctrl.get_act().is_ancestor_of(owner), "focus is back on the action menu")
	while ctrl.get_viewport().gui_get_focus_owner() != ctrl.get_act("Attack") and frames < 920:
		await _tap(KEY_DOWN)
		frames += 1
	await _tap(KEY_ENTER)
	frames = 0
	while res.stage != res.STAGE_SELECT_MOVE and frames < 60:
		await physics_frame
		frames += 1
	_assert_true(res.stage == res.STAGE_SELECT_MOVE, "Enter on Attack opens the move picker")
	await physics_frame
	var picker: Control = ctrl.find_child("MovePicker", true, false)
	owner = ctrl.get_viewport().gui_get_focus_owner()
	_assert_true(owner != null and picker.is_ancestor_of(owner), "the move picker takes focus")
	await _tap(KEY_ENTER)
	frames = 0
	while res.stage != res.STAGE_SELECT_ATTACK_TARGET and frames < 60:
		await physics_frame
		frames += 1
	_assert_true(res.stage == res.STAGE_SELECT_ATTACK_TARGET, "Enter on a move opens target selection")
	await _tap(KEY_D)
	_assert_true(controls.keyboard_mode and res.attackable_pawn != null, "a D key event selects a target (%s)" % (res.attackable_pawn.name if res.attackable_pawn != null else "none"))
	var before_target: TacticsPawn = res.attackable_pawn
	await _tap(KEY_A)
	var after_target: TacticsPawn = res.attackable_pawn
	_assert_true(after_target != null, "an A key event cycles back")
	await _tap(KEY_ENTER)
	_assert_true(controls.armed_key is Vector3i and res.stage == res.STAGE_SELECT_ATTACK_TARGET, "the first Enter arms the target")
	await _tap(KEY_ENTER)
	frames = 0
	while res.stage != res.STAGE_ATTACK and frames < 30:
		await physics_frame
		frames += 1
	_assert_true(res.stage == res.STAGE_ATTACK, "the second Enter fires the move")
	var camera_node: TacticsCamera = main.find_child("TacticsCamera", true, false)
	var heading: int = camera_node.res.y_rot
	await _tap(KEY_E)
	_assert_true(camera_node.res.y_rot != heading, "E rotates the camera through a key event during the animation")
	await _tap(KEY_BRACKETLEFT)
	_assert_true(camera_node.res.orbit_direction == -1, "the left bracket starts an orbit")
	await _tap(KEY_BRACKETLEFT)
	_assert_true(camera_node.res.orbit_direction == 0, "the left bracket again stops it")
	var speed_before: float = GameSettings.cpu_speed
	await _tap(KEY_3)
	_assert_true(is_equal_approx(GameSettings.cpu_speed, 1.0) and is_equal_approx(Engine.time_scale, 1.0), "key 3 selects the 2x battle speed (time scale 1.0)")
	await _tap(KEY_2)
	_assert_true(is_equal_approx(GameSettings.cpu_speed, 0.5), "key 2 selects the 1x battle speed")
	GameSettings.cpu_speed = speed_before
	GameSettings.save_settings()
	var danger_before: bool = level.hud.danger_enabled
	await _tap(KEY_Z)
	_assert_true(level.hud.danger_enabled != danger_before, "Z toggles the danger zone")
	await _tap(KEY_Z)
	_assert_true(level.hud.danger_enabled == danger_before, "Z toggles it back")
	GameSettings.danger_zone = danger_before
	GameSettings.save_settings()
	var controls_node: Control = main.get("tactics_controls") as Control
	await _tap(KEY_TAB)
	_assert_true(not level.hud.visible and not level.message_log.visible and not level.banner.visible and not controls_node.visible and not bool(main.get("interface_visible")), "Tab hides the battle interface")
	await _tap(KEY_TAB)
	_assert_true(level.hud.visible and level.message_log.visible and controls_node.visible and bool(main.get("interface_visible")), "Tab shows it again")
	_finish()


func _finish() -> void:
	if failures > 0:
		push_error("smoke: input_events failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: input_events clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
