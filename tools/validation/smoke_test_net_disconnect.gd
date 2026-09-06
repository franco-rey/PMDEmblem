extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE: String = "match seed=21 mode=pvp p=0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember,scratch:blaze|0001_bulbasaur@50:tackle:overgrow"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _case("resign")
	await _case("disconnect")
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
	session.disconnect_grace_seconds = 0.05
	session.use_test_link(pair[0], true)
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
	else:
		fake.close("cable")
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
		_assert_true(result == TacticsLevel.RESULT_PLAYER_WIN, "disconnect: the remaining player wins (%d)" % result)
		_assert_true(transcript.contains("reason=disconnect"), "disconnect: the transcript records the lost connection")
	_assert_true(session.state == NetSession.ENDED, "%s: the session ends with the battle" % kind)
	session.leave("test")
	session.queue_free()
	if is_instance_valid(driver.main):
		driver.main.queue_free()
	await process_frame
	await process_frame


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
