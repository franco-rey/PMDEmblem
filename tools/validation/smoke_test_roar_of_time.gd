extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")

var failures: int = 0
var driver = null
var level: TacticsLevel = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=11 mode=pvp multiverse=1 p=0483_dialga@50:roar_of_time,dragon_claw:pressure|0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember,scratch:blaze|0001_bulbasaur@50:tackle,growth:overgrow")
	_assert_true(ok, "multiverse battle with Dialga launches")
	if not ok:
		_finish()
		return
	level = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var mv: MultiverseController = level.multiverse
	await _play_rounds_until(3)
	_assert_true(level.round_index == 3 and mv.state.boards(0).size() == 3, "timeline 0 holds boards T1, T2 and T3 after two full rounds (%d boards)" % mv.state.boards(0).size())
	var dialga: TacticsPawn = await _wait_for_active("P1")
	_assert_true(dialga != null, "Dialga's turn comes up in round 3")
	if dialga == null:
		_finish()
		return
	var charmander: TacticsPawn = level.notation.pawn_for_id("E1")
	var roar: PokemonMoveResource = PokemonLearnsetService.load_move("roar_of_time")
	level._ops().damage(charmander, 12, {"kind": "hit", "attacker": dialga, "move": roar})
	BattleMoveSpecials.new().after_hit(null, dialga, charmander, roar, 12, true, level, level.battle_log)
	var options: Array = mv.pending_travel.get("options", [])
	_assert_true(options.size() == 2 and String(options[0].get("label", "")) == "L0 T1" and String(options[1].get("label", "")) == "L0 T2", "a surviving Roar of Time hit offers every past moment where both stood (%s)" % str(options.map(func(o: Dictionary) -> String: return String(o.get("label", "")))))
	var dialga_hp: int = dialga.stats.curr_health
	var charmander_hp: int = charmander.stats.curr_health
	var origin_queue: Array = mv.capture(true).scheduler["queue"]
	_assert_true(mv.commit_travel(0), "committing the travel to L0 T1 succeeds")
	await physics_frame
	await physics_frame
	_assert_true(mv.state.created_by_player == 1 and mv.state.timelines.has(1) and mv.state.focus == Vector2i(1, 1), "a player branch opens timeline L+1 at T1 and the focus moves there (focus %s)" % str(mv.state.focus))
	var branch: BoardSnapshot = mv.state.latest(1)
	var branch_ids: Array[String] = branch.unit_ids()
	branch_ids.sort()
	_assert_true(branch_ids == ["E1", "E1'", "E2", "P1", "P1'", "P2"], "the branch board keeps the past copies and adds both travellers with primed ids (%s)" % str(branch.unit_ids()))
	_assert_true(int(branch.unit("P1'")["stats"]["curr_health"]) == dialga_hp and int(branch.unit("E1'")["stats"]["curr_health"]) == charmander_hp and int(branch.unit("P1")["stats"]["curr_health"]) == branch.unit("P1")["stats"]["max_health"], "travellers arrive with their departure HP while their past selves keep the past HP")
	var origin: BoardSnapshot = mv.state.latest(0)
	_assert_true(origin.turn == 3 and origin.mid_round and not origin.has_unit("P1") and not origin.has_unit("E1") and origin.unit_ids() == ["P2", "E2"], "timeline 0 keeps a mid-round T3 board without the travellers (%s)" % str(origin.unit_ids()))
	_assert_true(mv.state.present() == 1 and level.round_index == 1, "the present falls back to T1 and play resumes at round 1 on the branch (round %d)" % level.round_index)
	var arrival: TacticsPawn = level.notation.pawn_for_id("P1'")
	var past_self: TacticsPawn = level.notation.pawn_for_id("P1")
	_assert_true(arrival != null and past_self != null and arrival != past_self and arrival.stats.curr_health == dialga_hp and arrival.stats.battle_statuses.has("recharge"), "the arrived Dialga stands beside its past self, keeps its HP and owes its recharge")
	var transcript: String = level.notation.text()
	for needle in ["travel P1 roar_of_time L0T3 -> L1T1 with P1,E1", "branch L1 from L0T1", "board L1 T1", "unit P1' "]:
		if transcript.find(needle) < 0:
			print("smoke: transcript lacks '%s'; tail:\n%s" % [needle, "\n".join(transcript.split("\n").slice(-14))])
	_assert_true(transcript.find("travel P1 roar_of_time L0T3 -> L1T1 with P1,E1") >= 0 and transcript.find("branch L1 from L0T1") >= 0 and transcript.find("board L1 T1") >= 0 and transcript.find("unit P1' ") >= 0, "the notation records the travel, the branch and the branch board with primed units")
	var active: BattleUnit = level.scheduler.get_active_unit()
	_assert_true(active != null and level.notation.unit_id(active.pawn) in ["P1", "P2", "E1", "E2"], "round 1 on the branch starts with a past unit, not an arrival (%s)" % (level.notation.unit_id(active.pawn) if active != null else "none"))
	level.timeline_map.refresh()
	var grid: GridContainer = level.timeline_map.find_child("Grid", true, false) as GridContainer
	_assert_true(grid != null and grid.columns == 4 and grid.find_child("Board_L1_T1", true, false) != null and grid.find_child("Board_L0_T3", true, false) != null and grid.get_child_count() == 12, "the timeline map lays out both timelines across three turns (%d cells, %d columns)" % [grid.get_child_count() if grid != null else -1, grid.columns if grid != null else -1])
	_assert_true(level.multiverse.board_label().begins_with("L+1 T1"), "the HUD chip names the focused board (%s)" % level.multiverse.board_label())
	var actors_round_1: Array[String] = await _play_round_collect()
	_assert_true(not actors_round_1.has("P1'") and not actors_round_1.has("E1'") and actors_round_1.size() == 4, "arrivals rest during the round they arrived in (%s)" % str(actors_round_1))
	var actors_round_2: Array[String] = await _play_round_collect()
	_assert_true(actors_round_2.has("E1'") and not actors_round_2.has("P1'"), "the dragged arrival acts from the next round while the Roar of Time user spends its recharge (%s)" % str(actors_round_2))
	_assert_true(mv.state.latest(1).turn == 3 and mv.state.present() == 3, "the branch has caught up to T3 (present %d)" % mv.state.present())
	_assert_true(mv.switches == 1 and mv.state.focus == Vector2i(0, 3) and mv.last_switch_reason == "present", "the moment both boards sit at the present the game returns to timeline 0 first (switches %d, focus %s)" % [mv.switches, str(mv.state.focus)])
	_assert_true(level.round_index == 3 and level.notation.pawn_for_id("P1") == null and level.notation.pawn_for_id("P2") != null, "timeline 0 resumes its mid-round T3 without the travellers")
	var resumed: BattleUnit = level.scheduler.get_active_unit()
	_assert_true(resumed != null and level.notation.unit_id(resumed.pawn) == String(origin_queue[0]), "timeline 0 resumes with the unit that was next when Dialga left (%s)" % (level.notation.unit_id(resumed.pawn) if resumed != null else "none"))
	var remainder: Array[String] = await _play_round_collect()
	_assert_true(remainder.size() == 2 and mv.switches == 2 and mv.state.focus == Vector2i(1, 3) and mv.state.latest(0).turn == 4, "after timeline 0 finishes its round the game hands play back to the branch, which still owes T3 (%s)" % str(remainder))
	_assert_true(not level.battle_finished and level.notation.text().find("present L0 T3") >= 0 and level.notation.text().find("present L1 T3") >= 0, "the battle continues and both switches are written to the notation")
	_finish()


