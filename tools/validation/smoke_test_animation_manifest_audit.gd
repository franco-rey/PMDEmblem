extends SceneTree

var failures: int = 0


func _init() -> void:
	var readiness := CurrentRosterReadiness.new()
	var payload: Dictionary = readiness.build_payload()
	for raw_entry in payload.get("pokemon", []):
		if not (raw_entry is Dictionary):
			continue
		_check_entry(raw_entry as Dictionary)
	if failures > 0:
		push_error("smoke: animation manifest audit failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: animation_manifest_audit clean")
		quit(0)


func _check_entry(entry: Dictionary) -> void:
	var slug: String = String(entry.get("slug", ""))
	var sprites: Dictionary = entry.get("sprites", {})
	_assert_true(int(sprites.get("animation_state_count", 0)) >= 8, "%s catalogs expanded animation states" % slug)
	_assert_true((sprites.get("external_path_leaks", []) as Array).is_empty(), "%s has no external runtime animation paths" % slug)

	var source_backed: int = 0
	for raw_state in sprites.get("animation_states", []):
		if not (raw_state is Dictionary):
			continue
		var state: Dictionary = raw_state
		var key: String = String(state.get("key", ""))
		var path: String = String(state.get("path", ""))
		_assert_true(path.begins_with("res://"), "%s/%s uses res path" % [slug, key])
		_assert_true(FileAccess.file_exists(path), "%s/%s animation file exists" % [slug, key])
		if not String(state.get("source_filename", "")).is_empty():
			source_backed += 1
			_assert_true(not String(state.get("source_name", "")).is_empty(), "%s/%s records source name" % [slug, key])
			_assert_true(String(state.get("checksum", "")).begins_with("sha256:"), "%s/%s records checksum" % [slug, key])
	_assert_true(source_backed >= 5, "%s has source-backed animation states" % slug)

	var move_map: Dictionary = sprites.get("move_animation_map", {})
	_assert_true(move_map.size() >= int(entry.get("move_slot_count", 0)), "%s maps current move slots to animation states" % slug)
	for raw_move in entry.get("moves", []):
		if not (raw_move is Dictionary):
			continue
		var move: Dictionary = raw_move
		var mapped_key: String = String(move.get("mapped_animation_key", ""))
		_assert_true(not mapped_key.is_empty(), "%s/%s has an animation mapping" % [slug, String(move.get("move_id", ""))])
		_assert_true(_state_exists(sprites, mapped_key), "%s/%s mapped state exists: %s" % [slug, String(move.get("move_id", "")), mapped_key])


func _state_exists(sprites: Dictionary, key: String) -> bool:
	for raw_state in sprites.get("animation_states", []):
		if raw_state is Dictionary and String((raw_state as Dictionary).get("key", "")) == key:
			return true
	return false


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
