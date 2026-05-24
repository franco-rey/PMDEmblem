class_name SkirmishLobby
extends Control
## Scalable M5.5 skirmish setup surface.

signal launch_requested(definition: SkirmishDefinitionResource, seed: int)
signal close_requested

const SIDE_PLAYER: String = "player"
const SIDE_ENEMY: String = "enemy"
const RosterProvider = preload("res://data/modules/skirmish/skirmish_roster_provider.gd")
const FONT_SIZE: int = 20
const SMALL_FONT_SIZE: int = 18
const TITLE_FONT_SIZE: int = 24
const CELL_SIZE: Vector2 = Vector2(148, 172)
const SLOT_SIZE: Vector2 = Vector2(168, 90)
const TRAY_HEIGHT: float = 150.0
const CONTROL_HEIGHT: float = 42.0
const PANEL_COLOR: Color = Color(0.17, 0.18, 0.18, 0.96)
const ACTIVE_COLOR: Color = Color(0.22, 0.31, 0.28, 1.0)
const BORDER_COLOR: Color = Color(0.62, 0.75, 0.70, 0.95)
const MUTED_BORDER_COLOR: Color = Color(0.28, 0.35, 0.33, 0.95)

var roster_entries: Array[Dictionary] = []
var map_paths: Array[String] = []
var player_team_paths: Array[String] = []
var enemy_team_paths: Array[String] = []
var active_side: String = SIDE_PLAYER
var selected_player_index: int = -1
var selected_enemy_index: int = -1
var last_resolved_seed: int = 0

var _built: bool = false
var _last_launch_state: Dictionary = {}

var player_tray: PanelContainer
var enemy_tray: PanelContainer
var player_slots: HBoxContainer
var enemy_slots: HBoxContainer
var roster_grid: GridContainer
var roster_scroll: ScrollContainer
var search_input: LineEdit
var type_filter: OptionButton
var sort_picker: OptionButton
var map_picker: OptionButton
var seed_input: LineEdit
var difficulty_spin: SpinBox
var random_enemy_check: CheckBox
var enemy_size_spin: SpinBox
var status_label: Label
var target_label: Label
var details_label: Label
var launch_button: Button
var summary_panel: PanelContainer
var summary_label: Label
var play_again_button: Button


func _ready() -> void:
	if not _built:
		_build_ui()
	_load_data()
	_refresh_all()
	call_deferred("_update_grid_columns")


func open() -> void:
	visible = true
	_set_active_side(active_side)
	call_deferred("_update_grid_columns")


func get_roster_entries() -> Array[Dictionary]:
	return roster_entries.duplicate(true)


func get_player_team_paths() -> Array[String]:
	return player_team_paths.duplicate()


func get_enemy_team_paths() -> Array[String]:
	return enemy_team_paths.duplicate()


func get_active_side() -> String:
	return active_side


func activate_player_team() -> void:
	_set_active_side(SIDE_PLAYER)


func activate_enemy_team() -> void:
	_set_active_side(SIDE_ENEMY)


func add_roster_index(index: int) -> bool:
	if index < 0 or index >= roster_entries.size():
		_set_status("Pick a roster Pokemon first")
		return false
	return _add_to_active_team(String(roster_entries[index].get("path", "")))


func set_random_enemy_enabled(enabled: bool) -> void:
	if random_enemy_check != null:
		random_enemy_check.button_pressed = enabled
	_on_random_enemy_toggled(enabled)


func build_current_definition() -> Dictionary:
	return _build_launch_result(false)


