extends SceneTree

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var opener := NetPortOpener.new()
	root.add_child(opener)
	var results: Array = []
	opener.finished.connect(func(result: Dictionary) -> void: results.append(result))
	opener.port = 24555
	opener.state = NetPortOpener.STATE_WORKING
	opener._apply_result({"ok": true, "port": 24555, "address": "203.0.113.5"})
	_assert_true(opener.is_open() and opener.external_address == "203.0.113.5" and opener.detail.contains("203.0.113.5") and opener.detail.contains("24555"), "a successful mapping reports the port and the public address")
	opener.close()
	_assert_true(opener.state == NetPortOpener.STATE_CLOSED and opener.external_address.is_empty() and opener.detail.is_empty(), "closing clears the mapping state")
	opener.port = 24555
	opener.state = NetPortOpener.STATE_WORKING
	opener._apply_result({"ok": false, "port": 24555, "error": "no UPnP gateway answered (-1)"})
	_assert_true(opener.state == NetPortOpener.STATE_FAILED and opener.detail.contains("manually") and results.size() == 2, "a refused mapping tells the host to forward the port by hand")
	opener._apply_result({"ok": true, "port": 9999, "address": "198.51.100.9"})
	_assert_true(opener.state == NetPortOpener.STATE_FAILED, "a stale result for another port is ignored")
	opener.open(24556)
	_assert_true(opener.state == NetPortOpener.STATE_WORKING and opener.detail.contains("24556"), "opening starts the router request in the background")
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 12000 and opener.state == NetPortOpener.STATE_WORKING:
		await create_timer(0.1).timeout
	_assert_true(opener.state == NetPortOpener.STATE_OPEN or opener.state == NetPortOpener.STATE_FAILED, "the background request settles either way (%s: %s)" % [opener.state, opener.detail])
	opener.close()
	var session := NetSession.new()
	session.local_name = "host"
	root.add_child(session)
	await process_frame
	_assert_true(session.port_opener != null and session.router_status().is_empty(), "a session owns a port opener and reports nothing before hosting")
	session.host_role = true
	session.port_opener.port = 24555
	session.port_opener.state = NetPortOpener.STATE_WORKING
	session.port_opener._apply_result({"ok": true, "port": 24555, "address": "203.0.113.7"})
	_assert_true(session.public_address() == "203.0.113.7" and session.router_status().contains("203.0.113.7"), "the session exposes the router status and public address to the lobby")
	session.leave("test")
	_assert_true(session.public_address().is_empty(), "leaving releases the mapping")
	opener.queue_free()
	session.queue_free()
	await process_frame
	_finish()


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)


func _finish() -> void:
	if failures > 0:
		push_error("smoke: net_port_opener failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: net_port_opener clean")
	quit(0)
