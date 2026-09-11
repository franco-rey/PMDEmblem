extends SceneTree

const SIZE: int = 1024
const RADIUS: float = 190.0
const FRAME: float = 30.0
const PORTRAIT: int = 600
const PORTRAIT_FRAME: float = 18.0
const DEFAULT_SPECIES: String = "0025_pikachu"
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
	var slug: String = _arg("species", DEFAULT_SPECIES)
	var out: String = _arg("out", DEFAULT_OUT)
	var image: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var fill: Color = Color(PmdStyle.NAVY_DEEP.r, PmdStyle.NAVY_DEEP.g, PmdStyle.NAVY_DEEP.b, 1.0)
	var frame: Color = PmdStyle.FRAME
	var half: float = float(SIZE) * 0.5
	for y in range(SIZE):
		for x in range(SIZE):
			var distance: float = _rounded_distance(Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half), Vector2(half, half), RADIUS)
			if distance > 0.0:
				continue
			image.set_pixel(x, y, frame if distance > -FRAME else fill)
	var portrait: Texture2D = PortraitLibrary.texture_for(slug, PortraitLibrary.NORMAL)
	if portrait == null:
		push_error("render_app_icon: no portrait for %s" % slug)
		quit(1)
		return
	var art: Image = portrait.get_image()
	art.convert(Image.FORMAT_RGBA8)
	art.resize(PORTRAIT, PORTRAIT, Image.INTERPOLATE_NEAREST)
	var origin: int = int((SIZE - PORTRAIT) / 2)
	var pad: int = int(PORTRAIT_FRAME)
	image.fill_rect(Rect2i(origin - pad, origin - pad, PORTRAIT + pad * 2, PORTRAIT + pad * 2), frame)
	image.blit_rect(art, Rect2i(0, 0, PORTRAIT, PORTRAIT), Vector2i(origin, origin))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var error: int = image.save_png(ProjectSettings.globalize_path(out))
	print("render_app_icon: %s -> %s (%d)" % [slug, out, error])
	quit(0 if error == OK else 1)


func _rounded_distance(point: Vector2, half_extent: Vector2, radius: float) -> float:
	var q: Vector2 = point.abs() - (half_extent - Vector2(radius, radius))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
