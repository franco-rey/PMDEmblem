class_name BattleBanner
extends CanvasLayer

signal intro_finished

const LAYER_INDEX: int = 21
const TURN_SECONDS: float = 1.1
const NOTICE_SECONDS: float = 1.8
const INTRO_SECONDS: float = 2.6
const PORTRAIT_PX: float = 56.0

var level: TacticsLevel = null
var intro_active: bool = false
var last_turn_shown: int = 0
var notices_shown: int = 0
var _root: Control = null
var _turn_panel: PanelContainer = null
var _turn_label: Label = null
var _turn_tween: Tween = null
var _notice_chip: PanelContainer = null
var _notice_label: Label = null
var _notice_tween: Tween = null
var _intro: Control = null
var _intro_timer: SceneTreeTimer = null


func _ready() -> void:
	name = "BattleBanner"
	layer = LAYER_INDEX
	_root = Control.new()
	_root.name = "BannerRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_turn_panel = PanelContainer.new()
	_turn_panel.name = "TurnBanner"
	_turn_panel.set_anchors_preset(Control.PRESET_CENTER)
	_turn_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_turn_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_turn_panel.add_theme_stylebox_override("panel", PmdStyle.window(PmdStyle.NAVY, PmdStyle.CURSOR, 3, 8))
	_turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_panel.visible = false
	_root.add_child(_turn_panel)
	_turn_label = Label.new()
	_turn_label.name = "TurnLabel"
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.custom_minimum_size = Vector2(360, 0)
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PmdStyle.apply_heading(_turn_label, 48)
	_turn_panel.add_child(_turn_label)
	_notice_chip = PanelContainer.new()
	_notice_chip.name = "NoticeChip"
	_notice_chip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice_chip.anchor_left = 0.5
	_notice_chip.anchor_right = 0.5
	_notice_chip.offset_top = 236
	_notice_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice_chip.add_theme_stylebox_override("panel", PmdStyle.chip(PmdStyle.NAVY_DEEP, PmdStyle.CURSOR))
	_notice_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_chip.visible = false
	_root.add_child(_notice_chip)
	_notice_label = Label.new()
	_notice_label.name = "NoticeLabel"
	_notice_label.add_theme_font_size_override("font_size", PmdStyle.FONT_CAPTION)
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_chip.add_child(_notice_label)


func setup(battle_level: TacticsLevel) -> void:
	level = battle_level
	if level != null and level.battle_log != null and not level.battle_log.event_appended.is_connected(_on_event):
		level.battle_log.event_appended.connect(_on_event)


func show_turn(round_index: int) -> void:
	if not GameSettings.battle_flair or intro_active:
		return
	last_turn_shown = round_index
	_turn_label.text = "Turn %d" % round_index
	_turn_panel.visible = true
	_turn_panel.modulate = Color(1, 1, 1, 0)
	_turn_panel.reset_size()
	_turn_panel.pivot_offset = _turn_panel.size * 0.5
	_turn_panel.scale = Vector2(0.85, 0.85)
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.set_parallel(true)
	_turn_tween.tween_property(_turn_panel, "modulate:a", 1.0, 0.18)
	_turn_tween.tween_property(_turn_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_turn_tween.chain().tween_interval(TURN_SECONDS - 0.5)
	_turn_tween.chain().tween_property(_turn_panel, "modulate:a", 0.0, 0.25)
	_turn_tween.chain().tween_callback(func() -> void: _turn_panel.visible = false)


func show_notice(text: String) -> void:
	if not GameSettings.battle_flair or text.is_empty():
		return
	notices_shown += 1
	_notice_label.text = text
	_notice_chip.visible = true
	_notice_chip.modulate = Color(1, 1, 1, 1)
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_SECONDS)
	_notice_tween.tween_property(_notice_chip, "modulate:a", 0.0, 0.3)
	_notice_tween.tween_callback(func() -> void: _notice_chip.visible = false)


func show_intro(battle_level: TacticsLevel, definition: SkirmishDefinitionResource) -> void:
	if battle_level == null:
		return
	level = battle_level
	if _intro != null:
		_intro.queue_free()
	intro_active = true
	level.intro_pending = true
	_intro = Control.new()
	_intro.name = "Intro"
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro.gui_input.connect(_on_intro_input)
	_root.add_child(_intro)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "IntroPanel"
	panel.add_theme_stylebox_override("panel", PmdStyle.window())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.name = "IntroTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var map_name: String = ""
	if definition != null and definition.map != null:
		map_name = definition.map.display_name if not definition.map.display_name.is_empty() else definition.map.map_id.capitalize()
	title.text = map_name if not map_name.is_empty() else "Skirmish"
	PmdStyle.apply_title(title, 24)
	column.add_child(title)
	var mode_label := Label.new()
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	mode_label.text = SkirmishControlMode.label(definition.control_mode) if definition != null else ""
	column.add_child(mode_label)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 24)
	sides.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(sides)
	sides.add_child(_team_column("Player", level.player, PmdStyle.TEAM_PLAYER))
	var versus := Label.new()
	versus.text = "VS"
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PmdStyle.apply_title(versus, 24)
	sides.add_child(versus)
	sides.add_child(_team_column("Enemy", level.opponent, PmdStyle.TEAM_ENEMY))
	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	hint.text = "Click to begin"
	column.add_child(hint)
	_intro_timer = get_tree().create_timer(INTRO_SECONDS, false)
	_intro_timer.timeout.connect(finish_intro)


func finish_intro() -> void:
	if not intro_active:
		return
	intro_active = false
	if _intro != null:
		_intro.queue_free()
		_intro = null
	if level != null and is_instance_valid(level):
		level.intro_pending = false
	intro_finished.emit()


func _on_intro_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		finish_intro()


func _unhandled_input(event: InputEvent) -> void:
	if intro_active and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		finish_intro()
		get_viewport().set_input_as_handled()


func _team_column(caption: String, parent: Node, color: Color) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var header := Label.new()
	header.text = caption
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", color)
	column.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	if parent != null:
		for child in parent.get_children():
			if not (child is TacticsPawn):
				continue
			var frame := PanelContainer.new()
			frame.custom_minimum_size = Vector2(PORTRAIT_PX + 6.0, PORTRAIT_PX + 6.0)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.02, 0.03, 0.08, 1.0)
			style.border_color = color
			style.set_border_width_all(2)
			style.set_corner_radius_all(3)
			frame.add_theme_stylebox_override("panel", style)
			var portrait := TextureRect.new()
			portrait.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			portrait.texture = PortraitLibrary.texture_for(PortraitLibrary.slug_for_pawn(child), "Determined")
			frame.add_child(portrait)
			grid.add_child(frame)
	return column


func _on_event(event: Dictionary) -> void:
	var kind: String = String(event.get("kind", ""))
	if kind == "weather_started":
		show_notice(BattleWeatherService.start_message(String(event.get("condition_id", ""))))
	elif kind == "field_condition_applied" and String(event.get("scope", "")) == "field":
		var condition: String = String(event.get("condition_id", ""))
		show_notice(BattleWeatherService.terrain_start_message(condition) if BattleWeatherService.is_terrain(condition) else "%s took effect!" % condition.capitalize())
