class_name DamageResolver
extends RefCounted

const STAB_NUMERATOR: int = 4
const STAB_DENOMINATOR: int = 3
const CRIT_ROLL_SIDES: int = 12
const CRIT_CHANCES: Array[int] = [0, 3, 4, 6, 12]

var _warned_unsupported_moves: Dictionary = {}
var _fallback_rng := RandomNumberGenerator.new()


func _init() -> void:
	_fallback_rng.seed = 0


func resolve(
		attacker: Stats,
		defender: Stats,
		move: PokemonMoveResource,
		type_chart: TypeChartResource,
		rng: RandomNumberGenerator
) -> DamageResult:
	var result := DamageResult.new()
	if attacker == null or defender == null or move == null:
		return result

	result.pp_used = 1
	result.effect_tags = move.effect_tags.duplicate()
	result.hit = AccuracyResolver.roll(move, rng)
	result.effectiveness = _effectiveness(move, defender, type_chart)
	result.stab = type_chart.is_stab(move.type, attacker.types) if type_chart != null else _is_stab(move.type, attacker.types)

	_warn_unsupported_once(move)

	if not result.hit:
		return result
	var outcome: Dictionary = {}
	result.damage = calculate_damage(attacker, defender, move, result.effectiveness, result.stab, 1.0, rng, outcome)
	result.is_critical = bool(outcome.get("is_critical", false))
	return result


func calculate_damage(
		attacker: Stats,
		defender: Stats,
		move: PokemonMoveResource,
		effectiveness: float,
		stab: bool,
		extra_multiplier: float = 1.0,
		rng: RandomNumberGenerator = null,
		outcome: Dictionary = {},
		critical_blocked: bool = false
) -> int:
	if attacker == null or defender == null or move == null:
		return 0
	if not move.is_damaging():
		return 0
	if effectiveness <= 0.0:
		return 0

	var attack_stat: int = attacker.battle_stat("attack") if move.category == PokemonMoveResource.CATEGORY_PHYSICAL else attacker.battle_stat("special_attack")
	var defense_stat: int = defender.battle_stat("defense") if move.category == PokemonMoveResource.CATEGORY_PHYSICAL else defender.battle_stat("special_defense")
	var source_rng: RandomNumberGenerator = rng if rng != null else _fallback_rng
	var crit_level: int = _crit_level_for(move)
	if critical_blocked:
		crit_level = 0
		outcome["critical_blocked"] = true
	var is_critical: bool = _roll_critical(source_rng, crit_level)
	outcome["is_critical"] = is_critical
	outcome["crit_level"] = crit_level

	if is_critical:
		attack_stat = _critical_attack_stat(attacker, move, attack_stat)
		defense_stat = _critical_defense_stat(defender, move, defense_stat)

	var level_term: int = int(attacker.level / 3) + 6
	var base: int = level_term * maxi(attack_stat, 1) * maxi(move.base_power, 0)
	var scaled: int = _apply_pmd_damage_multiplier(base, effectiveness, stab, extra_multiplier, is_critical, _has_intrinsic(attacker, "sniper"))
	var variance: int = source_rng.randi_range(90, 100)
	outcome["variance"] = variance
	var damage: int = int(scaled / maxi(defense_stat, 1))
	damage = int(damage / 50)
	damage = int(damage * variance / 100)
	return maxi(1, damage)


func _effectiveness(move: PokemonMoveResource, defender: Stats, type_chart: TypeChartResource) -> float:
	if type_chart == null:
		return TypeChartResource.DEFAULT_NEUTRAL_MULTIPLIER
	var defender_type1: String = "none"
	var defender_type2: String = "none"
	if defender.types.size() > 0:
		defender_type1 = String(defender.types[0])
	if defender.types.size() > 1:
		defender_type2 = String(defender.types[1])
	return type_chart.get_effectiveness_dual(move.type, defender_type1, defender_type2)


func _is_stab(move_type: String, user_types: Array) -> bool:
	var key: String = move_type.to_lower()
	if key == "none":
		return false
	for t in user_types:
		if String(t).to_lower() == key:
			return true
	return false


func _apply_pmd_damage_multiplier(
		value: int,
		effectiveness: float,
		stab: bool,
		extra_multiplier: float,
		is_critical: bool,
		has_sniper: bool
) -> int:
	var scaled: int = value
	if stab:
		scaled = int(scaled * STAB_NUMERATOR / STAB_DENOMINATOR)
	if is_critical:
		scaled = int(scaled * (5 if has_sniper else 3) / 2)
	scaled = int(floor(float(scaled) * effectiveness))
	scaled = int(floor(float(scaled) * extra_multiplier))
	return scaled


func _crit_level_for(move: PokemonMoveResource) -> int:
	var total: int = 0
	for record in move.effect_records:
		var family: String = String(record.get("family", ""))
		if family == "boost_critical":
			total += int(record.get("crit_level", record.get("add_crit", 0)))
		elif family == "block_critical":
			return 0
	return maxi(0, total)


func _roll_critical(rng: RandomNumberGenerator, crit_level: int) -> bool:
	var bounded: int = clampi(crit_level, 0, CRIT_CHANCES.size() - 1)
	var chance: int = CRIT_CHANCES[bounded]
	if chance <= 0:
		return false
	return rng.randi_range(0, CRIT_ROLL_SIDES - 1) < chance


func _critical_attack_stat(attacker: Stats, move: PokemonMoveResource, current: int) -> int:
	var stat_id: String = "attack" if move.category == PokemonMoveResource.CATEGORY_PHYSICAL else "special_attack"
	if attacker.get_stat_stage(stat_id) >= 0:
		return current
	return maxi(1, attacker.raw_battle_stat(stat_id))


func _critical_defense_stat(defender: Stats, move: PokemonMoveResource, current: int) -> int:
	var stat_id: String = "defense" if move.category == PokemonMoveResource.CATEGORY_PHYSICAL else "special_defense"
	if defender.get_stat_stage(stat_id) <= 0:
		return current
	return maxi(1, defender.raw_battle_stat(stat_id))


func _has_intrinsic(stats: Stats, intrinsic_id: String) -> bool:
	if stats == null:
		return false
	var key: String = intrinsic_id.strip_edges().to_lower()
	if stats.intrinsic_override_active:
		for slug in stats.temporary_intrinsic_slugs:
			if String(slug).to_lower() == key:
				return true
		return false
	for slug in stats.temporary_intrinsic_slugs:
		if String(slug).to_lower() == key:
			return true
	var instance: PokemonInstanceResource = stats.pokemon_instance
	var form: PokemonFormResource = instance.resolved_form() if instance != null else null
	if form == null:
		return false
	for slug in [form.intrinsic1, form.intrinsic2, form.intrinsic3]:
		if String(slug).to_lower() == key:
			return true
	return false


func _warn_unsupported_once(move: PokemonMoveResource) -> void:
	if move.unsupported_effect_tags.is_empty():
		return
	if _warned_unsupported_moves.has(move.move_id):
		return
	_warned_unsupported_moves[move.move_id] = true
	push_warning("M2 ignoring unsupported effect tags for %s: %s" % [
		move.display_name(),
		", ".join(move.unsupported_effect_tags),
	])
