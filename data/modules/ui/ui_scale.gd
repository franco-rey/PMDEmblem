class_name UiScale
extends RefCounted

const DESIGN_HEIGHT: float = 1080.0
const MIN_DESIGN_WIDTH: float = 1280.0
const MIN_FACTOR: float = 0.75
const MAX_FACTOR: float = 3.0
const HIDPI_THRESHOLD: float = 1.5
const HIDPI_BONUS: float = 1.1
const SNAP_STEP: float = 0.5

static var override_factor: float = 0.0
static var _watched: Dictionary = {}


static func compute(window_size: Vector2, screen_scale: float = 1.0) -> float:
	if override_factor > 0.0:
		return override_factor
	if window_size.y <= 1.0:
		return 1.0
	var bonus: float = HIDPI_BONUS if screen_scale >= HIDPI_THRESHOLD else 1.0
	var by_height: float = window_size.y / DESIGN_HEIGHT * bonus
	var by_width: float = window_size.x / MIN_DESIGN_WIDTH * bonus if window_size.x > 1.0 else by_height
	var raw: float = clampf(minf(by_height, by_width), MIN_FACTOR, MAX_FACTOR)
	return maxf(MIN_FACTOR, snappedf(raw, SNAP_STEP))


static func screen_scale_for(window: Window) -> float:
	if window == null or DisplayServer.get_name() == "headless":
		return 1.0
	var screen: int = DisplayServer.window_get_current_screen(window.get_window_id())
	return maxf(1.0, DisplayServer.screen_get_scale(screen))


static func apply(window: Window) -> float:
	if window == null:
		return 1.0
	var factor: float = compute(Vector2(window.size), screen_scale_for(window))
	if not is_equal_approx(window.content_scale_factor, factor):
		window.content_scale_factor = factor
	return factor


static func watch(window: Window) -> void:
	if window == null:
		return
	apply(window)
	var key: int = window.get_instance_id()
	if _watched.has(key):
		return
	_watched[key] = true
	window.size_changed.connect(func() -> void: apply(window))
