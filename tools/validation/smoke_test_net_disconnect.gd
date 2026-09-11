extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE: String = "match seed=21 mode=pvp p=0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember,scratch:blaze|0001_bulbasaur@50:tackle:overgrow"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _case("resign")
	await _case("disconnect")
	await _case("rejoin")
	_finish()


func _case(kind: String) -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(ok, "%s: the battle launches" % kind)
	if not ok:
		return
	var level: TacticsLevel = driver.level
	var pair: Array = LoopbackLink.pair()
	var session := NetSession.new()
	session.local_name = "host"
	root.add_child(session)
	session.suspend_seconds = 0.05
	session.use_test_link(pair[0], true)
	session.battle_id = "loopback-%s" % kind
	session.pending_code = CODE
	var fake: LoopbackLink = pair[1]
	session.attach_level(level)
	level.net_session = session
	session.mark_ready()
	fake.send(NetMessages.build(NetMessages.BATTLE_READY, {"battle_id": session.battle_id}))
	for i in range(4):
		fake.poll()
		await physics_frame
	var ended: Array[String] = []
	level.battle_ended.connect(func(result: int) -> void: ended.append("%d|%s" % [result, level.notation.text()]))
	if kind == "resign":
		session.resign()
	elif kind == "disconnect":
		fake.close("cable")
		await physics_frame
		_assert_true(session.state == NetSession.SUSPENDED, "disconnect: the session suspends instead of ending (%d)" % session.state)
		_assert_true(level.ui_control == null or not level.ui_control.remote_turn or session.remote_turn_active(), "disconnect: the host keeps its own turns")
		for i in range(30):
			await physics_frame
		_assert_true(session.suspend_expired(), "disconnect: the wait expires")
		_assert_true(ended.is_empty(), "disconnect: expiry alone does not end the battle")
		session.claim_win()
	else:
		await _rejoin_case(session, level, fake)
		session.leave("test")
		session.queue_free()
		if is_instance_valid(driver.main):
			driver.main.queue_free()
		await process_frame
		await process_frame
		return
	for i in range(30):
		fake.poll()
		await physics_frame
	_assert_true(ended.size() == 1, "%s: the battle ends for the local player" % kind)
	if ended.is_empty():
		session.queue_free()
		return
	var parts: PackedStringArray = ended[0].split("|", true, 1)
	var result: int = int(parts[0])
	var transcript: String = parts[1]
	if kind == "resign":
		_assert_true(result == TacticsLevel.RESULT_PLAYER_LOSS, "resign: the player who resigned loses (%d)" % result)
		_assert_true(transcript.contains("reason=resign"), "resign: the transcript records the resignation")
	else:
		_assert_true(result == TacticsLevel.RESULT_PLAYER_WIN, "disconnect: the remaining player wins the claim (%d)" % result)
		_assert_true(transcript.contains("reason=abandon"), "disconnect: the transcript records the abandoned battle")
	_assert_true(session.state == NetSession.ENDED, "%s: the session ends with the battle" % kind)
	session.leave("test")
	session.queue_free()
	if is_instance_valid(driver.main):
		driver.main.queue_free()
	await process_frame
	await process_frame


func _rejoin_case(session: NetSession, level: TacticsLevel, fake: LoopbackLink) -> void:
	session.suspend_seconds = 30.0
	var seen: Array[Dictionary] = []
	fake.close("cable")
	await physics_frame
	_assert_true(session.state == NetSession.SUSPENDED, "rejoin: the host suspends when the guest drops")
	var again: Array = LoopbackLink.pair()
	session.accept_rejoin_test_link(again[0])
	var back: LoopbackLink = again[1]
	back.received.connect(func(message: Dictionary) -> void: seen.append(message))
	back.send(NetMessages.build(NetMessages.HELLO, {"protocol": NetMessages.PROTOCOL, "version": GameSettings.GAME_VERSION, "name": "stranger", "content": NetMessages.content_fingerprint()}))
	for i in range(4):
		back.poll()
		await physics_frame
	_assert_true(not seen.is_empty() and String(seen[0].get("k", "")) == NetMessages.REJECT and String(seen[0].get("reason", "")) == "busy", "rejoin: a fresh hello during the battle is refused as busy")
	seen.clear()
	back.send(NetMessages.build(NetMessages.REJOIN, {"battle_id": "other", "name": "guest"}))
	for i in range(4):
		back.poll()
		await physics_frame
	_assert_true(not seen.is_empty() and String(seen[0].get("reason", "")) == "no_battle", "rejoin: a rejoin for another battle is refused")
	seen.clear()
	back.send(NetMessages.build(NetMessages.REJOIN, {"battle_id": session.battle_id, "name": "guest"}))
	for i in range(30):
		back.poll()
		await physics_frame
		if not seen.is_empty():
			break
	_assert_true(not seen.is_empty() and String(seen[0].get("k", "")) == NetMessages.CATCHUP, "rejoin: the host answers a matching rejoin with a catch-up")
	if seen.is_empty():
		return
	var catchup: Dictionary = seen[0]
	var lines: Array = catchup.get("lines", [])
	_assert_true(lines.size() == level.notation.lines.size() and int(catchup.get("count", -1)) == lines.size(), "rejoin: the catch-up carries every notation line (%d)" % lines.size())
	_assert_true(String(catchup.get("chain", "")) == NetMessages.chain_of(level.notation.lines), "rejoin: the catch-up chain matches the notation")
	_assert_true(String(catchup.get("code", "")) == session.pending_code and String(catchup.get("battle_id", "")) == session.battle_id, "rejoin: the catch-up names the same code and battle")
	_assert_true(session.state == NetSession.SUSPENDED, "rejoin: the host stays suspended until the guest is ready")
	seen.clear()
	back.send(NetMessages.build(NetMessages.BATTLE_READY, {"battle_id": session.battle_id}))
	for i in range(4):
		back.poll()
		await physics_frame
	_assert_true(session.state == NetSession.IN_BATTLE, "rejoin: battle_ready resumes the host (%d)" % session.state)
	_assert_true(session.ready_to_play(), "rejoin: both sides count as ready after the resume")
	_assert_true(session.suspend_remaining() == 0.0, "rejoin: the countdown clears on resume")


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)


func _finish() -> void:
	if failures > 0:
		push_error("smoke: net_disconnect failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: net_disconnect clean")
	quit(0)
