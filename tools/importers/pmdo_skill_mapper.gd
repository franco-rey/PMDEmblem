@tool
class_name PMDOSkillMapper
extends RefCounted
## Maps PMDODump `Skill/<slug>.json` payloads onto `PokemonMoveResource` fields.
##
## PMD's tactical model is a roguelike grid where moves are described via
## `HitboxAction` subclasses. We translate those into our enum-based tactical
## range model. Anything we don't recognize is recorded as `unsupported` so the
## move still imports and shows up in the validation report.

const RESULT_KIND := "kind"
const RESULT_VALUE := "value"
const RESULT_RAW := "raw_type"

## PMD `$type` strings the importer knows how to map.
const ATTACK_ACTION_TYPE: String = "RogueEssence.Dungeon.AttackAction, RogueEssence"
const PROJECTILE_ACTION_TYPE: String = "RogueEssence.Dungeon.ProjectileAction, RogueEssence"
const OFFSET_ACTION_TYPE: String = "RogueEssence.Dungeon.OffsetAction, RogueEssence"
const SELF_ACTION_TYPE: String = "RogueEssence.Dungeon.SelfAction, RogueEssence"
const AREA_ACTION_TYPE: String = "RogueEssence.Dungeon.AreaAction, RogueEssence"

## PMD damage event we already plan to support in M2.
const SUPPORTED_HIT_EVENTS: Array = [
	"PMDC.Dungeon.DamageFormulaEvent, PMDC",
]


## Translate a PMD `HitboxAction` dictionary into a `{kind, value, raw_type}`
## triple. Falls back to `UNSUPPORTED`/1 with the raw type recorded so the
## report can show what was skipped.
static func map_hitbox(hitbox: Dictionary) -> Dictionary:
	var raw_type: String = String(hitbox.get("$type", ""))
	var kind: int = PokemonMoveResource.TacticalRangeKind.UNSUPPORTED
	var value: int = 1
	match raw_type:
		ATTACK_ACTION_TYPE:
			kind = PokemonMoveResource.TacticalRangeKind.MELEE
			value = 1
		PROJECTILE_ACTION_TYPE:
			kind = PokemonMoveResource.TacticalRangeKind.PROJECTILE
			value = int(hitbox.get("Range", 1))
		OFFSET_ACTION_TYPE:
			var range_mod: int = int(hitbox.get("RangeMod", 0))
			if range_mod == 0:
				kind = PokemonMoveResource.TacticalRangeKind.MELEE
				value = 1
			else:
				kind = PokemonMoveResource.TacticalRangeKind.LINE
				value = max(1, range_mod + 1)
		SELF_ACTION_TYPE:
			kind = PokemonMoveResource.TacticalRangeKind.SELF
			value = 0
		AREA_ACTION_TYPE:
			kind = PokemonMoveResource.TacticalRangeKind.AREA
			value = int(hitbox.get("Range", 1))
		_:
			kind = PokemonMoveResource.TacticalRangeKind.UNSUPPORTED
			value = int(hitbox.get("Range", 1))
	return {RESULT_KIND: kind, RESULT_VALUE: value, RESULT_RAW: raw_type}


## Return the human-readable label for a `TacticalRangeKind` value, used by
## reports.
static func kind_label(kind: int) -> String:
	match kind:
		PokemonMoveResource.TacticalRangeKind.MELEE: return "melee"
		PokemonMoveResource.TacticalRangeKind.LINE: return "line"
		PokemonMoveResource.TacticalRangeKind.PROJECTILE: return "projectile"
		PokemonMoveResource.TacticalRangeKind.CONE: return "cone"
		PokemonMoveResource.TacticalRangeKind.AREA: return "area"
		PokemonMoveResource.TacticalRangeKind.SELF: return "self"
		PokemonMoveResource.TacticalRangeKind.ALLY: return "ally"
		PokemonMoveResource.TacticalRangeKind.ROOM: return "room"
		PokemonMoveResource.TacticalRangeKind.MAP: return "map"
		_: return "unsupported"


## Walks every `OnHits`, `BeforeActions`, `AfterActions` entry and returns
## `(all_tags, unsupported_tags)`. Unsupported = anything whose `$type` isn't
## in `SUPPORTED_HIT_EVENTS`.
static func extract_effect_tags(skill_data: Dictionary) -> Dictionary:
	var all_tags: Array[String] = []
	var unsupported: Array[String] = []
	for key in ["OnHits", "BeforeActions", "AfterActions"]:
		var arr: Variant = skill_data.get(key, [])
		if not (arr is Array):
			continue
		for entry in arr:
			var tag: String = _entry_type(entry)
			if tag.is_empty():
				continue
			if not all_tags.has(tag):
				all_tags.append(tag)
			if not _is_supported(tag) and not unsupported.has(tag):
				unsupported.append(tag)
	return {"all": all_tags, "unsupported": unsupported}


## PMD events are usually wrapped as `{Key: ..., Value: { "$type": ... }}`.
## Some are flat. This handles both.
static func _entry_type(entry: Variant) -> String:
	if not (entry is Dictionary):
		return ""
	var dict: Dictionary = entry
	if dict.has("$type"):
		return String(dict["$type"])
	if dict.has("Value") and dict["Value"] is Dictionary:
		var inner: Dictionary = dict["Value"]
		if inner.has("$type"):
			return String(inner["$type"])
	return ""


static func _is_supported(tag: String) -> bool:
	for supported in SUPPORTED_HIT_EVENTS:
		if tag == supported:
			return true
	return false


## Reads `BasePowerState.Power` from the SkillStates list. Returns 0 if the
## move has no power state (status moves like Hypnosis).
static func extract_base_power(skill_data: Dictionary) -> int:
	var states: Variant = skill_data.get("SkillStates", [])
	if not (states is Array):
		return 0
	for state in states:
		if state is Dictionary and String(state.get("$type", "")).begins_with("RogueEssence.Dungeon.BasePowerState"):
			return int(state.get("Power", 0))
	return 0
