class_name RosterCarousel
extends Control

signal picked(entry: Dictionary)

const ROW_HEIGHT: float = 62.0
const ROW_WIDTH: float = 264.0
const PORTRAIT_SIZE: float = 50.0
const VISIBLE_ROWS: int = 7
const CURVE_DEPTH: float = 86.0
const GLIDE_SPEED: float = 14.0
const WHEEL_STEP: float = 1.0
const HAPPY: String = "Happy"

var entries: Array[Dictionary] = []

var _rows: Array[Control] = []
var _offset: float = 0.0
var _target: float = 0.0
var _selected: int = -1


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(ROW_WIDTH + CURVE_DEPTH, ROW_HEIGHT * float(VISIBLE_ROWS))
	resized.connect(_layout_rows)
	set_process(true)


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


func selected_entry() -> Dictionary:
	return entries[_selected].duplicate() if _selected >= 0 and _selected < entries.size() else {}


func _build_row() -> Control:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	var panel := Panel.new()
	panel.name = "Plate"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(panel)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.position = Vector2(8.0, (ROW_HEIGHT - PORTRAIT_SIZE) * 0.5)
	portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	row.add_child(portrait)
	var label := Label.new()
	label.name = "Name"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(PORTRAIT_SIZE + 18.0, 0.0)
	label.size = Vector2(ROW_WIDTH - PORTRAIT_SIZE - 26.0, ROW_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	row.add_child(label)
	return row


func _process(delta: float) -> void:
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
	var centre: float = span * 0.5 - ROW_HEIGHT * 0.5
	var first: int = int(floor(_offset)) - int(_rows.size() / 2)
	for i in range(_rows.size()):
		var index: int = first + i
		var row: Control = _rows[i]
		if index < 0 or index >= entries.size():
			row.visible = false
			continue
		row.visible = true
		var distance: float = float(index) - _offset
		var y: float = centre + distance * ROW_HEIGHT
		var recede: float = clampf(absf(distance) / float(VISIBLE_ROWS / 2), 0.0, 1.0)
		var x: float = CURVE_DEPTH * (1.0 - recede * recede)
		row.position = Vector2(x, y)
		row.modulate.a = lerpf(1.0, 0.45, recede)
		_paint_row(row, entries[index], index == _selected)


func _paint_row(row: Control, entry: Dictionary, is_selected: bool) -> void:
	var label: Label = row.get_node("Name") as Label
	label.text = String(entry.get("label", ""))
	label.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD if is_selected else PmdStyle.TEXT_DIM)
	var plate: Panel = row.get_node("Plate") as Panel
	var fill: Color = PmdStyle.NAVY_LIGHT if is_selected else PmdStyle.NAVY_DEEP
	plate.add_theme_stylebox_override("panel", PmdStyle.window(fill, PmdStyle.FRAME, 2, 6))
	var portrait: TextureRect = row.get_node("Portrait") as TextureRect
	var slug: String = String(entry.get("slug", ""))
	var mood: String = HAPPY if is_selected and PortraitLibrary.has_expression(slug, HAPPY) else PortraitLibrary.NORMAL
	portrait.texture = PortraitLibrary.texture_for(slug, mood)


func _select(index: int, emit: bool) -> void:
	if entries.is_empty():
		return
	_selected = clampi(index, 0, entries.size() - 1)
	_target = float(_selected)
	_layout_rows()
	if emit:
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


func _row_at(point: Vector2) -> int:
	for i in range(_rows.size()):
		var row: Control = _rows[i]
		if not row.visible:
			continue
		if Rect2(row.position, Vector2(ROW_WIDTH, ROW_HEIGHT)).has_point(point):
			return int(floor(_offset)) - int(_rows.size() / 2) + i
	return -1
