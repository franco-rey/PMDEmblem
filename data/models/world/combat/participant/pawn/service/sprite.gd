class_name TacticsPawnSprite
extends Sprite3D

const ANIM_IDLE: String = "idle"
const ANIM_WALK: String = "walk"
const ANIM_HURT: String = "hurt"
const ANIM_SLEEP: String = "sleep"
const ANIM_HOP: String = "hop"
const ANIM_FAINT: String = "faint"

const ANIMDATA_NAME_CANDIDATES: Dictionary = {
	ANIM_IDLE: ["Idle"],
	ANIM_WALK: ["Walk"],
	ANIM_HURT: ["Hurt"],
	ANIM_SLEEP: ["Sleep", "Laying", "EventSleep"],
	ANIM_HOP: ["Hop"],
	"attack": ["Attack"],
	"physical_attack": ["Attack"],
	"special_attack": ["Shoot", "Charge", "Special0", "Attack"],
	"status_attack": ["Charge", "Special0", "Appeal", "Attack"],
	"shoot": ["Shoot"],
	"charge": ["Charge"],
	"buff": ["Charge", "Appeal"],
	"debuff": ["Cringe", "Hurt"],
	"heal": ["Charge", "Appeal"],
	"miss": ["Idle"],
	"faint": ["Faint", "Laying", "EventSleep", "Sleep"],
}

const FRAME_DURATION: Dictionary = {
	ANIM_IDLE: 0.18,
	ANIM_WALK: 0.10,
	ANIM_HURT: 0.10,
	ANIM_SLEEP: 0.55,
	ANIM_HOP:  0.07,
}

const HOLD_LAST_FRAME_STATES: Array[String] = [ANIM_FAINT]
const SHADOW_WIDTHS: Dictionary = {0: 20.0, 1: 22.0, 2: 30.0, 3: 40.0}
const SPRITE_ROW_COUNT_FALLBACK: int = 2
const DEFAULT_CHARACTER_CENTER_Y: float = 0.602
const DEFAULT_FRAME_CELL_PX: float = 128.0
const DEFAULT_FRAME_BOTTOM_PADDING_PX: float = 8.0
const DEFAULT_PIXEL_SIZE: float = 0.01
const DEFAULT_VISIBLE_FOOT_Y: float = (
	DEFAULT_CHARACTER_CENTER_Y
	- (DEFAULT_FRAME_CELL_PX * DEFAULT_PIXEL_SIZE * 0.5)
	+ (DEFAULT_FRAME_BOTTOM_PADDING_PX * DEFAULT_PIXEL_SIZE)
)
const SOURCE_TICKS_PER_SECOND: float = 60.0
const SOURCE_SHADOW_GROUND_PX: int = 4
const DIRECTION_COUNT: int = 8
const GROUNDING_LEGACY: String = "legacy_padding"
const GROUNDING_SOURCE: String = "source_shadow"
const ANCHOR_POINTS: Array[String] = ["center", "head", "left_hand", "right_hand", "shadow"]

var animator: AnimationNodeStateMachinePlayback = null

var state_textures: Dictionary = {}
var state_texture_paths: Dictionary = {}
var state_frame_counts: Dictionary = {}
var state_column_counts: Dictionary = {}
var state_row_counts: Dictionary = {}
var state_cell_widths: Dictionary = {}
var state_cell_heights: Dictionary = {}
var state_bottom_paddings: Dictionary = {}
var state_foot_drops: Dictionary = {}
var state_frame_durations: Dictionary = {}
var state_timings: Dictionary = {}
var state_source_names: Dictionary = {}
var state_phase_frames: Dictionary = {}
var source_name_to_state: Dictionary = {}

var anim_data: Dictionary = {}
var anchors: Dictionary = {}
var anchors_path: String = ""
var shadow_size: int = 0
var grounding_mode: String = GROUNDING_LEGACY
var ground_shadow_px: int = SOURCE_SHADOW_GROUND_PX
var sprite_set_ref: PokemonSpriteSetResource = null

