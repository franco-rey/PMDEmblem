extends SceneTree

const TYPE_CHART_PATH: String = "res://data/models/pokemon/generated/types/type_chart.tres"
const LUCARIO_PATH: String = "res://data/models/pokemon/overrides/instances/0448_lucario.tres"
const MAGMORTAR_PATH: String = "res://data/models/pokemon/overrides/instances/0467_magmortar.tres"
const SCENE_PATH: String = "res://assets/maps/level/test_level.tscn"

var failures: int = 0


func _init() -> void:
	var type_chart: TypeChartResource = load(TYPE_CHART_PATH) as TypeChartResource
	var lucario: Stats = _stats_from_instance(LUCARIO_PATH)
	var magmortar: Stats = _stats_from_instance(MAGMORTAR_PATH)
	if type_chart == null or lucario == null or magmortar == null:
		quit(1)
		return

	_check_type_chart(type_chart)
	_check_accuracy()
	_check_pp(lucario)
	_check_damage_round(lucario, magmortar, type_chart)
	_check_status_and_faint(lucario, magmortar, type_chart)

	lucario.free()
	magmortar.free()
	await _check_scene_attack_flow()

	if failures > 0:
		push_error("smoke: combat resolver failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: combat resolver clean")
		quit(0)


func _stats_from_instance(path: String) -> Stats:
	var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
	if instance == null:
		_fail("could not load instance %s" % path)
		return null
	var stats := Stats.new()
	stats.init_from_pokemon(instance)
	return stats


func _check_type_chart(type_chart: TypeChartResource) -> void:
	_assert_close(type_chart.get_effectiveness("fire", "steel"), 2.0, "fire > steel is super-effective")
	_assert_close(type_chart.get_effectiveness("fighting", "fire"), 1.0, "fighting > fire is neutral")
	_assert_close(type_chart.get_effectiveness("fighting", "poison"), 0.5, "fighting > poison is resisted")
	_assert_close(type_chart.get_effectiveness("normal", "ghost"), 0.0, "normal > ghost is immune")
	_assert_close(type_chart.get_effectiveness_dual("fire", "water", "rock"), 0.25, "fire > water/rock double-resist")
	_assert_close(type_chart.get_effectiveness_dual("fighting", "rock", "steel"), 4.0, "fighting > rock/steel double-super")


func _check_accuracy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var never_miss := PokemonMoveResource.new()
	never_miss.accuracy = PokemonMoveResource.ACCURACY_NEVER_MISS
	_assert_true(AccuracyResolver.roll(never_miss, rng), "sure-hit move never misses")

	var always_miss := PokemonMoveResource.new()
	always_miss.accuracy = 0
	_assert_true(not AccuracyResolver.roll(always_miss, rng), "0 accuracy move can miss")


func _check_pp(lucario: Stats) -> void:
	lucario.refill_all_pp()
	for i in range(8):
		_assert_true(lucario.has_pp(0), "Aura Sphere has PP before use %d" % (i + 1))
		lucario.consume_pp(0)
	_assert_true(not lucario.has_pp(0), "Aura Sphere has no PP after 8 uses")
	_assert_true(lucario.first_usable_move_index(false) == -1, "9th Aura Sphere attempt is rejected")
	lucario.refill_all_pp()


