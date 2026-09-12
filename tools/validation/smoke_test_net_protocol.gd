extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE: String = "match seed=11 mode=pvp p=0025_pikachu@50:thunderbolt,quick_attack:static e=0004_charmander@50:ember,scratch:blaze|0001_bulbasaur@50:tackle:overgrow"
const PORT: int = 24591


func _run() -> void:
	_check_messages()
	_check_chain()
	await _check_loopback()
	await _check_enet()
	await _check_handshake()
	await _check_bridge()
	_finish("net_protocol")


func _check_messages() -> void:
	_assert_true(NetMessages.validate("nope") != "", "a non-dictionary message is refused")
	_assert_true(NetMessages.validate({}) != "", "a message without a kind is refused")
	_assert_true(NetMessages.validate({"k": "nonsense"}) != "", "an unknown kind is refused")
	_assert_true(NetMessages.validate({"k": NetMessages.HELLO, "protocol": 1, "version": "x", "name": "n"}) != "", "a hello without its content fingerprint is refused")
	_assert_true(NetMessages.validate(NetMessages.build(NetMessages.HELLO, {"protocol": 1, "version": "x", "name": "n", "content": "c"})) == "", "a complete hello passes validation")
	var built: Dictionary = NetMessages.build(NetMessages.CMD, {"seq": 1, "turn": "T1 P1 @A1", "line": "end", "chain": "c", "count": 3})
	var round_trip: Variant = bytes_to_var(var_to_bytes(built))
	_assert_true(round_trip is Dictionary and (round_trip as Dictionary)["line"] == "end" and (round_trip as Dictionary)["seq"] == 1, "a decision survives the wire encoding")
	var fingerprint: String = NetMessages.content_fingerprint()
	_assert_true(fingerprint.length() == 64 and fingerprint == NetMessages.content_fingerprint(), "the content fingerprint is a stable hash")


func _check_chain() -> void:
	var a: String = NetMessages.chain_of(["one", "two"])
	var b: String = NetMessages.chain_next(NetMessages.chain_next(NetMessages.chain_start(), "one"), "two")
	_assert_true(a == b, "the transcript chain folds line by line")
	_assert_true(NetMessages.chain_of(["one", "two"]) != NetMessages.chain_of(["two", "one"]), "the chain depends on line order")


func _check_loopback() -> void:
	var pair: Array = LoopbackLink.pair()
	var host: LoopbackLink = pair[0]
	var guest: LoopbackLink = pair[1]
	var seen: Array[Dictionary] = []
	guest.received.connect(func(m: Dictionary) -> void: seen.append(m))
	host.send(NetMessages.build(NetMessages.SYNC, {"round": 1, "chain": "a", "count": 1}))
	host.send(NetMessages.build(NetMessages.SYNC, {"round": 2, "chain": "b", "count": 2}))
	guest.poll()
	_assert_true(seen.size() == 2 and int(seen[0]["round"]) == 1 and int(seen[1]["round"]) == 2, "the loopback link delivers messages in order")
	var closes: Array[String] = []
	guest.closed.connect(func(r: String) -> void: closes.append(r))
	host.close("done")
	_assert_true(closes.size() == 1 and not guest.is_open(), "closing one end closes the other")


func _check_enet() -> void:
	var server := EnetLink.new()
	var client := EnetLink.new()
	_assert_true(server.host(PORT) == "", "an ENet host binds its port")
	_assert_true(client.join("127.0.0.1", PORT) == "", "an ENet client starts connecting")
	var got: Array[Dictionary] = []
	server.received.connect(func(m: Dictionary) -> void: got.append(m))
	var frames: int = 0
	while frames < 600 and (client.remote_id == 0 or server.remote_id == 0):
		server.poll(0.016)
		client.poll(0.016)
		await physics_frame
		frames += 1
	_assert_true(client.remote_id != 0 and server.remote_id != 0, "the two ENet peers connect over the loopback address")
	client.send(NetMessages.build(NetMessages.HELLO, {"protocol": NetMessages.PROTOCOL, "version": "v", "name": "guest", "content": "c"}))
	frames = 0
	while frames < 300 and got.is_empty():
		server.poll(0.016)
		client.poll(0.016)
		await physics_frame
		frames += 1
	_assert_true(got.size() == 1 and String(got[0].get("name", "")) == "guest", "a hello crosses a real ENet connection")
	server.close("done")
	client.close("done")
	await physics_frame


func _sessions() -> Array:
	var pair: Array = LoopbackLink.pair()
	var host := NetSession.new()
	var guest := NetSession.new()
	host.local_name = "hostplayer"
	guest.local_name = "guestplayer"
	root.add_child(host)
	root.add_child(guest)
	host.use_test_link(pair[0], true)
	guest.use_test_link(pair[1], false)
	return [host, guest]


