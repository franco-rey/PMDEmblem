class_name BattleIntrinsicService
extends RefCounted

const SUPPORTED_DAMAGE_BOOSTS: Dictionary = {
	"blaze": "fire",
	"overgrow": "grass",
	"torrent": "water",
}
const SUPPORTED_INTRINSICS: Array[String] = [
	"adaptability",
	"anticipation",
	"blaze",
	"chlorophyll",
	"cursed_body",
	"drought",
	"dry_skin",
	"flame_body",
	"frisk",
	"inner_focus",
	"justified",
	"mega_launcher",
	"overgrow",
	"pixilate",
	"poison_touch",
	"pressure",
	"rain_dish",
	"shadow_tag",
	"sharpness",
	"solar_power",
	"steadfast",
	"synchronize",
	"telepathy",
	"thick_fat",
	"torrent",
	"tough_claws",
	"trace",
	"vital_spirit",
]
const SLEEP_STATUSES: Array[String] = ["sleep", "asleep", "yawn"]
const FLINCH_STATUSES: Array[String] = ["flinch", "cringe"]
const SYNCHRONIZE_STATUSES: Array[String] = ["burn", "poison", "poison_toxic", "paralyze"]


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


func before_damage_multiplier(attacker: Stats, move: PokemonMoveResource, battle_log: BattleLog = null, pawn: TacticsPawn = null) -> float:
	if attacker == null or move == null:
		return 1.0
	var multiplier: float = 1.0
	for slug in intrinsic_slugs_for(attacker):
		var applied_multiplier: float = _damage_multiplier_for_slug(slug, attacker, move)
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


func blocks_status(recipient: Stats, status_id: String, battle_log: BattleLog = null, pawn: TacticsPawn = null, move: PokemonMoveResource = null) -> bool:
	var normalized: String = status_id.strip_edges().to_lower()
	for slug in intrinsic_slugs_for(recipient):
		var blocked: bool = false
		if (slug == "vital_spirit" or slug == "insomnia") and SLEEP_STATUSES.has(normalized):
			blocked = true
		elif (slug == "inner_focus" or slug == "steadfast") and FLINCH_STATUSES.has(normalized):
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
			"flame_body":
				if move.category == PokemonMoveResource.CATEGORY_PHYSICAL and _chance(rng, 30):
					_apply_contact_status(attacker, "burn", slug, move, battle_log)
			"cursed_body":
				if _chance(rng, 30):
					_apply_contact_status(attacker, "disable", slug, move, battle_log)
	for slug in intrinsic_slugs_for(attacker.stats):
		if slug == "poison_touch" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL and _chance(rng, 30):
			_apply_contact_status(defender, "poison", slug, move, battle_log)


func pressure_extra_pp_cost(targets: Array[TacticsPawn]) -> int:
	for target in targets:
		if target != null and target.stats != null and intrinsic_slugs_for(target.stats).has("pressure"):
			return 1
	return 0


func intrinsic_slugs_for(stats: Stats) -> Array[String]:
	var out: Array[String] = []
	if stats == null:
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


func _damage_multiplier_for_slug(slug: String, attacker: Stats, move: PokemonMoveResource) -> float:
	if SUPPORTED_DAMAGE_BOOSTS.has(slug):
		if String(SUPPORTED_DAMAGE_BOOSTS[slug]) == move.type and attacker.curr_health <= int(floor(float(attacker.max_health) / 3.0)):
			return 1.5
	if slug == "sharpness" and _is_slicing_move(move):
		return 1.5
	if slug == "tough_claws" and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		return 1.3
	if slug == "mega_launcher" and _is_pulse_move(move):
		return 1.5
	return 1.0


func _is_slicing_move(move: PokemonMoveResource) -> bool:
	var id: String = move.move_id
	return id.contains("cut") or id.contains("slash") or id.contains("blade") or id.contains("cutter") or id == "razor_leaf"


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
