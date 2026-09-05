class_name BattleHud
extends CanvasLayer

const QUEUE_TILE: float = 64.0
const ACTIVE_TILE: float = 80.0
const PANEL_WIDTH: float = 440.0
const PANEL_HEIGHT: float = 196.0
const ARROW_PX: float = 20.0
const TILE_HP_PX: float = 6.0
const TILE_HOLDER_HEIGHT: float = ACTIVE_TILE + 8.0 + 1.0 + TILE_HP_PX + 1.0 + ARROW_PX
const PORTRAIT_PX: float = 96.0
const STATUS_DOCK_HEIGHT: float = 104.0
const QUEUE_LENGTH: int = 8
const MOOD_SECONDS: float = 1.6
const LOW_HP_FRACTION: float = 0.25
const ARROW_SHEET: String = "res://assets/visuals/raw_asset/Icon/Arrow_Down_Yellow.None.png"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"
const BASELINE_STATUS_MOODS: Dictionary = {"sleep": "Sigh", "confuse": "Dizzy", "freeze": "Stunned", "paralyze": "Worried", "burn": "Worried", "poison": "Worried", "toxic": "Worried", "in_love": "Joyous"}

var level: TacticsLevel = null
var round_index: int = 0
var weather_text: String = ""
var _root: Control = null
var _queue_row: HBoxContainer = null
var _round_label: Label = null
var _weather_chip: PanelContainer = null
var _weather_label: Label = null
var _tiles: Dictionary = {}
var _tile_order: Array[TacticsPawn] = []
var _moods: Dictionary = {}
var _move_cache: Dictionary = {}
var _active_panel: PanelContainer = null
var _active_portrait: TextureRect = null
var _active_frame: PanelContainer = null
var _active_name: Label = null
var _active_meta: Label = null
var _active_hp: PmdHpBar = null
var _active_detail: Label = null
var _active_statuses: HBoxContainer = null
var _active_item_icon: TextureRect = null
var _active_pawn: TacticsPawn = null
var _target_panel: PanelContainer = null
var _target_portrait: TextureRect = null
var _target_frame: PanelContainer = null
var _target_name: Label = null
var _target_hp: PmdHpBar = null
var _target_hint: Label = null
var _target_meta: Label = null
var _target_statuses: HBoxContainer = null
var _target_pawn: TacticsPawn = null
var _queue_strip: PanelContainer = null
var _queue_column: VBoxContainer = null
var _status_dock: PanelContainer = null
var _status_rows: VBoxContainer = null
var _status_signature: String = ""
var _status_toggle: Button = null
var _status_header: HBoxContainer = null
var status_minimized: bool = false
var _scheduler_connected: bool = false


func _init() -> void:
	name = "BattleHud"
	layer = 18


func setup(battle_level: TacticsLevel) -> void:
	level = battle_level
	if _root == null:
		_build()
	_connect_scheduler()
	if level.battle_log != null and not level.battle_log.event_appended.is_connected(_on_event):
		level.battle_log.event_appended.connect(_on_event)
	rebuild_queue()


func _connect_scheduler() -> void:
	if _scheduler_connected or level == null or level.scheduler == null:
		return
	level.scheduler.turn_started.connect(_on_turn_started)
	level.scheduler.turn_completed.connect(func(_unit: BattleUnit) -> void: rebuild_queue())
	level.scheduler.round_started.connect(_on_round_started)
	level.scheduler.battle_ended.connect(rebuild_queue)
	_scheduler_connected = true
	var active: BattleUnit = level.scheduler.get_active_unit()
	if active != null and active.pawn != null:
		_active_pawn = active.pawn
		if round_index == 0:
			round_index = 1
	rebuild_queue()
	refresh_active_panel()


func _build() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_queue_bar()
	_build_active_panel()
	_build_target_panel()
	_build_weather_chip()
	_build_status_dock()


