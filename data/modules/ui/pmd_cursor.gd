class_name PmdCursor
extends CanvasLayer

const BLINK_SECONDS: float = 0.45
const GAP: float = 6.0

static var _instance: PmdCursor = null

var _icon: TextureRect = null
var _time: float = 0.0


static func ensure(root: Window) -> PmdCursor:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	_instance = PmdCursor.new()
	_instance.name = "PmdCursor"
	root.add_child.call_deferred(_instance)
	return _instance


static func instance() -> PmdCursor:
	return _instance if _instance != null and is_instance_valid(_instance) else null


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.texture = PmdStyle.cursor_texture()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	add_child(_icon)
	set_process(true)


func is_showing() -> bool:
	return _icon != null and _icon.visible


func _process(delta: float) -> void:
	if _icon == null:
		return
	if _icon.texture == null:
		_icon.texture = PmdStyle.cursor_texture()
	if not GameSettings.menu_cursor or _icon.texture == null:
		_icon.visible = false
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null or not focus.is_visible_in_tree() or focus.get_window() != get_window():
		_icon.visible = false
		return
	_time += delta
	var rect: Rect2 = focus.get_global_rect()
	var icon_size: Vector2 = _icon.texture.get_size()
	_icon.size = icon_size
	_icon.position = Vector2(rect.position.x - icon_size.x - GAP, rect.position.y + (rect.size.y - icon_size.y) * 0.5)
	_icon.visible = fmod(_time, BLINK_SECONDS * 2.0) < BLINK_SECONDS * 1.4
