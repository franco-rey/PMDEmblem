class_name PmdWindowStyle
extends StyleBox

var flat: StyleBoxFlat = null
var fill: Color = PmdStyle.NAVY
var frame_color: Color = PmdStyle.FRAME
var sheet: String = "menu"
var texture: ImageTexture = null
var baked_style: int = 0
var baked_color: int = 0
var flat_margins: Array[float] = [10.0, 8.0, 10.0, 8.0]


static func create(flat_style: StyleBoxFlat, fill_color: Color, frame: Color = PmdStyle.FRAME, sheet_kind: String = "menu") -> PmdWindowStyle:
	var style := PmdWindowStyle.new()
	style.flat = flat_style
	style.fill = fill_color
	style.frame_color = frame
	style.sheet = sheet_kind
	style.flat_margins = [flat_style.content_margin_left, flat_style.content_margin_top, flat_style.content_margin_right, flat_style.content_margin_bottom]
	style.refresh()
	return style


func refresh() -> void:
	var index: int = PmdStyle.active_sheet_style(sheet)
	var row: int = PmdStyle.active_border_color()
	var effective: Color = PmdStyle.effective_fill(fill)
	if flat != null:
		flat.bg_color = effective
	texture = PmdStyle.bake_sheet_texture(sheet, index, row, effective, frame_color) if index > 0 else null
	if texture == null:
		index = 0
	baked_style = index
	baked_color = row
	var inset: float = PmdStyle.sheet_inset(sheet)
	content_margin_left = flat_margins[0] if index == 0 else inset
	content_margin_top = flat_margins[1] if index == 0 else inset
	content_margin_right = flat_margins[2] if index == 0 else inset
	content_margin_bottom = flat_margins[3] if index == 0 else inset
	emit_changed()


func is_textured() -> bool:
	return baked_style > 0 and texture != null


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if not is_textured():
		if flat != null:
			flat.draw(to_canvas_item, rect)
		return
	var margin: float = float(PmdStyle.sheet_frame_px(sheet) + PmdStyle.sheet_guard_px(sheet))
	var frame := Vector2(margin, margin)
	var drawn: Rect2 = rect.grow(float(PmdStyle.sheet_overhang_px(sheet)))
	RenderingServer.canvas_item_add_nine_patch(to_canvas_item, drawn, Rect2(Vector2.ZERO, texture.get_size()), texture.get_rid(), frame, frame, RenderingServer.NINE_PATCH_TILE_FIT, RenderingServer.NINE_PATCH_TILE_FIT, true, Color.WHITE)


func _get_draw_rect(rect: Rect2) -> Rect2:
	if is_textured():
		return rect.grow(float(PmdStyle.sheet_overhang_px(sheet)))
	if flat == null:
		return rect
	return rect.grow(float(flat.shadow_size) + maxf(absf(flat.shadow_offset.x), absf(flat.shadow_offset.y)))
