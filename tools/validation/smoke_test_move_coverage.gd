extends SmokeCase

const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves"
const REPORT_PATH: String = "res://data/models/pokemon/import_reports/move_coverage_report.json"
const EXPECTED_MOVES: int = 581
const EXPECTED_UNSUPPORTED_MOVES: int = 68
const EXPECTED_UNSUPPORTED_TAG_INSTANCES: int = 69
const TAG_DISPOSITIONS: Dictionary = {
	"PMDC.Dungeon.KnockBackEvent, PMDC": {"disposition": "implemented", "step": "3.1", "gate": ""},
	"PMDC.Dungeon.ThrowBackEvent, PMDC": {"disposition": "implemented", "step": "3.1", "gate": ""},
	"PMDC.Dungeon.SwitcherEvent, PMDC": {"disposition": "implemented", "step": "3.1", "gate": ""},
	"PMDC.Dungeon.HopEvent, PMDC": {"disposition": "implemented", "step": "3.1", "gate": ""},
	"PMDC.Dungeon.WarpAlliesInEvent, PMDC": {"disposition": "implemented", "step": "3.1", "gate": ""},
	"PMDC.Dungeon.RandomWarpEvent, PMDC": {"disposition": "implemented", "step": "3.1", "gate": ""},
	"PMDC.Dungeon.OHKODamageEvent, PMDC": {"disposition": "implemented", "step": "3.2", "gate": ""},
	"PMDC.Dungeon.CutHPDamageEvent, PMDC": {"disposition": "implemented", "step": "3.2", "gate": ""},
	"PMDC.Dungeon.MaxHPDamageEvent, PMDC": {"disposition": "implemented", "step": "3.2", "gate": ""},
	"PMDC.Dungeon.EndeavorEvent, PMDC": {"disposition": "implemented", "step": "3.2", "gate": ""},
	"PMDC.Dungeon.PsywaveDamageEvent, PMDC": {"disposition": "implemented", "step": "3.2", "gate": ""},
	"PMDC.Dungeon.BasePowerDamageEvent, PMDC": {"disposition": "implemented", "step": "3.2", "gate": ""},
	"PMDC.Dungeon.PainSplitEvent, PMDC": {"disposition": "implemented", "step": "3.3", "gate": ""},
	"PMDC.Dungeon.StatSplitEvent, PMDC": {"disposition": "implemented", "step": "3.3", "gate": ""},
	"PMDC.Dungeon.SwapStatsEvent, PMDC": {"disposition": "implemented", "step": "3.3", "gate": ""},
	"PMDC.Dungeon.PowerTrickEvent, PMDC": {"disposition": "implemented", "step": "3.3", "gate": ""},
	"PMDC.Dungeon.ReflectStatsEvent, PMDC": {"disposition": "implemented", "step": "3.3", "gate": ""},
	"PMDC.Dungeon.RestEvent, PMDC": {"disposition": "implemented", "step": "6.3", "gate": ""},
	"PMDC.Dungeon.MirrorMoveEvent, PMDC": {"disposition": "implemented", "step": "6.1", "gate": ""},
	"PMDC.Dungeon.RandomMoveEvent, PMDC": {"disposition": "implemented", "step": "6.1", "gate": ""},
	"PMDC.Dungeon.MimicBattleEvent, PMDC": {"disposition": "implemented", "step": "6.1", "gate": ""},
	"PMDC.Dungeon.SketchBattleEvent, PMDC": {"disposition": "implemented", "step": "6.1", "gate": ""},
	"PMDC.Dungeon.NatureMoveEvent, PMDC": {"disposition": "implemented", "step": "6.1", "gate": ""},
	"PMDC.Dungeon.CopycatEvent, PMDC": {"disposition": "implemented", "step": "6.1", "gate": ""},
	"PMDC.Dungeon.SwapAbilityEvent, PMDC": {"disposition": "implemented", "step": "6.2", "gate": ""},
	"PMDC.Dungeon.ReflectAbilityEvent, PMDC": {"disposition": "implemented", "step": "6.2", "gate": ""},
	"PMDC.Dungeon.ChangeToAbilityEvent, PMDC": {"disposition": "implemented", "step": "6.2", "gate": ""},
	"PMDC.Dungeon.TransferStatusEvent, PMDC": {"disposition": "implemented", "step": "6.3", "gate": ""},
	"PMDC.Dungeon.StatusStateBattleEvent, PMDC": {"disposition": "implemented", "step": "6.3", "gate": ""},
	"PMDC.Dungeon.SetItemStickyEvent, PMDC": {"disposition": "implemented", "step": "6.3", "gate": ""},
	"PMDC.Dungeon.BegItemEvent, PMDC": {"disposition": "implemented", "step": "7.4", "gate": ""},
	"PMDC.Dungeon.BestowItemEvent, PMDC": {"disposition": "implemented", "step": "7.4", "gate": ""},
	"PMDC.Dungeon.LandItemEvent, PMDC": {"disposition": "implemented", "step": "7.4", "gate": ""},
	"PMDC.Dungeon.ItemRestoreEvent, PMDC": {"disposition": "implemented", "step": "7.4", "gate": ""},
	"PMDC.Dungeon.SwitchHeldItemEvent, PMDC": {"disposition": "implemented", "step": "7.4", "gate": ""},
	"PMDC.Dungeon.TransformEvent, PMDC": {"disposition": "decide_type_form_change", "step": "", "gate": ""},
	"PMDC.Dungeon.ChangeToElementEvent, PMDC": {"disposition": "decide_type_form_change", "step": "", "gate": ""},
	"PMDC.Dungeon.AddElementEvent, PMDC": {"disposition": "decide_type_form_change", "step": "", "gate": ""},
	"PMDC.Dungeon.ReflectElementEvent, PMDC": {"disposition": "decide_type_form_change", "step": "", "gate": ""},
	"PMDC.Dungeon.NatureElementEvent, PMDC": {"disposition": "decide_type_form_change", "step": "", "gate": ""},
	"PMDC.Dungeon.OnHitAnyEvent, PMDC": {"disposition": "decide_future_only", "step": "", "gate": ""},
	"PMDC.Dungeon.OnHitEvent, PMDC": {"disposition": "decide_future_only", "step": "", "gate": ""},
	"PMDC.Dungeon.KnockOutNeededEvent, PMDC": {"disposition": "decide_future_only", "step": "", "gate": ""},
	"PMDC.Dungeon.AffectHighestStatBattleEvent, PMDC": {"disposition": "decide_future_only", "step": "", "gate": ""},
	"PMDC.Dungeon.CrashLandEvent, PMDC": {"disposition": "decide_future_only", "step": "", "gate": ""},
	"PMDC.Dungeon.MapOutRadiusEvent, PMDC": {"disposition": "maps_gated", "step": "1.6", "gate": "maps"},
}
const DISPOSITION_PRIORITY: Array[String] = [
	"maps_gated",
	"planned_forced_movement",
	"planned_damage_variant",
	"planned_stat_hp_manipulation",
	"planned_heal_sleep",
	"planned_move_copying",
	"planned_ability_dependent",
	"planned_status_dependent",
	"planned_item_dependent",
	"decide_type_form_change",
	"decide_future_only",
	"implemented",
]


