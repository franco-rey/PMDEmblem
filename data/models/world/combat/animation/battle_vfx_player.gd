class_name BattleVFXPlayer
extends Node3D

const TILE_PX: float = 24.0
const PIXEL_SIZE: float = 0.04
const SOURCE_FPS: float = 60.0
const DEFAULT_LIFETIME: float = 0.6
const MAX_PARTICLES_PER_EMITTER: int = 24
const LAYER_HEIGHTS: Dictionary = {-1: -0.02, 0: 0.0, 1: 0.01, 2: 0.02, 3: 0.03, 4: 0.04}
const OVERLAY_CANVAS_LAYER: int = 10
const OVERLAY_PIXEL_SCALE: float = 3.0
const GROUND_OVERLAY_SIZE: float = 24.0
const GROUND_OVERLAY_MAX_PX: int = 1024
const GROUND_OVERLAY_DEPTH: float = 24.0
const SHAKE_SCALE: float = 0.5
const COLUMN_HEIGHT: float = 4.0
const AFTER_IMAGE_MAX: int = 12
const ORBIT_RADIUS: float = 0.6
const EFFECT_RENDER_LAYER: int = 2
const FLOOR_DECAL_CULL_MASK: int = 1
const SOLID_OVERLAY_SIZE: float = 64.0
const DIR8_ORDER: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
]

var battle_log: BattleLog = null
var visual_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var spawned_total: int = 0
var _rotated_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _tiled_cache: Dictionary = {}
var _overlay_canvas: CanvasLayer = null
var _spawners: Array[Dictionary] = []
var _cue_delay: float = 0.0
var _shake_remaining: float = 0.0
var _shake_total: float = 0.0
var _shake_amplitude: float = 0.0


class VFXSprite extends Sprite3D:
	var frames_total: int = 1
	var start_frame: int = 0
	var end_frame: int = 0
	var frame_time: float = 1.0
	var lifetime: float = DEFAULT_LIFETIME
	var elapsed: float = 0.0
	var columns: int = 1
	var row: int = 0
	var velocity: Vector3 = Vector3.ZERO
	var attach_target: Node3D = null
	var attach_offset: Vector3 = Vector3.ZERO
	var converge_to: Vector3 = Vector3.ZERO
	var converge: bool = false
	var frame_textures: Array = []
	var travel_from: Vector3 = Vector3.ZERO
	var travel_to: Vector3 = Vector3.ZERO
	var travel_seconds: float = 0.0
	var traveling: bool = false
	var arc_height: float = 0.0
	var delay: float = 0.0
	var travel_start: float = 0.0
	var orbiting: bool = false
	var orbit_center: Vector3 = Vector3.ZERO
	var orbit_radius: float = 0.0
	var orbit_axis_ratio: float = 1.0
	var orbit_period: float = 1.0
	var orbit_phase: float = 0.0
	var orbit_height: float = 0.0
	var orbit_rise: float = 0.0
	var orbit_height_limit: float = 0.0
	var on_finished: Callable = Callable()

	func _process(delta: float) -> void:
		if delay > 0.0:
			delay -= delta
			visible = false
			return
		visible = true
		elapsed += delta
		if traveling and travel_seconds > 0.0:
			var t: float = clampf((elapsed - travel_start) / travel_seconds, 0.0, 1.0)
			global_position = travel_from.lerp(travel_to, t) + Vector3.UP * (arc_height * 4.0 * t * (1.0 - t))
		elif orbiting:
			var angle: float = orbit_phase + elapsed * TAU / maxf(orbit_period, 0.05)
			var height: float = orbit_height + orbit_rise * elapsed
			if orbit_rise > 0.0:
				height = minf(height, orbit_height_limit)
			elif orbit_rise < 0.0:
				height = maxf(height, orbit_height_limit)
			global_position = orbit_center + Vector3(cos(angle) * orbit_radius, height, sin(angle) * orbit_radius * orbit_axis_ratio)
		elif converge and lifetime > 0.0:
			var t: float = clampf(elapsed / lifetime, 0.0, 1.0)
			global_position = global_position.lerp(converge_to, t * 0.35)
		elif velocity.length_squared() > 0.0:
			global_position += velocity * delta
		if attach_target != null and is_instance_valid(attach_target):
			global_position = attach_target.global_position + attach_offset
		_update_frame()
		if elapsed >= lifetime:
			finish()

	func finish() -> void:
		if on_finished.is_valid():
			on_finished.call(self)
			on_finished = Callable()
		queue_free()

	func _update_frame() -> void:
		var span: int = maxi(1, end_frame - start_frame + 1)
		var index: int = start_frame + (int(floor(elapsed * SOURCE_FPS / maxf(frame_time, 0.001))) % span)
		index = clampi(index, 0, maxi(0, frames_total - 1))
		if not frame_textures.is_empty():
			var tex: Variant = frame_textures[clampi(index, 0, frame_textures.size() - 1)]
			if tex is Texture2D and texture != tex:
				texture = tex
			return
		frame = row * columns + (index % maxi(1, columns))


class GhostSprite extends Sprite3D:
	var lifetime: float = 0.2
	var elapsed: float = 0.0
	var base_alpha: float = 0.5

	func _process(delta: float) -> void:
		elapsed += delta
		modulate.a = base_alpha * clampf(1.0 - elapsed / maxf(lifetime, 0.01), 0.0, 1.0)
		if elapsed >= lifetime:
			queue_free()


class ScreenOverlay extends Control:
	var sheet: Texture2D = null
	var cell: Vector2 = Vector2(24.0, 24.0)
	var frames: int = 1
	var frame_time: float = 3.0
	var movement: Vector2 = Vector2.ZERO
	var repeat_x: bool = true
	var repeat_y: bool = true
	var tint: Color = Color.WHITE
	var fade_in: float = 0.0
	var fade_out: float = 0.0
	var total: float = 1.0
	var elapsed: float = 0.0
	var scroll: Vector2 = Vector2.ZERO
	var solid: bool = false

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		elapsed += delta
		scroll += movement * delta
		queue_redraw()
		if elapsed >= total:
			queue_free()

	func alpha_factor() -> float:
		var factor: float = 1.0
		if fade_in > 0.0:
			factor = minf(factor, clampf(elapsed / fade_in, 0.0, 1.0))
		if fade_out > 0.0:
			factor = minf(factor, clampf((total - elapsed) / fade_out, 0.0, 1.0))
		return factor

	func _draw() -> void:
		var color: Color = Color(tint.r, tint.g, tint.b, tint.a * alpha_factor())
		var rect_size: Vector2 = size
		if solid or sheet == null:
			draw_rect(Rect2(Vector2.ZERO, rect_size), color)
			return
		var frame: int = int(floor(elapsed * SOURCE_FPS / maxf(frame_time, 1.0))) % maxi(1, frames)
		var region := Rect2(float(frame) * cell.x, 0.0, cell.x, cell.y)
		var draw_size: Vector2 = cell * OVERLAY_PIXEL_SCALE
		var columns: int = int(ceil(rect_size.x / draw_size.x)) + 2 if repeat_x else 1
		var rows: int = int(ceil(rect_size.y / draw_size.y)) + 2 if repeat_y else 1
		var start := Vector2.ZERO
		if repeat_x:
			start.x = fposmod(scroll.x, draw_size.x) - draw_size.x
		else:
			start.x = (rect_size.x - draw_size.x) * 0.5 + scroll.x
		if repeat_y:
			start.y = fposmod(scroll.y, draw_size.y) - draw_size.y
		else:
			start.y = (rect_size.y - draw_size.y) * 0.5 + scroll.y
		for row in range(rows):
			for column in range(columns):
				draw_texture_rect_region(sheet, Rect2(start + Vector2(float(column) * draw_size.x, float(row) * draw_size.y), draw_size), region, color)