func _build_queue_bar() -> void:
	_queue_column = VBoxContainer.new()
	_queue_column.name = "QueueColumn"
	_queue_column.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_queue_column.anchor_left = 0.5
	_queue_column.anchor_right = 0.5
	_queue_column.offset_top = 16
	_queue_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_queue_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	_queue_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_queue_column.add_theme_constant_override("separation", 6)
	_root.add_child(_queue_column)
	_queue_strip = PanelContainer.new()
	_queue_strip.name = "QueueStrip"
	var strip_style: StyleBoxFlat = PmdStyle.window()
	_queue_strip.add_theme_stylebox_override("panel", strip_style)
	_queue_strip.custom_minimum_size = Vector2(0, TILE_HOLDER_HEIGHT + strip_style.get_margin(SIDE_TOP) + strip_style.get_margin(SIDE_BOTTOM))
	_queue_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_queue_column.add_child(_queue_strip)
	var inner := MarginContainer.new()
	inner.name = "Inner"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_queue_strip.add_child(inner)
	_queue_row = HBoxContainer.new()
	_queue_row.name = "QueueRow"
	_queue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_queue_row.add_theme_constant_override("separation", 6)
	_queue_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_queue_row)
	_round_label = Label.new()
	_round_label.name = "RoundLabel"
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_round_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_round_label.add_theme_font_size_override("font_size", 24)
	_round_label.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD)
	_round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_round_label)


func _build_active_panel() -> void:
	_active_panel = PanelContainer.new()
	_active_panel.name = "ActivePanel"
	_active_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_active_panel.offset_left = 16
	_active_panel.offset_top = 16
	_active_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_active_panel.add_theme_stylebox_override("panel", PmdStyle.window())
	_active_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_active_panel)
	var parts: Dictionary = _build_unit_panel_content(_active_panel, false)
	_active_frame = parts["frame"]
	_active_portrait = parts["portrait"]
	_active_name = parts["name"]
	_active_hp = parts["hp"]
	_active_meta = parts["meta"]
	_active_item_icon = parts["item_icon"]
	_active_detail = parts["detail"]
	_active_statuses = parts["statuses"]
	_active_name.name = "ActiveName"
	_active_hp.name = "ActiveHp"
	_active_meta.name = "ActiveMeta"
	_active_item_icon.name = "ActiveItemIcon"
	_active_detail.name = "ActiveDetail"
	_active_statuses.name = "ActiveStatuses"
	_active_panel.visible = false


func _build_target_panel() -> void:
	_target_panel = PanelContainer.new()
	_target_panel.name = "TargetPanel"
	_target_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_target_panel.offset_right = -16
	_target_panel.offset_top = 16
	_target_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_target_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_target_panel.add_theme_stylebox_override("panel", PmdStyle.window(PmdStyle.NAVY, PmdStyle.CURSOR, 3, 6))
	_target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_target_panel)
	var parts: Dictionary = _build_unit_panel_content(_target_panel, true)
	_target_frame = parts["frame"]
	_target_portrait = parts["portrait"]
	_target_name = parts["name"]
	_target_hp = parts["hp"]
	_target_meta = parts["meta"]
	_target_hint = parts["detail"]
	_target_statuses = parts["statuses"]
	(parts["item_icon"] as TextureRect).visible = false
	_target_name.name = "TargetName"
	_target_hp.name = "TargetHp"
	_target_meta.name = "TargetMeta"
	_target_hint.name = "TargetHint"
	_target_statuses.name = "TargetStatuses"
	_target_panel.visible = false


