extends SmokeCase

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var resolver := BattleActionResolver.new()


func _run() -> void:
	var plain: int = await _damage("0007_squirtle", "tackle", "0094_gengar", "", "")
	var fairy: int = await _damage("0007_squirtle", "tackle", "0094_gengar", "pixilate", "")
	_assert_true(plain == 0 and fairy > 0, "Pixilate turns Tackle into a Fairy move that hits Gengar (%d)" % fairy)
	var base: int = await _damage("0007_squirtle", "tackle", "0004_charmander", "", "")
	var coat: int = await _damage("0007_squirtle", "tackle", "0004_charmander", "", "fur_coat")
	_assert_true(coat >= int(base * 0.5) - 2 and coat <= int(base * 0.5) + 2, "Fur Coat halves physical damage (%d -> %d)" % [base, coat])
	var guard_neutral: int = await _damage("0007_squirtle", "tackle", "0004_charmander", "", "wonder_guard")
	var guard_super: int = await _damage("0007_squirtle", "water_gun", "0004_charmander", "", "wonder_guard")
	_assert_true(guard_neutral == 0 and guard_super > 0, "Wonder Guard only lets super-effective hits through (%d/%d)" % [guard_neutral, guard_super])
	var bite: int = await _damage("0007_squirtle", "bite", "0004_charmander", "", "")
	var aura: int = await _damage("0007_squirtle", "bite", "0004_charmander", "dark_aura", "")
	_assert_true(aura > bite and aura <= int(bite * 4.0 / 3.0) + 2, "Dark Aura boosts Dark moves by a third (%d -> %d)" % [bite, aura])
	var gas_base: int = await _damage("0007_squirtle", "tackle", "0004_charmander", "huge_power", "")
	var gassed: int = await _damage("0007_squirtle", "tackle", "0004_charmander", "huge_power", "neutralizing_gas")
	_assert_true(gassed < gas_base and gassed >= base - 2 and gassed <= base + 2, "Neutralizing Gas cancels the foe's Huge Power (%d -> %d)" % [gas_base, gassed])
	var slow: int = await _damage("0007_squirtle", "tackle", "0004_charmander", "slow_start", "")
	_assert_true(slow >= int(base * 0.5) - 2 and slow <= int(base * 0.5) + 2, "Slow Start halves physical damage at the start (%d -> %d)" % [base, slow])
	var setup: Dictionary = await _level("0001_bulbasaur", ["mega_drain"], "0007_squirtle", "", "liquid_ooze")
	var bulbasaur: TacticsPawn = setup["attacker"]
	bulbasaur.stats.curr_health = 50
	_execute_until_hit(setup, 0)
	_assert_true(bulbasaur.stats.curr_health < 50, "Liquid Ooze turns drained HP into damage (%d)" % bulbasaur.stats.curr_health)
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "download", "")
	var squirtle: TacticsPawn = setup["attacker"]
	_assert_true(squirtle.stats.get_stat_stage("attack") + squirtle.stats.get_stat_stage("special_attack") == 1, "Download raises one attacking stat at battle start")
	await _teardown(setup)
	setup = await _level("0004_charmander", ["ember"], "0007_squirtle", "", "color_change")
	_execute_until_hit(setup, 0)
	_assert_true((setup["defender"] as TacticsPawn).stats.types == ["fire"], "Color Change adopts the attacking type (%s)" % str((setup["defender"] as TacticsPawn).stats.types))
	await _teardown(setup)
	setup = await _level("0004_charmander", ["water_gun"], "0007_squirtle", "protean", "")
	_execute(setup, 0)
	_assert_true((setup["attacker"] as TacticsPawn).stats.types == ["water"], "Protean changes the user to the move's type (%s)" % str((setup["attacker"] as TacticsPawn).stats.types))
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "moody", "")
	var level: TacticsLevel = setup["level"]
	squirtle = setup["attacker"]
	level._on_turn_started(_unit_for(level, squirtle))
	var total: int = 0
	var raised: int = 0
	for stat_id in ["attack", "defense", "special_attack", "special_defense", "speed"]:
		var stage: int = squirtle.stats.get_stat_stage(stat_id)
		total += stage
		if stage == 2:
			raised += 1
	_assert_true(total == 1 and raised == 1, "Moody raises one stat by two and lowers another by one")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "bad_dreams", "")
	level = setup["level"]
	var charmander: TacticsPawn = setup["defender"]
	charmander.stats.apply_battle_status("sleep")
	var hp: int = charmander.stats.curr_health
	level._on_turn_started(_unit_for(level, setup["attacker"]))
	_assert_true(hp - charmander.stats.curr_health == maxi(1, int(floor(float(charmander.stats.max_health) / 8.0))), "Bad Dreams hurts a sleeping foe by 1/8 each turn")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "", "berserk")
	charmander = setup["defender"]
	charmander.stats.curr_health = int(floor(float(charmander.stats.max_health) / 2.0)) + 3
	_execute_until_hit(setup, 0)
	_assert_true(charmander.stats.get_stat_stage("special_attack") == 1, "Berserk raises Sp. Atk when a hit drops the holder below half")
	await _teardown(setup)
	setup = await _level("0001_bulbasaur", ["poison_powder"], "0007_squirtle", "", "pastel_veil")
	_execute_until_hit(setup, 0)
	_assert_true(not (setup["defender"] as TacticsPawn).stats.battle_statuses.has("poison"), "Pastel Veil blocks poison")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "cheek_pouch", "", "berry_sitrus")
	squirtle = setup["attacker"]
	squirtle.stats.curr_health = 10
	PokemonItemService.try_trigger_held_threshold(squirtle, (setup["level"] as TacticsLevel).battle_log)
	var expected_pouch: int = 10 + maxi(1, int(floor(float(squirtle.stats.max_health) / 4.0))) + maxi(1, int(floor(float(squirtle.stats.max_health) / 3.0)))
	_assert_true(squirtle.stats.curr_health == expected_pouch, "Cheek Pouch adds a third of max HP when a berry is eaten (%d vs %d)" % [squirtle.stats.curr_health, expected_pouch])
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "harvest", "", "berry_sitrus")
	level = setup["level"]
	squirtle = setup["attacker"]
	level.set_battle_condition("sunny", {})
	squirtle.stats.curr_health = 10
	PokemonItemService.try_trigger_held_threshold(squirtle, level.battle_log)
	_assert_true(PokemonItemService.held_item_for(squirtle) == null, "berry consumed before Harvest")
	level._on_turn_started(_unit_for(level, squirtle))
	_assert_true(PokemonItemService.held_item_for(squirtle) != null and PokemonItemService.held_item_for(squirtle).item_id == "berry_sitrus", "Harvest restores the eaten berry in sun")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "victory_star", "")
	level = setup["level"]
	_assert_true(is_equal_approx(level.intrinsic_service.accuracy_multiplier(setup["attacker"], setup["defender"], (setup["attacker"] as TacticsPawn).stats.move_slots[0], level), 1.1), "Victory Star raises accuracy by a tenth")
	await _teardown(setup)
	_finish("abilities_batch2")


