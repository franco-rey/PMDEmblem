class_name CustomizePanel
extends MenuPanel

signal closed

const PICKER_WIDTH: float = 340.0
const IMPORT_HINT: String = "Import the PMD interface sheets with tools/importers/batch_assets/ui_sheet_packager.py --write"

var font_picker: OptionButton = null
var palette_picker: OptionButton = null
var border_picker: OptionButton = null
var border_color_picker: OptionButton = null
var portrait_picker: OptionButton = null
var sky_picker: OptionButton = null
var menu_backdrop_picker: OptionButton = null
var close_button: Button = null


func _ready() -> void:
	super()
	name = "CustomizePanel"
	set_title("Customize")
	font_picker = _picker("Text font", "FontPicker")
	for id in GameSettings.UI_FONTS:
		font_picker.add_item(PmdStyle.font_label(id))
	palette_picker = _picker("Interface palette", "PalettePicker")
	for id in GameSettings.UI_PALETTES:
		palette_picker.add_item(PmdStyle.palette_label(id))
	border_picker = _picker("Border style", "BorderStylePicker")
	for index in range(PmdStyle.BORDER_STYLE_COUNT + 1):
		border_picker.add_item(PmdStyle.border_style_label(index))
	border_color_picker = _picker("Border color", "BorderColorPicker")
	for index in range(PmdStyle.BORDER_COLOR_COUNT):
		border_color_picker.add_item(PmdStyle.border_color_label(index))
	portrait_picker = _picker("Portrait borders", "PortraitBorderPicker")
	for index in range(PmdStyle.PORTRAIT_STYLE_COUNT + 1):
		portrait_picker.add_item(PmdStyle.portrait_border_label(index))
	sky_picker = _picker("Sky backdrop", "SkyPicker")
	for id in GameSettings.SKY_BACKDROPS:
		sky_picker.add_item(PmdStyle.sky_label(id))
	menu_backdrop_picker = _picker("Menu backdrop", "MenuBackdropPicker")
	for id in GameSettings.MENU_BACKDROPS:
		menu_backdrop_picker.add_item(PmdStyle.menu_backdrop_label(id))
	close_button = add_footer_button("Back", "CloseButton", func() -> void: closed.emit())
	font_picker.item_selected.connect(_on_font_selected)
	palette_picker.item_selected.connect(_on_palette_selected)
	border_picker.item_selected.connect(_on_border_style_selected)
	border_color_picker.item_selected.connect(_on_border_color_selected)
	portrait_picker.item_selected.connect(_on_portrait_selected)
	sky_picker.item_selected.connect(_on_sky_selected)
	menu_backdrop_picker.item_selected.connect(_on_menu_backdrop_selected)
	refresh()


func refresh() -> void:
	font_picker.select(maxi(0, GameSettings.UI_FONTS.find(GameSettings.ui_font)))
	palette_picker.select(maxi(0, GameSettings.UI_PALETTES.find(GameSettings.ui_palette)))
	var sheets: bool = PmdStyle.border_sheet_available()
	var portraits: bool = PmdStyle.sheet_available("portrait")
	border_picker.select(clampi(GameSettings.border_style, 0, PmdStyle.BORDER_STYLE_COUNT))
	border_picker.disabled = not sheets
	border_picker.tooltip_text = IMPORT_HINT if border_picker.disabled else ""
	border_color_picker.select(clampi(GameSettings.border_color, 0, PmdStyle.BORDER_COLOR_COUNT - 1))
	border_color_picker.disabled = (not sheets and not portraits) or (GameSettings.border_style == 0 and GameSettings.portrait_border == 0)
	portrait_picker.select(clampi(GameSettings.portrait_border, 0, PmdStyle.PORTRAIT_STYLE_COUNT))
	portrait_picker.disabled = not portraits
	portrait_picker.tooltip_text = IMPORT_HINT if portrait_picker.disabled else ""
	sky_picker.select(maxi(0, GameSettings.SKY_BACKDROPS.find(GameSettings.sky_backdrop)))
	menu_backdrop_picker.select(maxi(0, GameSettings.MENU_BACKDROPS.find(GameSettings.menu_backdrop)))
	menu_backdrop_picker.disabled = not PmdStyle.menu_backdrops_available()
	menu_backdrop_picker.tooltip_text = IMPORT_HINT if menu_backdrop_picker.disabled else ""


func focus_first() -> void:
	fit_to_viewport()
	if font_picker != null and font_picker.is_inside_tree():
		font_picker.grab_focus()


func _picker(caption: String, node_name: String) -> OptionButton:
	var picker := OptionButton.new()
	picker.name = node_name
	picker.fit_to_longest_item = false
	picker.clip_text = true
	add_row(caption, picker, PICKER_WIDTH)
	return picker


func _save() -> void:
	GameSettings.save_settings()
	refresh()


func _on_font_selected(index: int) -> void:
	PmdStyle.set_ui_font(GameSettings.UI_FONTS[clampi(index, 0, GameSettings.UI_FONTS.size() - 1)])
	_save()


func _on_palette_selected(index: int) -> void:
	PmdStyle.set_ui_palette(GameSettings.UI_PALETTES[clampi(index, 0, GameSettings.UI_PALETTES.size() - 1)])
	_save()


func _on_border_style_selected(index: int) -> void:
	PmdStyle.set_border_style(index)
	_save()


func _on_border_color_selected(index: int) -> void:
	PmdStyle.set_border_color(index)
	_save()


func _on_portrait_selected(index: int) -> void:
	PmdStyle.set_portrait_border(index)
	_save()


func _on_sky_selected(index: int) -> void:
	PmdStyle.set_sky_backdrop(GameSettings.SKY_BACKDROPS[clampi(index, 0, GameSettings.SKY_BACKDROPS.size() - 1)])
	_save()


func _on_menu_backdrop_selected(index: int) -> void:
	PmdStyle.set_menu_backdrop(GameSettings.MENU_BACKDROPS[clampi(index, 0, GameSettings.MENU_BACKDROPS.size() - 1)])
	_save()
