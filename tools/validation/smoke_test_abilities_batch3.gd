extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var failures: int = 0
var resolver: BattleActionResolver = BattleActionResolver.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _ability_checks()
	await _move_checks()
	if failures > 0:
		push_error("smoke: abilities_batch3 failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: abilities_batch3 clean")
	quit(0)


func _ability_checks() -> void:
	var setup: Dictionary = await _level("0006_charizard", ["slash", "flamethrower", "growl", "earthquake"], "0009_blastoise", ["tackle", "water_gun", "withdraw", "toxic"], "", "")
	var level: TacticsLevel = setup["level"]
	var charizard: TacticsPawn = setup["attacker"]
	var blastoise: TacticsPawn = setup["defender"]
	var ops: BattleStateOps = level._ops()
	var service: BattleIntrinsicService = resolver.intrinsic_service
	_assert_true(charizard.stats.gender != GenderRules.GENDERLESS and charizard.stats.weight_kg > 50.0, "instances roll a gender and carry the form weight (%d, %.1f)" % [charizard.stats.gender, charizard.stats.weight_kg])
	_set_ability(blastoise, "arena_trap")
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(not charizard.stats.battle_statuses.has("rooted"), "Arena Trap does not root a Flying attacker")
	charizard.stats.types = ["fire"] as Array[String]
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(charizard.stats.battle_statuses.has("rooted") and level.is_trapped(charizard), "Arena Trap roots a grounded attacker so it cannot move")
	ops.remove_status(charizard, "rooted", {"source": "test"})
	charizard.stats.types = ["fire", "flying"] as Array[String]
	_set_ability(blastoise, "shadow_tag")
	_execute_until_hit(charizard, blastoise, 1, level)
	_assert_true(charizard.stats.battle_statuses.has("rooted"), "Shadow Tag roots any attacker")
	ops.remove_status(charizard, "rooted", {"source": "test"})
	_set_ability(blastoise, "torrent")
	_set_ability(charizard, "stall")
	blastoise.stats.last_attacker = null
	var baseline: int = _hit_damage(level, charizard, blastoise, 0)
	_execute_until_hit(blastoise, charizard, 0, level)
	var revenge: int = _hit_damage(level, charizard, blastoise, 0)
	_assert_true(revenge > baseline, "Stall hits harder against the foe that last attacked it (%d vs %d)" % [revenge, baseline])
	_set_ability(charizard, "rivalry")
	charizard.stats.gender = GenderRules.MALE
	blastoise.stats.gender = GenderRules.MALE
	var same: int = _hit_damage(level, charizard, blastoise, 0)
	blastoise.stats.gender = GenderRules.FEMALE
	var opposite: int = _hit_damage(level, charizard, blastoise, 0)
	_assert_true(same > opposite, "Rivalry deals more to the same gender than to the opposite (%d vs %d)" % [same, opposite])
	_set_ability(charizard, "natural_cure")
	ops.apply_status(charizard, "burn", {}, {"kind": "test", "skip_rules": true})
	charizard.stats.curr_health = charizard.stats.max_health
	level._on_turn_started(_unit_for(level, charizard))
	_assert_true(not charizard.stats.battle_statuses.has("burn"), "Natural Cure cures a status at full HP on its turn")
	_set_ability(charizard, "regenerator")
	charizard.stats.curr_health = 50
	var far: Vector3i = Vector3i.ZERO
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var charizard_key: Vector3i = resolver._unit_key(charizard)
	for key in keys.keys():
		if maxi(absi(key.x - charizard_key.x), absi(key.z - charizard_key.z)) > 6 and not (keys[key] as TacticsTile).is_taken():
			far = key
			break
	var blastoise_key: Vector3i = resolver._unit_key(blastoise)
	_settle_on_tile(blastoise, keys[far])
	level._on_turn_started(_unit_for(level, charizard))
	_assert_true(charizard.stats.curr_health > 50, "Regenerator heals when no foe is within five tiles (%d)" % charizard.stats.curr_health)
	_settle_on_tile(blastoise, keys[blastoise_key])
	_set_ability(charizard, "blaze")
	_set_ability(blastoise, "cute_charm")
	blastoise.stats.gender = GenderRules.FEMALE
	charizard.stats.gender = GenderRules.MALE
	var charmed: bool = false
	for attempt in range(40):
		blastoise.stats.curr_health = blastoise.stats.max_health
		_execute_until_hit(charizard, blastoise, 0, level)
		if charizard.stats.battle_statuses.has("in_love"):
			charmed = true
			break
	_assert_true(charmed, "Cute Charm infatuates a contact attacker of the opposite gender")
	var blocked: bool = false
	blastoise.stats.curr_health = blastoise.stats.max_health
	for attempt in range(20):
		var start: int = level.battle_log.events.size()
		resolver.execute(charizard, blastoise, 2, level)
		for i in range(start, level.battle_log.events.size()):
			if String(level.battle_log.events[i].get("kind", "")) == "move_blocked" and String(level.battle_log.events[i].get("reason", "")) == "infatuated":
				blocked = true
	_assert_true(blocked, "infatuation makes moves fail half the time")
	ops.remove_status(charizard, "in_love", {"source": "test"})
	_set_ability(blastoise, "pickpocket")
	blastoise.stats.curr_health = blastoise.stats.max_health
	charizard.stats.curr_health = charizard.stats.max_health
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("held_life_orb")
	blastoise.stats.pokemon_instance.held_item = null
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(PokemonItemService.held_item_for(blastoise.stats) != null and PokemonItemService.held_item_for(charizard.stats) == null, "Pickpocket steals the item of a contact attacker")
	_set_ability(blastoise, "sticky_hold")
	_set_ability(charizard, "magician")
	_execute_until_hit(charizard, blastoise, 1, level)
	_assert_true(PokemonItemService.held_item_for(blastoise.stats) != null and PokemonItemService.held_item_for(charizard.stats) == null, "Sticky Hold keeps the item from Magician")
	_set_ability(blastoise, "torrent")
	blastoise.stats.curr_health = blastoise.stats.max_health
	_execute_until_hit(charizard, blastoise, 1, level)
	_assert_true(PokemonItemService.held_item_for(charizard.stats) != null and PokemonItemService.held_item_for(blastoise.stats) == null, "Magician steals the target's item when hitting empty-handed")
	_set_ability(charizard, "klutz")
	var klutz_damage: int = _hit_damage(level, charizard, blastoise, 0)
	_set_ability(charizard, "blaze")
	var orb_damage: int = _hit_damage(level, charizard, blastoise, 0)
	_assert_true(orb_damage > klutz_damage, "Klutz disables the held Life Orb (%d vs %d)" % [klutz_damage, orb_damage])
	charizard.stats.pokemon_instance.held_item = null
	_set_ability(charizard, "parental_bond")
	blastoise.stats.curr_health = blastoise.stats.max_health
	var start_bond: int = level.battle_log.events.size()
	_execute_until_hit(charizard, blastoise, 0, level)
	var bond_hits: int = 0
	for i in range(start_bond, level.battle_log.events.size()):
		if String(level.battle_log.events[i].get("kind", "")) == "damage_dealt" and String(level.battle_log.events[i].get("move_id", "")) == "slash":
			bond_hits += 1
	_assert_true(bond_hits == 2, "Parental Bond strikes twice (%d)" % bond_hits)
	_set_ability(charizard, "suction_cups")
	_set_moves(blastoise, ["roar", "water_gun", "withdraw", "toxic"])
	var start_roar: int = level.battle_log.events.size()
	resolver.execute(blastoise, charizard, 0, level)
	_assert_true(_has_event_since(level, start_roar, "forced_movement_blocked") and not _has_event_since(level, start_roar, "forced_movement"), "Suction Cups blocks Roar's knockback")
	_set_ability(charizard, "blaze")
	_set_moves(blastoise, ["tackle", "water_gun", "withdraw", "toxic"])
	_assert_true(BattleIntrinsicService.range_bonus_for(_with_ability(charizard, "prankster"), charizard.stats.move_slots[2]) == 2 and BattleIntrinsicService.range_bonus_for(charizard.stats, charizard.stats.move_slots[0]) == 0, "Prankster extends status move range by two")
	_set_ability(charizard, "gale_wings")
	charizard.stats.curr_health = charizard.stats.max_health
	var gust: PokemonMoveResource = load(GENERATED_MOVES_DIR + "gust.tres")
	_assert_true(BattleIntrinsicService.range_bonus_for(charizard.stats, gust) == 1, "Gale Wings extends Flying move range at full HP")
	_set_ability(charizard, "blaze")
	_set_ability(blastoise, "electric_surge")
	level.set_terrain("electric_terrain", 5, "test")
	var slept: Dictionary = ops.apply_status(blastoise, "sleep", {}, {"kind": "status"})
	_assert_true(not bool(slept.get("applied", true)) and String(slept.get("reason", "")) == "electric_terrain", "Electric Terrain keeps grounded units awake")
	_set_moves(charizard, ["thunder_punch", "flamethrower", "growl", "earthquake"])
	charizard.stats.types = ["fire"] as Array[String]
	var shocked: int = _hit_damage(level, charizard, blastoise, 0)
	level.battle_conditions.erase("electric_terrain")
	var plain: int = _hit_damage(level, charizard, blastoise, 0)
	_assert_true(shocked > plain, "Electric Terrain boosts grounded Electric moves (%d vs %d)" % [shocked, plain])
	level.set_terrain("grassy_terrain", 5, "test")
	blastoise.stats.curr_health = 50
	level._on_turn_started(_unit_for(level, blastoise))
	_assert_true(blastoise.stats.curr_health > 50, "Grassy Terrain heals grounded units each turn")
	_set_ability(blastoise, "grass_pelt")
	var pelted: int = _hit_damage(level, charizard, blastoise, 0)
	_set_ability(blastoise, "torrent")
	var unpelted: int = _hit_damage(level, charizard, blastoise, 0)
	_assert_true(pelted < unpelted, "Grass Pelt raises Defense on Grassy Terrain (%d vs %d)" % [pelted, unpelted])
	for i in range(6):
		level._tick_battle_conditions()
	_assert_true(level.current_terrain().is_empty(), "terrain ends after five rounds")
	level.set_battle_condition("desolate_land", {"source_intrinsic": "desolate_land", "unit": charizard.name})
	var start_water: int = level.battle_log.events.size()
	resolver.execute(blastoise, charizard, 1, level)
	_assert_true(_has_event_since(level, start_water, "move_rejected", "", "weather") and level.current_weather() == "desolate_land", "Extremely harsh sunlight evaporates Water attacks")
	level.set_battle_condition("rain", {})
	_assert_true(level.current_weather() == "desolate_land", "ordinary weather cannot replace strong weather")
	level.clear_weather("test")
	level.set_battle_condition("delta_stream", {"source_intrinsic": "delta_stream", "unit": charizard.name})
	charizard.stats.types = ["fire", "flying"] as Array[String]
	var chart: TypeChartResource = level.get_type_chart()
	var rock_slide: PokemonMoveResource = load(GENERATED_MOVES_DIR + "rock_slide.tres")
	resolver._bound_level = level
	_assert_true(is_equal_approx(resolver._status_adjusted_effectiveness(charizard, rock_slide, 4.0, chart), 2.0), "Delta Stream removes the Flying weakness")
	level.clear_weather("test")
	_set_ability(charizard, "imposter")
	blastoise.stats.curr_health = blastoise.stats.max_health
	charizard.stats.curr_health = charizard.stats.max_health
	var start_transform: int = level.battle_log.events.size()
	resolver.intrinsic_service.log_battle_start(level.battle_units, level.battle_log, level)
	_assert_true(charizard.stats.transformed and charizard.stats.types == blastoise.stats.types and charizard.stats.move_slots[0].move_id == blastoise.stats.move_slots[0].move_id, "Imposter transforms into the nearest foe")
	await _teardown(setup)


