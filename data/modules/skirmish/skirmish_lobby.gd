class_name SkirmishLobby
extends Control

signal launch_requested(definition: SkirmishDefinitionResource, seed: int)
signal launch_series_requested(definitions: Array[SkirmishDefinitionResource], code: String)
signal close_requested

const SIDE_PLAYER: String = "player"
const SIDE_ENEMY: String = "enemy"
const RosterProvider = preload("res://data/modules/skirmish/skirmish_roster_provider.gd")
const SkirmishCode = preload("res://data/modules/skirmish/skirmish_code.gd")
const SkirmishControlMode = preload("res://data/modules/skirmish/skirmish_control_mode.gd")
const FONT_SIZE: int = PmdStyle.FONT_BODY
const TITLE_FONT_SIZE: int = PmdStyle.FONT_TITLE
const COMPACT_FONT_SIZE: int = PmdStyle.FONT_CAPTION
const COMPACT_TITLE_FONT_SIZE: int = PmdStyle.FONT_CAPTION
const PORTRAIT_FLASH_SECONDS: float = 0.9
const SELECTED_PORTRAIT_PX: float = 96.0
const LARGE_FONT_LAYOUT_WIDTH: float = 1700.0
const TITLE_FONT_GROUP: String = "lobby_title_font"
const BODY_FONT_GROUP: String = "lobby_body_font"
const CELL_SIZE: Vector2 = Vector2(108, 108)
const ROSTER_COLUMNS: int = 10
const ROSTER_MIN_CELL: float = 40.0
const SLOT_SIZE: Vector2 = Vector2(96, 64)
const SLOT_PORTRAIT_SIZE: Vector2 = Vector2(52, 52)
const CHOOSER_ROW_SIZE: Vector2 = Vector2(250, 56)
const CHOOSER_ICON_SIZE: Vector2 = Vector2(40, 40)
const CHOOSER_MIN_COLUMNS: int = 2
const CHOOSER_MAX_COLUMNS: int = 6
const CHOOSER_ITEM: String = "item"
const CHOOSER_MOVES: String = "moves"
const CHOOSER_ABILITY: String = "ability"
const TRAY_HEIGHT: float = 112.0
const SLOT_COLUMNS: int = 8
const COMPACT_SLOT_HEIGHT: float = 50.0
const CONTROL_HEIGHT: float = PmdStyle.ROW_HEIGHT
const MAP_PREVIEW_LABEL: String = "Preview..."
const SCROLL_PAD_RIGHT: int = 12
const PAGE_MATCH: String = "match"
const PAGES: Array[String] = ["match", "player", "enemy"]
const REMOTE_CHOOSING_MS: int = 3000
const GRID_GAP: float = 8.0
const LAYOUT_MARGIN_X: float = 20.0
const PANEL_MARGIN_X: float = 10.0
const MIDDLE_GAP: float = 20.0
const COMPACT_LAYOUT_WIDTH: float = 1600.0
const SETUP_PANEL_WIDTH: float = 320.0
const SETUP_PANEL_COMPACT_WIDTH: float = 260.0
const DETAILS_PANEL_WIDTH: float = 310.0
const DETAILS_PANEL_COMPACT_WIDTH: float = 300.0
const TYPE_FILTER_WIDTH: float = 170.0
const TYPE_FILTER_COMPACT_WIDTH: float = 130.0
const SORT_PICKER_WIDTH: float = 150.0
const SORT_PICKER_COMPACT_WIDTH: float = 105.0
const PANEL_COLOR: Color = Color(0.17, 0.18, 0.18, 0.96)
const ACTIVE_COLOR: Color = Color(0.22, 0.31, 0.28, 1.0)
const BORDER_COLOR: Color = Color(0.62, 0.75, 0.70, 0.95)
const MUTED_BORDER_COLOR: Color = Color(0.28, 0.35, 0.33, 0.95)

var body_font_size: int = FONT_SIZE
var title_font_size: int = TITLE_FONT_SIZE
var selected_portrait: TextureRect = null
var selected_portrait_frame: PanelContainer = null
var selected_name_label: Label = null
var selected_types_label: Label = null
var selected_path: String = ""
var selected_expression: String = PortraitLibrary.NORMAL
var _flash_serial: int = 0
var roster_entries: Array[Dictionary] = []
var map_paths: Array[String] = []
var player_team_paths: Array[String] = []
var enemy_team_paths: Array[String] = []
var player_slot_specs: Array[Dictionary] = []
var enemy_slot_specs: Array[Dictionary] = []
var item_choices: Array[Dictionary] = []
var roster_cell_scale: float = 1.0
var roster_cell_px: float = CELL_SIZE.x
var last_launch_code: String = ""
var code_output: LineEdit = null
var chooser_mode: String = ""
var chooser_side: String = SIDE_PLAYER
var chooser_slot: int = -1
var chooser_selection: Array[String] = []
var active_side: String = SIDE_PLAYER
var selected_player_index: int = -1
var selected_enemy_index: int = -1
var last_resolved_seed: int = 0

var _built: bool = false
var _last_launch_state: Dictionary = {}
var net_session: NetSession = null
var net_ready_check: CheckButton = null
var net_status_label: Label = null
var copy_address_button: Button = null
var copy_code_button: Button = null
var remote_ready_cues: int = 0
var _remote_ready_seen: bool = false
var _net_syncing: bool = false
var _net_sent: Dictionary = {}
var _net_push_timer: float = 0.0
var _remote_items: Array = []
var _remote_specs: Array = []
var _remote_random: bool = false

var player_tray: PanelContainer
var enemy_tray: PanelContainer
var player_tray_title: Label = null
var enemy_tray_title: Label = null
var _remote_changed_at: int = 0
var _remote_fingerprint: String = ""
var _net_title_timer: float = 0.0
var _scroll_pads: Array[MarginContainer] = []
var player_slots: GridContainer
var enemy_slots: GridContainer
var setup_panel: PanelContainer
var details_panel: Control
var setup_grid: GridContainer = null
var match_page: VBoxContainer = null
var match_grid: GridContainer = null
var editor_grid: GridContainer = null
var setup_tabs: Dictionary = {}
var setup_page: String = PAGE_MATCH
var roster_grid: GridContainer
var roster_scroll: ScrollContainer
var search_input: LineEdit
var type_filter: OptionButton
var sort_picker: OptionButton
var map_picker: OptionButton
var map_preview: MapPreviewScreen = null
var _map_index: int = 0
var control_mode_picker: OptionButton
var multiverse_toggle: CheckButton
var ai_level_spin: SpinBox
var seed_input: LineEdit
var reroll_seed_check: CheckButton
var difficulty_spin: SpinBox
var random_enemy_check: CheckButton
var random_player_check: CheckButton
var enemy_size_spin: HSlider
var player_size_slider: HSlider
var status_label: Label
var target_label: Label
var details_label: Label
var slot_title_label: Label
var random_moves_check: CheckButton
var choose_moves_button: Button
var moves_value_label: Label
var random_form_check: CheckButton
var form_picker: OptionButton
var form_value_label: Label
var random_gender_check: CheckButton
var gender_picker: OptionButton
var gender_value_label: Label
var random_ability_check: CheckButton
var choose_ability_button: Button
var ability_value_label: Label
var random_item_check: CheckButton
var choose_item_button: Button
var clear_item_button: Button
var item_value_label: Label
var chooser_panel: PanelContainer
var chooser_title: Label
var chooser_search: LineEdit
var chooser_grid: GridContainer
var chooser_scroll: ScrollContainer
var chooser_counter: Label
var chooser_done_button: Button
var launch_button: Button
var summary_panel: PanelContainer
var summary_label: Label
var play_again_button: Button


func _ready() -> void:
	if not _built:
		_build_ui()
		_show_setup_page(PAGE_MATCH)
	_load_data()
	_refresh_all()
	_queue_update_grid_columns()


func open() -> void:
	visible = true
	MusicPlayer.play_scene("lobby")
	_set_active_side(active_side)
	_queue_update_grid_columns()


func get_roster_entries() -> Array[Dictionary]:
	return roster_entries.duplicate(true)


func get_player_team_paths() -> Array[String]:
	return player_team_paths.duplicate()


func get_enemy_team_paths() -> Array[String]:
	return enemy_team_paths.duplicate()


func get_player_item_ids() -> Array[String]:
	return _items_for_side(SIDE_PLAYER)


func get_enemy_item_ids() -> Array[String]:
	return _items_for_side(SIDE_ENEMY)


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


func set_random_player_enabled(enabled: bool) -> void:
	if random_player_check != null:
		random_player_check.button_pressed = enabled
	_on_random_player_toggled(enabled)


func set_random_enemy_enabled(enabled: bool) -> void:
	if random_enemy_check != null:
		random_enemy_check.button_pressed = enabled
	_on_random_enemy_toggled(enabled)


func get_slot_spec(side: String, index: int) -> Dictionary:
	var specs: Array[Dictionary] = _specs_for_side(side)
	return specs[index].duplicate(true) if index >= 0 and index < specs.size() else {}


func set_held_item(side: String, index: int, item_id: String) -> bool:
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	if index < 0 or index >= team.size():
		_set_status("Pick a team slot first")
		return false
	if not item_id.is_empty() and item_id != CustomSkirmishBuilder.RANDOM_CHOICE and not BattleItemCatalog.is_selectable(item_id):
		_set_status("Unknown item %s" % item_id)
		return false
	_sync_specs(side)
	var spec: Dictionary = _specs_for_side(side)[index]
	spec["item"] = "" if item_id == CustomSkirmishBuilder.RANDOM_CHOICE else item_id
	spec["random_item"] = item_id == CustomSkirmishBuilder.RANDOM_CHOICE
	_set_status("")
	_refresh_team_trays()
	_refresh_details()
	_refresh_slot_section()
	return true


func set_slot_moves(side: String, index: int, move_ids: Array) -> bool:
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	if index < 0 or index >= team.size():
		_set_status("Pick a team slot first")
		return false
	_sync_specs(side)
	var spec: Dictionary = _specs_for_side(side)[index]
	var chosen: Array[String] = []
	for raw in move_ids:
		var move_id: String = String(raw)
		if not move_id.is_empty() and not chosen.has(move_id) and chosen.size() < PokemonInstanceResource.MAX_MOVE_SLOTS:
			chosen.append(move_id)
	spec["moves"] = chosen
	spec["random_moves"] = chosen.is_empty()
	_refresh_details()
	_refresh_slot_section()
	return true


func set_slot_ability(side: String, index: int, ability_id: String) -> bool:
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	if index < 0 or index >= team.size():
		_set_status("Pick a team slot first")
		return false
	_sync_specs(side)
	var spec: Dictionary = _specs_for_side(side)[index]
	spec["ability"] = "" if ability_id == CustomSkirmishBuilder.RANDOM_CHOICE else ability_id
	spec["random_ability"] = ability_id.is_empty() or ability_id == CustomSkirmishBuilder.RANDOM_CHOICE
	_refresh_details()
	_refresh_slot_section()
	return true


func set_slot_form(side: String, index: int, form_value: String) -> bool:
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	if index < 0 or index >= team.size():
		_set_status("Pick a team slot first")
		return false
	_sync_specs(side)
	var spec: Dictionary = _specs_for_side(side)[index]
	if form_value.is_empty() or form_value == CustomSkirmishBuilder.RANDOM_CHOICE:
		spec["form"] = ""
		spec["random_form"] = true
	else:
		if not form_value.is_valid_int():
			_set_status("Unknown form %s" % form_value)
			return false
		var entry: Dictionary = _entry_for_path(team[index])
		var error: String = FormRules.choice_error(_species_for_entry(entry), int(form_value), String(entry.get("label", "")))
		if not error.is_empty():
			_set_status(error)
			return false
		spec["form"] = str(int(form_value))
		spec["random_form"] = false
	_set_status("")
	_refresh_details()
	_refresh_slot_section()
	return true


func set_slot_gender(side: String, index: int, gender_id: String) -> bool:
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	if index < 0 or index >= team.size():
		_set_status("Pick a team slot first")
		return false
	_sync_specs(side)
	var spec: Dictionary = _specs_for_side(side)[index]
	if gender_id.is_empty() or gender_id == CustomSkirmishBuilder.RANDOM_CHOICE:
		spec["gender"] = ""
		spec["random_gender"] = true
	else:
		var wanted: int = GenderRules.parse_id(gender_id)
		if wanted == GenderRules.UNKNOWN:
			_set_status("Unknown gender %s" % gender_id)
			return false
		var entry: Dictionary = _entry_for_path(team[index])
		var error: String = GenderRules.choice_error(_form_for_entry(entry), wanted, String(entry.get("label", "")))
		if not error.is_empty():
			_set_status(error)
			return false
		spec["gender"] = GenderRules.id(wanted)
		spec["random_gender"] = false
	_set_status("")
	_refresh_details()
	_refresh_slot_section()
	return true


func build_current_definition() -> Dictionary:
	return _build_launch_result(false)


