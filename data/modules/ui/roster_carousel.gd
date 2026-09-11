class_name RosterCarousel
extends Control

signal picked(entry: Dictionary)
signal selection_changed(entry: Dictionary)

const ROW_HEIGHT: float = 92.0
const ROW_WIDTH: float = 440.0
const PORTRAIT_SIZE: float = 76.0
const VISIBLE_ROWS: int = 9
const CURVE_DEPTH: float = 128.0
const NAME_FONT_SIZE: int = 40
const GLIDE_SPEED: float = 14.0
const SPIN_SECONDS: float = 1.2
const WHEEL_STEP: float = 1.0
const HAPPY: String = "Happy"
const TICK_MS: int = 45
const DESIGN_HEIGHT: float = 1080.0
const MAX_ZOOM: float = 2.5

var entries: Array[Dictionary] = []

var _rows: Array[Control] = []
var _offset: float = 0.0
var _target: float = 0.0
var _selected: int = -1
var _spin_from: float = 0.0
var _spin_elapsed: float = -1.0
var _last_tick_ms: int = 0
var _last_tick_row: int = -1
var _zoom: float = 1.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_zoom()
	resized.connect(_layout_rows)
	if get_viewport() != null:
		get_viewport().size_changed.connect(_apply_zoom)
	set_process(true)


func zoom() -> float:
	return _zoom


func row_height() -> float:
	return ROW_HEIGHT * _zoom


func row_width() -> float:
	return ROW_WIDTH * _zoom


func portrait_size() -> float:
	return PORTRAIT_SIZE * _zoom


func curve_depth() -> float:
	return CURVE_DEPTH * _zoom


func _apply_zoom() -> void:
	var height: float = DESIGN_HEIGHT
	if is_inside_tree() and get_viewport() != null:
		height = get_viewport().get_visible_rect().size.y
	_zoom = clampf(height / DESIGN_HEIGHT, 1.0, MAX_ZOOM)
	custom_minimum_size = Vector2(row_width() + curve_depth(), row_height() * float(VISIBLE_ROWS))
	for row in _rows:
		_size_row(row)
	_layout_rows()


func _size_row(row: Control) -> void:
	row.custom_minimum_size = Vector2(row_width(), row_height())
	row.size = row.custom_minimum_size
	var portrait: TextureRect = row.get_node("Portrait") as TextureRect
	portrait.position = Vector2(8.0 * _zoom, (row_height() - portrait_size()) * 0.5)
	portrait.size = Vector2(portrait_size(), portrait_size())
	var frame: Panel = row.get_node("PortraitFrame") as Panel
	frame.position = portrait.position
	frame.size = portrait.size
	var label: Label = row.get_node("Name") as Label
	label.position = Vector2(portrait_size() + 18.0 * _zoom, 0.0)
	label.size = Vector2(row_width() - portrait_size() - 26.0 * _zoom, row_height())
	label.add_theme_font_size_override("font_size", int(round(NAME_FONT_SIZE * _zoom)))


func set_entries(source: Array[Dictionary]) -> void:
	entries = source.duplicate()
	for row in _rows:
		row.queue_free()
	_rows.clear()
	for i in range(mini(VISIBLE_ROWS + 2, entries.size())):
		var row: Control = _build_row()
		add_child(row)
		_rows.append(row)
	_offset = 0.0
	_target = 0.0
	if not entries.is_empty():
		_select(0, false)
	_layout_rows()


func select_index(index: int, emit: bool) -> void:
	_select(index, emit)
	_offset = _target
	_layout_rows()


func selected_index() -> int:
	return _selected


func selected_entry() -> Dictionary:
	return entries[_selected].duplicate() if _selected >= 0 and _selected < entries.size() else {}


func _build_row() -> Control:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Panel.new()
	panel.name = "Plate"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(panel)
	var frame := Panel.new()
	frame.name = "PortraitFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", PmdStyle.portrait_overlay())
	row.add_child(frame)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var label := Label.new()
	label.name = "Name"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	row.add_child(label)
	_size_row(row)
	return row


func spin_to_random() -> void:
	if entries.size() < 2:
		return
	var index: int = _selected
	while index == _selected:
		index = randi_range(0, entries.size() - 1)
	_selected = index
	_target = float(index)
	_spin_from = _offset
	_spin_elapsed = 0.0
	_layout_rows()


