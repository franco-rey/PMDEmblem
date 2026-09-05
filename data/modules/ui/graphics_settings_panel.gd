class_name GraphicsSettingsPanel
extends PanelContainer

signal closed

const ROW_HEIGHT: float = 48.0
const PANEL_WIDTH: float = 620.0

var mode_picker: OptionButton = null
var resolution_picker: OptionButton = null
var scale_picker: OptionButton = null
var vsync_toggle: CheckButton = null
var close_button: Button = null
var status_label: Label = null


func _ready() -> void:
	name = "GraphicsSettingsPanel"
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	add_theme_stylebox_override("panel", PmdStyle.window())
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Graphics"
	PmdStyle.apply_title(title, 40)
	column.add_child(title)
	mode_picker = _picker(column, "Window mode")
	for mode in GameSettings.WINDOW_MODES:
		mode_picker.add_item(GameSettings.window_mode_label(mode))
	resolution_picker = _picker(column, "Resolution")
	for size in GameSettings.RESOLUTIONS:
		resolution_picker.add_item(GameSettings.resolution_label(size))
	scale_picker = _picker(column, "UI scale")
	for value in GameSettings.UI_SCALES:
		scale_picker.add_item(GameSettings.ui_scale_label(value))
	var vsync_row := HBoxContainer.new()
	vsync_row.custom_minimum_size.y = ROW_HEIGHT
	column.add_child(vsync_row)
	var vsync_label := Label.new()
	vsync_label.text = "VSync"
	vsync_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vsync_row.add_child(vsync_label)
	vsync_toggle = CheckButton.new()
	vsync_toggle.name = "VsyncToggle"
	vsync_row.add_child(vsync_toggle)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	status_label.text = "Changes apply immediately and are saved."
	column.add_child(status_label)
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Back"
	close_button.custom_minimum_size.y = ROW_HEIGHT
	column.add_child(close_button)
	mode_picker.item_selected.connect(_on_mode_selected)
	resolution_picker.item_selected.connect(_on_resolution_selected)
	scale_picker.item_selected.connect(_on_scale_selected)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	close_button.pressed.connect(func() -> void: closed.emit())
	refresh()


func refresh() -> void:
	mode_picker.select(maxi(0, GameSettings.WINDOW_MODES.find(GameSettings.window_mode)))
	resolution_picker.select(maxi(0, GameSettings.RESOLUTIONS.find(GameSettings.resolution)))
	scale_picker.select(maxi(0, GameSettings.UI_SCALES.find(GameSettings.ui_scale)))
	vsync_toggle.set_pressed_no_signal(GameSettings.vsync)
	resolution_picker.disabled = GameSettings.window_mode != "windowed"


func focus_first() -> void:
	if mode_picker != null and mode_picker.is_inside_tree():
		mode_picker.grab_focus()


func _picker(column: VBoxContainer, caption: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	column.add_child(row)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker := OptionButton.new()
	picker.name = "%sPicker" % caption.replace(" ", "")
	picker.custom_minimum_size = Vector2(280, ROW_HEIGHT)
	row.add_child(picker)
	return picker


func _apply_and_save() -> void:
	GameSettings.apply(get_window())
	GameSettings.save_settings()
	refresh()


func _on_mode_selected(index: int) -> void:
	GameSettings.window_mode = GameSettings.WINDOW_MODES[clampi(index, 0, GameSettings.WINDOW_MODES.size() - 1)]
	_apply_and_save()


func _on_resolution_selected(index: int) -> void:
	GameSettings.resolution = GameSettings.RESOLUTIONS[clampi(index, 0, GameSettings.RESOLUTIONS.size() - 1)]
	_apply_and_save()


func _on_scale_selected(index: int) -> void:
	GameSettings.ui_scale = GameSettings.UI_SCALES[clampi(index, 0, GameSettings.UI_SCALES.size() - 1)]
	_apply_and_save()


func _on_vsync_toggled(pressed: bool) -> void:
	GameSettings.vsync = pressed
	_apply_and_save()
