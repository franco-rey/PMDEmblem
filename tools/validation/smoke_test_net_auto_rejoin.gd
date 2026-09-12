extends SmokeCase


func _run() -> void:
	var session := NetSession.new()
	session.local_name = "guest"
	root.add_child(session)
	await process_frame
	session.host_role = false
	session._join_address = "127.0.0.1"
	session._join_port = 1
	session.battle_id = "auto-1"
	session.state = NetSession.IN_BATTLE
	session._suspend("cable")
	_assert_true(session.suspended() and session.rejoin_attempts == 0 and session.can_rejoin(), "a suspended guest starts with no attempts and may rejoin")
	session._tick_suspension(1.0)
	_assert_true(session.rejoin_attempts == 0, "the first retry waits a moment for the host to re-listen")
	session._tick_suspension(1.5)
	_assert_true(session.rejoin_attempts == 1 and session.rejoining() and session.link is EnetLink, "the first automatic attempt fires after two seconds")
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 15000 and session.rejoining():
		await process_frame
	_assert_true(not session.rejoining() and session.suspended(), "an unreachable host leaves the guest suspended and not rejoining (%s)" % session.last_reason)
	session._tick_suspension(4.0)
	_assert_true(session.rejoin_attempts == 1, "retries wait five seconds between attempts")
	session._tick_suspension(1.5)
	_assert_true(session.rejoin_attempts == 2, "the next automatic attempt fires after the wait")
	session.auto_rejoin = false
	started = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 15000 and session.rejoining():
		await process_frame
	session._tick_suspension(30.0)
	_assert_true(session.rejoin_attempts == 2, "auto-rejoin off leaves the manual button in charge")
	session.leave("test")
	session.queue_free()
	await process_frame
	_finish("net_auto_rejoin")
