class_name BattleIntrinsicService
extends RefCounted

const PINCH_DAMAGE_BOOSTS: Dictionary = {
	"blaze": "fire",
	"overgrow": "grass",
	"swarm": "bug",
	"torrent": "water",
}
const MAJOR_STATUS_IDS: Array[String] = ["burn", "poison", "poison_toxic", "paralyze", "sleep", "freeze"]
const SLEEP_STATUSES: Array[String] = ["sleep", "asleep", "yawn", "yawning"]
const FLINCH_STATUSES: Array[String] = ["flinch", "cringe"]
const SYNCHRONIZE_STATUSES: Array[String] = ["burn", "poison", "poison_toxic", "paralyze"]
const CRITICAL_BLOCK_INTRINSICS: Array[String] = ["battle_armor", "shell_armor"]
const RECOIL_BLOCK_INTRINSICS: Array[String] = ["rock_head"]
const WEATHER_SPEED_INTRINSICS: Dictionary = {
	"chlorophyll": "sunny",
	"swift_swim": "rain",
}
const STATUS_PREVENTION_BY_INTRINSIC: Dictionary = {
	"immunity": ["poison", "poison_toxic"],
	"limber": ["paralyze"],
	"oblivious": ["in_love", "rage_powder"],
	"own_tempo": ["confuse"],
	"run_away": ["immobilized", "wrap", "bind", "fire_spin", "whirlpool", "sand_tomb", "telekinesis", "clamp", "infestation", "magma_storm"],
	"water_veil": ["burn"],
}
const STAT_DROP_BLOCKS_BY_INTRINSIC: Dictionary = {
	"big_pecks": ["defense"],
	"clear_body": [],
	"hyper_cutter": ["attack"],
	"keen_eye": ["accuracy"],
}
const TYPE_IMMUNITY_BY_INTRINSIC: Dictionary = {
	"levitate": "ground",
}
const ABSORB_HEAL_BY_INTRINSIC: Dictionary = {
	"volt_absorb": "electric",
	"water_absorb": "water",
}
const ABSORB_STAGE_BY_INTRINSIC: Dictionary = {
	"lightning_rod": {"element": "electric", "stat": "special_attack"},
	"sap_sipper": {"element": "grass", "stat": "attack"},
}
const CONTACT_STATUS_BY_INTRINSIC: Dictionary = {
	"flame_body": "burn",
	"poison_point": "poison",
	"static": "paralyze",
}
const SUPPORTED_INTRINSICS: Array[String] = [
	"adaptability",
	"anticipation",
	"battle_armor",
	"big_pecks",
	"blaze",
	"chlorophyll",
	"clear_body",
	"cursed_body",
	"drought",
	"dry_skin",
	"flame_body",
	"flash_fire",
	"frisk",
	"guts",
	"hustle",
	"hyper_cutter",
	"immunity",
	"inner_focus",
	"insomnia",
	"intimidate",
	"iron_fist",
	"justified",
	"keen_eye",
	"levitate",
	"lightning_rod",
	"mega_launcher",
	"oblivious",
	"overgrow",
	"own_tempo",
	"pixilate",
	"poison_point",
	"poison_touch",
	"pressure",
	"rain_dish",
	"rock_head",
	"run_away",
	"sand_force",
	"sap_sipper",
	"shadow_tag",
	"sharpness",
	"sheer_force",
	"shell_armor",
	"sniper",
	"solar_power",
	"steadfast",
	"static",
	"sturdy",
	"swarm",
	"swift_swim",
	"synchronize",
	"telepathy",
	"technician",
	"thick_fat",
	"torrent",
	"tough_claws",
	"trace",
	"volt_absorb",
	"vital_spirit",
	"water_absorb",
]


func log_battle_start(units: Array[BattleUnit], battle_log: BattleLog, battle_level: TacticsLevel = null) -> void:
	if battle_log == null:
		return
	for unit in units:
		if unit == null or unit.pawn == null or unit.stats == null:
			continue
		for slug in intrinsic_slugs_for(unit.stats):
			if SUPPORTED_INTRINSICS.has(slug):
				battle_log.append({
					"kind": "intrinsic_triggered",
					"hook": "battle_start",
					"unit": unit.pawn,
					"intrinsic_id": slug,
					"supported": true,
				})
				if slug == "drought" and battle_level != null:
					battle_level.set_battle_condition("sunny", {"source_intrinsic": slug, "unit": unit.pawn.name})
					battle_log.append({
						"kind": "field_condition_applied",
						"condition_id": "sunny",
						"source": "intrinsic",
						"intrinsic_id": slug,
						"unit": unit.pawn,
					})
			else:
				battle_log.append({
					"kind": "intrinsic_future_only",
					"hook": "battle_start",
					"unit": unit.pawn,
					"intrinsic_id": slug,
				})


