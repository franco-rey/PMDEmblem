class_name TacticsPawnSprite
extends Sprite3D
## Handles the visual representation and animation of a pawn in the tactics game.
##
## Multi-state, multi-direction sprite animator. Each sprite state (idle/walk
## /hurt/sleep/hop) is a separate sheet shipped under
## `assets/textures/actor/pokemon/<dex>_<slug>/`. Sheets follow the standard
## SpriteCollab layout: hframes = frames-per-direction, vframes = 8 facings
## arranged in PMD order (Down, DownRight, Right, UpRight, Up, UpLeft, Left,
## DownLeft). Sleep is the only state that is single-direction (vframes = 1).
##
## Per-state cell width/height come from the species' `AnimData.xml` sidecar
## (referenced via `PokemonSpriteSetResource.anim_data_path`); falling back
## to texture-aspect heuristics keeps the legacy 2-row sheets renderable.
## Frame timing is advanced in `_process`; the displayed cell is chosen each
## frame in `rotate_sprite` by bucketing the camera-relative pawn facing into
## one of 8 directions (or row 0 for single-direction sheets).

## Animation state names
const ANIM_IDLE: String = "idle"
const ANIM_WALK: String = "walk"
const ANIM_HURT: String = "hurt"
const ANIM_SLEEP: String = "sleep"
const ANIM_HOP: String = "hop"

## Mapping from our internal lowercase state to the AnimData.xml `<Name>` field.
const ANIMDATA_NAMES: Dictionary = {
	ANIM_IDLE: "Idle",
	ANIM_WALK: "Walk",
	ANIM_HURT: "Hurt",
	ANIM_SLEEP: "Sleep",
	ANIM_HOP: "Hop",
}

## Seconds per displayed frame for each animation state. Tuned for legibility,
## not perfectly faithful to AnimData.xml's per-frame tick durations.
const FRAME_DURATION: Dictionary = {
	ANIM_IDLE: 0.18,
	ANIM_WALK: 0.10,
	ANIM_HURT: 0.10,
	ANIM_SLEEP: 0.55,
	ANIM_HOP:  0.07,
}

## Default cell dims used when no AnimData is available (e.g., legacy 2-row
## placeholder sheets). The renderer treats height/2 as the cell side then.
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

## Sprite-row indices for the 8 facings, in the order the user confirmed:
## Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft. Index 0 is
## "pawn faces the camera"; index advances clockwise from above as the pawn
## rotates away. Sheets with vframes == 1 (Sleep) ignore this and always use
## row 0.
const DIRECTION_COUNT: int = 8

## Animation state machine playback controller (kept for compatibility with the
## existing AnimationTree that drives the JUMP Y-arc).
var animator: AnimationNodeStateMachinePlayback = null

## Loaded textures per anim state, indexed by ANIM_* constants. Missing states
## fall back to ANIM_IDLE in [code]_apply_state_texture[/code].
var state_textures: Dictionary = {}
## Frame count per state (hframes of the loaded texture).
var state_frame_counts: Dictionary = {}
## Number of vertical rows per state. 8 for typical SpriteCollab sheets, 1 for
## Sleep (single-direction). Used to decide whether `rotate_sprite` selects a
## direction row or always uses row 0.
var state_row_counts: Dictionary = {}
## Per-state cell width in source pixels.
var state_cell_widths: Dictionary = {}
## Per-state cell height in source pixels.
var state_cell_heights: Dictionary = {}
## Lowest transparent padding per state, in source pixels.
var state_bottom_paddings: Dictionary = {}

## Currently active anim state.
var current_state: String = ANIM_IDLE
## Current frame within current_state (0..state_frame_counts[current_state]-1).
var curr_frame: int = 0
## Time accumulator since the last frame advance.
var frame_timer: float = 0.0

## Reference to the AnimationTree node
@onready var animation_tree: AnimationTree = $AnimationTree
## Reference to the Label3D node displaying the pawn's name
@onready var character_ui_name_label: Label3D = $CharacterUI/NameLabel


## Sets up the pawn sprite with the given stats and expertise.
##
## Pulls the full `PokemonSpriteSetResource` (including the AnimData.xml
## sidecar) from `stats.pokemon_instance` when available so per-state cell
## sizing follows the species' actual sheet layout. Legacy non-Pokemon stats
## fall back to filename-convention loading off `stats.sprite`.
##
## @param stats: The Stats resource containing pawn data
## @param expertise: The pawn's expertise (class or type)
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


