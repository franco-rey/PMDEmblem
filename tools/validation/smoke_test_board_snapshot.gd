extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")

var driver = null
var level: TacticsLevel = null


func _run() -> void:
	driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=9 mode=pvp multiverse=1 p=0025_pikachu@50:thunderbolt,quick_attack,agility:static|0004_charmander@50:ember,growl:blaze e=0001_bulbasaur@50:tackle,growth:overgrow|0007_squirtle@50:tackle,withdraw:torrent")
	_assert_true(ok, "multiverse battle launches from a code with multiverse=1")
	if not ok:
		_finish("board_snapshot")
		return
	level = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var mv: MultiverseController = level.multiverse
	_assert_true(mv.enabled and mv.state.timelines.has(0) and mv.state.latest(0).turn == 1 and mv.state.latest(0).units.size() == 4, "the root board is captured at turn 1 with every unit")
	_assert_true(mv.state.latest(0).unit_ids() == ["P1", "P2", "E1", "E2"], "root units carry the notation ids (%s)" % str(mv.state.latest(0).unit_ids()))
	var pikachu: TacticsPawn = level.notation.pawn_for_id("P1")
	var bulbasaur: TacticsPawn = level.notation.pawn_for_id("E1")
	var pp_before: int = pikachu.stats.current_pp[2]
	await _play_turn(pikachu, 2, pikachu)
	_assert_true(pikachu.stats.current_pp[2] == pp_before - 1, "agility was used before the snapshot (PP %d -> %d)" % [pp_before, pikachu.stats.current_pp[2]])
	var acted: int = 0
	while level.round_index < 2 and acted < 6:
		var active: BattleUnit = await _next_active()
		if active == null:
			break
		await _play_turn(active.pawn, 0, _foe_of(active.pawn))
		acted += 1
	_assert_true(level.round_index == 2 and mv.state.latest(0).turn == 2 and mv.state.boards(0).size() == 2, "finishing round 1 stores the turn 2 board on timeline 0 (round %d, boards %d)" % [level.round_index, mv.state.boards(0).size()])
	var snapshot: BoardSnapshot = mv.capture(true)
	var hp_before: Dictionary = _hp_map()
	var pos_before: Dictionary = _pos_map()
	var stage_before: int = pikachu.stats.get_stat_stage("speed")
	var pp_snapshot: int = pikachu.stats.current_pp[2]
	var queue_before: Array = snapshot.scheduler["queue"]
	_assert_true(snapshot.mid_round and not queue_before.is_empty() and snapshot.units.size() == 4, "a mid-round capture keeps the remaining queue (%s)" % str(queue_before))
	var first: BattleUnit = await _next_active()
	level._ops().damage(bulbasaur, 17, {"kind": "hit", "attacker": first.pawn})
	level._ops().apply_status(bulbasaur, "burn", {}, {"kind": "status", "attacker": first.pawn})
	level._ops().change_stat_stage(first.pawn, "attack", 1, {"kind": "move"})
	await _play_turn(first.pawn, 0, _foe_of(first.pawn))
	var second: BattleUnit = await _next_active()
	await _play_turn(second.pawn, 0, _foe_of(second.pawn))
	_assert_true(_hp_map() != hp_before and bulbasaur.stats.battle_statuses.has("burn"), "damage, a burn and a stat change moved the board past the snapshot")
	mv.restore(snapshot)
	level.scheduler.resume()
	await physics_frame
	await physics_frame
	var pikachu_again: TacticsPawn = level.notation.pawn_for_id("P1")
	_assert_true(pikachu_again != null and is_instance_valid(pikachu_again) and pikachu_again != pikachu, "restore respawns the units under the same notation ids")
	_assert_true(_hp_map() == hp_before, "restore brings every HP back to the captured values (%s vs %s)" % [str(_hp_map()), str(hp_before)])
	_assert_true(_pos_map() == pos_before, "restore puts every unit back on its captured tile")
	_assert_true(pikachu_again.stats.get_stat_stage("speed") == stage_before and pikachu_again.stats.current_pp[2] == pp_snapshot, "stat stages and PP come back with the unit")
	var bulbasaur_again: TacticsPawn = level.notation.pawn_for_id("E1")
	_assert_true(bulbasaur_again != null and not bulbasaur_again.stats.battle_statuses.has("burn") and level.notation.pawn_for_id(String(queue_before[0])).stats.get_stat_stage("attack") == 0, "statuses and stages added after the capture are gone on restore")
	_assert_true(level.round_index == 2 and level.battle_units.size() == 4, "round counter and unit list match the board")
	var active_after: BattleUnit = level.scheduler.get_active_unit()
	_assert_true(active_after != null and level.notation.unit_id(active_after.pawn) == String(queue_before[0]), "play resumes with the unit that was next in the captured queue (%s)" % (level.notation.unit_id(active_after.pawn) if active_after != null else "none"))
	var resumed: TacticsPawn = active_after.pawn
	await _play_turn(resumed, 0, _foe_of(resumed))
	var following: BattleUnit = await _next_active()
	_assert_true(following != null and following.pawn != resumed and following.pawn.is_alive(), "the restored board plays on: the turn passes to the next unit")
	_assert_true(level.notation.text().find("T") >= 0, "notation keeps writing after the restore")
	_finish("board_snapshot")


func _next_active() -> BattleUnit:
	var frames: int = 0
	while frames < 600:
		var active: BattleUnit = level.scheduler.get_active_unit()
		if active != null and active.pawn != null and is_instance_valid(active.pawn) and not level.is_presentation_busy():
			return active
		await physics_frame
		frames += 1
	return null


func _play_turn(pawn: TacticsPawn, slot: int, target: TacticsPawn) -> void:
	var frames: int = 0
	while frames < 600 and (level.scheduler.get_active_unit() == null or level.scheduler.get_active_unit().pawn != pawn):
		await physics_frame
		frames += 1
	if target != null and pawn.stats.has_pp(slot) and (target == pawn or Targeting.legal_targets_for_move(pawn, pawn.stats.move_slots[slot], level.units_on_map()).has(target)):
		await driver._attack(pawn, slot, target)
	await driver._end_turn(pawn)


func _foe_of(pawn: TacticsPawn) -> TacticsPawn:
	var foes: Node = level.opponent if pawn.get_parent() == level.player else level.player
	for child in foes.get_children():
		if child is TacticsPawn and (child as TacticsPawn).is_alive():
			return child
	return null


func _hp_map() -> Dictionary:
	var out: Dictionary = {}
	for pawn in level.units_on_map():
		out[level.notation.unit_id(pawn)] = pawn.stats.curr_health
	return out


func _pos_map() -> Dictionary:
	var out: Dictionary = {}
	for pawn in level.units_on_map():
		out[level.notation.unit_id(pawn)] = Targeting._tile_key(pawn.get_tile()) if pawn.get_tile() != null else Vector3i(-1, -1, -1)
	return out
