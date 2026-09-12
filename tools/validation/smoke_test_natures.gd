extends SmokeCase

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"


func _init() -> void:
	var instance: PokemonInstanceResource = load(BULBASAUR_PATH) as PokemonInstanceResource
	instance.level = 50
	var neutral: Dictionary = PokemonStatCalculator.calculate_for_instance(instance)
	instance.nature_id = "adamant"
	var adamant: Dictionary = PokemonStatCalculator.calculate_for_instance(instance)
	instance.permanent_modifiers = {"attack": 5}
	instance.held_item = PokemonItemService.load_item("held_power_band")
	var boosted: Dictionary = PokemonStatCalculator.calculate_for_instance(instance)

	_assert_true(int(adamant["attack"]) > int(neutral["attack"]), "adamant raises attack")
	_assert_true(int(adamant["special_attack"]) < int(neutral["special_attack"]), "adamant lowers special attack")
	_assert_eq(int(boosted["attack"]), int(adamant["attack"]) + 15, "permanent + held modifiers apply through calculator")
	_finish("natures")
