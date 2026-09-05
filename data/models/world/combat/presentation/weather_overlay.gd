class_name WeatherOverlay
extends CanvasLayer

const RAIN_SHEET: String = "res://assets/visuals/raw_asset/Particle/Rain.None.png"
const HAIL_SHEET: String = "res://assets/visuals/raw_asset/Particle/Hail.None.png"
const SANDSTORM_SHEET: String = "res://assets/visuals/raw_asset/BG/Sandstorm.1.png"
const CLOUDS_SHEET: String = "res://assets/visuals/raw_asset/BG/Clouds_Overhead.1.png"
const PERSISTENT_SECONDS: float = 1.0e9
const PIXEL_SCALE: float = 3.0
const SOURCE_SCREEN_AREA: float = 256.0 * 192.0

var weather_id: String = ""
var _field: WeatherField = null
var _tint: ColorRect = null
var _sheet_overlay: Control = null


func _init() -> void:
	name = "WeatherOverlay"
	layer = -1


func _ready() -> void:
	_tint = ColorRect.new()
	_tint.name = "WeatherTint"
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.visible = false
	add_child(_tint)
	_field = WeatherField.new()
	_field.name = "WeatherField"
	add_child(_field)
	_field.visible = false


func set_weather(next_id: String) -> void:
	weather_id = BattleWeatherService.normalize(next_id)
	_tint.visible = false
	_tint.material = null
	_field.visible = false
	_field.stop()
	if _sheet_overlay != null and is_instance_valid(_sheet_overlay):
		_sheet_overlay.queue_free()
	_sheet_overlay = null
	match weather_id:
		"rain", "primordial_sea":
			_field.start(load(RAIN_SHEET) as Texture2D, 5, 1, 360.0, 120.0, 2, 3)
			_field.visible = true
			if weather_id == "primordial_sea":
				_tint.color = Color(0.10, 0.18, 0.40, 0.22)
				_tint.visible = true
		"hail":
			_field.start(load(HAIL_SHEET) as Texture2D, 4, 2, 240.0, 120.0, 2, 5)
			_field.visible = true
		"sunny", "desolate_land":
			var material := CanvasItemMaterial.new()
			material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			_tint.material = material
			_tint.color = Color(0.22, 0.17, 0.06, 1.0) if weather_id == "sunny" else Color(0.34, 0.16, 0.04, 1.0)
			_tint.visible = true
		"sandstorm":
			_tint.color = Color(0.76, 0.62, 0.32, 0.11)
			_tint.visible = true
			_sheet_overlay = _start_sheet(SANDSTORM_SHEET, Vector2(-420.0, 30.0), Color(1.0, 0.92, 0.7, 0.28))
		"delta_stream":
			_sheet_overlay = _start_sheet(CLOUDS_SHEET, Vector2(-160.0, 0.0), Color(1.0, 1.0, 1.0, 0.35))


func _start_sheet(path: String, movement: Vector2, tint: Color) -> Control:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return null
	var overlay := BattleVFXPlayer.ScreenOverlay.new()
	overlay.name = "WeatherSheet"
	overlay.sheet = texture
	overlay.cell = Vector2(texture.get_size())
	overlay.frames = 1
	overlay.movement = movement
	overlay.tint = tint
	overlay.total = PERSISTENT_SECONDS
	add_child(overlay)
	return overlay


class WeatherField:
	extends Node2D

	var sheet: Texture2D = null
	var frame_count: int = 1
	var falling_frames: int = 1
	var fall_speed: float = 360.0
	var drift_speed: float = 120.0
	var particles_per_burst: int = 2
	var burst_frames: int = 3
	var drops: Array[Dictionary] = []
	var active: bool = false
	var _burst_accumulator: float = 0.0
	var _rng := RandomNumberGenerator.new()

	func start(next_sheet: Texture2D, frames: int, falling: int, speed: float, drift: float, per_burst: int, burst_every: int) -> void:
		sheet = next_sheet
		frame_count = maxi(1, frames)
		falling_frames = clampi(falling, 1, frame_count)
		fall_speed = speed * PIXEL_SCALE
		drift_speed = drift * PIXEL_SCALE
		particles_per_burst = per_burst
		burst_frames = maxi(1, burst_every)
		drops.clear()
		_rng.seed = 7
		active = sheet != null

	func stop() -> void:
		active = false
		drops.clear()
		queue_redraw()

	func _process(delta: float) -> void:
		if not active or sheet == null:
			return
		var size: Vector2 = get_viewport_rect().size
		var density: float = (size.x * size.y) / (SOURCE_SCREEN_AREA * PIXEL_SCALE * PIXEL_SCALE)
		_burst_accumulator += delta * 60.0 * density
		while _burst_accumulator >= float(burst_frames):
			_burst_accumulator -= float(burst_frames)
			for i in range(particles_per_burst):
				var land := Vector2(_rng.randf_range(0.0, size.x), _rng.randf_range(0.0, size.y * 2.0))
				drops.append({"land": land, "height": land.y, "t": 0.0, "fall_time": maxf(0.05, land.y / fall_speed), "done": false})
		var cell: float = float(sheet.get_height())
		var splash_time: float = 0.05 * float(maxi(1, frame_count - falling_frames))
		var keep: Array[Dictionary] = []
		for drop in drops:
			drop["t"] = float(drop["t"]) + delta
			var t: float = float(drop["t"])
			var fall_time: float = float(drop["fall_time"])
			if t < fall_time + splash_time + 0.05:
				keep.append(drop)
		drops = keep
		queue_redraw()

	func _draw() -> void:
		if not active or sheet == null:
			return
		var cell: float = float(sheet.get_height())
		var size: Vector2 = get_viewport_rect().size
		var splash_frames: int = maxi(1, frame_count - falling_frames)
		for drop in drops:
			var t: float = float(drop["t"])
			var fall_time: float = float(drop["fall_time"])
			var land: Vector2 = drop["land"]
			var frame: int = 0
			var pos: Vector2
			if t < fall_time:
				frame = int(floor(t * 20.0)) % falling_frames
				pos = Vector2(land.x + drift_speed * t, land.y - float(drop["height"]) + fall_speed * t)
			else:
				frame = falling_frames + mini(splash_frames - 1, int(floor((t - fall_time) / 0.05)))
				pos = Vector2(land.x + drift_speed * fall_time, land.y)
			if pos.y > size.y + cell * PIXEL_SCALE or pos.x < -cell * PIXEL_SCALE:
				continue
			var src := Rect2(float(frame) * cell, 0.0, cell, cell)
			draw_texture_rect_region(sheet, Rect2(pos - Vector2(cell, cell) * PIXEL_SCALE * 0.5, Vector2(cell, cell) * PIXEL_SCALE), src)