var current_state: String = ANIM_IDLE
var curr_frame: int = 0
var frame_timer: float = 0.0
var state_elapsed: float = 0.0
var one_shot: bool = false
var one_shot_finished: bool = false
var facing_row: int = 0
var lunge_offset: Vector3 = Vector3.ZERO
var pose_frozen: bool = false
var base_local_position: Vector3 = Vector3(0.0, DEFAULT_CHARACTER_CENTER_Y, 0.0)

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var character_ui_name_label: Label3D = $CharacterUI/NameLabel


func setup(stats: Stats, expertise: String) -> void:
	var playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]
	if playback is AnimationNodeStateMachinePlayback:
		animator = playback
	else:
		push_error("Expected AnimationNodeStateMachinePlayback, but got " + str(typeof(playback)))
		return

	animator.start("IDLE")
	animation_tree.active = true
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	base_local_position = position

	var sprite_set: PokemonSpriteSetResource = _resolve_sprite_set(stats)
	sprite_set_ref = sprite_set
	_apply_world_pixel_size(sprite_set)
	var anim_root: Dictionary = SpriteAnimData.parse_root(sprite_set.anim_data_path) if sprite_set != null else {"shadow_size": 0, "anims": {}}
	anim_data = anim_root.get("anims", {})
	shadow_size = sprite_set.shadow_size if sprite_set != null and sprite_set.shadow_size > 0 else int(anim_root.get("shadow_size", 0))
	_load_anchors(sprite_set)
	_load_state_textures(stats.sprite, sprite_set, anim_data)
	_apply_state_texture(ANIM_IDLE)
	_ensure_ground_shadow()
	character_ui_name_label.text = stats.override_name if stats.override_name else expertise


static var _shadow_texture: ImageTexture = null


static func _ground_shadow_texture() -> ImageTexture:
	if _shadow_texture != null:
		return _shadow_texture
	var size: int = 64
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size) / 2.0
	for y in range(size):
		for x in range(size):
			var dx: float = (float(x) + 0.5 - center) / center
			var dy: float = (float(y) + 0.5 - center) / center
			var r: float = sqrt(dx * dx + dy * dy)
			var alpha: float = clampf(1.0 - r, 0.0, 1.0)
			alpha = clampf(alpha * 1.6, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	_shadow_texture = ImageTexture.create_from_image(image)
	return _shadow_texture


func _ensure_ground_shadow() -> void:
	var pawn: Node3D = get_parent() as Node3D
	if pawn == null or pawn.get_node_or_null("Shadow") != null:
		return
	var shadow := Sprite3D.new()
	shadow.name = "Shadow"
	shadow.texture = _ground_shadow_texture()
	shadow.axis = Vector3.AXIS_Y
	shadow.pixel_size = pixel_size
	shadow.shaded = false
	shadow.transparent = true
	shadow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	shadow.render_priority = -1
	shadow.layers = 2
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.42)
	var width: float = SHADOW_WIDTHS.get(clampi(shadow_size, 0, 3), 26.0)
	shadow.scale = Vector3(width / 64.0, 1.0, width * 0.55 / 64.0)
	shadow.position = Vector3(0.0, 0.012, 0.0)
	pawn.add_child(shadow)


func _resolve_sprite_set(stats: Stats) -> PokemonSpriteSetResource:
	if stats == null or stats.pokemon_instance == null:
		return null
	var form: PokemonFormResource = stats.pokemon_instance.resolved_form()
	if form == null:
		return null
	return form.sprite_set


func _apply_world_pixel_size(sprite_set: PokemonSpriteSetResource) -> void:
	pixel_size = DEFAULT_PIXEL_SIZE
	if sprite_set != null and sprite_set.world_pixel_size > 0.0:
		pixel_size = sprite_set.world_pixel_size


