extends SmokeCase

const SCENE_PATH: String = "res://assets/maps/level/test_level.tscn"
const FRAMES_TO_RUN: int = 360


func _init() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("smoke: could not load %s" % SCENE_PATH)
		quit(1)
		return
	var level: TacticsLevel = scene.instantiate() as TacticsLevel
	if level == null:
		push_error("smoke: test_level did not instantiate as TacticsLevel")
		quit(1)
		return
	root.add_child(level)
	await _run_until_first_player_turn(level)

	_assert_true(level.use_speed_scheduler, "scheduler flag is enabled by default")
	_assert_true(level.scheduler != null, "scheduler instance allocated")
	_assert_true(level.battle_units.size() == 10, "10 battle units built (4 player + 6 enemy)")

	var first_event: Dictionary = _first_turn_event(level.battle_log)
	_assert_true(first_event.size() > 0, "battle log captured at least one turn_started event")
	if first_event.size() > 0:
		var first_pawn: TacticsPawn = first_event.get("unit") as TacticsPawn
		if first_pawn != null and first_pawn.stats != null:
			_assert_true(first_pawn.stats.species_name == "Gengar", "first scheduled unit is a Gengar (Speed 110)")
			_assert_true(int(first_event.get("team", -1)) == PokemonInstanceResource.Team.ENEMY, "first scheduled unit is on the enemy team")

	var turn_count: int = _count_turn_events(level.battle_log)
	_assert_true(turn_count >= 1, "scheduler dispatched at least one turn_started event (got %d)" % turn_count)
	_force_skip_active_unit(level, "flinch")
	_assert_true(_log_has_status(level.battle_log, "turn_skipped", "flinch"), "flinched scheduled unit skipped its turn")
	_assert_true(_log_has_status(level.battle_log, "status_removed", "flinch"), "flinch was consumed by scheduler scene hook")

	level.queue_free()

	if failures > 0:
		push_error("smoke: scheduler scene failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: scheduler scene clean")
		quit(0)


func _run_until_first_player_turn(level: TacticsLevel) -> void:
	for _i in range(FRAMES_TO_RUN):
		await physics_frame
		if level.battle_finished:
			break
		if level.scheduler != null and level.scheduler.get_active_unit() != null:
			var unit: BattleUnit = level.scheduler.get_active_unit()
			if unit.control_type == PokemonInstanceResource.ControlType.PLAYER:
				return


func _first_turn_event(log: BattleLog) -> Dictionary:
	if log == null:
		return {}
	for event in log.events:
		if event.get("kind", "") == "turn_started":
			return event
	return {}


func _count_turn_events(log: BattleLog) -> int:
	if log == null:
		return 0
	var n: int = 0
	for event in log.events:
		if event.get("kind", "") == "turn_started":
			n += 1
	return n


func _force_skip_active_unit(level: TacticsLevel, status_id: String) -> void:
	if level == null or level.scheduler == null:
		return
	var unit: BattleUnit = level.scheduler.get_active_unit()
	if unit == null or unit.pawn == null or unit.pawn.stats == null:
		return
	unit.pawn.stats.apply_battle_status(status_id, {"source": "scheduler_scene_smoke"})
	level._on_turn_started(unit)


func _log_has_status(log: BattleLog, kind: String, status_id: String) -> bool:
	if log == null:
		return false
	for event in log.events:
		if event.get("kind", "") == kind and event.get("status_id", "") == status_id:
			return true
	return false