class GroundOverlay extends Decal:
	var frame_textures: Array = []
	var frame_time: float = 3.0
	var movement: Vector3 = Vector3.ZERO
	var cell_units: float = 1.0
	var tint: Color = Color.WHITE
	var fade_in: float = 0.0
	var fade_out: float = 0.0
	var total: float = 1.0
	var elapsed: float = 0.0
	var base_position: Vector3 = Vector3.ZERO
	var scroll: Vector3 = Vector3.ZERO

	func _process(delta: float) -> void:
		elapsed += delta
		scroll += movement * delta
		var wrapped := Vector3(fposmod(scroll.x, cell_units), 0.0, fposmod(scroll.z, cell_units))
		global_position = base_position + wrapped
		if frame_textures.size() > 1:
			var frame: int = int(floor(elapsed * SOURCE_FPS / maxf(frame_time, 1.0))) % frame_textures.size()
			var tex: Variant = frame_textures[frame]
			if tex is Texture2D and texture_albedo != tex:
				texture_albedo = tex
		var factor: float = 1.0
		if fade_in > 0.0:
			factor = minf(factor, clampf(elapsed / fade_in, 0.0, 1.0))
		if fade_out > 0.0:
			factor = minf(factor, clampf((total - elapsed) / fade_out, 0.0, 1.0))
		modulate = Color(tint.r, tint.g, tint.b, tint.a * factor)
		if elapsed >= total:
			queue_free()


func setup(seed_value: int, log: BattleLog) -> void:
	visual_rng.seed = seed_value ^ 0x5EEDF00D
	battle_log = log


func _process(delta: float) -> void:
	_process_spawners(delta)
	_process_shake(delta)


func active_count() -> int:
	var count: int = 0
	for child in get_children():
		if child is VFXSprite:
			count += 1
	return count


func play_cue(cue: Dictionary) -> float:
	var shake: Variant = cue.get("shake", null)
	if shake is Dictionary:
		_start_shake(shake, String(cue.get("label", "")))
		return 0.0
	_cue_delay = maxf(float(cue.get("delay", 0.0)), 0.0)
	var seconds: float = _play_cue_body(cue)
	_cue_delay = 0.0
	return seconds


func _play_cue_body(cue: Dictionary) -> float:
	var assets: Dictionary = cue.get("assets", {})
	var origin: Vector3 = cue.get("origin", global_position)
	var dest: Vector3 = cue.get("dest", origin)
	var direction: Vector3 = cue.get("dir", Vector3.ZERO)
	var attach: Node3D = cue.get("attach", null) as Node3D
	var range_tiles: int = int(cue.get("range_tiles", 0))
	var emitter: Variant = cue.get("emitter", null)
	if emitter is Dictionary and not (emitter as Dictionary).is_empty():
		return play_emitter(emitter, assets, origin, dest, direction, attach, range_tiles, float(cue.get("duration", 0.0)), String(cue.get("label", "")))
	var anim: Variant = cue.get("anim", null)
	if anim is Dictionary and not String((anim as Dictionary).get("index", "")).is_empty():
		var sprite: VFXSprite = spawn_static(_asset_for(assets, String((anim as Dictionary)["index"])), anim, origin, direction, int(cue.get("cycles", 1)), int(cue.get("total_time", 0)), int(cue.get("loc_height", 0)), int(cue.get("layer", 2)), String(cue.get("label", "")))
		return sprite.lifetime if sprite != null else 0.0
	return 0.0


