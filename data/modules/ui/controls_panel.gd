class_name ControlsPanel
extends MenuPanel

signal closed

const LABEL_WIDTH: float = 420.0
const KEY_FONT: int = PmdStyle.FONT_CAPTION
const KEY_HEIGHT: float = 38.0
const KEY_MIN_WIDTH: float = 38.0
const KEY_GAP: int = 6
const ROW_GAP: int = 4
const KEY_NAMES: Dictionary = {"Comma": ",", "Period": ".", "Slash": "/", "BracketLeft": "[", "BracketRight": "]", "Equal": "=", "Plus": "+", "Minus": "-", "Kp Add": "Numpad +", "Kp Subtract": "Numpad -", "Kp Enter": "Numpad Enter", "Escape": "Esc", "Left": "Left arrow", "Right": "Right arrow", "Up": "Up arrow", "Down": "Down arrow"}
const JOY_NAMES: Dictionary = {0: "Pad A", 1: "Pad B", 2: "Pad X", 3: "Pad Y", 4: "Pad Back", 5: "Pad Guide", 6: "Pad Start", 7: "Left stick click", 8: "Right stick click", 9: "Pad LB", 10: "Pad RB", 11: "D-pad up", 12: "D-pad down", 13: "D-pad left", 14: "D-pad right"}
const SECTIONS: Array = [
	["Camera", [
		["Move the camera", ["camera_forward", "camera_left", "camera_backwards", "camera_right"], []],
		["Turn 45 degrees", ["camera_rotate_left", "camera_rotate_right"], []],
		["Slow orbit (toggle)", ["camera_orbit_left", "camera_orbit_right"], []],
		["Zoom", ["camera_zoom_in", "camera_zoom_out"], ["Mouse wheel"]],
		["Top-down / angled view", ["camera_perspective"], []],
		["Free look", ["camera_free_look"], ["Hold and drag"]],
		["Edge panning (toggle)", ["toggle_edge_pan"], []],
	]],
	["Battle", [
		["Confirm", ["ui_accept"], []],
		["Cancel / pause menu", ["ui_cancel"], []],
		["Choose a square", ["ui_up", "ui_down", "ui_left", "ui_right"], []],
		["Choose a target", ["camera_left", "camera_right"], ["Left arrow", "Right arrow"]],
		["Danger zones", ["toggle_danger_zone"], ["Danger button"]],
		["Battle speed", ["battle_speed_1", "battle_speed_2", "battle_speed_3", "battle_speed_4", "battle_speed_5", "battle_speed_6"], []],
	]],
	["Multiverse", [
		["Timeline map", ["toggle_timeline_map"], []],
		["Previous / next board", ["board_prev", "board_next"], []],
		["Back to the board in play", ["board_present"], []],
		["Look at a board", [], ["Click it on the mini map or the timeline map"]],
	]],
	["Interface", [
		["Hide / show interface", ["toggle_interface"], []],
		["Inspect a unit", [], ["Hover", "Click to lock", "x to unlock"]],
		["Shrink / grow a dock", [], ["- and + on the dock header"]],
	]],
]

var close_button: Button = null
var _rows: Array[Dictionary] = []
var _scroll: ScrollContainer = null
var _grid: VBoxContainer = null


func _ready() -> void:
	super()
	name = "ControlsPanel"
	set_title("Controls")
	_scroll = scroll
	_grid = body
	_grid.add_theme_constant_override("separation", ROW_GAP)
	for section in SECTIONS:
		add_heading(String(section[0]))
		var entries: Array = section[1]
		for i in range(entries.size()):
			var entry: Array = entries[i]
			_grid.add_child(_row(String(entry[0]), _keys_for(entry[1], entry[2])))
			if i < entries.size() - 1:
				add_divider()
	close_button = add_footer_button("Back", "CloseButton", func() -> void: closed.emit())


func _row(caption: String, keys: Array[String]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(LABEL_WIDTH * PmdStyle.font_width_factor(), PmdStyle.ROW_HEIGHT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flow.add_theme_constant_override("h_separation", KEY_GAP)
	flow.add_theme_constant_override("v_separation", KEY_GAP)
	row.add_child(flow)
	for key in keys:
		flow.add_child(_key_chip(key))
	return row


static func _is_pad_key(text: String) -> bool:
	return text.begins_with("Pad ") or text.begins_with("D-pad") or text.ends_with("stick") or text.ends_with("stick click")


func _key_chip(text: String) -> PanelContainer:
	var pad: bool = _is_pad_key(text)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", PmdStyle.keycap(pad))
	chip.custom_minimum_size = Vector2(KEY_MIN_WIDTH, KEY_HEIGHT)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", KEY_FONT)
	label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM if pad else PmdStyle.TEXT_GOLD)
	chip.add_child(label)
	return chip


func focus_first() -> void:
	fit_to_viewport()
	if close_button != null and close_button.is_inside_tree():
		close_button.grab_focus()


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
			var is_pad: bool = _is_pad_key(text)
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
