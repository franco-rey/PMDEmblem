@tool
class_name PMDOSkillMapper
extends RefCounted

const RESULT_KIND := "kind"
const RESULT_VALUE := "value"
const RESULT_RAW := "raw_type"

const ATTACK_ACTION_TYPE: String = "RogueEssence.Dungeon.AttackAction, RogueEssence"
const PROJECTILE_ACTION_TYPE: String = "RogueEssence.Dungeon.ProjectileAction, RogueEssence"
const OFFSET_ACTION_TYPE: String = "RogueEssence.Dungeon.OffsetAction, RogueEssence"
const SELF_ACTION_TYPE: String = "RogueEssence.Dungeon.SelfAction, RogueEssence"
const AREA_ACTION_TYPE: String = "RogueEssence.Dungeon.AreaAction, RogueEssence"
const DASH_ACTION_TYPE: String = "RogueEssence.Dungeon.DashAction, RogueEssence"
const THROW_ACTION_TYPE: String = "RogueEssence.Dungeon.ThrowAction, RogueEssence"
const WAVE_MOTION_ACTION_TYPE: String = "RogueEssence.Dungeon.WaveMotionAction, RogueEssence"

const SUPPORTED_HIT_EVENTS: Array = [
	"PMDC.Dungeon.DamageFormulaEvent, PMDC",
	"PMDC.Dungeon.StatusBattleEvent, PMDC",
	"PMDC.Dungeon.StatusStackBattleEvent, PMDC",
	"PMDC.Dungeon.RemoveStatusBattleEvent, PMDC",
	"PMDC.Dungeon.WeatherHPEvent, PMDC",
	"PMDC.Dungeon.HPRecoilEvent, PMDC",
	"PMDC.Dungeon.UserHPDamageEvent, PMDC",
	"PMDC.Dungeon.AdditionalEvent, PMDC",
	"PMDC.Dungeon.AdditionalEndEvent, PMDC",
	"PMDC.Dungeon.OnHitEvent, PMDC",
	"PMDC.Dungeon.ChangeToAbilityEvent, PMDC",
	"PMDC.Dungeon.GiveMapStatusEvent, PMDC",
	"PMDC.Dungeon.WeatherStackEvent, PMDC",
	"PMDC.Dungeon.AddContextStateEvent, PMDC",
	"PMDC.Dungeon.DisableBattleEvent, PMDC",
	"PMDC.Dungeon.FutureAttackEvent, PMDC",
	"PMDC.Dungeon.HPDrainEvent, PMDC",
	"PMDC.Dungeon.HPTo1Event, PMDC",
	"PMDC.Dungeon.LevelDamageEvent, PMDC",
	"PMDC.Dungeon.RandomGroupWarpEvent, PMDC",
	"PMDC.Dungeon.RemoveStateStatusBattleEvent, PMDC",
	"PMDC.Dungeon.RestoreHPEvent, PMDC",
	"PMDC.Dungeon.SpiteEvent, PMDC",
	"PMDC.Dungeon.StatusHPBattleEvent, PMDC",
	"PMDC.Dungeon.StrongestMoveEvent, PMDC",
]


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
		DASH_ACTION_TYPE:
			kind = PokemonMoveResource.TacticalRangeKind.LINE
			value = int(hitbox.get("Range", 1))
		THROW_ACTION_TYPE:
			kind = PokemonMoveResource.TacticalRangeKind.PROJECTILE
			value = int(hitbox.get("Range", 1))
		WAVE_MOTION_ACTION_TYPE:
			kind = PokemonMoveResource.TacticalRangeKind.LINE
			value = int(hitbox.get("Range", 1))
		_:
			kind = PokemonMoveResource.TacticalRangeKind.UNSUPPORTED
			value = int(hitbox.get("Range", 1))
	return {RESULT_KIND: kind, RESULT_VALUE: value, RESULT_RAW: raw_type}


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