func play_emitter(emitter: Dictionary, assets: Dictionary, origin: Vector3, dest: Vector3, direction: Vector3, attach: Node3D, range_tiles: int, duration: float, label: String) -> float:
	var type_name: String = String(emitter.get("type", ""))
	var anims: Array = _emitter_anims(emitter)
	var layer: int = int(emitter.get("layer", 2))
	var loc_height: int = int(emitter.get("loc_height", 0))
	var lifetime: float = 0.0
	match type_name:
		"EmptyFiniteEmitter", "EmptyCircleSquareEmitter", "EmptyAttachEmitter", "EmptyShootEmitter", "":
			return 0.0
		"SingleEmitter":
			var use_dest: bool = bool(emitter.get("use_dest", false))
			var offset_px: float = float(emitter.get("offset", 0))
			var base: Vector3 = dest if use_dest else origin
			var pos: Vector3 = base + _flat(direction) * (offset_px / TILE_PX)
			for anim in anims:
				lifetime = maxf(lifetime, _spawn_anim_record(anim, assets, pos, direction, loc_height, layer, label))
		"BetweenEmitter":
			var offset_px: float = float(emitter.get("offset", 0))
			var center: Vector3 = origin + _flat(direction) * (offset_px / TILE_PX)
			for key in ["anim_back", "anim_front"]:
				var raw: Variant = emitter.get(key, null)
				if raw is Dictionary:
					var height: int = int(emitter.get("height_back" if key == "anim_back" else "height_front", 0))
					lifetime = maxf(lifetime, _spawn_anim_record(raw, assets, center, direction, height, layer + (1 if key == "anim_front" else -1), label))
		"CircleSquareAreaEmitter", "StaticAreaEmitter":
			var radius: float = float(maxi(range_tiles, int(emitter.get("range", 0)) / int(TILE_PX)))
			var particles_per_tile: float = float(emitter.get("particles_per_tile", 0.0))
			var count: int = int(emitter.get("particles_per_burst", 0)) * maxi(1, int(emitter.get("bursts", 1)))
			if particles_per_tile > 0.0:
				count = maxi(1, int(round(particles_per_tile * PI * maxf(radius, 0.5) * maxf(radius, 0.5))))
			count = clampi(maxi(count, 1), 1, MAX_PARTICLES_PER_EMITTER)
			for i in range(count):
				var pos: Vector3 = origin + _random_in_disc(radius)
				var record: Dictionary = anims[visual_rng.randi_range(0, anims.size() - 1)] if not anims.is_empty() else {}
				if record.is_empty():
					break
				var sprite_life: float = _spawn_anim_record(record, assets, pos, direction, loc_height, layer, label, visual_rng.randf_range(0.0, 0.18))
				lifetime = maxf(lifetime, sprite_life)
		"AttachAreaEmitter":
			var per_burst: int = maxi(1, int(emitter.get("particles_per_burst", 1)))
			var burst_time: float = maxf(1.0, float(emitter.get("burst_time", 5))) / SOURCE_FPS
			var window: float = maxf(duration, burst_time)
			var bursts: int = clampi(int(ceil(window / burst_time)), 1, 12)
			var radius: float = float(int(emitter.get("range", 0))) / TILE_PX
			for b in range(bursts):
				for i in range(per_burst):
					var record: Dictionary = anims[visual_rng.randi_range(0, anims.size() - 1)] if not anims.is_empty() else {}
					if record.is_empty():
						break
					var sprite: VFXSprite = _spawn_anim_sprite(record, assets, origin + _random_in_disc(maxf(radius, 0.25)), direction, loc_height + int(emitter.get("add_height", 0)), layer, label, float(b) * burst_time)
					if sprite != null and attach != null:
						sprite.attach_target = attach
						sprite.attach_offset = _random_in_disc(maxf(radius, 0.25)) + Vector3.UP * (float(loc_height) / TILE_PX)
						lifetime = maxf(lifetime, sprite.delay + sprite.lifetime)
		"FiniteReleaseEmitter", "FiniteReleaseRangeEmitter", "CircleSquareReleaseEmitter", "AttachReleaseRangeEmitter":
			var default_bursts: int = 1
			if type_name == "AttachReleaseRangeEmitter":
				default_bursts = int(ceil(maxf(duration, 0.3) * SOURCE_FPS / maxf(1.0, float(emitter.get("burst_time", 3)))))
			var bursts: int = clampi(maxi(1, int(emitter.get("bursts", default_bursts))), 1, 8)
			var per_burst: int = clampi(maxi(1, int(emitter.get("particles_per_burst", 1))), 1, 6)
			var burst_time: float = maxf(1.0, float(emitter.get("burst_time", 1))) / SOURCE_FPS
			var speed_px: float = float(emitter.get("speed", 0))
			var start_distance: float = float(emitter.get("start_distance", 0)) / TILE_PX
			for b in range(bursts):
				for i in range(per_burst):
					var record: Dictionary = anims[visual_rng.randi_range(0, anims.size() - 1)] if not anims.is_empty() else {}
					if record.is_empty():
						break
					var angle: float = visual_rng.randf_range(0.0, TAU)
					var out_dir: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
					if (type_name == "FiniteReleaseRangeEmitter" or type_name == "AttachReleaseRangeEmitter") and direction.length() > 0.001:
						out_dir = _flat(direction).rotated(Vector3.UP, visual_rng.randf_range(-0.6, 0.6))
					var sprite: VFXSprite = _spawn_anim_sprite(record, assets, origin + out_dir * visual_rng.randf_range(0.0, maxf(start_distance, 0.01)), out_dir, loc_height, layer, label, float(b) * burst_time)
					if sprite != null:
						sprite.velocity = out_dir * (speed_px / TILE_PX)
						lifetime = maxf(lifetime, sprite.delay + sprite.lifetime)
		"CircleSquareSprinkleEmitter":
			var radius: float = float(maxi(range_tiles, 1))
			var particles_per_tile: float = float(emitter.get("particles_per_tile", 1.0))
			var count: int = clampi(maxi(1, int(round(particles_per_tile * PI * radius * radius))), 1, MAX_PARTICLES_PER_EMITTER)
			var start_height: float = float(emitter.get("start_height", 24)) / TILE_PX
			var height_speed: float = maxf(4.0, float(emitter.get("height_speed", 8))) / TILE_PX
			for i in range(count):
				var record: Dictionary = anims[visual_rng.randi_range(0, anims.size() - 1)] if not anims.is_empty() else {}
				if record.is_empty():
					break
				var sprite: VFXSprite = _spawn_anim_sprite(record, assets, origin + _random_in_disc(radius) + Vector3.UP * start_height, direction, loc_height, layer, label, visual_rng.randf_range(0.0, 0.3))
				if sprite != null:
					sprite.velocity = Vector3.DOWN * height_speed * 6.0
					lifetime = maxf(lifetime, sprite.delay + sprite.lifetime)
		"SqueezedAreaEmitter":
			var bursts: int = clampi(maxi(1, int(emitter.get("bursts", 1))), 1, 8)
			var per_burst: int = clampi(maxi(1, int(emitter.get("particles_per_burst", 1))), 1, 6)
			var burst_time: float = maxf(1.0, float(emitter.get("burst_time", 1))) / SOURCE_FPS
			var radius: float = float(emitter.get("range", 16)) / TILE_PX
			for b in range(bursts):
				for i in range(per_burst):
					var record: Dictionary = anims[visual_rng.randi_range(0, anims.size() - 1)] if not anims.is_empty() else {}
					if record.is_empty():
						break
					var sprite: VFXSprite = _spawn_anim_sprite(record, assets, origin + _random_in_disc(maxf(radius, 0.3)), direction, loc_height + int(emitter.get("start_height", 0)), layer, label, float(b) * burst_time)
					if sprite != null:
						sprite.converge = true
						sprite.converge_to = origin + Vector3.UP * (float(loc_height) / TILE_PX)
						lifetime = maxf(lifetime, sprite.delay + sprite.lifetime)
		"StreamEmitter":
			var shots: int = clampi(maxi(1, int(emitter.get("shots", 1))), 1, 24)
			var burst_time: float = maxf(1.0, float(emitter.get("burst_time", 1))) / SOURCE_FPS
			var start_distance: float = float(emitter.get("start_distance", 0)) / TILE_PX
			var end_diff: float = float(emitter.get("end_diff", 0)) / TILE_PX
			var stream_range: float = float(maxi(int(emitter.get("range", 0)) / int(TILE_PX), maxi(range_tiles, 1)))
			var speed_tiles: float = float(emitter.get("speed", 0)) / TILE_PX
			var flat_dir: Vector3 = _flat(direction)
			for shot in range(shots):
				var record: Dictionary = anims[shot % anims.size()] if not anims.is_empty() else {}
				if record.is_empty():
					break
				var travel: float = maxf(stream_range - start_distance, 0.25)
				var total_time: float = travel / speed_tiles if speed_tiles > 0.0 else 0.4
				var end_delta: Vector3 = _random_in_disc(end_diff) if end_diff > 0.0 else Vector3.ZERO
				var start: Vector3 = origin + flat_dir * start_distance
				var sprite: VFXSprite = _spawn_anim_sprite(record, assets, start, direction, loc_height, layer, label, float(shot) * burst_time)
				if sprite != null:
					sprite.velocity = (flat_dir * travel + end_delta) / maxf(total_time, 0.05)
					sprite.lifetime = minf(sprite.lifetime, total_time) if sprite.lifetime > 0.0 else total_time
					lifetime = maxf(lifetime, sprite.delay + sprite.lifetime)
		"ClampEmitter":
			var half_height: float = float(emitter.get("half_height", 0)) / TILE_PX
			var half_offset: Dictionary = emitter.get("half_offset", {}) if emitter.get("half_offset", null) is Dictionary else {}
			var side_offset: float = float(half_offset.get("x", 0)) / TILE_PX
			var up_offset: float = float(half_offset.get("y", 0)) / TILE_PX
			var flat_dir: Vector3 = _flat(direction)
			var side: Vector3 = Vector3(flat_dir.z, 0.0, -flat_dir.x) if flat_dir.length() > 0.001 else Vector3.RIGHT
			var center: Vector3 = origin + Vector3.UP * (float(loc_height) / TILE_PX)
			var halves: Array = anims if anims.size() >= 2 else [anims[0], anims[0]] if not anims.is_empty() else []
			for i in range(halves.size()):
				var sign: float = 1.0 if i % 2 == 0 else -1.0
				var pos: Vector3 = center + side * (side_offset * sign) + Vector3.UP * ((half_height + up_offset) * sign)
				var sprite: VFXSprite = _spawn_anim_sprite(halves[i], assets, pos, direction, 0, layer, label, 0.0)
				if sprite != null:
					sprite.converge = true
					sprite.converge_to = center
					lifetime = maxf(lifetime, sprite.lifetime)
		"FiniteOverlayEmitter":
			lifetime = _play_overlay(emitter, assets, origin, label)
		"MoveToEmitter":
			lifetime = _play_move_to(emitter, assets, origin, direction, layer, label)
		"FiniteGatherEmitter":
			var center: Vector3 = dest if bool(emitter.get("use_dest", false)) else origin
			var bursts: int = clampi(maxi(1, int(emitter.get("bursts", 1))), 1, 8)
			var per_burst: int = clampi(maxi(1, int(emitter.get("particles_per_burst", 1))), 1, 8)
			var burst_time: float = maxf(0.0, float(emitter.get("burst_time", 0))) / SOURCE_FPS
			var travel: float = maxf(float(emitter.get("travel_time", 30)), 1.0) / SOURCE_FPS
			var start_distance: float = float(emitter.get("start_distance", 0)) / TILE_PX
			var variance: float = float(emitter.get("start_variance", 0)) / TILE_PX
			var end_distance: float = float(emitter.get("end_distance", 0)) / TILE_PX
			if start_distance <= 0.0:
				start_distance = 1.0
			for b in range(bursts):
				for i in range(per_burst):
					var record: Dictionary = anims[visual_rng.randi_range(0, anims.size() - 1)] if not anims.is_empty() else {}
					if record.is_empty():
						break
					var angle: float = visual_rng.randf_range(0.0, TAU)
					var out_dir := Vector3(cos(angle), 0.0, sin(angle))
					var from: Vector3 = center + out_dir * maxf(start_distance + visual_rng.randf_range(-variance, variance), 0.05)
					var sprite: VFXSprite = _spawn_anim_sprite(record, assets, from, direction, loc_height, layer, label, float(b) * burst_time)
					if sprite != null:
						_set_travel(sprite, from, center + out_dir * end_distance, travel, 0.0)
						sprite.lifetime = travel
						lifetime = maxf(lifetime, sprite.delay + sprite.lifetime)
		"RepeatEmitter":
			var bursts: int = clampi(maxi(1, int(emitter.get("bursts", 1))), 1, 12)
			var burst_time: float = maxf(1.0, float(emitter.get("burst_time", 1))) / SOURCE_FPS
			var pos: Vector3 = origin + _flat(direction) * (float(emitter.get("offset", 0)) / TILE_PX)
			for b in range(bursts):
				for anim in anims:
					lifetime = maxf(lifetime, _spawn_anim_record(anim, assets, pos, direction, loc_height, layer, label, float(b) * burst_time))
		"AfterImageEmitter":
			lifetime = _play_after_images(emitter, attach, duration, label)
		"FiniteAreaEmitter":
			var total: int = clampi(maxi(1, int(emitter.get("total_particles", 1))), 1, MAX_PARTICLES_PER_EMITTER)
			var radius: float = maxf(float(emitter.get("range", 0)) / TILE_PX, float(range_tiles))
			var speed_px: float = maxf(float(emitter.get("speed", 0)), 1.0)
			var expand: float = clampf(radius * TILE_PX / speed_px, 0.0, 1.5)
			for i in range(total):
				var record: Dictionary = anims[visual_rng.randi_range(0, anims.size() - 1)] if not anims.is_empty() else {}
				if record.is_empty():
					break
				var frac: float = float(i) / float(total)
				lifetime = maxf(lifetime, _spawn_anim_record(record, assets, origin + _random_in_disc(radius * maxf(frac, 0.25)), direction, loc_height, layer, label, frac * expand))
		"FiniteSprinkleEmitter":
			var total: int = clampi(maxi(1, int(emitter.get("total_particles", 1))), 1, MAX_PARTICLES_PER_EMITTER)
			var radius: float = maxf(float(emitter.get("range", 0)) / TILE_PX, float(range_tiles))
			var start_height: int = int(emitter.get("start_height", 0))
			var height_speed: float = float(emitter.get("height_speed", 0)) / TILE_PX
			var speed_px: float = float(emitter.get("speed", 0))
			var speed_diff: float = float(emitter.get("speed_diff", 0))
			for i in range(total):
				var record: Dictionary = anims[i % anims.size()] if not anims.is_empty() else {}
				if record.is_empty():
					break
				var angle: float = visual_rng.randf_range(0.0, TAU)
				var out_dir := Vector3(cos(angle), 0.0, sin(angle))
				var sprite: VFXSprite = _spawn_anim_sprite(record, assets, origin + _random_in_disc(radius), direction, loc_height + start_height, layer, label, visual_rng.randf_range(0.0, 0.15))
				if sprite != null:
					sprite.velocity = out_dir * ((speed_px + visual_rng.randf_range(0.0, speed_diff)) / TILE_PX) + Vector3.UP * height_speed
					lifetime = maxf(lifetime, sprite.delay + sprite.lifetime)
		"CircleSquareFountainEmitter":
			var bursts: int = clampi(maxi(1, int(emitter.get("bursts", 1))), 1, 8)
			var per_burst: int = clampi(maxi(1, int(emitter.get("particles_per_burst", 1))), 1, 6)
			var burst_time: float = maxf(1.0, float(emitter.get("burst_time", 1))) / SOURCE_FPS
			var radius: float = float(maxi(range_tiles, 1)) + float(emitter.get("range_diff", 0)) / TILE_PX
			var height_ratio: float = float(emitter.get("height_ratio", 0.5))
			var start_distance: float = float(emitter.get("start_distance", 0)) / TILE_PX
			for b in range(bursts):
				for i in range(per_burst):
					var record: Dictionary = anims[visual_rng.randi_range(0, anims.size() - 1)] if not anims.is_empty() else {}
					if record.is_empty():
						break
					var landing: Vector3 = origin + _random_in_disc(radius)
					var toward: Vector3 = _flat(landing - origin)
					var start: Vector3 = origin + toward * start_distance
					var sprite: VFXSprite = _spawn_anim_sprite(record, assets, start, direction, loc_height, layer, label, float(b) * burst_time)
					if sprite != null:
						var seconds: float = maxf(sprite.lifetime, 0.3)
						_set_travel(sprite, start, landing, seconds, 0.0)
						sprite.arc_height = (landing - start).length() * height_ratio + 0.3
						sprite.lifetime = seconds
						lifetime = maxf(lifetime, sprite.delay + sprite.lifetime)
		"MultiCircleSquareEmitter":
			for sub in emitter.get("emitters", []):
				if sub is Dictionary:
					lifetime = maxf(lifetime, play_emitter(sub, assets, origin, dest, direction, attach, range_tiles, duration, label))
		"ListEmitter":
			var base: Vector3 = dest if bool(emitter.get("use_dest", false)) else origin
			var pos: Vector3 = base + _flat(direction) * (float(emitter.get("offset", 0)) / TILE_PX)
			for anim in anims:
				lifetime = maxf(lifetime, _spawn_anim_record(anim, assets, pos, direction, loc_height, layer, label))
		"SwingSwitchEmitter":
			var amount: int = clampi(maxi(1, int(emitter.get("amount", 1))), 1, 6)
			var period: float = maxf(float(emitter.get("rotation_time", 20)), 1.0) / SOURCE_FPS
			var tail: float = maxf(float(emitter.get("stream_time", 0)), 0.0) / SOURCE_FPS
			for anim in anims:
				var sprite: VFXSprite = _spawn_anim_sprite(anim, assets, origin, direction, loc_height, layer, label, 0.0)
				if sprite != null:
					sprite.orbiting = true
					sprite.orbit_center = Vector3(origin.x, sprite.global_position.y, origin.z)
					sprite.orbit_radius = ORBIT_RADIUS
					sprite.orbit_axis_ratio = clampf(float(emitter.get("axis_ratio", 1.0)), 0.1, 1.0)
					sprite.orbit_period = period
					sprite.orbit_phase = visual_rng.randf_range(0.0, TAU)
					sprite.lifetime = float(amount) * period + tail
					lifetime = maxf(lifetime, sprite.lifetime)
		"VortexEmitter", "SpinEmitter":
			var bursts: int = clampi(maxi(1, int(emitter.get("bursts", 1))), 1, 8)
			var per_burst: int = clampi(maxi(1, int(emitter.get("particles_per_burst", anims.size()))), 1, 8)
			var burst_time: float = maxf(1.0, float(emitter.get("burst_time", 1))) / SOURCE_FPS
			var radius: float = maxf(float(emitter.get("range", 16)) / TILE_PX, 0.2)
			var start_height: float = float(emitter.get("start_height", 0)) / TILE_PX
			var end_height: float = float(emitter.get("end_height", 0)) / TILE_PX
			var height_speed: float = maxf(float(emitter.get("height_speed", 8)), 1.0) / TILE_PX
			var period: float = 360.0 / maxf(float(emitter.get("cycle_speed", 360)), 30.0)
			var rise_seconds: float = absf(end_height - start_height) / height_speed
			for b in range(bursts):
				for i in range(per_burst):
					var record: Dictionary = anims[i % anims.size()] if not anims.is_empty() else {}
					if record.is_empty():
						break
					var sprite: VFXSprite = _spawn_anim_sprite(record, assets, origin, direction, loc_height, layer, label, float(b) * burst_time)
					if sprite != null:
						sprite.orbiting = true
						sprite.orbit_center = origin + Vector3.UP * float(LAYER_HEIGHTS.get(layer, 0.02))
						sprite.orbit_radius = radius
						sprite.orbit_period = period
						sprite.orbit_phase = TAU * float(i) / float(per_burst) + visual_rng.randf_range(0.0, 0.5)
						sprite.orbit_height = start_height
						sprite.orbit_rise = height_speed * signf(end_height - start_height)
						sprite.orbit_height_limit = end_height
						sprite.lifetime = maxf(rise_seconds, sprite.lifetime)
						lifetime = maxf(lifetime, sprite.delay + sprite.lifetime)
		_:
			var pos: Vector3 = origin + Vector3.UP * (float(loc_height) / TILE_PX)
			for anim in anims:
				lifetime = maxf(lifetime, _spawn_anim_record(anim, assets, pos, direction, 0, layer, label))
			_append({"kind": "vfx_emitter_approximated", "emitter": type_name, "label": label})
	return lifetime


