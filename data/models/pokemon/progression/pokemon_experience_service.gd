class_name PokemonExperienceService
extends RefCounted
## EXP table and level transition service backed by generated form data.

const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 100


static func xp_for_level(form: PokemonFormResource, level: int) -> int:
	if form == null or form.exp_table_values.is_empty():
		return _fallback_xp_for_level(level)
	var lv: int = clampi(level, MIN_LEVEL, mini(MAX_LEVEL, form.exp_table_values.size()))
	return int(form.exp_table_values[lv - 1])


static func level_for_xp(form: PokemonFormResource, xp: int) -> int:
	var level: int = MIN_LEVEL
	var max_level: int = form.exp_table_values.size() if form != null and not form.exp_table_values.is_empty() else MAX_LEVEL
	for candidate in range(MIN_LEVEL, max_level + 1):
		if xp_for_level(form, candidate) <= xp:
			level = candidate
		else:
			break
	return level


static func xp_to_next_level(form: PokemonFormResource, level: int, current_xp: int) -> int:
	var next_level: int = clampi(level + 1, MIN_LEVEL, MAX_LEVEL)
	if next_level == level:
		return 0
	return maxi(0, xp_for_level(form, next_level) - current_xp)


static func calculate_xp_reward(defeated: PokemonInstanceResource, context: Dictionary = {}) -> int:
	if defeated == null:
		return 0
	var form: PokemonFormResource = defeated.resolved_form()
	var exp_yield: int = form.exp_yield if form != null else 0
	if exp_yield <= 0 and form != null:
		exp_yield = maxi(1, int(round(float(form.base_stat_total()) / 8.0)))
	var participants: int = maxi(1, int(context.get("participant_count", 1)))
	var multiplier: float = float(context.get("reward_multiplier", 1.0))
	var reward: int = int(floor((float(exp_yield) * float(maxi(1, defeated.level)) / 7.0) * multiplier))
	return maxi(1, int(floor(float(reward) / float(participants))))


static func apply_xp(instance: PokemonInstanceResource, amount: int, replacement_choices: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"old_level": instance.level if instance != null else 0,
		"new_level": instance.level if instance != null else 0,
		"old_xp": instance.experience if instance != null else 0,
		"new_xp": instance.experience if instance != null else 0,
		"xp_gained": amount,
		"new_moves": [],
		"replacement_requests": [],
		"evolution_candidates": [],
	}
	if instance == null or amount <= 0:
		return result
	var form: PokemonFormResource = instance.resolved_form()
	if instance.experience <= 0:
		instance.experience = xp_for_level(form, instance.level)
	var old_level: int = instance.level
	instance.experience = maxi(0, instance.experience + amount)
	var new_level: int = level_for_xp(form, instance.experience)
	var learn_result: Dictionary = PokemonLearnsetService.apply_level_transition(instance, old_level, new_level, replacement_choices)
	instance.level = new_level
	result["old_level"] = old_level
	result["new_level"] = instance.level
	result["old_xp"] = int(result["old_xp"])
	result["new_xp"] = instance.experience
	result["new_moves"] = learn_result.get("learned", [])
	result["replacement_requests"] = learn_result.get("replacement_requests", [])
	result["evolution_candidates"] = PokemonEvolutionService.eligible_evolution_ids(instance)
	return result


static func _fallback_xp_for_level(level: int) -> int:
	var lv: int = clampi(level, MIN_LEVEL, MAX_LEVEL)
	return int(pow(float(lv), 3.0))
