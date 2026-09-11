class_name BattleResultsScreen
extends CanvasLayer

signal play_again_requested
signal lobby_requested
signal main_menu_requested
signal next_requested

const LAYER_INDEX: int = 25
const PORTRAIT_SIZE: float = 64.0
const BUTTON_HEIGHT: float = PmdStyle.CONTROL_HEIGHT
const PANEL_WIDTH: float = PmdStyle.PANEL_WIDTH
const ROSTER_CHROME: float = 260.0
const ROSTER_MIN_HEIGHT: float = 200.0

var result_code: int = 0
var _center: CenterContainer = null
var _panel: PanelContainer = null
var _title: Label = null
var _subtitle: Label = null
var _columns: HBoxContainer = null
var _scroll: ScrollContainer = null
var _buttons: Dictionary = {}
var _level: TacticsLevel = null
var _copy_button: Button = null
var _copy_tween: Tween = null


func _ready() -> void:
	name = "BattleResultsScreen"
	layer = LAYER_INDEX
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_panel = PanelContainer.new()
	_panel.name = "ResultsPanel"
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.add_theme_stylebox_override("panel", PmdStyle.window())
	_center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, PmdStyle.PANEL_MARGIN)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PmdStyle.PANEL_GAP)
	margin.add_child(column)
	_title = Label.new()
	_title.name = "ResultTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PmdStyle.apply_title(_title, PmdStyle.FONT_HERO)
	column.add_child(_title)
	_subtitle = Label.new()
	_subtitle.name = "ResultSubtitle"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	column.add_child(_subtitle)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 24)
	_scroll = ScrollContainer.new()
	_scroll.name = "RosterScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_columns)
	column.add_child(_scroll)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", PmdStyle.PANEL_GAP)
	buttons.add_theme_constant_override("v_separation", PmdStyle.PANEL_GAP)
	buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_add_button(buttons, "Play Again", "PlayAgainButton", play_again_requested)
	_add_button(buttons, "Lobby", "LobbyButton", lobby_requested)
	_add_button(buttons, "Main Menu", "MainMenuButton", main_menu_requested)
	_add_button(buttons, "Next Battle", "NextButton", next_requested)
	_copy_button = PmdStyle.control_button("Copy Notation", "CopyButton", _on_copy_pressed)
	_copy_button.custom_minimum_size.x = 200
	buttons.add_child(_copy_button)
	visible = false


func set_play_again_label(text: String, enabled: bool) -> void:
	var button: Button = _buttons.get("PlayAgainButton", null)
	if button == null:
		return
	button.text = text
	button.disabled = not enabled


func show_result(result: int, definition: SkirmishDefinitionResource, level: TacticsLevel, next_label: String = "", local_side: int = PokemonInstanceResource.Team.PLAYER) -> void:
	result_code = result
	var viewer_won: int = result
	if local_side == PokemonInstanceResource.Team.ENEMY:
		viewer_won = 2 if result == 1 else (1 if result == 2 else result)
	_level = level
	_copy_button.text = "Copy Notation"
	_copy_button.visible = level != null and level.notation != null
	var viewport_width: float = _center.size.x if _center != null else 0.0
	if viewport_width > 0.0:
		_panel.custom_minimum_size.x = minf(PANEL_WIDTH, viewport_width - 40.0)
	var viewport_height: float = _center.size.y if _center != null else 0.0
	if viewport_height > 0.0 and _scroll != null:
		_scroll.custom_minimum_size.y = maxf(ROSTER_MIN_HEIGHT, viewport_height - ROSTER_CHROME)
	var series: bool = not next_label.is_empty()
	for node_name in ["PlayAgainButton", "LobbyButton", "MainMenuButton"]:
		(_buttons[node_name] as Button).visible = not series
	var next_button: Button = _buttons["NextButton"]
	next_button.visible = series
	next_button.text = next_label
	var human_player: bool = definition == null or definition.control_mode != SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU
	SoundPlayer.cue("battle.victory" if result == 1 else ("battle.defeat" if result == 2 else ""))
	match viewer_won:
		1:
			_title.text = "Victory!" if human_player else "Player side wins"
			_title.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD)
		2:
			_title.text = "Defeat" if human_player else "Enemy side wins"
			_title.add_theme_color_override("font_color", PmdStyle.HP_LOW)
		_:
			_title.text = "Battle over"
			_title.add_theme_color_override("font_color", PmdStyle.TEXT)
	var mode: String = SkirmishControlMode.label(definition.control_mode) if definition != null else ""
	var seed: int = definition.seed if definition != null else (level.battle_seed if level != null else 0)
	var turns: int = level.notation.turn_index if level != null and level.notation != null else 0
	_subtitle.text = "%s   Seed %d   %d turns" % [mode, seed, turns]
	if level != null and level.multiverse != null and level.multiverse.enabled and not level.multiverse.state.timelines.is_empty():
		_subtitle.text += "   Timelines %d   Travels %d" % [level.multiverse.state.timeline_ids().size(), level.multiverse.travels]
		var per_timeline: String = level.multiverse.timeline_summary()
		if not per_timeline.is_empty():
			_subtitle.text += "\n" + per_timeline
	for child in _columns.get_children():
		child.queue_free()
	if level != null:
		_columns.add_child(_side_column("Player", level.player, PmdStyle.player_color(), level))
		_columns.add_child(_side_column("Enemy", level.opponent, PmdStyle.enemy_color(), level))
	visible = true
	var focus_target: Button = _buttons["NextButton"] if series else _buttons.get("PlayAgainButton", null)
	if focus_target != null:
		focus_target.grab_focus()