func _move_checks() -> void:
	var setup: Dictionary = await _level("0006_charizard", ["fling", "teleport", "me_first", "bide"], "0009_blastoise", ["tackle", "water_gun", "withdraw", "toxic"], "held_iron_ball", "")
	var level: TacticsLevel = setup["level"]
	var charizard: TacticsPawn = setup["attacker"]
	var blastoise: TacticsPawn = setup["defender"]
	var ops: BattleStateOps = level._ops()
	var start: int = level.battle_log.events.size()
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(PokemonItemService.held_item_for(charizard.stats) == null and _has_event_since(level, start, "damage_dealt") and _has_event_since(level, start, "item_thrown"), "Fling throws the held item for damage and loses it")
	var key_before: Vector3i = resolver._unit_key(charizard)
	resolver.execute(charizard, charizard, 1, level)
	_assert_true(resolver._unit_key(charizard) != key_before, "Teleport relocates the user")
	_settle_on_tile(charizard, Targeting.arena_tile_keys(level)[key_before])
	blastoise.stats.curr_health = blastoise.stats.max_health
	start = level.battle_log.events.size()
	_execute_until_hit(charizard, blastoise, 2, level)
	_assert_true(_has_event_since(level, start, "move_copied") and blastoise.stats.curr_health < blastoise.stats.max_health, "Me First uses the target's strongest attack first")
	blastoise.stats.curr_health = blastoise.stats.max_health
	charizard.stats.curr_health = charizard.stats.max_health
	resolver.execute(charizard, blastoise, 3, level)
	_assert_true(charizard.stats.battle_statuses.has("bide"), "Bide starts storing damage")
	_execute_until_hit(blastoise, charizard, 0, level)
	var stored: int = int(charizard.stats.battle_statuses.get("bide", {}).get("stored", 0))
	_assert_true(stored > 0, "Bide stores damage taken (%d)" % stored)
	start = level.battle_log.events.size()
	resolver.execute(charizard, blastoise, 0, level)
	_assert_true(_has_event_since(level, start, "move_blocked", "bide"), "a biding user cannot use other moves")
	var hp_before: int = blastoise.stats.curr_health
	resolver.execute(charizard, blastoise, 3, level)
	_assert_true(hp_before - blastoise.stats.curr_health == mini(hp_before, stored * 2) and not charizard.stats.battle_statuses.has("bide"), "Bide returns double the stored damage to the last attacker (%d)" % (hp_before - blastoise.stats.curr_health))
	_set_moves(charizard, ["transform", "baton_pass", "topsy_turvy", "snatch"])
	var before_types: Array[String] = charizard.stats.types.duplicate()
	resolver.execute(charizard, blastoise, 0, level)
	_assert_true(charizard.stats.transformed and charizard.stats.types == blastoise.stats.types and charizard.stats.raw_battle_stat("attack") == blastoise.stats.raw_battle_stat("attack") and charizard.stats.current_pp[0] == 5, "Transform copies types, stats and moves with 5 PP each")
	_set_moves(charizard, ["transform", "baton_pass", "topsy_turvy", "snatch"])
	blastoise.stats.stat_stages = {"attack": 2, "defense": -1}
	resolver.execute(charizard, blastoise, 2, level)
	_assert_true(blastoise.stats.get_stat_stage("attack") == -2 and blastoise.stats.get_stat_stage("defense") == 1, "Topsy-Turvy inverts stat stages")
	blastoise.stats.stat_stages = {}
	charizard.stats.stat_stages = {"speed": 1}
	resolver.execute(charizard, blastoise, 1, level)
	_assert_true(blastoise.stats.get_stat_stage("speed") == 1 and charizard.stats.get_stat_stage("speed") == 0, "Baton Pass hands boosts to any target it reaches, as PMDO allows")
	resolver.execute(charizard, charizard, 3, level)
	_assert_true(charizard.stats.battle_statuses.has("snatch"), "Snatch readies the user")
	_set_moves(blastoise, ["withdraw", "water_gun", "tackle", "toxic"])
	charizard.stats.stat_stages = {}
	start = level.battle_log.events.size()
	resolver.execute(blastoise, blastoise, 0, level)
	_assert_true(_has_event_since(level, start, "move_snatched") and charizard.stats.get_stat_stage("defense") == 1 and blastoise.stats.get_stat_stage("defense") == 0, "Snatch steals the foe's self-targeted Withdraw")
	await _teardown(setup)
	var ally_setup: Dictionary = await _level_with_ally()
	var ally_level: TacticsLevel = ally_setup["level"]
	var passer: TacticsPawn = ally_setup["attacker"]
	var receiver: TacticsPawn = ally_setup["ally"]
	passer.stats.stat_stages = {"attack": 2}
	ally_level._ops().apply_status(passer, "focus_energy", {}, {"kind": "test", "skip_rules": true})
	resolver.execute(passer, receiver, 0, ally_level)
	_assert_true(receiver.stats.get_stat_stage("attack") == 2 and receiver.stats.battle_statuses.has("focus_energy") and passer.stats.get_stat_stage("attack") == 0, "Baton Pass hands stat stages and passable statuses to the chosen ally")
	resolver.execute(passer, passer, 1, ally_level)
	_assert_true(receiver.stats.battle_statuses.has("mat_block") and passer.stats.battle_statuses.has("mat_block"), "Mat Block shields the whole team")
	var foe: TacticsPawn = ally_setup["defender"]
	var start_mat: int = ally_level.battle_log.events.size()
	resolver.execute(foe, receiver, 0, ally_level)
	_assert_true(_has_event_since(ally_level, start_mat, "move_blocked", "mat_block"), "Mat Block stops a damaging move on an ally")
	_set_moves(passer, ["substitute", "follow_me", "fairy_lock", "embargo"])
	passer.stats.curr_health = passer.stats.max_health
	ally_level._ops().remove_status(passer, "mat_block", {"source": "test"})
	ally_level._ops().remove_status(receiver, "mat_block", {"source": "test"})
	foe.serv.movement.look_at_direction_8(foe, passer.global_position - foe.global_position)
	resolver.execute(passer, passer, 0, ally_level)
	var decoy_hp: int = int(passer.stats.battle_statuses.get("decoy", {}).get("hp", 0))
	_assert_true(decoy_hp == int(floor(float(passer.stats.max_health) / 4.0)) and passer.stats.curr_health == passer.stats.max_health - decoy_hp, "Substitute costs a quarter of max HP and stores it as a decoy")
	var shielded_hp: int = passer.stats.curr_health
	var sub_start: int = ally_level.battle_log.events.size()
	_execute_until_hit(foe, passer, 0, ally_level)
	_assert_true(passer.stats.curr_health == shielded_hp and _has_event_since(ally_level, sub_start, "substitute_hit"), "the decoy absorbs a hit instead of the user (%d vs %d)" % [passer.stats.curr_health, shielded_hp])
	_set_moves(foe, ["growl", "water_gun", "withdraw", "toxic"])
	sub_start = ally_level.battle_log.events.size()
	resolver.execute(foe, passer, 0, ally_level)
	_assert_true(passer.stats.get_stat_stage("attack") == 0, "a foe's status move cannot pass the decoy")
	ally_level._ops().remove_status(passer, "decoy", {"source": "test"})
	_set_moves(foe, ["tackle", "water_gun", "withdraw", "toxic"])
	resolver.execute(passer, passer, 1, ally_level)
	var redirect_start: int = ally_level.battle_log.events.size()
	resolver.execute(foe, receiver, 1, ally_level)
	_assert_true(_has_event_since(ally_level, redirect_start, "move_redirected"), "Follow Me draws a foe's attack onto the user")
	resolver.execute(passer, passer, 2, ally_level)
	_assert_true(foe.stats.battle_statuses.has("rooted") and receiver.stats.battle_statuses.has("rooted"), "Fairy Lock roots everyone for a turn")
	ally_level._ops().remove_status(foe, "rooted", {"source": "test"})
	ally_level._ops().remove_status(receiver, "rooted", {"source": "test"})
	ally_level._ops().remove_status(passer, "rooted", {"source": "test"})
	foe.stats.pokemon_instance.held_item = PokemonItemService.load_item("held_life_orb")
	resolver.execute(passer, foe, 3, ally_level)
	_assert_true(foe.stats.battle_statuses.has("embargo") and PokemonItemService.items_disabled(foe.stats), "Embargo switches off the target's held item")
	var weight_move: PokemonMoveResource = load(GENERATED_MOVES_DIR + "low_kick.tres")
	var light: PokemonMoveResource = resolver.move_specials.prepare_weight_move(passer, receiver, weight_move, resolver.intrinsic_service)
	_assert_true(light.has_meta("weight_power") and int(light.get_meta("weight_power")) == BattleMoveSpecials.weight_power(receiver.stats.weight_kg), "Low Kick power follows the target's weight (%d)" % int(light.get_meta("weight_power")))
	_assert_true(BattleMoveSpecials.weight_ratio_power(100.0, 10.0) == 120 and BattleMoveSpecials.weight_ratio_power(30.0, 20.0) == 40, "Heavy Slam power follows the weight ratio")
	await _teardown(ally_setup)


