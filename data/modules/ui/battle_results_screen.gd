class_name BattleResultsScreen
extends CanvasLayer

signal play_again_requested
signal lobby_requested
signal main_menu_requested

const LAYER_INDEX: int = 25
const PORTRAIT_SIZE: float = 64.0
const BUTTON_HEIGHT: float = 52.0
const PANEL_WIDTH: float = 900.0

var result_code: int = 0
var _center: CenterContainer = null
var _panel: PanelContainer = null
var _title: Label = null
var _subtitle: Label = null
var _columns: HBoxContainer = null
var _buttons: Dictionary = {}


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
		margin.add_theme_constant_override("margin_%s" % side, 20)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_title = Label.new()
	_title.name = "ResultTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PmdStyle.apply_title(_title, 64)
	column.add_child(_title)
	_subtitle = Label.new()
	_subtitle.name = "ResultSubtitle"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	column.add_child(_subtitle)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 24)
	column.add_child(_columns)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_add_button(buttons, "Play Again", "PlayAgainButton", play_again_requested)
	_add_button(buttons, "Lobby", "LobbyButton", lobby_requested)
	_add_button(buttons, "Main Menu", "MainMenuButton", main_menu_requested)
	visible = false


func show_result(result: int, definition: SkirmishDefinitionResource, level: TacticsLevel) -> void:
	result_code = result
	var human_player: bool = definition == null or definition.control_mode != SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU
	match result:
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
	for child in _columns.get_children():
		child.queue_free()
	if level != null:
		_columns.add_child(_side_column("Player", level.player, PmdStyle.TEAM_PLAYER, level))
		_columns.add_child(_side_column("Enemy", level.opponent, PmdStyle.TEAM_ENEMY, level))
	visible = true
	var play_again: Button = _buttons.get("PlayAgainButton", null)
	if play_again != null:
		play_again.grab_focus()


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
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for pawn in pawns:
		grid.add_child(_unit_row(pawn, level))
	return column


func _unit_row(pawn: TacticsPawn, level: TacticsLevel) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var expression: String = "Normal" if pawn.is_alive() else "Pain"
	portrait.texture = PortraitLibrary.texture_for(PortraitLibrary.slug_for_pawn(pawn), expression)
	if not pawn.is_alive():
		portrait.modulate = Color(0.55, 0.55, 0.55, 1.0)
	row.add_child(portrait)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = "%s  Lv %d" % [level.notation.unit_name(pawn), pawn.stats.level if pawn.stats != null else 0]
	text.add_child(name_label)
	var bar := PmdHpBar.new()
	bar.custom_minimum_size = Vector2(160, 14)
	if pawn.stats != null:
		bar.set_values(pawn.stats.curr_health, pawn.stats.max_health)
	text.add_child(bar)
	return row


func _add_button(row: HBoxContainer, text: String, node_name: String, signal_to_emit: Signal) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(200, BUTTON_HEIGHT)
	button.pressed.connect(func() -> void:
		hide_results()
		signal_to_emit.emit())
	row.add_child(button)
	_buttons[node_name] = button
