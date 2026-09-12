extends SceneTree

const SIZE: int = 1024
const DEFAULT_SOURCE: String = "res://assets/textures/ui/icons/app_icon_source.png"
const DEFAULT_OUT: String = "res://assets/textures/ui/icons/app_icon.png"


func _init() -> void:
	call_deferred("_run")


func _arg(key: String, fallback: String) -> String:
	for entry in OS.get_cmdline_user_args():
		var text: String = String(entry)
		if text.begins_with("--%s=" % key):
			return text.split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var source: String = _arg("source", DEFAULT_SOURCE)
	var out: String = _arg("out", DEFAULT_OUT)
	var art: Image = Image.load_from_file(ProjectSettings.globalize_path(source))
	if art == null or art.is_empty():
		push_error("render_app_icon: cannot read %s" % source)
		quit(1)
		return
	art.convert(Image.FORMAT_RGBA8)
	var scale: float = float(SIZE) / float(maxi(art.get_width(), art.get_height()))
	var width: int = maxi(1, int(round(float(art.get_width()) * scale)))
	var height: int = maxi(1, int(round(float(art.get_height()) * scale)))
	var fitted: Image = art.duplicate()
	fitted.resize(width, height, Image.INTERPOLATE_LANCZOS)
	var icon: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	icon.fill(Color(0, 0, 0, 0))
	icon.blit_rect(fitted, Rect2i(0, 0, width, height), Vector2i(int((SIZE - width) / 2), int((SIZE - height) / 2)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var error: int = icon.save_png(ProjectSettings.globalize_path(out))
	print("render_app_icon: %s (%dx%d as-is) -> %s %dx%d on %d (%d)" % [source, art.get_width(), art.get_height(), out, width, height, SIZE, error])
	quit(0 if error == OK else 1)