func _build_unit_panel_content(panel: PanelContainer, mirrored: bool) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var frame: PanelContainer = _portrait_frame(PORTRAIT_PX)
	var portrait: TextureRect = frame.get_node("Portrait") as TextureRect
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mirrored:
		row.add_child(column)
		row.add_child(frame)
	else:
		row.add_child(frame)
		row.add_child(column)
	var align: int = HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	var name_label := Label.new()
	name_label.horizontal_alignment = align
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	var hp := PmdHpBar.new()
	hp.custom_minimum_size = Vector2(300, 22)
	hp.size_flags_horizontal = Control.SIZE_SHRINK_END if mirrored else Control.SIZE_FILL
	column.add_child(hp)
	var meta := Label.new()
	meta.horizontal_alignment = align
	meta.add_theme_font_size_override("font_size", 24)
	meta.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(meta)
	var detail_row := HBoxContainer.new()
	detail_row.alignment = BoxContainer.ALIGNMENT_END if mirrored else BoxContainer.ALIGNMENT_BEGIN
	detail_row.add_theme_constant_override("separation", 6)
	detail_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(detail_row)
	var item_icon := TextureRect.new()
	item_icon.custom_minimum_size = Vector2(28, 28)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.visible = false
	detail_row.add_child(item_icon)
	var detail := Label.new()
	detail.horizontal_alignment = align
	detail.add_theme_font_size_override("font_size", 24)
	detail.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_row.add_child(detail)
	var statuses := HBoxContainer.new()
	statuses.alignment = BoxContainer.ALIGNMENT_END if mirrored else BoxContainer.ALIGNMENT_BEGIN
	statuses.add_theme_constant_override("separation", 4)
	statuses.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(statuses)
	return {"frame": frame, "portrait": portrait, "name": name_label, "hp": hp, "meta": meta, "item_icon": item_icon, "detail": detail, "statuses": statuses}


func _build_weather_chip() -> void:
	_weather_chip = PanelContainer.new()
	_weather_chip.name = "WeatherChip"
	_weather_chip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_weather_chip.anchor_left = 0.5
	_weather_chip.anchor_right = 0.5
	_weather_chip.offset_top = 160
	_weather_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_weather_chip.add_theme_stylebox_override("panel", PmdStyle.chip(PmdStyle.NAVY_DEEP, PmdStyle.FRAME))
	_weather_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_weather_chip)
	_weather_label = Label.new()
	_weather_label.name = "WeatherLabel"
	_weather_label.add_theme_font_size_override("font_size", 24)
	_weather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_chip.add_child(_weather_label)
	_weather_chip.visible = false


func _build_status_dock() -> void:
	_status_dock = PanelContainer.new()
	_status_dock.name = "StatusDock"
	_status_dock.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status_dock.offset_left = 16
	_status_dock.offset_right = 16 + BattleMessageLog.DOCK_SIZE.x
	_status_dock.offset_bottom = -BattleMessageLog.DOCK_SIZE.y - 24
	_status_dock.offset_top = _status_dock.offset_bottom - STATUS_DOCK_HEIGHT
	_status_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status_dock.add_theme_stylebox_override("panel", PmdStyle.window(PmdStyle.NAVY_DEEP, PmdStyle.FRAME_SOFT, 2, 6))
	_status_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_status_dock)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_dock.add_child(column)
	_status_header = HBoxContainer.new()
	_status_header.name = "StatusHeader"
	_status_header.add_theme_constant_override("separation", 8)
	_status_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_status_header)
	var title := Label.new()
	title.name = "StatusTitle"
	title.text = "Status"
	PmdStyle.apply_heading(title, 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_header.add_child(title)
	_status_toggle = PmdStyle.dock_toggle_button(false)
	_status_toggle.pressed.connect(func() -> void: set_status_minimized(not status_minimized))
	_status_header.add_child(_status_toggle)
	TacticsConfig.register_hover_control(_status_toggle)
	_status_rows = VBoxContainer.new()
	_status_rows.name = "StatusRows"
	_status_rows.add_theme_constant_override("separation", 2)
	_status_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_status_rows)
	_refresh_status_dock(true)


func set_status_minimized(value: bool) -> void:
	status_minimized = value
	_status_rows.visible = not value
	_status_toggle.text = "+" if value else "-"
	_place_status_dock()


func _place_status_dock() -> void:
	if _status_dock == null:
		return
	var log_top: float = -BattleMessageLog.DOCK_SIZE.y - 16.0
	if level != null and level.message_log != null:
		log_top = level.message_log.dock_top()
	var style: StyleBox = _status_dock.get_theme_stylebox("panel")
	var margins: float = style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM) if style != null else 0.0
	var height: float = STATUS_DOCK_HEIGHT if not status_minimized else maxf(_status_header.size.y, 30.0) + margins
	var bottom: float = log_top - 8.0
	if not is_equal_approx(_status_dock.offset_bottom, bottom) or not is_equal_approx(_status_dock.offset_top, bottom - height):
		_status_dock.offset_bottom = bottom
		_status_dock.offset_top = bottom - height


