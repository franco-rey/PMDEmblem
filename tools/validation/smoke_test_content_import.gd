extends SceneTree

const MANIFEST_PATH: String = "res://data/models/pokemon/generated/manifests/pokemon_import_manifest.json"
const REPORT_JSON_PATH: String = "res://data/models/pokemon/import_reports/pokemon_import_report.json"
const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/test_arena.tres"
const REQUIRED_CURRENT_SEVEN: Array[String] = [
	"0475_gallade",
	"0448_lucario",
	"0282_gardevoir",
	"0454_toxicroak",
	"0467_magmortar",
	"0094_gengar",
	"0356_dusclops",
]
const EXTERNAL_PATH_MARKERS: Array[String] = [
	"/Users/",
	"PMDODump",
	"RawAsset",
	"SpriteCollab",
	"pokerogue",
]
const REST_ANIMDATA_CANDIDATES: Array[String] = ["Laying", "EventSleep", "Sleep"]

var failures: int = 0
var manifest: Dictionary = {}
var report: Dictionary = {}


func _init() -> void:
	_load_json_artifacts()
	_check_manifest_entries()
	_check_current_seven_roster()
	_check_roster_provider_metadata()
	_check_random_skirmish_from_battle_ready_pool()

	if failures > 0:
		push_error("smoke: content_import failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: content_import clean")
		quit(0)


func _load_json_artifacts() -> void:
	manifest = _load_json(MANIFEST_PATH)
	report = _load_json(REPORT_JSON_PATH)
	_assert_true(not manifest.is_empty(), "manifest JSON loads")
	_assert_true(not report.is_empty(), "report JSON loads")
	_assert_true(int(manifest.get("schema_version", 0)) >= 1, "manifest schema is supported")
	_assert_true(int(report.get("schema_version", 0)) >= 1, "report schema is supported")


func _check_manifest_entries() -> void:
	var species_entries: Array = manifest.get("species", [])
	_assert_true(not species_entries.is_empty(), "manifest contains species entries")
	var checked: int = 0
	for raw_entry in species_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var slug: String = String(entry.get("slug", ""))
		var status: String = String(entry.get("status", ""))
		var assets: Dictionary = entry.get("assets", {})
		for path_string in _manifest_asset_paths(assets):
			if not path_string.begins_with("res://"):
				continue
			_assert_true(_has_no_external_marker(path_string), "%s asset path is project-owned: %s" % [slug, path_string])
		if status != "battle_ready":
			continue
		checked += 1
		_assert_true(_load_species(slug) != null, "%s species resource loads" % slug)
		_assert_true(_load_instance(slug) != null, "%s generated/override instance loads" % slug)
		var instance: PokemonInstanceResource = _load_instance(slug)
		if instance != null:
			var form: PokemonFormResource = instance.resolved_form()
			_assert_true(form != null, "%s default form resolves" % slug)
			if form != null:
				_assert_true(form.sprite_set != null and form.sprite_set.is_complete(), "%s sprite set is complete" % slug)
				if form.sprite_set != null:
					for pair in form.sprite_set.iter_animation_paths():
						var sprite_path: String = String(pair[1])
						_assert_true(sprite_path.begins_with("res://"), "%s %s sprite uses res path" % [slug, pair[0]])
						_assert_true(_has_no_external_marker(sprite_path), "%s %s sprite has no external marker" % [slug, pair[0]])
						_assert_true(FileAccess.file_exists(sprite_path), "%s %s sprite exists" % [slug, pair[0]])
					_check_rest_sheet_slices(slug, form.sprite_set)
			_assert_true(_has_usable_move(instance), "%s has at least one usable move" % slug)
	_assert_true(checked > 0, "at least one battle-ready manifest entry was checked")


func _check_rest_sheet_slices(slug: String, sprite_set: PokemonSpriteSetResource) -> void:
	if sprite_set == null or sprite_set.sleep_path.is_empty() or sprite_set.anim_data_path.is_empty():
		return
	var tex: Texture2D = load(sprite_set.sleep_path) as Texture2D
	_assert_true(tex != null, "%s rest/faint texture loads" % slug)
	if tex == null:
		return
	var anim_data: Dictionary = SpriteAnimData.parse(sprite_set.anim_data_path)
	var matched_name: String = _matching_rest_anim_name(tex, anim_data)
	_assert_true(not matched_name.is_empty(), "%s rest/faint sheet matches AnimData" % slug)


