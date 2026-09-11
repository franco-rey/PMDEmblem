extends SceneTree

var failures: int = 0


func _run_settings_round_trip() -> Dictionary:
	GameSettings.load_settings()
	var saved: Dictionary = {
		"border_style": GameSettings.border_style, "border_color": GameSettings.border_color, "portrait_border": GameSettings.portrait_border,
		"ui_font": GameSettings.ui_font, "ui_palette": GameSettings.ui_palette, "sky_backdrop": GameSettings.sky_backdrop, "menu_backdrop": GameSettings.menu_backdrop,
	}
	GameSettings.border_style = 3
	GameSettings.border_color = 2
	GameSettings.portrait_border = 4
	GameSettings.ui_font = "system"
	GameSettings.ui_palette = "forest"
	GameSettings.sky_backdrop = "dawn"
	GameSettings.menu_backdrop = "ForestCamp"
	_assert_true(GameSettings.save_settings(), "settings save with every customize choice")
	GameSettings.border_style = 0
	GameSettings.border_color = 0
	GameSettings.portrait_border = 0
	GameSettings.ui_font = "text"
	GameSettings.ui_palette = "navy"
	GameSettings.sky_backdrop = "sky"
	GameSettings.menu_backdrop = "sky"
	GameSettings.load_settings()
	_assert_true(GameSettings.border_style == 3 and GameSettings.border_color == 2 and GameSettings.portrait_border == 4 and GameSettings.ui_font == "system" and GameSettings.ui_palette == "forest" and GameSettings.sky_backdrop == "dawn" and GameSettings.menu_backdrop == "ForestCamp", "every customize choice loads back from the user config")
	GameSettings.border_style = 42
	GameSettings.border_color = 9
	GameSettings.portrait_border = 9
	GameSettings.ui_font = "comic"
	GameSettings.ui_palette = "neon"
	GameSettings.sky_backdrop = "mars"
	GameSettings.menu_backdrop = "Nowhere"
	GameSettings.save_settings()
	GameSettings.load_settings()
	_assert_true(GameSettings.border_style == PmdStyle.BORDER_STYLE_COUNT and GameSettings.border_color == PmdStyle.BORDER_COLOR_COUNT - 1 and GameSettings.portrait_border == PmdStyle.PORTRAIT_STYLE_COUNT and GameSettings.ui_font == "text" and GameSettings.ui_palette == "navy" and GameSettings.sky_backdrop == "sky" and GameSettings.menu_backdrop == "sky", "out-of-range and unknown customize values clamp or fall back on load")
	GameSettings.border_style = 0
	GameSettings.border_color = 0
	GameSettings.portrait_border = 0
	GameSettings.ui_font = "text"
	GameSettings.ui_palette = "navy"
	GameSettings.sky_backdrop = "sky"
	GameSettings.menu_backdrop = "sky"
	return saved


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var saved: Dictionary = _run_settings_round_trip()
	PmdStyle.set_ui_font("text")
	PmdStyle.refresh_windows()
	_assert_true(PmdStyle.window() is PmdWindowStyle, "the default window style is the PMD window wrapper")
	var dock: StyleBox = PmdStyle.window(PmdStyle.NAVY_DEEP, PmdStyle.FRAME_SOFT, 2, 6)
	var highlight: StyleBox = PmdStyle.window(PmdStyle.NAVY, PmdStyle.CURSOR, 3, 6)
	_assert_true(dock is PmdWindowStyle and highlight is PmdWindowStyle, "soft-framed docks and gold highlight windows take the frame too")
	var plate: StyleBoxFlat = PmdStyle.plate("normal")
	var soft_plate: StyleBoxFlat = PmdStyle.plate("disabled")
	var focus_plate: StyleBoxFlat = PmdStyle.plate("focus")
	_assert_true(plate is StyleBoxFlat and PmdStyle.chip() is StyleBoxFlat and PmdStyle.panel_soft() is StyleBoxFlat and PmdStyle.field("normal") is StyleBoxFlat, "plates, chips, soft panels and fields stay flat")
	_assert_true(plate.border_color == PmdStyle.FRAME and soft_plate.border_color == PmdStyle.FRAME_SOFT and focus_plate.border_color == PmdStyle.CURSOR, "at Emblem the plates keep the white, soft and gold borders")
	var window: PmdWindowStyle = PmdStyle.window() as PmdWindowStyle
	_assert_true(not window.is_textured() and is_equal_approx(window.get_content_margin(SIDE_TOP), 8.0) and is_equal_approx(window.get_content_margin(SIDE_LEFT), 10.0), "style 0 keeps the flat margins")
	var portrait: PmdWindowStyle = PmdStyle.portrait_frame(PmdStyle.TEAM_PLAYER, 2) as PmdWindowStyle
	_assert_true(portrait != null and portrait.sheet == "portrait" and not portrait.is_textured() and is_equal_approx(portrait.get_content_margin(SIDE_LEFT), 2.0), "portrait frames wrap the flat team-coloured frame by default")
	var canvas: RID = RenderingServer.canvas_item_create()
	window.draw(canvas, Rect2(0, 0, 200, 100))
	portrait.draw(canvas, Rect2(0, 0, 64, 64))
	var available: bool = PmdStyle.border_sheet_available()
	var portraits_available: bool = PmdStyle.sheet_available("portrait")
	print("smoke: border sheet %s, portrait sheet %s" % ["available" if available else "missing", "available" if portraits_available else "missing"])
	if available:
		var expected: int = PmdStyle.BORDER_CELL_PX * 3 * PmdStyle.BORDER_SCALE
		var last: int = expected - 1
		var baked: int = 0
		var edge_colors: Dictionary = {}
		for row in range(PmdStyle.BORDER_COLOR_COUNT):
			for index in range(1, PmdStyle.BORDER_STYLE_COUNT + 1):
				var texture: ImageTexture = PmdStyle.bake_window_texture(index, row, PmdStyle.NAVY)
				if texture == null or texture.get_size() != Vector2(expected, expected):
					failures += 1
					printerr("FAIL: style %d row %d bakes a %d px window texture" % [index, row, expected])
					continue
				baked += 1
				var image: Image = texture.get_image()
				var corners_clear: bool = true
				for corner in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
					if image.get_pixelv(corner).a > 0.0:
						corners_clear = false
				var centre: Color = image.get_pixel(expected / 2, expected / 2)
				var edge: Color = image.get_pixel(expected / 2, PmdStyle.BORDER_SCALE)
				if not corners_clear or not _close(centre, PmdStyle.NAVY) or edge.a <= 0.0 or _close(edge, PmdStyle.NAVY):
					failures += 1
					printerr("FAIL: style %d row %d keeps clear corners, a filled centre and frame pixels on the top edge" % [index, row])
				edge_colors["%d:%d" % [index, row]] = _ring_average(image, expected)
		_assert_true(baked == PmdStyle.BORDER_STYLE_COUNT * PmdStyle.BORDER_COLOR_COUNT, "all %d frames bake from the sheet" % (PmdStyle.BORDER_STYLE_COUNT * PmdStyle.BORDER_COLOR_COUNT))
		var rows_differ: bool = true
		for index in range(1, PmdStyle.BORDER_STYLE_COUNT + 1):
			var green: Color = edge_colors.get("%d:0" % index, Color.BLACK)
			var blue: Color = edge_colors.get("%d:1" % index, Color.BLACK)
			var pink: Color = edge_colors.get("%d:2" % index, Color.BLACK)
			if not (green.g > green.r and green.g > green.b and blue.b > blue.r and blue.b > blue.g and pink.r > pink.g):
				rows_differ = false
		_assert_true(rows_differ, "the three colour rows bake as green, blue and pink frames for every style")
		var plain: Image = PmdStyle.bake_window_texture(1, 0, PmdStyle.NAVY).get_image()
		var gold: Image = PmdStyle.bake_window_texture(1, 0, PmdStyle.NAVY, PmdStyle.CURSOR).get_image()
		var gold_ring: Color = _ring_average(gold, expected)
		_assert_true(gold_ring.r > gold_ring.b + 0.2 and gold_ring != _ring_average(plain, expected), "gold highlight windows bake a gold-tinted ring")
		PmdStyle.set_border_style(2)
		_assert_true(window.is_textured() and window.baked_style == 2 and window.baked_color == 0, "live windows switch to the chosen border in the green row")
		var accent: Color = PmdStyle.frame_accent(2, 0)
		_assert_true(accent.g > accent.r and accent.g > accent.b and plate.border_color == accent and soft_plate.border_color == accent.darkened(0.35) and focus_plate.border_color == PmdStyle.CURSOR, "plates follow the frame's green accent while the gold focus stays")
		PmdStyle.set_border_color(2)
		_assert_true(plate.border_color.r > plate.border_color.g, "plates follow the pink row when the colour changes")
		PmdStyle.set_border_color(0)
		var inset: float = float(PmdStyle.BORDER_FRAME_PX - PmdStyle.BORDER_OVERHANG_PX + PmdStyle.BORDER_GUARD_PX + PmdStyle.BORDER_INNER_PAD)
		_assert_true(is_equal_approx(window.get_content_margin(SIDE_LEFT), inset) and inset <= 14.0, "textured windows inset content %d px, close to the flat 10 px, with the ring overhanging the panel edge" % int(inset))
		var grown: Rect2 = window._get_draw_rect(Rect2(0, 0, 200, 100))
		_assert_true(is_equal_approx(grown.position.x, -float(PmdStyle.BORDER_OVERHANG_PX)), "textured windows report the overhang in their draw rect")
		window.draw(canvas, Rect2(0, 0, 200, 100))
		_assert_true(not portrait.is_textured(), "portrait frames stay flat while portrait borders are off")
		PmdStyle.set_border_style(0)
		_assert_true(not window.is_textured() and is_equal_approx(window.get_content_margin(SIDE_LEFT), 10.0), "switching back restores the flat window")
		_assert_true(plate.border_color == PmdStyle.FRAME and soft_plate.border_color == PmdStyle.FRAME_SOFT, "switching back restores the plate borders")
	if portraits_available:
		PmdStyle.set_portrait_border(3)
		var portrait_px: int = PmdStyle.sheet_frame_px("portrait") * 3
		_assert_true(portrait.is_textured() and portrait.baked_style == 3 and portrait.texture.get_size() == Vector2(portrait_px, portrait_px), "portrait frames bake the portrait border sheet at %d px" % portrait_px)
		var ring: Color = _ring_average(portrait.texture.get_image(), portrait_px, PmdStyle.sheet_frame_px("portrait"), PmdStyle.PORTRAIT_FILL)
		_assert_true(ring.b > ring.r, "a player portrait frame bakes a blue-tinted ring")
		_assert_true(is_equal_approx(portrait.get_content_margin(SIDE_LEFT), PmdStyle.sheet_inset("portrait")) and PmdStyle.sheet_inset("portrait") <= 8.0, "portrait frames keep a small inset with the ring overhanging")
		portrait.draw(canvas, Rect2(0, 0, 64, 64))
		_assert_true(not window.is_textured(), "portrait borders do not texture the windows")
		PmdStyle.set_portrait_border(0)
		_assert_true(not portrait.is_textured() and is_equal_approx(portrait.get_content_margin(SIDE_LEFT), 2.0), "portrait borders off restores the flat frame")
	RenderingServer.free_rid(canvas)
	PmdStyle.set_ui_palette("forest")
	var forest: Dictionary = PmdStyle.PALETTES["forest"]
	_assert_true(window.flat.bg_color == forest["window"] and plate.bg_color == forest["deep"] and plate.border_color == forest["frame"] and soft_plate.border_color == forest["frame_soft"] and focus_plate.border_color == PmdStyle.CURSOR, "the forest palette recolours window fills, plate fills and Emblem borders while gold stays")
	_assert_true(PmdStyle.window_flat().bg_color == forest["window"] and PmdStyle.plate("hover").bg_color == forest["light"], "new flats are born in the active palette")
	PmdStyle.set_ui_palette("navy")
	_assert_true(window.flat.bg_color == PmdStyle.NAVY and plate.bg_color == PmdStyle.NAVY_DEEP and plate.border_color == PmdStyle.FRAME, "the navy palette restores the default colours")
	PmdStyle.set_ui_font("system")
	_assert_true(PmdStyle.font_body().base_font == PmdStyle.font_file_for("system") and GameSettings.ui_font == "system", "choosing a font swaps the shared body font live")
	PmdStyle.set_ui_font("text")
	_assert_true(PmdStyle.font_body().base_font == PmdStyle.TEXT_FONT and PmdStyle.font_title().base_font == PmdStyle.BANNER_FONT, "the text font returns and titles keep the banner font")
	root.theme = PmdStyle.build_theme(load("res://assets/ui/pmd_theme.tres") as Theme)
	_assert_true(root.theme.default_font == PmdStyle.font_body(), "the theme's default font is the shared body font")
	var toggle_style: StyleBoxFlat = root.theme.get_stylebox("normal", "CheckButton") as StyleBoxFlat
	_assert_true(toggle_style != null and toggle_style.bg_color.a == 0.0 and toggle_style.border_color.a == 0.0, "toggles sit bare on their row with no plate box")
	_assert_true(root.theme.get_stylebox("panel", "PopupMenu") is StyleBoxFlat and not (root.theme.get_stylebox("panel", "PopupMenu") is PmdWindowStyle), "dropdown popups keep a flat frame that cannot be clipped by the popup window")
	_assert_true(root.theme.get_stylebox("slider", "HSlider") is StyleBoxFlat and root.theme.get_stylebox("grabber_area", "HSlider") is StyleBoxFlat and root.theme.get_icon("grabber", "HSlider") != null and root.theme.get_icon("grabber", "HSlider").get_size() == Vector2(22, 22), "sliders take a themed track, fill and knob")
	var track: StyleBoxFlat = root.theme.get_stylebox("grabber_area", "HSlider") as StyleBoxFlat
	var scroll_grabber: StyleBoxFlat = root.theme.get_stylebox("grabber", "VScrollBar") as StyleBoxFlat
	PmdStyle.set_ui_palette("rose")
	_assert_true(track.bg_color == PmdStyle.PALETTES["rose"]["frame_soft"] and scroll_grabber.bg_color == PmdStyle.PALETTES["rose"]["frame_soft"] and PmdStyle.field("normal").bg_color == PmdStyle.PALETTES["rose"]["field"], "slider fills, scrollbar grabbers and text fields follow the palette")
	PmdStyle.set_ui_palette("navy")
	_assert_true(track.bg_color == PmdStyle.FRAME_SOFT and PmdStyle.field("normal").bg_color == PmdStyle.FIELD_FILL, "navy restores the soft fills")
	_assert_true(is_equal_approx(PmdStyle.font_width_factor(), 1.0), "the Text font has a width factor of one")
	PmdStyle.set_ui_font("system")
	_assert_true(PmdStyle.font_width_factor() > 1.5, "the System font widens menu rows")
	PmdStyle.set_ui_font("text")
	var overlay: PmdWindowStyle = PmdStyle.portrait_overlay() as PmdWindowStyle
	_assert_true(overlay != null and not overlay.is_textured() and overlay.flat.bg_color.a == 0.0 and overlay.flat.border_color.a == 0.0, "portrait overlays are invisible while portrait borders are off")
	if portraits_available:
		PmdStyle.set_portrait_border(1)
		var overlay_image: Image = overlay.texture.get_image()
		var overlay_px: int = PmdStyle.sheet_frame_px("portrait") * 3
		_assert_true(overlay.is_textured() and overlay_image.get_pixel(overlay_px / 2, overlay_px / 2).a == 0.0 and overlay_image.get_pixel(overlay_px / 2, 2).a > 0.0, "portrait overlays bake an untinted ring around a transparent centre")
		PmdStyle.set_portrait_border(0)
	var probe_config := ConfigFile.new()
	probe_config.load(GameSettings.SETTINGS_PATH)
	probe_config.set_value(GameSettings.SECTION, "ui_scale", 2.0)
	probe_config.erase_section_key(GameSettings.SECTION, "ui_scale_relative")
	probe_config.save(GameSettings.SETTINGS_PATH)
	var scale_before: float = GameSettings.ui_scale
	GameSettings.load_settings()
	_assert_true(is_equal_approx(GameSettings.ui_scale, 1.0), "a saved absolute UI scale from before the relative change resets to 100% once")
	GameSettings.ui_scale = scale_before
	GameSettings.save_settings()
	GameSettings.load_settings()
	_assert_true(is_equal_approx(GameSettings.ui_scale, scale_before), "after saving once the relative scale is kept")
	GameSettings.border_style = 0
	GameSettings.border_color = 0
	GameSettings.portrait_border = 0
	GameSettings.ui_font = "text"
	GameSettings.ui_palette = "navy"
	GameSettings.sky_backdrop = "sky"
	GameSettings.menu_backdrop = "sky"
	PmdStyle.set_ui_font("text")
	PmdStyle.refresh_windows()
	var orphan := Node.new()
	root.add_child(orphan)
	var orphan_button := Button.new()
	orphan_button.text = "Battle"
	orphan.add_child(orphan_button)
	await process_frame
	var orphan_style: StyleBoxFlat = orphan_button.get_theme_stylebox("normal") as StyleBoxFlat
	_assert_true(orphan_style != null and orphan_style.bg_color == PmdStyle.PALETTES["navy"]["deep"] and orphan_button.get_theme_font("font") == PmdStyle.font_body(), "a button under a plain Node still gets the PMD plate and body font through the project theme")
	var orphan_width: float = orphan_button.get_minimum_size().x
	PmdStyle.set_ui_font("system")
	await process_frame
	_assert_true(orphan_button.get_minimum_size().x > orphan_width, "switching the font re-measures controls that only see the project theme")
	PmdStyle.set_ui_font("text")
	await process_frame
	orphan.queue_free()
	var backdrop := PmdBackdrop.new()
	root.add_child(backdrop)
	await process_frame
	_assert_true(not backdrop.has_scene() and backdrop.sky_texture_path().ends_with("Sky.1.png"), "the backdrop starts on the sky sheet")
	PmdStyle.set_sky_backdrop("dawn")
	_assert_true(backdrop.sky_texture_path().ends_with("Dawn.1.png") and not backdrop._clouds.visible, "picking Dawn swaps the sky sheet live and drops the cloud layer")
	PmdStyle.set_sky_backdrop("sky")
	_assert_true(backdrop.sky_texture_path().ends_with("Sky.1.png") and backdrop._clouds.visible, "returning to Sky restores the clouds")
	var scenes: bool = PmdStyle.menu_backdrops_available()
	print("smoke: menu backdrops %s" % ("available" if scenes else "missing, scene checks skipped"))
	if scenes:
		PmdStyle.set_menu_backdrop("ForestCamp")
		_assert_true(backdrop.has_scene() and not backdrop._sky.visible, "picking Forest Camp shows the hub scene instead of the sky")
		PmdStyle.set_menu_backdrop("sky")
		_assert_true(not backdrop.has_scene() and backdrop._sky.visible, "returning to Sky hides the scene")
		var black_edged: Array[String] = []
		for id in GameSettings.MENU_BACKDROPS:
			if id == "sky":
				continue
			var texture: Texture2D = load(PmdStyle.MENU_BACKDROP_DIR + id + ".png") as Texture2D
			var image: Image = texture.get_image() if texture != null else null
			if image == null:
				black_edged.append(id + " (missing)")
				continue
			var dark: int = 0
			var samples: int = 0
			for x in range(0, image.get_width(), 4):
				for y in [0, image.get_height() - 1]:
					samples += 1
					if image.get_pixel(x, y).v < 0.05:
						dark += 1
			for y in range(0, image.get_height(), 4):
				for x in [0, image.get_width() - 1]:
					samples += 1
					if image.get_pixel(x, y).v < 0.05:
						dark += 1
			if dark > 0:
				black_edged.append("%s (%d of %d edge samples)" % [id, dark, samples])
		_assert_true(black_edged.is_empty(), "every menu backdrop is full-bleed with no black surround (%s)" % ", ".join(black_edged))
	backdrop.queue_free()
	var options := GraphicsSettingsPanel.new()
	root.add_child(options)
	await process_frame
	_assert_true(options.find_child("CustomizeButton", true, false) != null and options.find_child("BorderStylePicker", true, false) == null, "Options ends with a Customize button and no longer carries the border pickers")
	var requested: Array = []
	options.customize_requested.connect(func() -> void: requested.append(true))
	(options.find_child("CustomizeButton", true, false) as Button).pressed.emit()
	_assert_true(requested.size() == 1, "the Customize button asks the host to open the Customize panel")
	options.queue_free()
	var panel := CustomizePanel.new()
	root.add_child(panel)
	await process_frame
	var picker: OptionButton = panel.find_child("BorderStylePicker", true, false) as OptionButton
	var color_picker: OptionButton = panel.find_child("BorderColorPicker", true, false) as OptionButton
	var portrait_picker: OptionButton = panel.find_child("PortraitBorderPicker", true, false) as OptionButton
	var font_picker: OptionButton = panel.find_child("FontPicker", true, false) as OptionButton
	var palette_picker: OptionButton = panel.find_child("PalettePicker", true, false) as OptionButton
	var sky_picker: OptionButton = panel.find_child("SkyPicker", true, false) as OptionButton
	var menu_picker: OptionButton = panel.find_child("MenuBackdropPicker", true, false) as OptionButton
	_assert_true(picker != null and picker.item_count == PmdStyle.BORDER_STYLE_COUNT + 1 and color_picker != null and color_picker.item_count == PmdStyle.BORDER_COLOR_COUNT and portrait_picker != null and portrait_picker.item_count == PmdStyle.PORTRAIT_STYLE_COUNT + 1, "Customize lists Default plus five border styles, three colours and team colours plus five portrait borders")
	_assert_true(font_picker != null and font_picker.item_count == GameSettings.UI_FONTS.size() and palette_picker != null and palette_picker.item_count == GameSettings.UI_PALETTES.size() and sky_picker != null and sky_picker.item_count == GameSettings.SKY_BACKDROPS.size() and menu_picker != null and menu_picker.item_count == GameSettings.MENU_BACKDROPS.size(), "Customize lists the fonts, palettes, skies and menu backdrops")
	if picker != null and color_picker != null and portrait_picker != null and font_picker != null and palette_picker != null and sky_picker != null:
		_assert_true(picker.get_item_text(0) == "Default" and picker.get_item_text(PmdStyle.BORDER_STYLE_COUNT) == "Style %d" % PmdStyle.BORDER_STYLE_COUNT and color_picker.get_item_text(0) == "Green" and color_picker.get_item_text(2) == "Pink" and portrait_picker.get_item_text(0) == "Team colors" and font_picker.get_item_text(0) == "Text" and palette_picker.get_item_text(1) == "Forest" and sky_picker.get_item_text(2) == "Dawn", "Customize labels")
		_assert_true(picker.disabled == (not available) and portrait_picker.disabled == (not portraits_available), "sheet-backed pickers are disabled only when their sheet is missing")
		_assert_true(color_picker.disabled, "the colour picker is disabled while both borders are off")
		if available:
			picker.item_selected.emit(4)
			_assert_true(GameSettings.border_style == 4 and picker.selected == 4 and not color_picker.disabled, "picking a border style applies it and enables the colour picker")
			color_picker.item_selected.emit(2)
			_assert_true(GameSettings.border_color == 2 and color_picker.selected == 2, "picking a border colour applies it")
			_assert_true(window.baked_style == 4 and window.baked_color == 2 and window.is_textured(), "picking style and colour restyles live windows")
		if portraits_available:
			portrait_picker.item_selected.emit(2)
			_assert_true(GameSettings.portrait_border == 2 and portrait.is_textured() and portrait.baked_style == 2, "picking a portrait border restyles live portrait frames")
		palette_picker.item_selected.emit(3)
		_assert_true(GameSettings.ui_palette == "rose" and window.flat.bg_color == PmdStyle.PALETTES["rose"]["window"], "picking a palette applies it live")
		font_picker.item_selected.emit(2)
		_assert_true(GameSettings.ui_font == "system" and PmdStyle.font_body().base_font == PmdStyle.font_file_for("system"), "picking a font applies it live")
		sky_picker.item_selected.emit(3)
		_assert_true(GameSettings.sky_backdrop == "cosmic", "picking a sky applies it")
		GameSettings.border_style = 0
		GameSettings.border_color = 0
		GameSettings.portrait_border = 0
		GameSettings.ui_palette = "navy"
		GameSettings.ui_font = "text"
		GameSettings.sky_backdrop = "sky"
		GameSettings.load_settings()
		_assert_true((not available or (GameSettings.border_style == 4 and GameSettings.border_color == 2)) and (not portraits_available or GameSettings.portrait_border == 2) and GameSettings.ui_palette == "rose" and GameSettings.ui_font == "system" and GameSettings.sky_backdrop == "cosmic", "the picked customize choices survive a reload")
	panel.queue_free()
	GameSettings.border_style = int(saved["border_style"])
	GameSettings.border_color = int(saved["border_color"])
	GameSettings.portrait_border = int(saved["portrait_border"])
	GameSettings.ui_font = String(saved["ui_font"])
	GameSettings.ui_palette = String(saved["ui_palette"])
	GameSettings.sky_backdrop = String(saved["sky_backdrop"])
	GameSettings.menu_backdrop = String(saved["menu_backdrop"])
	PmdStyle.set_ui_font(GameSettings.ui_font)
	PmdStyle.refresh_windows()
	GameSettings.save_settings()
	_finish()


func _ring_average(image: Image, size: int, band: int = PmdStyle.BORDER_FRAME_PX, fill: Color = PmdStyle.NAVY) -> Color:
	var total := Color(0, 0, 0, 0)
	var count: int = 0
	for x in range(size):
		for y in range(band):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0 and not _close(pixel, fill):
				total += pixel
				count += 1
	return total / float(maxi(count, 1))


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01


func _finish() -> void:
	if failures > 0:
		print("smoke: border_style FAILED with %d failures" % failures)
		quit(1)
		return
	print("smoke: border_style clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("ok: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)
