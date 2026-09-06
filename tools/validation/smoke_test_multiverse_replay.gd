extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE: String = "match seed=21 mode=pvp map=chessboard multiverse=1 p=0483_dialga@30:roar_of_time,dragon_claw:pressure e=0004_charmander@50:ember,scratch:blaze|0242_blissey@50:seismic_toss,soft_boiled:natural_cure"

var failures: int = 0
var driver = null
var level: TacticsLevel = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var first: Array = await _scenario()
	var second: Array = await _scenario()
	_assert_true(first.size() > 20 and first == second, "the scripted multiverse game is deterministic (%d vs %d lines)" % [first.size(), second.size()])
	if first != second:
		for i in range(mini(first.size(), second.size())):
			if first[i] != second[i]:
				push_error("smoke: first divergence at line %d: %s | %s" % [i, first[i], second[i]])
				break
		print("smoke: RUN1 head:\n%s" % "\n".join(first.slice(0, 30)))
		print("smoke: RUN2 head:\n%s" % "\n".join(second.slice(0, 30)))
	var joined: String = "\n".join(first)
	_assert_true(joined.find("[Notation \"pmdn/2\"]") >= 0 and joined.find("[Multiverse \"1\"]") >= 0, "the transcript declares pmdn/2 and the multiverse flag")
	_assert_true(joined.find("travel P1 roar_of_time L0T4 -> L1T1 with P1,E2") >= 0 and joined.find("branch L1 from L0T1") >= 0, "the transcript carries the travel and branch lines")
	driver = DRIVER.new(self)
	var replay: Dictionary = await driver.run_script(first)
	_assert_true(int(replay.get("failures", 0)) == 0, "replaying the pmdn/2 transcript runs without command failures (%s)" % str(replay.get("log", [])).substr(0, 400))
	var replayed: Array = _body(String(replay.get("notation", "")))
	var original: Array = _body(joined)
	var same: bool = replayed == original
	if not same:
		for i in range(mini(replayed.size(), original.size())):
			if replayed[i] != original[i]:
				push_error("smoke: replay diverges at body line %d: %s | %s" % [i, original[i], replayed[i]])
				break
	_assert_true(same and replayed.size() == original.size(), "the replay rebuilds the same multiverse line for line (%d vs %d)" % [replayed.size(), original.size()])
	_finish()


func _scenario() -> Array:
	driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	if not ok:
		_assert_true(false, "scenario launch")
		return []
	level = driver.level
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var mv: MultiverseController = level.multiverse
	var travelled: bool = false
	var guard: int = 0
	while guard < 60 and not level.battle_finished:
		var active: BattleUnit = await _next_active()
		if active == null:
			break
		var id: String = level.notation.unit_id(active.pawn)
		if id == "P1" and level.round_index == 1:
			await driver._move(active.pawn, "C2")
		elif id == "P1" and level.round_index == 2:
			await driver._move(active.pawn, "B2")
			await driver._attack(active.pawn, 0, level.notation.pawn_for_id("E2"))
			mv.cancel_travel()
		elif id == "P1" and level.round_index == 4 and not travelled:
			await driver._attack(active.pawn, 0, level.notation.pawn_for_id("E2"))
			if not mv.pending_travel.is_empty():
				mv.commit_travel(0)
				travelled = true
				await physics_frame
				await physics_frame
				guard += 1
				continue
		if is_instance_valid(active.pawn) and active.pawn.is_alive() and level.scheduler.get_active_unit() == active:
			await driver._end_turn(active.pawn)
		guard += 1
		if travelled and level.round_index >= 2 and mv.state.focus.x == 1:
			break
	var lines: Array = level.notation.text().split("\n")
	return lines


func _body(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("[") or trimmed.begins_with("result"):
			continue
		out.append(line)
	return out


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


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)


func _finish() -> void:
	if failures > 0:
		push_error("smoke: multiverse_replay failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: multiverse_replay clean")
	quit(0)
