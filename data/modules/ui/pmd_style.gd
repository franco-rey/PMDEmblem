class_name PmdStyle
extends RefCounted

const TEXT_FONT: FontFile = preload("res://assets/fonts/pmd/pmd_text.fnt")
const BANNER_FONT: FontFile = preload("res://assets/fonts/pmd/pmd_banner.fnt")
const NAVY: Color = Color(0.07, 0.10, 0.24, 0.94)
const NAVY_DEEP: Color = Color(0.04, 0.06, 0.16, 0.97)
const NAVY_LIGHT: Color = Color(0.13, 0.18, 0.38, 0.96)
const FRAME: Color = Color(0.93, 0.95, 1.0, 1.0)
const FRAME_SOFT: Color = Color(0.50, 0.58, 0.82, 1.0)
const CURSOR: Color = Color(1.0, 0.86, 0.32, 1.0)
const TEXT: Color = Color(1.0, 1.0, 1.0, 1.0)
const TEXT_DIM: Color = Color(0.64, 0.68, 0.80, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.90, 0.55, 1.0)
const TEAM_PLAYER: Color = Color(0.30, 0.58, 1.0, 1.0)
const TEAM_ENEMY: Color = Color(1.0, 0.38, 0.36, 1.0)
const HP_HIGH: Color = Color(0.24, 0.82, 0.38, 1.0)
const HP_MID: Color = Color(0.96, 0.78, 0.22, 1.0)
const HP_LOW: Color = Color(0.92, 0.26, 0.22, 1.0)
const HP_BACK: Color = Color(0.06, 0.07, 0.12, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.55)
const FONT_BIG: int = 72
const FONT_HERO: int = 60
const FONT_TITLE: int = 48
const FONT_BODY: int = 36
const FONT_CAPTION: int = 24
const FONT_MICRO: int = 12
const CONTROL_WIDTH: float = 360.0
const CONTROL_HEIGHT: float = 64.0
const ROW_HEIGHT: float = 56.0
const PANEL_WIDTH: float = 900.0
const PANEL_MARGIN: int = 24
const PANEL_GAP: int = 12
const PLATE_FRAME: int = 2
const RADIUS: int = 6
const PLATE_PRESSED: Color = Color(0.20, 0.26, 0.48, 1.0)
const TYPE_COLORS: Dictionary = {
	"normal": Color(0.66, 0.65, 0.48),
	"fire": Color(0.93, 0.50, 0.19),
	"water": Color(0.39, 0.56, 0.94),
	"electric": Color(0.97, 0.82, 0.17),
	"grass": Color(0.48, 0.78, 0.30),
	"ice": Color(0.59, 0.85, 0.84),
	"fighting": Color(0.76, 0.18, 0.16),
	"poison": Color(0.64, 0.24, 0.63),
	"ground": Color(0.89, 0.75, 0.40),
	"flying": Color(0.66, 0.56, 0.95),
	"psychic": Color(0.98, 0.33, 0.53),
	"bug": Color(0.65, 0.73, 0.10),
	"rock": Color(0.72, 0.63, 0.22),
	"ghost": Color(0.45, 0.34, 0.59),
	"dragon": Color(0.44, 0.21, 0.99),
	"dark": Color(0.44, 0.34, 0.27),
	"steel": Color(0.72, 0.72, 0.81),
	"fairy": Color(0.93, 0.60, 0.68),
}
const BORDER_SHEET_PATH: String = "res://assets/visuals/raw_asset/UI/MenuBorder.png"
const PORTRAIT_SHEET_PATH: String = "res://assets/visuals/raw_asset/UI/PortraitBorder.png"
const BORDER_STYLE_COUNT: int = 5
const PORTRAIT_STYLE_COUNT: int = 5
const BORDER_CELL_PX: int = 8
const BORDER_SCALE: int = 2
const BORDER_FRAME_PX: int = BORDER_CELL_PX * BORDER_SCALE
const BORDER_GUARD_PX: int = BORDER_SCALE
const BORDER_OVERHANG_PX: int = 6
const BORDER_INNER_PAD: int = 2
const BORDER_COLOR_COUNT: int = 3
const BORDER_COLOR_NAMES: Array[String] = ["Green", "Blue", "Pink"]
const SHEETS: Dictionary = {
	"menu": {"path": BORDER_SHEET_PATH, "cell": BORDER_CELL_PX, "scale": BORDER_SCALE, "overhang": BORDER_OVERHANG_PX, "pad": BORDER_INNER_PAD, "styles": BORDER_STYLE_COUNT},
	"portrait": {"path": PORTRAIT_SHEET_PATH, "cell": 4, "scale": 2, "overhang": 4, "pad": 0, "styles": PORTRAIT_STYLE_COUNT},
}
const PORTRAIT_FILL: Color = Color(0.02, 0.03, 0.08, 1.0)
const PALETTES: Dictionary = {
	"navy": {"window": NAVY, "deep": NAVY_DEEP, "light": NAVY_LIGHT, "pressed": PLATE_PRESSED, "frame": FRAME, "frame_soft": FRAME_SOFT},
	"forest": {"window": Color(0.06, 0.16, 0.10, 0.94), "deep": Color(0.03, 0.10, 0.06, 0.97), "light": Color(0.11, 0.26, 0.16, 0.96), "pressed": Color(0.16, 0.34, 0.22, 1.0), "frame": Color(0.80, 0.96, 0.84, 1.0), "frame_soft": Color(0.42, 0.66, 0.50, 1.0)},
	"ocean": {"window": Color(0.04, 0.10, 0.24, 0.94), "deep": Color(0.02, 0.06, 0.16, 0.97), "light": Color(0.08, 0.20, 0.42, 0.96), "pressed": Color(0.12, 0.28, 0.55, 1.0), "frame": Color(0.78, 0.90, 1.0, 1.0), "frame_soft": Color(0.38, 0.58, 0.90, 1.0)},
	"rose": {"window": Color(0.18, 0.06, 0.14, 0.94), "deep": Color(0.11, 0.03, 0.09, 0.97), "light": Color(0.30, 0.11, 0.24, 0.96), "pressed": Color(0.40, 0.16, 0.32, 1.0), "frame": Color(1.0, 0.86, 0.94, 1.0), "frame_soft": Color(0.80, 0.48, 0.66, 1.0)},
	"slate": {"window": Color(0.10, 0.10, 0.12, 0.94), "deep": Color(0.06, 0.06, 0.07, 0.97), "light": Color(0.18, 0.18, 0.22, 0.96), "pressed": Color(0.24, 0.24, 0.29, 1.0), "frame": Color(0.88, 0.88, 0.90, 1.0), "frame_soft": Color(0.52, 0.52, 0.58, 1.0)},
}
const PALETTE_LABELS: Dictionary = {"navy": "Navy", "forest": "Forest", "ocean": "Ocean", "rose": "Rose", "slate": "Slate"}
const FONT_FILES: Dictionary = {
	"text": TEXT_FONT,
	"banner": BANNER_FONT,
	"system": preload("res://assets/fonts/pmd/pmd_system.fnt"),
	"simple": preload("res://assets/fonts/pmd/pmd_simple.fnt"),
}
const FONT_LABELS: Dictionary = {"text": "Text", "banner": "Banner", "system": "System", "simple": "Simple"}
const SKY_SHEETS: Dictionary = {
	"sky": "res://assets/visuals/raw_asset/BG/Sky.1.png",
	"cloudy": "res://assets/visuals/raw_asset/BG/Cloudy_Sky.1.png",
	"dawn": "res://assets/visuals/raw_asset/BG/Dawn.1.png",
	"cosmic": "res://assets/visuals/raw_asset/BG/Cosmic_Power.1.png",
}
const SKY_LABELS: Dictionary = {"sky": "Sky", "cloudy": "Cloudy sky", "dawn": "Dawn", "cosmic": "Night sky"}
const MENU_BACKDROP_DIR: String = "res://assets/visuals/raw_asset/Backdrop/"
const MENU_BACKDROP_LABELS: Dictionary = {"sky": "Sky", "BaseCamp": "Base Camp", "ForestCamp": "Forest Camp", "ForestCampSecret": "Secret Forest Camp", "GardenEnd": "Garden's End", "GuildPath": "Guild Path", "SnowCamp": "Snow Camp", "LuminousSpring": "Luminous Spring", "CaveStop": "Cave Stop"}

