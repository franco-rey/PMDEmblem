extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"

var main: Node = null
var session: NetSession = null
var out_path: String = ""
var drop_at_turn: int = 0
var rejoin_after: int = 0
var auto_rejoin: bool = false
var dropped: bool = false
var rejoined: bool = false
var drop_frame: int = 0
var max_frames: int = 60000
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
	var address: String = _arg("address", "127.0.0.1")
	var port: int = int(_arg("port", "24592"))
	out_path = _arg("out", "res://logs/debug/net/guest.pmdn")
	drop_at_turn = int(_arg("drop_at_turn", "0"))
	rejoin_after = int(_arg("rejoin_after", "0"))
	auto_rejoin = _arg("auto_rejoin", "0") == "1"
	var player_name: String = _arg("name", "guest")
	GameSettings.load_settings()
	main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	GameSettings.player_name = player_name
	session = main.net_session
	session.local_name = player_name
	session.auto_play = _arg("auto_play", "1") == "1"
	session.auto_rejoin = auto_rejoin
	var error: String = session.join(address, port)
	if not error.is_empty():
		print("guest: %s" % error)
		quit(1)
		return
	var frames: int = 0
	while frames < 1800 and session.state != NetSession.LOBBY:
		await physics_frame
		frames += 1
	if session.state != NetSession.LOBBY:
		print("guest: never reached the lobby")
		quit(1)
		return
	print("guest: lobby with %s" % session.remote_name)
	session.set_ready(true)
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
		if drop_at_turn > 0 and not dropped and level != null and is_instance_valid(level) and level.notation.turn_index >= drop_at_turn:
			dropped = true
			if rejoin_after <= 0 and not auto_rejoin:
				print("guest: dropping at turn %d" % level.notation.turn_index)
				_saved_text = level.notation.text()
				break
			print("guest: cutting the link at turn %d" % level.notation.turn_index)
			drop_frame = frames
			if session.link != null:
				session.link.close("cable")
		if dropped and not rejoined and not auto_rejoin and rejoin_after > 0 and frames - drop_frame >= rejoin_after:
			rejoined = true
			var back: String = session.rejoin()
			print("guest: rejoining (%s)" % ("ok" if back.is_empty() else back))
		if session.state == NetSession.IDLE and frames > 1200:
			break
	if _saved_text.is_empty():
		print("guest: no transcript to save")
		quit(1)
		return
	for i in range(int(_arg("linger", "240"))):
		await physics_frame
	_write()
	print("guest: done")
	quit(0)


func _write() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		print("guest: could not write %s" % out_path)
		return
	file.store_string(_saved_text + "\n")
	file.close()
	print("guest: wrote %s" % out_path)