func status_dock_lines() -> Array[String]:
	var out: Array[String] = []
	if _status_rows == null:
		return out
	for child in _status_rows.get_children():
		var label: Label = child.find_child("StatusText", true, false) as Label if child is Control and not (child is Label) else child as Label
		if label != null:
			out.append(label.text)
	return out


func _status_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if level == null:
		return entries
	var weather: String = level.effective_weather()
	if not weather.is_empty():
		var rounds: int = 0
		var stored: Variant = level.battle_conditions.get(weather, null)
		if stored is Dictionary:
			rounds = int((stored as Dictionary).get("counter", 0))
		entries.append({"icon": "", "text": "%s%s" % [BattleWeatherService.label(weather), " (%d)" % rounds if rounds > 0 else ""], "color": PmdStyle.TEXT})
	for key in level.battle_conditions.keys():
		var condition: String = String(key)
		if condition == weather or BattleWeatherService.is_weather(condition):
			continue
		var stored: Variant = level.battle_conditions[key]
		var rounds: int = int((stored as Dictionary).get("counter", 0)) if stored is Dictionary else 0
		entries.append({"icon": "", "text": "%s%s" % [condition.capitalize(), " (%d)" % rounds if rounds > 0 else ""], "color": PmdStyle.TEXT_DIM})
	var pawn: TacticsPawn = _active_pawn
	if pawn != null and is_instance_valid(pawn) and pawn.stats != null and pawn.is_alive():
		for status_id in pawn.stats.battle_statuses.keys():
			var id: String = String(status_id)
			if StatusBadgeRow.HIDDEN.has(id):
				continue
			var payload: Variant = pawn.stats.battle_statuses[status_id]
			var turns: int = 0
			if payload is Dictionary:
				for turn_key in ["turns", "turns_left", "counter", "duration"]:
					if (payload as Dictionary).has(turn_key):
						turns = int((payload as Dictionary)[turn_key])
						break
			entries.append({"icon": id, "text": "%s: %s%s" % [level.notation.unit_name(pawn), BattleMessageCatalog._status_label(id), " (%d)" % turns if turns > 0 else ""], "color": PmdStyle.TEXT})
	return entries


func _refresh_status_dock(force: bool = false) -> void:
	if _status_rows == null:
		return
	var entries: Array[Dictionary] = _status_entries()
	var parts: PackedStringArray = []
	for entry in entries:
		parts.append(String(entry["text"]))
	var signature: String = "|".join(parts)
	if signature == _status_signature and not force:
		return
	_status_signature = signature
	for child in _status_rows.get_children():
		_status_rows.remove_child(child)
		child.queue_free()
	if entries.is_empty():
		var empty := Label.new()
		empty.name = "StatusText"
		empty.text = "No status effects"
		empty.add_theme_font_size_override("font_size", 24)
		empty.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_status_rows.add_child(empty)
		return
	for entry in entries.slice(0, 3):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_id: String = String(entry.get("icon", ""))
		if not icon_id.is_empty() and StatusBadgeRow.EMOTICONS.has(icon_id):
			var icon := EmoticonIcon.new()
			if icon.set_status(icon_id, 24.0):
				row.add_child(icon)
			else:
				icon.free()
		var label := Label.new()
		label.name = "StatusText"
		label.text = String(entry["text"])
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", entry.get("color", PmdStyle.TEXT))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		_status_rows.add_child(row)


func _portrait_frame(px: float) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.custom_minimum_size = Vector2(px + 8.0, px + 8.0)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _frame_style(PmdStyle.FRAME_SOFT))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(px, px)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	return frame


func _frame_style(color: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.08, 1.0)
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _on_round_started() -> void:
	round_index += 1
	rebuild_queue()


func _on_turn_started(unit: BattleUnit) -> void:
	if unit != null and unit.pawn != null:
		_active_pawn = unit.pawn
	rebuild_queue()
	refresh_active_panel()


