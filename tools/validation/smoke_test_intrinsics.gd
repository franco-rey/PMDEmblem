extends SceneTree

const BULBASAUR_PATH: String = "res://data/models/pokemon/generated/instances/0001_bulbasaur.tres"
const CURRENT_SEVEN: Array[String] = [
	"res://data/models/pokemon/overrides/instances/0475_gallade.tres",
	"res://data/models/pokemon/overrides/instances/0448_lucario.tres",
	"res://data/models/pokemon/overrides/instances/0282_gardevoir.tres",
	"res://data/models/pokemon/overrides/instances/0454_toxicroak.tres",
	"res://data/models/pokemon/overrides/instances/0467_magmortar.tres",
	"res://data/models/pokemon/overrides/instances/0094_gengar.tres",
	"res://data/models/pokemon/overrides/instances/0356_dusclops.tres",
]

class FakePawn:
	extends TacticsPawn

var failures: int = 0


func _init() -> void:
	var service := BattleIntrinsicService.new()
	for path in CURRENT_SEVEN:
		var stats: Stats = _stats(path)
		for slug in service.intrinsic_slugs_for(stats):
			var res_path: String = "res://data/models/pokemon/generated/intrinsics/%s.tres" % slug
			_assert_true(ResourceLoader.exists(res_path), "intrinsic resource exists for %s" % slug)
		stats.free()

	var bulba_stats: Stats = _stats(BULBASAUR_PATH)
	bulba_stats.curr_health = 1
	var move := PokemonMoveResource.new()
	move.move_id = "grass_test"
	move.type = "grass"
	var log := BattleLog.new()
	var multiplier: float = service.before_damage_multiplier(bulba_stats, move, log, null)
	_assert_true(is_equal_approx(multiplier, 2.0), "Overgrow PMD pinch damage hook applies")
	_assert_true(_log_has(log, "intrinsic_triggered"), "intrinsic trigger logged")
	bulba_stats.free()

	_check_high_frequency_batch(service)
	_check_ability_swap_primitive(service)

	if failures > 0:
		push_error("smoke: intrinsics failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: intrinsics clean")
		quit(0)


func _stats(path: String) -> Stats:
	var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
	var stats := Stats.new()
	stats.init_from_pokemon(instance)
	return stats


