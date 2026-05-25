extends SceneTree
## M8 smoke: natures, permanent modifiers, and held passives share stat path.

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"

var failures: int = 0


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