func show_battle_summary(result: int, definition: SkirmishDefinitionResource, level: TacticsLevel) -> void:
	visible = true
	summary_panel.visible = true
	var result_text: String = _result_label(result, definition)
	var turn_count: int = _turn_count(level)
	var player_summary: Dictionary = _side_summary(level.player if level != null else null)
	var enemy_summary: Dictionary = _side_summary(level.opponent if level != null else null)
	summary_label.text = "%s\nMode: %s\nSeed: %d\nTurns: %d\nPlayer: %d/%d standing\nEnemy: %d/%d standing\n%s\n%s" % [
		result_text,
		SkirmishControlMode.label(definition.control_mode if definition != null else ""),
		definition.seed if definition != null else last_resolved_seed,
		turn_count,
		int(player_summary.get("alive", 0)),
		int(player_summary.get("total", 0)),
		int(enemy_summary.get("alive", 0)),
		int(enemy_summary.get("total", 0)),
		String(player_summary.get("detail", "")),
		String(enemy_summary.get("detail", "")),
	]
	if level != null and level.multiverse != null and level.multiverse.enabled:
		var per_timeline: String = level.multiverse.timeline_summary()
		if not per_timeline.is_empty():
			summary_label.text += "\nTimelines: %s" % per_timeline
	play_again_button.disabled = _last_launch_state.is_empty()
	_set_status("")
	_refresh_launch_state()


func _build_ui() -> void:
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	body_font_size = _font_step_for_width(_layout_width())
	title_font_size = TITLE_FONT_SIZE if body_font_size == FONT_SIZE else COMPACT_TITLE_FONT_SIZE
	theme = _make_lobby_theme()

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.02, 0.03, 0.08, 0.35)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := PmdBackdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "LayoutMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(LAYOUT_MARGIN_X))
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", int(LAYOUT_MARGIN_X))
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.name = "LobbyLayout"
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", int(MIDDLE_GAP))
	margin.add_child(outer)

	player_tray = _create_team_tray("PlayerTeamTray", "Player Team", SIDE_PLAYER)
	player_tray_title = player_tray.find_child("%sTitle" % SIDE_PLAYER.capitalize(), true, false) as Label
	outer.add_child(player_tray)

	var middle := HBoxContainer.new()
	middle.name = "MiddleLayout"
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", int(MIDDLE_GAP))
	outer.add_child(middle)

	var setup: PanelContainer = _create_setup_panel()
	setup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup.size_flags_stretch_ratio = 1.0
	middle.add_child(setup)
	var roster: PanelContainer = _create_roster_panel()
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.size_flags_stretch_ratio = 1.0
	middle.add_child(roster)

	enemy_tray = _create_team_tray("EnemyTeamTray", "Enemy Team", SIDE_ENEMY)
	enemy_tray_title = enemy_tray.find_child("%sTitle" % SIDE_ENEMY.capitalize(), true, false) as Label
	outer.add_child(enemy_tray)
	add_child(_create_chooser_panel())
	resized.connect(_queue_update_grid_columns)


func _create_team_tray(node_name: String, title: String, side: String) -> PanelContainer:
	var tray := PanelContainer.new()
	tray.name = node_name
	tray.custom_minimum_size = Vector2(0, TRAY_HEIGHT)
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	tray.gui_input.connect(_on_tray_gui_input.bind(side))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 6)
	tray.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)

	var label := Label.new()
	label.name = "%sTitle" % side.capitalize()
	label.text = title
	_apply_title_font(label)
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

	var slots := GridContainer.new()
	slots.name = "%sSlots" % side.capitalize()
	slots.columns = SLOT_COLUMNS
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("h_separation", 8)
	slots.add_theme_constant_override("v_separation", 6)
	column.add_child(slots)

	if side == SIDE_PLAYER:
		player_slots = slots
	else:
		enemy_slots = slots
	return tray


func _create_setup_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "SetupPanel"
	panel.custom_minimum_size = Vector2(SETUP_PANEL_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_box(PANEL_COLOR, MUTED_BORDER_COLOR, 1))
	setup_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.name = "SetupColumn"
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var tabs := HBoxContainer.new()
	tabs.name = "SetupTabs"
	tabs.add_theme_constant_override("separation", int(PmdStyle.PANEL_GAP))
	outer.add_child(tabs)
	var group := ButtonGroup.new()
	for page in PAGES:
		var tab := Button.new()
		tab.name = "%sTab" % page.capitalize()
		tab.text = _tab_label(page)
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size.y = PmdStyle.ROW_HEIGHT
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_show_setup_page.bind(page))
		tabs.add_child(tab)
		setup_tabs[page] = tab

	var setup_scroll := ScrollContainer.new()
	setup_scroll.name = "SetupScroll"
	setup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	setup_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(setup_scroll)

	setup_grid = GridContainer.new()
	setup_grid.name = "SetupGrid"
	setup_grid.columns = 1
	setup_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_scroll.add_child(_scroll_pad(setup_grid))

	var column := VBoxContainer.new()
	column.name = "MatchPage"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 8)
	setup_grid.add_child(column)
	match_page = column
	match_grid = GridContainer.new()
	match_grid.name = "MatchGrid"
	match_grid.columns = 2
	match_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_grid.add_theme_constant_override("h_separation", int(MIDDLE_GAP))
	match_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(match_grid)
	var left := VBoxContainer.new()
	left.name = "MatchLeft"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.add_theme_constant_override("separation", 8)
	match_grid.add_child(left)
	var right := VBoxContainer.new()
	right.name = "MatchRight"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_theme_constant_override("separation", 8)
	match_grid.add_child(right)
	setup_grid.add_child(_create_details_panel())

	var footer := VBoxContainer.new()
	footer.name = "SetupFooter"
	footer.add_theme_constant_override("separation", 6)
	outer.add_child(footer)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Back"
	close_button.custom_minimum_size.y = CONTROL_HEIGHT
	close_button.pressed.connect(_on_close_pressed)
	left.add_child(_section_header("Match"))


	map_picker = OptionButton.new()
	map_picker.name = "MapPicker"
	map_picker.fit_to_longest_item = false
	map_picker.item_selected.connect(_on_map_changed)
	left.add_child(_labeled_control("Map", map_picker))

	control_mode_picker = OptionButton.new()
	control_mode_picker.name = "ControlModePicker"
	control_mode_picker.fit_to_longest_item = false
	_add_control_mode_item("Player vs CPU", SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU)
	_add_control_mode_item("Player vs Player", SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER)
	_add_control_mode_item("CPU vs CPU", SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
	control_mode_picker.item_selected.connect(_on_control_mode_selected)
	left.add_child(_labeled_control("Control", control_mode_picker))

	multiverse_toggle = CheckButton.new()
	multiverse_toggle.name = "MultiverseToggle"
	multiverse_toggle.button_pressed = false
	multiverse_toggle.tooltip_text = "5D chess rules: Roar of Time, Spacial Rend and the other dimension moves open and cross timelines"
	multiverse_toggle.toggled.connect(func(_pressed: bool) -> void: _refresh_launch_state())
	left.add_child(_labeled_control("Multiversal Rules", multiverse_toggle))

	ai_level_spin = SpinBox.new()
	ai_level_spin.name = "AiLevelSpin"
	ai_level_spin.min_value = AIProfile.MIN_LEVEL
	ai_level_spin.max_value = AIProfile.MAX_LEVEL
	ai_level_spin.step = 1
	ai_level_spin.value = AIProfile.DEFAULT_LEVEL
	ai_level_spin.tooltip_text = "CPU skill: 1 Wandering, 2 Scrappy, 3 Tactical, 4 Ruthless, 5 Champion"
	ai_level_spin.value_changed.connect(func(_value: float) -> void: _refresh_launch_state())
	left.add_child(_labeled_control("Difficulty", ai_level_spin))

	reroll_seed_check = CheckButton.new()
	reroll_seed_check.name = "RerollSeedCheck"
	reroll_seed_check.text = "New seed each match"
	reroll_seed_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reroll_seed_check.custom_minimum_size.y = CONTROL_HEIGHT
	reroll_seed_check.tooltip_text = "Roll a fresh seed on every launch and on Play Again, so the seed box does not have to be cleared between matches"
	reroll_seed_check.toggled.connect(func(_pressed: bool) -> void: _refresh_launch_state())
	right.add_child(reroll_seed_check)

	difficulty_spin = SpinBox.new()
	difficulty_spin.name = "DifficultySpin"
	difficulty_spin.min_value = 0
	difficulty_spin.max_value = 4
	difficulty_spin.step = 1
	difficulty_spin.value = CustomSkirmishBuilder.DEFAULT_RANDOM_DIFFICULTY_TIER
	left.add_child(_labeled_control("CPU Quality", difficulty_spin))

	right.add_child(_section_header("Teams"))
	right.move_child(right.get_child(right.get_child_count() - 1), 0)
	random_player_check = CheckButton.new()
	random_player_check.name = "RandomPlayerCheck"
	random_player_check.text = "Random player team"
	random_player_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_player_check.custom_minimum_size.y = CONTROL_HEIGHT
	random_player_check.toggled.connect(_on_random_player_toggled)
	right.add_child(random_player_check)

	random_enemy_check = CheckButton.new()
	random_enemy_check.name = "RandomEnemyCheck"
	random_enemy_check.text = "Random enemy team"
	random_enemy_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_enemy_check.custom_minimum_size.y = CONTROL_HEIGHT
	random_enemy_check.toggled.connect(_on_random_enemy_toggled)
	right.add_child(random_enemy_check)

	player_size_slider = _team_size_slider("PlayerSizeSlider", 3)
	right.add_child(_labeled_control("Player team", _slider_row(player_size_slider, "PlayerSizeValue")))
	enemy_size_spin = _team_size_slider("EnemySizeSlider", 3)
	right.add_child(_labeled_control("Enemy team", _slider_row(enemy_size_spin, "EnemySizeValue")))

	net_status_label = Label.new()
	net_status_label.name = "NetStatus"
	net_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_status_label.visible = false
	_apply_body_font(net_status_label)
	column.add_child(net_status_label)
	copy_address_button = Button.new()
	copy_address_button.name = "CopyAddressButton"
	copy_address_button.text = "Copy public address"
	copy_address_button.custom_minimum_size.y = CONTROL_HEIGHT
	copy_address_button.visible = false
	copy_address_button.pressed.connect(_on_copy_address_pressed)
	column.add_child(copy_address_button)

	net_ready_check = CheckButton.new()
	net_ready_check.name = "NetReadyCheck"
	net_ready_check.text = "Ready"
	net_ready_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	net_ready_check.custom_minimum_size.y = CONTROL_HEIGHT
	net_ready_check.visible = false
	net_ready_check.toggled.connect(_on_net_ready_toggled)
	footer.add_child(net_ready_check)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", PmdStyle.FONT_CAPTION)
	status_label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	status_label.custom_minimum_size = Vector2(0, 0)
	status_label.visible = false
	footer.add_child(status_label)

	var actions := HBoxContainer.new()
	actions.name = "SetupActions"
	actions.add_theme_constant_override("separation", int(PmdStyle.PANEL_GAP))
	footer.add_child(actions)
	launch_button = Button.new()
	launch_button.name = "LaunchButton"
	launch_button.text = "Launch Skirmish"
	launch_button.custom_minimum_size.y = PmdStyle.CONTROL_HEIGHT
	launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch_button.size_flags_stretch_ratio = 2.0
	launch_button.pressed.connect(_on_launch_pressed)
	actions.add_child(launch_button)
	close_button.custom_minimum_size.y = PmdStyle.CONTROL_HEIGHT
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(close_button)

	column.add_child(_section_header("Seed"))
	code_output = LineEdit.new()
	code_output.name = "CodeOutput"
	code_output.editable = false
	code_output.selecting_enabled = true
	code_output.context_menu_enabled = true
	code_output.placeholder_text = "skirmish code appears after launch"
	code_output.tooltip_text = "Select all and copy, then paste into the seed box to replay this exact setup"
	code_output.custom_minimum_size.y = CONTROL_HEIGHT
	code_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var code_row := HBoxContainer.new()
	code_row.name = "CodeRow"
	code_row.add_theme_constant_override("separation", 8)
	code_row.add_child(code_output)
	copy_code_button = Button.new()
	copy_code_button.name = "CopyCodeButton"
	copy_code_button.text = "Copy"
	copy_code_button.custom_minimum_size = Vector2(110, CONTROL_HEIGHT)
	copy_code_button.disabled = true
	copy_code_button.tooltip_text = "Copy the skirmish code to the clipboard"
	copy_code_button.pressed.connect(_on_copy_code_pressed)
	code_row.add_child(copy_code_button)
	column.add_child(code_row)
	seed_input = LineEdit.new()
	seed_input.name = "SeedInput"
	seed_input.placeholder_text = "seed or skirmish code"
	seed_input.text_changed.connect(_on_seed_changed)
	column.add_child(_labeled_control("Seed", seed_input))

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
	type_filter.fit_to_longest_item = false
	type_filter.custom_minimum_size = Vector2(TYPE_FILTER_WIDTH, CONTROL_HEIGHT)
	type_filter.item_selected.connect(_on_filter_changed)
	toolbar.add_child(type_filter)

	sort_picker = OptionButton.new()
	sort_picker.name = "SortPicker"
	sort_picker.fit_to_longest_item = false
	sort_picker.custom_minimum_size = Vector2(SORT_PICKER_WIDTH, CONTROL_HEIGHT)
	sort_picker.item_selected.connect(_on_filter_changed)
	toolbar.add_child(sort_picker)

	roster_scroll = ScrollContainer.new()
	roster_scroll.name = "RosterScroll"
	roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_scroll.resized.connect(_queue_update_grid_columns)
	column.add_child(roster_scroll)

	roster_grid = GridContainer.new()
	roster_grid.name = "RosterGrid"
	roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_grid.add_theme_constant_override("h_separation", int(GRID_GAP))
	roster_grid.add_theme_constant_override("v_separation", int(GRID_GAP))
	roster_scroll.add_child(roster_grid)
	return panel


func _create_details_panel() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "DetailsPanel"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 8)
	details_panel = column

	target_label = Label.new()
	target_label.name = "TargetLabel"
	_apply_title_font(target_label)
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_label.visible = false
	column.add_child(target_label)
	column.add_child(_create_selected_box())

	details_label = Label.new()
	details_label.name = "DetailsLabel"
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(details_label)

	slot_title_label = Label.new()
	slot_title_label.name = "SlotTitleLabel"
	slot_title_label.text = "Pokemon setup"
	_apply_body_font(slot_title_label)
	slot_title_label.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD)
	slot_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(slot_title_label)

	editor_grid = GridContainer.new()
	editor_grid.name = "EditorGrid"
	editor_grid.columns = 2
	editor_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_grid.add_theme_constant_override("h_separation", int(MIDDLE_GAP))
	editor_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(editor_grid)
	var edit_left := VBoxContainer.new()
	edit_left.name = "EditorLeft"
	edit_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	edit_left.add_theme_constant_override("separation", 8)
	editor_grid.add_child(edit_left)
	var edit_right := VBoxContainer.new()
	edit_right.name = "EditorRight"
	edit_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	edit_right.add_theme_constant_override("separation", 8)
	editor_grid.add_child(edit_right)

	edit_left.add_child(_section_header("Form"))
	var form_row := HBoxContainer.new()
	form_row.add_theme_constant_override("separation", 6)
	edit_left.add_child(form_row)
	random_form_check = CheckButton.new()
	random_form_check.name = "RandomFormCheck"
	random_form_check.text = "Random"
	random_form_check.button_pressed = true
	random_form_check.toggled.connect(_on_random_form_toggled)
	form_row.add_child(random_form_check)
	form_picker = OptionButton.new()
	form_picker.name = "FormPicker"
	form_picker.custom_minimum_size.y = CONTROL_HEIGHT
	form_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_picker.fit_to_longest_item = false
	form_picker.clip_text = true
	form_picker.item_selected.connect(_on_form_picked)
	form_row.add_child(form_picker)
	form_value_label = _section_value("FormValueLabel")
	edit_left.add_child(form_value_label)

	edit_left.add_child(_section_header("Gender"))
	var gender_row := HBoxContainer.new()
	gender_row.add_theme_constant_override("separation", 6)
	edit_left.add_child(gender_row)
	random_gender_check = CheckButton.new()
	random_gender_check.name = "RandomGenderCheck"
	random_gender_check.text = "Random"
	random_gender_check.button_pressed = true
	random_gender_check.toggled.connect(_on_random_gender_toggled)
	gender_row.add_child(random_gender_check)
	gender_picker = OptionButton.new()
	gender_picker.name = "GenderPicker"
	gender_picker.custom_minimum_size.y = CONTROL_HEIGHT
	gender_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gender_picker.fit_to_longest_item = false
	gender_picker.add_item("%s %s" % [GenderRules.label(GenderRules.MALE), GenderRules.glyph(GenderRules.MALE)])
	gender_picker.add_item("%s %s" % [GenderRules.label(GenderRules.FEMALE), GenderRules.glyph(GenderRules.FEMALE)])
	gender_picker.item_selected.connect(_on_gender_picked)
	gender_row.add_child(gender_picker)
	gender_value_label = _section_value("GenderValueLabel")
	edit_left.add_child(gender_value_label)

	edit_right.add_child(_section_header("Moves"))
	var moves_row := HBoxContainer.new()
	moves_row.add_theme_constant_override("separation", 6)
	edit_right.add_child(moves_row)
	random_moves_check = CheckButton.new()
	random_moves_check.name = "RandomMovesCheck"
	random_moves_check.text = "Random"
	random_moves_check.button_pressed = true
	random_moves_check.toggled.connect(_on_random_moves_toggled)
	moves_row.add_child(random_moves_check)
	choose_moves_button = Button.new()
	choose_moves_button.name = "ChooseMovesButton"
	choose_moves_button.text = "Choose Moves"
	choose_moves_button.custom_minimum_size.y = CONTROL_HEIGHT
	choose_moves_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choose_moves_button.pressed.connect(_open_chooser.bind(CHOOSER_MOVES))
	moves_row.add_child(choose_moves_button)
	moves_value_label = _section_value("MovesValueLabel")
	edit_right.add_child(moves_value_label)

	edit_right.add_child(_section_header("Ability"))
	var ability_row := HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 6)
	edit_right.add_child(ability_row)
	random_ability_check = CheckButton.new()
	random_ability_check.name = "RandomAbilityCheck"
	random_ability_check.text = "Random"
	random_ability_check.button_pressed = true
	random_ability_check.toggled.connect(_on_random_ability_toggled)
	ability_row.add_child(random_ability_check)
	choose_ability_button = Button.new()
	choose_ability_button.name = "ChooseAbilityButton"
	choose_ability_button.text = "Choose Ability"
	choose_ability_button.custom_minimum_size.y = CONTROL_HEIGHT
	choose_ability_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choose_ability_button.pressed.connect(_open_chooser.bind(CHOOSER_ABILITY))
	ability_row.add_child(choose_ability_button)
	ability_value_label = _section_value("AbilityValueLabel")
	edit_right.add_child(ability_value_label)

	edit_right.add_child(_section_header("Held item"))
	var held_row := HBoxContainer.new()
	held_row.add_theme_constant_override("separation", 6)
	edit_right.add_child(held_row)
	random_item_check = CheckButton.new()
	random_item_check.name = "RandomItemCheck"
	random_item_check.text = "Random"
	random_item_check.toggled.connect(_on_random_item_toggled)
	held_row.add_child(random_item_check)
	choose_item_button = Button.new()
	choose_item_button.name = "ChooseItemButton"
	choose_item_button.text = "Choose Item"
	choose_item_button.custom_minimum_size.y = CONTROL_HEIGHT
	choose_item_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choose_item_button.pressed.connect(_open_chooser.bind(CHOOSER_ITEM))
	held_row.add_child(choose_item_button)
	clear_item_button = Button.new()
	clear_item_button.name = "ClearItemButton"
	clear_item_button.text = "None"
	clear_item_button.custom_minimum_size = Vector2(52, CONTROL_HEIGHT)
	clear_item_button.pressed.connect(_on_clear_item_pressed)
	held_row.add_child(clear_item_button)
	item_value_label = _section_value("ItemValueLabel")
	edit_right.add_child(item_value_label)
	return column


