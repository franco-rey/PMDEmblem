class_name PauseMenu
extends CanvasLayer

signal resumed
signal restart_requested
signal lobby_requested
signal main_menu_requested
signal quit_requested
signal resign_requested

const LAYER_INDEX: int = 30
const MENU_WIDTH: float = 480.0

var can_open: Callable = Callable()
var is_open: bool = false
var _dim: ColorRect = null
var _center: CenterContainer = null
var _menu: PanelContainer = null
var _graphics: GraphicsSettingsPanel = null
var _controls: ControlsPanel = null
var _customize: CustomizePanel = null
var _buttons: Dictionary = {}


var pauses_tree: bool = true
var resign_visible: bool = false
var network_battle: bool = false
var _confirm: PanelContainer = null
var _confirm_label: Label = null
var _confirm_action: Callable = Callable()


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
		margin.add_theme_constant_override("margin_%s" % side, PmdStyle.PANEL_MARGIN)
	_menu.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PmdStyle.apply_title(title, PmdStyle.FONT_TITLE)
	column.add_child(title)
	_add_button(column, "Resume", "ResumeButton", close)
	_add_button(column, "Restart Skirmish", "RestartButton", func() -> void: _leave(restart_requested))
	_add_button(column, "Resign", "ResignButton", func() -> void: _guarded_leave(resign_requested, "Resign this battle?"))
	_add_button(column, "Return to Lobby", "LobbyButton", func() -> void: _leave(lobby_requested))
	_add_button(column, "Main Menu", "MainMenuButton", func() -> void: _guarded_leave(main_menu_requested, "Leave the battle? Your opponent takes the win."))
	_add_button(column, "Options", "GraphicsButton", _show_graphics)
	_add_button(column, "Controls", "ControlsButton", _show_controls)
	_add_button(column, "Quit Game", "QuitButton", func() -> void: _guarded_leave(quit_requested, "Quit the game? Your opponent takes the win."))
	_build_confirm()
	_graphics = GraphicsSettingsPanel.new()
	_graphics.visible = false
	_graphics.closed.connect(_hide_graphics)
	_graphics.controls_requested.connect(_show_controls)
	_graphics.customize_requested.connect(_show_customize)
	_center.add_child(_graphics)
	_controls = ControlsPanel.new()
	_controls.visible = false
	_controls.closed.connect(_hide_controls)
	_customize = CustomizePanel.new()
	_customize.visible = false
	_customize.closed.connect(_hide_customize)
	_center.add_child(_customize)
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
		if _confirm.visible:
			_hide_confirm()
		elif _graphics.visible:
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
	_customize.visible = false
	_confirm.visible = false
	if pauses_tree:
		get_tree().paused = true
	var resign: Button = _buttons.get("ResignButton", null)
	if resign != null:
		resign.visible = resign_visible
	for node_name in ["RestartButton", "LobbyButton"]:
		var button: Button = _buttons.get(node_name, null)
		if button != null:
			button.visible = not network_battle
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


func _guarded_leave(signal_to_emit: Signal, question: String) -> void:
	if not network_battle:
		_leave(signal_to_emit)
		return
	_ask(question, func() -> void: _leave(signal_to_emit))


func _ask(question: String, action: Callable) -> void:
	_confirm_action = action
	_confirm_label.text = question
	_menu.visible = false
	_confirm.visible = true
	var no: Button = _buttons.get("ConfirmNoButton", null)
	if no != null:
		no.grab_focus()


func _hide_confirm() -> void:
	_confirm.visible = false
	_confirm_action = Callable()
	_menu.visible = true
	var resume: Button = _buttons.get("ResumeButton", null)
	if resume != null:
		resume.grab_focus()


func _confirm_yes() -> void:
	var action: Callable = _confirm_action
	_confirm_action = Callable()
	_confirm.visible = false
	if action.is_valid():
		action.call()


func _build_confirm() -> void:
	_confirm = PanelContainer.new()
	_confirm.name = "Confirm"
	_confirm.custom_minimum_size = Vector2(MENU_WIDTH + 120.0, 0)
	_confirm.add_theme_stylebox_override("panel", PmdStyle.window())
	_confirm.visible = false
	_center.add_child(_confirm)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, PmdStyle.PANEL_MARGIN)
	_confirm.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	margin.add_child(column)
	_confirm_label = Label.new()
	_confirm_label.name = "Question"
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PmdStyle.apply_heading(_confirm_label, PmdStyle.FONT_BODY)
	column.add_child(_confirm_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	column.add_child(row)
	var yes := PmdStyle.control_button("Yes", "ConfirmYesButton", _confirm_yes)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
	_buttons["ConfirmYesButton"] = yes
	var no := PmdStyle.control_button("No", "ConfirmNoButton", _hide_confirm)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
	_buttons["ConfirmNoButton"] = no


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
	_customize.visible = false
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


func _show_customize() -> void:
	_menu.visible = false
	_graphics.visible = false
	_customize.visible = true
	_customize.refresh()
	_customize.focus_first()


func _hide_customize() -> void:
	_customize.visible = false
	_graphics.visible = true
	_graphics.refresh()
	_graphics.focus_first()


func _add_button(column: VBoxContainer, text: String, node_name: String, callback: Callable) -> void:
	var button := PmdStyle.control_button(text, node_name, callback)
	column.add_child(button)
	_buttons[node_name] = button
