extends SceneTree
## M8 smoke: level-based starter evolution is executable.

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"

var failures: int = 0


func _init() -> void:
	var instance: PokemonInstanceResource = load(BULBASAUR_PATH) as PokemonInstanceResource
	instance.level = 15
	_assert_true(PokemonEvolutionService.eligible_evolutions(instance).is_empty(), "Bulbasaur is not eligible before level 16")
	instance.level = 16
	instance.experience = PokemonExperienceService.xp_for_level(instance.resolved_form(), 16)
	instance.current_hp = 20
	instance.nature_id = "bold"
	instance.permanent_modifiers = {"defense": 2}
	var eligible: Array[Dictionary] = PokemonEvolutionService.eligible_evolutions(instance)
	_assert_true(eligible.size() == 1 and String(eligible[0].get("result", "")) == "ivysaur", "Bulbasaur can evolve to Ivysaur at 16")
	var result: Dictionary = PokemonEvolutionService.apply_evolution(instance, "ivysaur")
	_assert_true(bool(result.get("evolved", false)), "evolution applies")
	_assert_true(instance.species.species_id == "0002_ivysaur", "species changes to Ivysaur")
	_assert_eq(instance.level, 16, "level preserved")
	_assert_true(instance.nature_id == "bold" and int(instance.permanent_modifiers.get("defense", 0)) == 2, "persistent progression fields preserved")
	_finish("evolution")


func _assert_eq(actual: int, expected: int, label: String) -> void:
	_assert_true(actual == expected, "%s (got %d expected %d)" % [label, actual, expected])


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)


func _finish(name: String) -> void:
	if failures > 0:
		push_error("smoke: %s failed %d check(s)" % [name, failures])
		quit(1)
	else:
		print("smoke: %s clean" % name)
		quit(0)
