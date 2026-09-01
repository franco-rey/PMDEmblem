class_name BattleScheduler
extends RefCounted

signal turn_started(unit: BattleUnit)
signal turn_completed(unit: BattleUnit)
signal round_started
signal battle_ended

var _units: Array[BattleUnit] = []
var _queue: Array[BattleUnit] = []
var _active_unit: BattleUnit = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tie_values: Dictionary = {}
var _battle_ended_emitted: bool = false


func start_battle(units: Array, battle_seed: int) -> void:
	_units.clear()
	_queue.clear()
	_tie_values.clear()
	_active_unit = null
	_battle_ended_emitted = false
	_rng = RandomNumberGenerator.new()
	_rng.seed = battle_seed
	for u in units:
		if u is BattleUnit:
			_units.append(u)
			_tie_values[u] = _rng.randi()
	_build_queue()
	round_started.emit()
	_activate_next()


func get_active_unit() -> BattleUnit:
	return _active_unit


func complete_active_unit() -> void:
	if _active_unit == null:
		return
	var completed: BattleUnit = _active_unit
	_active_unit = null
	turn_completed.emit(completed)
	_activate_next()


func skip_active_unit(_reason: String = "") -> bool:
	if _active_unit == null:
		return false
	var skipped: BattleUnit = _active_unit
	_active_unit = null
	turn_completed.emit(skipped)
	_activate_next()
	return true


func remove_unit(unit: BattleUnit) -> void:
	if unit == null:
		return
	var was_active: bool = _active_unit == unit
	if was_active:
		_active_unit = null
	var filtered_queue: Array[BattleUnit] = []
	for q in _queue:
		if q != unit:
			filtered_queue.append(q)
	_queue = filtered_queue
	var filtered_units: Array[BattleUnit] = []
	for u in _units:
		if u != unit:
			filtered_units.append(u)
	_units = filtered_units
	_tie_values.erase(unit)
	if was_active:
		_activate_next()


func insert_unit(unit: BattleUnit) -> void:
	if unit == null:
		return
	if unit in _units:
		return
	_units.append(unit)
	_tie_values[unit] = _rng.randi()
	if not unit.is_alive():
		return
	var insert_at: int = 0
	while insert_at < _queue.size() and _is_less_than(_queue[insert_at], unit):
		insert_at += 1
	_queue.insert(insert_at, unit)


func rebuild_queue() -> void:
	_active_unit = null
	_build_queue()
	_activate_next()


func is_battle_over() -> bool:
	var teams_alive: Dictionary = {}
	for u in _units:
		if u.is_alive():
			teams_alive[u.team] = true
	return teams_alive.size() <= 1


func peek_upcoming(count: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var i: int = 0
	while i < count and i < _queue.size():
		out.append(_queue[i])
		i += 1
	return out


func _build_queue() -> void:
	var living: Array[BattleUnit] = []
	for u in _units:
		if u.is_alive():
			living.append(u)
	living.sort_custom(_is_less_than)
	_queue = living


func _activate_next() -> void:
	while _queue.size() > 0:
		var next: BattleUnit = _queue.pop_front()
		if not next.is_alive():
			continue
		_active_unit = next
		turn_started.emit(_active_unit)
		return

	if is_battle_over():
		if not _battle_ended_emitted:
			_battle_ended_emitted = true
			battle_ended.emit()
		return

	_build_queue()
	round_started.emit()
	while _queue.size() > 0:
		var next: BattleUnit = _queue.pop_front()
		if not next.is_alive():
			continue
		_active_unit = next
		turn_started.emit(_active_unit)
		return


func _is_less_than(a: BattleUnit, b: BattleUnit) -> bool:
	if a.speed() != b.speed():
		return a.speed() > b.speed()
	if a.team != b.team:
		return a.team < b.team
	if a.insertion_order != b.insertion_order:
		return a.insertion_order < b.insertion_order
	var va: int = _tie_values.get(a, 0)
	var vb: int = _tie_values.get(b, 0)
	return va < vb