func before_damage_multiplier(attacker: Stats, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null, battle_level: TacticsLevel = null) -> float:
	if attacker == null or move == null:
		return 1.0
	var multiplier: float = 1.0
	for slug in intrinsic_slugs_for(attacker):
		var applied_multiplier: float = _damage_multiplier_for_slug(slug, attacker, move, battle_level)
		if is_equal_approx(applied_multiplier, 1.0):
			continue
		multiplier *= applied_multiplier
		if battle_log != null:
			battle_log.append({
				"kind": "intrinsic_triggered",
				"hook": "before_damage",
				"unit": pawn,
				"intrinsic_id": slug,
				"move_id": move.move_id,
				"multiplier": applied_multiplier,
			})
	return multiplier


func defender_damage_multiplier(defender: Stats, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null) -> float:
	if defender == null or move == null:
		return 1.0
	var multiplier: float = 1.0
	for slug in intrinsic_slugs_for(defender):
		var applied_multiplier: float = 1.0
		if slug == "intimidate" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
			applied_multiplier = 2.0 / 3.0
		elif slug == "thick_fat" and (move.type == "fire" or move.type == "ice"):
			applied_multiplier = 0.5
		if is_equal_approx(applied_multiplier, 1.0):
			continue
		multiplier *= applied_multiplier
		if battle_log != null:
			battle_log.append({
				"kind": "intrinsic_triggered",
				"hook": "before_being_hit",
				"unit": pawn,
				"intrinsic_id": slug,
				"move_id": move.move_id,
				"multiplier": applied_multiplier,
			})
	return multiplier


func on_turn_started(pawn: TacticsPawn, battle_level: TacticsLevel, battle_log: BattleLog) -> void:
	if pawn == null or pawn.stats == null or battle_level == null:
		return
	for slug in intrinsic_slugs_for(pawn.stats):
		match slug:
			"rain_dish":
				if battle_level.has_battle_condition("rain"):
					_heal_fraction(pawn, 16, slug, battle_log)
			"dry_skin":
				if battle_level.has_battle_condition("rain"):
					_heal_fraction(pawn, 8, slug, battle_log)
				elif battle_level.has_battle_condition("sunny"):
					_damage_fraction(pawn, 8, slug, battle_log)
			"solar_power":
				if battle_level.has_battle_condition("sunny"):
					_damage_fraction(pawn, 8, slug, battle_log)
			"chlorophyll":
				if battle_level.has_battle_condition("sunny") and battle_log != null:
					battle_log.append({
						"kind": "intrinsic_triggered",
						"hook": "turn_start",
						"unit": pawn,
						"intrinsic_id": slug,
						"condition_id": "sunny",
					})


func apply_speed_modifiers(units: Array[BattleUnit], battle_level: TacticsLevel, battle_log: BattleLog = null) -> void:
	for unit in units:
		if unit == null or unit.stats == null:
			continue
		unit.stats.battle_speed_multiplier = 1.0
		for slug in intrinsic_slugs_for(unit.stats):
			if not WEATHER_SPEED_INTRINSICS.has(slug):
				continue
			var weather_id: String = String(WEATHER_SPEED_INTRINSICS[slug])
			if battle_level == null or not battle_level.has_battle_condition(weather_id):
				continue
			unit.stats.battle_speed_multiplier *= 2.0
			if battle_log != null:
				battle_log.append({
					"kind": "intrinsic_triggered",
					"hook": "speed_modifier",
					"unit": unit.pawn,
					"intrinsic_id": slug,
					"condition_id": weather_id,
					"multiplier": 2.0,
				})


