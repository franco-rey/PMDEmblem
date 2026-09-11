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
		_label.add_theme_font_size_override("font_size", PmdStyle.FONT_CAPTION)
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
		_label.visible = not PmdStyle.hp_bar_is_pmd()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_inside_tree():
		_refresh()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var fraction: float = clampf(float(current) / float(maximum), 0.0, 1.0)
	if PmdStyle.hp_bar_is_pmd():
		_draw_pmd(fraction)
		return
	draw_rect(rect, PmdStyle.HP_BACK)
	var fill := Rect2(Vector2(2, 2), Vector2(maxf(0.0, (size.x - 4.0) * fraction), maxf(0.0, size.y - 4.0)))
	draw_rect(fill, PmdStyle.hp_color(fraction))
	draw_rect(rect, PmdStyle.FRAME_SOFT, false, 1.0)


func _draw_pmd(fraction: float) -> void:
	var glyph_scale: float = clampf(floorf(size.y / float(PmdStyle.HP_GLYPH_PX)), 1.0, 3.0)
	var text: String = "%d/%d" % [current, maximum]
	var text_width: float = PmdStyle.hp_text_width(text, glyph_scale) + 6.0 if show_text else 0.0
	var bar_height: float = minf(size.y, 4.0 * glyph_scale)
	var bar := Rect2(Vector2(0.0, (size.y - bar_height) * 0.5), Vector2(maxf(0.0, size.x - text_width), bar_height))
	draw_texture_rect(PmdStyle.mini_hp_texture(), bar, false, PmdStyle.FRAME)
	var inset: float = bar_height * 0.25
	var inner := Rect2(bar.position + Vector2(glyph_scale, inset), Vector2(maxf(0.0, (bar.size.x - glyph_scale * 2.0) * fraction), bar_height - inset * 2.0))
	if inner.size.x > 0.0:
		draw_rect(inner, PmdStyle.hp_color(fraction))
	if show_text:
		PmdStyle.draw_hp_text(self, text, Vector2(size.x, size.y * 0.5), glyph_scale)