func hide_results() -> void:
	visible = false


func _side_column(caption: String, parent: Node, color: Color, level: TacticsLevel) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	var pawns: Array[TacticsPawn] = []
	if parent != null:
		for child in parent.get_children():
			if child is TacticsPawn:
				pawns.append(child)
	var alive: int = 0
	for pawn in pawns:
		if pawn.is_alive():
			alive += 1
	var header := Label.new()
	header.text = "%s  %d/%d standing" % [caption, alive, pawns.size()]
	header.add_theme_color_override("font_color", color)
	column.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 2 if _panel.custom_minimum_size.x >= PANEL_WIDTH else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for pawn in pawns:
		grid.add_child(_unit_row(pawn, level))
	return column


func _unit_row(pawn: TacticsPawn, level: TacticsLevel) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var frame := PanelContainer.new()
	frame.name = "PortraitFrame"
	frame.add_theme_stylebox_override("panel", PmdStyle.portrait_overlay())
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var expression: String = "Normal" if pawn.is_alive() else "Pain"
	portrait.texture = PortraitLibrary.texture_for(PortraitLibrary.slug_for_pawn(pawn), expression)
	if not pawn.is_alive():
		portrait.modulate = Color(0.55, 0.55, 0.55, 1.0)
	frame.add_child(portrait)
	row.add_child(frame)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = "%s%s  Lv %d" % [FormRules.decorate(level.notation.unit_name(pawn), pawn.stats), GenderRules.suffix(pawn.stats.gender) if pawn.stats != null else "", pawn.stats.level if pawn.stats != null else 0]
	text.add_child(name_label)
	var bar := PmdHpBar.new()
	bar.custom_minimum_size = Vector2(160, 14)
	if pawn.stats != null:
		bar.set_values(pawn.stats.curr_health, pawn.stats.max_health)
	text.add_child(bar)
	if level != null and level.stats_tracker != null:
		var summary: Dictionary = level.stats_tracker.summary(pawn)
		var stats_label := Label.new()
		stats_label.name = "UnitStats"
		stats_label.text = "Dealt %d  Taken %d  KO %d" % [int(summary.get("dealt", 0)), int(summary.get("taken", 0)), int(summary.get("kos", 0))]
		stats_label.add_theme_font_size_override("font_size", PmdStyle.FONT_CAPTION)
		stats_label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
		text.add_child(stats_label)
	return row


func notation_text() -> String:
	if _level == null or not is_instance_valid(_level) or _level.notation == null:
		return ""
	return _level.notation.text()


func _on_copy_pressed() -> void:
	var text: String = notation_text()
	if text.is_empty():
		return
	DisplayServer.clipboard_set(text)
	_copy_button.text = "Copied!"
	if _copy_tween != null and _copy_tween.is_valid():
		_copy_tween.kill()
	_copy_tween = create_tween()
	_copy_tween.tween_interval(1.5)
	_copy_tween.tween_callback(func() -> void: _copy_button.text = "Copy Notation")


func _add_button(row: Container, text: String, node_name: String, signal_to_emit: Signal) -> void:
	var button := PmdStyle.control_button(text, node_name, func() -> void:
		hide_results()
		signal_to_emit.emit())
	button.custom_minimum_size.x = 200
	row.add_child(button)
	_buttons[node_name] = button
