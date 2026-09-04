class_name BattleMessageLog
extends CanvasLayer

const MAX_VISIBLE: int = 4
const LINE_LIFETIME: float = 4.0
const FADE_TIME: float = 0.6
const HISTORY_LIMIT: int = 300
const FONT_SIZE: int = 36

var history: Array[String] = []
var _lines: VBoxContainer = null
var _weather_label: Label = null
var _entries: Array[Dictionary] = []


func _init() -> void:
	name = "BattleMessageLog"
	layer = 20


func _ready() -> void:
	var anchor := Control.new()
	anchor.name = "MessageAnchor"
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.offset_top = -24
	anchor.offset_bottom = -24
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	_lines = VBoxContainer.new()
	_lines.name = "Lines"
	_lines.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lines.anchor_left = 0.36
	_lines.anchor_right = 0.36
	_lines.offset_left = -280
	_lines.offset_right = 280
	_lines.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lines.alignment = BoxContainer.ALIGNMENT_END
	_lines.add_theme_constant_override("separation", 4)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_lines)
	_weather_label = Label.new()
	_weather_label.name = "WeatherLabel"
	_weather_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_weather_label.offset_left = -260
	_weather_label.offset_right = -12
	_weather_label.offset_top = 12
	_weather_label.offset_bottom = 40
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weather_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_weather_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_weather_label.add_theme_constant_override("outline_size", 6)
	_weather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_label.visible = false
	add_child(_weather_label)


func setup(battle_log: BattleLog) -> void:
	if battle_log != null and not battle_log.event_appended.is_connected(_on_event):
		battle_log.event_appended.connect(_on_event)


func _on_event(event: Dictionary) -> void:
	for text in BattleMessageCatalog.messages_for(event):
		add_message(text)
	var kind: String = String(event.get("kind", ""))
	if kind == "weather_started" or kind == "weather_tick":
		set_weather_line("%s (%d)" % [BattleWeatherService.label(String(event.get("condition_id", ""))), int(event.get("rounds", 0))])
	elif kind == "weather_ended":
		set_weather_line("")


func add_message(text: String) -> void:
	history.append(text)
	if history.size() > HISTORY_LIMIT:
		history.pop_front()
	if _lines == null:
		return
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.72)
	style.border_color = Color(0.5, 0.58, 0.55, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	_lines.add_child(panel)
	_entries.append({"node": panel, "age": 0.0})
	while _entries.size() > MAX_VISIBLE:
		var oldest: Dictionary = _entries.pop_front()
		(oldest["node"] as Node).queue_free()


func set_weather_line(text: String) -> void:
	if _weather_label == null:
		return
	_weather_label.text = text
	_weather_label.visible = not text.is_empty()


func recent(count: int = 5) -> Array[String]:
	var out: Array[String] = []
	for i in range(maxi(0, history.size() - count), history.size()):
		out.append(history[i])
	return out


func _process(delta: float) -> void:
	var expired: Array[Dictionary] = []
	for entry in _entries:
		entry["age"] = float(entry["age"]) + delta
		var node: Control = entry["node"]
		var age: float = float(entry["age"])
		if age > LINE_LIFETIME:
			node.modulate.a = clampf(1.0 - (age - LINE_LIFETIME) / FADE_TIME, 0.0, 1.0)
			if age > LINE_LIFETIME + FADE_TIME:
				expired.append(entry)
	for entry in expired:
		_entries.erase(entry)
		(entry["node"] as Node).queue_free()
