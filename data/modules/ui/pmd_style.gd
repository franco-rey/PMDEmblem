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


static func window(fill: Color = NAVY, frame: Color = FRAME, width: int = 3, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
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
	return style


static func panel_soft(fill: Color = NAVY_DEEP) -> StyleBoxFlat:
	var style := window(fill, FRAME_SOFT, 1, 4)
	style.shadow_size = 0
	return style


static func chip(fill: Color = NAVY_DEEP, frame: Color = FRAME_SOFT) -> StyleBoxFlat:
	var style := window(fill, frame, 1, 4)
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
			style = window(NAVY_LIGHT, CURSOR, PLATE_FRAME, RADIUS)
		"pressed":
			style = window(PLATE_PRESSED, CURSOR, PLATE_FRAME, RADIUS)
		"disabled":
			style = window(NAVY_DEEP, FRAME_SOFT, PLATE_FRAME, RADIUS)
		"focus":
			style = window(Color(0, 0, 0, 0), CURSOR, PLATE_FRAME, RADIUS)
			style.draw_center = false
			style.shadow_size = 0
		_:
			style = window(NAVY_DEEP, FRAME, PLATE_FRAME, RADIUS)
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
	theme.default_font = TEXT_FONT
	if theme.default_font_size <= 0:
		theme.default_font_size = FONT_BODY
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
	return theme


static func apply_heading(label: Label, size: int = FONT_CAPTION, color: Color = TEXT_GOLD) -> void:
	label.add_theme_font_override("font", TEXT_FONT)
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
	label.add_theme_font_override("font", BANNER_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
