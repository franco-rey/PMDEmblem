class_name GraphicsSettingsPanel
extends MenuPanel

signal closed
signal controls_requested
signal customize_requested

const PICKER_WIDTH: float = 340.0

var mode_picker: OptionButton = null
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
var customize_button: Button = null
var close_button: Button = null


func _ready() -> void:
	super()
	name = "GraphicsSettingsPanel"
	set_title("Options")
	mode_picker = _picker("Window mode", "WindowModePicker")
	for mode in GameSettings.WINDOW_MODES:
		mode_picker.add_item(GameSettings.window_mode_label(mode))
	scale_picker = _picker("UI scale", "UIscalePicker")
	for value in GameSettings.ui_scale_options():
		scale_picker.add_item(GameSettings.ui_scale_label(value))
	vsync_toggle = _toggle("VSync", "VsyncToggle")
	camera_track_toggle = _toggle("Camera track", "CameraTrackToggle")
	cpu_report_toggle = _toggle("Battle report after CPU battles", "CpuReportToggle")
	cpu_speed_picker = _picker("Battle speed", "BattlespeedPicker")
	for value in GameSettings.CPU_SPEEDS:
		cpu_speed_picker.add_item(GameSettings.cpu_speed_label(value))
	battle_flair_toggle = _toggle("Battle flair (intro, banners, notices)", "BattleFlairToggle")
	master_slider = _slider("Master volume", "MasterVolumeSlider")
	sfx_slider = _slider("Effects volume", "EffectsVolumeSlider")
	music_slider = _slider("Music volume", "MusicVolumeSlider")
	customize_button = add_body_button("Customize", "CustomizeButton", func() -> void: customize_requested.emit())
	controls_button = add_footer_button("Controls", "ControlsButton", func() -> void: controls_requested.emit())
	close_button = add_footer_button("Back", "CloseButton", func() -> void: closed.emit())
	mode_picker.item_selected.connect(_on_mode_selected)
	scale_picker.item_selected.connect(_on_scale_selected)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	camera_track_toggle.toggled.connect(_on_camera_track_toggled)
	cpu_report_toggle.toggled.connect(_on_cpu_report_toggled)
	cpu_speed_picker.item_selected.connect(_on_cpu_speed_selected)
	battle_flair_toggle.toggled.connect(_on_battle_flair_toggled)
	master_slider.value_changed.connect(_on_volume_changed.bind("master"))
	sfx_slider.value_changed.connect(_on_volume_changed.bind("sfx"))
	music_slider.value_changed.connect(_on_volume_changed.bind("music"))
	refresh()


func refresh() -> void:
	mode_picker.select(maxi(0, GameSettings.WINDOW_MODES.find(GameSettings.window_mode)))
	scale_picker.select(GameSettings.ui_scale_index(GameSettings.ui_scale))
	vsync_toggle.set_pressed_no_signal(GameSettings.vsync)
	camera_track_toggle.set_pressed_no_signal(GameSettings.camera_track)
	cpu_report_toggle.set_pressed_no_signal(GameSettings.cpu_battle_report)
	cpu_speed_picker.select(maxi(0, GameSettings.CPU_SPEEDS.find(GameSettings.cpu_speed)))
	battle_flair_toggle.set_pressed_no_signal(GameSettings.battle_flair)
	_show_volume(master_slider, GameSettings.master_volume)
	_show_volume(sfx_slider, GameSettings.sfx_volume)
	_show_volume(music_slider, GameSettings.music_volume)


func focus_first() -> void:
	fit_to_viewport()
	if mode_picker != null and mode_picker.is_inside_tree():
		mode_picker.grab_focus()


func _picker(caption: String, node_name: String) -> OptionButton:
	var picker := OptionButton.new()
	picker.name = node_name
	picker.fit_to_longest_item = false
	picker.clip_text = true
	add_row(caption, picker, PICKER_WIDTH)
	return picker


func _toggle(caption: String, node_name: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_row(caption, toggle, 0.0)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	return toggle


func _slider(caption: String, node_name: String, min_value: float = 0.0, max_value: float = 1.0, step: float = 0.05) -> HSlider:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 84
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	group.add_child(value_label)
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(PICKER_WIDTH - 84.0 - PmdStyle.PANEL_GAP, PmdStyle.ROW_HEIGHT)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.add_child(slider)
	add_row(caption, group, PICKER_WIDTH)
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
	GameSettings.apply_audio()
	_save()


func _on_camera_track_toggled(pressed: bool) -> void:
	GameSettings.camera_track = pressed
	_save()


func _on_cpu_report_toggled(pressed: bool) -> void:
	GameSettings.cpu_battle_report = pressed
	_save()


func _on_battle_flair_toggled(pressed: bool) -> void:
	GameSettings.battle_flair = pressed
	_save()


func _on_cpu_speed_selected(index: int) -> void:
	GameSettings.cpu_speed = GameSettings.CPU_SPEEDS[clampi(index, 0, GameSettings.CPU_SPEEDS.size() - 1)]
	_save()


func _apply_and_save() -> void:
	GameSettings.apply(get_window())
	_save()


func _save() -> void:
	GameSettings.save_settings()
	refresh()


func _on_mode_selected(index: int) -> void:
	GameSettings.window_mode = GameSettings.WINDOW_MODES[clampi(index, 0, GameSettings.WINDOW_MODES.size() - 1)]
	_apply_and_save()


func _on_scale_selected(index: int) -> void:
	var options: Array[float] = GameSettings.ui_scale_options()
	GameSettings.ui_scale = options[clampi(index, 0, options.size() - 1)]
	GameSettings.apply_ui_scale(get_window())
	_save()



func _on_vsync_toggled(pressed: bool) -> void:
	GameSettings.vsync = pressed
	GameSettings.apply_vsync(get_window())
	_save()
