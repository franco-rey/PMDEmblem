class_name PauseMenu
extends CanvasLayer

signal resumed
signal restart_requested
signal lobby_requested
signal main_menu_requested
signal quit_requested

const LAYER_INDEX: int = 30
const BUTTON_HEIGHT: float = 56.0
const MENU_WIDTH: float = 420.0

var can_open: Callable = Callable()
var is_open: bool = false
var _dim: ColorRect = null
var _center: CenterContainer = null
var _menu: PanelContainer = null
var _graphics: GraphicsSettingsPanel = null
var _controls: ControlsPanel = null
var _buttons: Dictionary = {}


func _ready() -> void:
	name = "PauseMenu"
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_menu = PanelContainer.new()
	_menu.name = "Menu"
	_menu.custom_minimum_size = Vector2(MENU_WIDTH, 0)
	_menu.add_theme_stylebox_override("panel", PmdStyle.window())
	_center.add_child(_menu)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	_menu.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PmdStyle.apply_heading(title, 36)
	column.add_child(title)
	_add_button(column, "Resume", "ResumeButton", close)
	_add_button(column, "Restart Skirmish", "RestartButton", func() -> void: _leave(restart_requested))
	_add_button(column, "Return to Lobby", "LobbyButton", func() -> void: _leave(lobby_requested))
	_add_button(column, "Main Menu", "MainMenuButton", func() -> void: _leave(main_menu_requested))
	_add_button(column, "Options", "GraphicsButton", _show_graphics)
	_add_button(column, "Controls", "ControlsButton", _show_controls)
	_add_button(column, "Quit Game", "QuitButton", func() -> void: _leave(quit_requested))
	_graphics = GraphicsSettingsPanel.new()
	_graphics.visible = false
	_graphics.closed.connect(_hide_graphics)
	_graphics.controls_requested.connect(_show_controls)
	_center.add_child(_graphics)
	_controls = ControlsPanel.new()
	_controls.visible = false
	_controls.closed.connect(_hide_controls)
	_center.add_child(_controls)
	visible = false


func _input(event: InputEvent) -> void:
	var start_pressed: bool = event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	if not event.is_action_pressed("ui_cancel") and not start_pressed:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if is_open:
		SoundPlayer.cue("ui.cancel")
		if _graphics.visible:
			_hide_graphics()
		elif _controls.visible:
			_hide_controls()
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if can_open.is_valid() and bool(can_open.call()):
		SoundPlayer.cue("ui.pause_open")
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	MusicPlayer.duck(true)
	_menu.visible = true
	_graphics.visible = false
	_controls.visible = false
	get_tree().paused = true
	var resume: Button = _buttons.get("ResumeButton", null)
	if resume != null:
		resume.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	MusicPlayer.duck(false)
	get_tree().paused = false
	resumed.emit()


func _leave(signal_to_emit: Signal) -> void:
	close()
	signal_to_emit.emit()


func _show_graphics() -> void:
	_menu.visible = false
	_graphics.visible = true
	_graphics.refresh()
	_graphics.focus_first()


func _show_controls() -> void:
	_menu.visible = false
	_graphics.visible = false
	_controls.visible = true
	_controls.focus_first()


func _hide_controls() -> void:
	_controls.visible = false
	_menu.visible = true
	var button: Button = _buttons.get("ControlsButton", null)
	if button != null:
		button.grab_focus()


func _hide_graphics() -> void:
	_graphics.visible = false
	_menu.visible = true
	var button: Button = _buttons.get("GraphicsButton", null)
	if button != null:
		button.grab_focus()


func _add_button(column: VBoxContainer, text: String, node_name: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.pressed.connect(callback)
	column.add_child(button)
	_buttons[node_name] = button