func queue_pawns() -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	if level == null or level.scheduler == null:
		return out
	var active: BattleUnit = level.scheduler.get_active_unit()
	if active != null and active.pawn != null and active.pawn.is_alive():
		out.append(active.pawn)
	for unit in level.scheduler.peek_upcoming(QUEUE_LENGTH):
		if unit.pawn != null and unit.pawn.is_alive() and not out.has(unit.pawn):
			out.append(unit.pawn)
	var predicted: Array[BattleUnit] = []
	for unit in level.battle_units:
		if unit.pawn != null and unit.pawn.is_alive() and not out.has(unit.pawn):
			predicted.append(unit)
	predicted.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.speed() > b.speed() if a.speed() != b.speed() else a.insertion_order < b.insertion_order)
	for unit in predicted:
		if out.size() >= QUEUE_LENGTH:
			break
		out.append(unit.pawn)
	return out


func rebuild_queue() -> void:
	if _queue_row == null or level == null:
		return
	var pawns: Array[TacticsPawn] = queue_pawns()
	var upcoming_count: int = 1 + (level.scheduler.peek_upcoming(QUEUE_LENGTH).size() if level.scheduler != null else 0)
	for child in _queue_row.get_children():
		child.queue_free()
	_tiles.clear()
	_tile_order = pawns
	for i in range(pawns.size()):
		if i == upcoming_count and i > 0:
			var divider := Label.new()
			divider.text = "|"
			divider.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
			divider.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_queue_row.add_child(divider)
		_queue_row.add_child(_make_tile(pawns[i], i == 0))
	_round_label.text = "Turn %d" % maxi(1, round_index)
	_round_label.visible = pawns.size() > 0
	(_queue_row.get_parent() as Control).visible = pawns.size() > 0
	_refresh_tiles(true)


func _make_tile(pawn: TacticsPawn, active: bool) -> Control:
	var px: float = ACTIVE_TILE if active else QUEUE_TILE
	var holder := VBoxContainer.new()
	holder.name = "Tile_%s" % pawn.name
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.custom_minimum_size = Vector2(0, TILE_HOLDER_HEIGHT)
	holder.add_theme_constant_override("separation", 1)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if active:
		var arrow := EmoticonIcon.new()
		arrow.set_sheet(ARROW_SHEET, ARROW_PX)
		arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.add_child(arrow)
	var frame := _portrait_frame(px)
	var team: int = pawn.stats.pokemon_instance.team if pawn.stats != null and pawn.stats.pokemon_instance != null else 0
	frame.add_theme_stylebox_override("panel", _frame_style(PmdStyle.CURSOR if active else PmdStyle.team_color(team), 3 if active else 2))
	holder.add_child(frame)
	var hp := PmdHpBar.new()
	hp.show_text = false
	hp.custom_minimum_size = Vector2(px + 8.0, TILE_HP_PX)
	hp.set_values(pawn.stats.curr_health, pawn.stats.max_health)
	holder.add_child(hp)
	_tiles[pawn] = {"node": holder, "portrait": frame.get_node("Portrait"), "hp": hp, "expression": "", "team": team}
	return holder


func set_mood(pawn: TacticsPawn, expression: String, seconds: float = MOOD_SECONDS) -> void:
	if pawn == null:
		return
	_moods[pawn] = {"expression": expression, "until": Time.get_ticks_msec() + int(seconds * 1000.0)}


func mood_for(pawn: TacticsPawn) -> String:
	var mood: Dictionary = _moods.get(pawn, {})
	if mood.is_empty() or Time.get_ticks_msec() > int(mood.get("until", 0)):
		return ""
	return String(mood.get("expression", ""))


func expression_for(pawn: TacticsPawn) -> String:
	if pawn == null or not is_instance_valid(pawn) or pawn.stats == null:
		return PortraitLibrary.NORMAL
	if not pawn.is_alive():
		return "Crying"
	var mood: String = mood_for(pawn)
	if not mood.is_empty():
		return mood
	for status_id in BASELINE_STATUS_MOODS:
		if pawn.stats.battle_statuses.has(status_id):
			return String(BASELINE_STATUS_MOODS[status_id])
	if float(pawn.stats.curr_health) <= float(pawn.stats.max_health) * LOW_HP_FRACTION:
		return "Worried"
	if pawn == _active_pawn:
		return "Determined"
	return PortraitLibrary.NORMAL


