class_name TacticsPawnSprite
extends Sprite3D
## Handles the visual representation and animation of a pawn in the tactics game.
##
## Multi-state sprite animator. Loads up to 5 textures per pawn following a naming
## convention derived from stats.sprite — idle is the base path, walk/hurt/sleep/hop
## are sidecar PNGs with _walk/_hurt/_sleep/_hop suffixes. Each texture is laid out as
## hframes=N (frame count for that anim) x vframes=2 (top=front-pose, bottom=back-pose).
## Frame index is advanced over time by [code]_process[/code]; row (front/back) is
## chosen each frame by [code]rotate_sprite[/code] based on camera-vs-pawn facing.

## Animation state names
const ANIM_IDLE: String = "idle"
const ANIM_WALK: String = "walk"
const ANIM_HURT: String = "hurt"
const ANIM_SLEEP: String = "sleep"
const ANIM_HOP: String = "hop"

## Seconds per displayed frame for each animation state. Tuned for legibility,
## not perfectly faithful to AnimData.xml's per-frame tick durations.
const FRAME_DURATION: Dictionary = {
	ANIM_IDLE: 0.18,
	ANIM_WALK: 0.10,
	ANIM_HURT: 0.10,
	ANIM_SLEEP: 0.55,
	ANIM_HOP:  0.07,
}

const SPRITE_ROW_COUNT: int = 2
const DEFAULT_CHARACTER_CENTER_Y: float = 0.602
const DEFAULT_FRAME_CELL_PX: float = 128.0
const DEFAULT_FRAME_BOTTOM_PADDING_PX: float = 8.0
const DEFAULT_PIXEL_SIZE: float = 0.01
const DEFAULT_VISIBLE_FOOT_Y: float = (
	DEFAULT_CHARACTER_CENTER_Y
	- (DEFAULT_FRAME_CELL_PX * DEFAULT_PIXEL_SIZE * 0.5)
	+ (DEFAULT_FRAME_BOTTOM_PADDING_PX * DEFAULT_PIXEL_SIZE)
)

## Animation state machine playback controller (kept for compatibility with the
## existing AnimationTree that drives the JUMP Y-arc).
var animator: AnimationNodeStateMachinePlayback = null

## Loaded textures per anim state, indexed by ANIM_* constants. Missing states
## fall back to ANIM_IDLE in [code]_apply_state_texture[/code].
var state_textures: Dictionary = {}
## Frame count per state (hframes of the loaded texture).
var state_frame_counts: Dictionary = {}
## Square frame cell size per state, in source pixels.
var state_cell_sizes: Dictionary = {}
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


## Sets up the pawn sprite with the given stats and expertise
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

	_load_state_textures(stats.sprite)
	_apply_state_texture(ANIM_IDLE)
	character_ui_name_label.text = stats.override_name if stats.override_name else expertise


## Loads up to 5 textures based on the base sprite path. The base path itself
## is treated as the IDLE texture; sidecar paths follow the
## [code]<base>_<state>.png[/code] convention. States with no file are silently
## skipped and fall back to IDLE at render time.
func _load_state_textures(base_sprite_path: String) -> void:
	var base_no_ext: String = base_sprite_path.get_basename()
	var ext: String = "." + base_sprite_path.get_extension()

	var paths: Dictionary = {
		ANIM_IDLE:  base_sprite_path,
		ANIM_WALK:  base_no_ext + "_walk"  + ext,
		ANIM_HURT:  base_no_ext + "_hurt"  + ext,
		ANIM_SLEEP: base_no_ext + "_sleep" + ext,
		ANIM_HOP:   base_no_ext + "_hop"   + ext,
	}

	for state: String in paths.keys():
		var path: String = paths[state]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if not tex:
			continue
		state_textures[state] = tex
		# Each cell is square; hframes = texture_width / cell_height.
		# Cell size = texture_height / vframes_assumed (2).
		var cell: int = tex.get_height() / SPRITE_ROW_COUNT
		state_frame_counts[state] = maxi(1, tex.get_width() / cell)
		state_cell_sizes[state] = cell
		state_bottom_paddings[state] = _find_lowest_bottom_padding(tex, cell, state_frame_counts[state])