func _check_damage_round(lucario: Stats, magmortar: Stats, type_chart: TypeChartResource) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var resolver := DamageResolver.new()
	var aura_sphere: PokemonMoveResource = lucario.move_slots[0]
	var result: DamageResult = resolver.resolve(lucario, magmortar, aura_sphere, type_chart, rng)
	_assert_true(result.hit, "Aura Sphere hit")
	_assert_true(result.stab, "Aura Sphere gets Lucario STAB")
	_assert_close(result.effectiveness, 1.0, "Fighting > Fire is neutral")
	_assert_true(result.damage == 46, "Aura Sphere damage is deterministic 46")
	lucario.consume_pp(0)
	_assert_true(lucario.current_pp[0] == 7, "Aura Sphere PP decremented 8 -> 7")
	magmortar.apply_to_curr_health(-result.damage)

	var flamethrower: PokemonMoveResource = magmortar.move_slots[0]
	var reply: DamageResult = resolver.resolve(magmortar, lucario, flamethrower, type_chart, rng)
	_assert_true(reply.hit, "Flamethrower hit")
	_assert_true(reply.stab, "Flamethrower gets Magmortar STAB")
	_assert_close(reply.effectiveness, 2.0, "Fire > Fighting/Steel is single-super")
	_assert_true(reply.damage == 127, "Flamethrower damage is deterministic 127 (got %d)" % reply.damage)
	magmortar.consume_pp(0)
	_assert_true(magmortar.current_pp[0] == 7, "Flamethrower PP decremented 8 -> 7")


func _check_status_and_faint(lucario: Stats, magmortar: Stats, type_chart: TypeChartResource) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var resolver := DamageResolver.new()
	var status_move := PokemonMoveResource.new()
	status_move.move_id = "smoke_status"
	status_move.category = PokemonMoveResource.CATEGORY_STATUS
	status_move.accuracy = PokemonMoveResource.ACCURACY_NEVER_MISS
	status_move.pp = 1
	var status_result: DamageResult = resolver.resolve(lucario, magmortar, status_move, type_chart, rng)
	_assert_true(status_result.hit, "status move hits")
	_assert_true(status_result.damage == 0, "status move deals 0 damage in M2")

	magmortar.apply_to_curr_health(-magmortar.curr_health)
	_assert_true(not magmortar.is_active(), "0 HP sets FAINTED battle status")


func _check_scene_attack_flow() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		_fail("could not load %s" % SCENE_PATH)
		return
	var level: TacticsLevel = scene.instantiate() as TacticsLevel
	if level == null:
		_fail("could not instantiate TacticsLevel")
		return
	root.add_child(level)
	for i in range(6):
		await physics_frame

	var lucario: TacticsPawn = _find_pawn_by_species(level.get_node("TacticsParticipant/TacticsPlayer"), "Lucario")
	var magmortar: TacticsPawn = _find_pawn_by_species(level.get_node("TacticsParticipant/TacticsOpponent"), "Magmortar")
	if lucario == null or magmortar == null:
		_fail("scene attack flow could not find Lucario and Magmortar")
		root.remove_child(level)
		level.free()
		return

	lucario.res.selected_move_index = 0
	for i in range(8):
		var done: bool = lucario.attack_target_pawn(magmortar, 0.2)
		await physics_frame
		if done:
			break

	_assert_true(lucario.stats.current_pp[0] == 7, "scene attack consumed Lucario PP")
	_assert_true(magmortar.stats.curr_health == 89, "scene attack applied resolver damage")
	_assert_true(_log_has(level.battle_log, "move_used"), "scene attack logged move_used")
	_assert_true(_log_has(level.battle_log, "damage_dealt"), "scene attack logged damage_dealt")
	_assert_true(_log_has(level.battle_log, "pp_decremented"), "scene attack logged pp_decremented")

	root.remove_child(level)
	level.free()


func _find_pawn_by_species(parent: Node, species_name: String) -> TacticsPawn:
	for child in parent.get_children():
		if child is TacticsPawn and child.stats.species_name == species_name:
			return child
	return null


func _log_has(battle_log: BattleLog, kind: String) -> bool:
	if battle_log == null:
		return false
	for event in battle_log.events:
		if event.get("kind", "") == kind:
			return true
	return false


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		_fail(label)


func _assert_close(actual: float, expected: float, label: String) -> void:
	if is_equal_approx(actual, expected):
		print("smoke: ok - %s (%.2f)" % [label, actual])
	else:
		_fail("%s expected %.2f, got %.2f" % [label, expected, actual])


func _fail(label: String) -> void:
	failures += 1
	push_error("smoke: fail - %s" % label)
