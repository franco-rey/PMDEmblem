class_name MapPreviewScreen
extends Control

signal map_selected(index: int)
signal closed

var stage: MapPreviewStage = null
var carousel: RosterCarousel = null
var select_button: Button = null
var back_button: Button = null
var map_paths: Array[String] = []


func _ready() -> void:
	name = "MapPreviewScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = MapPreviewStage.new()
	stage.name = "MapPreviewStage"
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	var holder := HBoxContainer.new()
	holder.name = "MapRolodex"
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	holder.grow_vertical = Control.GROW_DIRECTION_BOTH
	holder.offset_left = 24.0
	add_child(holder)
	carousel = RosterCarousel.new()
	carousel.name = "MapCarousel"
	carousel.selection_changed.connect(_on_selection_changed)
	carousel.picked.connect(_on_picked)
	holder.add_child(carousel)
	var column := VBoxContainer.new()
	column.name = "Buttons"
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_right = -24.0
	column.offset_bottom = -24.0
	column.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	add_child(column)
	select_button = PmdStyle.control_button("Select Map", "SelectMapButton", _on_select_pressed)
	select_button.custom_minimum_size = Vector2(PmdStyle.CONTROL_WIDTH, PmdStyle.CONTROL_HEIGHT)
	column.add_child(select_button)
	back_button = PmdStyle.control_button("Back", "BackButton", close)
	back_button.custom_minimum_size = Vector2(PmdStyle.CONTROL_WIDTH, PmdStyle.CONTROL_HEIGHT)
	column.add_child(back_button)
	visible = false


func open(paths: Array[String], current: int) -> void:
	map_paths = paths.duplicate()
	var entries: Array[Dictionary] = []
	for path in map_paths:
		var map: MapDefinitionResource = load(path) as MapDefinitionResource
		var label: String = map.display_name if map != null and not map.display_name.is_empty() else path.get_file().get_basename().capitalize()
		entries.append({"label": label, "map_path": path, "slug": ""})
	carousel.set_entries(entries)
	visible = true
	if not entries.is_empty():
		carousel.select_index(clampi(current, 0, entries.size() - 1), false)
	carousel.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func selected_index() -> int:
	return carousel.selected_index()


func _on_selection_changed(entry: Dictionary) -> void:
	var path: String = String(entry.get("map_path", ""))
	if not path.is_empty() and path != stage.map_path:
		stage.show_map(path)


func _on_picked(entry: Dictionary) -> void:
	_on_selection_changed(entry)


func _on_select_pressed() -> void:
	var index: int = selected_index()
	visible = false
	if index >= 0:
		map_selected.emit(index)
	closed.emit()
