extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_profile_checks()
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=5 mode=pvp map=chessboard p=0006_charizard@50:flamethrower,air_slash,dragon_claw,roost:blaze|0025_pikachu@50:thunderbolt,quick_attack:static e=0009_blastoise@50:hydro_pump,ice_beam:torrent|0003_venusaur@50:giga_drain,sludge_bomb:overgrow")
	_assert_true(ok, "the difficulty battle launches")
	if not ok:
		_finish()
		return
	var level: TacticsLevel = driver.level
	var chart: TypeChartResource = load("res://data/models/pokemon/generated/types/type_chart.tres") as TypeChartResource
	var charizard: TacticsPawn = level.notation.pawn_for_id("P1")
	var blastoise: TacticsPawn = level.notation.pawn_for_id("E1")
	var allies: Array = level.player.get_children()
	var foes: Array = level.opponent.get_children()

	var ai := BattleAI.new()
	ai.set_level(1)
	var low: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
	ai.set_level(5)
	var high: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
	_assert_true(low.move_index >= 0 and high.move_index >= 0, "both tiers pick a move (L1 slot %d, L5 slot %d)" % [low.move_index, high.move_index])
	_assert_true(low.move_index == 0, "level 1 takes the first usable slot")

	var best_pair_damage: float = 0.0
	var best_pair: String = ""
	for i in range(charizard.stats.move_slots.size()):
		var move: PokemonMoveResource = charizard.stats.move_slots[i]
		if move == null:
			continue
		for foe in foes:
			if not (foe is TacticsPawn) or not (foe as TacticsPawn).is_alive():
				continue
			var value: float = ai._expected_damage(charizard, foe, move, chart)
			if value > best_pair_damage:
				best_pair_damage = value
				best_pair = "%d/%s" % [i, (foe as TacticsPawn).name]
	_assert_true(best_pair_damage > 0.0, "the damage estimator returns a real number for at least one pairing")
	var chosen_pair: String = "%d/%s" % [high.move_index, high.target_unit.name] if high.target_unit != null else ""
	_assert_true(chosen_pair == best_pair, "level 5 takes the best move and target pairing available (%s, best %s)" % [chosen_pair, best_pair])
	_assert_true(high.target_unit != blastoise, "level 5 ignores the nearer resistant target for the one it can hurt")
	_assert_true(low.target_unit == blastoise, "level 1 just walks at the nearest enemy")

	_assert_true(ai._expected_damage(charizard, blastoise, charizard.stats.move_slots[0], chart) < ai._expected_damage(blastoise, charizard, blastoise.stats.move_slots[0], chart), "the estimator respects type advantage (water beats fire)")

	var kо_target: TacticsPawn = blastoise
	kо_target.stats.curr_health = 1
	ai.set_level(4)
	ai.forget(charizard)
	var finisher: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
	_assert_true(finisher.target_unit == kо_target, "level 4 goes for the unit it can knock out")
	kо_target.stats.curr_health = kо_target.stats.max_health

	ai.set_level(2)
	ai.forget(charizard)
	charizard.stats.curr_health = 1
	var heal_item: PokemonItemResource = PokemonItemService.load_item("berry_oran")
	if heal_item != null and charizard.stats.pokemon_instance != null:
		charizard.stats.pokemon_instance.held_item = heal_item
		var healing: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
		_assert_true(healing.intent != null and healing.intent.is_item_action(), "level 2 drinks its berry when badly hurt")
		ai.set_level(1)
		ai.forget(charizard)
		var stubborn: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
		_assert_true(stubborn.intent == null or not stubborn.intent.is_item_action(), "level 1 never uses items")
		charizard.stats.pokemon_instance.held_item = null
	charizard.stats.curr_health = charizard.stats.max_health

	ai.set_team_levels({PokemonInstanceResource.Team.PLAYER: 5, PokemonInstanceResource.Team.ENEMY: 1})
	_assert_true(ai.level_for_team(PokemonInstanceResource.Team.PLAYER) == 5 and ai.level_for_team(PokemonInstanceResource.Team.ENEMY) == 1, "each side can run its own skill level")

	_finish()


func _profile_checks() -> void:
	_assert_true(AIProfile.clamp_level(0) == 1 and AIProfile.clamp_level(9) == 5, "levels clamp to 1 through 5")
	var previous: AIProfile = null
	for level in range(AIProfile.MIN_LEVEL, AIProfile.MAX_LEVEL + 1):
		var profile: AIProfile = AIProfile.for_level(level)
		_assert_true(profile.level == level, "profile %d reports its own level" % level)
		if previous != null:
			var monotone: bool = (
				int(profile.target_mode) >= int(previous.target_mode)
				and int(profile.move_mode) >= int(previous.move_mode)
				and profile.risk_weight >= previous.risk_weight
				and _at_least(profile.avoid_hazards, previous.avoid_hazards)
				and _at_least(profile.threat_aware, previous.threat_aware)
				and _at_least(profile.use_heal_items, previous.use_heal_items)
				and _at_least(profile.shared_focus, previous.shared_focus)
				and _at_least(profile.consider_status_moves, previous.consider_status_moves)
				and _at_least(profile.consider_setup_moves, previous.consider_setup_moves)
				and _at_least(profile.use_throwables, previous.use_throwables)
				and _at_least(profile.team_assignment, previous.team_assignment)
				and _at_least(profile.consider_travel, previous.consider_travel)
			)
			_assert_true(monotone, "level %d never knows less than level %d" % [level, level - 1])
		previous = profile
	_assert_true(AIProfile.for_level(1).risk_weight == 0.0, "level 1 ignores danger entirely")
	_assert_true(AIProfile.for_level(5).consider_travel, "level 5 considers time travel")
	_assert_true(AIProfile.label_for(3) == "Tactical", "levels carry readable names")


func _at_least(current: bool, previous: bool) -> bool:
	return current or not previous


func _finish() -> void:
	if failures > 0:
		push_error("smoke: ai_difficulty failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: ai_difficulty clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
