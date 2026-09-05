class_name GameSettings
extends RefCounted

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "graphics"
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "borderless"]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const UI_SCALES: Array[float] = [0.0, 1.0, 2.0, 3.0]
const CPU_SPEEDS: Array[float] = [0.5, 1.0, 2.0, 5.0, 10.0]

static var window_mode: String = "windowed"
static var resolution: Vector2i = Vector2i(1920, 1080)
static var ui_scale: float = 0.0
static var vsync: bool = true
static var camera_track: bool = true
static var cpu_battle_report: bool = true
static var cpu_speed: float = 2.0
static var loaded: bool = false


static func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		window_mode = String(config.get_value(SECTION, "window_mode", window_mode))
		var stored: Variant = config.get_value(SECTION, "resolution", resolution)
		if stored is Vector2i:
			resolution = stored
		ui_scale = float(config.get_value(SECTION, "ui_scale", ui_scale))
		vsync = bool(config.get_value(SECTION, "vsync", vsync))
		camera_track = bool(config.get_value(SECTION, "camera_track", camera_track))
		cpu_battle_report = bool(config.get_value(SECTION, "cpu_battle_report", cpu_battle_report))
		cpu_speed = float(config.get_value(SECTION, "cpu_speed", cpu_speed))
	if not WINDOW_MODES.has(window_mode):
		window_mode = "windowed"
	if not UI_SCALES.has(ui_scale):
		ui_scale = 0.0
	if not CPU_SPEEDS.has(cpu_speed):
		cpu_speed = 2.0
	loaded = true


static func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value(SECTION, "window_mode", window_mode)
	config.set_value(SECTION, "resolution", resolution)
	config.set_value(SECTION, "ui_scale", ui_scale)
	config.set_value(SECTION, "vsync", vsync)
	config.set_value(SECTION, "camera_track", camera_track)
	config.set_value(SECTION, "cpu_battle_report", cpu_battle_report)
	config.set_value(SECTION, "cpu_speed", cpu_speed)
	return config.save(SETTINGS_PATH) == OK


static func apply(window: Window) -> void:
	UiScale.override_factor = ui_scale
	if window == null or DisplayServer.get_name() == "headless":
		return
	var window_id: int = window.get_window_id()
	match window_mode:
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false, window_id)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, window_id)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, window_id)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, window_id)
			var screen: int = DisplayServer.window_get_current_screen(window_id)
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen), window_id)
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen), window_id)
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false, window_id)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, window_id)
			if DisplayServer.window_get_size(window_id) != resolution:
				DisplayServer.window_set_size(resolution, window_id)
				var screen: int = DisplayServer.window_get_current_screen(window_id)
				var origin: Vector2i = DisplayServer.screen_get_position(screen)
				var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
				DisplayServer.window_set_position(origin + (screen_size - resolution) / 2, window_id)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED, window_id)
	UiScale.apply(window)


static func window_mode_label(mode: String) -> String:
	match mode:
		"fullscreen":
			return "Fullscreen"
		"borderless":
			return "Borderless window"
	return "Windowed"


static func resolution_label(size: Vector2i) -> String:
	return "%d x %d" % [size.x, size.y]


static func ui_scale_label(value: float) -> String:
	if value <= 0.0:
		return "Auto"
	return "%dx" % int(value)


static func cpu_speed_label(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%dx" % int(roundf(value))
	return "%sx" % ("%.1f" % value)