func _damage(attacker_slug: String, move_id: String, defender_slug: String, attacker_ability: String, defender_ability: String) -> int:
	var setup: Dictionary = await _level(attacker_slug, [move_id], defender_slug, attacker_ability, defender_ability)
	var defender: TacticsPawn = setup["defender"]
	var before: int = defender.stats.curr_health
	_execute_until_hit(setup, 0)
	var dealt: int = before - defender.stats.curr_health
	await _teardown(setup)
	return dealt


func _execute(setup: Dictionary, slot: int) -> void:
	resolver.execute(setup["attacker"], setup["defender"], slot, setup["level"])


func _execute_until_hit(setup: Dictionary, slot: int) -> void:
	var level: TacticsLevel = setup["level"]
	for attempt in range(12):
		var start: int = level.battle_log.events.size()
		resolver.execute(setup["attacker"], setup["defender"], slot, level)
		var missed: bool = false
		for i in range(start, level.battle_log.events.size()):
			if String(level.battle_log.events[i].get("kind", "")) == "miss":
				missed = true
		if not missed:
			return


func _level(attacker_slug: String, move_ids: Array, defender_slug: String, attacker_ability: String, defender_ability: String, attacker_item: String = "") -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "ability2_%s" % attacker_slug
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	var attacker_instance: PokemonInstanceResource = _instance(attacker_slug, move_ids, PokemonInstanceResource.Team.PLAYER, attacker_ability)
	if not attacker_item.is_empty():
		attacker_instance.held_item = PokemonItemService.load_item(attacker_item)
	definition.player_team = [attacker_instance]
	definition.enemy_team = [_instance(defender_slug, ["tackle"], PokemonInstanceResource.Team.ENEMY, defender_ability)]
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var attacker: TacticsPawn = level.player.get_child(0)
	var defender: TacticsPawn = level.opponent.get_child(0)
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var attacker_key: Vector3i = Targeting._tile_key(attacker.get_tile())
	for direction in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		if keys.has(attacker_key + direction):
			_settle_on_tile(defender, keys[attacker_key + direction])
			attacker.serv.movement.look_at_direction_8(attacker, Vector3(float(direction.x), 0.0, float(direction.z)))
			break
	return {"loader": loader, "level": level, "attacker": attacker, "defender": defender}


func _teardown(setup: Dictionary) -> void:
	var loader: SkirmishLoader = setup["loader"]
	loader.unload_current()
	loader.queue_free()
	await process_frame


func _instance(slug: String, move_ids: Array, team: int, ability: String) -> PokemonInstanceResource:
	var template: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/%s.tres" % slug) as PokemonInstanceResource
	var instance: PokemonInstanceResource = SkirmishMoveLoadout.clone_for_side(template, team, PokemonInstanceResource.ControlType.PLAYER)
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for move_id in move_ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(move_id)]) as PokemonMoveResource
		slots.append(move)
		pp.append(move.pp)
	while slots.size() < PokemonInstanceResource.MAX_MOVE_SLOTS:
		slots.append(slots[0])
		pp.append(slots[0].pp)
	instance.move_slots = slots
	instance.pp_state = pp
	instance.loadout_locked = true
	instance.ability_override = ability
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