func play_projectile_cue(cue: Dictionary) -> float:
	var from: Vector3 = cue.get("from", global_position)
	var to: Vector3 = cue.get("to", from)
	var speed_tiles: float = maxf(float(cue.get("speed", 10.0)), 0.5)
	var direction: Vector3 = cue.get("dir", to - from)
	var distance: float = (to - from).length()
	var seconds: float = distance / speed_tiles
	var asset: Dictionary = cue.get("asset", {})
	var anim: Dictionary = cue.get("anim", {})
	var label: String = String(cue.get("label", ""))
	if asset.is_empty():
		_append({"kind": "vfx_projectile_skipped", "label": label, "reason": "missing_asset"})
		return seconds
	var sprite: VFXSprite = _spawn_anim_sprite({"type": "StaticAnim", "anim": anim, "cycles": 0, "total_time": 0}, {"_direct": asset}, from, direction, int(cue.get("loc_height", 8)), int(cue.get("layer", 2)), label, 0.0)
	if sprite == null:
		return seconds
	sprite.traveling = true
	sprite.travel_from = from + Vector3.UP * (float(cue.get("loc_height", 8)) / TILE_PX)
	sprite.travel_to = to + Vector3.UP * (float(cue.get("loc_height", 8)) / TILE_PX)
	sprite.travel_seconds = maxf(seconds, 0.01)
	sprite.arc_height = float(cue.get("arc_height", 0.0))
	sprite.lifetime = maxf(seconds, 0.01)
	_append({"kind": "vfx_projectile_spawned", "label": label, "seconds": seconds, "asset_path": String(asset.get("path", "")), "distance": distance})
	return seconds