func _check_handshake() -> void:
	var pair: Array = _sessions()
	var host: NetSession = pair[0]
	var guest: NetSession = pair[1]
	host.send_lobby({"map_path": "res://data/models/maps/definitions/chessboard.tres", "seed_text": "7", "ready": false})
	for i in range(6):
		await physics_frame
	_assert_true(host.state == NetSession.LOBBY and guest.state == NetSession.LOBBY, "both peers reach the lobby after the handshake")
	_assert_true(host.local_side == PokemonInstanceResource.Team.PLAYER and guest.local_side == PokemonInstanceResource.Team.ENEMY, "the host takes team 1 and the guest team 2")
	_assert_true(guest.remote_name == "hostplayer" and host.remote_name == "guestplayer", "each peer learns the other's name")
	guest.send_lobby({"team": ["a", "b"], "ready": true})
	for i in range(4):
		await physics_frame
	_assert_true(host.remote_ready and (host.remote_lobby.get("team", []) as Array).size() == 2, "a lobby change reaches the other peer")
	host.set_ready(true)
	for i in range(4):
		await physics_frame
	_assert_true(guest.remote_ready and host.both_ready(), "both ready flags cross the link")
	host.start_battle(CODE)
	var guest_code: Array[String] = []
	guest.start_requested.connect(func(code: String, _id: String) -> void: guest_code.append(code))
	for i in range(6):
		await physics_frame
	_assert_true(guest_code.size() == 1 and guest_code[0] == CODE, "the guest accepts a start whose units match")
	var bad: Dictionary = NetMessages.build(NetMessages.START, {"code": CODE, "battle_id": "x", "units": PackedStringArray(["wrong"])})
	guest.link.partner.send(bad)
	var refusals: Array[String] = []
	guest.notice.connect(func(text: String) -> void: refusals.append(text))
	for i in range(6):
		await physics_frame
	_assert_true(refusals.size() > 0, "a start whose teams differ is refused with a reason")
	host.leave("test")
	guest.leave("test")
	host.queue_free()
	guest.queue_free()
	await process_frame


func _check_bridge() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(ok, "the bridge test battle launches")
	if not ok:
		return
	var level: TacticsLevel = driver.level
	var pair: Array = LoopbackLink.pair()
	var host := NetSession.new()
	host.local_name = "host"
	root.add_child(host)
	host.use_test_link(pair[0], true)
	var fake: LoopbackLink = pair[1]
	(host.link as LoopbackLink).delay_frames = 6
	fake.delay_frames = 6
	var from_host: Array[Dictionary] = []
	fake.received.connect(func(m: Dictionary) -> void: from_host.append(m))
	host.attach_level(level)
	level.net_session = host
	host.mark_ready()
	fake.send(NetMessages.build(NetMessages.BATTLE_READY, {"battle_id": host.battle_id}))
	for i in range(20):
		fake.poll()
		await physics_frame
	_assert_true(host.ready_to_play(), "both peers report ready before decisions flow")
	var ended_text: Array[String] = []
	level.battle_ended.connect(func(_r: int) -> void: ended_text.append(level.notation.text()))
	var p1: TacticsPawn = level.notation.pawn_for_id("P1")
	if not await driver._wait_for_turn(p1):
		_assert_true(false, "the host's own unit gets a turn")
		return
	_assert_true(not host.remote_turn_active() and not level.ui_control.remote_turn, "the local player keeps control on their own turn")
	from_host.clear()
	await driver._end_turn(p1)
	for i in range(12):
		fake.poll()
		await physics_frame
	var sent: Array[Dictionary] = []
	for message in from_host:
		if String(message.get("k", "")) == NetMessages.CMD:
			sent.append(message)
	_assert_true(sent.size() == 1 and String(sent[0]["line"]) == "end" and int(sent[0]["seq"]) == 1, "the host's own decision is sent once as a transcript line even with the link delayed")
	var frames: int = 0
	while frames < 300 and not host.remote_turn_active():
		await physics_frame
		frames += 1
	_assert_true(host.remote_turn_active() and level.ui_control.remote_turn, "the controls lock while the other player's unit acts")
	var header: String = _last_turn_header(level)
	var enemy_id: String = NotationParser.tokenize(header)[1]
	var bad_chain: Dictionary = NetMessages.build(NetMessages.CMD, {"seq": 1, "turn": header, "line": "end", "chain": "not-the-chain", "count": host.line_count})
	fake.send(bad_chain)
	frames = 0
	while frames < 300 and host.desync_reason.is_empty():
		await physics_frame
		frames += 1
	_assert_true(not host.desync_reason.is_empty(), "a decision carrying the wrong state hash raises a desync (%s)" % host.desync_reason)
	_assert_true(ended_text.size() == 1, "a desync ends the battle")
	_assert_true(not ended_text.is_empty() and ended_text[0].contains("reason=desync"), "the transcript records why the battle ended")
	host.leave("test")
	host.queue_free()
	if is_instance_valid(driver.main):
		driver.main.queue_free()
	await process_frame
	await process_frame


func _last_turn_header(level: TacticsLevel) -> String:
	for i in range(level.notation.lines.size() - 1, -1, -1):
		var line: String = String(level.notation.lines[i])
		if String(NotationParser.parse(line).get("kind", "")) == NotationParser.KIND_TURN:
			return line.strip_edges()
	return ""