func blocks_status(recipient: Stats, status_id: String, battle_log: BattleLog = null, pawn: TacticsPawn = null, move: PokemonMoveResource = null) -> bool:
	var normalized: String = status_id.strip_edges().to_lower()
	for slug in intrinsic_slugs_for(recipient):
		var blocked: bool = false
		if (slug == "vital_spirit" or slug == "insomnia") and SLEEP_STATUSES.has(normalized):
			blocked = true
		elif (slug == "inner_focus" or slug == "steadfast") and FLINCH_STATUSES.has(normalized):
			blocked = true
		elif STATUS_PREVENTION_BY_INTRINSIC.has(slug) and (STATUS_PREVENTION_BY_INTRINSIC[slug] as Array).has(normalized):
			blocked = true
		if not blocked:
			continue
		if battle_log != null:
			battle_log.append({
				"kind": "status_blocked",
				"unit": pawn,
				"move_id": move.move_id if move != null else "",
				"status_id": normalized,
				"intrinsic_id": slug,
		})
		return true
	return false


func blocks_stat_stage(recipient: Stats, stat_id: String, delta: int, battle_log: BattleLog = null, pawn: TacticsPawn = null, move: PokemonMoveResource = null) -> bool:
	if recipient == null or delta >= 0:
		return false
	var normalized_stat: String = stat_id.strip_edges().to_lower()
	for slug in intrinsic_slugs_for(recipient):
		if not STAT_DROP_BLOCKS_BY_INTRINSIC.has(slug):
			continue
		var protected_stats: Array = STAT_DROP_BLOCKS_BY_INTRINSIC[slug]
		if not protected_stats.is_empty() and not protected_stats.has(normalized_stat):
			continue
		if battle_log != null:
			battle_log.append({
				"kind": "stat_stage_blocked",
				"unit": pawn,
				"move_id": move.move_id if move != null else "",
				"stat": normalized_stat,
				"delta": delta,
				"intrinsic_id": slug,
			})
		return true
	return false


func damage_intercepted(defender: TacticsPawn, move: PokemonMoveResource, battle_log: BattleLog = null) -> bool:
	if defender == null or defender.stats == null or move == null:
		return false
	for slug in intrinsic_slugs_for(defender.stats):
		if TYPE_IMMUNITY_BY_INTRINSIC.has(slug) and move.type == String(TYPE_IMMUNITY_BY_INTRINSIC[slug]):
			_log_damage_intercept(defender, move, slug, "type_immunity", battle_log)
			return true
		if ABSORB_HEAL_BY_INTRINSIC.has(slug) and move.type == String(ABSORB_HEAL_BY_INTRINSIC[slug]):
			_heal_fraction(defender, 4, slug, battle_log)
			_log_damage_intercept(defender, move, slug, "absorb_heal", battle_log)
			return true
		if slug == "flash_fire" and move.type == "fire":
			defender.stats.apply_battle_status("type_boosted", {"source": "intrinsic", "intrinsic_id": slug, "element": "fire", "move_id": move.move_id})
			_log_damage_intercept(defender, move, slug, "absorb_boost", battle_log)
			return true
		if ABSORB_STAGE_BY_INTRINSIC.has(slug):
			var config: Dictionary = ABSORB_STAGE_BY_INTRINSIC[slug]
			if move.type != String(config.get("element", "")):
				continue
			_apply_stat_boost(defender, String(config.get("stat", "")), 1, slug, move, battle_log)
			_log_damage_intercept(defender, move, slug, "absorb_stage", battle_log)
			return true
	return false


func blocks_critical(defender: Stats) -> bool:
	for slug in intrinsic_slugs_for(defender):
		if CRITICAL_BLOCK_INTRINSICS.has(slug):
			return true
	return false


func blocks_recoil(attacker: Stats) -> bool:
	for slug in intrinsic_slugs_for(attacker):
		if RECOIL_BLOCK_INTRINSICS.has(slug):
			return true
	return false


func cap_damage_for_endure(defender: TacticsPawn, requested_damage: int, move: PokemonMoveResource, battle_log: BattleLog = null) -> int:
	if defender == null or defender.stats == null or requested_damage <= 0:
		return requested_damage
	if defender.stats.curr_health != defender.stats.max_health or requested_damage < defender.stats.curr_health:
		return requested_damage
	if not intrinsic_slugs_for(defender.stats).has("sturdy"):
		return requested_damage
	if battle_log != null:
		battle_log.append({
			"kind": "intrinsic_triggered",
			"hook": "damage_endure",
			"unit": defender,
			"intrinsic_id": "sturdy",
			"move_id": move.move_id if move != null else "",
		})
	return maxi(0, defender.stats.curr_health - 1)


