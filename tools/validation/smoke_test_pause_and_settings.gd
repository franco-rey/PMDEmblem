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
	GameSettings.window_mode = "borderless"
	GameSettings.resolution = Vector2i(1600, 900)
	GameSettings.ui_scale = 2.0
	GameSettings.vsync = false
	_assert_true(GameSettings.save_settings(), "settings save to the user config")
	GameSettings.window_mode = "windowed"
	GameSettings.resolution = Vector2i(1920, 1080)
	GameSettings.ui_scale = 0.0
	GameSettings.vsync = true
	GameSettings.load_settings()
	_assert_true(GameSettings.window_mode == "borderless" and GameSettings.resolution == Vector2i(1600, 900) and is_equal_approx(GameSettings.ui_scale, 2.0) and not GameSettings.vsync, "settings load back the saved values")
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
	_assert_true(panel.visible and panel.mode_picker.item_count == 3 and panel.resolution_picker.item_count == 5 and panel.scale_picker.item_count == 4, "graphics panel lists window modes, resolutions and UI scales")
	panel._on_scale_selected(2)
	_assert_true(is_equal_approx(GameSettings.ui_scale, 2.0) and is_equal_approx(UiScale.override_factor, 2.0), "picking a UI scale applies it")
	GameSettings.ui_scale = saved_scale
	UiScale.override_factor = saved_scale
	GameSettings.save_settings()
	pause.close()
	_assert_true(not pause.is_open and not paused, "closing the pause menu resumes the tree")
	var level: TacticsLevel = driver.level
	var results: BattleResultsScreen = main.get_node("BattleResultsScreen")
	var definition := SkirmishDefinitionResource.new()
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.seed = 9
	results.show_result(1, definition, level)
	_assert_true(results.visible and results._title.text == "Victory!" and results._columns.get_child_count() == 2, "results screen shows the outcome with both sides listed")
	results.show_result(2, definition, level)
	_assert_true(results._title.text == "Defeat", "results screen reports a defeat")
	results.hide_results()
	main._on_return_to_lobby_requested()
	await process_frame
	_assert_true(main.level_instance == null and main.skirmish_lobby.visible, "returning to the lobby unloads the level and opens the lobby")
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
