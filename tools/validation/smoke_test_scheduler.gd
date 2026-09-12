extends SmokeCase

var created_stats: Array[Stats] = []


func _init() -> void:
	_test_basic_order()
	_test_determinism_same_seed()
	_test_player_team_precedence()
	_test_remove_unit()
	_test_insert_unit()
	_test_rebuild_queue()
	_test_fainted_skipped()
	_test_status_turn_skip()
	_test_is_battle_over()
	_test_peek_upcoming()

	if failures > 0:
		_cleanup()
		push_error("smoke: scheduler failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: scheduler clean")
		_cleanup()
		quit(0)


func _make_unit(speed_val: int, team: int, insertion: int) -> BattleUnit:
	var stats := Stats.new()
	stats.speed = speed_val
	stats.battle_status = Stats.BattleStatus.ACTIVE
	created_stats.append(stats)
	return BattleUnit.new(null, stats, team, PokemonInstanceResource.ControlType.AI, insertion)


func _test_basic_order() -> void:
	var a := _make_unit(110, PokemonInstanceResource.Team.PLAYER, 0)
	var b := _make_unit(90, PokemonInstanceResource.Team.ENEMY, 1)
	var c := _make_unit(85, PokemonInstanceResource.Team.PLAYER, 2)
	var d := _make_unit(25, PokemonInstanceResource.Team.ENEMY, 3)

	var s := BattleScheduler.new()
	s.start_battle([a, b, c, d], 42)
	var order: Array = _drain(s, 4)
	_assert_array_eq(order, [a, b, c, d], "basic speed-descending order (110>90>85>25)")


func _test_determinism_same_seed() -> void:
	var a := _make_unit(80, PokemonInstanceResource.Team.PLAYER, 0)
	var b := _make_unit(80, PokemonInstanceResource.Team.PLAYER, 1)
	var c := _make_unit(80, PokemonInstanceResource.Team.PLAYER, 2)
	var d := _make_unit(80, PokemonInstanceResource.Team.PLAYER, 3)

	var s1 := BattleScheduler.new()
	s1.start_battle([a, b, c, d], 7)
	var order1: Array = _drain(s1, 4)

	var s2 := BattleScheduler.new()
	s2.start_battle([a, b, c, d], 7)
	var order2: Array = _drain(s2, 4)

	_assert_array_eq(order1, order2, "same seed produces same order")
	_assert_array_eq(order1, [a, b, c, d], "stable insertion order resolves within-team ties")


func _test_player_team_precedence() -> void:
	var p1 := _make_unit(90, PokemonInstanceResource.Team.PLAYER, 0)
	var e1 := _make_unit(90, PokemonInstanceResource.Team.ENEMY, 1)
	var p2 := _make_unit(90, PokemonInstanceResource.Team.PLAYER, 2)
	var s := BattleScheduler.new()
	s.start_battle([e1, p1, p2], 11)
	var order: Array = _drain(s, 3)
	_assert_array_eq(order, [p1, p2, e1], "team precedence applies within tied Speeds")


func _test_remove_unit() -> void:
	var a := _make_unit(110, PokemonInstanceResource.Team.PLAYER, 0)
	var b := _make_unit(90, PokemonInstanceResource.Team.ENEMY, 1)
	var c := _make_unit(85, PokemonInstanceResource.Team.PLAYER, 2)
	var d := _make_unit(25, PokemonInstanceResource.Team.ENEMY, 3)
	var s := BattleScheduler.new()
	s.start_battle([a, b, c, d], 42)

	_assert_array_eq([s.get_active_unit()], [a], "round starts with a")
	s.complete_active_unit()
	_assert_array_eq([s.get_active_unit()], [b], "advances to b")
	s.remove_unit(b)
	_assert_array_eq([s.get_active_unit()], [c], "removing active b advances to c")
	s.remove_unit(b)
	_assert_array_eq([s.get_active_unit()], [c], "double-remove of b is idempotent")
	s.complete_active_unit()
	_assert_array_eq([s.get_active_unit()], [d], "after c, d is active")


func _test_insert_unit() -> void:
	var a := _make_unit(110, PokemonInstanceResource.Team.PLAYER, 0)
	var b := _make_unit(90, PokemonInstanceResource.Team.ENEMY, 1)
	var c := _make_unit(85, PokemonInstanceResource.Team.PLAYER, 2)
	var d := _make_unit(25, PokemonInstanceResource.Team.ENEMY, 3)
	var s := BattleScheduler.new()
	s.start_battle([a, b, c, d], 42)

	s.complete_active_unit()
	var hot := _make_unit(200, PokemonInstanceResource.Team.ALLY, 99)
	s.insert_unit(hot)
	_assert_array_eq([s.get_active_unit()], [b], "active b not displaced by insertion")
	s.complete_active_unit()
	_assert_array_eq([s.get_active_unit()], [hot], "inserted high-speed unit acts before remaining queue")
	s.complete_active_unit()
	_assert_array_eq([s.get_active_unit()], [c], "queue resumes after inserted unit acts")


