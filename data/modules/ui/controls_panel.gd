class_name ControlsPanel
extends PanelContainer

signal closed

const ROW_HEIGHT: float = 34.0
const PANEL_WIDTH: float = 760.0
const KEY_FONT: int = 24
const KEY_NAMES: Dictionary = {"BracketLeft": "[", "BracketRight": "]", "Equal": "=", "Plus": "+", "Minus": "-", "Kp Add": "Numpad +", "Kp Subtract": "Numpad -", "Kp Enter": "Numpad Enter", "Escape": "Esc", "Left": "Left arrow", "Right": "Right arrow", "Up": "Up arrow", "Down": "Down arrow"}
const JOY_NAMES: Dictionary = {0: "Pad A", 1: "Pad B", 2: "Pad X", 3: "Pad Y", 4: "Pad Back", 5: "Pad Guide", 6: "Pad Start", 7: "Left stick click", 8: "Right stick click", 9: "Pad LB", 10: "Pad RB", 11: "D-pad up", 12: "D-pad down", 13: "D-pad left", 14: "D-pad right"}
const SECTIONS: Array = [
	["Camera", [
		["Move the camera", ["camera_forward", "camera_left", "camera_backwards", "camera_right"], []],
		["Turn 45 degrees", ["camera_rotate_left", "camera_rotate_right"], []],
		["Slow orbit, press again to stop", ["camera_orbit_left", "camera_orbit_right"], []],
		["Zoom", ["camera_zoom_in", "camera_zoom_out"], ["Mouse wheel"]],
		["Top-down or angled view", ["camera_perspective"], []],
		["Free look", ["camera_free_look"], ["Hold and drag"]],
		["Edge panning on or off", ["toggle_edge_pan"], []],
	]],
	["Battle", [
		["Confirm", ["ui_accept"], []],
		["Cancel, or open the pause menu", ["ui_cancel"], []],
		["Choose a square", ["ui_up", "ui_down", "ui_left", "ui_right"], []],
		["Choose a target", ["camera_left", "camera_right"], ["Left arrow", "Right arrow"]],
		["Danger zones", ["toggle_danger_zone"], ["Danger button"]],
		["Battle speed, 0.5x to 20x", ["battle_speed_1", "battle_speed_2", "battle_speed_3", "battle_speed_4", "battle_speed_5", "battle_speed_6"], []],
	]],
	["Interface", [
		["Inspect a unit", [], ["Hover", "Click to lock", "x to unlock"]],
		["Shrink or grow a dock", [], ["- and + on the dock header"]],
	]],
]

var close_button: Button = null
var _rows: Array[Dictionary] = []
var _scroll: ScrollContainer = null
var _grid: VBoxContainer = null
var _fit_pending: bool = false


func _ready() -> void:
	name = "ControlsPanel"
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	add_theme_stylebox_override("panel", PmdStyle.window())
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Controls"
	PmdStyle.apply_heading(title, 36)
	column.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.name = "RowsScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_grid = VBoxContainer.new()
	_grid.name = "Rows"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("separation", 4)
	_scroll.add_child(_grid)
	for section in SECTIONS:
		var heading := Label.new()
		heading.text = String(section[0])
		heading.add_theme_font_size_override("font_size", 24)
		heading.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD)
		_grid.add_child(heading)
		for entry in section[1]:
			_grid.add_child(_row(String(entry[0]), _keys_for(entry[1], entry[2])))
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Back"
	close_button.custom_minimum_size.y = 48
	close_button.pressed.connect(func() -> void: closed.emit())
	column.add_child(close_button)


func _row(caption: String, keys: Array[String]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(300, ROW_HEIGHT)
	label.add_theme_font_size_override("font_size", KEY_FONT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	row.add_child(flow)
	for key in keys:
		flow.add_child(_key_chip(key))
	return row


func _key_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", PmdStyle.chip(PmdStyle.NAVY_LIGHT, PmdStyle.FRAME_SOFT))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", KEY_FONT)
	label.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD)
	chip.add_child(label)
	return chip


func focus_first() -> void:
	fit_to_viewport()
	if close_button != null and close_button.is_inside_tree():
		close_button.grab_focus()


func fit_to_viewport() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	custom_minimum_size.x = minf(PANEL_WIDTH, maxf(320.0, view.x - 40.0))
	var natural: float = maxf(_grid.get_combined_minimum_size().y, _grid.size.y)
	_scroll.custom_minimum_size.y = minf(natural, maxf(120.0, view.y - 200.0))
	reset_size()
	if not _fit_pending:
		_fit_pending = true
		call_deferred("_fit_again")


func _fit_again() -> void:
	_fit_pending = false
	if not is_inside_tree() or _grid == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var natural: float = maxf(_grid.get_combined_minimum_size().y, _grid.size.y)
	var wanted: float = minf(natural, maxf(120.0, view.y - 200.0))
	if not is_equal_approx(_scroll.custom_minimum_size.y, wanted):
		_scroll.custom_minimum_size.y = wanted
		reset_size()


func rows() -> Array[Dictionary]:
	if not _rows.is_empty():
		return _rows
	for section in SECTIONS:
		for entry in section[1]:
			_rows.append({"label": String(entry[0]), "keys": ", ".join(_keys_for(entry[1], entry[2]))})
	return _rows


func _keys_for(actions: Array, extra: Array) -> Array[String]:
	var names: Array[String] = []
	var pads: Array[String] = []
	for action in actions:
		for text in _action_keys(String(action)):
			var is_pad: bool = text.begins_with("Pad ") or text.begins_with("D-pad") or text.ends_with("stick") or text.ends_with("stick click")
			if is_pad and not pads.has(text):
				pads.append(text)
			elif not is_pad and not names.has(text):
				names.append(text)
	for text in extra:
		if not names.has(String(text)):
			names.append(String(text))
	names.append_array(pads)
	return names


static func _action_keys(action: String) -> Array[String]:
	var out: Array[String] = []
	if not InputMap.has_action(action):
		return out
	for event in InputMap.action_get_events(action):
		var text: String = _event_text(event)
		if not text.is_empty() and not out.has(text):
			out.append(text)
	return out


static func _event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code == 0:
			code = key.key_label
		var raw: String = OS.get_keycode_string(code)
		return String(KEY_NAMES.get(raw, raw))
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Left click"
			MOUSE_BUTTON_RIGHT:
				return "Right click"
			MOUSE_BUTTON_MIDDLE:
				return "Middle mouse"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel down"
		return "Mouse"
	if event is InputEventJoypadButton:
		var index: int = (event as InputEventJoypadButton).button_index
		return String(JOY_NAMES.get(index, "Pad %d" % index))
	if event is InputEventJoypadMotion:
		return "Left stick"
	return ""