func play_beam(asset: Dictionary, from: Vector3, to: Vector3, direction: Vector3, frame_time: int, seconds: float, label: String) -> float:
	var layout: Dictionary = asset.get("layout", {})
	var paths: Dictionary = asset.get("paths", {})
	var total_frames: int = maxi(1, int(layout.get("frames", 1)))
	var step: Vector3 = _flat(direction)
	if step.length() < 0.001:
		return 0.0
	var length: float = (to - from).length()
	var segments: int = maxi(1, int(round(length)))
	for i in range(segments + 1):
		var component: String = "body"
		if i == 0:
			component = "tail"
		elif i == segments:
			component = "head"
		var path: String = String(paths.get(component, ""))
		if path.is_empty():
			continue
		var tex: Texture2D = _load_texture(path)
		if tex == null:
			continue
		var sprite := VFXSprite.new()
		sprite.name = "Beam_%s_%d" % [label, i]
		sprite.layers = EFFECT_RENDER_LAYER
		sprite.texture = tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.pixel_size = PIXEL_SIZE
		sprite.hframes = total_frames
		sprite.vframes = 1
		sprite.columns = total_frames
		sprite.frames_total = total_frames
		sprite.start_frame = 0
		sprite.end_frame = total_frames - 1
		sprite.frame_time = float(maxi(1, frame_time))
		sprite.lifetime = maxf(seconds, 0.2)
		add_child(sprite)
		sprite.global_position = from + step * float(i) + Vector3.UP * 0.4
		spawned_total += 1
	_append({"kind": "vfx_beam_spawned", "label": label, "segments": segments + 1, "seconds": seconds})
	return seconds


func spawn_static(asset: Dictionary, anim: Dictionary, position_world: Vector3, direction: Vector3, cycles: int, total_time_frames: int, loc_height: int, layer: int, label: String) -> VFXSprite:
	return _spawn_anim_sprite({"type": "StaticAnim", "anim": anim, "cycles": cycles, "total_time": total_time_frames}, {"_direct": asset}, position_world, direction, loc_height, layer, label, 0.0)


func _spawn_anim_record(record: Dictionary, assets: Dictionary, position_world: Vector3, direction: Vector3, loc_height: int, layer: int, label: String, delay: float = 0.0) -> float:
	var record_type: String = String(record.get("type", ""))
	if record_type.ends_with("Emitter"):
		if record_type.begins_with("Empty"):
			return 0.0
		var previous_delay: float = _cue_delay
		_cue_delay += delay
		var nested: float = play_emitter(record, assets, position_world + Vector3.UP * (float(loc_height) / TILE_PX), position_world, direction, null, 0, 0.0, label)
		_cue_delay = previous_delay
		return delay + nested
	if record_type == "ColumnAnim":
		return _spawn_column(record, assets, position_world, direction, loc_height, layer, label, delay)
	var sprite: VFXSprite = _spawn_anim_sprite(record, assets, position_world, direction, loc_height, layer, label, delay)
	return sprite.delay + sprite.lifetime if sprite != null else 0.0


func _spawn_anim_sprite(record: Dictionary, assets: Dictionary, position_world: Vector3, direction: Vector3, loc_height: int, layer: int, label: String, delay: float) -> VFXSprite:
	var record_type: String = String(record.get("type", ""))
	if record_type.ends_with("Emitter") or record_type == "ColumnAnim":
		_spawn_anim_record(record, assets, position_world, direction, loc_height, layer, label, delay)
		return null
	var anim: Dictionary = record.get("anim", {}) if record.get("anim", null) is Dictionary else {}
	var unwrap_guard: int = 0
	while not anim.has("index") and anim.get("anim", null) is Dictionary and unwrap_guard < 4:
		if record.get("cycles", null) == null and anim.has("cycles"):
			record = anim
		anim = anim["anim"]
		unwrap_guard += 1
	if anim.is_empty() or not anim.has("index"):
		return null
	var index: String = String(anim.get("index", ""))
	if index.is_empty():
		return null
	var asset: Dictionary = assets.get("_direct", {}) if assets.has("_direct") else _asset_for(assets, index)
	if asset.is_empty():
		_append({"kind": "vfx_skipped", "label": label, "anim": index, "reason": "missing_asset"})
		return null
	var layout: Dictionary = asset.get("layout", {})
	var kind: String = String(layout.get("kind", "None"))
	var rotate: String = String(layout.get("rotate", "None"))
	var frames_total: int = maxi(1, int(layout.get("frames", 1)))
	var columns: int = frames_total
	var rows: int = maxi(1, int(layout.get("rows", 1)))
	var dir_index: int = _dir8_index(direction)
	var sprite := VFXSprite.new()
	sprite.name = "VFX_%s_%s" % [label, index]
	sprite.layers = EFFECT_RENDER_LAYER
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = PIXEL_SIZE
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.no_depth_test = layer >= 3
	match kind:
		"dir_frames":
			var base_dir: String = String(asset.get("path", ""))
			for frame_file in layout.get("frame_files", []):
				var tex: Texture2D = _load_texture("%s/%s" % [base_dir, String(frame_file)])
				if tex != null:
					sprite.frame_textures.append(tex)
			if sprite.frame_textures.is_empty():
				sprite.free()
				return null
			sprite.texture = sprite.frame_textures[0]
			columns = 1
			rows = 1
		"grid":
			columns = maxi(1, int(layout.get("columns", frames_total)))
			sprite.texture = _load_texture(String(asset.get("path", "")))
		"beam":
			sprite.texture = _load_texture(String((asset.get("paths", {}) as Dictionary).get("body", "")))
		_:
			var path: String = String(asset.get("path", ""))
			if rotate == "Dir1" or rotate == "Dir2":
				sprite.texture = _rotated_texture(path, layout, dir_index, rotate)
				rows = 1 if rotate == "Dir1" else 2
			else:
				sprite.texture = _load_texture(path)
	if sprite.texture == null:
		sprite.free()
		return null
	sprite.hframes = maxi(1, columns)
	sprite.vframes = maxi(1, rows)
	sprite.columns = maxi(1, columns)
	sprite.frames_total = frames_total
	var row: int = 0
	var flip: bool = int(anim.get("flip", 0)) != 0
	match rotate:
		"Dir8":
			row = dir_index
		"Dir5":
			var idx: int = dir_index
			if idx > 4:
				idx = 8 - idx
				flip = not flip
			row = idx
		"Dir2":
			row = dir_index % 2
		"Flip":
			if dir_index >= 4:
				flip = not flip
	sprite.row = clampi(row, 0, maxi(0, sprite.vframes - 1))
	sprite.flip_h = flip
	var start_frame: int = int(anim.get("start_frame", -1))
	var end_frame: int = int(anim.get("end_frame", -1))
	sprite.start_frame = clampi(start_frame if start_frame >= 0 else 0, 0, frames_total - 1)
	sprite.end_frame = clampi(end_frame if end_frame >= 0 else frames_total - 1, sprite.start_frame, frames_total - 1)
	sprite.frame_time = float(maxi(1, int(anim.get("frame_time", 1))))
	var span: int = sprite.end_frame - sprite.start_frame + 1
	var cycles: int = int(record.get("cycles", 1))
	var total_time: int = int(record.get("total_time", 0))
	if cycles > 0:
		sprite.lifetime = float(span) * sprite.frame_time * float(cycles) / SOURCE_FPS
	elif total_time > 0:
		sprite.lifetime = float(total_time) / SOURCE_FPS
	else:
		sprite.lifetime = float(span) * sprite.frame_time / SOURCE_FPS
	sprite.lifetime = clampf(sprite.lifetime, 0.05, 6.0)
	sprite.delay = maxf(delay + _cue_delay, 0.0)
	sprite.modulate.a = float(anim.get("alpha", 255)) / 255.0
	add_child(sprite)
	var column_lift: float = 0.0
	if kind == "beam":
		var body_cell: Array = ((layout.get("components", {}) as Dictionary).get("body", {}) as Dictionary).get("cell", [0, 0])
		column_lift = float(body_cell[1]) * PIXEL_SIZE * 0.5 if body_cell.size() >= 2 else 0.0
	sprite.global_position = position_world + Vector3.UP * (float(loc_height) / TILE_PX + float(LAYER_HEIGHTS.get(layer, 0.02)) + column_lift)
	sprite.frame = sprite.row * sprite.columns + sprite.start_frame
	var result: Variant = record.get("result_anim", null)
	if result is Dictionary and _result_playable(result as Dictionary):
		sprite.on_finished = _on_result_anim.bind(result, assets, direction, int(record.get("layer", layer)), label)
	spawned_total += 1
	_append({"kind": "vfx_spawned", "label": label, "anim": index, "asset_path": String(asset.get("path", "")), "lifetime": sprite.lifetime, "frames": span, "layout": kind, "rotate": rotate, "at": sprite.global_position})
	return sprite