## Loads per-state textures. Prefers the explicit per-state paths in the
## sprite-set resource when supplied; otherwise derives sidecar paths from
## the idle PNG filename. Cell dims come from AnimData where available so
## non-square cells (typical of SpriteCollab) are sliced correctly.
func _load_state_textures(base_sprite_path: String, sprite_set: PokemonSpriteSetResource, anim_data: Dictionary) -> void:
	var paths: Dictionary = _resolve_state_paths(base_sprite_path, sprite_set)

	for state: String in paths.keys():
		var path: String = paths[state]
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue
		state_textures[state] = tex

		var cell_w: int = 0
		var cell_h: int = 0
		var anim_name: String = String(ANIMDATA_NAMES.get(state, ""))
		if not anim_name.is_empty() and anim_data.has(anim_name):
			var entry: SpriteAnimData.AnimEntry = anim_data[anim_name]
			cell_w = entry.frame_width
			cell_h = entry.frame_height
		if cell_w <= 0 or cell_h <= 0:
			# Fallback: assume the legacy 2-row, square-cell layout.
			cell_h = int(tex.get_height() / SPRITE_ROW_COUNT_FALLBACK)
			cell_w = cell_h

		var hframes_local: int = maxi(1, int(tex.get_width() / max(1, cell_w)))
		var vframes_local: int = maxi(1, int(tex.get_height() / max(1, cell_h)))
		state_frame_counts[state] = hframes_local
		state_row_counts[state] = vframes_local
		state_cell_widths[state] = cell_w
		state_cell_heights[state] = cell_h
		state_bottom_paddings[state] = _find_lowest_bottom_padding(tex, cell_w, cell_h, hframes_local, vframes_local)


func _resolve_state_paths(base_sprite_path: String, sprite_set: PokemonSpriteSetResource) -> Dictionary:
	if sprite_set != null and not sprite_set.idle_path.is_empty():
		return {
			ANIM_IDLE:  sprite_set.idle_path,
			ANIM_WALK:  sprite_set.walk_path,
			ANIM_HURT:  sprite_set.hurt_path,
			ANIM_SLEEP: sprite_set.sleep_path,
			ANIM_HOP:   sprite_set.hop_path,
		}
	# Legacy non-Pokemon fallback - derive sidecars from base path filename.
	var base_no_ext: String = base_sprite_path.get_basename()
	var ext: String = "." + base_sprite_path.get_extension()
	return {
		ANIM_IDLE:  base_sprite_path,
		ANIM_WALK:  base_no_ext + "_walk"  + ext,
		ANIM_HURT:  base_no_ext + "_hurt"  + ext,
		ANIM_SLEEP: base_no_ext + "_sleep" + ext,
		ANIM_HOP:   base_no_ext + "_hop"   + ext,
	}


## Switches the displayed texture and updates hframes/vframes to match. Reset
## frame index and timer so the new animation starts at frame 0.
func _apply_state_texture(state: String) -> void:
	if not state_textures.has(state):
		state = ANIM_IDLE
	if not state_textures.has(state):
		return # No textures at all loaded — leave Sprite3D blank.
	var tex: Texture2D = state_textures[state]
	texture = tex
	vframes = int(state_row_counts.get(state, 1))
	hframes = int(state_frame_counts.get(state, 1))
	_apply_grounding_offset(state)
	current_state = state
	curr_frame = 0
	frame_timer = 0.0
	# 8-direction sheets encode left/right as distinct rows, so the legacy
	# flip_h trick is no longer needed (and would mirror the wrong row when on).
	flip_h = false


## Keeps the visible feet on the same world baseline used by the original
## 128x128 default pawn frames, even when replacement sheets use larger cells.
## Uses the per-state cell HEIGHT - SpriteCollab cells are taller than wide.
func _apply_grounding_offset(state: String) -> void:
	var cell_h: float = float(state_cell_heights.get(state, DEFAULT_FRAME_CELL_PX))
	var bottom_padding: float = float(state_bottom_paddings.get(state, DEFAULT_FRAME_BOTTOM_PADDING_PX))
	var current_visible_foot_y: float = (
		DEFAULT_CHARACTER_CENTER_Y
		- (cell_h * pixel_size * 0.5)
		+ (bottom_padding * pixel_size)
	)
	offset.y = (DEFAULT_VISIBLE_FOOT_Y - current_visible_foot_y) / pixel_size


