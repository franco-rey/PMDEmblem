extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")


func _run() -> void:
	_value_checks()
	_band_checks()
	_hop_checks()
	_branch_checks()
	_direction_checks()
	_level_checks()
	_determinism_checks()
	await _live_checks()
	_finish("multiverse_policy")


func _value_checks() -> void:
	var strong: Dictionary = _record(0, true, 120.0, 200.0, 200.0)
	var weak: Dictionary = _record(0, true, 40.0, 60.0, 60.0)
	_assert_true(MultiversePolicy.unit_value(strong) > MultiversePolicy.unit_value(weak), "a bulkier, harder hitting unit is worth more")
	var hurt: Dictionary = _record(0, true, 120.0, 20.0, 200.0)
	_assert_true(MultiversePolicy.strength([hurt], 0) < MultiversePolicy.strength([strong], 0), "strength is health weighted, so a past board restores value the present has already taken")
	_assert_true(is_equal_approx(MultiversePolicy.margin([strong, weak], MultiverseState.SIDE_ENEMY), -MultiversePolicy.unit_value(strong) - MultiversePolicy.unit_value(weak)), "the margin is read from the travelling side's point of view")
	_assert_true(is_equal_approx(MultiversePolicy.risk([strong], MultiverseState.SIDE_PLAYER), 0.0), "a board you are winning carries no risk")
	_assert_true(MultiversePolicy.strike_value([hurt], MultiverseState.SIDE_ENEMY) > MultiversePolicy.strike_value([strong], MultiverseState.SIDE_ENEMY), "the strike target of choice is the valuable unit that is already hurt")
	_assert_true(MultiversePolicy.standing([strong, weak, _record(0, false, 40.0, 0.0, 60.0)], 0) == 2, "fainted units do not stand")


func _band_checks() -> void:
	_assert_true(MultiversePolicy.lands_frozen("branch", 1, 0), "a branch lands frozen once you have created more timelines than the opponent")
	_assert_true(MultiversePolicy.lands_frozen("new", 2, 1), "a fresh universe is bound by the same band rule")
	_assert_true(not MultiversePolicy.lands_frozen("branch", 1, 1), "a branch lands active while the branch counts are level")
	_assert_true(not MultiversePolicy.lands_frozen("hop", 3, 0), "hops are exempt from the band rule because they create no timeline")
	var frozen: Dictionary = _mixed_context()
	frozen["mine"] = 1
	frozen["theirs"] = 0
	_assert_true(MultiversePolicy.decide([_branch_option(6, _good_board())], frozen) == -1, "a branch that would arrive on a frozen timeline is declined")
	_assert_true(MultiversePolicy.decide([_branch_option(6, _good_board()), _hop_option(_needy_board())], frozen) == 1, "the band guard rejects the branch and still takes the hop")


func _hop_checks() -> void:
	var context: Dictionary = _mixed_context()
	_assert_true(MultiversePolicy.decide([_hop_option(_needy_board())], context) == 0, "a hop to a board that is losing without you is taken")
	_assert_true(MultiversePolicy.decide([_hop_option(_good_board())], context) == -1, "a hop that helps nobody is declined")
	var two: Array = [_hop_option(_good_board()), _hop_option(_needy_board())]
	_assert_true(MultiversePolicy.decide(two, context) == 1, "the neediest destination wins among hops")