func _wait_for_active(id: String) -> TacticsPawn:
	var guard: int = 0
	while guard < 40:
		var active: BattleUnit = await _next_active()
		if active == null:
			return null
		if level.notation.unit_id(active.pawn) == id:
			return active.pawn
		await _play_turn(active.pawn)
		guard += 1
	return null


func _play_rounds_until(round_target: int) -> void:
	var guard: int = 0
	while level.round_index < round_target and guard < 60:
		var active: BattleUnit = await _next_active()
		if active == null:
			break
		await _play_turn(active.pawn)
		guard += 1


func _play_round_collect() -> Array[String]:
	var actors: Array[String] = []
	var start_round: int = level.round_index
	var start_focus: Vector2i = level.multiverse.state.focus
	var guard: int = 0
	while guard < 30:
		var active: BattleUnit = await _next_active()
		if active == null:
			break
		if level.round_index != start_round or level.multiverse.state.focus != start_focus:
			break
		actors.append(level.notation.unit_id(active.pawn))
		await _play_turn(active.pawn)
		guard += 1
	return actors


func _next_active() -> BattleUnit:
	var frames: int = 0
	while frames < 600:
		var active: BattleUnit = level.scheduler.get_active_unit()
		if active != null and active.pawn != null and is_instance_valid(active.pawn) and not level.is_presentation_busy():
			return active
		if level.battle_finished:
			return null
		await physics_frame
		frames += 1
	return null


func _play_turn(pawn: TacticsPawn) -> void:
	var target: TacticsPawn = _foe_of(pawn)
	if target != null and pawn.stats.move_slots.size() > 1 and pawn.stats.has_pp(1) and Targeting.legal_targets_for_move(pawn, pawn.stats.move_slots[1], level.units_on_map()).has(target):
		await driver._attack(pawn, 1, target)
	await driver._end_turn(pawn)


func _foe_of(pawn: TacticsPawn) -> TacticsPawn:
	var foes: Node = level.opponent if pawn.get_parent() == level.player else level.player
	for child in foes.get_children():
		if child is TacticsPawn and (child as TacticsPawn).is_alive():
			return child
	return null


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)


func _finish() -> void:
	if failures > 0:
		push_error("smoke: roar_of_time failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: roar_of_time clean")
	quit(0)
