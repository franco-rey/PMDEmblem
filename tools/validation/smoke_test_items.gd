extends SceneTree
## M8 smoke: generated item resources, bag, consumables, held effects, reports.

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"

var failures: int = 0


func _init() -> void:
	var report: Dictionary = PokemonItemService.validation_report()
	_assert_true(int(report.get("items", 0)) >= 2000, "full PMDO item catalog loads")
	_assert_true(int(report.get("items_with_supported_effects", 0)) > 0, "supported item effects are reported")
	_assert_true(int(report.get("held_passive_items", 0)) > 0, "held passive effects are reported")

	var bag := PokemonBagResource.new()
	var oran: PokemonItemResource = PokemonItemService.load_item("berry_oran")
	var elixir: PokemonItemResource = PokemonItemService.load_item("medicine_elixir")
	var protein: PokemonItemResource = PokemonItemService.load_item("boost_protein")
	var power_band: PokemonItemResource = PokemonItemService.load_item("held_power_band")
	_assert_true(oran != null and elixir != null and protein != null and power_band != null, "sample item resources load")
	bag.add_item(oran, 2)
	_assert_eq(bag.count(oran), 2, "bag add is deterministic")

	var instance: PokemonInstanceResource = PokemonPersistenceService.clone_for_run(load(BULBASAUR_PATH) as PokemonInstanceResource)
	instance.level = 50
	instance.current_hp = 10
	var heal_result: Dictionary = PokemonItemService.use_item(oran, instance, bag)
	_assert_true(bool(heal_result.get("used", false)), "Oran Berry use succeeds")
	_assert_eq(instance.current_hp, PokemonStatCalculator.max_hp(instance), "Oran Berry heals to max")
	_assert_eq(bag.count(oran), 1, "consumable removed from bag")

	instance.pp_state[0] = 0
	PokemonItemService.use_item(elixir, instance)
	_assert_true(instance.pp_state[0] > 0, "Elixir restores PP")

	PokemonItemService.use_item(protein, instance)
	_assert_eq(int(instance.permanent_modifiers.get("attack", 0)), 4, "Protein applies permanent attack modifier")

	_assert_true(PokemonItemService.equip_held_item(instance, power_band), "held item equips")
	var stats := Stats.new()
	stats.init_from_pokemon(instance)
	var attack_without_held: int = int(PokemonStatCalculator.calculate(instance.resolved_form(), instance.level, "", instance.permanent_modifiers).get("attack", 0))
	var attack_with_held: int = int(PokemonStatCalculator.calculate_for_instance(instance).get("attack", 0))
	_assert_true(stats.attack > attack_without_held, "held passive affects spawned stats")
	_assert_eq(stats.attack, attack_with_held, "held passive applies once")
	stats.free()
	_finish("items")


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
