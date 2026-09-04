class_name BattleVFXPlayer
extends Node3D

const TILE_PX: float = 24.0
const PIXEL_SIZE: float = 0.04
const SOURCE_FPS: float = 60.0
const DEFAULT_LIFETIME: float = 0.6
const MAX_PARTICLES_PER_EMITTER: int = 24
const LAYER_HEIGHTS: Dictionary = {-1: -0.02, 0: 0.0, 1: 0.01, 2: 0.02, 3: 0.03, 4: 0.04}
const DIR8_ORDER: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
]

var battle_log: BattleLog = null
var visual_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var spawned_total: int = 0
var _rotated_cache: Dictionary = {}
var _texture_cache: Dictionary = {}


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

	func _process(delta: float) -> void:
		if delay > 0.0:
			delay -= delta
			visible = false
			return
		visible = true
		elapsed += delta
		if traveling and travel_seconds > 0.0:
			var t: float = clampf(elapsed / travel_seconds, 0.0, 1.0)
			global_position = travel_from.lerp(travel_to, t) + Vector3.UP * (arc_height * 4.0 * t * (1.0 - t))
		elif converge and lifetime > 0.0:
			var t: float = clampf(elapsed / lifetime, 0.0, 1.0)
			global_position = global_position.lerp(converge_to, t * 0.35)
		elif velocity.length_squared() > 0.0:
			global_position += velocity * delta
		if attach_target != null and is_instance_valid(attach_target):
			global_position = attach_target.global_position + attach_offset
		_update_frame()
		if elapsed >= lifetime:
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


func setup(seed_value: int, log: BattleLog) -> void:
	visual_rng.seed = seed_value ^ 0x5EEDF00D
	battle_log = log


func active_count() -> int:
	var count: int = 0
	for child in get_children():
		if child is VFXSprite:
			count += 1
	return count


func play_cue(cue: Dictionary) -> float:
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
		"FiniteReleaseEmitter", "FiniteReleaseRangeEmitter", "CircleSquareReleaseEmitter":
			var bursts: int = clampi(maxi(1, int(emitter.get("bursts", 1))), 1, 8)
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
					if type_name == "FiniteReleaseRangeEmitter" and direction.length() > 0.001:
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
	var sprite: VFXSprite = _spawn_anim_sprite(record, assets, position_world, direction, loc_height, layer, label, delay)
	return sprite.delay + sprite.lifetime if sprite != null else 0.0


func _spawn_anim_sprite(record: Dictionary, assets: Dictionary, position_world: Vector3, direction: Vector3, loc_height: int, layer: int, label: String, delay: float) -> VFXSprite:
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
	sprite.delay = maxf(delay, 0.0)
	sprite.modulate.a = float(anim.get("alpha", 255)) / 255.0
	add_child(sprite)
	var column_lift: float = 0.0
	if kind == "beam":
		var body_cell: Array = ((layout.get("components", {}) as Dictionary).get("body", {}) as Dictionary).get("cell", [0, 0])
		column_lift = float(body_cell[1]) * PIXEL_SIZE * 0.5 if body_cell.size() >= 2 else 0.0
	sprite.global_position = position_world + Vector3.UP * (float(loc_height) / TILE_PX + float(LAYER_HEIGHTS.get(layer, 0.02)) + column_lift)
	sprite.frame = sprite.row * sprite.columns + sprite.start_frame
	spawned_total += 1
	_append({"kind": "vfx_spawned", "label": label, "anim": index, "asset_path": String(asset.get("path", "")), "lifetime": sprite.lifetime, "frames": span, "layout": kind, "rotate": rotate, "at": sprite.global_position})
	return sprite


func _emitter_anims(emitter: Dictionary) -> Array:
	var out: Array = []
	var anims: Variant = emitter.get("anims", null)
	if anims is Array:
		for record in anims:
			if record is Dictionary and (record as Dictionary).get("anim", null) is Dictionary:
				out.append(record)
	for key in ["anim", "anim1", "anim2"]:
		var single: Variant = emitter.get(key, null)
		if single is Dictionary:
			var dict: Dictionary = single
			if dict.get("anim", null) is Dictionary:
				out.append(dict)
			elif dict.has("index"):
				out.append({"type": "StaticAnim", "anim": dict, "cycles": 1, "total_time": 0})
	return out


func _asset_for(assets: Dictionary, index: String) -> Dictionary:
	if index.is_empty():
		return {}
	for prefix in ["particle:", "beam:", "item:"]:
		var record: Variant = assets.get(prefix + index, null)
		if record is Dictionary:
			return record
	return {}


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
