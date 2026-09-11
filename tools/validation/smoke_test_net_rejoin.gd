extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GUEST_SCRIPT: String = "tools/validation/net/guest_peer.gd"
const BASE_PORT: int = 24612
const MAX_FRAMES: int = 120000

var failures: int = 0
var children: Array[int] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenarios: Array[Dictionary] = [
		{"seed": 3201, "team": 2, "multiverse": false, "drop": 5, "label": "plain"},
		{"seed": 3202, "team": 3, "multiverse": true, "drop": 9, "label": "multiverse"},
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
	var guest_out: String = "res://logs/debug/net/rejoin_%s.pmdn" % label
	DirAccess.remove_absolute(ProjectSettings.globalize_path(guest_out))
	var guest_log: String = ProjectSettings.globalize_path("res://logs/debug/net/rejoin_%s_guest.log" % label)
	var pid: int = OS.create_process(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", guest_log,
		"--script", GUEST_SCRIPT, "--",
		"--port=%d" % port, "--address=127.0.0.1", "--name=guest", "--out=%s" % guest_out,
		"--drop_at_turn=%d" % int(scenario["drop"]), "--rejoin_after=90",
	])
	_assert_true(pid > 0, "%s: the guest process starts" % label)
	if pid <= 0:
		main.queue_free()
		return
	children.append(pid)
	var frames: int = 0
	while frames < 3600 and session.state != NetSession.LOBBY:
		await physics_frame
		frames += 1
	_assert_true(session.state == NetSession.LOBBY, "%s: the peers reach the lobby" % label)
	if session.state != NetSession.LOBBY:
		_stop(pid, main)
		return
	while frames < 5400 and not session.remote_ready:
		await physics_frame
		frames += 1
	var code: String = _build_code(int(scenario["seed"]), int(scenario["team"]), bool(scenario["multiverse"]))
	session.start_battle(code)
	frames = 0
	while frames < 1800 and (main.level_instance == null or not is_instance_valid(main.level_instance)):
		await physics_frame
		frames += 1
	var level: TacticsLevel = main.level_instance
	_assert_true(level != null and is_instance_valid(level), "%s: both peers launch the battle" % label)
	if level == null:
		_stop(pid, main)
		return
	var host_text: Array[String] = []
	level.battle_ended.connect(func(_r: int) -> void: host_text.append(level.notation.text()))
	var states: Array[int] = []
	session.state_changed.connect(func(state: int) -> void: states.append(state))
	var notices: Array[String] = []
	session.notice.connect(func(text: String) -> void: notices.append(text))
	frames = 0
	while frames < MAX_FRAMES and host_text.is_empty() and session.desync_reason.is_empty():
		await physics_frame
		frames += 1
	_assert_true(states.has(NetSession.SUSPENDED), "%s: the host suspended when the guest cut the link" % label)
	var resumed: bool = false
	for i in range(states.size() - 1):
		if states[i] == NetSession.SUSPENDED and states[i + 1] == NetSession.IN_BATTLE:
			resumed = true
	_assert_true(resumed, "%s: the host resumed after the guest caught up (%s)" % [label, str(states)])
	_assert_true(session.desync_reason.is_empty(), "%s: the peers never diverge after the rejoin (%s)" % [label, session.desync_reason])
	_assert_true(not host_text.is_empty(), "%s: the battle reaches a result on the host" % label)
	var waited: int = 0
	while waited < 1200 and not FileAccess.file_exists(guest_out):
		await physics_frame
		waited += 1
	_assert_true(FileAccess.file_exists(guest_out), "%s: the rejoined guest writes its transcript" % label)
	if not host_text.is_empty() and FileAccess.file_exists(guest_out):
		var guest_text: String = FileAccess.get_file_as_string(guest_out)
		var diff: String = _first_difference(host_text[0], guest_text)
		_assert_true(diff.is_empty(), "%s: host and rejoined guest produced the same transcript (%s)" % [label, diff])
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
		push_error("smoke: net_rejoin failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: net_rejoin clean")
	quit(0)
