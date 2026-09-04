extends SceneTree

const GENERATED_STATUSES_DIR: String = "res://data/models/pokemon/generated/statuses"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves"
const REPORT_PATH: String = "res://data/models/pokemon/import_reports/status_coverage_report.json"
const EXPECTED_STATUSES: int = 85
const CLASSIFICATIONS: Dictionary = {
	"protect": "screen",
	"counter": "screen",
	"light_screen": "screen",
	"lucky_chant": "screen",
	"mist": "screen",
	"reflect": "screen",
	"safeguard": "screen",
	"aqua_ring": "tick",
	"burn": "tick",
	"ingrain": "tick",
	"leech_seed": "tick",
	"poison": "tick",
	"poison_toxic": "tick",
	"confuse": "gate",
	"disable": "gate",
	"encore": "gate",
	"flinch": "gate",
	"freeze": "gate",
	"heal_block": "gate",
	"immobilized": "gate",
	"paralyze": "gate",
	"paused": "gate",
	"sleep": "gate",
	"taunted": "gate",
	"detect": "screen",
	"kings_shield": "screen",
	"crafty_shield": "screen",
	"wide_guard": "screen",
	"endure": "screen",
	"magic_coat": "screen",
	"mirror_coat": "screen",
	"metal_burst": "screen",
	"destiny_bond": "screen",
	"grudge": "screen",
	"focus_energy": "modifier",
	"charge": "modifier",
	"defense_curl": "modifier",
	"stockpile": "modifier",
	"minimized": "modifier",
	"exposed": "modifier",
	"miracle_eye": "modifier",
	"sure_shot": "modifier",
	"electrified": "modifier",
	"enraged": "modifier",
	"telekinesis": "modifier",
	"magnet_rise": "modifier",
	"roosting": "modifier",
	"nightmare": "tick",
	"perish_song": "tick",
	"wish": "tick",
	"future_sight": "tick",
	"yawning": "tick",
	"torment": "gate",
	"powder": "gate",
	"sleepless": "gate",
	"outrage": "gate",
	"thrash": "gate",
	"petal_dance": "gate",
	"bind": "tick",
	"wrap": "tick",
	"clamp": "tick",
	"fire_spin": "tick",
	"sand_tomb": "tick",
	"whirlpool": "tick",
	"magma_storm": "tick",
	"infestation": "tick",
	"in_love": "gate",
	"rooted": "gate",
	"bide": "modifier",
	"mat_block": "screen",
	"snatch": "screen",
	"cud_chew": "tick",
	"embargo": "gate",
	"decoy": "screen",
	"follow_me": "screen",
	"rage_powder": "screen",
	"fairy_lock": "gate",
	"quick_guard": "screen",
	"belch": "modifier",
	"conversion": "modifier",
	"conversion_2": "modifier",
	"mod_accuracy": "modifier",
	"mod_attack": "modifier",
	"mod_defense": "modifier",
	"mod_evasion": "modifier",
	"mod_special_attack": "modifier",
	"mod_special_defense": "modifier",
	"mod_speed": "modifier",
}
const INTRINSIC_APPLIERS: Dictionary = {
	"burn": ["flame_body", "synchronize"],
	"disable": ["cursed_body"],
	"paralyze": ["synchronize"],
	"poison": ["poison_touch", "synchronize"],
	"poison_toxic": ["synchronize"],
}

var failures: int = 0


func _init() -> void:
	var status_slugs: Array[String] = _tres_slugs(GENERATED_STATUSES_DIR)
	_assert_true(status_slugs.size() == EXPECTED_STATUSES, "found %d generated statuses (expected %d)" % [status_slugs.size(), EXPECTED_STATUSES])
	var applier_index: Dictionary = _move_applier_index()
	var entries: Array[Dictionary] = []
	var classification_counts: Dictionary = {}
	var flag_only: Array[String] = []
	var apply_path_missing: Array[String] = []
	for slug in status_slugs:
		var applied_by_moves: Array[String] = _index_lookup(applier_index, "status", slug)
		var stat_stage_moves: Array[String] = _index_lookup(applier_index, "stat_stage", slug)
		var removed_by_moves: Array[String] = _index_lookup(applier_index, "status_remove", slug)
		var applied_by_intrinsics: Array[String] = []
		for intrinsic in INTRINSIC_APPLIERS.get(slug, []):
			applied_by_intrinsics.append(String(intrinsic))
		applied_by_intrinsics.sort()
		var classification: String = String(CLASSIFICATIONS.get(slug, "flag_only"))
		classification_counts[classification] = int(classification_counts.get(classification, 0)) + 1
		if classification == "flag_only":
			flag_only.append(slug)
		if applied_by_moves.is_empty() and applied_by_intrinsics.is_empty() and stat_stage_moves.is_empty():
			apply_path_missing.append(slug)
		entries.append({
			"applied_by_intrinsics": applied_by_intrinsics,
			"applied_by_moves": applied_by_moves,
			"classification": classification,
			"expressed_as_stat_stage_by_moves": stat_stage_moves,
			"removed_by_moves": removed_by_moves,
			"slug": slug,
		})
	flag_only.sort()
	apply_path_missing.sort()
	var sorted_counts: Dictionary = {}
	var count_keys: Array = classification_counts.keys()
	count_keys.sort()
	for key in count_keys:
		sorted_counts[key] = classification_counts[key]
	var payload: Dictionary = {
		"apply_path_missing": apply_path_missing,
		"flag_only_worklist": flag_only,
		"schema_version": 1,
		"source": "smoke_test_status_coverage",
		"statuses": entries,
		"summary": {
			"apply_path_missing_count": apply_path_missing.size(),
			"classification_counts": sorted_counts,
			"status_total": entries.size(),
		},
	}
	_assert_true(_write_text(REPORT_PATH, JSON.stringify(payload, "\t") + "\n"), "status coverage report written")
	if failures > 0:
		push_error("smoke: status_coverage failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: status_coverage clean - statuses=%d classifications=%s flag_only_worklist=%d apply_path_missing=%s" % [
		entries.size(),
		JSON.stringify(sorted_counts),
		flag_only.size(),
		JSON.stringify(apply_path_missing),
	])
	quit(0)


func _move_applier_index() -> Dictionary:
	var out: Dictionary = {"status": {}, "stat_stage": {}, "status_remove": {}}
	for slug in _tres_slugs(GENERATED_MOVES_DIR):
		var move: PokemonMoveResource = load("%s/%s.tres" % [GENERATED_MOVES_DIR, slug]) as PokemonMoveResource
		if move == null:
			continue
		for record in move.effect_records:
			var family: String = String(record.get("family", ""))
			var bucket: String = ""
			match family:
				"status":
					bucket = "status"
				"stat_stage", "weather_stat_stage":
					bucket = "stat_stage"
				"status_remove":
					bucket = "status_remove"
				_:
					continue
			var status_id: String = String(record.get("status_id", ""))
			if status_id.is_empty():
				continue
			var index: Dictionary = out[bucket]
			if not index.has(status_id):
				index[status_id] = {}
			(index[status_id] as Dictionary)[move.move_id] = true
	return out


func _index_lookup(index: Dictionary, bucket: String, status_id: String) -> Array[String]:
	var out: Array[String] = []
	for move_id in ((index[bucket] as Dictionary).get(status_id, {}) as Dictionary).keys():
		out.append(String(move_id))
	out.sort()
	return out


func _tres_slugs(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if not dir.current_is_dir() and name.ends_with(".tres"):
			out.append(name.get_basename())
	dir.list_dir_end()
	out.sort()
	return out


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("smoke: failed to open %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("smoke: ok - %s" % message)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % message)
