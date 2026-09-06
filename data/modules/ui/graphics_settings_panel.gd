class_name GraphicsSettingsPanel
extends PanelContainer

signal closed
signal controls_requested

const ROW_HEIGHT: float = 48.0
const PANEL_WIDTH: float = 620.0

var mode_picker: OptionButton = null
var resolution_picker: OptionButton = null
var scale_picker: OptionButton = null
var vsync_toggle: CheckButton = null
var camera_track_toggle: CheckButton = null
var cpu_report_toggle: CheckButton = null
var cpu_speed_picker: OptionButton = null
var battle_flair_toggle: CheckButton = null
var master_slider: HSlider = null
var sfx_slider: HSlider = null
var music_slider: HSlider = null
var _volume_labels: Dictionary = {}
var controls_button: Button = null
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
	title.text = "Options"
	PmdStyle.apply_heading(title, 36)
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
	camera_track_toggle = _toggle(column, "Camera Track", "CameraTrackToggle")
	cpu_report_toggle = _toggle(column, "Show Battle Report after CPU Battles", "CpuReportToggle")
	cpu_speed_picker = _picker(column, "Battle speed")
	for value in GameSettings.CPU_SPEEDS:
		cpu_speed_picker.add_item(GameSettings.cpu_speed_label(value))
	battle_flair_toggle = _toggle(column, "Battle Flair (intro, turn banners, notices)", "BattleFlairToggle")
	master_slider = _slider(column, "Master volume", "MasterVolumeSlider")
	sfx_slider = _slider(column, "Effects volume", "EffectsVolumeSlider")
	music_slider = _slider(column, "Music volume", "MusicVolumeSlider")
	controls_button = Button.new()
	controls_button.name = "ControlsButton"
	controls_button.text = "Controls"
	controls_button.custom_minimum_size.y = ROW_HEIGHT
	column.add_child(controls_button)
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
	camera_track_toggle.toggled.connect(_on_camera_track_toggled)
	cpu_report_toggle.toggled.connect(_on_cpu_report_toggled)
	cpu_speed_picker.item_selected.connect(_on_cpu_speed_selected)
	battle_flair_toggle.toggled.connect(_on_battle_flair_toggled)
	master_slider.value_changed.connect(_on_volume_changed.bind("master"))
	sfx_slider.value_changed.connect(_on_volume_changed.bind("sfx"))
	music_slider.value_changed.connect(_on_volume_changed.bind("music"))
	controls_button.pressed.connect(func() -> void: controls_requested.emit())
	close_button.pressed.connect(func() -> void: closed.emit())
	refresh()


func refresh() -> void:
	mode_picker.select(maxi(0, GameSettings.WINDOW_MODES.find(GameSettings.window_mode)))
	resolution_picker.select(maxi(0, GameSettings.RESOLUTIONS.find(GameSettings.resolution)))
	scale_picker.select(maxi(0, GameSettings.UI_SCALES.find(GameSettings.ui_scale)))
	vsync_toggle.set_pressed_no_signal(GameSettings.vsync)
	camera_track_toggle.set_pressed_no_signal(GameSettings.camera_track)
	cpu_report_toggle.set_pressed_no_signal(GameSettings.cpu_battle_report)
	cpu_speed_picker.select(maxi(0, GameSettings.CPU_SPEEDS.find(GameSettings.cpu_speed)))
	battle_flair_toggle.set_pressed_no_signal(GameSettings.battle_flair)
	_show_volume(master_slider, GameSettings.master_volume)
	_show_volume(sfx_slider, GameSettings.sfx_volume)
	_show_volume(music_slider, GameSettings.music_volume)
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


func _slider(column: VBoxContainer, caption: String, node_name: String) -> HSlider:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	column.add_child(row)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 64
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	row.add_child(value_label)
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(210, ROW_HEIGHT)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	_volume_labels[slider] = value_label
	return slider


func _show_volume(slider: HSlider, value: float) -> void:
	if slider == null:
		return
	slider.set_value_no_signal(clampf(value, 0.0, 1.0))
	var label: Label = _volume_labels.get(slider, null)
	if label != null:
		label.text = GameSettings.volume_label(value)


func _on_volume_changed(value: float, key: String) -> void:
	match key:
		"master":
			GameSettings.master_volume = clampf(value, 0.0, 1.0)
		"sfx":
			GameSettings.sfx_volume = clampf(value, 0.0, 1.0)
		"music":
			GameSettings.music_volume = clampf(value, 0.0, 1.0)
	_apply_and_save()


func _toggle(column: VBoxContainer, caption: String, node_name: String) -> CheckButton:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	column.add_child(row)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var toggle := CheckButton.new()
	toggle.name = node_name
	row.add_child(toggle)
	return toggle


func _on_camera_track_toggled(pressed: bool) -> void:
	GameSettings.camera_track = pressed
	_apply_and_save()


func _on_cpu_report_toggled(pressed: bool) -> void:
	GameSettings.cpu_battle_report = pressed
	_apply_and_save()


func _on_battle_flair_toggled(pressed: bool) -> void:
	GameSettings.battle_flair = pressed
	_apply_and_save()


func _on_cpu_speed_selected(index: int) -> void:
	GameSettings.cpu_speed = GameSettings.CPU_SPEEDS[clampi(index, 0, GameSettings.CPU_SPEEDS.size() - 1)]
	_apply_and_save()


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