func _create_selected_box() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.name = "SelectedBox"
	box.add_theme_constant_override("separation", 10)
	selected_portrait_frame = PanelContainer.new()
	selected_portrait_frame.name = "SelectedPortraitFrame"
	selected_portrait_frame.custom_minimum_size = Vector2(SELECTED_PORTRAIT_PX + 8.0, SELECTED_PORTRAIT_PX + 8.0)
	selected_portrait_frame.add_theme_stylebox_override("panel", PmdStyle.portrait_frame(PmdStyle.FRAME_SOFT, 2))
	box.add_child(selected_portrait_frame)
	selected_portrait = TextureRect.new()
	selected_portrait.name = "SelectedPortrait"
	selected_portrait.custom_minimum_size = Vector2(SELECTED_PORTRAIT_PX, SELECTED_PORTRAIT_PX)
	selected_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	selected_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	selected_portrait_frame.add_child(selected_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	box.add_child(column)
	selected_name_label = Label.new()
	selected_name_label.name = "SelectedName"
	selected_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_body_font(selected_name_label)
	column.add_child(selected_name_label)
	selected_types_label = Label.new()
	selected_types_label.name = "SelectedTypes"
	selected_types_label.add_theme_font_size_override("font_size", PmdStyle.FONT_CAPTION)
	selected_types_label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	column.add_child(selected_types_label)
	box.visible = false
	return box


func _show_selected(path: String, expression: String = "Happy") -> void:
	selected_path = path
	var box: Control = selected_portrait_frame.get_parent() as Control
	if path.is_empty():
		box.visible = false
		return
	var entry: Dictionary = _entry_for_path(path)
	var slug: String = String(entry.get("slug", PortraitLibrary.slug_for_path(path)))
	box.visible = true
	selected_name_label.text = String(entry.get("label", slug.capitalize()))
	var types: Array = entry.get("types", [])
	var names: Array[String] = []
	for type_id in types:
		names.append(String(type_id).capitalize())
	selected_types_label.text = " / ".join(names)
	_set_selected_expression(slug, expression)
	if expression != PortraitLibrary.NORMAL:
		_flash_serial += 1
		var serial: int = _flash_serial
		get_tree().create_timer(PORTRAIT_FLASH_SECONDS * 1.4).timeout.connect(func() -> void:
			if serial == _flash_serial and is_instance_valid(selected_portrait) and selected_path == path:
				_set_selected_expression(slug, PortraitLibrary.NORMAL))


func _set_selected_expression(slug: String, expression: String) -> void:
	selected_expression = expression
	selected_portrait.texture = PortraitLibrary.texture_for(slug, expression)


func _flash_portrait(texture_rect: TextureRect, slug: String, expression: String = "Happy") -> void:
	if texture_rect == null or not is_instance_valid(texture_rect):
		return
	var happy: Texture2D = PortraitLibrary.texture_for(slug, expression)
	var normal: Texture2D = texture_rect.texture
	if happy == null or happy == normal:
		return
	texture_rect.texture = happy
	get_tree().create_timer(PORTRAIT_FLASH_SECONDS).timeout.connect(func() -> void:
		if is_instance_valid(texture_rect) and texture_rect.texture == happy:
			texture_rect.texture = normal)


func _tab_label(page: String) -> String:
	if page == PAGE_MATCH:
		return "Match"
	var side: String = SIDE_PLAYER if page == "player" else SIDE_ENEMY
	if network_mode() and net_session.state != NetSession.HOSTING and net_session.state != NetSession.CONNECTING:
		var mine: bool = side == local_side_key()
		var who: String = (net_session.local_name if not net_session.local_name.is_empty() else "You") if mine else (net_session.remote_name if not net_session.remote_name.is_empty() else "Opponent")
		return "%s (you)" % who if mine else "%s  %s" % [who, remote_activity_label()]
	return "Player Team" if side == SIDE_PLAYER else "Enemy Team"


func _refresh_tab_labels() -> void:
	for page in setup_tabs.keys():
		(setup_tabs[page] as Button).text = _tab_label(String(page))


func _show_setup_page(page: String) -> void:
	if not PAGES.has(page):
		page = PAGE_MATCH
	setup_page = page
	if match_page != null:
		match_page.visible = page == PAGE_MATCH
	if details_panel != null:
		details_panel.visible = page != PAGE_MATCH
	for key in setup_tabs.keys():
		(setup_tabs[key] as Button).set_pressed_no_signal(String(key) == page)
	if page != PAGE_MATCH:
		var side: String = SIDE_PLAYER if page == "player" else SIDE_ENEMY
		if active_side != side:
			_set_active_side(side)
			_refresh_team_trays()
		_refresh_details()
		_refresh_slot_section()


func _page_for_side(side: String) -> String:
	return "player" if side == SIDE_PLAYER else "enemy"


func _step_setup_page(direction: int) -> void:
	var index: int = PAGES.find(setup_page)
	_show_setup_page(PAGES[posmod(index + direction, PAGES.size())])
	SoundPlayer.cue("ui.cursor")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _built or (map_preview != null and map_preview.visible) or (summary_panel != null and summary_panel.visible):
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner is LineEdit or owner is SpinBox:
		return
	if event.is_action_pressed("camera_rotate_left"):
		_step_setup_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_rotate_right"):
		_step_setup_page(1)
		get_viewport().set_input_as_handled()


func _scroll_pad(content: Control) -> MarginContainer:
	var pad := MarginContainer.new()
	pad.name = "ScrollPad"
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 2)
	pad.add_theme_constant_override("margin_right", SCROLL_PAD_RIGHT)
	pad.add_theme_constant_override("margin_top", 2)
	pad.add_theme_constant_override("margin_bottom", 2)
	pad.add_child(content)
	_scroll_pads.append(pad)
	return pad


func _section_header(text: String) -> Control:
	var block := VBoxContainer.new()
	block.name = "%sHeader" % text.replace(" ", "")
	block.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = text
	_apply_body_font(label)
	label.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD)
	block.add_child(label)
	var rule: ColorRect = PmdStyle.rule(0.6)
	rule.custom_minimum_size.y = 2
	block.add_child(rule)
	return block


