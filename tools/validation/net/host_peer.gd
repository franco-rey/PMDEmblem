extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"

var main: Node = null
var session: NetSession = null
var out_path: String = ""
var max_frames: int = 90000
var _saved_text: String = ""


func _init() -> void:
	call_deferred("_run")


func _arg(key: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		var text: String = String(argument)
		if text.begins_with("--%s=" % key):
			return text.split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var port: int = int(_arg("port", "24595"))
	var team: int = int(_arg("team", "2"))
	var seed_value: int = int(_arg("seed", "5150"))
	var multiverse: bool = _arg("multiverse", "0") == "1"
	out_path = _arg("out", "user://host.pmdn")
	var player_name: String = _arg("name", "host")
	GameSettings.load_settings()
	main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	GameSettings.player_name = player_name
	session = main.net_session
	session.local_name = player_name
	session.auto_play = _arg("auto_play", "1") == "1"
	var error: String = session.host(port)
	if not error.is_empty():
		print("host: %s" % error)
		quit(1)
		return
	print("host: listening on %d" % port)
	var frames: int = 0
	while frames < 3600 and session.state != NetSession.LOBBY:
		await physics_frame
		frames += 1
	if session.state != NetSession.LOBBY:
		print("host: nobody joined")
		quit(1)
		return
	print("host: %s joined" % session.remote_name)
	while frames < 5400 and not session.remote_ready:
		await physics_frame
		frames += 1
	var code: String = _code(seed_value, team, multiverse)
	if code.is_empty():
		print("host: could not build a match")
		quit(1)
		return
	print("host: starting %s" % code)
	session.start_battle(code)
	frames = 0
	var watched: TacticsLevel = null
	while frames < max_frames and _saved_text.is_empty():
		await physics_frame
		frames += 1
		var level: TacticsLevel = main.level_instance
		if level != null and is_instance_valid(level) and level != watched:
			watched = level
			level.battle_ended.connect(func(_r: int) -> void:
				if is_instance_valid(level):
					_saved_text = level.notation.text())
		if not session.desync_reason.is_empty():
			print("host: desync %s" % session.desync_reason)
			break
	if _saved_text.is_empty():
		print("host: no transcript to save")
		quit(1)
		return
	for i in range(int(_arg("linger", "240"))):
		await physics_frame
	_write()
	print("host: done")
	quit(0)


func _code(seed_value: int, team: int, multiverse: bool) -> String:
	var built: Dictionary = CustomSkirmishBuilder.build_random(team, MAP_PATH, str(seed_value), SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER)
	if not bool(built.get("ok", false)):
		return ""
	var definition: SkirmishDefinitionResource = built["definition"]
	definition.multiverse = multiverse
	return SkirmishCode.encode_definition(definition)


func _write() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		print("host: could not write %s" % out_path)
		return
	file.store_string(_saved_text + "\n")
	file.close()
	print("host: wrote %s" % out_path)
