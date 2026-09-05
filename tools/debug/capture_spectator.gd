extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const OUTPUT_DIR: String = "res://logs/debug/readability"

var captured: Array[String] = []
var window_size: Vector2i = Vector2i(1920, 1080)
var label_prefix: String = "spectator_"
var code: String = "match seed=42 mode=bots team=6 map=chessboard"
var seconds: float = 6.0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				window_size = Vector2i(int(parts[0]), int(parts[1]))
		elif arg.begins_with("--label="):
			label_prefix = arg.trim_prefix("--label=")
		elif arg.begins_with("--code="):
			code = arg.trim_prefix("--code=")
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(window_size)
	root.content_scale_size = Vector2i(0, 0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(code)
	if not ok:
		print("capture: launch failed")
		quit(1)
		return
	DisplayServer.window_set_size(window_size)
	UiScale.override_factor = UiScale.compute(Vector2(window_size))
	UiScale.apply(root)
	await process_frame
	var level: TacticsLevel = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await process_frame
		frames += 1
	print("capture: time_scale=%.1f speed_bar_visible=%s" % [Engine.time_scale, str(driver.main.speed_bar.visible)])
	var elapsed: float = 0.0
	var shots: int = 0
	var target_seen: bool = false
	while elapsed < seconds:
		await process_frame
		elapsed += 1.0 / 60.0
		if level.hud != null and level.hud._target_panel.visible and not target_seen:
			target_seen = true
			await _snap("%02d_target" % shots)
			shots += 1
		if int(elapsed * 60.0) % 90 == 0:
			await _snap("%02d" % shots)
			shots += 1
	print("capture: target panel seen=%s turns=%d" % [str(target_seen), level.notation.turn_index])
	Engine.time_scale = 1.0
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
