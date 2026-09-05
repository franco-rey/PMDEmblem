class_name PmdHpBar
extends Control

var current: int = 0
var maximum: int = 1
var show_text: bool = true
var _label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(160, 14)
	if show_text:
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 24)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.offset_right = -4
		add_child(_label)
	_refresh()


func set_values(curr: int, max_value: int) -> void:
	current = maxi(0, curr)
	maximum = maxi(1, max_value)
	_refresh()


func _refresh() -> void:
	if _label != null:
		_label.text = "%d/%d" % [current, maximum]
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, PmdStyle.HP_BACK)
	var fraction: float = clampf(float(current) / float(maximum), 0.0, 1.0)
	var fill := Rect2(Vector2(2, 2), Vector2(maxf(0.0, (size.x - 4.0) * fraction), maxf(0.0, size.y - 4.0)))
	draw_rect(fill, PmdStyle.hp_color(fraction))
	draw_rect(rect, PmdStyle.FRAME_SOFT, false, 1.0)
