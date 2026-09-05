class_name BattleMessageLog
extends CanvasLayer

const MAX_VISIBLE: int = 60
const HISTORY_LIMIT: int = 300
const FONT_SIZE: int = 24
const FLASH_TIME: float = 0.8
const DOCK_SIZE: Vector2 = Vector2(640, 236)

var history: Array[String] = []
var weather_text: String = ""
var _dock: PanelContainer = null
var _scroll: ScrollContainer = null
var _lines: VBoxContainer = null
var _count_label: Label = null
var _entries: Array[Dictionary] = []


func _init() -> void:
	name = "BattleMessageLog"
	layer = 20


func _ready() -> void:
	_dock = PanelContainer.new()
	_dock.name = "LogDock"
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_dock.offset_left = 16
	_dock.offset_top = -DOCK_SIZE.y - 16
	_dock.offset_right = 16 + DOCK_SIZE.x
	_dock.offset_bottom = -16
	_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dock.add_theme_stylebox_override("panel", PmdStyle.window(PmdStyle.NAVY, PmdStyle.FRAME, 3, 6))
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dock)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var title := Label.new()
	title.name = "LogTitle"
	title.text = "Battle Log"
	PmdStyle.apply_title(title, 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	_count_label = Label.new()
	_count_label.name = "LogCount"
	_count_label.add_theme_font_size_override("font_size", 24)
	_count_label.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_count_label)
	_scroll = ScrollContainer.new()
	_scroll.name = "LogScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_scroll)
	_lines = VBoxContainer.new()
	_lines.name = "Lines"
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", 0)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_lines)


func setup(battle_log: BattleLog) -> void:
	if battle_log != null and not battle_log.event_appended.is_connected(_on_event):
		battle_log.event_appended.connect(_on_event)


func _on_event(event: Dictionary) -> void:
	for text in BattleMessageCatalog.messages_for(event):
		add_message(text)


func add_message(text: String) -> void:
	history.append(text)
	if history.size() > HISTORY_LIMIT:
		history.pop_front()
	if _lines == null:
		return
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = DOCK_SIZE.x - 40
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", PmdStyle.CURSOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.add_child(label)
	_entries.append({"node": label, "age": 0.0})
	while _entries.size() > MAX_VISIBLE:
		var oldest: Dictionary = _entries.pop_front()
		(oldest["node"] as Node).queue_free()
	_count_label.text = str(history.size())
	_scroll_to_end.call_deferred()


func _scroll_to_end() -> void:
	if _scroll == null:
		return
	await get_tree().process_frame
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func set_weather_line(text: String) -> void:
	weather_text = text


func recent(count: int = 5) -> Array[String]:
	var out: Array[String] = []
	for i in range(maxi(0, history.size() - count), history.size()):
		out.append(history[i])
	return out


func _process(delta: float) -> void:
	for entry in _entries:
		var age: float = float(entry["age"]) + delta
		entry["age"] = age
		if age <= FLASH_TIME:
			var node: Label = entry["node"]
			node.add_theme_color_override("font_color", PmdStyle.CURSOR.lerp(PmdStyle.TEXT, age / FLASH_TIME))
		elif age <= FLASH_TIME + delta:
			(entry["node"] as Label).add_theme_color_override("font_color", PmdStyle.TEXT)