func _process(delta: float) -> void:
	if _spin_elapsed >= 0.0:
		_spin_elapsed += delta
		var t: float = clampf(_spin_elapsed / SPIN_SECONDS, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - t, 3.0)
		_offset = lerpf(_spin_from, _target, eased)
		if int(round(_offset)) != _last_tick_row:
			_last_tick_row = int(round(_offset))
			_tick()
		_layout_rows()
		if t >= 1.0:
			_spin_elapsed = -1.0
			_offset = _target
			selection_changed.emit(selected_entry())
			picked.emit(selected_entry())
		return
	if is_equal_approx(_offset, _target):
		return
	_offset = lerpf(_offset, _target, clampf(delta * GLIDE_SPEED, 0.0, 1.0))
	if absf(_target - _offset) < 0.001:
		_offset = _target
	_layout_rows()


func _layout_rows() -> void:
	if entries.is_empty() or _rows.is_empty():
		return
	var span: float = maxf(size.y, custom_minimum_size.y)
	var centre: float = span * 0.5 - row_height() * 0.5
	var view: float = _view_offset()
	var first: int = int(floor(view)) - int(_rows.size() / 2)
	for i in range(_rows.size()):
		var index: int = first + i
		var row: Control = _rows[i]
		if index < 0 or index >= entries.size():
			row.visible = false
			continue
		row.visible = true
		var y: float = centre + (float(index) - view) * row_height()
		var distance: float = float(index) - _offset
		var recede: float = clampf(absf(distance) / float(VISIBLE_ROWS / 2), 0.0, 1.0)
		var x: float = curve_depth() * (1.0 - recede * recede)
		row.position = Vector2(x, y)
		row.modulate.a = lerpf(1.0, 0.45, recede)
		_paint_row(row, entries[index], index == _selected)


func _view_offset() -> float:
	return _offset


func _paint_row(row: Control, entry: Dictionary, is_selected: bool) -> void:
	var label: Label = row.get_node("Name") as Label
	label.text = String(entry.get("label", ""))
	label.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD if is_selected else PmdStyle.TEXT_DIM)
	var plate: Panel = row.get_node("Plate") as Panel
	plate.add_theme_stylebox_override("panel", PmdStyle.plate("hover" if is_selected else "normal"))
	var portrait: TextureRect = row.get_node("Portrait") as TextureRect
	var slug: String = String(entry.get("slug", ""))
	portrait.visible = not slug.is_empty()
	(row.get_node("PortraitFrame") as Panel).visible = portrait.visible
	label.position.x = portrait_size() + 18.0 * _zoom if portrait.visible else 18.0 * _zoom
	label.size.x = row_width() - label.position.x - 8.0 * _zoom
	if portrait.visible:
		var mood: String = HAPPY if is_selected and PortraitLibrary.has_expression(slug, HAPPY) else PortraitLibrary.NORMAL
		portrait.texture = PortraitLibrary.texture_for(slug, mood)


func _select(index: int, emit: bool) -> void:
	if entries.is_empty():
		return
	_spin_elapsed = -1.0
	var previous: int = _selected
	_selected = clampi(index, 0, entries.size() - 1)
	_target = float(_selected)
	_layout_rows()
	if _selected != previous:
		_tick()
		selection_changed.emit(selected_entry())
	if emit:
		SoundPlayer.cue("ui.confirm")
		picked.emit(selected_entry())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(_selected - int(WHEEL_STEP), false)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(_selected + int(WHEEL_STEP), false)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			var hit: int = _row_at(button.position)
			if hit >= 0:
				_select(hit, true)
			accept_event()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var key: InputEventKey = event
		if key.keycode == KEY_UP:
			_select(_selected - 1, false)
			accept_event()
		elif key.keycode == KEY_DOWN:
			_select(_selected + 1, false)
			accept_event()
		elif key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
			_select(_selected, true)
			accept_event()


func _tick() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_tick_ms < TICK_MS:
		return
	_last_tick_ms = now
	SoundPlayer.cue("ui.cursor")


func _row_at(point: Vector2) -> int:
	for i in range(_rows.size()):
		var row: Control = _rows[i]
		if not row.visible:
			continue
		if Rect2(row.position, Vector2(row_width(), row_height())).has_point(point):
			return int(floor(_view_offset())) - int(_rows.size() / 2) + i
	return -1
