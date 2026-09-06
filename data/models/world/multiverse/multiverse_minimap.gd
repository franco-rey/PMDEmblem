class_name MultiverseMinimap
extends Control

const DIAMETER: float = 250.0
const CARD: float = 24.0
const CELL: float = 34.0
const RING: float = 5.0
const MIN_SCALE: float = 0.3
const NEAR_FACTOR: float = 2.5
const COLOR_BACK: Color = Color(0.05, 0.06, 0.14, 0.92)
const COLOR_FIELD: Color = Color(0.72, 0.73, 0.78, 0.28)
const COLOR_PRESENT: Color = Color(0.20, 0.18, 0.30, 0.9)
const COLOR_LABEL: Color = Color(0.10, 0.08, 0.16, 1.0)

var level: TacticsLevel = null
var stage: MultiverseStage = null
var yaw: float = 0.0
var draws: int = 0
var last_cards: Dictionary = {}
var _pulse: float = 0.0
var _content: Control = null
var _frame: Control = null


func _ready() -> void:
	name = "MultiverseMinimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = Vector2(DIAMETER, DIAMETER)
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_content.draw.connect(_draw_mask)
	add_child(_content)
	var field := Control.new()
	field.name = "Field"
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.draw.connect(_draw_field.bind(field))
	_content.add_child(field)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	set_process(true)


func setup(battle_level: TacticsLevel, world_stage: MultiverseStage) -> void:
	level = battle_level
	stage = world_stage


func refresh() -> void:
	queue_redraw()
	for child in _content.get_children():
		child.queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	var camera: TacticsCamera = stage.camera_node() if stage != null else null
	if camera != null and camera.t_pivot != null:
		yaw = camera.t_pivot.rotation.y
	refresh()


func project(slot: Vector3, centre: Vector2, scale: float) -> Vector2:
	var right: Vector2 = Vector2(cos(yaw), -sin(yaw))
	var forward: Vector2 = Vector2(-sin(yaw), -cos(yaw))
	var flat: Vector2 = Vector2(slot.x, slot.z)
	return centre + Vector2(flat.dot(right), -flat.dot(forward)) * scale


func view_centre(state: MultiverseState) -> Vector3:
	var centre: Vector3 = MultiverseStage.slot(state.focus)
	var camera: TacticsCamera = stage.camera_node() if stage != null else null
	if camera != null and camera.is_inside_tree():
		centre += Vector3(camera.global_position.x, 0.0, camera.global_position.z)
	return centre


func fit_scale(state: MultiverseState, ids: Array[int]) -> float:
	var focus: Vector3 = MultiverseStage.slot(state.focus)
	var reach: float = MultiverseStage.pitch
	for l in ids:
		for board in state.boards(l):
			var d: Vector3 = MultiverseStage.slot(board.coords()) - focus
			reach = maxf(reach, maxf(absf(d.x), absf(d.z)) + MultiverseStage.pitch * 0.5)
	var radius: float = DIAMETER * 0.5 - RING - 4.0
	return clampf(radius / reach, MIN_SCALE, CELL / MultiverseStage.pitch)


func close_scale() -> float:
	return CELL / MultiverseStage.pitch * NEAR_FACTOR


func zoom_fraction() -> float:
	var camera: TacticsCamera = stage.camera_node() if stage != null else null
	if camera == null or camera.res == null:
		return 1.0
	var res: TacticsCameraResource = camera.res
	var span: float = maxf(0.001, res.max_zoom - res.min_zoom)
	var fov_part: float = clampf((res.current_fov - res.min_zoom) / span, 0.0, 1.0)
	if res.max_overview <= 0.0:
		return fov_part
	var dolly_part: float = clampf(res.current_distance / res.max_overview, 0.0, 1.0)
	return 0.5 * fov_part + 0.5 * dolly_part


func layout_scale(state: MultiverseState, ids: Array[int]) -> float:
	var far: float = fit_scale(state, ids)
	var near: float = maxf(far, close_scale())
	return far * pow(near / far, 1.0 - clampf(zoom_fraction(), 0.0, 1.0))


func _draw_mask() -> void:
	var centre: Vector2 = size * 0.5
	_content.draw_circle(centre, DIAMETER * 0.5 - RING, COLOR_BACK)


func _draw_frame() -> void:
	var centre: Vector2 = size * 0.5
	_frame.draw_arc(centre, DIAMETER * 0.5 - RING * 0.5, 0.0, TAU, 72, PmdStyle.FRAME_SOFT, RING, true)
	_frame.draw_arc(centre, DIAMETER * 0.5 - RING - 1.0, 0.0, TAU, 72, PmdStyle.SHADOW, 2.0, true)


