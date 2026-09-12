extends SmokeCase

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var resolver: BattleActionResolver = BattleActionResolver.new()


func _run() -> void:
	_assert_true(PokemonItemService.load_item("held_leftovers") != null and BattleItemCatalog.is_selectable("held_leftovers") and BattleItemCatalog.is_selectable("held_focus_sash"), "custom mainline items load and are selectable")
	var setup: Dictionary = await _level("0006_charizard", ["slash", "flamethrower", "growl", "reflect"], "0009_blastoise", ["tackle", "water_gun", "withdraw", "thunder_punch"], "", "")
	var level: TacticsLevel = setup["level"]
	var charizard: TacticsPawn = setup["attacker"]
	var blastoise: TacticsPawn = setup["defender"]
	var ops: BattleStateOps = level._ops()
	_give(charizard, "held_leftovers")
	charizard.stats.curr_health = 50
	level._on_turn_started(_unit_for(level, charizard))
	_assert_true(charizard.stats.curr_health == 50 + maxi(1, int(floor(float(charizard.stats.max_health) / 16.0))), "Leftovers heals 1/16 each turn (%d)" % charizard.stats.curr_health)
	_give(charizard, "held_black_sludge")
	charizard.stats.curr_health = 50
	level._on_turn_started(_unit_for(level, charizard))
	_assert_true(charizard.stats.curr_health == 50 - maxi(1, int(floor(float(charizard.stats.max_health) / 8.0))), "Black Sludge hurts a non-Poison holder (%d)" % charizard.stats.curr_health)
	_give(blastoise, "held_focus_sash")
	blastoise.stats.curr_health = blastoise.stats.max_health
	ops.damage(blastoise, 9999, {"kind": "hit", "attacker": charizard})
	_assert_true(blastoise.stats.curr_health == 1 and PokemonItemService.held_item_for(blastoise.stats) == null, "Focus Sash leaves the holder at 1 HP from full")
	blastoise.stats.curr_health = blastoise.stats.max_health
	_give(blastoise, "held_rocky_helmet")
	var before: int = charizard.stats.curr_health
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(before - charizard.stats.curr_health >= maxi(1, int(floor(float(charizard.stats.max_health) / 6.0))), "Rocky Helmet hurts a contact attacker")
	_give(charizard, "held_protective_pads")
	before = charizard.stats.curr_health
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(before - charizard.stats.curr_health == 0, "Protective Pads block Rocky Helmet")
	_give(charizard, "")
	_give(blastoise, "")
	blastoise.stats.curr_health = blastoise.stats.max_health
	_give(blastoise, "held_eviolite")
	var special_move: PokemonMoveResource = charizard.stats.move_slots[1]
	var squirtle_stats := Stats.new()
	squirtle_stats.init_from_pokemon(_instance("0007_squirtle", ["tackle"], PokemonInstanceResource.Team.ENEMY))
	squirtle_stats.pokemon_instance.held_item = PokemonItemService.load_item("held_eviolite")
	_assert_true(is_equal_approx(PokemonItemService.held_defense_multiplier(blastoise.stats, special_move, null, blastoise, 1.0), 1.0) and is_equal_approx(PokemonItemService.held_defense_multiplier(squirtle_stats, special_move, null, null, 1.0), 2.0 / 3.0), "Eviolite only helps a holder that can still evolve")
	squirtle_stats.free()
	_give(blastoise, "held_weakness_policy")
	blastoise.stats.stat_stages = {}
	_set_moves(charizard, ["thunder_punch", "flamethrower", "growl", "reflect"])
	charizard.stats.types = ["fire"] as Array[String]
	blastoise.stats.curr_health = blastoise.stats.max_health
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(blastoise.stats.get_stat_stage("attack") == 2 and blastoise.stats.get_stat_stage("special_attack") == 2 and PokemonItemService.held_item_for(blastoise.stats) == null, "Weakness Policy fires on a super-effective hit")
	blastoise.stats.stat_stages = {}
	_give(blastoise, "held_cell_battery")
	blastoise.stats.curr_health = blastoise.stats.max_health
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(blastoise.stats.get_stat_stage("attack") == 1 and PokemonItemService.held_item_for(blastoise.stats) == null, "Cell Battery raises Attack when hit by Electric")
	blastoise.stats.stat_stages = {}
	_give(blastoise, "held_air_balloon")
	_assert_true(not level.is_grounded(blastoise), "Air Balloon lifts the holder")
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(level.is_grounded(blastoise) and PokemonItemService.held_item_for(blastoise.stats) == null, "Air Balloon pops when hit")
	_give(blastoise, "held_heavy_duty_boots")
	level.hazards().tiles[Targeting._tile_key(blastoise.get_tile())] = {"spikes": {"layers": 3, "source": charizard}}
	blastoise.stats.curr_health = blastoise.stats.max_health
	level.on_pawn_reached_tile(blastoise, blastoise.global_position)
	_assert_true(blastoise.stats.curr_health == blastoise.stats.max_health, "Heavy-Duty Boots ignore hazards")
	level.hazards().tiles.clear()
	_give(charizard, "held_light_clay")
	_set_moves(charizard, ["reflect", "flamethrower", "growl", "slash"])
	resolver.execute(charizard, charizard, 0, level)
	_assert_true(int(charizard.stats.battle_statuses.get("reflect", {}).get("counter", 0)) == 8, "Light Clay makes Reflect last 8 rounds")
	_give(charizard, "held_muscle_band")
	_set_moves(charizard, ["slash", "flamethrower", "growl", "thunder_punch"])
	charizard.stats.stat_stages = {}
	blastoise.stats.stat_stages = {}
	var band: int = _hit_damage(level, charizard, blastoise, 0)
	_give(charizard, "")
	var bare: int = _hit_damage(level, charizard, blastoise, 0)
	_assert_true(band > bare, "Muscle Band boosts physical moves (%d vs %d)" % [band, bare])
	_give(charizard, "held_wise_glasses")
	var glasses: int = _hit_damage(level, charizard, blastoise, 1)
	_give(charizard, "")
	var bare_special: int = _hit_damage(level, charizard, blastoise, 1)
	_assert_true(glasses > bare_special, "Wise Glasses boost special moves (%d vs %d)" % [glasses, bare_special])
	_give(charizard, "held_kings_rock")
	var flinched: bool = false
	for attempt in range(60):
		blastoise.stats.curr_health = blastoise.stats.max_health
		_execute_until_hit(charizard, blastoise, 0, level)
		if blastoise.stats.battle_statuses.has("flinch"):
			flinched = true
			break
	_assert_true(flinched, "King's Rock can make the target flinch")
	ops.remove_status(blastoise, "flinch", {"source": "test"})
	_give(blastoise, "held_covert_cloak")
	_assert_true(PokemonItemService.blocks_additional_effects(blastoise.stats), "Covert Cloak shields from secondary effects")
	_give(blastoise, "held_clear_amulet")
	blastoise.stats.stat_stages = {}
	var start: int = level.battle_log.events.size()
	resolver.execute(charizard, blastoise, 2, level)
	_assert_true(blastoise.stats.get_stat_stage("attack") == 0 and _has_event_since(level, start, "stat_stage_blocked"), "Clear Amulet blocks Growl")
	_give(blastoise, "held_mirror_herb")
	_set_moves(charizard, ["swords_dance", "flamethrower", "growl", "slash"])
	charizard.stats.stat_stages = {}
	blastoise.stats.stat_stages = {}
	resolver.execute(charizard, charizard, 0, level)
	_assert_true(blastoise.stats.get_stat_stage("attack") == 2 and PokemonItemService.held_item_for(blastoise.stats) == null, "Mirror Herb copies the foe's Swords Dance")
	_give(charizard, "held_white_herb")
	charizard.stats.stat_stages = {"attack": -2}
	level._on_turn_started(_unit_for(level, charizard))
	_assert_true(charizard.stats.get_stat_stage("attack") == 0 and PokemonItemService.held_item_for(charizard.stats) == null, "White Herb restores lowered stats")
	_give(charizard, "held_mental_herb")
	ops.apply_status(charizard, "taunted", {}, {"kind": "test", "skip_rules": true})
	level._on_turn_started(_unit_for(level, charizard))
	_assert_true(not charizard.stats.battle_statuses.has("taunted") and PokemonItemService.held_item_for(charizard.stats) == null, "Mental Herb cures Taunt")
	_give(charizard, "held_blunder_policy")
	charizard.stats.stat_stages = {}
	ops.apply_status(blastoise, "airborne", {}, {"kind": "test", "skip_rules": true})
	resolver.execute(charizard, blastoise, 3, level)
	ops.remove_status(blastoise, "airborne", {"source": "test"})
	_assert_true(charizard.stats.get_stat_stage("speed") == 2 and PokemonItemService.held_item_for(charizard.stats) == null, "Blunder Policy fires when a move misses")
	_give(charizard, "held_throat_spray")
	charizard.stats.stat_stages = {}
	resolver.execute(charizard, blastoise, 2, level)
	_assert_true(charizard.stats.get_stat_stage("special_attack") == 1 and PokemonItemService.held_item_for(charizard.stats) == null, "Throat Spray fires after a sound move")
	_give(charizard, "held_red_card")
	_give(blastoise, "")
	var blastoise_key: Vector3i = resolver._unit_key(blastoise)
	charizard.stats.curr_health = charizard.stats.max_health
	_execute_until_hit(blastoise, charizard, 0, level)
	_assert_true(resolver._unit_key(blastoise) != blastoise_key and PokemonItemService.held_item_for(charizard.stats) == null, "Red Card knocks the attacker back")
	_give(charizard, "held_heat_rock")
	_set_moves(charizard, ["sunny_day", "flamethrower", "growl", "slash"])
	resolver.execute(charizard, charizard, 0, level)
	_assert_true(int(level.battle_condition("sunny").get("rounds_left", 0)) == 8, "Heat Rock makes sunlight last 8 rounds (%d)" % int(level.battle_condition("sunny").get("rounds_left", 0)))
	level.clear_weather("test")
	_give(charizard, "held_utility_umbrella")
	level.set_battle_condition("hail", {})
	charizard.stats.curr_health = charizard.stats.max_health
	level._on_turn_started(_unit_for(level, charizard))
	_assert_true(charizard.stats.curr_health == charizard.stats.max_health, "Utility Umbrella shields from hail chip")
	level.clear_weather("test")
	_give(charizard, "held_safety_goggles")
	_set_moves(blastoise, ["poison_powder", "water_gun", "withdraw", "thunder_punch"])
	var blocked: Dictionary = ops.apply_status(charizard, "poison", {}, {"kind": "status", "attacker": blastoise, "move": blastoise.stats.move_slots[0]})
	_assert_true(not bool(blocked.get("applied", true)) and String(blocked.get("reason", "")) == "safety_goggles", "Safety Goggles block powder moves")
	_give(charizard, "held_lagging_tail")
	PokemonItemService.apply_held_effects_to_stats(charizard.stats, level.battle_log)
	_assert_true(is_equal_approx(charizard.stats.battle_speed_multiplier, 0.1), "Lagging Tail makes the holder act last")
	_give(charizard, "held_light_ball")
	_assert_true(is_equal_approx(PokemonItemService.held_damage_multiplier(charizard.stats, charizard.stats.move_slots[1], null, charizard, 1.0), 1.0), "Light Ball does nothing for Charizard")
	_give(charizard, "held_destiny_knot")
	ops.apply_status(charizard, "in_love", {}, {"kind": "status", "attacker": blastoise})
	_assert_true(blastoise.stats.battle_statuses.has("in_love"), "Destiny Knot shares infatuation")
	ops.remove_status(charizard, "in_love", {"source": "test"})
	ops.remove_status(blastoise, "in_love", {"source": "test"})
	_give(charizard, "held_loaded_dice")
	var fury: PokemonMoveResource = load(GENERATED_MOVES_DIR + "fury_attack.tres")
	var low_rolls: int = 0
	for i in range(60):
		if resolver.move_specials.hit_count(resolver.intrinsic_service, charizard, fury, level.battle_rng) < 4:
			low_rolls += 1
	_assert_true(low_rolls == 0, "Loaded Dice keeps multi-hit moves at four or five strikes")
	_give(charizard, "held_power_herb")
	_set_moves(charizard, ["solar_beam", "flamethrower", "growl", "slash"])
	level.clear_weather("test")
	blastoise.stats.curr_health = blastoise.stats.max_health
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(not charizard.stats.battle_statuses.has("charging") and PokemonItemService.held_item_for(charizard.stats) == null and blastoise.stats.curr_health < blastoise.stats.max_health, "Power Herb fires Solar Beam at once and is used up")
	_give(charizard, "held_terrain_extender")
	_set_moves(charizard, ["grassy_terrain", "flamethrower", "growl", "slash"])
	resolver.execute(charizard, charizard, 0, level)
	_assert_true(int(level.battle_condition("grassy_terrain").get("counter", 0)) == 8, "Terrain Extender makes terrain last eight rounds")
	level.battle_conditions.erase("grassy_terrain")
	_give(charizard, "held_thick_club")
	var slash_move: PokemonMoveResource = load(GENERATED_MOVES_DIR + "slash.tres")
	_assert_true(is_equal_approx(PokemonItemService.held_damage_multiplier(charizard.stats, slash_move, null, charizard, 1.0), 1.0), "Thick Club does nothing for Charizard")
	var marowak := Stats.new()
	marowak.init_from_pokemon(_instance("0105_marowak", ["bone_club"], PokemonInstanceResource.Team.ENEMY))
	marowak.pokemon_instance.held_item = PokemonItemService.load_item("held_thick_club")
	_assert_true(is_equal_approx(PokemonItemService.held_damage_multiplier(marowak, slash_move, null, null, 1.0), 2.0), "Thick Club doubles Marowak's attacks")
	marowak.free()
	_give(charizard, "held_float_stone")
	_assert_true(is_equal_approx(resolver.move_specials.weight_of(charizard.stats, resolver.intrinsic_service), charizard.stats.weight_kg * 0.5), "Float Stone halves the holder's weight")
	_give(blastoise, "held_adrenaline_orb")
	blastoise.stats.stat_stages = {}
	ops.change_stat_stage(blastoise, "attack", -1, {"kind": "intrinsic", "attacker": charizard, "intrinsic_id": "intimidate"})
	_assert_true(blastoise.stats.get_stat_stage("speed") == 1 and PokemonItemService.held_item_for(blastoise.stats) == null, "Adrenaline Orb answers Intimidate with Speed")
	_give(blastoise, "held_bright_powder")
	_assert_true(is_equal_approx(PokemonItemService.target_accuracy_multiplier(blastoise.stats), 0.9), "Bright Powder lowers accuracy against the holder")
	_give(charizard, "held_punching_glove")
	var punch: PokemonMoveResource = load(GENERATED_MOVES_DIR + "thunder_punch.tres")
	_assert_true(is_equal_approx(PokemonItemService.held_damage_multiplier(charizard.stats, punch, null, charizard, 1.0), 1.1) and PokemonItemService.contact_shielded(charizard.stats, punch), "Punching Glove boosts punches and removes their contact")
	_give(blastoise, "held_snowball")
	blastoise.stats.stat_stages = {}
	blastoise.stats.curr_health = blastoise.stats.max_health
	_set_moves(charizard, ["ice_punch", "flamethrower", "growl", "slash"])
	_execute_until_hit(charizard, blastoise, 0, level)
	_assert_true(blastoise.stats.get_stat_stage("attack") == 1 and PokemonItemService.held_item_for(blastoise.stats) == null, "Snowball raises Attack when hit by Ice")
	_give(blastoise, "berry_kee")
	blastoise.stats.stat_stages = {}
	blastoise.stats.curr_health = blastoise.stats.max_health
	_execute_until_hit(charizard, blastoise, 3, level)
	_assert_true(blastoise.stats.get_stat_stage("defense") == 1 and PokemonItemService.held_item_for(blastoise.stats) == null, "Kee Berry raises Defense when hit by a physical move")
	_give(blastoise, "berry_maranga")
	blastoise.stats.stat_stages = {}
	blastoise.stats.curr_health = blastoise.stats.max_health
	_execute_until_hit(charizard, blastoise, 1, level)
	_assert_true(blastoise.stats.get_stat_stage("special_defense") == 1 and PokemonItemService.held_item_for(blastoise.stats) == null, "Maranga Berry raises Special Defense when hit by a special move")
	_give(blastoise, "held_focus_band")
	blastoise.stats.curr_health = blastoise.stats.max_health
	var survived: int = 0
	var fainted: int = 0
	for seed in range(1, 61):
		level.battle_rng.seed = seed
		var probe: RandomNumberGenerator = RandomNumberGenerator.new()
		probe.seed = seed
		var expected: bool = probe.randi_range(1, 100) <= 10
		var kept: int = PokemonItemService.survive_hit(blastoise, blastoise.stats.max_health * 2, level.battle_log)
		if kept == blastoise.stats.curr_health - 1:
			survived += 1
		elif kept == blastoise.stats.max_health * 2:
			fainted += 1
		_assert_true((kept == blastoise.stats.curr_health - 1) == expected, "Focus Band follows the battle roll for seed %d" % seed)
	_assert_true(survived > 0 and fainted > 0 and PokemonItemService.held_item_for(blastoise.stats) != null, "Focus Band sometimes leaves 1 HP and is kept")
	_assert_true(not BattleItemCatalog.is_selectable("berry_hondew") and not BattleItemCatalog.is_selectable("berry_tamato") and BattleItemCatalog.is_selectable("berry_kee") and BattleItemCatalog.is_selectable("berry_cheri") and BattleItemCatalog.is_selectable("berry_custap"), "implemented berries are offered and inert ones are not")
	_give(blastoise, "berry_custap")
	blastoise.stats.curr_health = blastoise.stats.max_health
	blastoise.stats.battle_speed_multiplier = 1.0
	PokemonItemService.apply_speed_multipliers(level.battle_units, level.battle_log)
	_assert_true(is_equal_approx(blastoise.stats.battle_speed_multiplier, 1.0) and PokemonItemService.held_item_for(blastoise.stats) != null, "Custap Berry waits above the pinch threshold")
	blastoise.stats.curr_health = int(floor(float(blastoise.stats.max_health) * 0.25))
	PokemonItemService.apply_speed_multipliers(level.battle_units, level.battle_log)
	_assert_true(blastoise.stats.battle_speed_multiplier > 50.0 and PokemonItemService.held_item_for(blastoise.stats) == null, "Custap Berry puts the holder first in the next round and is eaten")
	_give(charizard, "held_iron_ball")
	charizard.stats.battle_speed_multiplier = 1.0
	PokemonItemService.apply_speed_multipliers(level.battle_units, level.battle_log)
	_assert_true(is_equal_approx(charizard.stats.battle_speed_multiplier, 0.5), "Iron Ball halves speed through the round refresh")
	await _teardown(setup)
	_finish("custom_items")


func _give(pawn: TacticsPawn, item_id: String) -> void:
	pawn.stats.pokemon_instance.held_item = PokemonItemService.load_item(item_id) if not item_id.is_empty() else null


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


func _set_moves(pawn: TacticsPawn, ids: Array) -> void:
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for id in ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(id)]) as PokemonMoveResource
		slots.append(move)
		pp.append(move.pp)
	pawn.stats.move_slots = slots
	pawn.stats.current_pp = pp


func _has_event_since(level: TacticsLevel, start: int, kind: String) -> bool:
	for i in range(start, level.battle_log.events.size()):
		if String(level.battle_log.events[i].get("kind", "")) == kind:
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
	definition.skirmish_id = "custom_items"
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
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
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
	for direction in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		if keys.has(attacker_key + direction) and keys.has(attacker_key + direction * 3):
			_settle_on_tile(defender, keys[attacker_key + direction])
			attacker.serv.movement.look_at_direction_8(attacker, Vector3(float(direction.x), 0.0, float(direction.z)))
			defender.serv.movement.look_at_direction_8(defender, Vector3(-float(direction.x), 0.0, -float(direction.z)))
			break
	return {"loader": loader, "level": level, "attacker": attacker, "defender": defender}


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
