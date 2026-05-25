extends SceneTree
## M7 smoke: current-roster readiness report is deterministic and complete.

var failures: int = 0


func _init() -> void:
	var readiness := CurrentRosterReadiness.new()
	var first: Dictionary = readiness.build_payload()
	var second: Dictionary = readiness.build_payload()
	_assert_true(JSON.stringify(first) == JSON.stringify(second), "readiness payload is deterministic")
	_assert_true(readiness.write_reports(first), "readiness reports write")
	var loaded: Dictionary = _load_json(CurrentRosterReadiness.REPORT_JSON_PATH)
	_assert_true(not loaded.is_empty(), "readiness JSON reloads")
	_assert_true(int(loaded.get("roster_count", 0)) == CurrentRosterReadiness.CURRENT_ROSTER_PATHS.size(), "readiness roster count matches M7 roster")
	for failure in readiness.validate_payload(loaded):
		_assert_true(false, failure)
	_check_summary(loaded)
	if failures > 0:
		push_error("smoke: import readiness report failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: import_readiness_report clean")
		quit(0)


func _check_summary(payload: Dictionary) -> void:
	var summary: Dictionary = payload.get("summary", {})
	_assert_true(int(summary.get("battle_ready", 0)) == CurrentRosterReadiness.CURRENT_ROSTER_PATHS.size(), "all current-roster entries are battle-ready")
	_assert_true(int(summary.get("animation_states", 0)) >= CurrentRosterReadiness.CURRENT_ROSTER_PATHS.size() * 8, "expanded animation states are summarized")
	_assert_true(int(summary.get("move_animation_mappings", 0)) >= CurrentRosterReadiness.CURRENT_ROSTER_PATHS.size(), "move animation mappings are summarized")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
