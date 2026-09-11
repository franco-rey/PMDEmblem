class_name MenuPanel
extends PanelContainer

var title_label: Label = null
var body: VBoxContainer = null
var footer: HBoxContainer = null
var scroll: ScrollContainer = null
var _pad: MarginContainer = null
var _fit_pending: bool = false
var _fit_passes: int = 0
var _row_widths: Dictionary = {}

const FIT_PASSES: int = 4
const FOCUS_PAD: int = 4


func _ready() -> void:
	custom_minimum_size = Vector2(PmdStyle.PANEL_WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_style: StyleBox = PmdStyle.window()
	add_theme_stylebox_override("panel", panel_style)
	panel_style.changed.connect(fit_to_viewport)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, PmdStyle.PANEL_MARGIN)
	add_child(margin)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	margin.add_child(column)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PmdStyle.apply_title(title_label, PmdStyle.FONT_TITLE)
	column.add_child(title_label)
	scroll = ScrollContainer.new()
	scroll.name = "BodyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_pad = MarginContainer.new()
	_pad.name = "Pad"
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		_pad.add_theme_constant_override("margin_%s" % side, FOCUS_PAD)
	scroll.add_child(_pad)
	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	_pad.add_child(body)
	footer = HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	column.add_child(footer)
	visibility_changed.connect(_on_panel_visibility_changed)
	if get_viewport() != null:
		get_viewport().size_changed.connect(fit_to_viewport)


func set_title(text: String) -> void:
	title_label.text = text


func add_footer_button(text: String, node_name: String, callback: Callable) -> Button:
	var button := PmdStyle.control_button(text, node_name, callback)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(button)
	return button


func add_body_button(text: String, node_name: String, callback: Callable) -> Button:
	var button := PmdStyle.control_button(text, node_name, callback)
	body.add_child(button)
	return button


func add_row(caption: String, control: Control, control_width: float = 0.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size.y = PmdStyle.ROW_HEIGHT
	row.add_child(label)
	control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, PmdStyle.ROW_HEIGHT)
	if control_width > 0.0:
		_row_widths[control] = control_width
		control.custom_minimum_size.x = control_width * PmdStyle.font_width_factor()
	else:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	body.add_child(row)
	return row


func add_caption(text: String, color: Color = PmdStyle.TEXT_DIM) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", PmdStyle.FONT_CAPTION)
	label.add_theme_color_override("font_color", color)
	body.add_child(label)
	return label


func add_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	PmdStyle.apply_heading(label, PmdStyle.FONT_BODY)
	body.add_child(label)
	return label


func _on_panel_visibility_changed() -> void:
	if visible:
		fit_to_viewport()


func fit_to_viewport() -> void:
	_fit_passes = 0
	_fit_once()


func _fit_once() -> void:
	if not is_inside_tree() or get_viewport() == null or body == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	custom_minimum_size.x = minf(PmdStyle.PANEL_WIDTH * PmdStyle.font_width_factor(), maxf(320.0, view.x - 40.0))
	var natural: float = _pad.get_combined_minimum_size().y
	var panel_style: StyleBox = get_theme_stylebox("panel")
	var chrome: float = title_label.get_combined_minimum_size().y + footer.get_combined_minimum_size().y + float(PmdStyle.PANEL_MARGIN * 2 + PmdStyle.PANEL_GAP * 2) + (panel_style.get_minimum_size().y if panel_style != null else 16.0)
	var wanted: float = minf(natural, maxf(120.0, view.y - chrome - 24.0))
	var changed: bool = not is_equal_approx(scroll.custom_minimum_size.y, wanted)
	scroll.custom_minimum_size.y = wanted
	if changed:
		reset_size()
	if (changed or _fit_passes == 0) and _fit_passes < FIT_PASSES and not _fit_pending:
		_fit_pending = true
		_fit_passes += 1
		call_deferred("_fit_again")


func _fit_again() -> void:
	_fit_pending = false
	_fit_once()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_inside_tree() and body != null:
		var factor: float = PmdStyle.font_width_factor()
		for control in _row_widths.keys():
			if control != null and is_instance_valid(control):
				(control as Control).custom_minimum_size.x = float(_row_widths[control]) * factor
		fit_to_viewport()
