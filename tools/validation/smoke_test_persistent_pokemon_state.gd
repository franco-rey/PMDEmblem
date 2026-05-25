extends SceneTree
## M8 smoke: HP/PP/XP/level/moves round-trip through Resource save/load.

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"
const SAVE_PATH: String = "user://m8_persistent_pokemon_state.tres"

var failures: int = 0


func _init() -> void:
	var instance: PokemonInstanceResource = PokemonPersistenceService.clone_for_run(load(BULBASAUR_PATH) as PokemonInstanceResource)
	instance.level = 12
	instance.experience = PokemonExperienceService.xp_for_level(instance.resolved_form(), 12)
	instance.nature_id = "calm"
	instance.permanent_modifiers = {"special_defense": 3}
	var stats := Stats.new()
	stats.init_from_pokemon(instance)
	stats.curr_health = 17
	stats.consume_pp(0)
	var snapshot: Dictionary = PokemonPersistenceService.write_runtime_state(stats, instance)
	_assert_eq(int(snapshot.get("current_hp", 0)), 17, "runtime HP captured")
	_assert_true((snapshot.get("pp_state", []) as Array).size() == instance.move_slots.size(), "runtime PP captured")

	var err: int = ResourceSaver.save(instance, SAVE_PATH)
	_assert_eq(err, OK, "instance resource saves")
	var loaded: PokemonInstanceResource = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PokemonInstanceResource
	_assert_true(loaded != null, "instance resource reloads")
	_assert_eq(loaded.current_hp, 17, "current HP persisted")
	_assert_eq(loaded.level, 12, "level persisted")
	_assert_true(loaded.nature_id == "calm", "nature persisted")
	_assert_eq(int(loaded.permanent_modifiers.get("special_defense", 0)), 3, "permanent modifier persisted")
	_assert_true(loaded.pp_state[0] == instance.pp_state[0], "PP persisted")
	stats.free()
	_finish("persistent_pokemon_state")


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