func blocks_additional_effect(attacker: Stats, record: Dictionary, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null) -> bool:
	if attacker == null or not intrinsic_slugs_for(attacker).has("sheer_force"):
		return false
	if not _record_is_additional_effect(record, move):
		return false
	if battle_log != null:
		battle_log.append({
			"kind": "effect_blocked",
			"unit": pawn,
			"move_id": move.move_id if move != null else "",
			"effect_family": String(record.get("family", "")),
			"intrinsic_id": "sheer_force",
			"reason": "additional_effect_blocked",
		})
	return true


func maybe_reflect_status(attacker: TacticsPawn, recipient: TacticsPawn, status_id: String, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	if attacker == null or attacker.stats == null or recipient == null or recipient.stats == null:
		return
	var normalized: String = status_id.strip_edges().to_lower()
	if not SYNCHRONIZE_STATUSES.has(normalized):
		return
	if not intrinsic_slugs_for(recipient.stats).has("synchronize"):
		return
	if attacker.stats.battle_statuses.has(normalized):
		return
	attacker.stats.apply_battle_status(normalized, {"source": "synchronize", "move_id": move.move_id if move != null else ""})
	if battle_log != null:
		battle_log.append({
			"kind": "status_applied",
			"unit": attacker,
			"move_id": move.move_id if move != null else "",
			"status_id": normalized,
			"source": "synchronize",
		})


func after_damage(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource, damage_done: int, rng: RandomNumberGenerator, battle_log: BattleLog) -> void:
	if attacker == null or defender == null or attacker.stats == null or defender.stats == null or move == null:
		return
	if damage_done <= 0:
		return
	for slug in intrinsic_slugs_for(defender.stats):
		match slug:
			"justified":
				if move.type == "dark":
					_apply_stat_boost(defender, "attack", 1, slug, move, battle_log)
			"cursed_body":
				if _chance(rng, 30):
					_apply_contact_status(attacker, "disable", slug, move, battle_log)
		if CONTACT_STATUS_BY_INTRINSIC.has(slug) and move.category == PokemonMoveResource.CATEGORY_PHYSICAL and _chance(rng, 30):
			_apply_contact_status(attacker, String(CONTACT_STATUS_BY_INTRINSIC[slug]), slug, move, battle_log)
	for slug in intrinsic_slugs_for(attacker.stats):
		if slug == "poison_touch" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL and _chance(rng, 30):
			_apply_contact_status(defender, "poison", slug, move, battle_log)


func pressure_extra_pp_cost(targets: Array[TacticsPawn]) -> int:
	for target in targets:
		if target != null and target.stats != null and intrinsic_slugs_for(target.stats).has("pressure"):
			return 1
	return 0


func current_intrinsics(stats: Stats) -> Array[String]:
	return intrinsic_slugs_for(stats)


func replace_intrinsic(unit: TacticsPawn, intrinsic_id: String, move: PokemonMoveResource = null, battle_log: BattleLog = null, source_event: String = "") -> Dictionary:
	return replace_intrinsics(unit, [intrinsic_id], move, battle_log, source_event)


func replace_intrinsics(unit: TacticsPawn, intrinsic_ids: Array, move: PokemonMoveResource = null, battle_log: BattleLog = null, source_event: String = "") -> Dictionary:
	if unit == null or unit.stats == null:
		return {}
	var before: Array[String] = intrinsic_slugs_for(unit.stats)
	unit.stats.set_temporary_intrinsics(intrinsic_ids)
	var after: Array[String] = intrinsic_slugs_for(unit.stats)
	var payload: Dictionary = {
		"unit": unit,
		"move_id": move.move_id if move != null else "",
		"source_event": source_event,
		"before": before,
		"after": after,
	}
	_log_intrinsic_changed(payload, battle_log)
	return payload


func restore_natural_intrinsics(unit: TacticsPawn, move: PokemonMoveResource = null, battle_log: BattleLog = null, source_event: String = "") -> Dictionary:
	if unit == null or unit.stats == null:
		return {}
	var before: Array[String] = intrinsic_slugs_for(unit.stats)
	unit.stats.clear_temporary_intrinsics()
	var after: Array[String] = intrinsic_slugs_for(unit.stats)
	var payload: Dictionary = {
		"unit": unit,
		"move_id": move.move_id if move != null else "",
		"source_event": source_event,
		"before": before,
		"after": after,
		"restored": true,
	}
	_log_intrinsic_changed(payload, battle_log)
	return payload


func copy_intrinsics(source: TacticsPawn, recipient: TacticsPawn, move: PokemonMoveResource = null, battle_log: BattleLog = null, source_event: String = "") -> Dictionary:
	if source == null or source.stats == null or recipient == null or recipient.stats == null:
		return {}
	return replace_intrinsics(recipient, intrinsic_slugs_for(source.stats), move, battle_log, source_event)


func swap_intrinsics(first: TacticsPawn, second: TacticsPawn, move: PokemonMoveResource = null, battle_log: BattleLog = null, source_event: String = "") -> Array[Dictionary]:
	if first == null or first.stats == null or second == null or second.stats == null:
		return []
	var first_before: Array[String] = intrinsic_slugs_for(first.stats)
	var second_before: Array[String] = intrinsic_slugs_for(second.stats)
	first.stats.set_temporary_intrinsics(second_before)
	second.stats.set_temporary_intrinsics(first_before)
	var first_payload: Dictionary = {
		"unit": first,
		"move_id": move.move_id if move != null else "",
		"source_event": source_event,
		"before": first_before,
		"after": intrinsic_slugs_for(first.stats),
		"swap_partner": second,
	}
	var second_payload: Dictionary = {
		"unit": second,
		"move_id": move.move_id if move != null else "",
		"source_event": source_event,
		"before": second_before,
		"after": intrinsic_slugs_for(second.stats),
		"swap_partner": first,
	}
	_log_intrinsic_changed(first_payload, battle_log)
	_log_intrinsic_changed(second_payload, battle_log)
	return [first_payload, second_payload]


func intrinsic_slugs_for(stats: Stats) -> Array[String]:
	var out: Array[String] = []
	if stats == null:
		return out
	if stats.intrinsic_override_active:
		for slug in stats.temporary_intrinsic_slugs:
			var temporary_key: String = String(slug)
			if temporary_key.is_empty() or out.has(temporary_key):
				continue
			out.append(temporary_key)
		return out
	for slug in stats.temporary_intrinsic_slugs:
		var override_key: String = String(slug)
		if override_key.is_empty() or out.has(override_key):
			continue
		out.append(override_key)
	if stats.pokemon_instance == null:
		return out
	var form: PokemonFormResource = stats.pokemon_instance.resolved_form()
	if form == null:
		return out
	for slug in [form.intrinsic1, form.intrinsic2, form.intrinsic3]:
		var key: String = String(slug)
		if key.is_empty() or key == "none" or out.has(key):
			continue
		out.append(key)
	return out


func _log_intrinsic_changed(payload: Dictionary, battle_log: BattleLog) -> void:
	if battle_log == null:
		return
	var event: Dictionary = payload.duplicate(true)
	event["kind"] = "intrinsic_changed"
	battle_log.append(event)


func _damage_multiplier_for_slug(slug: String, attacker: Stats, move: PokemonMoveResource, battle_level: TacticsLevel = null) -> float:
	if PINCH_DAMAGE_BOOSTS.has(slug):
		if String(PINCH_DAMAGE_BOOSTS[slug]) == move.type and attacker.curr_health <= int(floor(float(attacker.max_health) / 4.0)):
			return 2.0
	if slug == "sharpness" and _is_slicing_move(move):
		return 1.5
	if slug == "tough_claws" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		return 1.3
	if slug == "mega_launcher" and _is_pulse_move(move):
		return 1.5
	if slug == "guts" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL and _has_major_status(attacker):
		return 1.5
	if slug == "hustle" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		return 4.0 / 3.0
	if slug == "sheer_force" and _move_has_additional_effect(move):
		return 4.0 / 3.0
	if slug == "technician" and move.base_power > 0 and move.base_power <= 40:
		return 1.5
	if slug == "iron_fist" and _is_punch_move(move):
		return 1.25
	if slug == "sand_force" and battle_level != null and (battle_level.has_battle_condition("sandstorm") or battle_level.has_battle_condition("sand")) and ["rock", "ground", "steel"].has(move.type):
		return 4.0 / 3.0
	if attacker.battle_statuses.has("type_boosted"):
		var payload: Variant = attacker.battle_statuses.get("type_boosted", {})
		if payload is Dictionary and String((payload as Dictionary).get("element", "")) == move.type:
			return 1.5
	return 1.0


func _has_major_status(stats: Stats) -> bool:
	for status_id in MAJOR_STATUS_IDS:
		if stats.battle_statuses.has(status_id):
			return true
	return false


func _move_has_additional_effect(move: PokemonMoveResource) -> bool:
	if move == null:
		return false
	for record in move.effect_records:
		if _record_is_additional_effect(record, move):
			return true
	return false


func _record_is_additional_effect(record: Dictionary, move: PokemonMoveResource) -> bool:
	if record.has("wrapped_source_event"):
		return true
	return move != null and move.is_damaging() and record.has("chance") and int(record.get("chance", 100)) < 100


func _is_slicing_move(move: PokemonMoveResource) -> bool:
	var id: String = move.move_id
	return id.contains("cut") or id.contains("slash") or id.contains("blade") or id.contains("cutter") or id == "razor_leaf"


func _is_punch_move(move: PokemonMoveResource) -> bool:
	var id: String = move.move_id
	return id.contains("punch") or id == "comet_punch" or id == "dizzy_punch"


func _is_pulse_move(move: PokemonMoveResource) -> bool:
	var id: String = move.move_id
	return id.contains("pulse") or id == "aura_sphere"


func _heal_fraction(pawn: TacticsPawn, divisor: int, intrinsic_id: String, battle_log: BattleLog) -> void:
	if pawn == null or pawn.stats == null or divisor <= 0:
		return
	var amount: int = maxi(1, int(floor(float(pawn.stats.max_health) / float(divisor))))
	var before: int = pawn.stats.curr_health
	pawn.stats.apply_to_curr_health(amount)
	var healed: int = pawn.stats.curr_health - before
	if healed <= 0 or battle_log == null:
		return
	battle_log.append({
		"kind": "healed",
		"unit": pawn,
		"amount": healed,
		"before": before,
		"after": pawn.stats.curr_health,
		"source": "intrinsic",
		"intrinsic_id": intrinsic_id,
	})


func _damage_fraction(pawn: TacticsPawn, divisor: int, intrinsic_id: String, battle_log: BattleLog) -> void:
	if pawn == null or pawn.stats == null or divisor <= 0:
		return
	var amount: int = maxi(1, int(floor(float(pawn.stats.max_health) / float(divisor))))
	pawn.stats.apply_to_curr_health(-amount)
	if battle_log != null:
		battle_log.append({
			"kind": "damage_dealt",
			"defender": pawn,
			"amount": amount,
			"source": "intrinsic",
			"intrinsic_id": intrinsic_id,
		})


func _log_damage_intercept(pawn: TacticsPawn, move: PokemonMoveResource, intrinsic_id: String, reason: String, battle_log: BattleLog) -> void:
	if battle_log == null:
		return
	battle_log.append({
		"kind": "damage_prevented",
		"unit": pawn,
		"defender": pawn,
		"move_id": move.move_id if move != null else "",
		"source": "intrinsic",
		"intrinsic_id": intrinsic_id,
		"reason": reason,
	})


func _apply_stat_boost(pawn: TacticsPawn, stat_id: String, delta: int, intrinsic_id: String, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	var change: Dictionary = pawn.stats.change_stat_stage(stat_id, delta)
	if change.is_empty() or battle_log == null:
		return
	battle_log.append({
		"kind": "stat_stage_changed",
		"unit": pawn,
		"move_id": move.move_id,
		"stat": change["stat"],
		"before": change["before"],
		"after": change["after"],
		"delta": change["delta"],
		"source": "intrinsic",
		"intrinsic_id": intrinsic_id,
	})


func _apply_contact_status(pawn: TacticsPawn, status_id: String, intrinsic_id: String, move: PokemonMoveResource, battle_log: BattleLog) -> void:
	if pawn == null or pawn.stats == null or status_id.is_empty():
		return
	if pawn.stats.battle_statuses.has(status_id):
		return
	pawn.stats.apply_battle_status(status_id, {"source": "intrinsic", "intrinsic_id": intrinsic_id, "move_id": move.move_id})
	if battle_log != null:
		battle_log.append({
			"kind": "status_applied",
			"unit": pawn,
			"move_id": move.move_id,
			"status_id": status_id,
			"source": "intrinsic",
			"intrinsic_id": intrinsic_id,
		})


func _chance(rng: RandomNumberGenerator, percent: int) -> bool:
	if percent >= 100:
		return true
	if percent <= 0:
		return false
	var source_rng: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	return source_rng.randf() * 100.0 < float(percent)