## Returns the smallest bottom padding among all rows and frames. Using the
## lowest opaque pixel prevents tall action frames from sinking into the tile.
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


## Sets the current animation state. Called by the pawn service every frame.
## No-op if already in [param new_state]; switches texture otherwise.
func set_anim_state(new_state: String) -> void:
	if new_state == current_state:
		return
	_apply_state_texture(new_state)


## Advances curr_frame on a per-state timer. Called from [code]_process[/code]
## so animation continues independently of physics ticks.
func _process(delta: float) -> void:
	var n: int = state_frame_counts.get(current_state, 1)
	if n <= 1:
		curr_frame = 0
		return
	var dur: float = FRAME_DURATION.get(current_state, 0.15)
	frame_timer += delta
	while frame_timer >= dur:
		frame_timer -= dur
		curr_frame = (curr_frame + 1) % n


## Starts the appropriate animation on the AnimationTree (still drives the
## existing JUMP Y-position arc; sprite frames are now state-driven separately).
##
## @param move_direction: The direction the pawn is moving in
## @param is_jumping: Whether the pawn is currently jumping
func start_animator(move_direction: Vector3, is_jumping: bool) -> void:
	if move_direction == Vector3.ZERO:
		animator.travel("IDLE")
	elif is_jumping:
		animator.travel("JUMP")


## Selects the sprite cell for this frame.
##
## For 8-direction sheets, picks the row based on the camera-relative pawn
## facing (bucketing into the standard PMD order Down, DownRight, Right, ...).
## For single-direction sheets (vframes == 1, e.g. Sleep), always renders
## row 0. Never enters a dead zone: side-on camera views still advance frames
## continuously, which was the freeze bug in the 2-row implementation.
##
## @param _global_basis: The global basis of the pawn
func rotate_sprite(_global_basis: Basis) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var n: int = state_frame_counts.get(current_state, 1)
	var rows: int = int(state_row_counts.get(current_state, 1))
	if rows <= 1:
		# Single-direction sheets: just animate the column.
		frame = curr_frame
		return

	var row: int = _direction_row(_global_basis, camera, rows)
	frame = row * n + curr_frame


## Computes which of [param rows] facings the camera should see, given the
## pawn's `global_basis` and the active camera. Buckets the horizontal angle
## between the pawn's facing direction and the camera-to-pawn direction, mapping to
## the PMD row order: 0 = Down (faces camera), advancing counter-clockwise from
## above to DownRight, Right, UpRight, Up (back), UpLeft, Left, DownLeft.
func _direction_row(pawn_basis: Basis, camera: Camera3D, rows: int) -> int:
	var to_cam_xz: Vector3 = -camera.global_basis.z
	to_cam_xz.y = 0.0
	var pawn_facing_xz: Vector3 = pawn_basis.z
	pawn_facing_xz.y = 0.0
	if to_cam_xz.length() < 0.0001 or pawn_facing_xz.length() < 0.0001:
		return 0
	to_cam_xz = to_cam_xz.normalized()
	pawn_facing_xz = pawn_facing_xz.normalized()

	# This codebase has historically treated +basis.z as the pawn's facing
	# direction; keep sprite rows aligned with movement and authored spawns.
	# `to_cam_xz` is camera_forward; its negation is the "to camera" direction.
	var to_camera: Vector3 = -to_cam_xz
	var cos_theta: float = pawn_facing_xz.dot(to_camera)
	# Signed by world up so positive follows SpriteCollab's row handedness.
	var cross_y: float = to_camera.cross(pawn_facing_xz).y
	var angle_ccw: float = atan2(cross_y, cos_theta)
	if angle_ccw < 0.0:
		angle_ccw += TAU
	var bucket_size: float = TAU / float(rows)
	return int(round(angle_ccw / bucket_size)) % rows


## Adjusts the pawn's position to the center of its current tile
##
## @param pawn: The TacticsPawn to adjust
## @return: Whether the adjustment was successful
func adjust_to_center(pawn: TacticsPawn) -> bool:
	if pawn.get_tile() and not pawn.res.is_moving:
		pawn.global_position = pawn.get_tile().global_position
		return true
	return false