func _emitter_anims(emitter: Dictionary) -> Array:
	var out: Array = []
	var anims: Variant = emitter.get("anims", null)
	if anims is Array:
		for record in anims:
			if not (record is Dictionary):
				continue
			var dict: Dictionary = record
			if dict.get("anim", null) is Dictionary:
				if not _anim_index(dict["anim"]).is_empty():
					out.append(dict)
			elif String(dict.get("type", "")).ends_with("Emitter"):
				if not String(dict.get("type", "")).begins_with("Empty"):
					out.append(dict)
			elif dict.has("index") and not String(dict.get("index", "")).is_empty():
				out.append({"type": "ParticleAnim", "anim": dict, "cycles": maxi(int(emitter.get("cycles", 1)), 0), "total_time": 0})
	for key in ["anim", "anim1", "anim2"]:
		var single: Variant = emitter.get(key, null)
		if single is Array:
			for record in (single as Array):
				if record is Dictionary and (record as Dictionary).get("anim", null) is Dictionary:
					out.append(record)
			continue
		if single is Dictionary:
			var dict: Dictionary = single
			if dict.get("anim", null) is Dictionary:
				if not _anim_index(dict["anim"]).is_empty():
					out.append(dict)
			elif dict.has("index") and not String(dict.get("index", "")).is_empty():
				out.append({"type": "StaticAnim", "anim": dict, "cycles": 1, "total_time": 0})
	return out


func _anim_index(anim: Dictionary) -> String:
	var current: Dictionary = anim
	var guard: int = 0
	while not current.has("index") and current.get("anim", null) is Dictionary and guard < 4:
		current = current["anim"]
		guard += 1
	return String(current.get("index", ""))


func _asset_for(assets: Dictionary, index: String) -> Dictionary:
	if index.is_empty():
		return {}
	for prefix in ["particle:", "beam:", "item:", "bg:"]:
		var record: Variant = assets.get(prefix + index, null)
		if record is Dictionary:
			return record
	return {}


func _set_travel(sprite: VFXSprite, spawn_position: Vector3, destination: Vector3, seconds: float, start_delay: float) -> void:
	var lift: Vector3 = sprite.global_position - spawn_position
	sprite.traveling = true
	sprite.travel_from = sprite.global_position
	sprite.travel_to = destination + lift
	sprite.travel_seconds = maxf(seconds, 0.01)
	sprite.travel_start = maxf(start_delay, 0.0)


func _result_playable(result: Dictionary) -> bool:
	var type_name: String = String(result.get("type", ""))
	if type_name.ends_with("Emitter"):
		return not type_name.begins_with("Empty")
	return result.get("anim", null) is Dictionary


func _on_result_anim(sprite: VFXSprite, result: Dictionary, assets: Dictionary, direction: Vector3, layer: int, label: String) -> void:
	var pos: Vector3 = sprite.global_position
	var type_name: String = String(result.get("type", ""))
	if type_name.ends_with("Emitter"):
		play_emitter(result, assets, pos, pos, direction, null, 0, 0.0, label + ":result")
	else:
		_spawn_anim_record(result, assets, pos, direction, 0, layer, label + ":result")


func _play_move_to(emitter: Dictionary, assets: Dictionary, origin: Vector3, direction: Vector3, layer: int, label: String) -> float:
	var anims: Array = _emitter_anims(emitter)
	if anims.is_empty():
		return 0.0
	var linger_start: float = maxf(float(emitter.get("linger_start", 0)), 0.0) / SOURCE_FPS
	var move_time: float = maxf(float(emitter.get("move_time", 10)), 1.0) / SOURCE_FPS
	var linger_end: float = maxf(float(emitter.get("linger_end", 0)), 0.0) / SOURCE_FPS
	var height_start: int = int(emitter.get("height_start", 0))
	var height_end: int = int(emitter.get("height_end", 0))
	var loc_height: int = int(emitter.get("loc_height", 0))
	var offset_start: Dictionary = emitter.get("offset_start", {}) if emitter.get("offset_start", null) is Dictionary else {}
	var offset_end: Dictionary = emitter.get("offset_end", {}) if emitter.get("offset_end", null) is Dictionary else {}
	var flat: Vector3 = _flat(direction)
	var side: Vector3 = Vector3(flat.z, 0.0, -flat.x) if flat.length() > 0.001 else Vector3.RIGHT
	var start: Vector3 = origin + side * (float(offset_start.get("x", 0)) / TILE_PX) + flat * (float(offset_start.get("y", 0)) / TILE_PX)
	var finish: Vector3 = origin + side * (float(offset_end.get("x", 0)) / TILE_PX) + flat * (float(offset_end.get("y", 0)) / TILE_PX)
	var lifetime: float = 0.0
	for record in anims:
		var sprite: VFXSprite = _spawn_anim_sprite(record, assets, start, direction, loc_height + height_start, layer, label, 0.0)
		if sprite == null:
			continue
		sprite.traveling = true
		sprite.travel_from = sprite.global_position
		sprite.travel_to = finish + Vector3.UP * (float(loc_height + height_end) / TILE_PX + float(LAYER_HEIGHTS.get(layer, 0.02)))
		sprite.travel_seconds = move_time
		sprite.travel_start = linger_start
		sprite.lifetime = linger_start + move_time + linger_end
		var result: Variant = emitter.get("result_anim", null)
		if result is Dictionary and _result_playable(result as Dictionary):
			sprite.on_finished = _on_result_anim.bind(result, assets, direction, int(emitter.get("result_layer", layer)), label)
		lifetime = maxf(lifetime, sprite.lifetime)
	return lifetime


func _play_after_images(emitter: Dictionary, attach: Node3D, duration: float, label: String) -> float:
	if attach == null or not is_instance_valid(attach):
		return 0.0
	var source: Sprite3D = attach.get_node_or_null("Character") as Sprite3D
	if source == null:
		return 0.0
	var window: float = maxf(duration, 0.3)
	var interval: float = maxf(1.0, float(emitter.get("burst_time", 1))) / SOURCE_FPS
	var count: int = clampi(int(ceil(window / interval)), 1, AFTER_IMAGE_MAX)
	interval = window / float(count)
	var life: float = maxf(float(emitter.get("anim_time", 8)), 1.0) / SOURCE_FPS
	_spawners.append({
		"kind": "after_image",
		"source": source,
		"next": 0.0,
		"interval": interval,
		"remaining": count,
		"life": life,
		"alpha": clampf(float(emitter.get("alpha", 128)) / 255.0, 0.05, 1.0),
		"label": label,
	})
	_append({"kind": "vfx_after_image_scheduled", "label": label, "count": count, "seconds": window + life})
	return window + life