func _section_value(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	_apply_body_font(label)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _create_chooser_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ChooserPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _style_box(Color(0.09, 0.1, 0.1, 0.94), MUTED_BORDER_COLOR, 0))
	chooser_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)

	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", _style_box(PANEL_COLOR, BORDER_COLOR, 2))
	margin.add_child(inner)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 14)
	inner_margin.add_theme_constant_override("margin_top", 12)
	inner_margin.add_theme_constant_override("margin_right", 14)
	inner_margin.add_theme_constant_override("margin_bottom", 12)
	inner.add_child(inner_margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	inner_margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	chooser_title = Label.new()
	chooser_title.name = "ChooserTitle"
	_apply_title_font(chooser_title)
	chooser_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(chooser_title)

	chooser_counter = Label.new()
	chooser_counter.name = "ChooserCounter"
	header.add_child(chooser_counter)

	chooser_search = LineEdit.new()
	chooser_search.name = "ChooserSearch"
	chooser_search.placeholder_text = "Search"
	chooser_search.custom_minimum_size = Vector2(240, CONTROL_HEIGHT)
	chooser_search.text_changed.connect(_on_chooser_search_changed)
	header.add_child(chooser_search)

	chooser_done_button = Button.new()
	chooser_done_button.name = "ChooserDoneButton"
	chooser_done_button.text = "Done"
	chooser_done_button.custom_minimum_size.y = CONTROL_HEIGHT
	chooser_done_button.pressed.connect(_close_chooser)
	header.add_child(chooser_done_button)

	chooser_scroll = ScrollContainer.new()
	chooser_scroll.name = "ChooserScroll"
	chooser_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chooser_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chooser_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chooser_scroll.resized.connect(_update_chooser_columns)
	column.add_child(chooser_scroll)

	chooser_grid = GridContainer.new()
	chooser_grid.name = "ChooserGrid"
	chooser_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chooser_grid.add_theme_constant_override("h_separation", 10)
	chooser_grid.add_theme_constant_override("v_separation", 8)
	chooser_grid.columns = 3
	chooser_scroll.add_child(chooser_grid)
	return panel


func _labeled_control(label_text: String, control: Control) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 92
	_apply_body_font(label)
	box.add_child(label)
	control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, CONTROL_HEIGHT)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(control)
	return box


func _add_control_mode_item(label: String, mode: String) -> void:
	control_mode_picker.add_item(label)
	control_mode_picker.set_item_metadata(control_mode_picker.item_count - 1, mode)


func _load_data() -> void:
	roster_entries = RosterProvider.entries()
	map_paths = CustomSkirmishBuilder.map_paths()
	item_choices = BattleItemCatalog.labels_for_picker()

	map_picker.clear()
	for path in map_paths:
		var map: MapDefinitionResource = load(path) as MapDefinitionResource
		var label: String = map.display_name if map != null and not map.display_name.is_empty() else path.get_file().get_basename().capitalize()
		map_picker.add_item(label)
	map_picker.add_item(MAP_PREVIEW_LABEL)
	var default_index: int = map_paths.find(SkirmishCode.DEFAULT_MAP_PATH)
	if default_index >= 0:
		map_picker.select(default_index)
	_map_index = maxi(0, map_picker.selected)
	_apply_map_team_cap()

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
	_refresh_slot_section()
	_refresh_launch_state()


func _specs_for_side(side: String) -> Array[Dictionary]:
	return player_slot_specs if side == SIDE_PLAYER else enemy_slot_specs


func _default_spec() -> Dictionary:
	return {"moves": [], "random_moves": true, "ability": "", "random_ability": true, "item": "", "random_item": false, "gender": "", "random_gender": true, "form": "", "random_form": true}


func _spec_for(side: String, index: int) -> Dictionary:
	var specs: Array[Dictionary] = _specs_for_side(side)
	return specs[index] if index >= 0 and index < specs.size() else _default_spec()


func _items_for_side(side: String) -> Array[String]:
	var out: Array[String] = []
	_sync_specs(side)
	for spec in _specs_for_side(side):
		if bool(spec.get("random_item", false)):
			out.append(CustomSkirmishBuilder.RANDOM_CHOICE)
		else:
			out.append(String(spec.get("item", "")))
	return out


func _specs_payload(side: String) -> Array:
	var out: Array = []
	_sync_specs(side)
	for spec in _specs_for_side(side):
		var moves: Array = [] if bool(spec.get("random_moves", true)) else (spec.get("moves", []) as Array).duplicate()
		var ability: String = CustomSkirmishBuilder.RANDOM_CHOICE if bool(spec.get("random_ability", true)) else String(spec.get("ability", ""))
		var gender: String = CustomSkirmishBuilder.RANDOM_CHOICE if bool(spec.get("random_gender", true)) else String(spec.get("gender", ""))
		var form: String = CustomSkirmishBuilder.RANDOM_CHOICE if bool(spec.get("random_form", true)) else String(spec.get("form", ""))
		out.append({"moves": moves, "ability": ability, "gender": gender, "form": form})
	return out


func _item_id_for(side: String, index: int) -> String:
	var spec: Dictionary = _spec_for(side, index)
	if bool(spec.get("random_item", false)):
		return CustomSkirmishBuilder.RANDOM_CHOICE
	return String(spec.get("item", ""))


func _sync_specs(side: String) -> void:
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	var specs: Array[Dictionary] = _specs_for_side(side)
	while specs.size() < team.size():
		specs.append(_default_spec())
	while specs.size() > team.size():
		specs.remove_at(specs.size() - 1)


func _sync_item_slots(side: String) -> void:
	_sync_specs(side)


func _refresh_slot_section() -> void:
	if slot_title_label == null:
		return
	var team: Array[String] = player_team_paths if active_side == SIDE_PLAYER else enemy_team_paths
	var index: int = _selected_index_for(active_side)
	var has_slot: bool = index >= 0 and index < team.size()
	var editable: bool = has_slot and (not network_mode() or active_side == local_side_key())
	for control in [random_moves_check, choose_moves_button, random_ability_check, choose_ability_button, random_item_check, choose_item_button, clear_item_button, random_gender_check, gender_picker, random_form_check, form_picker]:
		control.disabled = not editable
	if not has_slot:
		slot_title_label.text = "Select a %s slot" % _side_label(active_side).to_lower()
		moves_value_label.text = ""
		ability_value_label.text = ""
		item_value_label.text = ""
		gender_value_label.text = ""
		form_value_label.text = ""
		form_picker.clear()
		return
	_sync_specs(active_side)
	var spec: Dictionary = _spec_for(active_side, index)
	var entry: Dictionary = _entry_for_path(team[index])
	var species: PokemonSpeciesResource = _species_for_entry(entry)
	var form_options: Array[int] = FormRules.options(species)
	var form_choice: bool = form_options.size() > 1
	var random_form: bool = bool(spec.get("random_form", true)) or not form_choice
	var chosen_form: int = int(String(spec.get("form", ""))) if String(spec.get("form", "")).is_valid_int() else -1
	if not form_options.has(chosen_form):
		chosen_form = form_options[0]
	random_form_check.disabled = not form_choice
	random_form_check.set_pressed_no_signal(random_form)
	form_picker.disabled = random_form
	form_picker.clear()
	if form_choice:
		for j in range(form_options.size()):
			form_picker.add_item(FormRules.label(species, form_options[j]), form_options[j])
			if form_options[j] == chosen_form:
				form_picker.select(j)
		form_value_label.text = ("Rolled from %d forms" % form_options.size()) if random_form else FormRules.label(species, chosen_form)
	else:
		form_value_label.text = "Single form"
	var slot_name: String = FormRules.label(species, chosen_form) if form_choice and not random_form and chosen_form != FormRules.default_index(species) else String(entry.get("label", ""))
	slot_title_label.text = "%s slot %d: %s" % [_side_label(active_side), index + 1, slot_name]
	var form: PokemonFormResource = species.forms[chosen_form] if species != null and not random_form and chosen_form >= 0 and chosen_form < species.forms.size() else _form_for_entry(entry)
	var gender_choice: bool = GenderRules.is_choice(form)
	var random_gender: bool = bool(spec.get("random_gender", true)) or not gender_choice
	var chosen_gender: int = GenderRules.parse_id(String(spec.get("gender", "")))
	random_gender_check.disabled = not gender_choice
	random_gender_check.set_pressed_no_signal(random_gender)
	gender_picker.disabled = random_gender
	if gender_choice:
		gender_picker.select(1 if chosen_gender == GenderRules.FEMALE else 0)
		gender_value_label.text = ("Rolled from the species ratio (%s)" % GenderRules.ratio_label(form)) if random_gender else (GenderRules.label(chosen_gender) + GenderRules.suffix(chosen_gender))
		if not random_gender and chosen_gender != GenderRules.UNKNOWN:
			slot_title_label.text += GenderRules.suffix(chosen_gender)
	else:
		gender_picker.select(-1)
		gender_value_label.text = GenderRules.ratio_label(form)
	random_moves_check.set_pressed_no_signal(bool(spec.get("random_moves", true)))
	choose_moves_button.disabled = bool(spec.get("random_moves", true))
	var move_labels: Array[String] = []
	for move_id in spec.get("moves", []):
		move_labels.append(_move_label(String(move_id)))
	moves_value_label.text = "Seeded from the level-up pool" if bool(spec.get("random_moves", true)) else ("" + (", ".join(move_labels) if not move_labels.is_empty() else "(choose at least one)"))
	random_ability_check.set_pressed_no_signal(bool(spec.get("random_ability", true)))
	choose_ability_button.disabled = bool(spec.get("random_ability", true))
	ability_value_label.text = "Seeded from %s" % ", ".join(_ability_labels(team[index])) if bool(spec.get("random_ability", true)) else "%s" % (_ability_label(String(spec.get("ability", ""))) if not String(spec.get("ability", "")).is_empty() else "(choose one)")
	random_item_check.set_pressed_no_signal(bool(spec.get("random_item", false)))
	choose_item_button.disabled = bool(spec.get("random_item", false))
	clear_item_button.disabled = bool(spec.get("random_item", false)) or String(spec.get("item", "")).is_empty()
	var item_id: String = String(spec.get("item", ""))
	if bool(spec.get("random_item", false)):
		item_value_label.text = "Seeded from %d applicable items" % item_choices.size()
	elif item_id.is_empty():
		item_value_label.text = "None"
	else:
		item_value_label.text = "%s" % String(BattleItemCatalog.entry_for(item_id).get("label", item_id))


func _on_random_moves_toggled(enabled: bool) -> void:
	var index: int = _selected_index_for(active_side)
	if index < 0:
		return
	_sync_specs(active_side)
	var spec: Dictionary = _spec_for(active_side, index)
	spec["random_moves"] = enabled
	_refresh_details()
	_refresh_slot_section()
	if not enabled and (spec.get("moves", []) as Array).is_empty():
		_open_chooser(CHOOSER_MOVES)


func _on_random_form_toggled(enabled: bool) -> void:
	var index: int = _selected_index_for(active_side)
	if index < 0:
		return
	_sync_specs(active_side)
	var spec: Dictionary = _spec_for(active_side, index)
	spec["random_form"] = enabled
	if not enabled and not String(spec.get("form", "")).is_valid_int():
		var team: Array[String] = player_team_paths if active_side == SIDE_PLAYER else enemy_team_paths
		spec["form"] = str(FormRules.default_index(_species_for_entry(_entry_for_path(team[index]))))
	_refresh_details()
	_refresh_slot_section()


func _on_form_picked(item_index: int) -> void:
	if form_picker == null or item_index < 0 or item_index >= form_picker.item_count:
		return
	set_slot_form(active_side, _selected_index_for(active_side), str(form_picker.get_item_id(item_index)))


func _species_for_entry(entry: Dictionary) -> PokemonSpeciesResource:
	var instance: PokemonInstanceResource = entry.get("instance", null) as PokemonInstanceResource
	return instance.species if instance != null else null


func _on_random_gender_toggled(enabled: bool) -> void:
	var index: int = _selected_index_for(active_side)
	if index < 0:
		return
	_sync_specs(active_side)
	var spec: Dictionary = _spec_for(active_side, index)
	spec["random_gender"] = enabled
	if not enabled and GenderRules.parse_id(String(spec.get("gender", ""))) == GenderRules.UNKNOWN:
		spec["gender"] = GenderRules.id(GenderRules.MALE)
	_refresh_details()
	_refresh_slot_section()


func _on_gender_picked(item_index: int) -> void:
	set_slot_gender(active_side, _selected_index_for(active_side), GenderRules.id(GenderRules.FEMALE if item_index == 1 else GenderRules.MALE))


func _form_for_entry(entry: Dictionary) -> PokemonFormResource:
	var instance: PokemonInstanceResource = entry.get("instance", null) as PokemonInstanceResource
	return instance.resolved_form() if instance != null else null


func _on_random_ability_toggled(enabled: bool) -> void:
	var index: int = _selected_index_for(active_side)
	if index < 0:
		return
	_sync_specs(active_side)
	var spec: Dictionary = _spec_for(active_side, index)
	spec["random_ability"] = enabled
	_refresh_details()
	_refresh_slot_section()
	if not enabled and String(spec.get("ability", "")).is_empty():
		_open_chooser(CHOOSER_ABILITY)


func _on_random_item_toggled(enabled: bool) -> void:
	var index: int = _selected_index_for(active_side)
	if index < 0:
		return
	_sync_specs(active_side)
	var spec: Dictionary = _spec_for(active_side, index)
	spec["random_item"] = enabled
	if enabled:
		spec["item"] = ""
	_refresh_team_trays()
	_refresh_details()
	_refresh_slot_section()


func _on_clear_item_pressed() -> void:
	set_held_item(active_side, _selected_index_for(active_side), "")


func _move_label(move_id: String) -> String:
	var move: PokemonMoveResource = load("res://data/models/pokemon/generated/moves/%s.tres" % move_id) as PokemonMoveResource if ResourceLoader.exists("res://data/models/pokemon/generated/moves/%s.tres" % move_id) else null
	return move.display_name() if move != null else move_id.capitalize()


func _ability_label(ability_id: String) -> String:
	var path: String = "res://data/models/pokemon/generated/intrinsics/%s.tres" % ability_id
	var intrinsic: PokemonIntrinsicResource = load(path) as PokemonIntrinsicResource if ResourceLoader.exists(path) else null
	return intrinsic.label() if intrinsic != null else ability_id.capitalize()


