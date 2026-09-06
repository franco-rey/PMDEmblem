class_name MultiverseState
extends RefCounted

const SIDE_PLAYER: int = 0
const SIDE_ENEMY: int = 1

var timelines: Dictionary = {}
var created_by_player: int = 0
var created_by_enemy: int = 0
var focus: Vector2i = Vector2i(0, 1)
var origins: Dictionary = {}


func add_root(board: BoardSnapshot) -> void:
	board.timeline = 0
	timelines[0] = [board]
	focus = board.coords()


func timeline_ids() -> Array[int]:
	var out: Array[int] = []
	for key in timelines.keys():
		out.append(int(key))
	out.sort()
	return out


func boards(l: int) -> Array:
	return timelines.get(l, [])


func latest(l: int) -> BoardSnapshot:
	var list: Array = boards(l)
	return list.back() if not list.is_empty() else null


func board(l: int, t: int) -> BoardSnapshot:
	for entry in boards(l):
		if (entry as BoardSnapshot).turn == t:
			return entry
	return null


func first_turn(l: int) -> int:
	var list: Array = boards(l)
	return (list.front() as BoardSnapshot).turn if not list.is_empty() else 0


func active_band() -> int:
	return mini(created_by_player, created_by_enemy) + 1


func is_active(l: int) -> bool:
	return timelines.has(l) and absi(l) <= active_band()


func active_timelines() -> Array[int]:
	var out: Array[int] = []
	for l in timeline_ids():
		if is_active(l):
			out.append(l)
	return out


func present() -> int:
	var value: int = -1
	for l in active_timelines():
		var last: BoardSnapshot = latest(l)
		if last != null and (value < 0 or last.turn < value):
			value = last.turn
	return maxi(value, 0)


func owed_boards() -> Array[Vector2i]:
	var now: int = present()
	var out: Array[Vector2i] = []
	for l in active_timelines():
		var last: BoardSnapshot = latest(l)
		if last != null and last.turn == now and last.standing(0) > 0 and last.standing(1) > 0:
			out.append(last.coords())
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _timeline_before(a.x, b.x))
	return out


func next_owed(after: Vector2i) -> Vector2i:
	var owed: Array[Vector2i] = owed_boards()
	if owed.is_empty():
		return Vector2i(after.x, -1)
	for coords in owed:
		if coords != after:
			return coords
	return owed[0]


func next_timeline_index(side: int) -> int:
	return created_by_player + 1 if side == SIDE_PLAYER else -(created_by_enemy + 1)


func branch(from: Vector2i, first_board: BoardSnapshot, side: int) -> int:
	var l: int = next_timeline_index(side)
	if side == SIDE_PLAYER:
		created_by_player += 1
	else:
		created_by_enemy += 1
	first_board.timeline = l
	first_board.turn = from.y
	timelines[l] = [first_board]
	origins[l] = from
	return l


func advance(l: int, next: BoardSnapshot) -> void:
	next.timeline = l
	var list: Array = boards(l)
	if list.is_empty():
		timelines[l] = [next]
		return
	var last: BoardSnapshot = list.back()
	if next.turn == last.turn:
		list[list.size() - 1] = next
	else:
		list.append(next)
	timelines[l] = list


func replace_latest(l: int, board_state: BoardSnapshot) -> void:
	var list: Array = boards(l)
	if list.is_empty():
		timelines[l] = [board_state]
		return
	board_state.timeline = l
	list[list.size() - 1] = board_state
	timelines[l] = list


func past_boards(l: int, before_turn: int) -> Array[BoardSnapshot]:
	var out: Array[BoardSnapshot] = []
	for entry in boards(l):
		var candidate: BoardSnapshot = entry
		if candidate.turn < before_turn:
			out.append(candidate)
	return out


func dimensions_at(t: int, except_l: int) -> Array[int]:
	var out: Array[int] = []
	for l in active_timelines():
		if l == except_l:
			continue
		var last: BoardSnapshot = latest(l)
		if last != null and last.turn == t:
			out.append(l)
	return out


func standing_total(team: int, active_only: bool = true) -> int:
	var total: int = 0
	for l in (active_timelines() if active_only else timeline_ids()):
		var last: BoardSnapshot = latest(l)
		if last != null:
			total += last.standing(team)
	return total


func board_count() -> int:
	var total: int = 0
	for l in timeline_ids():
		total += boards(l).size()
	return total


func max_turn() -> int:
	var value: int = 0
	for l in timeline_ids():
		var last: BoardSnapshot = latest(l)
		if last != null:
			value = maxi(value, last.turn)
	return value


static func _timeline_before(a: int, b: int) -> bool:
	if absi(a) != absi(b):
		return absi(a) < absi(b)
	return a > b


static func label(l: int) -> String:
	if l == 0:
		return "L0"
	return "L%s%d" % ["+" if l > 0 else "-", absi(l)]