func _refresh_tiles(force: bool = false) -> void:
	for pawn in _tiles:
		if not is_instance_valid(pawn):
			continue
		var tile: Dictionary = _tiles[pawn]
		var expression: String = expression_for(pawn)
		if force or expression != String(tile["expression"]):
			tile["expression"] = expression
			(tile["portrait"] as TextureRect).texture = PortraitLibrary.texture_for(PortraitLibrary.slug_for_pawn(pawn), expression)
		if pawn.stats != null:
			(tile["hp"] as PmdHpBar).set_values(pawn.stats.curr_health, pawn.stats.max_health)


func refresh_active_panel() -> void:
	var pawn: TacticsPawn = _active_pawn
	if pawn == null or not is_instance_valid(pawn) or pawn.stats == null or not pawn.is_alive():
		_active_panel.visible = false
		return
	_active_panel.visible = true
	var stats: Stats = pawn.stats
	var team: int = stats.pokemon_instance.team if stats.pokemon_instance != null else 0
	_active_frame.add_theme_stylebox_override("panel", _frame_style(PmdStyle.team_color(team), 3))
	_active_portrait.texture = PortraitLibrary.texture_for(PortraitLibrary.slug_for_pawn(pawn), expression_for(pawn))
	_active_name.text = "%s  Lv %d" % [level.notation.unit_name(pawn), stats.level]
	_active_name.add_theme_color_override("font_color", PmdStyle.team_color(team))
	_active_hp.set_values(stats.curr_health, stats.max_health)
	_active_meta.text = _meta_text(stats)
	var item: PokemonItemResource = PokemonItemService.held_item_for(stats)
	if item != null:
		_active_detail.text = item.display_name()
		var icon_path: String = String(item.icon_path)
		_active_item_icon.visible = not icon_path.is_empty() and ResourceLoader.exists(icon_path)
		if _active_item_icon.visible:
			_active_item_icon.texture = load(icon_path) as Texture2D
	else:
		_active_detail.text = "No held item"
		_active_item_icon.visible = false
	_fill_status_icons(_active_statuses, stats)


func _meta_text(stats: Stats) -> String:
	var types: Array[String] = []
	for type_id in stats.types:
		types.append(String(type_id).capitalize())
	var ability: String = ""
	var natural: Array[String] = BattleIntrinsicService.natural_slugs_static(stats)
	if stats.pokemon_instance != null and not String(stats.pokemon_instance.ability_override).is_empty():
		ability = String(stats.pokemon_instance.ability_override)
	elif not natural.is_empty():
		ability = natural[0]
	return "%s  |  %s" % [" / ".join(types), ability.capitalize()]


func _fill_status_icons(container: HBoxContainer, stats: Stats) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for status_id in stats.battle_statuses:
		if StatusBadgeRow.EMOTICONS.has(String(status_id)):
			var icon := EmoticonIcon.new()
			if icon.set_status(String(status_id), 28.0):
				container.add_child(icon)
			else:
				icon.free()


func _refresh_target_panel() -> void:
	if level == null or level.participant == null or level.participant.res == null:
		return
	var res: TacticsParticipantResource = level.participant.res
	var stage: int = res.stage
	var target: TacticsPawn = res.attackable_pawn
	var targeting: bool = stage in [res.STAGE_DISPLAY_TARGETS, res.STAGE_SELECT_ATTACK_TARGET, res.STAGE_ATTACK, res.STAGE_SELECT_THROW_TARGET, res.STAGE_ITEM_ACTION]
	if not targeting and _is_cpu_turn(res.curr_pawn) and stage in [res.STAGE_SELECT_LOCATION, res.STAGE_MOVE_PAWN]:
		targeting = true
	if not targeting or target == null or not is_instance_valid(target) or target.stats == null or target == res.curr_pawn:
		_target_panel.visible = false
		_target_pawn = null
		return
	_target_panel.visible = true
	_target_pawn = target
	var team: int = target.stats.pokemon_instance.team if target.stats.pokemon_instance != null else 0
	_target_frame.add_theme_stylebox_override("panel", _frame_style(PmdStyle.team_color(team), 3))
	var mood: String = mood_for(target)
	_target_portrait.texture = PortraitLibrary.texture_for(PortraitLibrary.slug_for_pawn(target), mood if not mood.is_empty() else "Worried")
	_target_name.text = "%s  Lv %d" % [level.notation.unit_name(target), target.stats.level]
	_target_name.add_theme_color_override("font_color", PmdStyle.team_color(team))
	_target_hp.set_values(target.stats.curr_health, target.stats.max_health)
	_target_meta.text = _meta_text(target.stats)
	_target_hint.text = _effectiveness_hint(res.curr_pawn, target)
	_fill_status_icons(_target_statuses, target.stats)


