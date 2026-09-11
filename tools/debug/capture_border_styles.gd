extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const OUTPUT_DIR: String = "res://logs/debug/live_captures"

var captured: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var window_size := Vector2i(1920, 1080)
	DisplayServer.window_set_size(window_size)
	UiScale.override_factor = UiScale.compute(Vector2(window_size), 1.0)
	root.content_scale_size = Vector2i(0, 0)
	await process_frame
	GameSettings.remember_window_size = false
	var main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var saved_style: int = GameSettings.border_style
	var saved_color: int = GameSettings.border_color
	await _snap("border_style_menu_%d" % saved_style)
	PmdStyle.set_border_style(3)
	PmdStyle.set_border_color(2)
	for i in range(3):
		await process_frame
	await _snap("border_style_menu_3_pink")
	PmdStyle.set_border_color(saved_color)
	PmdStyle.set_border_style(saved_style)
	for i in range(2):
		await process_frame
	var options_button: Button = main.find_child("OptionsButton", true, false) as Button
	if options_button != null:
		options_button.pressed.emit()
	for i in range(3):
		await process_frame
	await _snap("options_panel")
	PmdStyle.set_menu_cursor(true)
	for i in range(3):
		await process_frame
	await _snap("options_cursor")
	PmdStyle.set_menu_cursor(false)
	var customize_button: Button = main.find_child("CustomizeButton", true, false) as Button
	if customize_button != null:
		customize_button.pressed.emit()
	for i in range(3):
		await process_frame
	await _snap("customize_panel")
	var saved_font: String = GameSettings.ui_font
	var saved_palette: String = GameSettings.ui_palette
	var saved_sky: String = GameSettings.sky_backdrop
	var saved_menu: String = GameSettings.menu_backdrop
	var saved_portrait: int = GameSettings.portrait_border
	for combo in [["forest", "text", "dawn", "sky"], ["ocean", "system", "cosmic", "ForestCamp"], ["rose", "banner", "sky", "GuildPath"], ["slate", "simple", "cloudy", "SnowCamp"]]:
		PmdStyle.set_ui_palette(combo[0])
		PmdStyle.set_ui_font(combo[1])
		PmdStyle.set_sky_backdrop(combo[2])
		PmdStyle.set_menu_backdrop(combo[3])
		var customize: CustomizePanel = main.find_child("CustomizePanel", true, false) as CustomizePanel
		if customize != null:
			customize.refresh()
		for i in range(3):
			await process_frame
		if customize != null:
			var probe: Label = customize.find_child("Title", true, false) as Label
			var row_label: Label = null
			for child in customize.body.get_children():
				if child is HBoxContainer and child.get_child_count() > 0 and child.get_child(0) is Label:
					row_label = child.get_child(0) as Label
					break
			if row_label != null:
				print("font probe: %s -> base %s, row font is body %s, row min %s, theme default is body %s, root theme %s" % [combo[1], PmdStyle.font_body().base_font.resource_path.get_file(), str(row_label.get_theme_font("font") == PmdStyle.font_body()), str(row_label.get_minimum_size()), str(root.theme != null and root.theme.default_font == PmdStyle.font_body()), str(root.theme)])
		await _snap("customize_%s_%s_%s_%s" % [combo[0], combo[1], combo[2], combo[3]])
	PmdStyle.set_ui_palette(saved_palette)
	PmdStyle.set_ui_font(saved_font)
	PmdStyle.set_sky_backdrop(saved_sky)
	PmdStyle.set_menu_backdrop(saved_menu)
	PmdStyle.set_portrait_border(saved_portrait)
	for index in range(PmdStyle.BORDER_STYLE_COUNT + 1):
		PmdStyle.set_border_style(index)
		var picker: OptionButton = main.find_child("BorderStylePicker", true, false) as OptionButton
		if picker != null:
			picker.select(index)
		for i in range(3):
			await process_frame
		await _snap("border_style_%d_options" % index)
	PmdStyle.set_border_style(2)
	var style_picker: OptionButton = main.find_child("BorderStylePicker", true, false) as OptionButton
	if style_picker != null:
		style_picker.select(2)
	for color in range(1, PmdStyle.BORDER_COLOR_COUNT):
		PmdStyle.set_border_color(color)
		var color_picker: OptionButton = main.find_child("BorderColorPicker", true, false) as OptionButton
		if color_picker != null:
			color_picker.select(color)
		for i in range(3):
			await process_frame
		await _snap("border_style_2_color_%d_options" % color)
	PmdStyle.set_border_color(saved_color)
	PmdStyle.set_border_style(saved_style)
	for path in captured:
		print("capture: %s" % path)
	quit(0)


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		return
	var path: String = "%s/%s.png" % [OUTPUT_DIR, label]
	image.save_png(ProjectSettings.globalize_path(path))
	captured.append(path)
