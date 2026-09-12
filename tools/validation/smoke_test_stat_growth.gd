extends SmokeCase

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"
const LUCARIO_PATH: String = "res://data/models/pokemon/overrides/instances/0448_lucario.tres"


func _init() -> void:
	_check_bulbasaur_levels()
	_check_lucario_level_50()
	_finish("stat_growth")


func _check_bulbasaur_levels() -> void:
	var instance: PokemonInstanceResource = load(BULBASAUR_PATH) as PokemonInstanceResource
	instance.level = 1
	var level_1: Dictionary = PokemonStatCalculator.calculate_for_instance(instance)
	instance.level = 50
	var level_50: Dictionary = PokemonStatCalculator.calculate_for_instance(instance)
	_assert_eq(int(level_1["hp"]), 11, "Bulbasaur level 1 HP uses source curve")
	_assert_eq(int(level_50["hp"]), 105, "Bulbasaur level 50 HP uses source curve")
	_assert_eq(int(level_50["special_attack"]), 70, "Bulbasaur level 50 SpA uses source curve")
	_assert_true(int(level_50["hp"]) > int(level_1["hp"]), "stats grow with level")


func _check_lucario_level_50() -> void:
	var instance: PokemonInstanceResource = load(LUCARIO_PATH) as PokemonInstanceResource
	instance.level = 50
	var stats: Dictionary = PokemonStatCalculator.calculate_for_instance(instance)
	_assert_eq(int(stats["hp"]), 130, "Lucario proof/current roster HP")
	_assert_eq(int(stats["attack"]), 115, "Lucario proof/current roster attack")
	_assert_eq(int(stats["special_attack"]), 120, "Lucario proof/current roster special attack")
