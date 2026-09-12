extends SmokeCase


func _init() -> void:
	var readiness := CurrentRosterReadiness.new()
	var payload: Dictionary = readiness.build_payload()
	var validation_failures: Array[String] = readiness.validate_payload(payload)
	for failure in validation_failures:
		_assert_true(false, failure)
	_check_unsupported_entries_are_explicit(payload)
	_check_move_families_are_reportable(payload)
	if failures > 0:
		push_error("smoke: roster mechanics audit failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: roster_mechanics_audit clean")
		quit(0)


func _check_unsupported_entries_are_explicit(payload: Dictionary) -> void:
	for raw_entry in payload.get("pokemon", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var slug: String = String(entry.get("slug", ""))
		var unsupported: Array = (entry.get("readiness", {}) as Dictionary).get("unsupported", [])
		for raw_move in entry.get("moves", []):
			if not (raw_move is Dictionary):
				continue
			var move: Dictionary = raw_move
			for tag in move.get("unsupported_effect_tags", []):
				var prefix: String = "move:%s:%s" % [String(move.get("move_id", "")), String(tag)]
				_assert_true(unsupported.has(prefix), "%s unsupported move effect is explicit: %s" % [slug, prefix])
		for raw_intrinsic in entry.get("intrinsics", []):
			if not (raw_intrinsic is Dictionary):
				continue
			var intrinsic: Dictionary = raw_intrinsic
			for hook in intrinsic.get("unsupported_hooks", []):
				var marker: String = "intrinsic:%s:%s" % [String(intrinsic.get("slug", "")), String(hook)]
				_assert_true(unsupported.has(marker), "%s unsupported intrinsic hook is explicit: %s" % [slug, marker])


func _check_move_families_are_reportable(payload: Dictionary) -> void:
	for raw_entry in payload.get("pokemon", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		for raw_move in entry.get("moves", []):
			if not (raw_move is Dictionary):
				continue
			var move: Dictionary = raw_move
			var families: Array = move.get("effect_families", [])
			var unsupported: Array = move.get("unsupported_effect_tags", [])
			var is_status: bool = int(move.get("category", 0)) == PokemonMoveResource.CATEGORY_STATUS
			_assert_true(
				not families.is_empty() or not unsupported.is_empty() or not is_status,
				"%s/%s has supported families or explicit unsupported tags" % [String(entry.get("slug", "")), String(move.get("move_id", ""))]
			)