func _matching_rest_anim_name(tex: Texture2D, anim_data: Dictionary) -> String:
	for anim_name in REST_ANIMDATA_CANDIDATES:
		if not anim_data.has(anim_name):
			continue
		var entry: SpriteAnimData.AnimEntry = anim_data[anim_name]
		if entry == null or entry.frame_width <= 0 or entry.frame_height <= 0:
			continue
		if tex.get_width() % entry.frame_width != 0 or tex.get_height() % entry.frame_height != 0:
			continue
		var columns: int = int(tex.get_width() / entry.frame_width)
		if columns == entry.frames_per_direction:
			return anim_name
	return ""


func _manifest_asset_paths(value: Variant) -> Array[String]:
	var paths: Array[String] = []
	_collect_manifest_asset_paths(value, paths)
	return paths


func _collect_manifest_asset_paths(value: Variant, out: Array[String]) -> void:
	if value is String:
		out.append(String(value))
	elif value is Array:
		for item in value:
			_collect_manifest_asset_paths(item, out)
	elif value is Dictionary:
		for item in (value as Dictionary).values():
			_collect_manifest_asset_paths(item, out)


func _check_current_seven_roster() -> void:
	var entries: Dictionary = _roster_entries_by_slug()
	for slug in REQUIRED_CURRENT_SEVEN:
		_assert_true(entries.has(slug), "current-seven roster includes %s" % slug)
		if entries.has(slug):
			var entry: Dictionary = entries[slug]
			_assert_true(bool(entry.get("battle_ready", false)), "%s remains battle-ready" % slug)


func _check_roster_provider_metadata() -> void:
	var entries: Array[Dictionary] = SkirmishRosterProvider.entries()
	_assert_true(not entries.is_empty(), "roster provider returns entries")
	for entry in entries:
		_assert_true(entry.has("generation"), "%s exposes generation" % entry.get("slug", "?"))
		_assert_true(entry.has("battle_ready"), "%s exposes battle_ready" % entry.get("slug", "?"))
		_assert_true(entry.has("status"), "%s exposes status" % entry.get("slug", "?"))
		_assert_true(entry.has("warnings"), "%s exposes warnings" % entry.get("slug", "?"))
		_assert_true(entry.has("disabled_reason"), "%s exposes disabled_reason" % entry.get("slug", "?"))


func _check_random_skirmish_from_battle_ready_pool() -> void:
	var ready_paths: Array[String] = CustomSkirmishBuilder.battle_ready_roster_paths()
	_assert_true(ready_paths.size() >= 3, "battle-ready roster has at least three entries")
	var result: Dictionary = CustomSkirmishBuilder.build_random(3, TEST_ARENA_MAP_PATH, "424242")
	_assert_true(result.get("ok", false), "random skirmish builds from battle-ready pool")
	if not result.get("ok", false):
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	_assert_true(definition != null, "random skirmish returns definition")
	if definition != null:
		_assert_true(definition.player_team.size() == 3, "random skirmish player team size is 3")
		_assert_true(definition.enemy_team.size() == 3, "random skirmish enemy team size is 3")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _load_species(slug: String) -> PokemonSpeciesResource:
	return load("res://data/models/pokemon/generated/species/%s.tres" % slug) as PokemonSpeciesResource


func _load_instance(slug: String) -> PokemonInstanceResource:
	var override_path: String = "%s%s.tres" % [CustomSkirmishBuilder.ROSTER_DIR, slug]
	if ResourceLoader.exists(override_path):
		return load(override_path) as PokemonInstanceResource
	var generated_path: String = "%s%s.tres" % [CustomSkirmishBuilder.GENERATED_ROSTER_DIR, slug]
	if ResourceLoader.exists(generated_path):
		return load(generated_path) as PokemonInstanceResource
	return null


func _roster_entries_by_slug() -> Dictionary:
	var out: Dictionary = {}
	for entry in SkirmishRosterProvider.entries():
		out[String(entry.get("slug", ""))] = entry
	return out


func _has_usable_move(instance: PokemonInstanceResource) -> bool:
	for move in instance.move_slots:
		if move != null:
			return true
	return false


func _has_no_external_marker(path: String) -> bool:
	for marker in EXTERNAL_PATH_MARKERS:
		if path.contains(marker):
			return false
	return true


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("smoke: ok - %s" % message)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % message)
