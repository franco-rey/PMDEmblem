extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")

var driver = null
var level: TacticsLevel = null


func _run() -> void:
	driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=13 mode=pvp multiverse=1 p=0484_palkia@50:spacial_rend,aqua_tail:pressure|0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember,scratch:blaze|0720_hoopa@50:hyperspace_hole,psychic:magician")
	_assert_true(ok, "multiverse battle with Palkia and Hoopa launches")
	if not ok:
		_finish("spacial_rend")
		return
	level = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var mv: MultiverseController = level.multiverse
	await _play_rounds_until(2)
	var palkia: TacticsPawn = await _wait_for_active("P1")
	_assert_true(palkia != null and level.round_index == 2, "Palkia acts in round 2 on timeline 0")
	var charmander: TacticsPawn = level.notation.pawn_for_id("E1")
	var rend: PokemonMoveResource = PokemonLearnsetService.load_move("spacial_rend")
	level._ops().damage(charmander, 9, {"kind": "hit", "attacker": palkia, "move": rend})
	BattleMoveSpecials.new().after_hit(null, palkia, charmander, rend, 9, true, level, level.battle_log)
	var options: Array = mv.pending_travel.get("options", [])
	_assert_true(options.size() == 1 and String(options[0].get("kind", "")) == "new", "with a single timeline Spacial Rend can only tear a new universe (%s)" % str(options))
	var participant: TacticsParticipantResource = level.participant.res
	participant.curr_pawn = palkia
	participant.stage = participant.STAGE_SELECT_TRAVEL
	for i in range(3):
		await physics_frame
	var ctrl: TacticsControls = driver.main.get_node_or_null("TacticsControls") as TacticsControls
	var picker: VBoxContainer = ctrl.get_node_or_null("HBox/TravelPicker") as VBoxContainer
	var first_button: Button = picker.get_node_or_null("Option0") as Button if picker != null else null
	_assert_true(picker != null and picker.visible and first_button != null and first_button.text == "Tear a new universe" and _option_count(picker) == 1, "the travel picker shows the single tear option while the human chooses")
	for i in range(3):
		await physics_frame
	_assert_true(picker != null and picker.get_node_or_null("Option0") == first_button and _option_count(picker) == 1, "the picker is built once per travel request, not once per frame")
	ctrl._player_wants_to_travel(0)
	await physics_frame
	await physics_frame
	_assert_true(picker != null and not picker.visible, "choosing an option hides the picker")
	_assert_true(mv.pending_travel.is_empty() and mv.travels == 1, "tearing the universe through the picker succeeds")
	_assert_true(mv.state.created_by_player == 1 and mv.state.timelines.has(1) and mv.state.latest(1).turn == 2, "the new universe is timeline L+1 branched from the current turn (T2)")
	var universe: BoardSnapshot = mv.state.latest(1)
	var ids: Array[String] = universe.unit_ids()
	ids.sort()
	_assert_true(ids == ["E1", "E1'", "E2", "P1", "P1'", "P2"], "the torn universe is a copy of the current board plus both travellers (%s)" % str(universe.unit_ids()))
	var origin: BoardSnapshot = mv.state.latest(0)
	_assert_true(origin.turn == 2 and origin.mid_round and origin.unit_ids() == ["P2", "E2"], "timeline 0 continues mid-round without Palkia and Charmander (%s)" % str(origin.unit_ids()))
	_assert_true(mv.switches == 1 and mv.state.focus == Vector2i(0, 2) and mv.last_switch_reason == "present", "both boards sit at T2, so play returns to timeline 0 to finish its round first (focus %s)" % str(mv.state.focus))
	var rest_of_round: Array[String] = await _play_round_collect()
	_assert_true(rest_of_round.size() == 2 and mv.state.focus == Vector2i(1, 2) and mv.switches == 2, "once timeline 0 finishes T2 the game moves to the new universe, which still owes T2 (%s, focus %s)" % [str(rest_of_round), str(mv.state.focus)])
	var universe_round: Array[String] = await _play_round_collect()
	_assert_true(not universe_round.has("P1'") and not universe_round.has("E1'") and universe_round.size() == 4, "arrivals in the new universe rest through the round they arrived in (%s)" % str(universe_round))
	_assert_true(mv.state.focus == Vector2i(0, 3) and mv.state.present() == 3, "with both timelines at T3 play is back on timeline 0 (focus %s)" % str(mv.state.focus))
	var hoopa: TacticsPawn = await _wait_for_active("E2")
	_assert_true(hoopa != null and mv.state.focus.x == 0, "Hoopa acts on timeline 0 at T3")
	var pikachu: TacticsPawn = level.notation.pawn_for_id("P2")
	var hole: PokemonMoveResource = PokemonLearnsetService.load_move("hyperspace_hole")
	level._ops().damage(pikachu, 8, {"kind": "hit", "attacker": hoopa, "move": hole})
	BattleMoveSpecials.new().after_hit(null, hoopa, pikachu, hole, 8, true, level, level.battle_log)
	var hop_options: Array = mv.pending_travel.get("options", [])
	_assert_true(hop_options.size() == 1 and String(hop_options[0].get("kind", "")) == "hop" and int(hop_options[0].get("to", 0)) == 1, "Hyperspace Hole offers the other timeline at the same turn as a hop (%s)" % str(hop_options.map(func(o: Dictionary) -> String: return String(o.get("label", "")))))
	var created_before: int = mv.state.created_by_enemy
	_assert_true(mv.commit_travel(0), "the hop commits")
	await physics_frame
	await physics_frame
	_assert_true(mv.state.created_by_enemy == created_before and mv.state.timeline_ids() == [0, 1], "a hop creates no timeline")
	_assert_true(mv.state.focus == Vector2i(1, 3), "with no player unit left on timeline 0 it is no longer owed, so play stays on L+1 (focus %s)" % str(mv.state.focus))
	var dest: BoardSnapshot = mv.state.latest(1)
	_assert_true(dest.has_unit("P2'") and dest.has_unit("P2") and dest.turn == 3, "Pikachu alone arrives on L+1 beside its copy there (%s)" % str(dest.unit_ids()))
	_assert_true(not mv.state.latest(0).has_unit("P2") and mv.state.latest(0).has_unit("E2"), "timeline 0 loses Pikachu and keeps Hoopa")
	var transcript: String = level.notation.text()
	_assert_true(transcript.find("travel P1 spacial_rend L0T2 -> L1T2 with P1,E1") >= 0 and transcript.find("branch L1 from L0T2") >= 0 and transcript.find("hop E2 hyperspace_hole L0T3 -> L1T3 with P2") >= 0, "the notation records the torn universe and the hop with the acting unit")
	_assert_true(not level.battle_finished, "the battle continues")
	_finish("spacial_rend")


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


func _option_count(picker: VBoxContainer) -> int:
	var count: int = 0
	for child in picker.get_children():
		if child.name.begins_with("Option") and not child.is_queued_for_deletion():
			count += 1
	return count