func _hit_damage(level: TacticsLevel, attacker: TacticsPawn, target: TacticsPawn, slot: int) -> int:
	target.stats.curr_health = target.stats.max_health
	var start: int = level.battle_log.events.size()
	_execute_until_hit(attacker, target, slot, level)
	var total: int = 0
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) == "damage_dealt" and String(event.get("source", "")).is_empty() and event.get("defender") == target:
			total += int(event.get("amount", 0))
	return total


func _set_ability(pawn: TacticsPawn, slug: String) -> void:
	pawn.stats.pokemon_instance.ability_override = slug
	pawn.stats.temporary_intrinsic_slugs = [] as Array[String]
	pawn.stats.intrinsic_override_active = false


func _with_ability(pawn: TacticsPawn, slug: String) -> Stats:
	pawn.stats.pokemon_instance.ability_override = slug
	return pawn.stats


func _set_moves(pawn: TacticsPawn, ids: Array) -> void:
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for id in ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(id)]) as PokemonMoveResource
		slots.append(move)
		pp.append(move.pp)
	pawn.stats.move_slots = slots
	pawn.stats.current_pp = pp


func _has_event_since(level: TacticsLevel, start: int, kind: String, status_id: String = "", reason: String = "") -> bool:
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) != kind:
			continue
		if not status_id.is_empty() and String(event.get("status_id", "")) != status_id:
			continue
		if not reason.is_empty() and String(event.get("reason", "")) != reason:
			continue
		return true
	return false