static var _sheet_images: Dictionary = {}
static var _window_textures: Dictionary = {}
static var _frame_accents: Dictionary = {}
static var _windows: Array[WeakRef] = []
static var _flats: Array[Dictionary] = []
static var _body_font: FontVariation = null
static var _title_font: FontVariation = null


static func window(fill: Color = NAVY, frame: Color = FRAME, width: int = 3, radius: int = 6) -> StyleBox:
	var flat: StyleBoxFlat = window_flat(fill, frame, width, radius)
	var style: PmdWindowStyle = PmdWindowStyle.create(flat, fill, frame)
	_windows.append(weakref(style))
	return style


static func window_flat(fill: Color = NAVY, frame: Color = FRAME, width: int = 3, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = effective_fill(fill)
	style.border_color = frame
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = SHADOW
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_register_flat(style, frame, fill)
	return style


static func panel_soft(fill: Color = NAVY_DEEP) -> StyleBoxFlat:
	var style := window_flat(fill, FRAME_SOFT, 1, 4)
	style.shadow_size = 0
	return style


static func chip(fill: Color = NAVY_DEEP, frame: Color = FRAME_SOFT) -> StyleBoxFlat:
	var style := window_flat(fill, frame, 1, 4)
	style.shadow_size = 0
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


static func plate(state: String) -> StyleBoxFlat:
	var style: StyleBoxFlat
	match state:
		"hover":
			style = window_flat(NAVY_LIGHT, CURSOR, PLATE_FRAME, RADIUS)
		"pressed":
			style = window_flat(PLATE_PRESSED, CURSOR, PLATE_FRAME, RADIUS)
		"disabled":
			style = window_flat(NAVY_DEEP, FRAME_SOFT, PLATE_FRAME, RADIUS)
		"focus":
			style = window_flat(Color(0, 0, 0, 0), CURSOR, PLATE_FRAME, RADIUS)
			style.draw_center = false
			style.shadow_size = 0
		_:
			style = window_flat(NAVY_DEEP, FRAME, PLATE_FRAME, RADIUS)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func button(state: String) -> StyleBoxFlat:
	return plate(state)


static func control_button(text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, CONTROL_HEIGHT)
	button.add_theme_font_size_override("font_size", FONT_BODY)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


static func field(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.10, 1.0)
	style.border_color = CURSOR if state == "focus" else FRAME_SOFT
	style.set_border_width_all(PLATE_FRAME)
	style.set_corner_radius_all(RADIUS)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_register_flat(style, style.border_color, Color(0, 0, 0, 0))
	return style


static func type_color(type_id: String) -> Color:
	return TYPE_COLORS.get(type_id.to_lower(), Color(0.55, 0.55, 0.6))


static func type_abbreviation(type_id: String) -> String:
	var text: String = type_id.strip_edges().to_upper()
	return text.substr(0, 3) if text.length() >= 3 else text


static func hp_color(fraction: float) -> Color:
	if fraction > 0.5:
		return HP_HIGH
	if fraction > 0.2:
		return HP_MID
	return HP_LOW


static func team_color(team: int) -> Color:
	return TEAM_PLAYER if team == PokemonInstanceResource.Team.PLAYER else TEAM_ENEMY


static func build_theme(base: Theme) -> Theme:
	var theme: Theme = base.duplicate(true) if base != null else Theme.new()
	theme.default_font = font_body()
	if theme.default_font_size <= 0:
		theme.default_font_size = FONT_BODY
	var reference: Theme = ThemeDB.get_default_theme()
	if reference != null:
		for type_name in reference.get_font_type_list():
			for font_name in reference.get_font_list(type_name):
				theme.set_font(font_name, type_name, font_body())
	theme.set_stylebox("panel", "Panel", window())
	theme.set_stylebox("panel", "PanelContainer", window())
	theme.set_stylebox("panel", "PopupMenu", window(NAVY_DEEP, FRAME, 2, 4))
	theme.set_stylebox("hover", "PopupMenu", button("hover"))
	theme.set_stylebox("panel", "PopupPanel", window(NAVY_DEEP, FRAME, 2, 4))
	theme.set_stylebox("panel", "TooltipPanel", chip(NAVY_DEEP, FRAME))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	for type_name in ["Button", "OptionButton", "CheckBox", "MenuButton"]:
		theme.set_stylebox("normal", type_name, button("normal"))
		theme.set_stylebox("hover", type_name, button("hover"))
		theme.set_stylebox("pressed", type_name, button("pressed"))
		theme.set_stylebox("disabled", type_name, button("disabled"))
		theme.set_stylebox("focus", type_name, button("focus"))
		theme.set_color("font_color", type_name, TEXT)
		theme.set_color("font_hover_color", type_name, CURSOR)
		theme.set_color("font_pressed_color", type_name, CURSOR)
		theme.set_color("font_focus_color", type_name, TEXT)
		theme.set_color("font_disabled_color", type_name, TEXT_DIM)
	theme.set_stylebox("normal", "CheckBox", chip(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	theme.set_stylebox("hover", "CheckBox", chip(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	theme.set_stylebox("pressed", "CheckBox", chip(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	theme.set_stylebox("normal", "LineEdit", field("normal"))
	theme.set_stylebox("focus", "LineEdit", field("focus"))
	theme.set_stylebox("read_only", "LineEdit", field("normal"))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	theme.set_color("caret_color", "LineEdit", CURSOR)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "RichTextLabel", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", CURSOR)
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_stylebox("scroll", "VScrollBar", panel_soft(Color(0.03, 0.04, 0.10, 0.6)))
	theme.set_stylebox("grabber", "VScrollBar", chip(FRAME_SOFT, FRAME_SOFT))
	theme.set_stylebox("grabber_highlight", "VScrollBar", chip(CURSOR, CURSOR))
	theme.set_stylebox("grabber_pressed", "VScrollBar", chip(CURSOR, CURSOR))
	_publish_project_theme(theme)
	return theme


static func _publish_project_theme(theme: Theme) -> void:
	var project: Theme = ThemeDB.get_project_theme()
	if project == null or project == theme:
		return
	project.merge_with(theme)
	project.default_font = font_body()
	project.default_font_size = theme.default_font_size


static func notify_theme_changed() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)


static func apply_heading(label: Label, size: int = FONT_CAPTION, color: Color = TEXT_GOLD) -> void:
	label.add_theme_font_override("font", font_body())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


static func dock_toggle_button(minimized: bool) -> Button:
	var button := Button.new()
	button.name = "MinimizeButton"
	button.text = "+" if minimized else "-"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(36, 30)
	button.add_theme_font_size_override("font_size", FONT_CAPTION)
	return button


static func apply_title(label: Label, size: int = FONT_TITLE, color: Color = TEXT_GOLD) -> void:
	label.add_theme_font_override("font", font_title())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


static func border_style_label(index: int) -> String:
	return "Default" if index <= 0 else "Style %d" % index


static func border_sheet_available() -> bool:
	return sheet_available("menu")


static func sheet_available(sheet: String) -> bool:
	return _sheet_image(sheet) != null


static func menu_backdrops_available() -> bool:
	return ResourceLoader.exists(MENU_BACKDROP_DIR + "BaseCamp.png")


static func active_border_style() -> int:
	var index: int = clampi(GameSettings.border_style, 0, BORDER_STYLE_COUNT)
	return index if index == 0 or sheet_available("menu") else 0


static func active_portrait_border() -> int:
	var index: int = clampi(GameSettings.portrait_border, 0, PORTRAIT_STYLE_COUNT)
	return index if index == 0 or sheet_available("portrait") else 0


static func active_sheet_style(sheet: String) -> int:
	return active_portrait_border() if sheet == "portrait" else active_border_style()


static func set_border_style(index: int) -> void:
	GameSettings.border_style = clampi(index, 0, BORDER_STYLE_COUNT)
	refresh_windows()


static func border_color_label(index: int) -> String:
	return BORDER_COLOR_NAMES[clampi(index, 0, BORDER_COLOR_COUNT - 1)]


static func active_border_color() -> int:
	return clampi(GameSettings.border_color, 0, BORDER_COLOR_COUNT - 1)


static func set_border_color(index: int) -> void:
	GameSettings.border_color = clampi(index, 0, BORDER_COLOR_COUNT - 1)
	refresh_windows()


static func portrait_border_label(index: int) -> String:
	return "Team colors" if index <= 0 else "Style %d" % index


static func set_portrait_border(index: int) -> void:
	GameSettings.portrait_border = clampi(index, 0, PORTRAIT_STYLE_COUNT)
	refresh_windows()


static func sheet_param(sheet: String, key: String) -> int:
	var spec: Dictionary = SHEETS.get(sheet, SHEETS["menu"])
	return int(spec.get(key, 0))


static func sheet_frame_px(sheet: String) -> int:
	return sheet_param(sheet, "cell") * sheet_param(sheet, "scale")


static func sheet_guard_px(sheet: String) -> int:
	return sheet_param(sheet, "scale")


static func sheet_overhang_px(sheet: String) -> int:
	return sheet_param(sheet, "overhang")


static func sheet_inset(sheet: String) -> float:
	return float(sheet_frame_px(sheet) - sheet_overhang_px(sheet) + sheet_guard_px(sheet) + sheet_param(sheet, "pad"))


static func portrait_flat(color: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PORTRAIT_FILL
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_register_flat(style, color, Color(0, 0, 0, 0))
	return style


static func portrait_frame(color: Color, width: int = 2) -> StyleBox:
	var flat: StyleBoxFlat = portrait_flat(color, width)
	var style: PmdWindowStyle = PmdWindowStyle.create(flat, PORTRAIT_FILL, color, "portrait")
	_windows.append(weakref(style))
	return style


static func palette_label(id: String) -> String:
	return String(PALETTE_LABELS.get(id, id))


static func active_palette() -> Dictionary:
	return PALETTES.get(GameSettings.ui_palette, PALETTES["navy"])


static func fill_role(color: Color) -> String:
	if color == NAVY:
		return "window"
	if color == NAVY_DEEP:
		return "deep"
	if color == NAVY_LIGHT:
		return "light"
	if color == PLATE_PRESSED:
		return "pressed"
	return ""


static func effective_fill(color: Color) -> Color:
	var role: String = fill_role(color)
	return active_palette()[role] if role != "" else color


static func set_ui_palette(id: String) -> void:
	GameSettings.ui_palette = id if PALETTES.has(id) else "navy"
	refresh_windows()


static func font_body() -> FontVariation:
	if _body_font == null:
		_body_font = FontVariation.new()
		_body_font.base_font = font_file_for(GameSettings.ui_font)
	return _body_font


static func font_title() -> FontVariation:
	if _title_font == null:
		_title_font = FontVariation.new()
		_title_font.base_font = BANNER_FONT
	return _title_font


static func font_file_for(id: String) -> FontFile:
	return FONT_FILES.get(id, TEXT_FONT)


static func font_label(id: String) -> String:
	return String(FONT_LABELS.get(id, id))


static func set_ui_font(id: String) -> void:
	GameSettings.ui_font = id if FONT_FILES.has(id) else "text"
	font_body().base_font = font_file_for(GameSettings.ui_font)
	notify_theme_changed()


static func sky_label(id: String) -> String:
	return String(SKY_LABELS.get(id, id))


static func sky_sheet_path(id: String) -> String:
	return String(SKY_SHEETS.get(id, SKY_SHEETS["sky"]))


static func menu_backdrop_label(id: String) -> String:
	return String(MENU_BACKDROP_LABELS.get(id, id))


static func menu_backdrop_path(id: String) -> String:
	if id == "sky" or not MENU_BACKDROP_LABELS.has(id):
		return ""
	return MENU_BACKDROP_DIR + id + ".png"


static func set_sky_backdrop(id: String) -> void:
	GameSettings.sky_backdrop = id if SKY_SHEETS.has(id) else "sky"
	PmdBackdrop.refresh_all()


static func set_menu_backdrop(id: String) -> void:
	GameSettings.menu_backdrop = id if MENU_BACKDROP_LABELS.has(id) else "sky"
	PmdBackdrop.refresh_all()


static func refresh_windows() -> void:
	var keep: Array[WeakRef] = []
	for ref in _windows:
		var style: PmdWindowStyle = ref.get_ref() as PmdWindowStyle
		if style == null:
			continue
		style.refresh()
		keep.append(ref)
	_windows = keep
	var keep_flats: Array[Dictionary] = []
	for entry in _flats:
		var flat: StyleBoxFlat = (entry["ref"] as WeakRef).get_ref() as StyleBoxFlat
		if flat == null:
			continue
		var role: String = String(entry["fill_role"])
		if role != "":
			flat.bg_color = active_palette()[role]
		flat.border_color = accent_for_frame(entry["frame"])
		keep_flats.append(entry)
	_flats = keep_flats
	notify_theme_changed()


static func _register_flat(style: StyleBoxFlat, frame: Color, fill: Color) -> void:
	var role: String = fill_role(fill)
	var follows_frame: bool = frame == FRAME or frame == FRAME_SOFT
	if not follows_frame and role == "":
		return
	_flats.append({"ref": weakref(style), "frame": frame, "fill_role": role})
	if role != "":
		style.bg_color = active_palette()[role]
	if follows_frame:
		style.border_color = accent_for_frame(frame)


static func accent_for_frame(frame: Color) -> Color:
	var role: String = "frame" if frame == FRAME else ("frame_soft" if frame == FRAME_SOFT else "")
	if role == "":
		return frame
	var index: int = active_border_style()
	if index == 0:
		return active_palette()[role]
	var accent: Color = frame_accent(index, active_border_color())
	return accent if role == "frame" else accent.darkened(0.35)


static func frame_accent(index: int, row: int) -> Color:
	var key: String = "%d:%d" % [index, row]
	if _frame_accents.has(key):
		return _frame_accents[key]
	var block: Image = _sheet_block("menu", index, row)
	if block == null:
		return FRAME
	var total := Color(0, 0, 0, 0)
	var count: int = 0
	for y in range(block.get_height()):
		for x in range(block.get_width()):
			var pixel: Color = block.get_pixel(x, y)
			if pixel.a > 0.0:
				total += pixel
				count += 1
	var accent: Color = (total / float(maxi(count, 1))).lerp(Color.WHITE, 0.25)
	accent.a = 1.0
	_frame_accents[key] = accent
	return accent


static func bake_window_texture(index: int, row: int, fill: Color, tint: Color = FRAME) -> ImageTexture:
	return bake_sheet_texture("menu", index, row, fill, tint)


static func bake_sheet_texture(sheet: String, index: int, row: int, fill: Color, tint: Color = FRAME) -> ImageTexture:
	var tinted: bool = tint != FRAME and tint != FRAME_SOFT
	var key: String = "%s:%d:%d:%s:%s" % [sheet, index, row, fill.to_html(true), tint.to_html(true) if tinted else "-"]
	if _window_textures.has(key):
		return _window_textures[key]
	var image: Image = _sheet_block(sheet, index, row)
	if image == null:
		return null
	var block: int = image.get_width()
	if tinted:
		_tint_ring(image, tint)
	_flood_fill(image, Vector2i(block / 2, block / 2), fill)
	var scale: int = sheet_param(sheet, "scale")
	image.resize(block * scale, block * scale, Image.INTERPOLATE_NEAREST)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_window_textures[key] = texture
	return texture


static func _sheet_block(sheet: String, index: int, row: int) -> Image:
	var image_sheet: Image = _sheet_image(sheet)
	if image_sheet == null or index < 1 or index > sheet_param(sheet, "styles") or row < 0 or row >= BORDER_COLOR_COUNT:
		return null
	var block: int = sheet_param(sheet, "cell") * 3
	var origin := Vector2i((index - 1) * block, row * block)
	var image: Image = Image.create(block, block, false, Image.FORMAT_RGBA8)
	image.blit_rect(image_sheet, Rect2i(origin, Vector2i(block, block)), Vector2i.ZERO)
	return image


static func _tint_ring(image: Image, tint: Color) -> void:
	var brightest: float = 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0:
				brightest = maxf(brightest, pixel.get_luminance())
	if brightest <= 0.0:
		return
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var level: float = pixel.get_luminance() / brightest
			image.set_pixel(x, y, Color(tint.r * level, tint.g * level, tint.b * level, pixel.a))


static func _flood_fill(image: Image, start: Vector2i, color: Color) -> void:
	var size: Vector2i = image.get_size()
	var stack: Array[Vector2i] = [start]
	var visited: Dictionary = {}
	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()
		if point.x < 0 or point.y < 0 or point.x >= size.x or point.y >= size.y or visited.has(point):
			continue
		if image.get_pixelv(point).a > 0.0:
			continue
		visited[point] = true
		image.set_pixelv(point, color)
		stack.append(point + Vector2i.RIGHT)
		stack.append(point + Vector2i.LEFT)
		stack.append(point + Vector2i.DOWN)
		stack.append(point + Vector2i.UP)


static func _sheet_image(sheet: String) -> Image:
	if _sheet_images.has(sheet):
		return _sheet_images[sheet]
	_sheet_images[sheet] = null
	var spec: Dictionary = SHEETS.get(sheet, {})
	var path: String = String(spec.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var block: int = int(spec.get("cell", 8)) * 3
	if image.get_width() < block * int(spec.get("styles", 5)) or image.get_height() < block * BORDER_COLOR_COUNT:
		return null
	_sheet_images[sheet] = image
	return image