func _branch_checks() -> void:
	var context: Dictionary = _mixed_context()
	_assert_true(MultiversePolicy.decide([_branch_option(6, _good_board())], context) == 0, "a branch worth more than the option it spends is taken")
	_assert_true(MultiversePolicy.decide([_branch_option(6, _good_board()), _hop_option(_needy_board())], context) == 1, "a hop is preferred to a branch when both are available")
	var costly: Dictionary = _mixed_context()
	costly["option_cost"] = 100.0
	_assert_true(MultiversePolicy.decide([_branch_option(6, _good_board())], costly) == 0, "the same branch survives an option cost it still outscores")
	costly["option_cost"] = 400.0
	_assert_true(MultiversePolicy.decide([_branch_option(6, _good_board())], costly) == -1, "a branch right priced above the force that would arrive is turned down")

	var ahead: Dictionary = _mixed_context()
	ahead["origin_pre"] = _team(0, 3) + _team(1, 1)
	ahead["origin_post"] = _team(0, 2) + _team(1, 1)
	ahead["global_margin"] = MultiversePolicy.margin(ahead["origin_pre"], MultiverseState.SIDE_PLAYER)
	_assert_true(MultiversePolicy.decide([_branch_option(6, _level_board())], ahead) == -1, "while ahead the CPU refuses a branch to a board where it was doing worse, because the destination roster resurrects the enemy")

	var veto: Dictionary = _mixed_context()
	veto["option_cost"] = 0.0
	veto["global_margin"] = -400.0
	veto["origin_pre"] = _team(0, 3) + _team(1, 1)
	veto["origin_post"] = _team(0, 2) + _team(1, 1)
	_assert_true(MultiversePolicy.decide([_branch_option(6, _level_board())], veto) == 0, "a branch no worse than the board it leaves is allowed while that board is still being won")
	_assert_true(MultiversePolicy.decide([_branch_option(6, _poor_board())], veto) == -1, "the destination margin veto fires on the same offer once the destination board is the worse one")

	var behind: Dictionary = _mixed_context()
	behind["origin_pre"] = _team(0, 1) + _team(1, 3)
	behind["origin_post"] = _team(0, 1) + _team(1, 3)
	behind["travellers"] = []
	behind["global_margin"] = MultiversePolicy.margin(behind["origin_pre"], MultiverseState.SIDE_PLAYER)
	_assert_true(MultiversePolicy.decide([_branch_option(6, _level_board())], behind) == 0, "while behind the same level board is worth the branch right")

	var level_new: Dictionary = _mixed_context()
	level_new["global_margin"] = MultiversePolicy.margin(level_new["origin_board"], MultiverseState.SIDE_PLAYER)
	_assert_true(MultiversePolicy.decide([_new_option(9)], level_new) == 0, "a fresh universe that duplicates the CPU's own traveller is taken even while ahead, because the multiverse gains a copy of that unit")
	var gift_new: Dictionary = _mixed_context()
	gift_new["travellers"] = _team(1, 1)
	gift_new["global_margin"] = MultiversePolicy.margin(gift_new["origin_board"], MultiverseState.SIDE_PLAYER)
	_assert_true(MultiversePolicy.decide([_new_option(9)], gift_new) == -1, "a fresh universe that only duplicates the opponent's traveller is refused, because the copy is a gift to the other side")
	var lifeline: Dictionary = _mixed_context()
	lifeline["origin_pre"] = _team(0, 1) + _team(1, 3)
	lifeline["origin_post"] = _team(0, 1) + _team(1, 3)
	lifeline["origin_board"] = _team(0, 1) + _team(1, 3)
	lifeline["travellers"] = []
	lifeline["global_margin"] = MultiversePolicy.margin(lifeline["origin_board"], MultiverseState.SIDE_PLAYER)
	_assert_true(MultiversePolicy.decide([_new_option(9)], lifeline) == 0, "the same fresh universe is taken as a lifeline once losing it means elimination, since the enemy must now clear two boards")

	var last_board: Dictionary = _mixed_context()
	last_board["origin_pre"] = _team(0, 1) + _team(1, 1)
	last_board["origin_post"] = _team(1, 1)
	_assert_true(MultiversePolicy.decide([_branch_option(6, _good_board())], last_board) == -1, "a self only travel that empties a board the CPU was not losing is declined")


func _direction_checks() -> void:
	var defending: Dictionary = _mixed_context()
	defending["origin_pre"] = _team(0, 1) + _team(1, 3)
	defending["origin_post"] = _team(0, 1) + _team(1, 3)
	defending["travellers"] = []
	defending["global_margin"] = MultiversePolicy.margin(defending["origin_pre"], MultiverseState.SIDE_PLAYER)
	var pair: Array = [_branch_option(6, _level_board()), _branch_option(3, _level_board())]
	_assert_true(MultiversePolicy.decide(pair, defending) == 1, "a defensive branch reaches for the earliest board it can, for the deepest roster reset and the longest suspension")

	var attacking: Dictionary = _mixed_context()
	attacking["travellers"] = []
	_assert_true(MultiversePolicy.decide([_branch_option(6, _good_board()), _branch_option(3, _good_board())], attacking) == 0, "an offensive branch takes the shallowest board that still wins, keeping the replay debt small")