static func extract_effect_records(skill_data: Dictionary, move_slug: String, strikes: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if strikes > 1:
		records.append({
			"family": "multi_hit",
			"source_event": "Object.Strikes",
			"target": "hit_target",
			"params": {"hit_count": strikes},
		})
	for key in ["BeforeActions", "OnHits", "AfterActions"]:
		var arr: Variant = skill_data.get(key, [])
		if not (arr is Array):
			continue
		for entry in arr:
			_append_records_for_entry(records, entry, key, move_slug, skill_data)
	return records


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


static func _entry_value(entry: Variant) -> Dictionary:
	if not (entry is Dictionary):
		return {}
	var dict: Dictionary = entry
	if dict.has("Value") and dict["Value"] is Dictionary:
		return dict["Value"]
	if dict.has("$type"):
		return dict
	return {}


static func _append_records_for_entry(records: Array[Dictionary], entry: Variant, source_bucket: String, move_slug: String, skill_data: Dictionary) -> void:
	var value: Dictionary = _entry_value(entry)
	if value.is_empty():
		return
	var tag: String = String(value.get("$type", ""))
	match tag:
		"PMDC.Dungeon.DamageFormulaEvent, PMDC":
			records.append({
				"family": "damage",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": "hit_target",
			})
		"PMDC.Dungeon.StatusBattleEvent, PMDC":
			records.append(_status_record(value, tag, source_bucket))
		"PMDC.Dungeon.StatusStackBattleEvent, PMDC":
			records.append(_status_stack_record(value, tag, source_bucket))
		"PMDC.Dungeon.RemoveStatusBattleEvent, PMDC":
			records.append({
				"family": "status_remove",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": _target_for_event(value),
				"status_id": String(value.get("StatusID", "")),
			})
		"PMDC.Dungeon.WeatherHPEvent, PMDC":
			records.append({
				"family": "heal",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": _target_for_event(value),
				"hp_divisor": int(value.get("HPDiv", 0)),
			})
		"PMDC.Dungeon.HPRecoilEvent, PMDC":
			records.append({
				"family": "recoil",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": "self",
				"fraction": int(value.get("Fraction", 0)),
				"max_hp": bool(value.get("MaxHP", true)),
			})
		"PMDC.Dungeon.UserHPDamageEvent, PMDC":
			records.append({
				"family": "fixed_damage",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": "hit_target",
				"amount": 40 if move_slug == "dragon_rage" else int(value.get("Damage", 0)),
			})
		"PMDC.Dungeon.OnHitEvent, PMDC":
			var on_hit_chance: int = int(value.get("Chance", 100))
			var require_damage: bool = bool(value.get("RequireDamage", false))
			var require_contact: bool = bool(value.get("RequireContact", false))
			var on_hit_events: Variant = value.get("BaseEvents", [])
			if on_hit_events is Array:
				for on_hit_event in on_hit_events:
					var on_hit_before: int = records.size()
					_append_records_for_entry(records, on_hit_event, source_bucket, move_slug, skill_data)
					for i in range(on_hit_before, records.size()):
						records[i]["chance"] = on_hit_chance
						records[i]["require_damage"] = require_damage
						records[i]["require_contact"] = require_contact
						records[i]["wrapped_source_event"] = tag
		"PMDC.Dungeon.ChangeToAbilityEvent, PMDC":
			records.append({
				"family": "ability_change",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": _target_for_event(value),
				"target_ability": String(value.get("TargetAbility", "")),
			})
		"PMDC.Dungeon.GiveMapStatusEvent, PMDC":
			records.append({
				"family": "field_condition",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": "field",
				"condition_id": String(value.get("StatusID", "")),
				"counter": int(value.get("Counter", 0)),
			})
		"PMDC.Dungeon.WeatherStackEvent, PMDC":
			var weather_status_id: String = String(value.get("StatusID", ""))
			if weather_status_id.begins_with("mod_"):
				records.append({
					"family": "weather_stat_stage",
					"source_event": tag,
					"source_bucket": source_bucket,
					"target": _target_for_event(value),
					"weather_id": String(value.get("WeatherID", "")),
					"stat": weather_status_id.substr(4),
					"delta": 1,
					"weather_delta": 2,
					"status_id": weather_status_id,
				})
			elif not weather_status_id.is_empty():
				records.append({
					"family": "status",
					"source_event": tag,
					"source_bucket": source_bucket,
					"target": _target_for_event(value),
					"status_id": weather_status_id,
				})
		"PMDC.Dungeon.RestoreHPEvent, PMDC":
			records.append({
				"family": "heal",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": _target_for_event(value),
				"percent": _fraction(value, "Numerator", "Denominator"),
			})
		"PMDC.Dungeon.HPDrainEvent, PMDC":
			records.append({
				"family": "drain",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": "self",
				"fraction": _fraction(value, "Numerator", "Denominator", 0.5),
			})
		"PMDC.Dungeon.LevelDamageEvent, PMDC":
			records.append({
				"family": "level_damage",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": _target_for_event(value),
				"numerator": int(value.get("Numerator", 1)),
				"denominator": int(value.get("Denominator", 1)),
			})
		"PMDC.Dungeon.DisableBattleEvent, PMDC", "PMDC.Dungeon.FutureAttackEvent, PMDC", "PMDC.Dungeon.StatusHPBattleEvent, PMDC":
			var status_id: String = String(value.get("StatusID", ""))
			if not status_id.is_empty():
				var status_record: Dictionary = _status_record(value, tag, source_bucket)
				if tag == "PMDC.Dungeon.StatusHPBattleEvent, PMDC":
					status_record["hp_divisor"] = int(value.get("HPFraction", 0))
				records.append(status_record)
		"PMDC.Dungeon.RemoveStateStatusBattleEvent, PMDC":
			records.append({
				"family": "cure_statuses",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": _target_for_event(value),
			})
		"PMDC.Dungeon.HPTo1Event, PMDC":
			records.append({
				"family": "hp_to_1",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": _target_for_event(value),
			})
		"PMDC.Dungeon.SpiteEvent, PMDC":
			records.append({
				"family": "pp_damage",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": "hit_target",
				"amount": int(value.get("PP", 0)),
			})
		"PMDC.Dungeon.AddContextStateEvent, PMDC", "PMDC.Dungeon.RandomGroupWarpEvent, PMDC", "PMDC.Dungeon.StrongestMoveEvent, PMDC":
			records.append({
				"family": "tactical_noop",
				"source_event": tag,
				"source_bucket": source_bucket,
				"target": "self",
			})
		"PMDC.Dungeon.AdditionalEvent, PMDC", "PMDC.Dungeon.AdditionalEndEvent, PMDC":
			var chance: int = _additional_effect_chance(skill_data)
			var base_events: Variant = value.get("BaseEvents", [])
			if base_events is Array:
				for base_event in base_events:
					var before_count: int = records.size()
					_append_records_for_entry(records, base_event, source_bucket, move_slug, skill_data)
					for i in range(before_count, records.size()):
						records[i]["chance"] = chance


static func _status_record(value: Dictionary, tag: String, source_bucket: String) -> Dictionary:
	return {
		"family": "status",
		"source_event": tag,
		"source_bucket": source_bucket,
		"target": _target_for_event(value),
		"status_id": String(value.get("StatusID", "")),
	}


static func _status_stack_record(value: Dictionary, tag: String, source_bucket: String) -> Dictionary:
	var status_id: String = String(value.get("StatusID", ""))
	if status_id.begins_with("mod_"):
		return {
			"family": "stat_stage",
			"source_event": tag,
			"source_bucket": source_bucket,
			"target": _target_for_event(value),
			"stat": status_id.substr(4),
			"delta": int(value.get("Stack", 0)),
			"status_id": status_id,
		}
	return {
		"family": "status",
		"source_event": tag,
		"source_bucket": source_bucket,
		"target": _target_for_event(value),
		"status_id": status_id,
		"stack": int(value.get("Stack", 0)),
	}


static func _target_for_event(value: Dictionary) -> String:
	if bool(value.get("SelfInflicted", false)) or not bool(value.get("AffectTarget", true)):
		return "self"
	return "hit_target"


static func _additional_effect_chance(skill_data: Dictionary) -> int:
	var states: Variant = skill_data.get("SkillStates", [])
	if not (states is Array):
		return 100
	for state in states:
		if state is Dictionary and String((state as Dictionary).get("$type", "")) == "PMDC.Dungeon.AdditionalEffectState, PMDC":
			return int((state as Dictionary).get("EffectChance", 100))
	return 100


static func _fraction(value: Dictionary, numerator_key: String, denominator_key: String, fallback: float = 0.0) -> float:
	var denominator: int = int(value.get(denominator_key, 0))
	if denominator <= 0:
		return fallback
	return float(value.get(numerator_key, 1)) / float(denominator)


static func animation_key_for(category: int) -> String:
	match category:
		PokemonMoveResource.CATEGORY_PHYSICAL:
			return "physical_attack"
		PokemonMoveResource.CATEGORY_SPECIAL:
			return "special_attack"
		_:
			return "status_attack"


static func _is_supported(tag: String) -> bool:
	for supported in SUPPORTED_HIT_EVENTS:
		if tag == supported:
			return true
	return false


static func extract_base_power(skill_data: Dictionary) -> int:
	var states: Variant = skill_data.get("SkillStates", [])
	if not (states is Array):
		return 0
	for state in states:
		if state is Dictionary and String(state.get("$type", "")).begins_with("RogueEssence.Dungeon.BasePowerState"):
			return int(state.get("Power", 0))
	return 0