func show_battle_summary(result: int, definition: SkirmishDefinitionResource, level: TacticsLevel) -> void:
	visible = true
	summary_panel.visible = true
	var result_text: String = "Player Win" if result == TacticsLevel.RESULT_PLAYER_WIN else "Player Loss"
	var turn_count: int = _turn_count(level)
	var player_summary: Dictionary = _side_summary(level.player if level != null else null)
	var enemy_summary: Dictionary = _side_summary(level.opponent if level != null else null)
	summary_label.text = "%s\nSeed: %d\nTurns: %d\nPlayer: %d/%d standing\nEnemy: %d/%d standing\n%s\n%s" % [
		result_text,
		definition.seed if definition != null else last_resolved_seed,
		turn_count,
		int(player_summary.get("alive", 0)),
		int(player_summary.get("total", 0)),
		int(enemy_summary.get("alive", 0)),
		int(enemy_summary.get("total", 0)),
		String(player_summary.get("detail", "")),
		String(enemy_summary.get("detail", "")),
	]
	play_again_button.disabled = _last_launch_state.is_empty()
	_set_status("")
	_refresh_launch_state()


func _build_ui() -> void:
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _make_lobby_theme()

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.11, 0.12, 0.12, 0.98)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "LayoutMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.name = "LobbyLayout"
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	player_tray = _create_team_tray("PlayerTeamTray", "Player Team", SIDE_PLAYER)
	outer.add_child(player_tray)

	var middle := HBoxContainer.new()
	middle.name = "MiddleLayout"
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	outer.add_child(middle)

	middle.add_child(_create_setup_panel())
	middle.add_child(_create_roster_panel())
	middle.add_child(_create_details_panel())

	enemy_tray = _create_team_tray("EnemyTeamTray", "Enemy Team", SIDE_ENEMY)
	outer.add_child(enemy_tray)
	resized.connect(_update_grid_columns)


func _create_team_tray(node_name: String, title: String, side: String) -> PanelContainer:
	var tray := PanelContainer.new()
	tray.name = node_name
	tray.custom_minimum_size = Vector2(0, TRAY_HEIGHT)
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	tray.gui_input.connect(_on_tray_gui_input.bind(side))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	tray.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)

	var label := Label.new()
	label.name = "%sTitle" % side.capitalize()
	label.text = title
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)

	var remove_button := Button.new()
	remove_button.name = "%sRemoveButton" % side.capitalize()
	remove_button.text = "Remove"
	remove_button.custom_minimum_size.y = CONTROL_HEIGHT
	remove_button.pressed.connect(_remove_selected_from_side.bind(side))
	header.add_child(remove_button)

	var left_button := Button.new()
	left_button.name = "%sMoveLeftButton" % side.capitalize()
	left_button.text = "<"
	left_button.custom_minimum_size = Vector2(44, CONTROL_HEIGHT)
	left_button.tooltip_text = "Move selected left"
	left_button.pressed.connect(_move_selected.bind(side, -1))
	header.add_child(left_button)

	var right_button := Button.new()
	right_button.name = "%sMoveRightButton" % side.capitalize()
	right_button.text = ">"
	right_button.custom_minimum_size = Vector2(44, CONTROL_HEIGHT)
	right_button.tooltip_text = "Move selected right"
	right_button.pressed.connect(_move_selected.bind(side, 1))
	header.add_child(right_button)

	var clear_button := Button.new()
	clear_button.name = "%sClearButton" % side.capitalize()
	clear_button.text = "Clear"
	clear_button.custom_minimum_size.y = CONTROL_HEIGHT
	clear_button.pressed.connect(_clear_side.bind(side))
	header.add_child(clear_button)

	var slots := HBoxContainer.new()
	slots.name = "%sSlots" % side.capitalize()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation", 8)
	column.add_child(slots)

	if side == SIDE_PLAYER:
		player_slots = slots
	else:
		enemy_slots = slots
	return tray