func _load_anchors(sprite_set: PokemonSpriteSetResource) -> void:
	anchors = {}
	anchors_path = ""
	grounding_mode = GROUNDING_LEGACY
	ground_shadow_px = SOURCE_SHADOW_GROUND_PX
	if sprite_set == null or sprite_set.anchors_path.is_empty():
		return
	if not FileAccess.file_exists(sprite_set.anchors_path):
		return
	var file: FileAccess = FileAccess.open(sprite_set.anchors_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var dict: Dictionary = parsed
	var states: Variant = dict.get("states", {})
	if not (states is Dictionary) or (states as Dictionary).is_empty():
		return
	anchors = states
	anchors_path = sprite_set.anchors_path
	if shadow_size <= 0:
		shadow_size = int(dict.get("shadow_size", 0))
	grounding_mode = GROUNDING_SOURCE
	var idle_shadow: Variant = anchor_point_px("Idle", 0, 0, "shadow")
	if idle_shadow is Vector2i:
		ground_shadow_px = (idle_shadow as Vector2i).y


func _load_state_textures(base_sprite_path: String, sprite_set: PokemonSpriteSetResource, anim_data_map: Dictionary) -> void:
	var entries: Dictionary = _resolve_state_entries(base_sprite_path, sprite_set)
	source_name_to_state = {}

	for state: String in entries.keys():
		var metadata: Dictionary = entries[state]
		var path: String = String(metadata.get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue
		state_textures[state] = tex
		state_texture_paths[state] = path

		var cell_w: int = 0
		var cell_h: int = 0
		var cell_size: Vector2i = metadata.get("cell_size", Vector2i.ZERO)
		if cell_size.x > 0 and cell_size.y > 0:
			cell_w = cell_size.x
			cell_h = cell_size.y
		else:
			var entry: SpriteAnimData.AnimEntry = _select_anim_data_entry(state, tex, anim_data_map)
			if entry != null:
				cell_w = entry.frame_width
				cell_h = entry.frame_height
		if cell_w <= 0 or cell_h <= 0:
			cell_h = int(tex.get_height() / SPRITE_ROW_COUNT_FALLBACK)
			cell_w = cell_h

		var columns_local: int = maxi(1, int(tex.get_width() / max(1, cell_w)))
		var rows_local: int = maxi(1, int(tex.get_height() / max(1, cell_h)))
		var frames_local: int = columns_local
		var imported_frame_count: int = int(metadata.get("frame_count", 0))
		if imported_frame_count > 0:
			frames_local = mini(columns_local, imported_frame_count)
		state_frame_counts[state] = frames_local
		state_column_counts[state] = columns_local
		state_row_counts[state] = rows_local
		state_cell_widths[state] = cell_w
		state_cell_heights[state] = cell_h
		if grounding_mode != GROUNDING_SOURCE:
			state_bottom_paddings[state] = _find_lowest_bottom_padding(tex, cell_w, cell_h, columns_local, rows_local)
		var timing: Array[int] = _timing_for_state(state, metadata, frames_local)
		state_timings[state] = timing
		state_frame_durations[state] = _duration_from_timing(timing, state)
		var source_name: String = String(metadata.get("source_name", ""))
		if source_name.is_empty():
			var xml_entry: SpriteAnimData.AnimEntry = _select_anim_data_entry(state, tex, anim_data_map)
			source_name = xml_entry.name if xml_entry != null else ""
		state_source_names[state] = source_name
		if not source_name.is_empty():
			var key: String = source_name.to_lower()
			if not source_name_to_state.has(key) or not metadata.has("alias_of"):
				source_name_to_state[key] = state
		state_phase_frames[state] = _phase_frames_for_state(state, metadata, source_name, frames_local)


func _timing_for_state(state: String, metadata: Dictionary, frames_local: int) -> Array[int]:
	var out: Array[int] = []
	var raw: Variant = metadata.get("timing", [])
	if raw is Array:
		for tick in (raw as Array):
			out.append(maxi(1, int(tick)))
	if out.is_empty():
		var source_name: String = String(metadata.get("source_name", ""))
		var entry: SpriteAnimData.AnimEntry = anim_data.get(source_name, null) if not source_name.is_empty() else null
		if entry == null:
			for candidate in ANIMDATA_NAME_CANDIDATES.get(state, []):
				if anim_data.has(String(candidate)):
					entry = anim_data[String(candidate)]
					break
		if entry != null:
			for tick in entry.durations:
				out.append(maxi(1, int(tick)))
	if out.size() > frames_local and frames_local > 0:
		out.resize(frames_local)
	return out


func _phase_frames_for_state(state: String, metadata: Dictionary, source_name: String, frames_local: int) -> Dictionary:
	var absent: int = PokemonSpriteSetResource.ABSENT_FRAME
	var rush: int = absent
	var hit: int = absent
	var ret: int = absent
	var schema_two: bool = sprite_set_ref != null and sprite_set_ref.animation_schema_version >= 2
	var xml_entry: SpriteAnimData.AnimEntry = anim_data.get(source_name, null) if not source_name.is_empty() else null
	if xml_entry != null:
		var resolved: SpriteAnimData.AnimEntry = SpriteAnimData.resolve_alias(anim_data, source_name)
		if resolved != null:
			xml_entry = resolved
		rush = xml_entry.rush_frame
		hit = xml_entry.hit_frame
		ret = xml_entry.return_frame
	elif schema_two:
		rush = int(metadata.get("rush_frame", absent))
		hit = int(metadata.get("hit_frame", absent))
		ret = int(metadata.get("return_frame", absent))
	if state == ANIM_HURT and rush == absent and hit == absent and ret == absent:
		pass
	return {
		"rush": rush if rush < frames_local else absent,
		"hit": hit if hit < frames_local else absent,
		"return": ret if ret < frames_local else absent,
	}


func _select_anim_data_entry(state: String, tex: Texture2D, anim_data_map: Dictionary) -> SpriteAnimData.AnimEntry:
	var candidates: Array = ANIMDATA_NAME_CANDIDATES.get(state, [])
	var best: SpriteAnimData.AnimEntry = null
	var best_score: int = -999999
	for index: int in range(candidates.size()):
		var anim_name: String = String(candidates[index])
		if not anim_data_map.has(anim_name):
			continue
		var entry: SpriteAnimData.AnimEntry = anim_data_map[anim_name]
		if entry == null or entry.frame_width <= 0 or entry.frame_height <= 0:
			continue
		if tex.get_width() % entry.frame_width != 0 or tex.get_height() % entry.frame_height != 0:
			continue

		var columns: int = int(tex.get_width() / entry.frame_width)
		var rows: int = int(tex.get_height() / entry.frame_height)
		var score: int = 1000 - index
		if columns == entry.frames_per_direction:
			score += 10000
		else:
			score -= abs(columns - entry.frames_per_direction) * 100
		if rows == DIRECTION_COUNT:
			score += 500
		elif rows == 1:
			score += 100

		if score > best_score:
			best_score = score
			best = entry
	return best


func _resolve_state_entries(base_sprite_path: String, sprite_set: PokemonSpriteSetResource) -> Dictionary:
	if sprite_set != null and not sprite_set.idle_path.is_empty():
		var entries: Dictionary = {}
		for key in sprite_set.animation_states.keys():
			var raw_entry: Variant = sprite_set.animation_states[key]
			if raw_entry is Dictionary and _state_entry_usable(raw_entry as Dictionary):
				entries[String(key)] = (raw_entry as Dictionary).duplicate(true)
		var minimal: Dictionary = {
			ANIM_IDLE:  sprite_set.idle_path,
			ANIM_WALK:  sprite_set.walk_path,
			ANIM_HURT:  sprite_set.hurt_path,
			ANIM_SLEEP: sprite_set.sleep_path,
			ANIM_HOP:   sprite_set.hop_path,
		}
		for key in minimal.keys():
			if not entries.has(key):
				entries[key] = {"path": String(minimal[key])}
		_normalize_rest_faint_entry(entries)
		return entries
	var base_no_ext: String = base_sprite_path.get_basename()
	var ext: String = "." + base_sprite_path.get_extension()
	return {
		ANIM_IDLE:  {"path": base_sprite_path},
		ANIM_WALK:  {"path": base_no_ext + "_walk"  + ext},
		ANIM_HURT:  {"path": base_no_ext + "_hurt"  + ext},
		ANIM_SLEEP: {"path": base_no_ext + "_sleep" + ext},
		ANIM_HOP:   {"path": base_no_ext + "_hop"   + ext},
	}


func _state_entry_usable(entry: Dictionary) -> bool:
	var cell: Vector2i = entry.get("cell_size", Vector2i.ZERO)
	return cell.x > 0 and cell.y > 0


func _normalize_rest_faint_entry(entries: Dictionary) -> void:
	if not entries.has("sleep"):
		return
	var sleep_entry_v: Variant = entries["sleep"]
	if not (sleep_entry_v is Dictionary):
		return
	var sleep_entry: Dictionary = sleep_entry_v
	if not entries.has("faint"):
		var alias_entry: Dictionary = sleep_entry.duplicate(true)
		alias_entry["alias_of"] = "sleep"
		entries["faint"] = alias_entry
		return

	var faint_entry_v: Variant = entries["faint"]
	if not (faint_entry_v is Dictionary):
		return
	var faint_entry: Dictionary = faint_entry_v
	var faint_path: String = String(faint_entry.get("path", ""))
	var sleep_path: String = String(sleep_entry.get("path", ""))
	if not faint_path.is_empty() and not sleep_path.is_empty() and faint_path != sleep_path:
		return
	if _has_explicit_frame_metadata(faint_entry):
		return

	var repaired_entry: Dictionary = sleep_entry.duplicate(true)
	repaired_entry["alias_of"] = "sleep"
	repaired_entry["source_name"] = String(faint_entry.get("source_name", repaired_entry.get("source_name", "Sleep")))
	entries["faint"] = repaired_entry


func _has_explicit_frame_metadata(entry: Dictionary) -> bool:
	var cell_size: Vector2i = entry.get("cell_size", Vector2i.ZERO)
	return cell_size.x > 0 and cell_size.y > 0 and int(entry.get("frame_count", 0)) > 0


func _duration_from_timing(timing: Variant, state: String) -> float:
	if timing is Array and not (timing as Array).is_empty():
		var total: int = 0
		for tick in (timing as Array):
			total += int(tick)
		return clampf(float(total) / float((timing as Array).size()) / SOURCE_TICKS_PER_SECOND, 0.02, 0.6)
	return float(FRAME_DURATION.get(state, 0.15))


func _apply_state_texture(state: String) -> void:
	if not state_textures.has(state):
		state = ANIM_IDLE
	if not state_textures.has(state):
		return
	var tex: Texture2D = state_textures[state]
	var rows_local: int = maxi(1, int(state_row_counts.get(state, 1)))
	var frames_local: int = maxi(1, int(state_frame_counts.get(state, 1)))
	var columns_local: int = maxi(frames_local, int(state_column_counts.get(state, frames_local)))
	texture = tex
	vframes = rows_local
	hframes = columns_local
	_apply_grounding_offset(state)
	current_state = state
	curr_frame = 0
	frame_timer = 0.0
	state_elapsed = 0.0
	one_shot_finished = false
	frame = 0
	flip_h = false


func _apply_grounding_offset(state: String) -> void:
	if grounding_mode == GROUNDING_SOURCE:
		offset.y = float(ground_shadow_px + maxi(0, foot_drop_px(state))) - (DEFAULT_CHARACTER_CENTER_Y / pixel_size)
		return
	var cell_h: float = float(state_cell_heights.get(state, DEFAULT_FRAME_CELL_PX))
	var bottom_padding: float = float(state_bottom_paddings.get(state, DEFAULT_FRAME_BOTTOM_PADDING_PX))
	var current_visible_foot_y: float = (
		DEFAULT_CHARACTER_CENTER_Y
		- (cell_h * pixel_size * 0.5)
		+ (bottom_padding * pixel_size)
	)
	offset.y = (DEFAULT_VISIBLE_FOOT_Y - current_visible_foot_y) / pixel_size


func foot_drop_px(state: String) -> int:
	if state_foot_drops.has(state):
		return int(state_foot_drops[state])
	var tex: Texture2D = state_textures.get(state, null)
	var cell_w: int = int(state_cell_widths.get(state, 0))
	var cell_h: int = int(state_cell_heights.get(state, 0))
	if tex == null or cell_w <= 0 or cell_h <= 0:
		return 0
	var columns: int = int(state_column_counts.get(state, state_frame_counts.get(state, 1)))
	var rows: int = int(state_row_counts.get(state, 1))
	var padding: int = _find_lowest_bottom_padding(tex, cell_w, cell_h, columns, rows)
	var lowest_from_center: int = (cell_h - padding - 1) - int(cell_h / 2)
	var drop: int = lowest_from_center - ground_shadow_px
	state_foot_drops[state] = drop
	return drop


func _find_lowest_bottom_padding(tex: Texture2D, cell_w: int, cell_h: int, hframes_count: int, vframes_count: int) -> int:
	var image: Image = tex.get_image()
	if not image:
		return int(DEFAULT_FRAME_BOTTOM_PADDING_PX)
	if image.is_compressed() and image.decompress() != OK:
		return int(DEFAULT_FRAME_BOTTOM_PADDING_PX)

	var lowest_padding: int = cell_h
	var max_rows: int = mini(vframes_count, image.get_height() / max(1, cell_h))
	var max_frames: int = mini(hframes_count, image.get_width() / max(1, cell_w))

	for row: int in range(max_rows):
		var row_y: int = row * cell_h
		for frame_idx: int in range(max_frames):
			var frame_x: int = frame_idx * cell_w
			var frame_padding: int = _find_frame_bottom_padding(image, frame_x, row_y, cell_w, cell_h)
			if frame_padding >= 0:
				lowest_padding = mini(lowest_padding, frame_padding)

	return 0 if lowest_padding == cell_h else lowest_padding


func _find_frame_bottom_padding(image: Image, frame_x: int, frame_y: int, cell_w: int, cell_h: int) -> int:
	for y: int in range(cell_h - 1, -1, -1):
		for x: int in range(cell_w):
			if image.get_pixel(frame_x + x, frame_y + y).a > 0.0:
				return cell_h - 1 - y
	return -1


func set_anim_state(new_state: String) -> void:
	if new_state == current_state and not one_shot:
		return
	one_shot = HOLD_LAST_FRAME_STATES.has(new_state)
	_apply_state_texture(new_state)


func freeze_pose(state: String) -> void:
	if not state_textures.has(state):
		return
	one_shot = true
	_apply_state_texture(state)
	var phases: Variant = state_phase_frames.get(state, {})
	var frame_count: int = int(state_frame_counts.get(state, 1))
	var peak: int = int((phases as Dictionary).get("hit", frame_count / 2)) if phases is Dictionary else frame_count / 2
	curr_frame = clampi(peak, 0, maxi(0, frame_count - 1))
	frame_timer = 0.0
	pose_frozen = true


func unfreeze_pose() -> void:
	if not pose_frozen:
		return
	pose_frozen = false
	one_shot = false
	one_shot_finished = false
	set_anim_state(ANIM_IDLE)


func play_action(state: String) -> float:
	if not state_textures.has(state):
		return 0.0
	one_shot = true
	_apply_state_texture(state)
	return state_total_seconds(state)


func is_one_shot_finished() -> bool:
	return one_shot and one_shot_finished


func can_play_state(state: String) -> bool:
	return state_textures.has(state)


func has_source_state(source_name: String) -> bool:
	return not resolve_source_state(source_name).is_empty()


func resolve_source_state(source_action_name: String) -> Dictionary:
	if source_action_name.is_empty():
		return {}
	var catalog: ActorActionCatalog = ActorActionCatalog.shared()
	var chain: Array[String] = catalog.fallback_chain(source_action_name)
	for candidate in chain:
		var state: String = _state_for_source_name(candidate)
		if not state.is_empty():
			return {
				"state_key": state,
				"source_name": candidate,
				"requested": source_action_name,
				"tier": "exact" if candidate == source_action_name else "source_fallback",
				"dash": catalog.is_dash(candidate),
			}
	return {}


func _state_for_source_name(source_name: String) -> String:
	var key: String = source_name.to_lower()
	if source_name_to_state.has(key):
		return String(source_name_to_state[key])
	if anim_data.has(source_name):
		var resolved: SpriteAnimData.AnimEntry = SpriteAnimData.resolve_alias(anim_data, source_name)
		if resolved != null and resolved.name != source_name:
			var target_key: String = resolved.name.to_lower()
			if source_name_to_state.has(target_key):
				return String(source_name_to_state[target_key])
	return ""


func state_timing(state: String) -> Array[int]:
	var out: Array[int] = []
	var raw: Variant = state_timings.get(state, [])
	if raw is Array:
		for tick in (raw as Array):
			out.append(int(tick))
	return out


func state_total_seconds(state: String) -> float:
	var timing: Array[int] = state_timing(state)
	if timing.is_empty():
		return float(state_frame_durations.get(state, FRAME_DURATION.get(state, 0.15))) * float(state_frame_counts.get(state, 1))
	var total: int = 0
	for tick in timing:
		total += tick
	return float(total) / SOURCE_TICKS_PER_SECOND


func state_frame_end_seconds(state: String, frame_index: int) -> float:
	var timing: Array[int] = state_timing(state)
	if timing.is_empty():
		var dur: float = float(state_frame_durations.get(state, FRAME_DURATION.get(state, 0.15)))
		return dur * float(frame_index + 1)
	var total: int = 0
	for i in range(mini(frame_index + 1, timing.size())):
		total += timing[i]
	return float(total) / SOURCE_TICKS_PER_SECOND


func state_phase_seconds(state: String) -> Dictionary:
	var phases: Dictionary = state_phase_frames.get(state, {})
	var absent: int = PokemonSpriteSetResource.ABSENT_FRAME
	var rush: int = int(phases.get("rush", absent))
	var hit: int = int(phases.get("hit", absent))
	var ret: int = int(phases.get("return", absent))
	var total: float = state_total_seconds(state)
	return {
		"rush": state_frame_end_seconds(state, rush) if rush > absent else 0.0,
		"hit": state_frame_end_seconds(state, hit) if hit > absent else total,
		"return": state_frame_end_seconds(state, ret) if ret > absent else total,
		"total": total,
		"rush_frame": rush,
		"hit_frame": hit,
		"return_frame": ret,
	}


func anchor_point_px(source_name: String, row: int, frame_index: int, point: String) -> Variant:
	if anchors.is_empty():
		return null
	var state_anchor: Variant = anchors.get(source_name, null)
	if not (state_anchor is Dictionary):
		return null
	var dirs: Variant = (state_anchor as Dictionary).get("dirs", [])
	if not (dirs is Array) or (dirs as Array).is_empty():
		return null
	var row_index: int = clampi(row, 0, (dirs as Array).size() - 1)
	var frames: Variant = (dirs as Array)[row_index]
	if not (frames is Array) or (frames as Array).is_empty():
		return null
	var packed: Variant = (frames as Array)[clampi(frame_index, 0, (frames as Array).size() - 1)]
	if not (packed is Array) or (packed as Array).size() < 10:
		return null
	var point_index: int = ANCHOR_POINTS.find(point)
	if point_index < 0:
		return null
	var x: Variant = (packed as Array)[point_index * 2]
	var y: Variant = (packed as Array)[point_index * 2 + 1]
	if x == null or y == null:
		return null
	return Vector2i(int(x), int(y))


func action_point_world(point: String) -> Vector3:
	var origin: Vector3 = global_position + Vector3(0.0, offset.y * pixel_size, 0.0)
	var source_name: String = String(state_source_names.get(current_state, ""))
	var anchor: Variant = anchor_point_px(source_name, facing_row, curr_frame, point)
	if anchor is Vector2i:
		var px: Vector2i = anchor
		var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
		var right: Vector3 = Vector3.RIGHT
		if camera != null:
			right = camera.global_basis.x
			right.y = 0.0
			right = right.normalized() if right.length() > 0.0001 else Vector3.RIGHT
		return origin + right * (float(px.x) * pixel_size) + Vector3.UP * (-float(px.y) * pixel_size)
	return origin


func set_lunge_offset(offset_world: Vector3) -> void:
	lunge_offset = offset_world
	position = base_local_position + lunge_offset


func clear_lunge_offset() -> void:
	set_lunge_offset(Vector3.ZERO)


func debug_animation_snapshot() -> Dictionary:
	var tex: Texture2D = texture
	return {
		"state": current_state,
		"source_name": String(state_source_names.get(current_state, "")),
		"texture_path": String(state_texture_paths.get(current_state, tex.resource_path if tex != null else "")),
		"texture_width": tex.get_width() if tex != null else 0,
		"texture_height": tex.get_height() if tex != null else 0,
		"cell_width": int(state_cell_widths.get(current_state, 0)),
		"cell_height": int(state_cell_heights.get(current_state, 0)),
		"hframes": hframes,
		"vframes": vframes,
		"frame": frame,
		"current_frame": curr_frame,
		"facing_row": facing_row,
		"one_shot": one_shot,
		"one_shot_finished": one_shot_finished,
		"grounding_mode": grounding_mode,
		"offset_y": offset.y,
		"timing": state_timing(current_state),
	}


func _process(delta: float) -> void:
	if pose_frozen:
		return
	var n: int = int(state_frame_counts.get(current_state, 1))
	if n <= 1:
		curr_frame = 0
		return
	state_elapsed += delta
	var timing: Array[int] = state_timing(current_state)
	frame_timer += delta
	var guard: int = 0
	while guard < 64:
		guard += 1
		var dur: float = _frame_duration(current_state, curr_frame, timing)
		if frame_timer < dur:
			break
		frame_timer -= dur
		if curr_frame + 1 >= n:
			if one_shot:
				one_shot_finished = true
				frame_timer = 0.0
				break
			curr_frame = 0
		else:
			curr_frame += 1


func _frame_duration(state: String, frame_index: int, timing: Array[int]) -> float:
	if not timing.is_empty() and frame_index < timing.size():
		return maxf(0.001, float(timing[frame_index]) / SOURCE_TICKS_PER_SECOND)
	return float(state_frame_durations.get(state, FRAME_DURATION.get(state, 0.15)))


func start_animator(move_direction: Vector3, is_jumping: bool) -> void:
	if move_direction == Vector3.ZERO:
		animator.travel("IDLE")
	elif is_jumping:
		animator.travel("JUMP")


func rotate_sprite(_global_basis: Basis) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var n: int = state_frame_counts.get(current_state, 1)
	var rows: int = int(state_row_counts.get(current_state, 1))
	facing_row = _direction_row(_global_basis, camera, DIRECTION_COUNT)
	if rows <= 1:
		frame = curr_frame
		return

	var columns: int = maxi(n, int(state_column_counts.get(current_state, n)))
	var row: int = facing_row if rows == DIRECTION_COUNT else _direction_row(_global_basis, camera, rows)
	frame = row * columns + mini(curr_frame, columns - 1)


func _direction_row(pawn_basis: Basis, camera: Camera3D, rows: int) -> int:
	var to_cam_xz: Vector3 = -camera.global_basis.z
	to_cam_xz.y = 0.0
	var pawn_facing_xz: Vector3 = pawn_basis.z
	pawn_facing_xz.y = 0.0
	if to_cam_xz.length() < 0.0001 or pawn_facing_xz.length() < 0.0001:
		return 0
	to_cam_xz = to_cam_xz.normalized()
	pawn_facing_xz = pawn_facing_xz.normalized()

	var to_camera: Vector3 = -to_cam_xz
	var cos_theta: float = pawn_facing_xz.dot(to_camera)
	var cross_y: float = to_camera.cross(pawn_facing_xz).y
	var angle_ccw: float = atan2(cross_y, cos_theta)
	if angle_ccw < 0.0:
		angle_ccw += TAU
	var bucket_size: float = TAU / float(rows)
	return int(round(angle_ccw / bucket_size)) % rows


func adjust_to_center(pawn: TacticsPawn) -> bool:
	if pawn.get_tile() and not pawn.res.is_moving:
		pawn.global_position = pawn.get_tile().global_position
		return true
	return false
