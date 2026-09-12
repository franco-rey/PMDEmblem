extends SmokeCase


func _board(t: int, player_alive: int = 2, enemy_alive: int = 2) -> BoardSnapshot:
	var board := BoardSnapshot.new()
	board.turn = t
	for i in range(player_alive):
		board.units.append({"id": "P%d" % (i + 1), "team": 0, "alive": true})
	for i in range(enemy_alive):
		board.units.append({"id": "E%d" % (i + 1), "team": 1, "alive": true})
	board.scheduler = {"order": board.unit_ids(), "queue": board.unit_ids()}
	return board


func _run() -> void:
	var state := MultiverseState.new()
	state.add_root(_board(1))
	for t in range(2, 8):
		state.advance(0, _board(t))
	_assert_true(state.active_band() == 1 and state.active_timelines() == [0] and state.present() == 7, "one timeline: band 1, present is its latest turn")
	_assert_true(state.next_timeline_index(MultiverseState.SIDE_PLAYER) == 1 and state.next_timeline_index(MultiverseState.SIDE_ENEMY) == -1, "new timelines take +1 for the player and -1 for the enemy (cwmtt getNewL)")
	var l1: int = state.branch(Vector2i(0, 3), state.board(0, 3).duplicate_board(), MultiverseState.SIDE_PLAYER)
	_assert_true(l1 == 1 and state.latest(1).turn == 3 and state.latest(1).timeline == 1, "a Roar of Time branch from L0T3 opens L+1 at T3")
	_assert_true(state.active_band() == 1 and state.active_timelines() == [0, 1] and state.present() == 3, "the branch is active and the present falls back to T3")
	_assert_true(state.owed_boards() == [Vector2i(1, 3)], "the only owed board is the branch at the present")
	var l2: int = state.branch(Vector2i(0, 5), state.board(0, 5).duplicate_board(), MultiverseState.SIDE_PLAYER)
	_assert_true(l2 == 2 and not state.is_active(2) and state.active_timelines() == [0, 1], "a second player branch is outside the band (min(0, 2) + 1 = 1) and inactive")
	_assert_true(state.present() == 3, "inactive timelines do not move the present")
	var lm1: int = state.branch(Vector2i(0, 6), state.board(0, 6).duplicate_board(), MultiverseState.SIDE_ENEMY)
	_assert_true(lm1 == -1 and state.active_band() == 2 and state.active_timelines() == [-1, 0, 1, 2], "an enemy branch widens the band to 2 and reactivates L+2 (cwmtt numActive)")
	_assert_true(state.present() == 3 and state.owed_boards() == [Vector2i(1, 3)], "present stays at the earliest active latest board")
	state.advance(1, _board(4))
	state.advance(1, _board(5))
	_assert_true(state.present() == 5 and state.owed_boards() == [Vector2i(1, 5), Vector2i(2, 5)], "as the branch catches up the present advances and boards at that turn are owed, lower index first")
	state.advance(1, _board(6))
	state.advance(2, _board(6))
	_assert_true(state.owed_boards() == [Vector2i(1, 6), Vector2i(-1, 6), Vector2i(2, 6)], "at a shared turn every active latest board at the present is owed (L0 sits ahead at T7), ordered by distance with the player side first")
	_assert_true(state.next_owed(Vector2i(1, 6)) == Vector2i(-1, 6) and state.next_owed(Vector2i(2, 6)) == Vector2i(1, 6), "the next owed board follows that order and wraps")

	var dims: Array[int] = state.dimensions_at(6, 0)
	_assert_true(dims == [-1, 1, 2], "Spacial Rend sees every other active timeline whose latest board is at the same turn")
	_assert_true(state.dimensions_at(9, 0).is_empty(), "no dimension qualifies at a turn nobody has reached")
	var past: Array[BoardSnapshot] = state.past_boards(0, 6)
	_assert_true(past.size() == 5 and past[0].turn == 1 and past[4].turn == 5, "past boards of a timeline are every board before the given turn")
	var seven: BoardSnapshot = _board(7, 1, 0)
	state.advance(0, seven)
	_assert_true(state.standing_total(1) == 6 and state.standing_total(0) == 7 and state.latest(0).standing(1) == 0, "standing counts sum over active latest boards")
	_assert_true(MultiverseState.label(0) == "L0" and MultiverseState.label(2) == "L+2" and MultiverseState.label(-1) == "L-1", "timeline labels carry the creator sign")
	var copy: BoardSnapshot = state.latest(1).duplicate_board()
	copy.remove_unit("P1")
	_assert_true(not copy.has_unit("P1") and state.latest(1).has_unit("P1") and not (copy.scheduler["queue"] as Array).has("P1"), "duplicating a board is deep and removing a unit also drops it from the queue")
	var travelled := MultiverseState.new()
	travelled.add_root(_board(1))
	travelled.advance(0, _board(2))
	var first_base: Array = travelled.opening_board(0, 2).unit_ids()
	var live: BoardSnapshot = _board(2, 1, 2)
	live.mid_round = true
	travelled.replace_latest(0, live)
	var second_base: Array = travelled.opening_board(0, 2).unit_ids()
	_assert_true(first_base == second_base and second_base.size() == 4, "two branches from one coordinate see the same opening board after a mid-round travel replaced the latest")
	_assert_true(travelled.latest(0).mid_round and travelled.latest(0).unit_ids().size() == 3, "the timeline itself still resumes from the mid-round board")
	_finish("multiverse_model")
