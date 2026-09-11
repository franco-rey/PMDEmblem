extends SceneTree

const MIN_SPECIES: int = 686
const MIN_MAPS: int = 8
const MIN_MOVES: int = 581
const MIN_ARENAS: int = 8
const REQUIRED_FILES: Array[String] = [
	"res://assets/fonts/pmd/pmd_text.fnt",
	"res://data/models/audio/music_cues.json",
	"res://data/models/audio/sound_cues.json",
	"res://assets/scene/main.tscn",
	"res://assets/ui/pmd_theme.tres",
]

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _arg(key: String, fallback: String) -> String:
	for entry in OS.get_cmdline_user_args():
		var text: String = String(entry)
		if text.begins_with("--%s=" % key):
			return text.split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var pack: String = _arg("pack", "")
	_assert_true(not pack.is_empty() and FileAccess.file_exists(pack), "a pack path was given and exists (%s)" % pack)
	if pack.is_empty() or not FileAccess.file_exists(pack):
		_finish()
		return
	_assert_true(ProjectSettings.load_resource_pack(pack, true), "the pack mounts over res://")
	var species: int = _count("res://data/models/pokemon/generated/species/", ".tres")
	var maps: int = _count("res://data/models/maps/definitions/", ".tres")
	var arenas: int = _count("res://assets/maps/level/arena/", ".tscn")
	var moves: int = _count("res://data/models/pokemon/generated/moves/", ".tres")
	_assert_true(species >= MIN_SPECIES, "the pack carries the roster (%d species)" % species)
	_assert_true(maps >= MIN_MAPS, "the pack carries the map definitions (%d)" % maps)
	_assert_true(arenas >= MIN_ARENAS, "the pack carries the arena scenes (%d)" % arenas)
	_assert_true(moves >= MIN_MOVES, "the pack carries the generated moves (%d)" % moves)
	for path in REQUIRED_FILES:
		_assert_true(FileAccess.file_exists(path) or ResourceLoader.exists(path), "the pack carries %s" % path)
	var portraits: int = _count("res://assets/textures/pokemon/portraits/", "")
	_assert_true(portraits > 0, "the pack carries portrait folders (%d entries)" % portraits)
	_finish()


func _count(directory: String, extension: String) -> int:
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return 0
	var total: int = 0
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var name: String = entry.trim_suffix(".remap").trim_suffix(".import")
		if extension.is_empty() or name.ends_with(extension):
			total += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return total


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)


func _finish() -> void:
	if failures > 0:
		push_error("smoke: export_pack failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: export_pack clean")
	quit(0)