func _is_cpu_turn(pawn: Variant) -> bool:
	if pawn == null or not is_instance_valid(pawn) or not (pawn is TacticsPawn) or pawn.stats == null or pawn.stats.pokemon_instance == null:
		return false
	return pawn.stats.pokemon_instance.control_type != PokemonInstanceResource.ControlType.PLAYER


func _effectiveness_hint(attacker: TacticsPawn, target: TacticsPawn) -> String:
	if attacker == null or attacker.stats == null or attacker.res == null:
		return ""
	var index: int = attacker.res.selected_move_index
	if index < 0 or index >= attacker.stats.move_slots.size():
		return ""
	var move: PokemonMoveResource = attacker.stats.move_slots[index]
	if move == null or not move.is_damaging():
		return move.display_name() if move != null else ""
	var chart: TypeChartResource = level.get_type_chart()
	var type_a: String = target.stats.types[0] if target.stats.types.size() > 0 else "none"
	var type_b: String = target.stats.types[1] if target.stats.types.size() > 1 else "none"
	var multiplier: float = chart.get_effectiveness_dual(move.type, type_a, type_b) if chart != null else 1.0
	var verdict: String = "Effective"
	var color: Color = PmdStyle.TEXT
	if multiplier <= 0.0:
		verdict = "No effect"
		color = PmdStyle.TEXT_DIM
	elif multiplier > 1.0:
		verdict = "Super effective!"
		color = PmdStyle.HP_HIGH
	elif multiplier < 1.0:
		verdict = "Not very effective"
		color = PmdStyle.HP_LOW
	_target_hint.add_theme_color_override("font_color", color)
	var estimate: String = _damage_estimate(attacker, target, move, multiplier)
	if estimate.is_empty():
		return "%s: %s" % [move.display_name(), verdict]
	return "%s: %s\n%s" % [move.display_name(), verdict, estimate]


func _damage_estimate(attacker: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource, multiplier: float) -> String:
	if multiplier <= 0.0 or target.stats == null or attacker.stats == null:
		return ""
	var stab: bool = attacker.stats.types.has(move.type)
	var resolver := DamageResolver.new()
	var full: int = resolver.calculate_damage(attacker.stats, target.stats, move, multiplier, stab, 1.0, null, {}, true)
	if full <= 0:
		return ""
	var low: int = maxi(1, int(floor(float(full) * 0.85)))
	var max_hp: int = maxi(1, target.stats.max_health)
	var low_pct: int = int(round(100.0 * float(low) / float(max_hp)))
	var high_pct: int = int(round(100.0 * float(full) / float(max_hp)))
	var suffix: String = "  KO range" if low >= target.stats.curr_health else ("  may KO" if full >= target.stats.curr_health else "")
	return "%d-%d dmg (%d-%d%%)%s" % [low, full, low_pct, high_pct, suffix]


func _move_is_damaging(move_id: String) -> bool:
	if move_id.is_empty():
		return false
	if not _move_cache.has(move_id):
		var path: String = "%s%s.tres" % [GENERATED_MOVES_DIR, move_id]
		var move: PokemonMoveResource = load(path) as PokemonMoveResource if ResourceLoader.exists(path) else null
		_move_cache[move_id] = move != null and move.is_damaging()
	return bool(_move_cache[move_id])