func _process_spawners(delta: float) -> void:
	if _spawners.is_empty():
		return
	var keep: Array[Dictionary] = []
	for spawner in _spawners:
		spawner["next"] = float(spawner["next"]) - delta
		var source: Sprite3D = spawner.get("source", null) as Sprite3D
		if source == null or not is_instance_valid(source):
			continue
		while float(spawner["next"]) <= 0.0 and int(spawner["remaining"]) > 0:
			_spawn_ghost(source, float(spawner["life"]), float(spawner["alpha"]), String(spawner["label"]))
			spawner["next"] = float(spawner["next"]) + float(spawner["interval"])
			spawner["remaining"] = int(spawner["remaining"]) - 1
		if int(spawner["remaining"]) > 0:
			keep.append(spawner)
	_spawners = keep


func _spawn_ghost(source: Sprite3D, life: float, alpha: float, label: String) -> void:
	var ghost := GhostSprite.new()
	ghost.name = "Ghost_%s" % label
	ghost.layers = EFFECT_RENDER_LAYER
	ghost.texture = source.texture
	ghost.hframes = source.hframes
	ghost.vframes = source.vframes
	ghost.frame = source.frame
	ghost.flip_h = source.flip_h
	ghost.pixel_size = source.pixel_size
	ghost.offset = source.offset
	ghost.centered = source.centered
	ghost.billboard = source.billboard
	ghost.texture_filter = source.texture_filter
	ghost.transparent = true
	ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	ghost.lifetime = life
	ghost.base_alpha = alpha
	ghost.modulate = Color(1.0, 1.0, 1.0, alpha)
	add_child(ghost)
	ghost.global_transform = source.global_transform
	spawned_total += 1
	_append({"kind": "vfx_after_image", "label": label, "lifetime": life})


func _spawn_column(record: Dictionary, assets: Dictionary, position_world: Vector3, direction: Vector3, loc_height: int, layer: int, label: String, delay: float) -> float:
	var anim: Dictionary = record.get("anim", {}) if record.get("anim", null) is Dictionary else {}
	var index: String = String(anim.get("index", ""))
	var asset: Dictionary = _asset_for(assets, index)
	if asset.is_empty():
		_append({"kind": "vfx_skipped", "label": label, "anim": index, "reason": "missing_asset"})
		return 0.0
	if String((asset.get("layout", {}) as Dictionary).get("kind", "")) != "beam":
		var sprite: VFXSprite = _spawn_anim_sprite(record, assets, position_world, direction, loc_height, layer, label, delay)
		return sprite.delay + sprite.lifetime if sprite != null else 0.0
	var layout: Dictionary = asset.get("layout", {})
	var components: Dictionary = layout.get("components", {}) if layout.get("components", null) is Dictionary else {}
	var paths: Dictionary = asset.get("paths", {}) if asset.get("paths", null) is Dictionary else {}
	var frames_total: int = maxi(1, int(layout.get("frames", 1)))
	var frame_time: float = float(maxi(1, int(anim.get("frame_time", 1))))
	var cycles: int = int(record.get("cycles", 1))
	var total_time: int = int(record.get("total_time", 0))
	var lifetime: float = frames_total * frame_time * float(maxi(cycles, 1)) / SOURCE_FPS
	if cycles <= 0 and total_time > 0:
		lifetime = float(total_time) / SOURCE_FPS
	lifetime = clampf(lifetime, 0.2, 6.0)
	var body_height: float = _component_height(components, "body")
	var head_height: float = _component_height(components, "head")
	var tail_height: float = _component_height(components, "tail")
	var bodies: int = clampi(int(ceil((COLUMN_HEIGHT - head_height - tail_height) / maxf(body_height, 0.1))), 1, 6)
	var parts: Array[String] = ["tail"]
	for i in range(bodies):
		parts.append("body")
	parts.append("head")
	var base: Vector3 = position_world + Vector3.UP * (float(loc_height) / TILE_PX + float(LAYER_HEIGHTS.get(layer, 0.02)))
	var cursor: float = 0.0
	for part in parts:
		var path: String = String(paths.get(part, ""))
		var tex: Texture2D = _load_texture(path)
		var height: float = _component_height(components, part)
		if tex == null or height <= 0.0:
			cursor += height
			continue
		var sprite := VFXSprite.new()
		sprite.name = "Column_%s_%s" % [label, part]
		sprite.layers = EFFECT_RENDER_LAYER
		sprite.texture = tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.pixel_size = PIXEL_SIZE
		sprite.transparent = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.hframes = frames_total
		sprite.vframes = 1
		sprite.columns = frames_total
		sprite.frames_total = frames_total
		sprite.start_frame = 0
		sprite.end_frame = frames_total - 1
		sprite.frame_time = frame_time
		sprite.lifetime = lifetime
		sprite.delay = maxf(delay + _cue_delay, 0.0)
		sprite.modulate.a = float(anim.get("alpha", 255)) / 255.0
		add_child(sprite)
		sprite.global_position = base + Vector3.UP * (cursor + height * 0.5)
		cursor += height
		spawned_total += 1
	_append({"kind": "vfx_column_spawned", "label": label, "anim": index, "parts": parts.size(), "lifetime": lifetime})
	return delay + lifetime


func _component_height(components: Dictionary, part: String) -> float:
	var component: Dictionary = components.get(part, {}) if components.get(part, null) is Dictionary else {}
	var cell: Array = component.get("cell", [0, 0])
	if cell.size() < 2:
		return 0.0
	return float(cell[1]) * PIXEL_SIZE


func _play_overlay(emitter: Dictionary, assets: Dictionary, origin: Vector3, label: String) -> float:
	var anims: Array = _emitter_anims(emitter)
	if anims.is_empty():
		return 0.0
	var anim: Dictionary = (anims[0] as Dictionary).get("anim", {})
	var index: String = String(anim.get("index", ""))
	var asset: Dictionary = _asset_for(assets, index)
	if asset.is_empty():
		_append({"kind": "vfx_skipped", "label": label, "anim": index, "reason": "missing_asset"})
		return 0.0
	var tex: Texture2D = _load_texture(String(asset.get("path", "")))
	if tex == null:
		_append({"kind": "vfx_skipped", "label": label, "anim": index, "reason": "missing_asset"})
		return 0.0
	var layout: Dictionary = asset.get("layout", {})
	var cell: Array = layout.get("cell", [tex.get_height(), tex.get_height()])
	var frames: int = maxi(1, int(layout.get("frames", 1)))
	var tint: Color = _parse_color(String(emitter.get("color", "255, 255, 255, 255")))
	var total: float = maxf(float(emitter.get("total_time", 60)), 1.0) / SOURCE_FPS
	var fade_in: float = maxf(float(emitter.get("fade_in", 0)), 0.0) / SOURCE_FPS
	var fade_out: float = maxf(float(emitter.get("fade_out", 0)), 0.0) / SOURCE_FPS
	var movement: Dictionary = emitter.get("movement", {}) if emitter.get("movement", null) is Dictionary else {}
	var move_x: float = float(movement.get("x", 0))
	var move_y: float = float(movement.get("y", 0))
	var layer: int = int(emitter.get("layer", 0))
	var solid: bool = int(cell[0]) <= 2 and int(cell[1]) <= 2
	var bright: bool = tint.r + tint.g + tint.b > 1.5
	if layer >= 2 or (solid and bright):
		var overlay := ScreenOverlay.new()
		overlay.name = "Overlay_%s" % label
		overlay.sheet = tex
		overlay.cell = Vector2(float(cell[0]), float(cell[1]))
		overlay.frames = frames
		overlay.frame_time = float(maxi(1, int(anim.get("frame_time", 3))))
		overlay.movement = Vector2(move_x, -move_y) * OVERLAY_PIXEL_SCALE
		overlay.repeat_x = bool(emitter.get("repeat_x", true))
		overlay.repeat_y = bool(emitter.get("repeat_y", true))
		overlay.tint = Color(tint.r, tint.g, tint.b, tint.a * float(anim.get("alpha", 255)) / 255.0)
		overlay.fade_in = fade_in
		overlay.fade_out = fade_out
		overlay.total = total
		overlay.solid = solid
		_overlay_layer().add_child(overlay)
		_append({"kind": "vfx_overlay", "label": label, "anim": index, "mode": "screen", "seconds": total})
		return total
	var decal := GroundOverlay.new()
	decal.name = "Ground_%s" % label
	var cell_units: float = float(cell[0]) / TILE_PX
	var reps: int = 1
	decal.cull_mask = FLOOR_DECAL_CULL_MASK
	if solid:
		decal.frame_textures.append(_solid_texture())
		cell_units = SOLID_OVERLAY_SIZE
		decal.size = Vector3(SOLID_OVERLAY_SIZE, GROUND_OVERLAY_DEPTH, SOLID_OVERLAY_SIZE)
	else:
		reps = clampi(int(ceil(GROUND_OVERLAY_SIZE / maxf(cell_units, 0.05))), 1, maxi(1, GROUND_OVERLAY_MAX_PX / maxi(1, int(cell[0]))))
		for frame in range(frames):
			decal.frame_textures.append(_tiled_texture(asset, tex, frame, int(cell[0]), int(cell[1]), reps))
		decal.size = Vector3(cell_units * float(reps), GROUND_OVERLAY_DEPTH, float(cell[1]) / TILE_PX * float(reps))
	if decal.frame_textures.is_empty() or decal.frame_textures[0] == null:
		decal.free()
		return 0.0
	decal.texture_albedo = decal.frame_textures[0]
	decal.albedo_mix = 1.0
	decal.upper_fade = 0.0
	decal.lower_fade = 0.0
	decal.frame_time = float(maxi(1, int(anim.get("frame_time", 3))))
	decal.movement = Vector3(move_x, 0.0, -move_y) / TILE_PX
	decal.cell_units = cell_units
	decal.tint = Color(tint.r, tint.g, tint.b, tint.a * float(anim.get("alpha", 255)) / 255.0)
	decal.modulate = decal.tint
	decal.fade_in = fade_in
	decal.fade_out = fade_out
	decal.total = total
	add_child(decal)
	decal.base_position = Vector3(origin.x, origin.y + GROUND_OVERLAY_DEPTH * 0.25, origin.z)
	decal.global_position = decal.base_position
	_append({"kind": "vfx_overlay", "label": label, "anim": index, "mode": "floor_dim" if solid else "ground", "seconds": total})
	return total


