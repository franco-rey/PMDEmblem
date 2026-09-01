extends SceneTree

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"

class FakePawn:
	extends TacticsPawn

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
	var full_heal: PokemonItemResource = PokemonItemService.load_item("medicine_full_heal")
	var x_attack: PokemonItemResource = PokemonItemService.load_item("medicine_x_attack")
	var charcoal: PokemonItemResource = PokemonItemService.load_item("held_charcoal")
	var flame_plate: PokemonItemResource = PokemonItemService.load_item("held_flame_plate")
	var life_orb: PokemonItemResource = PokemonItemService.load_item("held_life_orb")
	var liechi: PokemonItemResource = PokemonItemService.load_item("berry_liechi")
	_assert_true(oran != null and elixir != null and protein != null and power_band != null and full_heal != null and x_attack != null and charcoal != null and flame_plate != null and life_orb != null and liechi != null, "sample item resources load")
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

	stats.apply_battle_status("burn")
	var cure_result: Dictionary = PokemonItemService.use_item(full_heal, stats)
	_assert_true(bool(cure_result.get("used", false)) and not stats.battle_statuses.has("burn"), "Full Heal cures battle statuses")

	stats.stat_stages = {}
	var x_result: Dictionary = PokemonItemService.use_item(x_attack, stats)
	_assert_true(bool(x_result.get("used", false)) and stats.get_stat_stage("attack") == 2, "X Attack raises battle attack stage")

	var log := BattleLog.new()
	_assert_true(PokemonItemService.give_held_item(stats, charcoal, log, "smoke"), "held item give primitive succeeds")
	_assert_true(PokemonItemService.held_item_for(stats).item_id == charcoal.item_id, "held item lookup returns current item")
	var taken: PokemonItemResource = PokemonItemService.take_held_item(stats, log, "smoke")
	_assert_true(taken == charcoal and PokemonItemService.held_item_for(stats) == null, "held item take primitive removes item")
	PokemonItemService.give_held_item(stats, charcoal, log, "smoke")
	_assert_true(PokemonItemService.consume_held_item(stats, log, "smoke") == charcoal and PokemonItemService.held_item_for(stats) == null, "held item consume primitive removes item")

	PokemonItemService.give_held_item(stats, charcoal, log, "smoke")
	var fire_move := PokemonMoveResource.new()
	fire_move.move_id = "ember"
	fire_move.type = "fire"
	fire_move.category = PokemonMoveResource.CATEGORY_SPECIAL
	_assert_true(is_equal_approx(PokemonItemService.held_damage_multiplier(stats, fire_move), 1.2), "Charcoal boosts Fire move damage")
	PokemonItemService.give_held_item(stats, flame_plate, log, "smoke")
	_assert_true(is_equal_approx(PokemonItemService.held_defense_multiplier(stats, fire_move), 0.5), "Flame Plate halves Fire move damage")

	PokemonItemService.give_held_item(stats, life_orb, log, "smoke")
	var pawn := FakePawn.new()
	pawn.name = "ItemPawn"
	pawn.stats = stats
	var before_life_orb_hp: int = stats.curr_health
	PokemonItemService.after_damage_dealt(pawn, fire_move, 10, log)
	_assert_true(stats.curr_health == before_life_orb_hp - maxi(1, int(floor(float(stats.max_health) / 10.0))), "Life Orb applies post-damage recoil")

	PokemonItemService.give_held_item(stats, liechi, log, "smoke")
	stats.curr_health = int(floor(float(stats.max_health) / 4.0))
	stats.stat_stages = {}
	_assert_true(PokemonItemService.try_trigger_held_threshold(pawn, log), "pinch berry threshold triggers")
	_assert_true(stats.get_stat_stage("attack") == 6 and PokemonItemService.held_item_for(stats) == null, "Liechi Berry maximizes attack and is consumed")
	pawn.free()
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