func _level_checks() -> void:
	var context: Dictionary = _mixed_context()
	var branch: Array = [_branch_option(6, _good_board())]
	var hop: Array = [_hop_option(_needy_board())]
	for value in [1, 2, 3, 4, 5]:
		context["level"] = value
		context["noise"] = 0.0
		_assert_true(MultiversePolicy.decide(branch, context) == 0, "level %d opens a timeline when the branch is clearly good" % value)
		_assert_true(MultiversePolicy.decide(hop, context) == 0, "level %d takes a free hop" % value)
	var noisy: Dictionary = _mixed_context()
	noisy["level"] = 1
	noisy["noise"] = AIProfile.for_level(1).value_noise * MultiversePolicy.TRAVEL_NOISE_SCALE
	_assert_true(noisy["noise"] > 0.0, "the lowest tier carries travel judgement noise")
	_assert_true(AIProfile.for_level(5).value_noise == 0.0, "the top tier judges travel without noise")
	_assert_true(MultiversePolicy.judgement(noisy, 0) != 0.0, "noise actually moves a low tier's travel score")
	_assert_true(MultiversePolicy.judgement(noisy, 0) == MultiversePolicy.judgement(noisy, 0), "travel judgement noise is a pure function of seed and option, so peers agree")


func _determinism_checks() -> void:
	var context: Dictionary = _mixed_context()
	var options: Array = [_branch_option(6, _good_board()), _branch_option(3, _good_board()), _hop_option(_needy_board())]
	var first: int = MultiversePolicy.decide(options, context)
	var stable: bool = true
	for i in range(32):
		if MultiversePolicy.decide(options, context) != first:
			stable = false
	_assert_true(stable, "the same offer decides the same way every time, with no RNG in the policy")
	var source: String = FileAccess.get_file_as_string("res://data/models/world/multiverse/multiverse_policy.gd")
	var clean: bool = true
	for token in ["rand", "RandomNumberGenerator", "Time.", "randi", "randf", "shuffle", "keys()"]:
		if source.find(token) >= 0:
			clean = false
			push_error("smoke: policy source mentions %s" % token)
	_assert_true(clean, "the policy source carries no randomness, wall clock or unordered iteration")


func _live_checks() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=11 mode=bots map=chessboard multiverse=1 ai=5 p=0483_dialga@50:roar_of_time,dragon_claw,flash_cannon,earth_power:pressure|0025_pikachu@50:thunderbolt,quick_attack:static e=0484_palkia@50:spacial_rend,aqua_tail,dragon_claw,earth_power:pressure|0003_venusaur@50:giga_drain,sludge_bomb:overgrow")
	_assert_true(ok, "the multiverse battle launches")
	if not ok:
		return
	var level: TacticsLevel = driver.level
	var mv: MultiverseController = level.multiverse
	_assert_true(level.multiverse_enabled, "the multiverse rule set is on for the live checks")
	level.opponent.opponent_serv._sync_ai_level(level)
	_assert_true(mv.cpu_policy.is_valid(), "the opponent service installs the travel policy when it syncs the AI level")

	mv.enabled = true
	if mv.state.timelines.is_empty():
		mv.on_round_building()
	var root: BoardSnapshot = mv.state.latest(0)
	_assert_true(root != null and not root.units.is_empty(), "the root board is captured for the live context")
	if root == null:
		return
	var dialga: TacticsPawn = level.notation.pawn_for_id("P1")
	var palkia: TacticsPawn = level.notation.pawn_for_id("E1")
	var policy := MultiversePolicy.new()
	policy.setup(mv)
	var pending: Dictionary = {"move_id": "roar_of_time", "user": dialga, "target": palkia, "side": MultiverseState.SIDE_PLAYER, "serial": 1}
	var context: Dictionary = policy.context_for(pending)
	_assert_true(int(context["mine"]) == 0 and int(context["theirs"]) == 0, "a fresh battle has spent no branch rights")
	_assert_true((context["travellers"] as Array).size() == 2, "Roar of Time drags its target along, so both units leave the origin")
	_assert_true((context["origin_pre"] as Array).size() == (context["origin_post"] as Array).size() + 2, "the origin the policy scores is the board after the travellers have gone")
	_assert_true(float(context["option_cost"]) > 0.0, "the branch right is priced from the strongest unit on the field")
	_assert_true(is_equal_approx(float(context["unfreeze_margin"]), 0.0), "with no frozen timeline there is nothing for a branch to thaw")

	var options: Array = [{"kind": "branch", "from": root.coords(), "label": "L0 T1", "board": root}]
	level.ai_level = 1
	_assert_true(policy.choose(options, pending) == -1, "a level 1 CPU declines a live branch offer")
	level.ai_level = 5
	mv.state.created_by_player = 1
	_assert_true(policy.choose(options, pending) == -1, "a level 5 CPU declines a live branch that would arrive frozen")
	mv.state.created_by_player = 0

	for child in level.player.get_children():
		if child is TacticsPawn:
			(child as TacticsPawn).stats.curr_health = maxi(1, (child as TacticsPawn).stats.max_health / 20)
	level.round_index = 5
	_assert_true(mv.request_travel("roar_of_time", dialga, palkia) == 1, "a past board on the focus timeline is offered once the battle has a history")
	var desperate: int = policy.choose(mv.pending_travel["options"], mv.pending_travel)
	_assert_true(desperate == 0, "a CPU one board from elimination takes the branch back to the turn its roster was whole")
	if desperate < 0:
		return
	_assert_true(mv.commit_travel(desperate), "the accepted branch commits")
	_assert_true(mv.travels == 1 and mv.state.timeline_ids().size() == 2, "the commit opened exactly one new timeline")
	var opened: int = mv.state.next_timeline_index(MultiverseState.SIDE_PLAYER) - 1
	_assert_true(mv.state.is_active(opened), "the timeline the policy opened is inside the active band, so the traveller still counts toward the standing total")


