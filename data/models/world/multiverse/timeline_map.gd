class_name TimelineMap
extends CanvasLayer

const LAYER_INDEX: int = 22
const CELL_SIZE: Vector2 = Vector2(96, 60)

var level: TacticsLevel = null
var _root: Control = null
var _panel: PanelContainer = null
var _grid: GridContainer = null
var _title: Label = null


func _ready() -> void:
	name = "TimelineMap"
	layer = LAYER_INDEX
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "TimelinePanel"
	_panel.add_theme_stylebox_override("panel", PmdStyle.window())
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_title = Label.new()
	_title.name = "Title"
	PmdStyle.apply_heading(_title, 30)
	column.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(880, 420)
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)
	var hint := Label.new()
	hint.text = "Rows are timelines, columns are turns. Outlined boards are the latest of their timeline; the present column is marked."
	hint.add_theme_color_override("font_color", PmdStyle.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 880
	column.add_child(hint)
	visible = false


func setup(battle_level: TacticsLevel) -> void:
	level = battle_level


func _look_at(coords: Vector2i) -> void:
	if level == null or level.multiverse == null:
		return
	if level.multiverse.browse_board(coords):
		SoundPlayer.cue("ui.confirm")
		visible = false


func toggle() -> void:
	if visible:
		visible = false
		return
	refresh()
	visible = true


func refresh() -> void:
	if level == null or level.multiverse == null:
		return
	var state: MultiverseState = level.multiverse.state
	for child in _grid.get_children():
		child.queue_free()
	var ids: Array[int] = state.timeline_ids()
	ids.sort_custom(func(a: int, b: int) -> bool: return a > b)
	var max_turn: int = maxi(state.max_turn(), 1)
	var now: int = state.present()
	_grid.columns = max_turn + 1
	var viewing: Vector2i = level.multiverse.viewing()
	_title.text = "Timelines: %d   Present: T%d   In play: %s" % [ids.size(), now, level.multiverse.board_label()]
	if level.multiverse.browsing:
		_title.text += "   Viewing: %s T%d" % [MultiverseState.label(viewing.x), viewing.y]
	var corner := Label.new()
	corner.custom_minimum_size = CELL_SIZE
	_grid.add_child(corner)
	for t in range(1, max_turn + 1):
		var header := Label.new()
		header.text = "T%d%s" % [t, "  present" if t == now else ""]
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.custom_minimum_size = CELL_SIZE
		header.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD if t == now else PmdStyle.TEXT_DIM)
		_grid.add_child(header)
	for l in ids:
		var row_label := Label.new()
		row_label.text = "%s%s" % [MultiverseState.label(l), "" if state.is_active(l) else "  frozen"]
		row_label.custom_minimum_size = CELL_SIZE
		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_label.add_theme_color_override("font_color", PmdStyle.TEXT if state.is_active(l) else PmdStyle.TEXT_DIM)
		_grid.add_child(row_label)
		var first: int = state.first_turn(l)
		var latest: BoardSnapshot = state.latest(l)
		for t in range(1, max_turn + 1):
			var board: BoardSnapshot = state.board(l, t)
			var cell := Button.new()
			cell.name = "Board_L%d_T%d" % [l, t]
			cell.custom_minimum_size = CELL_SIZE
			cell.add_to_group(UiSoundHook.OPT_OUT_GROUP)
			if board == null:
				cell.text = "" if t < first else "·"
				cell.disabled = true
				cell.flat = true
			else:
				cell.text = "P %d\nE %d" % [board.standing(0), board.standing(1)]
				cell.flat = board != latest
				if not state.is_active(l):
					cell.modulate = Color(0.6, 0.6, 0.6, 1.0)
				if board.coords() == state.focus:
					cell.add_theme_color_override("font_color", PmdStyle.TEXT_GOLD)
				elif board.coords() == viewing and level.multiverse.browsing:
					cell.add_theme_color_override("font_color", PmdStyle.CURSOR)
				cell.tooltip_text = "%s T%d%s%s. Click to look at this board." % [MultiverseState.label(l), t, ", latest" if board == latest else ", past", ", in play" if board.coords() == state.focus else ""]
				var coords: Vector2i = board.coords()
				cell.pressed.connect(func() -> void: _look_at(coords))
			_grid.add_child(cell)