func _execute_until_hit(attacker: TacticsPawn, target: TacticsPawn, slot: int, level: TacticsLevel) -> void:
	for attempt in range(12):
		var start: int = level.battle_log.events.size()
		resolver.execute(attacker, target, slot, level)
		var missed: bool = false
		var blocked: bool = false
		for i in range(start, level.battle_log.events.size()):
			var kind: String = String(level.battle_log.events[i].get("kind", ""))
			if kind == "miss":
				missed = true
			if kind == "move_blocked":
				blocked = true
		if not missed or blocked:
			return


func _level(attacker_slug: String, attacker_moves: Array, defender_slug: String, defender_moves: Array, attacker_item: String, defender_item: String) -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "batch3_%s" % attacker_slug
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	var attacker_instance: PokemonInstanceResource = _instance(attacker_slug, attacker_moves, PokemonInstanceResource.Team.PLAYER)
	var defender_instance: PokemonInstanceResource = _instance(defender_slug, defender_moves, PokemonInstanceResource.Team.ENEMY)
	if not attacker_item.is_empty():
		attacker_instance.held_item = PokemonItemService.load_item(attacker_item)
	if not defender_item.is_empty():
		defender_instance.held_item = PokemonItemService.load_item(defender_item)
	definition.player_team = [attacker_instance]
	definition.enemy_team = [defender_instance]
	return await _finish_level(loader, definition)


