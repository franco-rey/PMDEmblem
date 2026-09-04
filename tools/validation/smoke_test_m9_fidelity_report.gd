extends SceneTree

const MANIFEST_PATH: String = "res://data/models/pokemon/generated/manifests/pokemon_import_manifest.json"
const REPORT_JSON_PATH: String = "res://data/models/pokemon/import_reports/pokemon_import_report.json"
const CREDITS_PATH: String = "res://assets/textures/credits.txt"
const GENERATED_ROOT: String = "res://data/models/pokemon/generated"
const EXPECTED_SPECIES: int = 686
const EXPECTED_EXCLUDED_UNRELEASED: int = 35
const EXPECTED_MOVES: int = 581
const EXPECTED_ITEMS: int = 2452
const EXPECTED_UNSUPPORTED_MOVES: int = 68
const EXPECTED_UNSUPPORTED_TAG_INSTANCES: int = 69
const EXPECTED_UNSUPPORTED_DEFAULT_SPECIES: int = 217
const EXPECTED_ALL_DEFAULT_UNSUPPORTED: int = 2
const EXTERNAL_PATH_MARKERS: Array[String] = ["/Users/", "PMDODump", "RawAsset", "SpriteCollab", "pokerogue"]
const CREDIT_LOCAL_MARKERS: Array[String] = ["/Users/", "PMDODump", "RawAsset", "SpriteCollab"]
const STATIC_IDLE_SLUGS: Array[String] = [
	"0015_beedrill",
	"0148_dragonair",
	"0266_silcoon",
	"0268_cascoon",
	"0345_lileep",
	"0414_mothim",
]

var failures: int = 0
var manifest: Dictionary = {}
var report: Dictionary = {}


func _init() -> void:
	manifest = _load_json(MANIFEST_PATH)
	report = _load_json(REPORT_JSON_PATH)
	_assert_true(not manifest.is_empty(), "M9 manifest loads")
	_assert_true(not report.is_empty(), "M9 import report loads")
	if not manifest.is_empty() and not report.is_empty():
		_check_manifest_counts()
		_check_report_counts()
		_check_unsupported_default_moves()
		_check_static_idle_substitutions()
		_check_runtime_resource_paths()
		_check_credits_paths()
	if failures > 0:
		push_error("smoke: m9_fidelity_report failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: m9_fidelity_report clean")
		quit(0)


func _check_manifest_counts() -> void:
	var species_entries: Array = manifest.get("species", [])
	var target: Dictionary = manifest.get("target", {})
	_assert_true(species_entries.size() == EXPECTED_SPECIES, "manifest has 686 included species")
	_assert_true((target.get("excluded_unreleased", []) as Array).size() == EXPECTED_EXCLUDED_UNRELEASED, "manifest reports 35 excluded unreleased species")
	_assert_true(_status_count(species_entries, "battle_ready") == EXPECTED_SPECIES, "manifest has 686 battle-ready species")
	_assert_true(_status_count(species_entries, "metadata_only") == 0, "manifest has zero metadata-only species")
	_assert_true(_status_count(species_entries, "disabled") == 0, "manifest has zero disabled species")


func _check_report_counts() -> void:
	var summary: Dictionary = report.get("summary", {})
	var moves: Array = report.get("moves", [])
	_assert_true(int(summary.get("species_imported", 0)) == EXPECTED_SPECIES, "report imports 686 species")
	_assert_true(int(summary.get("moves_imported", 0)) == EXPECTED_MOVES, "report imports 581 moves")
	_assert_true(int(summary.get("items_imported", 0)) == EXPECTED_ITEMS, "report imports 2452 items")
	_assert_true(int(summary.get("instances_written", 0)) == EXPECTED_SPECIES, "report writes 686 instance templates")
	_assert_true(int(summary.get("errors", -1)) == 0, "report has zero errors")
	_assert_true(int(summary.get("warnings", -1)) == 0, "report has zero aggregate warnings")
	_assert_true(moves.size() == EXPECTED_MOVES, "report move inventory has 581 entries")
	_assert_true(_unsupported_move_count(moves) == EXPECTED_UNSUPPORTED_MOVES, "report has 68 moves with unsupported tags")
	_assert_true(_unsupported_tag_instance_count(moves) == EXPECTED_UNSUPPORTED_TAG_INSTANCES, "report has 69 unsupported tag instances")