func _init() -> void:
	var slugs: Array[String] = _move_slugs()
	_assert_true(slugs.size() == EXPECTED_MOVES, "found %d generated moves (expected %d)" % [slugs.size(), EXPECTED_MOVES])
	var entries: Array[Dictionary] = []
	var unsupported_moves: int = 0
	var unsupported_tag_instances: int = 0
	var unmapped_tags: Array[String] = []
	var no_effect_moves: Array[String] = []
	var disposition_counts: Dictionary = {}
	for slug in slugs:
		var move: PokemonMoveResource = load("%s/%s.tres" % [GENERATED_MOVES_DIR, slug]) as PokemonMoveResource
		if move == null:
			failures += 1
			push_error("smoke: FAIL - move %s failed to load" % slug)
			continue
		var entry: Dictionary = _entry_for_move(move, unmapped_tags)
		entries.append(entry)
		if not (entry["unsupported_tags"] as Array).is_empty():
			unsupported_moves += 1
			unsupported_tag_instances += (entry["unsupported_tags"] as Array).size()
		if bool(entry["default_use_no_effect"]):
			no_effect_moves.append(slug)
		var disposition: String = String(entry["disposition"])
		disposition_counts[disposition] = int(disposition_counts.get(disposition, 0)) + 1
	no_effect_moves.sort()
	var sorted_disposition_counts: Dictionary = {}
	var disposition_keys: Array = disposition_counts.keys()
	disposition_keys.sort()
	for key in disposition_keys:
		sorted_disposition_counts[key] = disposition_counts[key]
	var payload: Dictionary = {
		"moves": entries,
		"no_effect_moves": no_effect_moves,
		"schema_version": 1,
		"source": "smoke_test_move_coverage",
		"summary": {
			"disposition_counts": sorted_disposition_counts,
			"move_total": entries.size(),
			"no_effect_move_count": no_effect_moves.size(),
			"unsupported_move_count": unsupported_moves,
			"unsupported_tag_instance_count": unsupported_tag_instances,
		},
	}
	_assert_true(unsupported_moves == EXPECTED_UNSUPPORTED_MOVES, "%d moves with unsupported tags (expected %d)" % [unsupported_moves, EXPECTED_UNSUPPORTED_MOVES])
	_assert_true(unsupported_tag_instances == EXPECTED_UNSUPPORTED_TAG_INSTANCES, "%d unsupported tag instances (expected %d)" % [unsupported_tag_instances, EXPECTED_UNSUPPORTED_TAG_INSTANCES])
	_assert_true(unmapped_tags.is_empty(), "every unsupported tag has a disposition")
	for tag in unmapped_tags:
		push_error("smoke: unmapped tag - %s" % tag)
	_assert_true(_write_text(REPORT_PATH, JSON.stringify(payload, "\t") + "\n"), "move coverage report written")
	if failures > 0:
		push_error("smoke: move_coverage failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: move_coverage clean - moves=%d unsupported=%d tag_instances=%d no_effect=%d dispositions=%s" % [
		entries.size(),
		unsupported_moves,
		unsupported_tag_instances,
		no_effect_moves.size(),
		JSON.stringify(sorted_disposition_counts),
	])
	quit(0)