func _pawn_in(event: Dictionary, keys: Array) -> TacticsPawn:
	for key in keys:
		var value: Variant = event.get(key, null)
		if value is TacticsPawn:
			return value
	return null


func _on_event(event: Dictionary) -> void:
	var kind: String = String(event.get("kind", ""))
	match kind:
		"move_used":
			set_mood(_pawn_in(event, ["attacker", "unit"]), "Angry" if _move_is_damaging(String(event.get("move_id", ""))) else "Determined")
		"damage_dealt":
			set_mood(_pawn_in(event, ["defender", "unit"]), "Shouting" if bool(event.get("critical", false)) else "Pain")
		"miss":
			set_mood(_pawn_in(event, ["defender", "target"]), "Happy", 1.2)
			set_mood(_pawn_in(event, ["attacker", "unit"]), "Surprised", 1.2)
		"healed":
			set_mood(_pawn_in(event, ["unit", "defender"]), "Happy")
		"status_applied":
			set_mood(_pawn_in(event, ["unit", "defender"]), "Worried")
		"status_removed":
			set_mood(_pawn_in(event, ["unit"]), "Happy", 1.0)
		"stat_stage_changed":
			set_mood(_pawn_in(event, ["unit", "defender"]), "Inspired" if int(event.get("delta", 0)) > 0 else "Sad")
		"unit_fainted":
			set_mood(_pawn_in(event, ["unit", "defender"]), "Crying", 600.0)
		"held_item_triggered", "held_item_consumed":
			set_mood(_pawn_in(event, ["unit"]), "Joyous")
		"intrinsic_triggered":
			set_mood(_pawn_in(event, ["unit"]), "Determined", 1.0)
		"move_blocked":
			set_mood(_pawn_in(event, ["unit", "attacker"]), "Surprised", 1.0)
		"turn_skipped":
			set_mood(_pawn_in(event, ["unit"]), "Dizzy", 1.2)
		"weather_started", "weather_tick":
			weather_text = "%s (%d)" % [BattleWeatherService.label(String(event.get("condition_id", ""))), int(event.get("rounds", 0))]
		"weather_ended":
			weather_text = ""
	if kind.begins_with("weather"):
		_weather_label.text = weather_text
		_weather_chip.visible = not weather_text.is_empty()
	if kind == "unit_fainted":
		rebuild_queue()


func _process(_delta: float) -> void:
	if level == null or not is_instance_valid(level):
		return
	if not _scheduler_connected:
		_connect_scheduler()
	_refresh_tiles()
	if _active_pawn != null and is_instance_valid(_active_pawn) and _active_panel.visible:
		_active_hp.set_values(_active_pawn.stats.curr_health, _active_pawn.stats.max_health)
		_active_portrait.texture = PortraitLibrary.texture_for(PortraitLibrary.slug_for_pawn(_active_pawn), expression_for(_active_pawn))
	_refresh_target_panel()
	_sync_panel_heights()
	_refresh_status_dock()
	_place_status_dock()


func _sync_panel_heights() -> void:
	_apply_layout(_root.size)
	var chip_top: float = _queue_column.offset_top + _queue_strip.size.y + 8.0
	if not is_equal_approx(_weather_chip.offset_top, chip_top):
		_weather_chip.offset_top = chip_top


func stacked_layout_for(width: float) -> bool:
	var needed: float = 16.0 + PANEL_WIDTH + 8.0 + maxf(_queue_strip.size.x, 400.0) + 8.0 + PANEL_WIDTH + 16.0
	return width > 0.0 and width < needed


func _apply_layout(size: Vector2) -> void:
	var top: float = 16.0 + PANEL_HEIGHT + 8.0 if stacked_layout_for(size.x) else 16.0
	if not is_equal_approx(_queue_column.offset_top, top):
		_queue_column.offset_top = top
	var dock_width: float = BattleMessageLog.dock_width_for(size.x)
	if not is_equal_approx(_status_dock.offset_right, 16.0 + dock_width):
		_status_dock.offset_right = 16.0 + dock_width
