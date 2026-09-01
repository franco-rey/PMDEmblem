class_name TacticsPawnSprite
extends Sprite3D

const ANIM_IDLE: String = "idle"
const ANIM_WALK: String = "walk"
const ANIM_HURT: String = "hurt"
const ANIM_SLEEP: String = "sleep"
const ANIM_HOP: String = "hop"

const ANIMDATA_NAME_CANDIDATES: Dictionary = {
	ANIM_IDLE: ["Idle"],
	ANIM_WALK: ["Walk"],
	ANIM_HURT: ["Hurt"],
	ANIM_SLEEP: ["Laying", "EventSleep", "Sleep"],
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
	"faint": ["Laying", "EventSleep", "Sleep"],
}

const FRAME_DURATION: Dictionary = {
	ANIM_IDLE: 0.18,
	ANIM_WALK: 0.10,
	ANIM_HURT: 0.10,
	ANIM_SLEEP: 0.55,
	ANIM_HOP:  0.07,
}

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

const DIRECTION_COUNT: int = 8

var animator: AnimationNodeStateMachinePlayback = null

var state_textures: Dictionary = {}
var state_texture_paths: Dictionary = {}
var state_frame_counts: Dictionary = {}
var state_column_counts: Dictionary = {}
var state_row_counts: Dictionary = {}
var state_cell_widths: Dictionary = {}
var state_cell_heights: Dictionary = {}
var state_bottom_paddings: Dictionary = {}
var state_frame_durations: Dictionary = {}

var current_state: String = ANIM_IDLE
var curr_frame: int = 0
var frame_timer: float = 0.0

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

	var sprite_set: PokemonSpriteSetResource = _resolve_sprite_set(stats)
	_apply_world_pixel_size(sprite_set)
	var anim_data: Dictionary = SpriteAnimData.parse(sprite_set.anim_data_path) if sprite_set != null else {}
	_load_state_textures(stats.sprite, sprite_set, anim_data)
	_apply_state_texture(ANIM_IDLE)
	character_ui_name_label.text = stats.override_name if stats.override_name else expertise


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


func _load_state_textures(base_sprite_path: String, sprite_set: PokemonSpriteSetResource, anim_data: Dictionary) -> void:
	var entries: Dictionary = _resolve_state_entries(base_sprite_path, sprite_set)

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
			var entry: SpriteAnimData.AnimEntry = _select_anim_data_entry(state, tex, anim_data)
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
		state_bottom_paddings[state] = _find_lowest_bottom_padding(tex, cell_w, cell_h, columns_local, rows_local)
		state_frame_durations[state] = _duration_from_timing(metadata.get("timing", []), state)


func _select_anim_data_entry(state: String, tex: Texture2D, anim_data: Dictionary) -> SpriteAnimData.AnimEntry:
	var candidates: Array = ANIMDATA_NAME_CANDIDATES.get(state, [])
	var best: SpriteAnimData.AnimEntry = null
	var best_score: int = -999999
	for index: int in range(candidates.size()):
		var anim_name: String = String(candidates[index])
		if not anim_data.has(anim_name):
			continue
		var entry: SpriteAnimData.AnimEntry = anim_data[anim_name]
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
			if raw_entry is Dictionary:
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
		return clampf(float(total) / float((timing as Array).size()) / 60.0, 0.04, 0.6)
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
	frame = 0
	flip_h = false


func _apply_grounding_offset(state: String) -> void:
	var cell_h: float = float(state_cell_heights.get(state, DEFAULT_FRAME_CELL_PX))
	var bottom_padding: float = float(state_bottom_paddings.get(state, DEFAULT_FRAME_BOTTOM_PADDING_PX))
	var current_visible_foot_y: float = (
		DEFAULT_CHARACTER_CENTER_Y
		- (cell_h * pixel_size * 0.5)
		+ (bottom_padding * pixel_size)
	)
	offset.y = (DEFAULT_VISIBLE_FOOT_Y - current_visible_foot_y) / pixel_size


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
	if new_state == current_state:
		return
	_apply_state_texture(new_state)


func can_play_state(state: String) -> bool:
	return state_textures.has(state)


func debug_animation_snapshot() -> Dictionary:
	var tex: Texture2D = texture
	return {
		"state": current_state,
		"texture_path": String(state_texture_paths.get(current_state, tex.resource_path if tex != null else "")),
		"texture_width": tex.get_width() if tex != null else 0,
		"texture_height": tex.get_height() if tex != null else 0,
		"cell_width": int(state_cell_widths.get(current_state, 0)),
		"cell_height": int(state_cell_heights.get(current_state, 0)),
		"hframes": hframes,
		"vframes": vframes,
		"frame": frame,
		"current_frame": curr_frame,
	}


func _process(delta: float) -> void:
	var n: int = state_frame_counts.get(current_state, 1)
	if current_state == ANIM_SLEEP or n <= 1:
		curr_frame = 0
		return
	var dur: float = state_frame_durations.get(current_state, FRAME_DURATION.get(current_state, 0.15))
	frame_timer += delta
	while frame_timer >= dur:
		frame_timer -= dur
		curr_frame = (curr_frame + 1) % n


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
	if rows <= 1:
		frame = curr_frame
		return

	var columns: int = maxi(n, int(state_column_counts.get(current_state, n)))
	var row: int = _direction_row(_global_basis, camera, rows)
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
