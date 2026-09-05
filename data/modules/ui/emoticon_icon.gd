class_name EmoticonIcon
extends TextureRect

const FPS: float = 8.0

var status_id: String = ""
var _frames: int = 1
var _atlas: AtlasTexture = null
var _time: float = 0.0
var _cell: float = 0.0


func set_status(id: String, size_px: float = 32.0) -> bool:
	status_id = id
	var icon_name: String = String(StatusBadgeRow.EMOTICONS.get(id, ""))
	var path: String = "%s%s.None.png" % [StatusBadgeRow.ICON_DIR, icon_name]
	if icon_name.is_empty() or not ResourceLoader.exists(path):
		texture = null
		return false
	var sheet: Texture2D = load(path) as Texture2D
	_cell = float(sheet.get_height())
	_frames = maxi(1, int(floor(float(sheet.get_width()) / _cell)))
	_atlas = AtlasTexture.new()
	_atlas.atlas = sheet
	_atlas.region = Rect2(0, 0, _cell, _cell)
	texture = _atlas
	custom_minimum_size = Vector2(size_px, size_px)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = id.capitalize()
	return true


func set_sheet(path: String, size_px: float = 32.0) -> bool:
	if not ResourceLoader.exists(path):
		texture = null
		return false
	var sheet: Texture2D = load(path) as Texture2D
	_cell = float(sheet.get_height())
	_frames = maxi(1, int(floor(float(sheet.get_width()) / _cell)))
	_atlas = AtlasTexture.new()
	_atlas.atlas = sheet
	_atlas.region = Rect2(0, 0, _cell, _cell)
	texture = _atlas
	custom_minimum_size = Vector2(size_px, size_px)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return true


func _process(delta: float) -> void:
	if _atlas == null or _frames <= 1:
		return
	_time += delta
	var frame: int = int(floor(_time * FPS)) % _frames
	_atlas.region = Rect2(float(frame) * _cell, 0, _cell, _cell)