func _ability_labels(path: String) -> Array[String]:
	var out: Array[String] = []
	var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
	for ability_id in CustomSkirmishBuilder.available_ability_ids(instance):
		out.append(_ability_label(ability_id))
	return out


func _open_chooser(mode: String) -> void:
	var index: int = _selected_index_for(active_side)
	var team: Array[String] = player_team_paths if active_side == SIDE_PLAYER else enemy_team_paths
	if index < 0 or index >= team.size() or chooser_panel == null:
		_set_status("Pick a team slot first")
		return
	_sync_specs(active_side)
	chooser_mode = mode
	chooser_side = active_side
	chooser_slot = index
	var spec: Dictionary = _spec_for(active_side, index)
	chooser_selection = []
	match mode:
		CHOOSER_MOVES:
			for move_id in spec.get("moves", []):
				chooser_selection.append(String(move_id))
		CHOOSER_ABILITY:
			if not String(spec.get("ability", "")).is_empty():
				chooser_selection.append(String(spec.get("ability", "")))
		_:
			if not String(spec.get("item", "")).is_empty():
				chooser_selection.append(String(spec.get("item", "")))
	var entry: Dictionary = _entry_for_path(team[index])
	var subject: String = "%s slot %d (%s)" % [_side_label(active_side), index + 1, String(entry.get("label", ""))]
	match mode:
		CHOOSER_MOVES:
			chooser_title.text = "Choose up to %d moves for %s" % [PokemonInstanceResource.MAX_MOVE_SLOTS, subject]
		CHOOSER_ABILITY:
			chooser_title.text = "Choose the ability for %s" % subject
		_:
			chooser_title.text = "Choose the held item for %s" % subject
	chooser_search.text = ""
	chooser_panel.visible = true
	_refresh_chooser()
	chooser_search.grab_focus()


func _close_chooser() -> void:
	if chooser_panel != null:
		chooser_panel.visible = false
	if chooser_mode == CHOOSER_MOVES and chooser_slot >= 0:
		set_slot_moves(chooser_side, chooser_slot, chooser_selection)
		if not chooser_selection.is_empty():
			SoundPlayer.cue("lobby.skill")
	chooser_mode = ""
	_refresh_slot_section()
	_refresh_launch_state()


func chooser_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var team: Array[String] = player_team_paths if chooser_side == SIDE_PLAYER else enemy_team_paths
	if chooser_slot < 0 or chooser_slot >= team.size():
		return out
	var path: String = team[chooser_slot]
	match chooser_mode:
		CHOOSER_MOVES:
			var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
			for move in SkirmishMoveLoadout.move_pool_for_instance(instance):
				out.append({"id": move.move_id, "label": move.display_name(), "detail": "%s %s  Pow %d" % [move.type.capitalize(), _category_label(move), move.base_power], "icon_path": "", "type": move.type, "category": move.category, "description": BattleText.move_summary(move)})
		CHOOSER_ABILITY:
			var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
			for ability_id in CustomSkirmishBuilder.available_ability_ids(instance):
				out.append({"id": ability_id, "label": _ability_label(ability_id), "detail": "", "icon_path": "", "description": BattleText.ability_description(ability_id)})
		_:
			for entry in BattleItemCatalog.entries():
				out.append({"id": String(entry["item_id"]), "label": String(entry["label"]), "detail": String(entry["category"]).capitalize(), "icon_path": String(entry.get("icon_path", "")), "description": BattleText.item_description(String(entry["item_id"]))})
	return out


func _refresh_chooser() -> void:
	if chooser_grid == null:
		return
	for child in chooser_grid.get_children():
		chooser_grid.remove_child(child)
		child.queue_free()
	var query: String = chooser_search.text.strip_edges().to_lower()
	if chooser_mode == CHOOSER_ITEM:
		chooser_grid.add_child(_create_chooser_row({"id": "", "label": "None", "detail": "No held item", "icon_path": ""}))
	for entry in chooser_entries():
		var label: String = String(entry.get("label", ""))
		var id: String = String(entry.get("id", ""))
		if not query.is_empty() and not label.to_lower().contains(query) and not id.contains(query) and not String(entry.get("detail", "")).to_lower().contains(query):
			continue
		chooser_grid.add_child(_create_chooser_row(entry))
	_update_chooser_counter()
	_update_chooser_columns()


func _create_chooser_row(entry: Dictionary) -> Button:
	var id: String = String(entry.get("id", ""))
	var button := Button.new()
	button.name = "Choice_%s" % (id if not id.is_empty() else "none")
	button.custom_minimum_size = CHOOSER_ROW_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.toggle_mode = chooser_mode == CHOOSER_MOVES
	button.button_pressed = chooser_selection.has(id) if not id.is_empty() else chooser_selection.is_empty()
	button.add_to_group(UiSoundHook.OPT_OUT_GROUP)
	button.pressed.connect(_on_chooser_row_pressed.bind(id))
	var description: String = String(entry.get("description", ""))
	button.tooltip_text = String(entry.get("label", "")) + ("\n" + description if not description.is_empty() else "")

	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6
	content.offset_top = 4
	content.offset_right = -6
	content.offset_bottom = -4
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var icon_path: String = String(entry.get("icon_path", ""))
	var text_left: float = 0.0
	var type_id: String = String(entry.get("type", ""))
	if icon_path.is_empty() and not type_id.is_empty():
		content.add_child(_type_badge(type_id, int(entry.get("category", PokemonMoveResource.CATEGORY_STATUS))))
		text_left = CHOOSER_ICON_SIZE.x + 8.0
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path) as Texture2D
		icon.anchor_top = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = 0
		icon.offset_top = -CHOOSER_ICON_SIZE.y * 0.5
		icon.offset_right = CHOOSER_ICON_SIZE.x
		icon.offset_bottom = CHOOSER_ICON_SIZE.y * 0.5
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		text_left = CHOOSER_ICON_SIZE.x + 8.0

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = text_left
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var detail: String = String(entry.get("detail", ""))
	label.text = String(entry.get("label", "")) + ("\n" + detail if not detail.is_empty() else "")
	content.add_child(label)
	return button


func _type_badge(type_id: String, category: int) -> Control:
	var badge := PanelContainer.new()
	badge.name = "TypeBadge"
	badge.anchor_top = 0.5
	badge.anchor_bottom = 0.5
	badge.offset_left = 0
	badge.offset_top = -CHOOSER_ICON_SIZE.y * 0.5
	badge.offset_right = CHOOSER_ICON_SIZE.x
	badge.offset_bottom = CHOOSER_ICON_SIZE.y * 0.5
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", PmdStyle.window_flat(PmdStyle.type_color(type_id), PmdStyle.FRAME, 2, 8))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	badge.add_child(column)
	var type_label := Label.new()
	type_label.text = PmdStyle.type_abbreviation(type_id)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", PmdStyle.FONT_MICRO)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(type_label)
	var category_label := Label.new()
	match category:
		PokemonMoveResource.CATEGORY_PHYSICAL:
			category_label.text = "PHY"
		PokemonMoveResource.CATEGORY_SPECIAL:
			category_label.text = "SPE"
		_:
			category_label.text = "STA"
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category_label.add_theme_font_size_override("font_size", PmdStyle.FONT_MICRO)
	category_label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(category_label)
	return badge


func _on_chooser_row_pressed(id: String) -> void:
	match chooser_mode:
		CHOOSER_MOVES:
			if chooser_selection.has(id):
				chooser_selection.erase(id)
				SoundPlayer.cue("ui.toggle")
			elif chooser_selection.size() < PokemonInstanceResource.MAX_MOVE_SLOTS:
				chooser_selection.append(id)
				SoundPlayer.cue("ui.toggle")
			else:
				SoundPlayer.cue("ui.error")
				_set_status("Up to %d moves; deselect one first" % PokemonInstanceResource.MAX_MOVE_SLOTS)
			_refresh_chooser()
		CHOOSER_ABILITY:
			set_slot_ability(chooser_side, chooser_slot, id)
			SoundPlayer.cue("ui.confirm")
			chooser_mode = ""
			chooser_panel.visible = false
			_refresh_launch_state()
		_:
			set_held_item(chooser_side, chooser_slot, id)
			SoundPlayer.cue("lobby.item" if not id.is_empty() else "ui.confirm")
			chooser_mode = ""
			chooser_panel.visible = false
			_refresh_launch_state()


func _update_chooser_counter() -> void:
	if chooser_counter == null:
		return
	chooser_counter.text = "%d/%d chosen" % [chooser_selection.size(), PokemonInstanceResource.MAX_MOVE_SLOTS] if chooser_mode == CHOOSER_MOVES else ""


func _update_chooser_columns() -> void:
	if chooser_grid == null or chooser_scroll == null:
		return
	var width: float = chooser_scroll.size.x if chooser_scroll.size.x > 1.0 else _layout_width() - 160.0
	chooser_grid.columns = clampi(int(floor((width + 10.0) / (CHOOSER_ROW_SIZE.x + 10.0))), CHOOSER_MIN_COLUMNS, CHOOSER_MAX_COLUMNS)


func _on_chooser_search_changed(_text: String) -> void:
	_refresh_chooser()


func _category_label(move: PokemonMoveResource) -> String:
	match move.category:
		PokemonMoveResource.CATEGORY_PHYSICAL:
			return "Physical"
		PokemonMoveResource.CATEGORY_SPECIAL:
			return "Special"
		_:
			return "Status"


func _on_item_search_changed(_text: String) -> void:
	_refresh_slot_section()


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
	_queue_update_grid_columns()


