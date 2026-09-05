extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GameSettings.load_settings()
	var saved_mode: String = GameSettings.window_mode
	var saved_resolution: Vector2i = GameSettings.resolution
	var saved_scale: float = GameSettings.ui_scale
	var saved_vsync: bool = GameSettings.vsync
	var saved_track: bool = GameSettings.camera_track
	var saved_report: bool = GameSettings.cpu_battle_report
	var saved_speed: float = GameSettings.cpu_speed
	GameSettings.window_mode = "borderless"
	GameSettings.resolution = Vector2i(1600, 900)
	GameSettings.ui_scale = 2.0
	GameSettings.vsync = false
	GameSettings.camera_track = false
	GameSettings.cpu_battle_report = false
	GameSettings.cpu_speed = 5.0
	_assert_true(GameSettings.save_settings(), "settings save to the user config")
	GameSettings.window_mode = "windowed"
	GameSettings.resolution = Vector2i(1920, 1080)
	GameSettings.ui_scale = 0.0
	GameSettings.vsync = true
	GameSettings.camera_track = true
	GameSettings.cpu_battle_report = true
	GameSettings.cpu_speed = 2.0
	GameSettings.load_settings()
	_assert_true(GameSettings.window_mode == "borderless" and GameSettings.resolution == Vector2i(1600, 900) and is_equal_approx(GameSettings.ui_scale, 2.0) and not GameSettings.vsync and not GameSettings.camera_track and not GameSettings.cpu_battle_report and is_equal_approx(GameSettings.cpu_speed, 5.0), "settings load back the saved values including camera track, CPU report and CPU speed")
	GameSettings.camera_track = saved_track
	GameSettings.cpu_battle_report = saved_report
	GameSettings.cpu_speed = saved_speed
	GameSettings.window_mode = saved_mode
	GameSettings.resolution = saved_resolution
	GameSettings.ui_scale = saved_scale
	GameSettings.vsync = saved_vsync
	GameSettings.save_settings()
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=9 mode=pvp p=0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember,scratch:blaze")
	_assert_true(ok, "battle launches for the menu checks")
	if not ok:
		_finish()
		return
	var main: Node = driver.main
	var level: TacticsLevel = driver.level
	var controls: Node = main.get_node("TacticsControls")
	_assert_true(controls.get_node_or_null("Hints") == null and controls.get_node_or_null("Hints/ControllerHints") == null, "the template controls hint is gone")
	var menu: VBoxContainer = main.get_node("UI/MapSelector/SkirmishMenu")
	_assert_true(menu.get_node_or_null("OptionsButton") != null and menu.get_node_or_null("QuitButton") != null, "main menu has Options and Quit")
	var pause: PauseMenu = main.get_node("PauseMenu")
	_assert_true(pause != null and not pause.is_open and not paused, "pause menu starts closed with the tree running")
	_assert_true(bool(main._can_open_pause_menu()), "pause menu may open while the active unit is choosing an action")
	pause.open()
	_assert_true(pause.is_open and pause.visible and paused, "opening the pause menu pauses the tree")
	var buttons: Array[String] = []
	for node_name in ["ResumeButton", "RestartButton", "LobbyButton", "MainMenuButton", "GraphicsButton", "QuitButton"]:
		if pause._buttons.has(node_name):
			buttons.append(node_name)
	_assert_true(buttons.size() == 6, "pause menu offers resume, restart, lobby, main menu, graphics and quit")
	pause._show_graphics()
	var panel: GraphicsSettingsPanel = pause._graphics
	_assert_true(panel.visible and panel.mode_picker.item_count == 3 and panel.resolution_picker.item_count == 5 and panel.scale_picker.item_count == 4 and panel.camera_track_toggle != null and panel.cpu_report_toggle != null and panel.cpu_speed_picker.item_count == 6, "options panel lists window modes, resolutions, UI scales, camera track, CPU report and CPU speeds")
	var camera_node_early: TacticsCamera = main.find_child("TacticsCamera", true, false)
	GameSettings.camera_track = false
	camera_node_early.res.target = level.notation.pawn_for_id("E1")
	camera_node_early.serv.move.focus_on_target(camera_node_early)
	_assert_true(camera_node_early.res.target == null, "camera track off drops the focus target immediately")
	GameSettings.camera_track = saved_track
	var cpu_res: TacticsParticipantResource = level.participant.res
	var hud_early: BattleHud = level.hud
	var cpu_pawn: TacticsPawn = level.notation.pawn_for_id("E1")
	cpu_pawn.stats.pokemon_instance.control_type = PokemonInstanceResource.ControlType.AI
	cpu_res.curr_pawn = cpu_pawn
	cpu_res.attackable_pawn = level.notation.pawn_for_id("P1")
	cpu_res.stage = cpu_res.STAGE_MOVE_PAWN
	hud_early._refresh_target_panel()
	_assert_true(hud_early._target_panel.visible and hud_early._target_pawn == level.notation.pawn_for_id("P1"), "target panel shows the CPU's target during its attack stage")
	cpu_pawn.stats.pokemon_instance.control_type = PokemonInstanceResource.ControlType.PLAYER
	cpu_res.attackable_pawn = null
	cpu_res.stage = cpu_res.STAGE_SHOW_ACTIONS
	hud_early._refresh_target_panel()
	panel._on_scale_selected(2)
	_assert_true(is_equal_approx(GameSettings.ui_scale, 2.0) and is_equal_approx(UiScale.override_factor, 2.0), "picking a UI scale applies it")
	GameSettings.ui_scale = saved_scale
	UiScale.override_factor = saved_scale
	GameSettings.save_settings()
	pause.close()
	_assert_true(not pause.is_open and not paused, "closing the pause menu resumes the tree")
	var results: BattleResultsScreen = main.get_node("BattleResultsScreen")
	var definition := SkirmishDefinitionResource.new()
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.seed = 9
	results.show_result(1, definition, level)
	_assert_true(results.visible and results._title.text == "Victory!" and results._columns.get_child_count() == 2, "results screen shows the outcome with both sides listed")
	results.show_result(2, definition, level)
	_assert_true(results._title.text == "Defeat", "results screen reports a defeat")
	results.show_result(1, definition, level, "Next Battle (2/3)")
	_assert_true((results._buttons["NextButton"] as Button).visible and (results._buttons["NextButton"] as Button).text == "Next Battle (2/3)" and not (results._buttons["PlayAgainButton"] as Button).visible and results.next_requested.is_connected(main._on_results_next), "series results offer only Next Battle and main handles it")
	results.hide_results()
	var log_dock: BattleMessageLog = level.message_log
	var open_top: float = log_dock.dock_top()
	log_dock.set_minimized(true)
	await process_frame
	_assert_true(not log_dock._scroll.visible and log_dock.dock_top() > open_top and log_dock._toggle.text == "+", "battle log minimizes to its header (%.0f -> %.0f)" % [open_top, log_dock.dock_top()])
	var hud: BattleHud = level.hud
	hud.set_status_minimized(true)
	await process_frame
	await process_frame
	_assert_true(not hud._status_rows.visible and hud._status_toggle.text == "+" and is_equal_approx(hud._status_dock.offset_bottom, log_dock.dock_top() - 8.0), "status dock minimizes and follows the log's top edge")
	log_dock.set_minimized(false)
	hud.set_status_minimized(false)
	_assert_true(TacticsConfig.hover_controls.size() >= 2 and TacticsConfig.hover_controls_contain(log_dock._toggle.get_global_rect().get_center()), "dock toggles register for the click-through guard")
	var override_before: float = UiScale.override_factor
	UiScale.override_factor = 0.0
	_assert_true(is_equal_approx(UiScale.compute(Vector2(1920, 1080), 2.0), 1.0) and is_equal_approx(UiScale.compute(Vector2(2560, 1440), 1.0), 1.5), "UI scale snaps to half steps")
	_assert_true(is_equal_approx(UiScale.compute(Vector2(1080, 1920), 1.0), 0.75) and is_equal_approx(UiScale.compute(Vector2(1080, 1080), 1.0), 0.75) and is_equal_approx(UiScale.compute(Vector2(1600, 1600), 1.0), 1.0) and is_equal_approx(UiScale.compute(Vector2(1280, 720), 1.0), 1.0), "portrait, square and narrow windows scale so the logical width never drops below 1280")
	UiScale.override_factor = override_before
	_assert_true(not hud.stacked_layout_for(1920.0) and hud.stacked_layout_for(1000.0), "the HUD stacks the queue under the panels when the top row cannot fit even with the smallest tiles")
	hud._apply_layout(Vector2(1000.0, 1920.0))
	_assert_true(hud._queue_column.offset_top > BattleHud.PANEL_HEIGHT and is_equal_approx(hud._status_dock.offset_right, 16.0 + BattleMessageLog.dock_width_for(1000.0)), "stacked layout moves the queue box down and narrows the docks")
	hud._apply_layout(Vector2(1920.0, 1080.0))
	_assert_true(is_equal_approx(hud._queue_column.offset_top, 16.0), "wide layout restores the top row")
	var camera_node: TacticsCamera = main.find_child("TacticsCamera", true, false)
	_assert_true(camera_node != null and not camera_node.res.spectator, "human match keeps the camera following actions")
	main._on_return_to_lobby_requested()
	await process_frame
	_assert_true(main.level_instance == null and main.skirmish_lobby.visible, "returning to the lobby unloads the level and opens the lobby")
	main.queue_free()
	await process_frame
	await process_frame
	var bots = DRIVER.new(self)
	var bots_ok: bool = await bots._launch("match seed=3 mode=bots team=2")
	_assert_true(bots_ok, "bot match launches")
	if bots_ok:
		var bots_camera: TacticsCamera = bots.main.find_child("TacticsCamera", true, false)
		_assert_true(bots_camera != null and bots_camera.res.spectator, "bot match frees the camera for spectating")
		_assert_true(bool(bots.main._can_open_pause_menu()), "pause menu opens during a bot match")
		_assert_true(is_equal_approx(Engine.time_scale, GameSettings.cpu_speed) and bots.main.speed_bar.visible, "bot match runs at the CPU speed with the speed bar shown (%.1fx)" % Engine.time_scale)
		bots.main.speed_bar._on_pressed(5.0)
		_assert_true(is_equal_approx(Engine.time_scale, 5.0) and is_equal_approx(GameSettings.cpu_speed, 5.0), "speed bar changes the battle speed and saves it")
		bots.main.speed_bar._on_pressed(saved_speed)
		GameSettings.cpu_speed = saved_speed
		GameSettings.save_settings()
		bots.main._on_main_menu_requested()
		await process_frame
		_assert_true(is_equal_approx(Engine.time_scale, 1.0) and not bots.main.speed_bar.visible, "leaving the bot match restores real time and hides the speed bar")
		bots_camera.res.spectator = false
	_finish()


func _finish() -> void:
	if failures > 0:
		push_error("smoke: pause_and_settings failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: pause_and_settings clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