func _solid_texture() -> ImageTexture:
	var key: String = "#solid"
	if _tiled_cache.has(key):
		return _tiled_cache[key]
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var tex: ImageTexture = ImageTexture.create_from_image(image)
	_tiled_cache[key] = tex
	return tex


func _tiled_texture(asset: Dictionary, sheet: Texture2D, frame: int, cell_w: int, cell_h: int, reps: int) -> ImageTexture:
	var key: String = "%s#%d#%d" % [String(asset.get("path", "")), frame, reps]
	if _tiled_cache.has(key):
		return _tiled_cache[key]
	var image: Image = sheet.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	var cell_image: Image = image.get_region(Rect2i(frame * cell_w, 0, cell_w, cell_h))
	cell_image.convert(Image.FORMAT_RGBA8)
	var tiled: Image = Image.create(cell_w * reps, cell_h * reps, false, Image.FORMAT_RGBA8)
	for row in range(reps):
		for column in range(reps):
			tiled.blit_rect(cell_image, Rect2i(0, 0, cell_w, cell_h), Vector2i(column * cell_w, row * cell_h))
	var tex: ImageTexture = ImageTexture.create_from_image(tiled)
	_tiled_cache[key] = tex
	return tex


func _overlay_layer() -> CanvasLayer:
	if _overlay_canvas == null or not is_instance_valid(_overlay_canvas):
		_overlay_canvas = CanvasLayer.new()
		_overlay_canvas.name = "VFXOverlay"
		_overlay_canvas.layer = OVERLAY_CANVAS_LAYER
		add_child(_overlay_canvas)
	return _overlay_canvas


func _start_shake(shake: Dictionary, label: String) -> void:
	var max_shake: float = float(shake.get("max_shake", 0))
	var frames: float = float(shake.get("max_shake_time", 0))
	if max_shake <= 0.0 or frames <= 0.0:
		return
	_shake_total = frames / SOURCE_FPS
	_shake_remaining = maxf(_shake_remaining, _shake_total)
	_shake_amplitude = maxf(_shake_amplitude, max_shake / TILE_PX * SHAKE_SCALE)
	_append({"kind": "vfx_screen_shake", "label": label, "seconds": _shake_total, "amplitude": _shake_amplitude})


func _process_shake(delta: float) -> void:
	if _shake_remaining <= 0.0:
		return
	_shake_remaining -= delta
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		_shake_remaining = 0.0
		return
	if _shake_remaining <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		_shake_amplitude = 0.0
		return
	var strength: float = _shake_amplitude * clampf(_shake_remaining / maxf(_shake_total, 0.01), 0.0, 1.0)
	camera.h_offset = visual_rng.randf_range(-strength, strength)
	camera.v_offset = visual_rng.randf_range(-strength, strength)


func _parse_color(text: String) -> Color:
	var parts: PackedStringArray = text.split(",")
	if parts.size() < 3:
		return Color.WHITE
	var alpha: float = float(parts[3].strip_edges()) / 255.0 if parts.size() >= 4 else 1.0
	return Color(float(parts[0].strip_edges()) / 255.0, float(parts[1].strip_edges()) / 255.0, float(parts[2].strip_edges()) / 255.0, alpha)


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if tex != null:
		_texture_cache[path] = tex
	return tex


func _rotated_texture(path: String, layout: Dictionary, dir_index: int, rotate: String) -> Texture2D:
	var steps: int = dir_index if rotate == "Dir1" else int(dir_index / 2) * 2
	var key: String = "%s#%d" % [path, steps]
	if _rotated_cache.has(key):
		return _rotated_cache[key]
	var base: Texture2D = _load_texture(path)
	if base == null:
		return null
	if steps == 0:
		return base
	var image: Image = base.get_image()
	if image == null:
		return base
	if image.is_compressed():
		image.decompress()
	var cell: Array = layout.get("cell", [image.get_height(), image.get_height()])
	var cell_w: int = maxi(1, int(cell[0]))
	var cell_h: int = maxi(1, int(cell[1]))
	var rotated: Image = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var angle: float = float(steps) * PI / 4.0
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var columns: int = maxi(1, image.get_width() / cell_w)
	var rows: int = maxi(1, image.get_height() / cell_h)
	for row in range(rows):
		for column in range(columns):
			var cx: float = float(cell_w) * 0.5
			var cy: float = float(cell_h) * 0.5
			for y in range(cell_h):
				for x in range(cell_w):
					var dx: float = float(x) + 0.5 - cx
					var dy: float = float(y) + 0.5 - cy
					var sx: int = int(floor(cx + dx * cos_a + dy * sin_a))
					var sy: int = int(floor(cy - dx * sin_a + dy * cos_a))
					if sx < 0 or sy < 0 or sx >= cell_w or sy >= cell_h:
						continue
					rotated.set_pixel(column * cell_w + x, row * cell_h + y, image.get_pixel(column * cell_w + sx, row * cell_h + sy))
	var tex: ImageTexture = ImageTexture.create_from_image(rotated)
	_rotated_cache[key] = tex
	return tex


func _dir8_index(direction: Vector3) -> int:
	var flat: Vector3 = _flat(direction)
	if flat.length() < 0.001:
		return 0
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var to_camera: Vector3 = Vector3(0.0, 0.0, 1.0)
	if camera != null:
		to_camera = camera.global_basis.z
		to_camera.y = 0.0
		if to_camera.length() < 0.001:
			to_camera = Vector3(0.0, 0.0, 1.0)
		to_camera = to_camera.normalized()
	var cos_theta: float = flat.dot(to_camera)
	var cross_y: float = to_camera.cross(flat).y
	var angle_ccw: float = atan2(cross_y, cos_theta)
	if angle_ccw < 0.0:
		angle_ccw += TAU
	var actor_row: int = int(round(angle_ccw / (TAU / 8.0))) % 8
	return (8 - actor_row) % 8


func _random_in_disc(radius: float) -> Vector3:
	if radius <= 0.0:
		return Vector3.ZERO
	var angle: float = visual_rng.randf_range(0.0, TAU)
	var dist: float = sqrt(visual_rng.randf()) * radius
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _flat(direction: Vector3) -> Vector3:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	return flat.normalized() if flat.length() > 0.001 else Vector3.ZERO


func _append(event: Dictionary) -> void:
	if battle_log != null:
		battle_log.append(event)
