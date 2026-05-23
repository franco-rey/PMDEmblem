class_name BattleScheduler
extends RefCounted
## Speed-ordered tactical initiative queue.
##
## One round = every living unit acts once, ordered by Speed descending.
## Player- and AI-controlled units share the same queue; the caller dispatches
## by control type. See [code]plan/architecture/scheduler_model.md[/code] for
## the API contract, tie-breaking rules, and determinism guarantees.

## Emitted after a unit becomes the active one (start of its turn).
signal turn_started(unit: BattleUnit)
## Emitted after [method complete_active_unit] finishes the active turn.
signal turn_completed(unit: BattleUnit)
## Emitted once when [method is_battle_over] flips to true.
signal battle_ended

var _units: Array[BattleUnit] = []
var _queue: Array[BattleUnit] = []
var _active_unit: BattleUnit = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Seeded tie-break value per unit. Filled on `start_battle` / `insert_unit`.
var _tie_values: Dictionary = {}
var _battle_ended_emitted: bool = false


## Initialize the queue from a flat list of living units. Seed drives the
## final tie-breaker (after Speed, team, and stable insertion order).
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
	_activate_next()


## Returns the unit whose turn it is now. Null after [method is_battle_over]
## returns true or before [method start_battle] is called.
func get_active_unit() -> BattleUnit:
	return _active_unit


## Marks the active unit's turn as complete and advances the queue.
func complete_active_unit() -> void:
	if _active_unit == null:
		return
	var completed: BattleUnit = _active_unit
	_active_unit = null
	turn_completed.emit(completed)
	_activate_next()


## Remove a unit from all current and future turns. Idempotent.
##
## If the removed unit is the active one, advance to the next legal unit
## (per the scheduler-model contract: "mark its turn complete and advance").
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


## Insert a new unit into the current round at its Speed-correct position.
## Honors deterministic tie-breaking. No-op if the unit is already tracked.
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


## Drop the current round's remainder and rebuild from the living-unit set.
## Use sparingly - common-case insertions / removals should use the explicit
## methods.
func rebuild_queue() -> void:
	_active_unit = null
	_build_queue()
	_activate_next()


## True when only one team has living units (or none do).
func is_battle_over() -> bool:
	var teams_alive: Dictionary = {}
	for u in _units:
		if u.is_alive():
			teams_alive[u.team] = true
	return teams_alive.size() <= 1


## Snapshot of the next [code]count[/code] units in turn order. Convenience for
## UI panels that need to preview upcoming turns.
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