func _check_high_frequency_batch(service: BattleIntrinsicService) -> void:
	var physical := _move("body_slam", "normal", PokemonMoveResource.CATEGORY_PHYSICAL, 80)
	var special := _move("water_pulse", "water", PokemonMoveResource.CATEGORY_SPECIAL, 60)
	var bug := _move("bug_bite", "bug", PokemonMoveResource.CATEGORY_PHYSICAL, 60)

	var swarm := _blank_stats(["swarm"])
	swarm.curr_health = 25
	_assert_true(is_equal_approx(service.before_damage_multiplier(swarm, bug), 2.0), "Swarm uses PMD pinch multiplier")

	var guts := _blank_stats(["guts"])
	guts.apply_battle_status("burn")
	_assert_true(is_equal_approx(service.before_damage_multiplier(guts, physical), 1.5), "Guts boosts physical damage under major status")

	var sheer_force := _blank_stats(["sheer_force"])
	var secondary := _move("force_probe", "normal", PokemonMoveResource.CATEGORY_PHYSICAL, 70)
	var secondary_record: Dictionary = {"family": "status", "target": "hit_target", "status_id": "burn", "chance": 100, "wrapped_source_event": "PMDC.Dungeon.OnHitEvent, PMDC"}
	secondary.effect_records = [{"family": "damage", "target": "hit_target"}, secondary_record]
	_assert_true(is_equal_approx(service.before_damage_multiplier(sheer_force, secondary), 4.0 / 3.0), "Sheer Force boosts moves with additional effects")
	_assert_true(service.blocks_additional_effect(sheer_force, secondary_record, secondary), "Sheer Force blocks additional effects")

	var technician := _blank_stats(["technician"])
	var weak := _move("quick_attack", "normal", PokemonMoveResource.CATEGORY_PHYSICAL, 40)
	_assert_true(is_equal_approx(service.before_damage_multiplier(technician, weak), 1.5), "Technician boosts PMD base power <= 40")

	var sand_level := TacticsLevel.new()
	sand_level.set_battle_condition("sandstorm")
	var sand_force := _blank_stats(["sand_force"])
	var rock := _move("rock_slide", "rock", PokemonMoveResource.CATEGORY_PHYSICAL, 75)
	_assert_true(is_equal_approx(service.before_damage_multiplier(sand_force, rock, null, null, sand_level), 4.0 / 3.0), "Sand Force boosts Rock/Ground/Steel moves in sandstorm")
	sand_level.free()

	var intimidate := _blank_stats(["intimidate"])
	_assert_true(is_equal_approx(service.defender_damage_multiplier(intimidate, physical), 2.0 / 3.0), "Intimidate reduces incoming physical damage")

	var levitate := _pawn_with_intrinsics(["levitate"], "LevitateTarget")
	var ground := _move("earth_power", "ground", PokemonMoveResource.CATEGORY_SPECIAL, 90)
	_assert_true(service.damage_intercepted(levitate, ground), "Levitate prevents Ground-type damage")

	var absorber := _pawn_with_intrinsics(["water_absorb"], "AbsorbTarget")
	absorber.stats.curr_health = 50
	_assert_true(service.damage_intercepted(absorber, special), "Water Absorb intercepts Water-type damage")
	_assert_true(absorber.stats.curr_health == 75, "Water Absorb heals one quarter max HP")

	var flash_fire := _pawn_with_intrinsics(["flash_fire"], "FlashFireTarget")
	var fire := _move("ember", "fire", PokemonMoveResource.CATEGORY_SPECIAL, 40)
	_assert_true(service.damage_intercepted(flash_fire, fire), "Flash Fire intercepts Fire-type damage")
	_assert_true(flash_fire.stats.battle_statuses.has("type_boosted"), "Flash Fire stores Fire boost status")
	_assert_true(is_equal_approx(service.before_damage_multiplier(flash_fire.stats, fire), 1.5), "Flash Fire boost powers Fire moves")

	var sturdy := _pawn_with_intrinsics(["sturdy"], "SturdyTarget")
	_assert_true(service.cap_damage_for_endure(sturdy, 150, physical) == 99, "Sturdy endures from full HP")

	var own_tempo := _blank_stats(["own_tempo"])
	_assert_true(service.blocks_status(own_tempo, "confuse"), "Own Tempo blocks confusion")
	var immunity := _blank_stats(["immunity"])
	_assert_true(service.blocks_status(immunity, "poison_toxic"), "Immunity blocks poison")
	var run_away := _blank_stats(["run_away"])
	_assert_true(service.blocks_status(run_away, "immobilized"), "Run Away blocks trapping statuses")

	var clear_body := _blank_stats(["clear_body"])
	_assert_true(service.blocks_stat_stage(clear_body, "attack", -1), "Clear Body blocks stat drops")
	var keen_eye := _blank_stats(["keen_eye"])
	_assert_true(service.blocks_stat_stage(keen_eye, "accuracy", -1), "Keen Eye blocks accuracy drops")
	var big_pecks := _blank_stats(["big_pecks"])
	_assert_true(service.blocks_stat_stage(big_pecks, "defense", -1), "Big Pecks blocks defense drops")

	var shell_armor := _blank_stats(["shell_armor"])
	_assert_true(service.blocks_critical(shell_armor), "Shell Armor blocks critical hits")
	var rock_head := _blank_stats(["rock_head"])
	_assert_true(service.blocks_recoil(rock_head), "Rock Head blocks recoil")

	var level := TacticsLevel.new()
	level.set_battle_condition("rain")
	var swimmer := _pawn_with_intrinsics(["swift_swim"], "SwiftSwimUser")
	var unit := BattleUnit.new(swimmer, swimmer.stats, 0, 0, 0)
	service.apply_speed_modifiers([unit], level)
	_assert_true(swimmer.stats.battle_stat("speed") == 20, "Swift Swim doubles scheduler speed in rain")
	levitate.free()
	absorber.free()
	flash_fire.free()
	sturdy.free()
	swimmer.free()
	level.free()


