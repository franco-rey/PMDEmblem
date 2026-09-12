extends SmokeCase

const REPORT_PATH: String = "res://data/models/pokemon/import_reports/deferred_effects_report.json"
const VALID_CAPABILITIES: Array[String] = ["maps", "run_loop"]


func _init() -> void:
	var capabilities: BattleCapabilities = BattleCapabilities.new()
	_assert_true(not capabilities.is_enabled(BattleCapabilities.CAPABILITY_MAPS), "maps capability defaults to disabled")
	_assert_true(not capabilities.is_enabled(BattleCapabilities.CAPABILITY_RUN_LOOP), "run_loop capability defaults to disabled")
	var battle_log: BattleLog = BattleLog.new()
	var record: Dictionary = capabilities.defer_effect(
		"map_out_radius",
		BattleCapabilities.CAPABILITY_MAPS,
		"PMDC.Dungeon.MapOutRadiusEvent, PMDC",
		battle_log,
		{"move_id": "flash"}
	)
	_assert_true(String(record.get("message", "")) == "effect_deferred: needs maps", "deferred record carries effect_deferred message")
	_assert_true(battle_log.events.size() == 1, "deferral appends one battle log event")
	if battle_log.events.size() == 1:
		var event: Dictionary = battle_log.events[0]
		_assert_true(String(event.get("kind", "")) == "effect_deferred", "battle log event kind is effect_deferred")
		_assert_true(String(event.get("effect", "")) == "map_out_radius", "battle log event names the effect")
		_assert_true(String(event.get("capability", "")) == "maps", "battle log event names the blocking capability")
	_assert_true(capabilities.deferred_events.size() == 1, "deferral is recorded on the capabilities helper")
	var silent_record: Dictionary = capabilities.defer_effect(
		"map_out_radius",
		BattleCapabilities.CAPABILITY_MAPS,
		"PMDC.Dungeon.MapOutRadiusEvent, PMDC"
	)
	_assert_true(not silent_record.is_empty(), "deferral without a battle log is a safe no-op")
	_assert_true(capabilities.deferred_events.size() == 2, "silent deferral is still recorded")
	capabilities.enable(BattleCapabilities.CAPABILITY_MAPS)
	_assert_true(capabilities.is_enabled(BattleCapabilities.CAPABILITY_MAPS), "enable flips the maps capability")
	_assert_true(not capabilities.is_enabled(BattleCapabilities.CAPABILITY_RUN_LOOP), "run_loop capability is unaffected")
	for effect in BattleCapabilities.GATED_EFFECTS:
		var effect_id: String = String(effect.get("effect", ""))
		_assert_true(not effect_id.is_empty(), "gated effect has an effect id")
		_assert_true(VALID_CAPABILITIES.has(String(effect.get("blocking_capability", ""))), "%s has a valid blocking capability" % effect_id)
		_assert_true(not String(effect.get("source_pmdc_class", "")).is_empty(), "%s cites its PMDC source class" % effect_id)
	var payload: Dictionary = BattleCapabilities.report_payload()
	var entries: Array = payload.get("deferred_effects", [])
	_assert_true(entries.size() == BattleCapabilities.GATED_EFFECTS.size(), "report lists every gated effect")
	_assert_true(_write_text(REPORT_PATH, JSON.stringify(payload, "\t") + "\n"), "deferred effects report written")
	if failures > 0:
		push_error("smoke: deferred_effects failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: deferred_effects clean - gated_effects=%d capabilities=%s" % [
		entries.size(),
		JSON.stringify((payload.get("summary", {}) as Dictionary).get("capability_counts", {})),
	])
	quit(0)


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("smoke: failed to open %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true
