extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GUEST_SCRIPT: String = "tools/validation/net/guest_peer.gd"
const BASE_PORT: int = 24592
const MAX_FRAMES: int = 120000

var failures: int = 0
var children: Array[int] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenarios: Array[Dictionary] = [
		{"seed": 3101, "team": 2, "multiverse": false, "label": "plain"},
		{"seed": 3102, "team": 3, "multiverse": true, "label": "multiverse"},
	]
	var index: int = 0
	for scenario in scenarios:
		await _play(scenario, BASE_PORT + index)
		index += 1
	_finish()


func _play(scenario: Dictionary, port: int) -> void:
	var label: String = String(scenario["label"])
	var main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var session: NetSession = main.net_session
	session.local_name = "host"
	session.auto_play = true
	var error: String = session.host(port)
	_assert_true(error.is_empty(), "%s: the host binds port %d (%s)" % [label, port, error])
	if not error.is_empty():
		main.queue_free()
		return
	var guest_out: String = "res://logs/debug/net/guest_%s.pmdn" % label
	var guest_file: String = ProjectSettings.globalize_path(guest_out)
	DirAccess.remove_absolute(guest_file)
	var address: String = "127.0.0.1"
	var pid: int = OS.create_process(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", GUEST_SCRIPT, "--",
		"--port=%d" % port, "--address=%s" % address, "--name=guest", "--out=%s" % guest_out,
	])
	print("smoke: guest joins over %s" % address)
	_assert_true(pid > 0, "%s: the guest process starts" % label)
	if pid <= 0:
		main.queue_free()
		return
	children.append(pid)
	var frames: int = 0
	while frames < 3600 and session.state != NetSession.LOBBY:
		await physics_frame
		frames += 1
	_assert_true(session.state == NetSession.LOBBY, "%s: the two processes reach the lobby over a real connection" % label)
	if session.state != NetSession.LOBBY:
		_stop(pid, main)
		return
	while frames < 5400 and not session.remote_ready:
		await physics_frame
		frames += 1
	_assert_true(session.remote_ready, "%s: the guest reports ready" % label)
	var code: String = _build_code(int(scenario["seed"]), int(scenario["team"]), bool(scenario["multiverse"]))
	_assert_true(not code.is_empty(), "%s: the host builds an explicit code for both teams" % label)
	if code.is_empty():
		_stop(pid, main)
		return
	session.start_battle(code)
	frames = 0
	while frames < 1800 and (main.level_instance == null or not is_instance_valid(main.level_instance)):
		await physics_frame
		frames += 1
	var level: TacticsLevel = main.level_instance
	_assert_true(level != null and is_instance_valid(level), "%s: both peers launch the same battle" % label)
	if level == null:
		_stop(pid, main)
		return
	_assert_true(session.latency_ms() >= 0, "%s: the ENet link reports a round-trip time (%d ms)" % [label, session.latency_ms()])
	var host_text: Array[String] = []
	level.battle_ended.connect(func(_r: int) -> void: host_text.append(level.notation.text()))
	frames = 0
	while frames < MAX_FRAMES and host_text.is_empty() and session.desync_reason.is_empty():
		await physics_frame
		frames += 1
	_assert_true(session.desync_reason.is_empty(), "%s: the two peers never diverge (%s)" % [label, session.desync_reason])
	_assert_true(not host_text.is_empty(), "%s: the battle reaches a result on the host" % label)
	var waited: int = 0
	while waited < 1200 and not FileAccess.file_exists(guest_out):
		await physics_frame
		waited += 1
	_assert_true(FileAccess.file_exists(guest_out), "%s: the guest writes its own transcript" % label)
	if not host_text.is_empty() and FileAccess.file_exists(guest_out):
		var guest_text: String = FileAccess.get_file_as_string(guest_out)
		var diff: String = _first_difference(host_text[0], guest_text)
		_assert_true(diff.is_empty(), "%s: both machines produced the same transcript (%s)" % [label, diff])
		_assert_true(host_text[0].split("\n").size() > 12, "%s: the transcript covers a real game (%d lines)" % [label, host_text[0].split("\n").size()])
	_stop(pid, main)


func _build_code(seed_value: int, team: int, multiverse: bool) -> String:
	var built: Dictionary = CustomSkirmishBuilder.build_random(team, MAP_PATH, str(seed_value), SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER)
	if not bool(built.get("ok", false)):
		return ""
	var definition: SkirmishDefinitionResource = built["definition"]
	definition.multiverse = multiverse
	return SkirmishCode.encode_definition(definition)


func _first_difference(a: String, b: String) -> String:
	var first: PackedStringArray = a.strip_edges().split("\n")
	var second: PackedStringArray = b.strip_edges().split("\n")
	for i in range(mini(first.size(), second.size())):
		if first[i].strip_edges() != second[i].strip_edges():
			return "line %d: host %s | guest %s" % [i, first[i].strip_edges(), second[i].strip_edges()]
	if first.size() != second.size():
		return "host has %d lines, guest %d" % [first.size(), second.size()]
	return ""


func _stop(pid: int, main: Node) -> void:
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	children.erase(pid)
	if is_instance_valid(main):
		if main.has_method("unload_level"):
			main.unload_level()
		main.queue_free()
	await process_frame
	await process_frame


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)


func _finish() -> void:
	for pid in children:
		if OS.is_process_running(pid):
			OS.kill(pid)
	if failures > 0:
		push_error("smoke: net_two_peers failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: net_two_peers clean")
	quit(0)
