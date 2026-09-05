class_name PmdBackdrop
extends Control

const SKY_PATH: String = "res://assets/visuals/raw_asset/BG/Sky.1.png"
const CLOUDS_PATH: String = "res://assets/visuals/raw_asset/BG/Clouds_Overhead.1.png"
const CLOUD_SCROLL: Vector2 = Vector2(-18.0, -11.0)
const SKY_SCROLL: Vector2 = Vector2(-3.0, 0.0)

var _sky: TextureRect = null
var _clouds: TextureRect = null
var _tint: ColorRect = null
var _sky_offset: Vector2 = Vector2.ZERO
var _cloud_offset: Vector2 = Vector2.ZERO
var _sky_tile: Vector2 = Vector2(320, 240)
var _cloud_tile: Vector2 = Vector2(768, 768)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_sky = _layer("Sky", SKY_PATH, Color(0.62, 0.70, 0.92, 1.0))
	if _sky.texture != null:
		_sky_tile = _sky.texture.get_size()
	_clouds = _layer("Clouds", CLOUDS_PATH, Color(1.0, 1.0, 1.0, 0.5))
	if _clouds.texture != null:
		_cloud_tile = _clouds.texture.get_size()
	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.color = Color(0.03, 0.05, 0.14, 0.42)
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	_layout()
	resized.connect(_layout)


func _layer(layer_name: String, path: String, tint: Color) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	if ResourceLoader.exists(path):
		layer.texture = load(path) as Texture2D
	layer.stretch_mode = TextureRect.STRETCH_TILE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.modulate = tint
	add_child(layer)
	return layer


func _sky_scale() -> float:
	return maxf(1.0, size.y / maxf(1.0, _sky_tile.y))


func _layout() -> void:
	var sky_scale: float = _sky_scale()
	_sky.scale = Vector2(sky_scale, sky_scale)
	_sky.size = Vector2(size.x / sky_scale + _sky_tile.x * 2.0, _sky_tile.y)
	_clouds.size = size + _cloud_tile * 2.0
	_place()


func _place() -> void:
	var sky_scale: float = _sky_scale()
	_sky.position = Vector2(-_sky_tile.x * sky_scale + _sky_offset.x, 0.0)
	_clouds.position = -_cloud_tile + _cloud_offset


func _process(delta: float) -> void:
	_sky_offset += SKY_SCROLL * delta
	_cloud_offset += CLOUD_SCROLL * delta
	_sky_offset.x = fmod(_sky_offset.x, _sky_tile.x * _sky_scale())
	_cloud_offset.x = fmod(_cloud_offset.x, _cloud_tile.x)
	_cloud_offset.y = fmod(_cloud_offset.y, _cloud_tile.y)
	_place()