func _draw_field(field: Control) -> void:
	draws += 1
	last_cards.clear()
	if level == null or level.multiverse == null or level.multiverse.state.timelines.is_empty():
		return
	var state: MultiverseState = level.multiverse.state
	var ids: Array[int] = state.timeline_ids()
	var centre: Vector2 = size * 0.5
	var scale: float = layout_scale(state, ids)
	var focus: Vector3 = view_centre(state)
	var card: float = CARD * clampf(scale / (CELL / MultiverseStage.pitch), 0.35, NEAR_FACTOR)
	var band: float = maxf(2.0, card * 0.45)
	var now: int = state.present()
	for l in ids:
		var active: bool = state.is_active(l)
		var first: int = state.first_turn(l)
		var latest: BoardSnapshot = state.latest(l)
		var color: Color = MultiverseStage.COLOR_BAND if active else MultiverseStage.COLOR_BAND_FROZEN
		var a: Vector2 = project(MultiverseStage.slot(Vector2i(l, first)) - focus - Vector3(MultiverseStage.pitch * 0.5, 0.0, 0.0), centre, scale)
		var b: Vector2 = project(MultiverseStage.slot(Vector2i(l, latest.turn)) - focus + Vector3(MultiverseStage.pitch * 0.6, 0.0, 0.0), centre, scale)
		field.draw_line(a, b, color, band, true)
		var dir: Vector2 = (b - a).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		field.draw_colored_polygon(PackedVector2Array([b + dir * band * 1.6, b + side * band * 1.3, b - side * band * 1.3]), color)
		if state.origins.has(l):
			var origin: Vector2i = state.origins[l]
			var o: Vector2 = project(MultiverseStage.slot(origin) - focus, centre, scale)
			var bend: Vector2 = project(MultiverseStage.slot(Vector2i(l, origin.y)) - focus - Vector3(MultiverseStage.pitch * 0.5, 0.0, 0.0), centre, scale)
			var mid: Vector2 = project(MultiverseStage.slot(Vector2i(l, origin.y)) - focus + Vector3(0.0, 0.0, (MultiverseStage.slot(origin) - MultiverseStage.slot(Vector2i(l, origin.y))).z * 0.5), centre, scale)
			field.draw_polyline(PackedVector2Array([o, mid, bend]), color, band * 0.8, true)
	var present_a: Vector2 = project(MultiverseStage.slot(Vector2i(ids.max(), now)) - focus - Vector3(MultiverseStage.pitch * 0.5, 0.0, MultiverseStage.pitch * 0.6), centre, scale)
	var present_b: Vector2 = project(MultiverseStage.slot(Vector2i(ids.min(), now)) - focus - Vector3(MultiverseStage.pitch * 0.5, 0.0, -MultiverseStage.pitch * 0.6), centre, scale)
	field.draw_line(present_a, present_b, COLOR_PRESENT, maxf(2.0, band * 0.9), true)
	var font: Font = PmdStyle.TEXT_FONT
	var font_size: int = int(clampf(card * 0.72, 7.0, 40.0))
	for l in ids:
		for board in state.boards(l):
			var coords: Vector2i = board.coords()
			var status: String = stage.board_status(coords) if stage != null else MultiverseStage.STATUS_PAST
			var fill: Color = MultiverseStage.status_color(status)
			fill.a = 1.0
			if status == MultiverseStage.STATUS_CURRENT:
				fill = fill.lerp(MultiverseStage.COLOR_PENDING, 0.5 + 0.5 * sin(_pulse * 6.0))
			var at: Vector2 = project(MultiverseStage.slot(coords) - focus, centre, scale)
			var rect := Rect2(at - Vector2(card, card) * 0.5, Vector2(card, card))
			field.draw_rect(rect, fill, true)
			var outline: Color = COLOR_LABEL if status != MultiverseStage.STATUS_PENDING else Color(1.0, 0.55, 0.2, 1.0)
			field.draw_rect(rect, outline, false, 1.0 if status != MultiverseStage.STATUS_PENDING and status != MultiverseStage.STATUS_CURRENT else 2.0)
			last_cards[coords] = status
			if card >= 9.0:
				var text: String = str(coords.y)
				var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x
				field.draw_string(font, at + Vector2(-width * 0.5, font_size * 0.38), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, COLOR_LABEL)
	if stage != null:
		for arc in stage.arcs:
			var side: int = int(arc["side"])
			var color: Color = MultiverseStage.COLOR_ARC_PLAYER if side == MultiverseState.SIDE_PLAYER else MultiverseStage.COLOR_ARC_ENEMY
			var from: Vector2 = project(MultiverseStage.slot(arc["from"]) - focus, centre, scale)
			var to: Vector2 = project(MultiverseStage.slot(arc["to"]) - focus, centre, scale)
			var control: Vector2 = (from + to) * 0.5 + Vector2(0.0, -maxf(8.0, from.distance_to(to) * 0.25))
			var points := PackedVector2Array()
			for i in range(13):
				var t: float = float(i) / 12.0
				var u: float = 1.0 - t
				points.append(from * (u * u) + control * (2.0 * u * t) + to * (t * t))
			field.draw_polyline(points, color, 2.0, true)
			field.draw_circle(to, 2.5, color)