func _mixed_context() -> Dictionary:
	return {
		"level": 5,
		"side": MultiverseState.SIDE_PLAYER,
		"mine": 0,
		"theirs": 0,
		"turn": 9,
		"strike": false,
		"origin_pre": _team(0, 2) + _team(1, 1),
		"origin_post": _team(0, 1) + _team(1, 1),
		"travellers": _team(0, 1),
		"origin_board": _team(0, 2) + _team(1, 1),
		"global_margin": 0.0,
		"standing_mine": 1,
		"unfreeze_margin": 0.0,
		"option_cost": 50.0,
	}


func _good_board() -> BoardSnapshot:
	return _board(_team(0, 2) + _team(1, 1))


func _level_board() -> BoardSnapshot:
	return _board(_team(0, 2) + _team(1, 2))


func _poor_board() -> BoardSnapshot:
	return _board(_team(0, 1) + _team(1, 2))


func _needy_board() -> BoardSnapshot:
	return _board(_team(1, 2))


func _branch_option(turn: int, board: BoardSnapshot) -> Dictionary:
	board.turn = turn
	return {"kind": "branch", "from": Vector2i(0, turn), "label": "L0 T%d" % turn, "board": board}


func _new_option(turn: int) -> Dictionary:
	return {"kind": "new", "from": Vector2i(0, turn), "label": "Tear a new universe"}


func _hop_option(board: BoardSnapshot) -> Dictionary:
	return {"kind": "hop", "to": 1, "label": "L+1", "board": board}


func _board(records: Array) -> BoardSnapshot:
	var board := BoardSnapshot.new()
	for i in range(records.size()):
		var record: Dictionary = records[i]
		board.units.append({
			"id": "U%d" % i,
			"team": int(record["team"]),
			"alive": bool(record["alive"]),
			"stats": {
				"attack": int(record["offence"]),
				"special_attack": 0,
				"curr_health": int(record["curr_health"]),
				"max_health": int(record["max_health"]),
			},
		})
	return board


func _team(team: int, count: int) -> Array:
	var out: Array = []
	for i in range(count):
		out.append(_record(team, true, 100.0, 100.0, 100.0))
	return out


func _record(team: int, alive: bool, offence: float, curr_health: float, max_health: float) -> Dictionary:
	return {"team": team, "alive": alive, "offence": offence, "curr_health": curr_health, "max_health": max_health}
