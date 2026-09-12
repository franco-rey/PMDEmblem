extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const UNIT_SPEED: float = 30.0
const MATCH_SPEED: float = 10.0
const UNIT_FRAMES: int = 240
const MATCH_FRAMES: int = 7200
const STALL_FRAMES: int = 900


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=6300 mode=bots team=6")
	_assert_true(ok, "6v6 bot match launches for the movement check")
	if not ok:
		_wrap_up()
		return
	var level: TacticsLevel = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	level.battle_finished = true
	var pawn: TacticsPawn = _pawn_with_row(level)
	var start: Vector3 = pawn.global_position
	var stack: Array[Variant] = _row_tiles(level, start, 3)
	_assert_true(stack.size() == 3, "found three tiles in a row beside %s" % pawn.name)
	pawn.res.can_move = true
	pawn.res.move_direction = Vector3.ZERO
	pawn.res.pathfinding_tilestack = stack.duplicate()
	Engine.time_scale = UNIT_SPEED
	var unit_frames: int = 0
	while not pawn.res.pathfinding_tilestack.is_empty() and unit_frames < UNIT_FRAMES:
		await physics_frame
		unit_frames += 1
	Engine.time_scale = 1.0
	var landed: float = pawn.global_position.distance_to(stack[stack.size() - 1]) if not stack.is_empty() else 999.0
	_assert_true(pawn.res.pathfinding_tilestack.is_empty() and landed < 0.35, "a pawn walking three squares at %dx arrives on the last square (stack %d left, %.2f away, %d frames)" % [int(UNIT_SPEED), pawn.res.pathfinding_tilestack.size(), landed, unit_frames])
	driver.main._on_main_menu_requested()
	await process_frame
	var match_driver = DRIVER.new(self)
	var match_ok: bool = await match_driver._launch("match seed=6301 mode=bots team=6")
	_assert_true(match_ok, "second 6v6 bot match launches for the full-speed run")
	if not match_ok:
		_wrap_up()
		return
	var match_level: TacticsLevel = match_driver.level
	Engine.time_scale = MATCH_SPEED
	var last_turn: int = -1
	var last_unit: String = ""
	var quiet: int = 0
	var total: int = 0
	var stalled: String = ""
	while total < MATCH_FRAMES:
		await physics_frame
		total += 1
		if not is_instance_valid(match_level) or match_level.battle_finished:
			break
		var turn: int = match_level.notation.turn_index
		var active: BattleUnit = match_level.scheduler.get_active_unit() if match_level.scheduler != null else null
		var unit_name: String = String(active.pawn.name) if active != null and active.pawn != null else ""
		if turn != last_turn or unit_name != last_unit:
			last_turn = turn
			last_unit = unit_name
			quiet = 0
		else:
			quiet += 1
		if total % 600 == 0:
			print("smoke: progress frames=%d turn=%d active=%s" % [total, turn, unit_name])
		if quiet >= STALL_FRAMES:
			var moving: String = ""
			for unit in match_level.units_on_map():
				if unit.res.is_moving:
					moving += "%s stack=%d at=%s; " % [unit.name, unit.res.pathfinding_tilestack.size(), str(unit.global_position)]
			stalled = "turn %d active %s stage %d moving [%s]" % [turn, unit_name, match_level.participant.res.stage, moving]
			break
	Engine.time_scale = 1.0
	_assert_true(stalled.is_empty(), "no unit stalls while the match runs at %dx (%s)" % [int(MATCH_SPEED), stalled])
	_assert_true(not is_instance_valid(match_level) or match_level.battle_finished or not stalled.is_empty(), "the %dx match finishes within %d physics frames" % [int(MATCH_SPEED), MATCH_FRAMES])
	_wrap_up()


func _pawn_with_row(level: TacticsLevel) -> TacticsPawn:
	for parent in [level.player, level.opponent]:
		for child in parent.get_children():
			if child is TacticsPawn and _row_tiles(level, (child as TacticsPawn).global_position, 3).size() == 3:
				return child
	return level.player.get_child(0)


func _row_tiles(level: TacticsLevel, start: Vector3, count: int) -> Array[Variant]:
	var candidates: Array[Vector3] = []
	for tile in level.arena.get_node("Tiles").get_children():
		var pos: Vector3 = (tile as Node3D).global_position
		if absf(pos.z - start.z) < 0.1 and pos.x > start.x + 0.5 and absf(pos.y - start.y) < 0.1:
			candidates.append(pos)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	var out: Array[Variant] = []
	var expected: float = start.x
	for pos in candidates:
		if absf(pos.x - (expected + 1.0)) > 0.15:
			break
		out.append(pos)
		expected = pos.x
		if out.size() >= count:
			break
	return out


func _wrap_up() -> void:
	Engine.time_scale = 1.0
	_finish("movement_at_speed")
