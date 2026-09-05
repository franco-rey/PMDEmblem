class_name SpectatorSpeedBar
extends CanvasLayer

signal speed_selected(value: float)

const LAYER_INDEX: int = 19
const BUTTON_SIZE: Vector2 = Vector2(88, 48)

var _panel: PanelContainer = null
var _buttons: Dictionary = {}


func _ready() -> void:
	name = "SpectatorSpeedBar"
	layer = LAYER_INDEX
	_panel = PanelContainer.new()
	_panel.name = "SpeedPanel"
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -16
	_panel.offset_bottom = -16
	_panel.add_theme_stylebox_override("panel", PmdStyle.window(PmdStyle.NAVY_DEEP, PmdStyle.FRAME_SOFT, 2, 6))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "Battle speed"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PmdStyle.apply_heading(title, 24)
	column.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	for value in GameSettings.CPU_SPEEDS:
		var button := Button.new()
		button.name = "Speed_%s" % GameSettings.cpu_speed_label(value).replace(".", "_")
		button.text = GameSettings.cpu_speed_label(value)
		button.custom_minimum_size = BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_pressed.bind(float(value)))
		row.add_child(button)
		_buttons[float(value)] = button
		TacticsConfig.register_hover_control(button)
	visible = false
	highlight(GameSettings.cpu_speed)


func highlight(value: float) -> void:
	for key in _buttons.keys():
		var button: Button = _buttons[key]
		button.disabled = is_equal_approx(float(key), value)


func _on_pressed(value: float) -> void:
	highlight(value)
	speed_selected.emit(value)
