class_name BoardProp
extends Sprite3D

const FRAME_RATE: float = 6.0

var frames: int = 1
var cell_px: int = 24
var _clock: float = 0.0


func setup(sheet: Texture2D, frame_count: int, cell: int, pixel: float) -> void:
	texture = sheet
	frames = maxi(1, frame_count)
	cell_px = maxi(1, cell)
	hframes = frames
	vframes = 1
	frame = 0
	pixel_size = pixel
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = false
	set_process(frames > 1)


func half_height() -> float:
	return float(cell_px) * pixel_size * 0.5


func _process(delta: float) -> void:
	_clock += delta
	frame = int(_clock * FRAME_RATE) % frames
