class_name GameSettings
extends RefCounted

const GAME_VERSION: String = "0.18.0"
const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "graphics"
const AUDIO_SECTION: String = "audio"
const NET_SECTION: String = "network"
const AUDIO_BUSES: Dictionary = {"master": "Master", "sfx": "SFX", "music": "Music"}
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "borderless"]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const UI_SCALES: Array[float] = [0.0, 1.0, 2.0, 3.0]
const CPU_SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.5, 5.0, 10.0]

static var window_mode: String = "windowed"
static var resolution: Vector2i = Vector2i(1920, 1080)
static var ui_scale: float = 0.0
static var vsync: bool = true
static var camera_track: bool = true
static var cpu_battle_report: bool = true
static var cpu_speed: float = 0.5
static var battle_flair: bool = true
static var danger_zone: bool = false
static var master_volume: float = 1.0
static var sfx_volume: float = 0.8
static var music_volume: float = 0.6
static var player_name: String = ""
static var last_address: String = "127.0.0.1"
static var net_port: int = 24555
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
		battle_flair = bool(config.get_value(SECTION, "battle_flair", battle_flair))
		danger_zone = bool(config.get_value(SECTION, "danger_zone", danger_zone))
		player_name = String(config.get_value(NET_SECTION, "player_name", player_name))
		last_address = String(config.get_value(NET_SECTION, "last_address", last_address))
		net_port = int(config.get_value(NET_SECTION, "port", net_port))
		master_volume = clampf(float(config.get_value(AUDIO_SECTION, "master_volume", master_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value(AUDIO_SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)
		music_volume = clampf(float(config.get_value(AUDIO_SECTION, "music_volume", music_volume)), 0.0, 1.0)
	if not WINDOW_MODES.has(window_mode):
		window_mode = "windowed"
	if not UI_SCALES.has(ui_scale):
		ui_scale = 0.0
	if not CPU_SPEEDS.has(cpu_speed):
		cpu_speed = 0.5
	if player_name.strip_edges().is_empty():
		player_name = default_player_name()
	loaded = true


static func default_player_name() -> String:
	var candidate: String = OS.get_environment("USER")
	if candidate.strip_edges().is_empty():
		candidate = "Player"
	return candidate.strip_edges()


static func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value(SECTION, "window_mode", window_mode)
	config.set_value(SECTION, "resolution", resolution)
	config.set_value(SECTION, "ui_scale", ui_scale)
	config.set_value(SECTION, "vsync", vsync)
	config.set_value(SECTION, "camera_track", camera_track)
	config.set_value(SECTION, "cpu_battle_report", cpu_battle_report)
	config.set_value(SECTION, "cpu_speed", cpu_speed)
	config.set_value(SECTION, "battle_flair", battle_flair)
	config.set_value(SECTION, "danger_zone", danger_zone)
	config.set_value(NET_SECTION, "player_name", player_name)
	config.set_value(NET_SECTION, "last_address", last_address)
	config.set_value(NET_SECTION, "port", net_port)
	config.set_value(AUDIO_SECTION, "master_volume", master_volume)
	config.set_value(AUDIO_SECTION, "sfx_volume", sfx_volume)
	config.set_value(AUDIO_SECTION, "music_volume", music_volume)
	return config.save(SETTINGS_PATH) == OK


static func apply(window: Window) -> void:
	UiScale.override_factor = ui_scale
	apply_audio()
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
			var screen: int = DisplayServer.window_get_current_screen(window_id)
			var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
			var target: Vector2i = fitted_resolution(resolution, usable.size)
			if DisplayServer.window_get_size(window_id) != target:
				DisplayServer.window_set_size(target, window_id)
				DisplayServer.window_set_position(usable.position + (usable.size - target) / 2, window_id)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED, window_id)
	UiScale.apply(window)


static func apply_audio() -> void:
	var volumes: Dictionary = {"master": master_volume, "sfx": sfx_volume, "music": music_volume}
	for key in AUDIO_BUSES:
		var index: int = AudioServer.get_bus_index(String(AUDIO_BUSES[key]))
		if index < 0:
			continue
		var linear: float = clampf(float(volumes[key]), 0.0, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.0001)


static func volume_label(value: float) -> String:
	return "%d%%" % int(round(clampf(value, 0.0, 1.0) * 100.0))


static func fitted_resolution(wanted: Vector2i, usable: Vector2i) -> Vector2i:
	if usable.x <= 0 or usable.y <= 0:
		return wanted
	return Vector2i(mini(wanted.x, usable.x), mini(wanted.y, usable.y))


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
	var shown: float = value * 2.0
	if is_equal_approx(shown, roundf(shown)):
		return "%dx" % int(roundf(shown))
	return "%sx" % ("%.1f" % shown)