func _entry_for_move(move: PokemonMoveResource, unmapped_tags: Array[String]) -> Dictionary:
	var families: Array[String] = []
	for record in move.effect_records:
		var family: String = String(record.get("family", ""))
		if not family.is_empty() and not families.has(family):
			families.append(family)
	families.sort()
	var unsupported: Array[String] = move.unsupported_effect_tags.duplicate()
	unsupported.sort()
	var supported: Array[String] = []
	for tag in move.effect_tags:
		if not unsupported.has(String(tag)) and not supported.has(String(tag)):
			supported.append(String(tag))
	supported.sort()
	var disposition: String = "implemented"
	var step: String = ""
	var gate: String = ""
	if not unsupported.is_empty():
		var candidates: Array[String] = []
		for tag in unsupported:
			if TAG_DISPOSITIONS.has(tag):
				var mapping: Dictionary = TAG_DISPOSITIONS[tag]
				candidates.append(String(mapping["disposition"]))
				if not String(mapping["gate"]).is_empty():
					gate = String(mapping["gate"])
			elif not unmapped_tags.has(tag):
				unmapped_tags.append(tag)
		disposition = "unclassified"
		for candidate in DISPOSITION_PRIORITY:
			if candidates.has(candidate):
				disposition = candidate
				break
		for tag in unsupported:
			if TAG_DISPOSITIONS.has(tag) and String((TAG_DISPOSITIONS[tag] as Dictionary)["disposition"]) == disposition:
				step = String((TAG_DISPOSITIONS[tag] as Dictionary)["step"])
				break
	var effective_families: Array[String] = families.duplicate()
	effective_families.erase("tactical_noop")
	var no_effect: bool = effective_families.is_empty() and move.base_power <= 0 and not unsupported.is_empty() and disposition != "implemented"
	return {
		"capability_gate": gate,
		"default_use_no_effect": no_effect,
		"disposition": disposition,
		"disposition_step": step,
		"effect_families": families,
		"pmdc_classes": _sorted_unique(move.effect_tags),
		"slug": move.move_id,
		"supported_tags": supported,
		"unsupported_tags": unsupported,
	}


func _move_slugs() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(GENERATED_MOVES_DIR)
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


func _sorted_unique(values: Array) -> Array[String]:
	var seen: Dictionary = {}
	for value in values:
		seen[String(value)] = true
	var out: Array[String] = []
	for key in seen.keys():
		out.append(String(key))
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
