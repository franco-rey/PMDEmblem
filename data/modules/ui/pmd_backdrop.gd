class_name PmdBackdrop
extends Control

const CLOUDS_PATH: String = "res://assets/visuals/raw_asset/BG/Clouds_Overhead.1.png"
const CLOUD_SCROLL: Vector2 = Vector2(-18.0, -11.0)
const SKY_SCROLL: Vector2 = Vector2(-3.0, 0.0)
const CLOUDY_SKIES: Array[String] = ["sky", "cloudy"]

static var _instances: Array[WeakRef] = []

var _scene: TextureRect = null
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
	_scene = TextureRect.new()
	_scene.name = "Scene"
	_scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene.visible = false
	add_child(_scene)
	_sky = _layer("Sky", "", Color(0.62, 0.70, 0.92, 1.0))
	_clouds = _layer("Clouds", CLOUDS_PATH, Color(1.0, 1.0, 1.0, 0.5))
	if _clouds.texture != null:
		_cloud_tile = _clouds.texture.get_size()
	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.color = Color(0.03, 0.05, 0.14, 0.42)
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	_instances.append(weakref(self))
	refresh()
	resized.connect(_layout)


static func refresh_all() -> void:
	var keep: Array[WeakRef] = []
	for ref in _instances:
		var backdrop: PmdBackdrop = ref.get_ref() as PmdBackdrop
		if backdrop == null:
			continue
		if backdrop.is_inside_tree():
			backdrop.refresh()
		keep.append(ref)
	_instances = keep


func refresh() -> void:
	var scene_path: String = PmdStyle.menu_backdrop_path(GameSettings.menu_backdrop)
	var scene_texture: Texture2D = null
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		scene_texture = load(scene_path) as Texture2D
	_scene.texture = scene_texture
	_scene.visible = scene_texture != null
	var sky_path: String = PmdStyle.sky_sheet_path(GameSettings.sky_backdrop)
	_sky.texture = load(sky_path) as Texture2D if ResourceLoader.exists(sky_path) else null
	_sky_tile = _sky.texture.get_size() if _sky.texture != null else Vector2(320, 240)
	_sky.visible = scene_texture == null
	_clouds.visible = scene_texture == null and CLOUDY_SKIES.has(GameSettings.sky_backdrop)
	if _tint != null:
		_tint.color = PmdStyle.active_palette().get("tint", _tint.color)
	_layout()


func has_scene() -> bool:
	return _scene != null and _scene.visible and _scene.texture != null


func sky_texture_path() -> String:
	return _sky.texture.resource_path if _sky != null and _sky.texture != null else ""


func _layer(layer_name: String, path: String, tint: Color) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	if not path.is_empty() and ResourceLoader.exists(path):
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
	if not _sky.visible:
		return
	_sky_offset += SKY_SCROLL * delta
	_cloud_offset += CLOUD_SCROLL * delta
	_sky_offset.x = fmod(_sky_offset.x, _sky_tile.x * _sky_scale())
	_cloud_offset.x = fmod(_cloud_offset.x, _cloud_tile.x)
	_cloud_offset.y = fmod(_cloud_offset.y, _cloud_tile.y)
	_place()
