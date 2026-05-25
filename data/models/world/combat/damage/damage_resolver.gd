class_name DamageResolver
extends RefCounted
## Pokemon-flavored deterministic damage resolver for M2 combat.

const STAB_MULTIPLIER: float = 1.5

var _warned_unsupported_moves: Dictionary = {}


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
	result.damage = calculate_damage(attacker, defender, move, result.effectiveness, result.stab)
	return result


func calculate_damage(
		attacker: Stats,
		defender: Stats,
		move: PokemonMoveResource,
		effectiveness: float,
		stab: bool,
		extra_multiplier: float = 1.0
) -> int:
	if attacker == null or defender == null or move == null:
		return 0
	if not move.is_damaging():
		return 0
	if effectiveness <= 0.0:
		return 0

	var attack_stat: int = attacker.battle_stat("attack") if move.category == PokemonMoveResource.CATEGORY_PHYSICAL else attacker.battle_stat("special_attack")
	var defense_stat: int = defender.battle_stat("defense") if move.category == PokemonMoveResource.CATEGORY_PHYSICAL else defender.battle_stat("special_defense")
	var base: float = (float(attacker.level) * 0.4 + 2.0) * float(move.base_power) * float(maxi(attack_stat, 1)) / float(maxi(defense_stat, 1))
	var damage: int = int(floor(base / 50.0 + 2.0))
	var multiplier: float = effectiveness * (STAB_MULTIPLIER if stab else 1.0) * extra_multiplier
	return maxi(1, int(floor(float(damage) * multiplier)))


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
