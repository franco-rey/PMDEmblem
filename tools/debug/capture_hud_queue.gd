extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const OUTPUT_DIR: String = "res://logs/debug/live_captures"

var captured: Array[String] = []
var label_prefix: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_size = Vector2i(0, 0)
	UiScale.override_factor = 0.0
	label_prefix = _arg("label")
	GameSettings.remember_window_size = false
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=42 mode=pvp team=6 map=chessboard")
	if not ok:
		print("queue: launch failed")
		quit(1)
		return
	var level: TacticsLevel = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 1800:
		await process_frame
		frames += 1
	for name in ["border", "color", "portrait"]:
		var value: String = _arg(name)
		if not value.is_valid_int():
			continue
		match name:
			"border":
				PmdStyle.set_border_style(int(value))
			"color":
				PmdStyle.set_border_color(int(value))
			"portrait":
				PmdStyle.set_portrait_border(int(value))
	for i in range(6):
		await process_frame
	print("queue: started after %d frames, %d queue tiles" % [frames, level.hud._queue_row.get_child_count()])
	await _snap("hud_queue")
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


func _arg(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = String(arg)
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return ""