func _test_rebuild_queue() -> void:
	var a := _make_unit(110, PokemonInstanceResource.Team.PLAYER, 0)
	var b := _make_unit(90, PokemonInstanceResource.Team.ENEMY, 1)
	var c := _make_unit(85, PokemonInstanceResource.Team.PLAYER, 2)
	var d := _make_unit(25, PokemonInstanceResource.Team.ENEMY, 3)
	var s := BattleScheduler.new()
	s.start_battle([a, b, c, d], 42)

	s.complete_active_unit()
	s.complete_active_unit()
	s.rebuild_queue()
	_assert_array_eq([s.get_active_unit()], [a], "rebuild restarts with highest-speed living unit")


func _test_fainted_skipped() -> void:
	var a := _make_unit(110, PokemonInstanceResource.Team.PLAYER, 0)
	var b := _make_unit(90, PokemonInstanceResource.Team.ENEMY, 1)
	var c := _make_unit(85, PokemonInstanceResource.Team.PLAYER, 2)
	var s := BattleScheduler.new()
	s.start_battle([a, b, c], 42)
	b.stats.battle_status = Stats.BattleStatus.FAINTED
	s.complete_active_unit()
	_assert_array_eq([s.get_active_unit()], [c], "fainted unit is skipped without removal")


func _test_status_turn_skip() -> void:
	var a := _make_unit(110, PokemonInstanceResource.Team.PLAYER, 0)
	var b := _make_unit(90, PokemonInstanceResource.Team.ENEMY, 1)
	var c := _make_unit(85, PokemonInstanceResource.Team.PLAYER, 2)
	var completed: Array = []
	var s := BattleScheduler.new()
	s.turn_completed.connect(func(unit: BattleUnit) -> void: completed.append(unit))
	s.start_battle([a, b, c], 42)

	a.stats.apply_battle_status("sleep", {"source": "test"})
	var sleep_skip: Dictionary = a.stats.consume_turn_skip_status()
	_assert_true(String(sleep_skip.get("status_id", "")) == "sleep", "sleep reports a turn skip")
	_assert_true(a.stats.battle_statuses.has("sleep"), "sleep persists after skip consumption")
	_assert_true(s.skip_active_unit(String(sleep_skip.get("status_id", ""))), "scheduler skips active sleeping unit")
	_assert_array_eq([s.get_active_unit()], [b], "skip advances from sleeping unit to next active unit")

	b.stats.apply_battle_status("flinch", {"source": "test"})
	var flinch_skip: Dictionary = b.stats.consume_turn_skip_status()
	_assert_true(String(flinch_skip.get("status_id", "")) == "flinch", "flinch reports a turn skip")
	_assert_true(not b.stats.battle_statuses.has("flinch"), "flinch is consumed by turn skip")
	_assert_true(s.skip_active_unit(String(flinch_skip.get("status_id", ""))), "scheduler skips active flinched unit")
	_assert_array_eq([s.get_active_unit()], [c], "skip advances from flinched unit to next active unit")
	_assert_array_eq(completed, [a, b], "skipped units emit turn_completed deterministically")

	c.stats.apply_battle_status("paralyze", {"skip_turn": true})
	var paralysis_skip: Dictionary = c.stats.consume_turn_skip_status()
	_assert_true(String(paralysis_skip.get("status_id", "")) == "paralyze", "full-paralysis payload reports a turn skip")
	_assert_true(not bool((c.stats.battle_statuses["paralyze"] as Dictionary).get("skip_turn", true)), "full-paralysis payload is consumed without removing paralysis")


func _test_is_battle_over() -> void:
	var a := _make_unit(110, PokemonInstanceResource.Team.PLAYER, 0)
	var b := _make_unit(90, PokemonInstanceResource.Team.ENEMY, 1)
	var s := BattleScheduler.new()
	s.start_battle([a, b], 42)
	_assert_true(not s.is_battle_over(), "two living teams -> battle ongoing")
	b.stats.battle_status = Stats.BattleStatus.FAINTED
	_assert_true(s.is_battle_over(), "one team remaining -> battle over")


func _test_peek_upcoming() -> void:
	var a := _make_unit(110, PokemonInstanceResource.Team.PLAYER, 0)
	var b := _make_unit(90, PokemonInstanceResource.Team.ENEMY, 1)
	var c := _make_unit(85, PokemonInstanceResource.Team.PLAYER, 2)
	var d := _make_unit(25, PokemonInstanceResource.Team.ENEMY, 3)
	var s := BattleScheduler.new()
	s.start_battle([a, b, c, d], 42)
	var upcoming: Array = s.peek_upcoming(3)
	_assert_array_eq(upcoming, [b, c, d], "peek_upcoming returns the next N queued units")


func _drain(s: BattleScheduler, n: int) -> Array:
	var order: Array = []
	while order.size() < n:
		var u: BattleUnit = s.get_active_unit()
		if u == null:
			break
		order.append(u)
		s.complete_active_unit()
	return order


func _assert_array_eq(actual: Array, expected: Array, label: String) -> void:
	if actual.size() != expected.size():
		_fail("%s (size mismatch: %d vs %d)" % [label, actual.size(), expected.size()])
		return
	for i in range(actual.size()):
		if actual[i] != expected[i]:
			_fail("%s (index %d differs)" % [label, i])
			return
	print("smoke: ok - %s" % label)


func _cleanup() -> void:
	for stats in created_stats:
		if is_instance_valid(stats):
			stats.free()
	created_stats.clear()