func _create_setup_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "SetupPanel"
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_box(PANEL_COLOR, MUTED_BORDER_COLOR, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var top_row := HBoxContainer.new()
	column.add_child(top_row)

	var title := Label.new()
	title.text = "Skirmish"
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Back"
	close_button.custom_minimum_size.y = CONTROL_HEIGHT
	close_button.pressed.connect(_on_close_pressed)
	top_row.add_child(close_button)

	map_picker = OptionButton.new()
	map_picker.name = "MapPicker"
	column.add_child(_labeled_control("Map", map_picker))

	seed_input = LineEdit.new()
	seed_input.name = "SeedInput"
	seed_input.placeholder_text = "integer or blank"
	seed_input.text_changed.connect(_on_seed_changed)
	column.add_child(_labeled_control("Seed", seed_input))

	difficulty_spin = SpinBox.new()
	difficulty_spin.name = "DifficultySpin"
	difficulty_spin.min_value = 0
	difficulty_spin.max_value = 4
	difficulty_spin.step = 1
	difficulty_spin.value = CustomSkirmishBuilder.DEFAULT_RANDOM_DIFFICULTY_TIER
	column.add_child(_labeled_control("Difficulty", difficulty_spin))

	random_enemy_check = CheckBox.new()
	random_enemy_check.name = "RandomEnemyCheck"
	random_enemy_check.text = "Random Enemy"
	random_enemy_check.custom_minimum_size.y = CONTROL_HEIGHT
	random_enemy_check.toggled.connect(_on_random_enemy_toggled)
	column.add_child(random_enemy_check)

	enemy_size_spin = SpinBox.new()
	enemy_size_spin.name = "EnemySizeSpin"
	enemy_size_spin.min_value = CustomSkirmishBuilder.MIN_TEAM_SIZE
	enemy_size_spin.max_value = CustomSkirmishBuilder.MAX_TEAM_SIZE
	enemy_size_spin.step = 1
	enemy_size_spin.value = 3
	column.add_child(_labeled_control("Enemy Size", enemy_size_spin))

	launch_button = Button.new()
	launch_button.name = "LaunchButton"
	launch_button.text = "Launch Skirmish"
	launch_button.custom_minimum_size.y = 48
	launch_button.pressed.connect(_on_launch_pressed)
	column.add_child(launch_button)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 48)
	column.add_child(status_label)

	summary_panel = PanelContainer.new()
	summary_panel.name = "SummaryPanel"
	summary_panel.visible = false
	summary_panel.add_theme_stylebox_override("panel", _style_box(Color(0.13, 0.15, 0.15, 1.0), MUTED_BORDER_COLOR, 1))
	column.add_child(summary_panel)

	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 8)
	summary_margin.add_theme_constant_override("margin_top", 8)
	summary_margin.add_theme_constant_override("margin_right", 8)
	summary_margin.add_theme_constant_override("margin_bottom", 8)
	summary_panel.add_child(summary_margin)

	var summary_column := VBoxContainer.new()
	summary_column.add_theme_constant_override("separation", 8)
	summary_margin.add_child(summary_column)

	summary_label = Label.new()
	summary_label.name = "SummaryLabel"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_column.add_child(summary_label)

	play_again_button = Button.new()
	play_again_button.name = "PlayAgainButton"
	play_again_button.text = "Play Again"
	play_again_button.custom_minimum_size.y = CONTROL_HEIGHT
	play_again_button.pressed.connect(_on_play_again_pressed)
	summary_column.add_child(play_again_button)

	var back_to_lobby_button := Button.new()
	back_to_lobby_button.name = "BackToLobbyButton"
	back_to_lobby_button.text = "Back to Lobby"
	back_to_lobby_button.custom_minimum_size.y = CONTROL_HEIGHT
	back_to_lobby_button.pressed.connect(_on_back_to_lobby_pressed)
	summary_column.add_child(back_to_lobby_button)
	return panel


func _create_roster_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "RosterPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_box(PANEL_COLOR, MUTED_BORDER_COLOR, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	column.add_child(toolbar)

	search_input = LineEdit.new()
	search_input.name = "SearchInput"
	search_input.placeholder_text = "Search"
	search_input.custom_minimum_size.y = CONTROL_HEIGHT
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_changed.connect(_on_search_changed)
	toolbar.add_child(search_input)

	type_filter = OptionButton.new()
	type_filter.name = "TypeFilter"
	type_filter.custom_minimum_size = Vector2(170, CONTROL_HEIGHT)
	type_filter.item_selected.connect(_on_filter_changed)
	toolbar.add_child(type_filter)

	sort_picker = OptionButton.new()
	sort_picker.name = "SortPicker"
	sort_picker.custom_minimum_size = Vector2(150, CONTROL_HEIGHT)
	sort_picker.item_selected.connect(_on_filter_changed)
	toolbar.add_child(sort_picker)

	roster_scroll = ScrollContainer.new()
	roster_scroll.name = "RosterScroll"
	roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(roster_scroll)

	roster_grid = GridContainer.new()
	roster_grid.name = "RosterGrid"
	roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_grid.add_theme_constant_override("h_separation", 12)
	roster_grid.add_theme_constant_override("v_separation", 12)
	roster_scroll.add_child(roster_grid)
	return panel