func _create_roster_cell(entry: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Roster_%s" % String(entry.get("slug", "pokemon"))
	button.custom_minimum_size = Vector2(roster_cell_px, roster_cell_px)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.flat = true
	button.tooltip_text = String(entry.get("label", ""))
	button.add_to_group(UiSoundHook.OPT_OUT_GROUP)
	button.pressed.connect(_on_roster_pressed.bind(String(entry.get("path", ""))))

	var frame := Panel.new()
	frame.name = "PortraitFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 2
	frame.offset_top = 2
	frame.offset_right = -2
	frame.offset_bottom = -2
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", PmdStyle.portrait_overlay())
	button.add_child(frame)
	var texture_rect := TextureRect.new()
	texture_rect.name = "Portrait"
	texture_rect.texture = RosterProvider.texture_for_entry(entry)
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.offset_left = 2
	texture_rect.offset_top = 2
	texture_rect.offset_right = -2
	texture_rect.offset_bottom = -2
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(texture_rect)
	return button

func _refresh_team_trays() -> void:
	_populate_slots(player_slots, player_team_paths, SIDE_PLAYER)
	_populate_slots(enemy_slots, enemy_team_paths, SIDE_ENEMY)
	player_tray.add_theme_stylebox_override("panel", _style_box(ACTIVE_COLOR if active_side == SIDE_PLAYER else PANEL_COLOR, BORDER_COLOR if active_side == SIDE_PLAYER else MUTED_BORDER_COLOR, 2 if active_side == SIDE_PLAYER else 1))
	enemy_tray.add_theme_stylebox_override("panel", _style_box(ACTIVE_COLOR if active_side == SIDE_ENEMY else PANEL_COLOR, BORDER_COLOR if active_side == SIDE_ENEMY else MUTED_BORDER_COLOR, 2 if active_side == SIDE_ENEMY else 1))


func _team_size_slider(node_name: String, value: int) -> HSlider:
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = CustomSkirmishBuilder.MIN_TEAM_SIZE
	slider.max_value = CustomSkirmishBuilder.MAX_TEAM_SIZE
	slider.step = 1
	slider.value = value
	slider.custom_minimum_size = Vector2(120, CONTROL_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return slider


func _slider_row(slider: HSlider, value_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value := Label.new()
	value.name = value_name
	value.text = str(int(slider.value))
	value.custom_minimum_size.x = 40
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = str(int(v))
		_refresh_details()
		_refresh_launch_state())
	return row


func _sync_size_slider(side: String) -> void:
	var slider: HSlider = player_size_slider if side == SIDE_PLAYER else enemy_size_spin
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	if slider == null or team.is_empty():
		return
	slider.set_value_no_signal(float(team.size()))
	var row: Node = slider.get_parent()
	if row != null:
		var value_label: Label = row.get_node_or_null("PlayerSizeValue" if side == SIDE_PLAYER else "EnemySizeValue")
		if value_label != null:
			value_label.text = str(team.size())


func team_size_for(side: String) -> int:
	var slider: HSlider = player_size_slider if side == SIDE_PLAYER else enemy_size_spin
	return int(slider.value) if slider != null else CustomSkirmishBuilder.MIN_TEAM_SIZE


func _map_max_team_size() -> int:
	if map_paths.is_empty() or map_picker == null:
		return CustomSkirmishBuilder.MAX_TEAM_SIZE
	return CustomSkirmishBuilder.max_team_size_for(map_paths[clampi(map_picker.selected, 0, map_paths.size() - 1)])


func _apply_map_team_cap() -> void:
	var cap: int = _map_max_team_size()
	for slider in [enemy_size_spin, player_size_slider]:
		if slider != null:
			slider.max_value = cap
			slider.value = minf(slider.value, float(cap))


func _on_map_changed(index: int) -> void:
	if index >= map_paths.size():
		map_picker.select(clampi(_map_index, 0, maxi(0, map_paths.size() - 1)))
		_open_map_preview()
		return
	_map_index = index
	var cap: int = _map_max_team_size()
	_apply_map_team_cap()
	while player_team_paths.size() > cap:
		player_team_paths.pop_back()
	while enemy_team_paths.size() > cap:
		enemy_team_paths.pop_back()
	_sync_item_slots(SIDE_PLAYER)
	_sync_item_slots(SIDE_ENEMY)
	selected_player_index = mini(selected_player_index, player_team_paths.size() - 1)
	selected_enemy_index = mini(selected_enemy_index, enemy_team_paths.size() - 1)
	_refresh_team_trays()
	_refresh_details()
	_refresh_slot_section()
	_refresh_launch_state()


func _populate_slots(container: GridContainer, team: Array[String], side: String) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	var cap: int = _map_max_team_size()
	var rows: int = int(ceil(float(cap) / float(SLOT_COLUMNS)))
	var slot_height: float = SLOT_SIZE.y if rows <= 1 else COMPACT_SLOT_HEIGHT
	var tray: PanelContainer = player_tray if side == SIDE_PLAYER else enemy_tray
	if tray != null:
		tray.custom_minimum_size.y = TRAY_HEIGHT - SLOT_SIZE.y + slot_height * float(rows) + 4.0 * float(rows - 1)
	container.add_theme_constant_override("v_separation", 4)
	for i in range(cap):
		var path: String = team[i] if i < team.size() else ""
		var button: Button = _create_slot_button(path, i, side)
		button.custom_minimum_size = Vector2(SLOT_SIZE.x, slot_height)
		container.add_child(button)


func _create_slot_button(path: String, index: int, side: String) -> Button:
	var button := Button.new()
	button.name = "%sSlot%d" % [side.capitalize(), index + 1]
	button.custom_minimum_size = SLOT_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.button_pressed = _selected_index_for(side) == index and not path.is_empty()
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = "Slot %d" % (index + 1)
	button.add_to_group(UiSoundHook.OPT_OUT_GROUP)
	button.pressed.connect(_on_team_slot_pressed.bind(side, index))

	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6
	content.offset_top = 4
	content.offset_right = -6
	content.offset_bottom = -4
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var frame := Panel.new()
	frame.name = "PortraitFrame"
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = 0
	frame.offset_top = -SLOT_PORTRAIT_SIZE.y * 0.5
	frame.offset_right = SLOT_PORTRAIT_SIZE.x
	frame.offset_bottom = SLOT_PORTRAIT_SIZE.y * 0.5
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", PmdStyle.portrait_overlay())
	content.add_child(frame)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.anchor_top = 0.5
	portrait.anchor_bottom = 0.5
	portrait.offset_left = 0
	portrait.offset_top = -SLOT_PORTRAIT_SIZE.y * 0.5
	portrait.offset_right = SLOT_PORTRAIT_SIZE.x
	portrait.offset_bottom = SLOT_PORTRAIT_SIZE.y * 0.5
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	content.add_child(portrait)

	var label := Label.new()
	label.name = "NameLabel"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = SLOT_PORTRAIT_SIZE.x + 8.0
	label.offset_top = 0
	label.offset_right = 0
	label.offset_bottom = 0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_body_font(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)

	if path.is_empty():
		portrait.visible = false
		frame.visible = false
		label.offset_left = 0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", PmdStyle.FONT_CAPTION)
		label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
		label.text = "%d" % (index + 1)
	else:
		var entry: Dictionary = _entry_for_path(path)
		portrait.texture = RosterProvider.texture_for_entry(entry)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.text = String(entry.get("label", RosterProvider.label_for_path(path)))
		var item_id: String = _item_id_for(side, index)
		if item_id == CustomSkirmishBuilder.RANDOM_CHOICE:
			label.text += "\n@ random item"
		elif not item_id.is_empty():
			var item_entry: Dictionary = BattleItemCatalog.entry_for(item_id)
			label.text += "\n@ %s" % String(item_entry.get("label", item_id))
	return button


func _refresh_details() -> void:
	var target: String = "Player" if active_side == SIDE_PLAYER else "Enemy"
	target_label.text = "%s Team" % target
	details_label.text = "%s\nPlayer %d/%d  Enemy %d/%d" % [
		SkirmishControlMode.label(_selected_control_mode()),
		player_team_paths.size(),
		_map_max_team_size(),
		enemy_team_paths.size(),
		_map_max_team_size(),
	]


func _refresh_launch_state() -> void:
	if network_mode():
		if not net_session.host_role:
			launch_button.disabled = true
			launch_button.text = "Waiting for the host"
			return
		launch_button.text = "Launch Skirmish"
		var own_ok: bool = not player_team_paths.is_empty() or (random_player_check != null and random_player_check.button_pressed)
		var their_ok: bool = not enemy_team_paths.is_empty() or _remote_random
		launch_button.disabled = not (own_ok and their_ok and net_session.both_ready() and not map_paths.is_empty())
		return
	launch_button.text = "Launch Skirmish"
	var map_ok: bool = not map_paths.is_empty()
	var validation: Dictionary = _validate_seed_text()
	var seed_ok: bool = bool(validation.get("ok", false))
	var code_driven: bool = bool(validation.get("code_driven", false))
	var player_ready: bool = not player_team_paths.is_empty() or (random_player_check != null and random_player_check.button_pressed)
	var teams_ok: bool = code_driven or (player_ready and (random_enemy_check.button_pressed or not enemy_team_paths.is_empty()))
	launch_button.disabled = not (map_ok and seed_ok and teams_ok)
	if not seed_ok:
		_set_status(String(validation.get("error", "Invalid skirmish code")))


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
	if network_mode() and side != local_side_key():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_active_side(side)


func _set_active_side(side: String) -> void:
	active_side = side if side == SIDE_ENEMY else SIDE_PLAYER
	_set_status("")
	_refresh_team_trays()
	_refresh_details()
	_refresh_slot_section()


func _on_roster_pressed(path: String) -> void:
	var slug: String = PortraitLibrary.slug_for_path(path)
	var cell: Node = roster_grid.find_child("Roster_%s" % slug, false, false) if roster_grid != null else null
	if cell != null:
		_flash_portrait(cell.get_node_or_null("Portrait") as TextureRect, slug)
	SoundPlayer.cry(slug)
	_show_selected(path)
	_add_to_active_team(path)


func _add_to_active_team(path: String) -> bool:
	if path.is_empty():
		_set_status("Pick a roster Pokemon first")
		return false
	var team: Array[String] = player_team_paths if active_side == SIDE_PLAYER else enemy_team_paths
	if team.size() >= _map_max_team_size():
		_set_status("%s team is at the %d-Pokemon cap" % [_side_label(active_side), _map_max_team_size()])
		return false
	team.append(path)
	SoundPlayer.cue("lobby.join")
	_sync_item_slots(active_side)
	_sync_size_slider(active_side)
	if active_side == SIDE_PLAYER:
		selected_player_index = team.size() - 1
	else:
		selected_enemy_index = team.size() - 1
	summary_panel.visible = false
	_set_status("")
	_refresh_team_trays()
	_refresh_details()
	_refresh_slot_section()
	_refresh_launch_state()
	return true


func _on_team_slot_pressed(side: String, index: int) -> void:
	_set_active_side(side)
	if setup_page != _page_for_side(side):
		_show_setup_page(_page_for_side(side))
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
	var tray: Node = player_tray if side == SIDE_PLAYER else enemy_tray
	var slot: Node = tray.find_child("%sSlot%d" % [side.capitalize(), index + 1], true, false) if tray != null else null
	if slot != null:
		_flash_portrait(slot.get_node_or_null("Portrait") as TextureRect, PortraitLibrary.slug_for_path(team[index]))
	SoundPlayer.cry(PortraitLibrary.slug_for_path(team[index]))
	_show_selected(team[index])
	_refresh_team_trays()
	_refresh_slot_section()


func _remove_selected_from_side(side: String) -> void:
	var team: Array[String] = player_team_paths if side == SIDE_PLAYER else enemy_team_paths
	if team.is_empty():
		_set_status("%s team is already empty" % _side_label(side))
		return
	var idx: int = _selected_index_for(side)
	if idx < 0 or idx >= team.size():
		idx = team.size() - 1
	team.remove_at(idx)
	SoundPlayer.cue("lobby.leave")
	var specs: Array[Dictionary] = _specs_for_side(side)
	if idx < specs.size():
		specs.remove_at(idx)
	_sync_specs(side)
	_set_selected_index_for(side, mini(idx, team.size() - 1))
	_set_status("")
	_refresh_team_trays()
	_refresh_details()
	_refresh_slot_section()
	_refresh_launch_state()
	_sync_size_slider(side)


func _clear_side(side: String) -> void:
	if not (player_team_paths if side == SIDE_PLAYER else enemy_team_paths).is_empty():
		SoundPlayer.cue("lobby.leave")
	if side == SIDE_PLAYER:
		player_team_paths.clear()
		player_slot_specs.clear()
		selected_player_index = -1
	else:
		enemy_team_paths.clear()
		enemy_slot_specs.clear()
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
	_sync_specs(side)
	var specs: Array[Dictionary] = _specs_for_side(side)
	var moving_spec: Dictionary = specs[idx]
	specs[idx] = specs[next_idx]
	specs[next_idx] = moving_spec
	_set_selected_index_for(side, next_idx)
	_refresh_team_trays()
	_refresh_details()
	_refresh_slot_section()


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


func _on_control_mode_selected(_index: int) -> void:
	_refresh_details()
	_refresh_launch_state()


func _on_random_enemy_toggled(_enabled: bool) -> void:
	_refresh_details()
	_refresh_launch_state()


func _on_random_player_toggled(_enabled: bool) -> void:
	_refresh_details()
	_refresh_launch_state()


func set_session(session: NetSession) -> void:
	net_session = session
	if session != null and is_instance_valid(session):
		if not session.remote_lobby_changed.is_connected(_on_remote_lobby):
			session.remote_lobby_changed.connect(_on_remote_lobby)
		if not session.state_changed.is_connected(_on_net_state_changed):
			session.state_changed.connect(_on_net_state_changed)
	set_process(true)
	_apply_network_mode()


func network_mode() -> bool:
	return net_session != null and is_instance_valid(net_session) and net_session.active()


func local_side_key() -> String:
	return SIDE_PLAYER if net_session == null or net_session.host_role else SIDE_ENEMY


func remote_side_key() -> String:
	return SIDE_ENEMY if local_side_key() == SIDE_PLAYER else SIDE_PLAYER


func _on_net_state_changed(_state: int) -> void:
	_apply_network_mode()


func _on_net_ready_toggled(value: bool) -> void:
	if net_session != null and is_instance_valid(net_session):
		net_session.set_ready(value)
	_refresh_launch_state()


func _apply_network_mode() -> void:
	var net: bool = network_mode()
	if net_status_label != null:
		net_status_label.visible = net
	if net_ready_check != null:
		net_ready_check.visible = net
	var host_role: bool = net and net_session.host_role
	if control_mode_picker != null:
		control_mode_picker.disabled = net
		if net:
			for i in range(control_mode_picker.item_count):
				if String(control_mode_picker.get_item_metadata(i)) == SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER:
					control_mode_picker.select(i)
					break
	if map_picker != null:
		map_picker.disabled = net and not host_role
	if seed_input != null:
		seed_input.editable = not net or host_role
	if multiverse_toggle != null:
		multiverse_toggle.disabled = net and not host_role
	for slider in [player_size_slider, enemy_size_spin, difficulty_spin]:
		if slider != null:
			slider.editable = not net or host_role
	if random_player_check != null:
		random_player_check.disabled = net and not host_role
	if random_enemy_check != null:
		random_enemy_check.disabled = net and host_role
	if net:
		active_side = local_side_key()
	_refresh_team_trays()
	_refresh_launch_state()
	_update_net_status()


func remote_activity_label() -> String:
	if net_session == null or not is_instance_valid(net_session):
		return ""
	if net_session.remote_ready:
		return "Ready"
	if _remote_changed_at > 0 and Time.get_ticks_msec() - _remote_changed_at < REMOTE_CHOOSING_MS:
		return "Choosing..."
	return "Not ready"


func _update_net_titles() -> void:
	if player_tray_title == null or enemy_tray_title == null:
		return
	if not network_mode() or net_session.state == NetSession.HOSTING or net_session.state == NetSession.CONNECTING:
		player_tray_title.text = "Player Team"
		enemy_tray_title.text = "Enemy Team"
		return
	var local_name: String = net_session.local_name if not net_session.local_name.is_empty() else "You"
	var remote_name: String = net_session.remote_name if not net_session.remote_name.is_empty() else "Opponent"
	var mine: String = "%s (you)  Team %d" % [local_name, 1 if net_session.host_role else 2]
	var theirs: String = "%s  Team %d  %s" % [remote_name, 2 if net_session.host_role else 1, remote_activity_label()]
	if local_side_key() == SIDE_PLAYER:
		player_tray_title.text = mine
		enemy_tray_title.text = theirs
	else:
		player_tray_title.text = theirs
		enemy_tray_title.text = mine


func _on_copy_address_pressed() -> void:
	if net_session == null or net_session.public_address().is_empty():
		return
	DisplayServer.clipboard_set("%s:%d" % [net_session.public_address(), GameSettings.net_port])
	SoundPlayer.cue("ui.confirm")
	_set_status("Public address copied.")


func _on_copy_code_pressed() -> void:
	var code: String = code_output.text if code_output != null else ""
	if code.is_empty():
		return
	DisplayServer.clipboard_set(code)
	SoundPlayer.cue("ui.confirm")
	_set_status("Skirmish code copied.")


func _update_net_status() -> void:
	_update_net_titles()
	_refresh_tab_labels()
	if copy_address_button != null:
		copy_address_button.visible = network_mode() and net_session.host_role and not net_session.public_address().is_empty()
	if net_status_label == null or not network_mode():
		if copy_address_button != null:
			copy_address_button.visible = false
		return
	var lines: Array[String] = []
	match net_session.state:
		NetSession.HOSTING:
			var addresses: PackedStringArray = (net_session.link as EnetLink).local_addresses() if net_session.link is EnetLink else PackedStringArray()
			lines.append("Hosting on port %d. Waiting for a player." % GameSettings.net_port)
			if addresses.size() > 0:
				lines.append("LAN address: %s" % ", ".join(addresses))
			var router: String = net_session.router_status()
			if not router.is_empty():
				lines.append(router)
		NetSession.CONNECTING:
			lines.append("Connecting...")
		NetSession.LOBBY, NetSession.STARTING, NetSession.ENDED:
			lines.append("%s with %s." % ["Hosting" if net_session.host_role else "Joined", net_session.remote_name])
			if net_session.host_role and not net_session.public_address().is_empty():
				lines.append("Public address %s, UDP %d open on the router." % [net_session.public_address(), GameSettings.net_port])
			var activity: String = remote_activity_label()
			lines.append("You play Team %d. %s" % [1 if net_session.host_role else 2, "They are ready." if net_session.remote_ready else ("They are choosing." if activity == "Choosing..." else "Waiting for them to ready up.")])
			var ping: int = net_session.latency_ms()
			if ping >= 0:
				lines.append("Ping %d ms" % ping)
	net_status_label.text = "\n".join(lines)


func network_state() -> Dictionary:
	var side: String = local_side_key()
	_sync_specs(side)
	var paths: Array[String] = (player_team_paths if side == SIDE_PLAYER else enemy_team_paths).duplicate()
	var random_side: bool = false
	if side == SIDE_PLAYER and random_player_check != null:
		random_side = random_player_check.button_pressed
	elif side == SIDE_ENEMY and random_enemy_check != null:
		random_side = random_enemy_check.button_pressed
	return {
		"map_path": map_paths[clampi(map_picker.selected, 0, map_paths.size() - 1)] if not map_paths.is_empty() else "",
		"seed_text": seed_input.text if seed_input != null else "",
		"multiverse": _multiverse_wanted(),
		"reroll_seed": reroll_seed_check != null and reroll_seed_check.button_pressed,
		"player_team_size": int(player_size_slider.value) if player_size_slider != null else 3,
		"enemy_team_size": int(enemy_size_spin.value) if enemy_size_spin != null else 3,
		"difficulty_tier": int(difficulty_spin.value) if difficulty_spin != null else 0,
		"ai_level": int(ai_level_spin.value) if ai_level_spin != null else AIProfile.DEFAULT_LEVEL,
		"paths": paths,
		"items": _items_for_side(side),
		"specs": _specs_payload(side),
		"random": random_side,
		"ready": net_ready_check != null and net_ready_check.button_pressed,
	}


func _process(delta: float) -> void:
	if not network_mode() or _net_syncing or not visible:
		return
	_net_title_timer += delta
	if _net_title_timer >= 0.5:
		_net_title_timer = 0.0
		_update_net_status()
	_net_push_timer += delta
	if _net_push_timer < 0.25:
		return
	_net_push_timer = 0.0
	var state: Dictionary = network_state()
	if state == _net_sent:
		return
	_net_sent = state
	net_session.send_lobby(state)
	_update_net_status()


func _on_remote_lobby(state: Dictionary) -> void:
	if not network_mode():
		return
	_net_syncing = true
	var remote_ready_now: bool = bool(state.get("ready", false))
	if remote_ready_now and not _remote_ready_seen:
		remote_ready_cues += 1
		SoundPlayer.cue("lobby.item")
	_remote_ready_seen = remote_ready_now
	var fingerprint: String = var_to_str([state.get("paths", []), state.get("specs", []), state.get("items", []), state.get("random", false)])
	if fingerprint != _remote_fingerprint:
		_remote_fingerprint = fingerprint
		_remote_changed_at = Time.get_ticks_msec()
	var remote: String = remote_side_key()
	var paths: Array[String] = []
	for entry in state.get("paths", []):
		paths.append(String(entry))
	if remote == SIDE_ENEMY:
		enemy_team_paths = paths
		enemy_slot_specs.clear()
	else:
		player_team_paths = paths
		player_slot_specs.clear()
	_sync_specs(remote)
	_remote_items = state.get("items", [])
	_remote_specs = state.get("specs", [])
	_remote_random = bool(state.get("random", false))
	if not net_session.host_role:
		var wanted_map: String = String(state.get("map_path", ""))
		for i in range(map_paths.size()):
			if map_paths[i] == wanted_map:
				map_picker.select(i)
				break
		if seed_input != null:
			seed_input.text = String(state.get("seed_text", ""))
		if multiverse_toggle != null:
			multiverse_toggle.button_pressed = bool(state.get("multiverse", false))
		if reroll_seed_check != null:
			reroll_seed_check.button_pressed = bool(state.get("reroll_seed", false))
		if ai_level_spin != null:
			ai_level_spin.value = AIProfile.clamp_level(int(state.get("ai_level", AIProfile.DEFAULT_LEVEL)))
		if player_size_slider != null:
			player_size_slider.value = int(state.get("player_team_size", player_size_slider.value))
		if enemy_size_spin != null:
			enemy_size_spin.value = int(state.get("enemy_team_size", enemy_size_spin.value))
		if random_player_check != null:
			random_player_check.button_pressed = _remote_random
	_refresh_team_trays()
	_refresh_slot_section()
	_net_syncing = false
	_refresh_launch_state()
	_update_net_status()


func _network_launch_state() -> Dictionary:
	var local: String = local_side_key()
	_sync_specs(SIDE_PLAYER)
	_sync_specs(SIDE_ENEMY)
	var own_paths: Array[String] = (player_team_paths if local == SIDE_PLAYER else enemy_team_paths).duplicate()
	var own_items: Array = _items_for_side(local)
	var own_specs: Array = _specs_payload(local)
	var own_random: bool = (random_player_check != null and random_player_check.button_pressed) if local == SIDE_PLAYER else (random_enemy_check != null and random_enemy_check.button_pressed)
	var player_paths: Array = own_paths if local == SIDE_PLAYER else (player_team_paths.duplicate() as Array)
	var enemy_paths: Array = own_paths if local == SIDE_ENEMY else (enemy_team_paths.duplicate() as Array)
	return {
		"random_enemy": false,
		"random_player": own_random if local == SIDE_PLAYER else _remote_random,
		"player_paths": player_paths,
		"enemy_paths": enemy_paths,
		"player_items": own_items if local == SIDE_PLAYER else _remote_items,
		"enemy_items": own_items if local == SIDE_ENEMY else _remote_items,
		"player_specs": own_specs if local == SIDE_PLAYER else _remote_specs,
		"enemy_specs": own_specs if local == SIDE_ENEMY else _remote_specs,
		"map_path": map_paths[clampi(map_picker.selected, 0, map_paths.size() - 1)] if not map_paths.is_empty() else "",
		"seed_text": seed_input.text,
		"enemy_team_size": int(enemy_size_spin.value),
		"player_team_size": int(player_size_slider.value),
		"difficulty_tier": int(difficulty_spin.value),
		"control_mode": SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER,
	}


func network_launch_code() -> String:
	var network_state: Dictionary = _network_launch_state()
	var result: Dictionary = _build_from_state(network_state)
	_apply_multiverse(result, network_state)
	_apply_ai_level(result)
	if not bool(result.get("ok", false)):
		_set_status(String(result.get("error", "Could not build the match")))
		return ""
	var definitions: Array[SkirmishDefinitionResource] = _definitions_from_result(result)
	if definitions.is_empty():
		return ""
	return SkirmishCode.encode_definition(definitions[0])


func _on_launch_pressed() -> void:
	if network_mode():
		if not net_session.host_role:
			return
		var code: String = network_launch_code()
		if code.is_empty():
			return
		last_launch_code = code
		if code_output != null:
			code_output.text = code
		net_session.start_battle(code)
		return
	var result: Dictionary = _build_launch_result(true)
	if not result.get("ok", false):
		return
	var definitions: Array[SkirmishDefinitionResource] = _definitions_from_result(result)
	if definitions.size() > 1:
		launch_series_requested.emit(definitions, String(result.get("code", "")))
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	launch_requested.emit(definition, int(result["seed"]))


func _on_play_again_pressed() -> void:
	if _last_launch_state.is_empty():
		return
	if _reroll_seed_wanted():
		_last_launch_state["seed_text"] = ""
	var result: Dictionary = _build_from_state(_last_launch_state)
	if not result.get("ok", false):
		_set_status(String(result.get("error", "Could not replay skirmish")))
		return
	last_resolved_seed = int(result["seed"])
	var definitions: Array[SkirmishDefinitionResource] = _definitions_from_result(result)
	if definitions.size() > 1:
		launch_series_requested.emit(definitions, String(result.get("code", "")))
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	launch_requested.emit(definition, last_resolved_seed)


func _on_back_to_lobby_pressed() -> void:
	summary_panel.visible = false
	_refresh_launch_state()


func _on_close_pressed() -> void:
	visible = false
	close_requested.emit()


func request_close() -> void:
	if map_preview != null and map_preview.visible:
		map_preview.close()
		return
	if summary_panel != null and summary_panel.visible:
		_on_back_to_lobby_pressed()
		return
	_on_close_pressed()


func _open_map_preview() -> void:
	if map_preview == null:
		map_preview = MapPreviewScreen.new()
		map_preview.map_selected.connect(_on_preview_map_selected)
		map_preview.closed.connect(_on_preview_closed)
		add_child(map_preview)
	var layout: Control = get_node_or_null("LayoutMargin") as Control
	if layout != null:
		layout.visible = false
	map_preview.open(map_paths, _map_index)


func _on_preview_map_selected(index: int) -> void:
	if index < 0 or index >= map_paths.size():
		return
	map_picker.select(index)
	_on_map_changed(index)


func _on_preview_closed() -> void:
	var layout: Control = get_node_or_null("LayoutMargin") as Control
	if layout != null:
		layout.visible = true
	if map_picker != null and map_picker.is_inside_tree():
		map_picker.grab_focus()


func _build_launch_result(store_state: bool) -> Dictionary:
	if map_paths.is_empty():
		_set_status("No maps available")
		return {"ok": false, "error": "No maps available"}
	var map_path: String = map_paths[clampi(map_picker.selected, 0, map_paths.size() - 1)]
	_sync_specs(SIDE_PLAYER)
	_sync_specs(SIDE_ENEMY)
	var random_player: bool = random_player_check != null and random_player_check.button_pressed
	var state: Dictionary = {
		"random_enemy": random_enemy_check.button_pressed,
		"random_player": random_player,
		"player_paths": [] if random_player else player_team_paths.duplicate(),
		"enemy_paths": enemy_team_paths.duplicate(),
		"player_items": [] if random_player else _items_for_side(SIDE_PLAYER),
		"enemy_items": _items_for_side(SIDE_ENEMY),
		"player_specs": [] if random_player else _specs_payload(SIDE_PLAYER),
		"enemy_specs": _specs_payload(SIDE_ENEMY),
		"map_path": map_path,
		"seed_text": _launch_seed_text(),
		"enemy_team_size": int(enemy_size_spin.value),
		"player_team_size": int(player_size_slider.value),
		"difficulty_tier": int(difficulty_spin.value),
		"control_mode": _selected_control_mode(),
	}
	var result: Dictionary = _build_from_state(state)
	_apply_multiverse(result, state)
	_apply_ai_level(result)
	if not result.get("ok", false):
		_set_status(String(result.get("error", "Could not build skirmish")))
		return result
	last_resolved_seed = int(result["seed"])
	if not bool(result.get("code_driven", false)) and not _reroll_seed_wanted():
		seed_input.text = str(last_resolved_seed)
	if store_state:
		if not bool(result.get("code_driven", false)) and not _reroll_seed_wanted():
			state["seed_text"] = str(last_resolved_seed)
		_last_launch_state = state
	summary_panel.visible = false
	var definitions: Array[SkirmishDefinitionResource] = _definitions_from_result(result)
	if definitions.size() > 1:
		_set_status(SkirmishCode.encode_summary(definitions))
	elif definitions.size() == 1:
		last_launch_code = SkirmishCode.encode_definition(definitions[0])
		if code_output != null:
			code_output.text = last_launch_code
		if copy_code_button != null:
			copy_code_button.disabled = last_launch_code.is_empty()
		_set_status("Seed %d. Copy the full code from the box below to replay this setup." % last_resolved_seed)
	else:
		_set_status("Seed: %d" % last_resolved_seed)
	return result


func _apply_ai_level(result: Dictionary) -> void:
	var wanted: int = AIProfile.clamp_level(int(ai_level_spin.value)) if ai_level_spin != null else AIProfile.DEFAULT_LEVEL
	var primary: SkirmishDefinitionResource = result.get("definition", null) as SkirmishDefinitionResource
	if primary != null:
		primary.ai_level = wanted
	for definition in result.get("definitions", []):
		if definition is SkirmishDefinitionResource:
			(definition as SkirmishDefinitionResource).ai_level = wanted


func _reroll_seed_wanted() -> bool:
	if reroll_seed_check == null or not reroll_seed_check.button_pressed:
		return false
	return not SkirmishCode.is_rich_code(seed_input.text if seed_input != null else "")


func _launch_seed_text() -> String:
	if seed_input == null:
		return ""
	return "" if _reroll_seed_wanted() else seed_input.text


func _multiverse_wanted() -> bool:
	return multiverse_toggle != null and multiverse_toggle.button_pressed


func _apply_multiverse(result: Dictionary, state: Dictionary = {}) -> void:
	var wanted: bool = _multiverse_wanted()
	var primary: SkirmishDefinitionResource = result.get("definition", null) as SkirmishDefinitionResource
	if primary != null and wanted:
		primary.multiverse = true
		_apply_traveller_moves(primary, state)
	for definition in result.get("definitions", []):
		if definition is SkirmishDefinitionResource and wanted:
			(definition as SkirmishDefinitionResource).multiverse = true
			_apply_traveller_moves(definition as SkirmishDefinitionResource, state)


func _apply_traveller_moves(definition: SkirmishDefinitionResource, state: Dictionary) -> void:
	if state.is_empty():
		return
	if _string_array(state.get("player_paths", [])).is_empty():
		MultiverseRoster.ensure_traveller_moves(definition.player_team)
	if bool(state.get("random_enemy", false)) or _string_array(state.get("enemy_paths", [])).is_empty():
		MultiverseRoster.ensure_traveller_moves(definition.enemy_team)


func _build_from_state(state: Dictionary) -> Dictionary:
	var seed_text: String = String(state.get("seed_text", ""))
	if SkirmishCode.is_rich_code(seed_text):
		var built: Dictionary = SkirmishCode.build_definitions(seed_text, state)
		if not bool(built.get("ok", false)):
			return built
		return _result_with_primary(built, true)
	var legacy: Dictionary = SkirmishCode.legacy_seed_and_mode(seed_text, String(state.get("control_mode", "")))
	if legacy.has("error"):
		return {"ok": false, "error": String(legacy["error"])}
	var resolved_seed_text: String = String(legacy.get("seed_text", ""))
	var control_mode: String = String(legacy.get("control_mode", SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU))
	var fill_seed: int = CustomSkirmishBuilder.resolve_seed(resolved_seed_text)
	var player_seed_paths: Array[String] = []
	if not bool(state.get("random_player", false)):
		player_seed_paths = _string_array(state.get("player_paths", []))
	var enemy_seed_paths: Array[String] = _string_array(state.get("enemy_paths", []))
	var player_paths: Array[String] = CustomSkirmishBuilder.fill_random_paths(player_seed_paths, int(state.get("player_team_size", 0)), fill_seed ^ 0x51A7)
	var enemy_paths: Array[String] = CustomSkirmishBuilder.fill_random_paths(enemy_seed_paths, int(state.get("enemy_team_size", 0)), fill_seed ^ 0x3E2D)
	var travellers_wanted: bool = _multiverse_wanted()
	if travellers_wanted and player_seed_paths.is_empty():
		player_paths = MultiverseRoster.ensure_traveller_paths(player_paths, fill_seed ^ 0x51A7)
	if travellers_wanted and enemy_seed_paths.is_empty():
		enemy_paths = MultiverseRoster.ensure_traveller_paths(enemy_paths, fill_seed ^ 0x3E2D)
	if bool(state.get("random_enemy", false)):
		return CustomSkirmishBuilder.build_with_random_enemy(
			player_paths,
			String(state.get("map_path", "")),
			resolved_seed_text,
			int(state.get("enemy_team_size", 1)),
			int(state.get("difficulty_tier", CustomSkirmishBuilder.DEFAULT_RANDOM_DIFFICULTY_TIER)),
			"",
			"",
			control_mode,
			travellers_wanted
		)
	return CustomSkirmishBuilder.build(
		player_paths,
		enemy_paths,
		String(state.get("map_path", "")),
		resolved_seed_text,
		control_mode,
		_string_array(state.get("player_items", [])),
		_string_array(state.get("enemy_items", [])),
		{"player": state.get("player_specs", []), "enemy": state.get("enemy_specs", [])}
	)


func _update_grid_columns() -> void:
	if roster_grid == null or roster_scroll == null:
		return
	var available_width: float = _roster_available_width()
	if available_width <= 1.0:
		return
	var layout: Dictionary = _grid_layout_for_width(available_width)
	roster_grid.columns = int(layout["columns"])
	var cell: float = float(layout["cell"])
	if not is_equal_approx(cell, roster_cell_px):
		roster_cell_px = cell
		roster_cell_scale = cell / CELL_SIZE.x
		_apply_cell_scale()


func _roster_available_width() -> float:
	var available_width: float = _roster_width_budget()
	if roster_scroll == null or roster_scroll.size.x <= 1.0:
		return available_width
	var scroll_width: float = roster_scroll.size.x
	var v_bar: VScrollBar = roster_scroll.get_v_scroll_bar()
	if v_bar != null and v_bar.visible:
		scroll_width -= v_bar.size.x
	return minf(available_width, scroll_width)


func _grid_layout_for_width(available_width: float) -> Dictionary:
	var columns: int = ROSTER_COLUMNS
	var cell: float = maxf(ROSTER_MIN_CELL, floor((available_width - GRID_GAP * float(columns - 1)) / float(columns)))
	return {
		"columns": columns,
		"cell": cell,
		"scale": cell / CELL_SIZE.x,
	}


func _apply_cell_scale() -> void:
	if roster_grid == null:
		return
	for child in roster_grid.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(roster_cell_px, roster_cell_px)


func roster_cell_size() -> Vector2:
	return Vector2(roster_cell_px, roster_cell_px)


func _queue_update_grid_columns() -> void:
	call_deferred("_apply_responsive_layout")


func _apply_responsive_layout() -> void:
	if is_inside_tree():
		_apply_font_step()
	var compact: bool = _uses_compact_layout()
	for pad in _scroll_pads:
		pad.add_theme_constant_override("margin_left", 0 if compact else 2)
		pad.add_theme_constant_override("margin_right", 0 if compact else SCROLL_PAD_RIGHT)
	for grid in [match_grid, editor_grid]:
		if grid != null:
			grid.columns = 1 if compact else 2
	if setup_panel != null:
		setup_panel.custom_minimum_size.x = SETUP_PANEL_COMPACT_WIDTH if compact else SETUP_PANEL_WIDTH
	if details_panel != null:
		details_panel.custom_minimum_size.x = DETAILS_PANEL_COMPACT_WIDTH if compact else DETAILS_PANEL_WIDTH
	if type_filter != null:
		type_filter.custom_minimum_size.x = TYPE_FILTER_COMPACT_WIDTH if compact else TYPE_FILTER_WIDTH
	if sort_picker != null:
		sort_picker.custom_minimum_size.x = SORT_PICKER_COMPACT_WIDTH if compact else SORT_PICKER_WIDTH
	_update_grid_columns()
	_update_chooser_columns()


func _uses_compact_layout() -> bool:
	return _layout_width() < COMPACT_LAYOUT_WIDTH


func _layout_width() -> float:
	if size.x > 1.0:
		return size.x
	return get_viewport_rect().size.x


func _roster_width_budget() -> float:
	var content_width: float = maxf(0.0, _layout_width() - LAYOUT_MARGIN_X * 2.0)
	var half: float = (content_width - MIDDLE_GAP) * 0.5
	var setup_width: float = half
	if setup_panel != null:
		setup_width = maxf(half, setup_panel.get_combined_minimum_size().x)
	var roster_outer: float = content_width - MIDDLE_GAP - setup_width
	return maxf(ROSTER_MIN_CELL * float(ROSTER_COLUMNS) + GRID_GAP * float(ROSTER_COLUMNS - 1), roster_outer - PANEL_MARGIN_X * 4.0 - _roster_scrollbar_width())


func _roster_scrollbar_width() -> float:
	if roster_scroll == null:
		return 8.0
	var bar: VScrollBar = roster_scroll.get_v_scroll_bar()
	return maxf(8.0, bar.get_combined_minimum_size().x) if bar != null else 8.0


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


func _format_team(team: Array[String], items: Array[String] = []) -> String:
	if team.is_empty():
		return "(empty)"
	var labels: Array[String] = []
	for i in range(team.size()):
		var path: String = team[i]
		var label: String = String(_entry_for_path(path).get("label", RosterProvider.label_for_path(path)))
		var item_id: String = String(items[i]) if i < items.size() else ""
		if item_id == CustomSkirmishBuilder.RANDOM_CHOICE:
			label += " @ random item"
		elif not item_id.is_empty():
			label += " @ %s" % String(BattleItemCatalog.entry_for(item_id).get("label", item_id))
		labels.append(label)
	return ", ".join(labels)


func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item in value:
			out.append(String(item))
	return out


func _selected_control_mode() -> String:
	if control_mode_picker == null:
		return SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU
	var idx: int = maxi(control_mode_picker.selected, 0)
	var metadata: Variant = control_mode_picker.get_item_metadata(idx)
	return SkirmishControlMode.normalize(String(metadata))


func _validate_seed_text() -> Dictionary:
	if seed_input == null:
		return {"ok": true, "code_driven": false}
	var text: String = seed_input.text.strip_edges()
	if text.is_empty() or SkirmishCode.is_legacy_seed_or_flag(text):
		return {"ok": true, "code_driven": false}
	if SkirmishCode.is_rich_code(text):
		var parsed: Dictionary = SkirmishCode.parse(text)
		return {
			"ok": bool(parsed.get("ok", false)),
			"code_driven": bool(parsed.get("ok", false)),
			"error": String(parsed.get("error", "")),
		}
	return {"ok": false, "code_driven": false, "error": "Seed must be an integer, empty, or a skirmish code"}


func _result_with_primary(result: Dictionary, code_driven: bool) -> Dictionary:
	var definitions: Array[SkirmishDefinitionResource] = _definitions_from_result(result)
	if definitions.is_empty():
		return {"ok": false, "error": "Skirmish code did not build any definitions"}
	var out: Dictionary = result.duplicate(true)
	out["definition"] = definitions[0]
	out["seed"] = definitions[0].seed
	out["code_driven"] = code_driven
	return out


func _definitions_from_result(result: Dictionary) -> Array[SkirmishDefinitionResource]:
	var out: Array[SkirmishDefinitionResource] = []
	if result.has("definitions") and result["definitions"] is Array:
		for entry in result["definitions"]:
			if entry is SkirmishDefinitionResource:
				out.append(entry as SkirmishDefinitionResource)
	elif result.get("definition", null) is SkirmishDefinitionResource:
		out.append(result["definition"] as SkirmishDefinitionResource)
	return out


func _result_label(result: int, definition: SkirmishDefinitionResource) -> String:
	var mode: String = SkirmishControlMode.normalize(definition.control_mode if definition != null else "")
	if mode == SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU:
		return "Player-side Win" if result == TacticsLevel.RESULT_PLAYER_WIN else "Enemy-side Win"
	return "Player Win" if result == TacticsLevel.RESULT_PLAYER_WIN else "Player Loss"


func _side_label(side: String) -> String:
	return "Player" if side == SIDE_PLAYER else "Enemy"


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
		status_label.visible = not text.is_empty()


func _style_box(color: Color, border: Color, border_width: int) -> StyleBox:
	var fill: Color = PmdStyle.NAVY_LIGHT if color == ACTIVE_COLOR else (PmdStyle.NAVY_DEEP if border_width == 0 else PmdStyle.NAVY)
	var frame: Color = PmdStyle.CURSOR if border == BORDER_COLOR else PmdStyle.FRAME_SOFT
	var style: StyleBox = PmdStyle.window(fill, frame, maxi(border_width, 1), 6)
	var flat: StyleBoxFlat = (style as PmdWindowStyle).flat if style is PmdWindowStyle else style as StyleBoxFlat
	if flat != null:
		flat.shadow_size = 3 if border_width > 0 else 0
	return style


func _make_lobby_theme() -> Theme:
	var lobby_theme := Theme.new()
	for type_name in ["Button", "CheckBox", "Label", "LineEdit", "OptionButton", "SpinBox"]:
		lobby_theme.set_font_size("font_size", type_name, body_font_size)
	return lobby_theme


func _font_step_for_width(width: float) -> int:
	return FONT_SIZE if width >= LARGE_FONT_LAYOUT_WIDTH else COMPACT_FONT_SIZE


func _apply_font_step() -> void:
	var body: int = _font_step_for_width(_layout_width())
	var title: int = TITLE_FONT_SIZE if body == FONT_SIZE else COMPACT_TITLE_FONT_SIZE
	if body == body_font_size and title == title_font_size and theme != null:
		return
	body_font_size = body
	title_font_size = title
	theme = _make_lobby_theme()
	for node in get_tree().get_nodes_in_group(TITLE_FONT_GROUP):
		if node is Control:
			(node as Control).add_theme_font_size_override("font_size", title_font_size)
	for node in get_tree().get_nodes_in_group(BODY_FONT_GROUP):
		if node is Control:
			(node as Control).add_theme_font_size_override("font_size", body_font_size)


func _apply_title_font(control: Control) -> void:
	control.add_theme_font_override("font", PmdStyle.font_title())
	control.add_theme_font_size_override("font_size", title_font_size)
	control.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD)
	control.add_to_group(TITLE_FONT_GROUP, true)


func _apply_body_font(control: Control) -> void:
	control.add_theme_font_size_override("font_size", body_font_size)
	control.add_to_group(BODY_FONT_GROUP, true)


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