func _check_unsupported_default_moves() -> void:
	var unsupported_moves: Dictionary = _unsupported_moves_by_slug()
	var affected: int = 0
	var all_default_unsupported: Array[String] = []
	var zero_default: int = 0
	for raw_entry in manifest.get("species", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var moves_block: Dictionary = entry.get("moves", {})
		var default_moves: Array = moves_block.get("default_moves", [])
		if default_moves.is_empty():
			zero_default += 1
			continue
		var unsupported_defaults: Array[String] = []
		for raw_move in default_moves:
			var move_id: String = String(raw_move)
			if unsupported_moves.has(move_id):
				unsupported_defaults.append(move_id)
		if not unsupported_defaults.is_empty():
			affected += 1
		if unsupported_defaults.size() == default_moves.size():
			all_default_unsupported.append(String(entry.get("slug", "")))
	all_default_unsupported.sort()
	_assert_true(affected == EXPECTED_UNSUPPORTED_DEFAULT_SPECIES, "217 species have unsupported default moves")
	_assert_true(all_default_unsupported.size() == EXPECTED_ALL_DEFAULT_UNSUPPORTED, "2 species have all default moves unsupported")
	_assert_true(all_default_unsupported == ["0132_ditto", "0235_smeargle"], "Ditto and Smeargle are the all-default unsupported species")
	_assert_true(zero_default == 0, "no included species has zero default moves")


func _check_static_idle_substitutions() -> void:
	var entries: Dictionary = _manifest_entries_by_slug()
	for slug in STATIC_IDLE_SLUGS:
		_assert_true(entries.has(slug), "%s exists in M9 manifest" % slug)
		if entries.has(slug):
			_assert_true(String((entries[slug] as Dictionary).get("status", "")) == "battle_ready", "%s remains battle-ready" % slug)
		var sprite_set: PokemonSpriteSetResource = load("res://data/models/pokemon/generated/sprites/%s.tres" % slug) as PokemonSpriteSetResource
		_assert_true(sprite_set != null, "%s sprite set loads" % slug)
		if sprite_set == null:
			continue
		var idle: Dictionary = sprite_set.animation_states.get("idle", {})
		_assert_true(bool(idle.get("alias_only", false)) and String(idle.get("alias_target", "")) == "Walk", "%s idle is the source alias of Walk" % slug)
		_assert_true(String(idle.get("substitution", "")).is_empty(), "%s no longer uses the static idle substitution" % slug)
		_assert_true(int(idle.get("frame_count", 0)) > 1 and not (idle.get("timing", []) as Array).is_empty(), "%s alias idle keeps the walk frames and timing (%d)" % [slug, int(idle.get("frame_count", 0))])
		var cell_size: Vector2i = idle.get("cell_size", Vector2i.ZERO)
		_assert_true(cell_size.x > 0 and cell_size.y > 0, "%s alias idle has cell size" % slug)
		var path: String = String(idle.get("path", ""))
		_assert_true(path.ends_with("/animations/walk.png"), "%s alias idle uses the canonical walk sheet" % slug)
		_assert_true(FileAccess.file_exists(path), "%s alias idle sheet exists" % slug)


func _check_runtime_resource_paths() -> void:
	var leaks: Array[String] = []
	for raw_entry in manifest.get("species", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		_collect_external_path_leaks(entry.get("assets", {}), leaks)
	_collect_text_tree_leaks(GENERATED_ROOT, leaks)
	_assert_true(leaks.is_empty(), "generated runtime resources have no external path leaks")
	for leak in leaks.slice(0, mini(8, leaks.size())):
		push_error("smoke: leak - %s" % leak)


func _check_credits_paths() -> void:
	var text: String = _read_text(CREDITS_PATH)
	_assert_true(not text.is_empty(), "texture credits file loads")
	for marker in CREDIT_LOCAL_MARKERS:
		_assert_true(not text.contains(marker), "credits do not contain %s" % marker)


func _unsupported_moves_by_slug() -> Dictionary:
	var out: Dictionary = {}
	for raw_move in report.get("moves", []):
		if not (raw_move is Dictionary):
			continue
		var move: Dictionary = raw_move
		if not (move.get("unsupported_effect_tags", []) as Array).is_empty():
			out[String(move.get("slug", ""))] = true
	return out


func _unsupported_move_count(moves: Array) -> int:
	var count: int = 0
	for raw_move in moves:
		if raw_move is Dictionary and not ((raw_move as Dictionary).get("unsupported_effect_tags", []) as Array).is_empty():
			count += 1
	return count


func _unsupported_tag_instance_count(moves: Array) -> int:
	var count: int = 0
	for raw_move in moves:
		if raw_move is Dictionary:
			count += ((raw_move as Dictionary).get("unsupported_effect_tags", []) as Array).size()
	return count


func _status_count(entries: Array, status: String) -> int:
	var count: int = 0
	for raw_entry in entries:
		if raw_entry is Dictionary and String((raw_entry as Dictionary).get("status", "")) == status:
			count += 1
	return count


func _manifest_entries_by_slug() -> Dictionary:
	var out: Dictionary = {}
	for raw_entry in manifest.get("species", []):
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			out[String(entry.get("slug", ""))] = entry
	return out


func _collect_external_path_leaks(value: Variant, out: Array[String]) -> void:
	if value is String:
		var text: String = String(value)
		for marker in EXTERNAL_PATH_MARKERS:
			if text.contains(marker):
				out.append(text)
				return
	elif value is Array:
		for item in value:
			_collect_external_path_leaks(item, out)
	elif value is Dictionary:
		for item in (value as Dictionary).values():
			_collect_external_path_leaks(item, out)


func _collect_text_tree_leaks(root_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		out.append("%s:unreadable" % root_path)
		return
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var child_path: String = "%s/%s" % [root_path, name]
		if dir.current_is_dir():
			_collect_text_tree_leaks(child_path, out)
		elif name.get_extension() == "tres":
			var text: String = _read_text(child_path)
			for marker in EXTERNAL_PATH_MARKERS:
				if text.contains(marker):
					out.append("%s:%s" % [child_path, marker])
					break
	dir.list_dir_end()


func _load_json(path: String) -> Dictionary:
	var text: String = _read_text(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("smoke: ok - %s" % message)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % message)