func _create_details_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "DetailsPanel"
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_box(PANEL_COLOR, MUTED_BORDER_COLOR, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	target_label = Label.new()
	target_label.name = "TargetLabel"
	target_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(target_label)

	details_label = Label.new()
	details_label.name = "DetailsLabel"
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(details_label)
	return panel


func _labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
	box.add_child(label)
	control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, CONTROL_HEIGHT)
	box.add_child(control)
	return box


func _load_data() -> void:
	roster_entries = RosterProvider.entries()
	map_paths = CustomSkirmishBuilder.map_paths()

	map_picker.clear()
	for path in map_paths:
		var map: MapDefinitionResource = load(path) as MapDefinitionResource
		var label: String = map.display_name if map != null and not map.display_name.is_empty() else path.get_file().get_basename().capitalize()
		map_picker.add_item(label)

	type_filter.clear()
	type_filter.add_item("All Types")
	var types: Array[String] = []
	for entry in roster_entries:
		for type in entry.get("types", []):
			if not types.has(type):
				types.append(type)
	types.sort()
	for type in types:
		type_filter.add_item(type.capitalize())
		type_filter.set_item_metadata(type_filter.item_count - 1, type)

	sort_picker.clear()
	sort_picker.add_item("Dex")
	sort_picker.set_item_metadata(0, "dex")
	sort_picker.add_item("Name")
	sort_picker.set_item_metadata(1, "name")
	sort_picker.add_item("Type")
	sort_picker.set_item_metadata(2, "type")


func _refresh_all() -> void:
	_refresh_roster()
	_refresh_team_trays()
	_refresh_details()
	_refresh_launch_state()


func _refresh_roster() -> void:
	for child in roster_grid.get_children():
		roster_grid.remove_child(child)
		child.queue_free()
	var filtered: Array[Dictionary] = []
	var query: String = search_input.text.strip_edges().to_lower()
	var selected_type: String = _selected_type()
	for entry in roster_entries:
		var label: String = String(entry.get("label", ""))
		var slug: String = String(entry.get("slug", ""))
		if not query.is_empty() and not label.to_lower().contains(query) and not slug.to_lower().contains(query):
			continue
		if not selected_type.is_empty() and not (entry.get("types", []) as Array).has(selected_type):
			continue
		filtered.append(entry)
	filtered.sort_custom(_is_roster_entry_less_than)
	for entry in filtered:
		roster_grid.add_child(_create_roster_cell(entry))


