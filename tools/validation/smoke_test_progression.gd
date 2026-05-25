extends SceneTree
## M8 smoke: EXP rewards and level transitions are deterministic.

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"
const SQUIRTLE_PATH: String = "res://data/models/pokemon/generated/instances/0007_squirtle.tres"

var failures: int = 0


func _init() -> void:
	var bulba: PokemonInstanceResource = load(BULBASAUR_PATH) as PokemonInstanceResource
	var form: PokemonFormResource = bulba.resolved_form()
	_assert_eq(PokemonExperienceService.xp_for_level(form, 16), 2535, "medium_slow level 16 threshold")
	_assert_eq(PokemonExperienceService.level_for_xp(form, 2535), 16, "level lookup from EXP")

	var defeated: PokemonInstanceResource = load(SQUIRTLE_PATH) as PokemonInstanceResource
	defeated.level = 12
	var reward: int = PokemonExperienceService.calculate_xp_reward(defeated)
	_assert_true(reward > 0, "defeated enemy grants non-zero EXP")

	bulba.level = 8
	bulba.experience = PokemonExperienceService.xp_for_level(form, 8)
	bulba.move_slots = [
		PokemonLearnsetService.load_move("tackle"),
		PokemonLearnsetService.load_move("growl"),
		PokemonLearnsetService.load_move("leech_seed"),
	]
	bulba.pp_state = [35, 40, 15]
	var amount: int = PokemonExperienceService.xp_for_level(form, 9) - bulba.experience
	var result: Dictionary = PokemonExperienceService.apply_xp(bulba, amount)
	_assert_eq(bulba.level, 9, "apply_xp advances level")
	_assert_true((result.get("new_moves", []) as Array).has("vine_whip"), "level-up reports new move")
	_finish("progression")


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
