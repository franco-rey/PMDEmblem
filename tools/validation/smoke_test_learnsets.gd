extends SceneTree
## M8 smoke: level-up moves produce replacement requests and choices.

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"

var failures: int = 0


func _init() -> void:
	var instance: PokemonInstanceResource = load(BULBASAUR_PATH) as PokemonInstanceResource
	instance.level = 26
	instance.move_slots = [
		PokemonLearnsetService.load_move("tackle"),
		PokemonLearnsetService.load_move("growl"),
		PokemonLearnsetService.load_move("leech_seed"),
		PokemonLearnsetService.load_move("vine_whip"),
	]
	instance.pp_state = [35, 40, 15, 15]
	instance.known_move_ids = PokemonLearnsetService.current_move_ids(instance)

	var pending: Dictionary = PokemonLearnsetService.apply_level_transition(instance, 26, 27)
	_assert_true((pending.get("replacement_requests", []) as Array).size() == 1, "full slots record replacement request")
	_assert_true(PokemonLearnsetService.current_move_ids(instance).has("growl"), "request does not silently replace a move")

	var chosen: Dictionary = PokemonLearnsetService.apply_new_moves(instance, ["double_edge"], {"double_edge": 1})
	_assert_true((chosen.get("learned", []) as Array).has("double_edge"), "replacement choice learns move")
	_assert_true(instance.move_slots[1].move_id == "double_edge", "replacement choice updates selected slot")
	_finish("learnsets")


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
