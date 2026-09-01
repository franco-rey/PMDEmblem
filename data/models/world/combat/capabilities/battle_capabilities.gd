class_name BattleCapabilities
extends RefCounted

const CAPABILITY_MAPS: String = "maps"
const CAPABILITY_RUN_LOOP: String = "run_loop"
const GATED_EFFECTS: Array[Dictionary] = [
	{
		"blocking_capability": "maps",
		"effect": "map_out_radius",
		"moves": ["flash"],
		"source_pmdc_class": "PMDC.Dungeon.MapOutRadiusEvent, PMDC",
	},
]

var enabled_capabilities: Dictionary = {
	CAPABILITY_MAPS: false,
	CAPABILITY_RUN_LOOP: false,
}
var deferred_events: Array[Dictionary] = []


func is_enabled(capability: String) -> bool:
	return bool(enabled_capabilities.get(capability, false))


func enable(capability: String) -> void:
	enabled_capabilities[capability] = true


func defer_effect(effect_id: String, capability: String, source_pmdc_class: String, battle_log: BattleLog = null, context: Dictionary = {}) -> Dictionary:
	var record: Dictionary = {
		"capability": capability,
		"context": context.duplicate(true),
		"effect": effect_id,
		"kind": "effect_deferred",
		"message": "effect_deferred: needs %s" % capability,
		"source_pmdc_class": source_pmdc_class,
	}
	deferred_events.append(record)
	if battle_log != null:
		battle_log.append(record)
	return record


static func report_payload() -> Dictionary:
	var entries: Array[Dictionary] = []
	for effect in GATED_EFFECTS:
		var moves: Array[String] = []
		for move in effect.get("moves", []):
			moves.append(String(move))
		moves.sort()
		entries.append({
			"blocking_capability": String(effect["blocking_capability"]),
			"effect": String(effect["effect"]),
			"moves": moves,
			"source_pmdc_class": String(effect["source_pmdc_class"]),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["effect"]) < String(b["effect"])
	)
	var capability_counts: Dictionary = {}
	for entry in entries:
		var capability: String = String(entry["blocking_capability"])
		capability_counts[capability] = int(capability_counts.get(capability, 0)) + 1
	var sorted_counts: Dictionary = {}
	var keys: Array = capability_counts.keys()
	keys.sort()
	for key in keys:
		sorted_counts[key] = capability_counts[key]
	return {
		"deferred_effects": entries,
		"schema_version": 1,
		"source": "BattleCapabilities",
		"summary": {
			"capability_counts": sorted_counts,
			"gated_effect_total": entries.size(),
		},
	}
