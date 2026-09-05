extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const OUTPUT_DIR: String = "res://logs/debug/readability"

var captured: Array[String] = []
var window_size: Vector2i = Vector2i(1920, 1080)
var label_prefix: String = "polish_"


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				window_size = Vector2i(int(parts[0]), int(parts[1]))
		elif arg.begins_with("--label="):
			label_prefix = arg.trim_prefix("--label=")
	call_deferred("_run")


var _settings_snapshot: String = ""


func _snapshot_settings() -> void:
	if FileAccess.file_exists(GameSettings.SETTINGS_PATH):
		_settings_snapshot = FileAccess.get_file_as_string(GameSettings.SETTINGS_PATH)


func _restore_settings() -> void:
	if _settings_snapshot.is_empty():
		return
	var file := FileAccess.open(GameSettings.SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(_settings_snapshot)
		file.close()


func _run() -> void:
	_snapshot_settings()
	DisplayServer.window_set_size(window_size)
	root.content_scale_size = Vector2i(0, 0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var driver = DRIVER.new(self)
	var saved_flair: bool = GameSettings.battle_flair
	GameSettings.battle_flair = true
	var ok: bool = await driver._launch("match seed=9 mode=pvp map=chessboard team=6 p=0025_pikachu@50:thunderbolt,quick_attack,iron_tail,thunder_wave:static:held_leftovers e=0004_charmander@50:ember,scratch,dragon_rage:blaze:berry_sitrus")
	if not ok:
		print("capture: launch failed")
		quit(1)
		return
	GameSettings.window_mode = "windowed"
	GameSettings.resolution = window_size
	UiScale.override_factor = 0.0
	GameSettings.ui_scale = UiScale.compute(Vector2(window_size))
	GameSettings.apply(root)
	await process_frame
	await process_frame
	await process_frame
	var level: TacticsLevel = driver.level
	var main: Node = driver.main
	var definition := SkirmishDefinitionResource.new()
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.map = load("res://data/models/maps/definitions/chessboard.tres")
	level.banner.show_intro(level, definition)
	await process_frame
	await process_frame
	await _snap("01_intro")
	level.banner.finish_intro()
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await process_frame
		frames += 1
	await create_timer(0.4).timeout
	await _snap("02_turn_banner")
	var hud: BattleHud = level.hud
	var enemy: TacticsPawn = level.notation.pawn_for_id("E1")
	enemy.stats.change_stat_stage("attack", 1)
	enemy.stats.change_stat_stage("speed", -1)
	enemy.stats.apply_battle_status("burn", {"counter": 3})
	hud.pin(enemy)
	await process_frame
	await _snap("03_inspector")
	hud.set_danger_enabled(true)
	await process_frame
	await _snap("04_danger_zone")
	hud.set_danger_enabled(false)
	hud.unpin()
	level.set_terrain("grassy_terrain", 5, "grassy_terrain")
	await create_timer(0.6).timeout
	await _snap("05_terrain")
	level.battle_conditions.erase("grassy_terrain")
	level.battle_log.append({"kind": "field_condition_ended", "condition_id": "grassy_terrain", "reason": "expired"})
	var pikachu: TacticsPawn = level.notation.pawn_for_id("P1")
	level.battle_log.append({"kind": "stat_stage_changed", "unit": pikachu, "stat": "speed", "before": 0, "after": 1, "delta": 1})
	level.battle_log.append({"kind": "intrinsic_triggered", "unit": enemy, "intrinsic_id": "blaze", "hook": "before_damage"})
	level.battle_log.append({"kind": "weather_started", "condition_id": "rain", "rounds": 5})
	await create_timer(0.35).timeout
	await _snap("06_popups")
	var pause: PauseMenu = main.get_node("PauseMenu")
	pause.open()
	pause._show_controls()
	await process_frame
	await _snap("07_controls")
	pause.close()
	level._ops().damage(enemy, 40, {"kind": "hit", "attacker": pikachu})
	var results: BattleResultsScreen = main.get_node("BattleResultsScreen")
	results.show_result(1, definition, level)
	await process_frame
	await _snap("08_results")
	results.hide_results()
	GameSettings.battle_flair = saved_flair
	_restore_settings()
	for path in captured:
		print("capture: %s" % path)
	quit(0)


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		return
	var path: String = "%s/%s%s.png" % [OUTPUT_DIR, label_prefix, label]
	image.save_png(ProjectSettings.globalize_path(path))
	captured.append(path)