## Switches the displayed texture and updates hframes/vframes to match. Reset
## frame index and timer so the new animation starts at frame 0.
func _apply_state_texture(state: String) -> void:
	if not state_textures.has(state):
		state = ANIM_IDLE
	if not state_textures.has(state):
		return # No textures at all loaded — leave Sprite3D blank.
	var tex: Texture2D = state_textures[state]
	texture = tex
	vframes = SPRITE_ROW_COUNT
	hframes = state_frame_counts[state]
	_apply_grounding_offset(state)
	current_state = state
	curr_frame = 0
	frame_timer = 0.0


## Keeps the visible feet on the same world baseline used by the original
## 128x128 default pawn frames, even when replacement sheets use larger cells.
func _apply_grounding_offset(state: String) -> void:
	var cell: float = float(state_cell_sizes.get(state, DEFAULT_FRAME_CELL_PX))
	var bottom_padding: float = float(state_bottom_paddings.get(state, DEFAULT_FRAME_BOTTOM_PADDING_PX))
	var current_visible_foot_y: float = (
		DEFAULT_CHARACTER_CENTER_Y
		- (cell * pixel_size * 0.5)
		+ (bottom_padding * pixel_size)
	)
	offset.y = (DEFAULT_VISIBLE_FOOT_Y - current_visible_foot_y) / pixel_size


## Returns the smallest bottom padding among all rows and frames. Using the
## lowest opaque pixel prevents tall action frames from sinking into the tile.
func _find_lowest_bottom_padding(tex: Texture2D, cell: int, frames: int) -> int:
	var image: Image = tex.get_image()
	if not image:
		return int(DEFAULT_FRAME_BOTTOM_PADDING_PX)
	if image.is_compressed() and image.decompress() != OK:
		return int(DEFAULT_FRAME_BOTTOM_PADDING_PX)

	var lowest_padding: int = cell
	var max_rows: int = mini(SPRITE_ROW_COUNT, image.get_height() / cell)
	var max_frames: int = mini(frames, image.get_width() / cell)

	for row: int in range(max_rows):
		var row_y: int = row * cell
		for frame_idx: int in range(max_frames):
			var frame_x: int = frame_idx * cell
			var frame_padding: int = _find_frame_bottom_padding(image, frame_x, row_y, cell)
			if frame_padding >= 0:
				lowest_padding = mini(lowest_padding, frame_padding)

	return 0 if lowest_padding == cell else lowest_padding


func _find_frame_bottom_padding(image: Image, frame_x: int, frame_y: int, cell: int) -> int:
	for y: int in range(cell - 1, -1, -1):
		for x: int in range(cell):
			if image.get_pixel(frame_x + x, frame_y + y).a > 0.0:
				return cell - 1 - y
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


## Rotates the sprite to face the camera and selects the appropriate frame
##
## @param _global_basis: The global basis of the pawn
func rotate_sprite(_global_basis: Basis) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	# Get forward vector of the camera (looking down the negative Z-axis)
	var _camera_forward: Vector3 = -camera.global_basis.z
	# Measure how much the pawn faces towards or away from camera
	var _scalar: float = _global_basis.z.dot(_camera_forward)
	# Determine if the sprite should be flipped horizontally
	flip_h = _global_basis.x.dot(_camera_forward) > 0
	# Pick row (top=front-pose, bottom=back-pose) and add the column offset.
	# Frame count is the current state's hframes.
	var n: int = state_frame_counts.get(current_state, 1)
	if _scalar < -0.306: # Pawn is facing away from camera
		frame = curr_frame
	elif _scalar > 0.306: # Facing towards camera
		frame = curr_frame + n
	# Note: If -0.306 <= scalar <= 0.306, the frame remains unchanged


## Adjusts the pawn's position to the center of its current tile
##
## @param pawn: The TacticsPawn to adjust
## @return: Whether the adjustment was successful
func adjust_to_center(pawn: TacticsPawn) -> bool:
	if pawn.get_tile() and not pawn.res.is_moving:
		pawn.global_position = pawn.get_tile().global_position
		return true
	return false