func _create_roster_cell(entry: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Roster_%s" % String(entry.get("slug", "pokemon"))
	button.custom_minimum_size = CELL_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = String(entry.get("label", ""))
	button.pressed.connect(_on_roster_pressed.bind(String(entry.get("path", ""))))

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6
	content.offset_top = 6
	content.offset_right = -6
	content.offset_bottom = -6
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 3)
	button.add_child(content)

	var texture_rect := TextureRect.new()
	texture_rect.name = "Portrait"
	texture_rect.texture = RosterProvider.texture_for_entry(entry)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(108, 112)
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	content.add_child(texture_rect)

	var label := Label.new()
	label.name = "NameLabel"
	label.text = String(entry.get("label", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	return button


func _refresh_team_trays() -> void:
	_populate_slots(player_slots, player_team_paths, SIDE_PLAYER)
	_populate_slots(enemy_slots, enemy_team_paths, SIDE_ENEMY)
	player_tray.add_theme_stylebox_override("panel", _style_box(ACTIVE_COLOR if active_side == SIDE_PLAYER else PANEL_COLOR, BORDER_COLOR if active_side == SIDE_PLAYER else MUTED_BORDER_COLOR, 2 if active_side == SIDE_PLAYER else 1))
	enemy_tray.add_theme_stylebox_override("panel", _style_box(ACTIVE_COLOR if active_side == SIDE_ENEMY else PANEL_COLOR, BORDER_COLOR if active_side == SIDE_ENEMY else MUTED_BORDER_COLOR, 2 if active_side == SIDE_ENEMY else 1))


func _populate_slots(container: HBoxContainer, team: Array[String], side: String) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for i in range(CustomSkirmishBuilder.MAX_TEAM_SIZE):
		var path: String = team[i] if i < team.size() else ""
		container.add_child(_create_slot_button(path, i, side))


func _create_slot_button(path: String, index: int, side: String) -> Button:
	var button := Button.new()
	button.name = "%sSlot%d" % [side.capitalize(), index + 1]
	button.custom_minimum_size = SLOT_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.button_pressed = _selected_index_for(side) == index and not path.is_empty()
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = "Slot %d" % (index + 1)
	button.pressed.connect(_on_team_slot_pressed.bind(side, index))

	var content := HBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 5
	content.offset_top = 4
	content.offset_right = -5
	content.offset_bottom = -4
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	button.add_child(content)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	content.add_child(portrait)

	var label := Label.new()
	label.name = "NameLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)

	if path.is_empty():
		label.text = "%d" % (index + 1)
	else:
		var entry: Dictionary = _entry_for_path(path)
		portrait.texture = RosterProvider.texture_for_entry(entry)
		label.text = String(entry.get("label", RosterProvider.label_for_path(path)))
	return button


func _refresh_details() -> void:
	var target: String = "Player" if active_side == SIDE_PLAYER else "Enemy"
	target_label.text = "Add Target: %s" % target
	var player_names: String = _format_team(player_team_paths)
	var enemy_names: String = _format_team(enemy_team_paths)
	details_label.text = "Player %d/%d\n%s\n\nEnemy %d/%d\n%s" % [
		player_team_paths.size(),
		CustomSkirmishBuilder.MAX_TEAM_SIZE,
		player_names,
		enemy_team_paths.size(),
		CustomSkirmishBuilder.MAX_TEAM_SIZE,
		enemy_names,
	]


func _refresh_launch_state() -> void:
	var map_ok: bool = not map_paths.is_empty()
	var seed_ok: bool = seed_input.text.strip_edges().is_empty() or seed_input.text.strip_edges().is_valid_int()
	var teams_ok: bool = not player_team_paths.is_empty() and (random_enemy_check.button_pressed or not enemy_team_paths.is_empty())
	launch_button.disabled = not (map_ok and seed_ok and teams_ok)


func _selected_type() -> String:
	var idx: int = type_filter.selected
	if idx <= 0:
		return ""
	var metadata: Variant = type_filter.get_item_metadata(idx)
	return String(metadata)


func _is_roster_entry_less_than(a: Dictionary, b: Dictionary) -> bool:
	var mode: String = String(sort_picker.get_item_metadata(maxi(sort_picker.selected, 0)))
	match mode:
		"name":
			return String(a.get("label", "")) < String(b.get("label", ""))
		"type":
			var a_type: String = ",".join(a.get("types", []))
			var b_type: String = ",".join(b.get("types", []))
			if a_type != b_type:
				return a_type < b_type
			return int(a.get("dex_number", 0)) < int(b.get("dex_number", 0))
		_:
			return int(a.get("dex_number", 0)) < int(b.get("dex_number", 0))


func _on_tray_gui_input(event: InputEvent, side: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_active_side(side)


func _set_active_side(side: String) -> void:
	active_side = side if side == SIDE_ENEMY else SIDE_PLAYER
	_set_status("")
	_refresh_team_trays()
	_refresh_details()


func _on_roster_pressed(path: String) -> void:
	_add_to_active_team(path)


func _add_to_active_team(path: String) -> bool:
	if path.is_empty():
		_set_status("Pick a roster Pokemon first")
		return false
	var team: Array[String] = player_team_paths if active_side == SIDE_PLAYER else enemy_team_paths
	if team.size() >= CustomSkirmishBuilder.MAX_TEAM_SIZE:
		_set_status("%s team is at the %d-Pokemon cap" % [_side_label(active_side), CustomSkirmishBuilder.MAX_TEAM_SIZE])
		return false
	team.append(path)
	if active_side == SIDE_PLAYER:
		selected_player_index = team.size() - 1
	else:
		selected_enemy_index = team.size() - 1
	summary_panel.visible = false
	_set_status("")
	_refresh_team_trays()
	_refresh_details()
	_refresh_launch_state()
	return true


func _on_team_slot_pressed(side: String, index: int) -> void:
	_set_active_side(side)
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	if index >= team.size():
		if side == SIDE_PLAYER:
			selected_player_index = -1
		else:
			selected_enemy_index = -1
		_refresh_team_trays()
		return
	if side == SIDE_PLAYER:
		selected_player_index = index
	else:
		selected_enemy_index = index
	_refresh_team_trays()


func _remove_selected_from_side(side: String) -> void:
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	if team.is_empty():
		_set_status("%s team is already empty" % _side_label(side))
		return
	var idx: int = _selected_index_for(side)
	if idx < 0 or idx >= team.size():
		idx = team.size() - 1
	team.remove_at(idx)
	_set_selected_index_for(side, mini(idx, team.size() - 1))
	_set_status("")
	_refresh_team_trays()
	_refresh_details()
	_refresh_launch_state()


func _clear_side(side: String) -> void:
	if side == SIDE_PLAYER:
		player_team_paths.clear()
		selected_player_index = -1
	else:
		enemy_team_paths.clear()
		selected_enemy_index = -1
	_set_active_side(side)
	_refresh_launch_state()


func _move_selected(side: String, delta: int) -> void:
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	var idx: int = _selected_index_for(side)
	var next_idx: int = idx + delta
	if idx < 0 or idx >= team.size() or next_idx < 0 or next_idx >= team.size():
		return
	var moving: String = team[idx]
	team[idx] = team[next_idx]
	team[next_idx] = moving
	_set_selected_index_for(side, next_idx)
	_refresh_team_trays()
	_refresh_details()


func _selected_index_for(side: String) -> int:
	return selected_player_index if side == SIDE_PLAYER else selected_enemy_index


func _set_selected_index_for(side: String, index: int) -> void:
	if side == SIDE_PLAYER:
		selected_player_index = index
	else:
		selected_enemy_index = index


func _on_search_changed(_text: String) -> void:
	_refresh_roster()


func _on_filter_changed(_index: int) -> void:
	_refresh_roster()


func _on_seed_changed(_text: String) -> void:
	_refresh_launch_state()


func _on_random_enemy_toggled(_enabled: bool) -> void:
	_refresh_details()
	_refresh_launch_state()


func _on_launch_pressed() -> void:
	var result: Dictionary = _build_launch_result(true)
	if not result.get("ok", false):
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	launch_requested.emit(definition, int(result["seed"]))


func _on_play_again_pressed() -> void:
	if _last_launch_state.is_empty():
		return
	var result: Dictionary = _build_from_state(_last_launch_state)
	if not result.get("ok", false):
		_set_status(String(result.get("error", "Could not replay skirmish")))
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	last_resolved_seed = int(result["seed"])
	launch_requested.emit(definition, last_resolved_seed)


func _on_back_to_lobby_pressed() -> void:
	summary_panel.visible = false
	_refresh_launch_state()


func _on_close_pressed() -> void:
	visible = false
	close_requested.emit()


func _build_launch_result(store_state: bool) -> Dictionary:
	if map_paths.is_empty():
		_set_status("No maps available")
		return {"ok": false, "error": "No maps available"}
	var map_path: String = map_paths[clampi(map_picker.selected, 0, map_paths.size() - 1)]
	var state: Dictionary = {
		"random_enemy": random_enemy_check.button_pressed,
		"player_paths": player_team_paths.duplicate(),
		"enemy_paths": enemy_team_paths.duplicate(),
		"map_path": map_path,
		"seed_text": seed_input.text,
		"enemy_team_size": int(enemy_size_spin.value),
		"difficulty_tier": int(difficulty_spin.value),
	}
	var result: Dictionary = _build_from_state(state)
	if not result.get("ok", false):
		_set_status(String(result.get("error", "Could not build skirmish")))
		return result
	last_resolved_seed = int(result["seed"])
	seed_input.text = str(last_resolved_seed)
	if store_state:
		state["seed_text"] = str(last_resolved_seed)
		_last_launch_state = state
	summary_panel.visible = false
	_set_status("Seed: %d" % last_resolved_seed)
	return result


func _build_from_state(state: Dictionary) -> Dictionary:
	if bool(state.get("random_enemy", false)):
		return CustomSkirmishBuilder.build_with_random_enemy(
			_string_array(state.get("player_paths", [])),
			String(state.get("map_path", "")),
			String(state.get("seed_text", "")),
			int(state.get("enemy_team_size", 1)),
			int(state.get("difficulty_tier", CustomSkirmishBuilder.DEFAULT_RANDOM_DIFFICULTY_TIER))
		)
	return CustomSkirmishBuilder.build(
		_string_array(state.get("player_paths", [])),
		_string_array(state.get("enemy_paths", [])),
		String(state.get("map_path", "")),
		String(state.get("seed_text", ""))
	)


func _update_grid_columns() -> void:
	if roster_grid == null or roster_scroll == null:
		return
	var available_width: float = maxf(roster_scroll.size.x, CELL_SIZE.x * 3.0)
	roster_grid.columns = clampi(int(floor(available_width / (CELL_SIZE.x + 12.0))), 3, 10)


func _entry_for_path(path: String) -> Dictionary:
	for entry in roster_entries:
		if String(entry.get("path", "")) == path:
			return entry
	return {
		"path": path,
		"slug": path.get_file().get_basename(),
		"label": RosterProvider.label_for_path(path),
		"portrait_path": RosterProvider.FALLBACK_ICON_PATH,
	}


func _format_team(team: Array[String]) -> String:
	if team.is_empty():
		return "(empty)"
	var labels: Array[String] = []
	for path in team:
		labels.append(String(_entry_for_path(path).get("label", RosterProvider.label_for_path(path))))
	return ", ".join(labels)


func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item in value:
			out.append(String(item))
	return out


func _side_label(side: String) -> String:
	return "Player" if side == SIDE_PLAYER else "Enemy"


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _style_box(color: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style


func _make_lobby_theme() -> Theme:
	var lobby_theme := Theme.new()
	lobby_theme.set_font_size("font_size", "Button", FONT_SIZE)
	lobby_theme.set_font_size("font_size", "CheckBox", FONT_SIZE)
	lobby_theme.set_font_size("font_size", "Label", FONT_SIZE)
	lobby_theme.set_font_size("font_size", "LineEdit", FONT_SIZE)
	lobby_theme.set_font_size("font_size", "OptionButton", FONT_SIZE)
	lobby_theme.set_font_size("font_size", "SpinBox", FONT_SIZE)
	return lobby_theme


func _turn_count(level: TacticsLevel) -> int:
	if level == null or level.battle_log == null:
		return 0
	var count: int = 0
	for event in level.battle_log.events:
		if String(event.get("kind", "")) == "turn_started":
			count += 1
	return count


func _side_summary(parent: Node) -> Dictionary:
	var total: int = 0
	var alive: int = 0
	var details: Array[String] = []
	if parent != null:
		for child in parent.get_children():
			if not (child is TacticsPawn):
				continue
			var pawn: TacticsPawn = child
			total += 1
			if pawn.is_alive():
				alive += 1
			if pawn.stats != null:
				details.append("%s %d/%d HP" % [pawn.stats.species_name, pawn.stats.curr_health, pawn.stats.max_health])
	return {
		"total": total,
		"alive": alive,
		"detail": ", ".join(details),
	}