func _check_ability_swap_primitive(service: BattleIntrinsicService) -> void:
	var move := _move("ability_probe", "normal", PokemonMoveResource.CATEGORY_STATUS, 0)
	var log := BattleLog.new()
	var target := _pawn_with_intrinsics(["pressure"], "AbilityTarget")
	var change: Dictionary = service.replace_intrinsic(target, "insomnia", move, log, "PMDC.Dungeon.ChangeToAbilityEvent, PMDC")
	_assert_true((change.get("before", []) as Array).has("pressure"), "ability replace records the previous intrinsic")
	_assert_true(service.current_intrinsics(target.stats) == ["insomnia"], "ability replace overrides natural intrinsics")
	_assert_true(_log_has(log, "intrinsic_changed"), "ability replace logs intrinsic change")

	service.replace_intrinsic(target, "none", move, log, "PMDC.Dungeon.ChangeToAbilityEvent, PMDC")
	_assert_true(service.current_intrinsics(target.stats).is_empty(), "ability replace supports no-ability override")

	var source := _pawn_with_intrinsics(["levitate"], "AbilitySource")
	service.copy_intrinsics(source, target, move, log, "PMDC.Dungeon.ReflectAbilityEvent, PMDC")
	_assert_true(service.current_intrinsics(target.stats) == ["levitate"], "ability copy mirrors source intrinsics")

	var other := _pawn_with_intrinsics(["swift_swim"], "AbilityOther")
	service.swap_intrinsics(source, other, move, log, "PMDC.Dungeon.SwapAbilityEvent, PMDC")
	_assert_true(service.current_intrinsics(source.stats) == ["swift_swim"], "ability swap gives first unit the second intrinsic")
	_assert_true(service.current_intrinsics(other.stats) == ["levitate"], "ability swap gives second unit the first intrinsic")

	var natural := _pawn_for_instance(BULBASAUR_PATH, "NaturalAbility")
	service.replace_intrinsic(natural, "insomnia", move, log)
	service.restore_natural_intrinsics(natural, move, log)
	_assert_true(service.current_intrinsics(natural.stats).has("overgrow"), "ability restore returns natural intrinsics")
	target.free()
	source.free()
	other.free()
	natural.free()


func _blank_stats(intrinsics: Array[String]) -> Stats:
	var stats := Stats.new()
	stats.max_health = 100
	stats.hp_max = 100
	stats.curr_health = 100
	stats.level = 50
	stats.attack = 80
	stats.defense = 80
	stats.special_attack = 80
	stats.special_defense = 80
	stats.speed = 10
	stats.battle_status = Stats.BattleStatus.ACTIVE
	stats.temporary_intrinsic_slugs = intrinsics.duplicate()
	return stats


func _pawn_with_intrinsics(intrinsics: Array[String], pawn_name: String) -> FakePawn:
	var pawn := FakePawn.new()
	pawn.name = pawn_name
	pawn.stats = _blank_stats(intrinsics)
	pawn.add_child(pawn.stats)
	return pawn


func _pawn_for_instance(path: String, pawn_name: String) -> FakePawn:
	var pawn := FakePawn.new()
	pawn.name = pawn_name
	pawn.stats = _stats(path)
	pawn.add_child(pawn.stats)
	return pawn


func _move(move_id: String, type_id: String, category: int, power: int) -> PokemonMoveResource:
	var move := PokemonMoveResource.new()
	move.move_id = move_id
	move.name = move_id.capitalize()
	move.type = type_id
	move.category = category
	move.base_power = power
	move.accuracy = PokemonMoveResource.ACCURACY_NEVER_MISS
	move.pp = 9
	return move


func _log_has(log: BattleLog, kind: String) -> bool:
	for event in log.events:
		if event.get("kind", "") == kind:
			return true
	return false


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