func _level_with_ally() -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "batch3_ally"
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	definition.player_team = [_instance("0006_charizard", ["baton_pass", "mat_block", "slash", "growl"], PokemonInstanceResource.Team.PLAYER), _instance("0007_squirtle", ["tackle", "water_gun", "withdraw", "protect"], PokemonInstanceResource.Team.PLAYER)]
	definition.enemy_team = [_instance("0009_blastoise", ["tackle", "water_gun", "withdraw", "toxic"], PokemonInstanceResource.Team.ENEMY)]
	var out: Dictionary = await _finish_level(loader, definition, 2)
	return out


func _finish_level(loader: SkirmishLoader, definition: SkirmishDefinitionResource, player_count: int = 1) -> Dictionary:
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	var player_order: Array = []
	for i in range(player_count):
		player_order.append(i)
	definition.generation_metadata = {"player_spawn_order": player_order, "enemy_spawn_order": [0]}
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	level.battle_rng.seed = 777
	var attacker: TacticsPawn = level.player.get_child(0)
	var defender: TacticsPawn = level.opponent.get_child(0)
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var attacker_key: Vector3i = Targeting._tile_key(attacker.get_tile())
	var out: Dictionary = {"loader": loader, "level": level, "attacker": attacker, "defender": defender}
	for direction in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		if keys.has(attacker_key + direction):
			_settle_on_tile(defender, keys[attacker_key + direction])
			attacker.serv.movement.look_at_direction_8(attacker, Vector3(float(direction.x), 0.0, float(direction.z)))
			defender.serv.movement.look_at_direction_8(defender, Vector3(-float(direction.x), 0.0, -float(direction.z)))
			if player_count > 1:
				var ally: TacticsPawn = level.player.get_child(1)
				var side: Vector3i = Vector3i(direction.z, 0, -direction.x)
				if keys.has(attacker_key + side):
					_settle_on_tile(ally, keys[attacker_key + side])
				out["ally"] = ally
			break
	return out


func _teardown(setup: Dictionary) -> void:
	var loader: SkirmishLoader = setup["loader"]
	loader.unload_current()
	loader.queue_free()
	await process_frame


func _instance(slug: String, move_ids: Array, team: int) -> PokemonInstanceResource:
	var template: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/%s.tres" % slug) as PokemonInstanceResource
	var instance: PokemonInstanceResource = SkirmishMoveLoadout.clone_for_side(template, team, PokemonInstanceResource.ControlType.PLAYER)
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for move_id in move_ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(move_id)]) as PokemonMoveResource
		slots.append(move)
		pp.append(move.pp)
	instance.move_slots = slots
	instance.pp_state = pp
	instance.loadout_locked = true
	return instance


func _unit_for(level: TacticsLevel, pawn: TacticsPawn) -> BattleUnit:
	for unit in level.battle_units:
		if unit.pawn == pawn:
			return unit
	return null


func _settle_on_tile(pawn: TacticsPawn, tile: TacticsTile) -> void:
	var ray: RayCast3D = pawn.get_node("Tile") as RayCast3D
	pawn.global_position = tile.global_position + Vector3.UP * 0.05
	ray.force_raycast_update()
	pawn.center()
	ray.force_raycast_update()


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
