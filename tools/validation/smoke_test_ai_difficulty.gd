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

	_assert_true(high.target_unit != blastoise, "level 5 ignores the nearer resistant target for the one it can hurt")
	_assert_true(low.target_unit == blastoise, "level 1 just walks at the nearest enemy")

	_assert_true(ai._expected_damage(charizard, blastoise, charizard.stats.move_slots[0], chart) < ai._expected_damage(blastoise, charizard, blastoise.stats.move_slots[0], chart), "the estimator respects type advantage (water beats fire)")

	var finisher_target: TacticsPawn = blastoise
	finisher_target.stats.curr_health = 1
	var venusaur: TacticsPawn = level.notation.pawn_for_id("E2")
	ai.set_level(4)
	ai.forget(charizard)
	var finisher: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
	_assert_true(finisher.target_unit == finisher_target, "level 4 goes for the unit it can knock out")
	ai.set_level(3)
	ai.forget(charizard)
	var greedy: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
	_assert_true(greedy.target_unit == finisher_target, "level 3 reaches the same finish through the damage fraction cap, so the knockout bonus is a tie-break rather than a new ordering")
	finisher_target.stats.curr_health = finisher_target.stats.max_health

	ai.set_level(2)
	ai.forget(charizard)
	charizard.stats.curr_health = 1
	var heal_item: PokemonItemResource = PokemonItemService.load_item("berry_oran")
	_assert_true(heal_item != null and charizard.stats.pokemon_instance != null, "the heal item and instance needed for the item checks exist")
	charizard.stats.pokemon_instance.held_item = heal_item
	var healing: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
	_assert_true(healing.intent != null and healing.intent.is_item_action(), "level 2 drinks its berry when badly hurt")
	ai.set_level(1)
	ai.forget(charizard)
	var stubborn: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
	_assert_true(stubborn.intent == null or not stubborn.intent.is_item_action(), "level 1 never uses items")
	ai.set_level(5)
	ai.forget(charizard)
	venusaur.stats.curr_health = 1
	var lethal_first: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
	_assert_true(lethal_first.intent == null or not lethal_first.intent.is_item_action(), "a hurt unit takes a guaranteed knockout instead of drinking")
	venusaur.stats.curr_health = venusaur.stats.max_health
	charizard.stats.pokemon_instance.held_item = null
	charizard.stats.curr_health = charizard.stats.max_health

	ai.set_team_levels({PokemonInstanceResource.Team.PLAYER: 1, PokemonInstanceResource.Team.ENEMY: 5})
	ai.forget(charizard)
	var per_team: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
	ai.set_level(1)
	ai.set_team_levels({})
	ai.forget(charizard)
	var plain_low: AIAction = ai.choose_action(charizard, allies, foes, chart, level)
	_assert_true(per_team.move_index == plain_low.move_index and per_team.target_unit == plain_low.target_unit, "a player unit plays at the level assigned to its own team, not the default")

	_assert_true(_setup_headroom_reads_real_stats(charizard), "setup headroom reads the stat stage keys the game actually stores")
	_assert_true(_range_rules_agree(charizard), "key_in_range agrees with range_from for every range kind")

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
				and _at_least(profile.consider_ability_items, previous.consider_ability_items)
				and _at_least(profile.turn_order_aware, previous.turn_order_aware)
			)
			_assert_true(monotone, "level %d never knows less than level %d" % [level, level - 1])
		previous = profile
	_assert_true(AIProfile.for_level(1).risk_weight == 0.0, "level 1 ignores danger entirely")
	_assert_true(AIProfile.for_level(5).consider_ability_items and not AIProfile.for_level(4).consider_ability_items, "only level 5 folds ability effects into its damage estimate")
	_assert_true(AIProfile.label_for(3) == "Tactical", "levels carry readable names")


func _setup_headroom_reads_real_stats(pawn: TacticsPawn) -> bool:
	var ai := BattleAI.new()
	ai.set_level(4)
	var clean: float = ai._setup_headroom(pawn)
	pawn.stats.stat_stages = {"attack": 4, "evasion": 3, "speed": -2}
	var boosted: float = ai._setup_headroom(pawn)
	pawn.stats.stat_stages = {}
	return is_equal_approx(clean, 1.0) and boosted < 0.5


func _range_rules_agree(unit: TacticsPawn) -> bool:
	var ai := BattleAI.new()
	var move := PokemonMoveResource.new()
	for kind in [
			PokemonMoveResource.TacticalRangeKind.MELEE,
			PokemonMoveResource.TacticalRangeKind.LINE,
			PokemonMoveResource.TacticalRangeKind.PROJECTILE,
			PokemonMoveResource.TacticalRangeKind.AREA,
			PokemonMoveResource.TacticalRangeKind.SELF,
	]:
		move.tactical_range_kind = kind
		for distance in range(1, 5):
			move.tactical_range_value = distance
			for origin in [Vector3i(0, 0, 0), Vector3i(-3, 0, 2)]:
				var listed: Dictionary = {}
				for key in Targeting.range_from(origin, unit, move):
					listed[key] = true
				var reach: int = distance + 2
				for x in range(-reach, reach + 1):
					for z in range(-reach, reach + 1):
						var probe: Vector3i = origin + Vector3i(x, 0, z)
						if listed.has(probe) != Targeting.key_in_range(origin, probe, unit, move):
							push_error("smoke: range mismatch kind=%d distance=%d probe=%s" % [kind, distance, str(probe)])
							return false
	return true


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
