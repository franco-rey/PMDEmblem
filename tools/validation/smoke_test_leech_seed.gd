extends SmokeCase

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"


func _run() -> void:
	var setup: Dictionary = await _level("0001_bulbasaur", ["leech_seed", "sleep_powder"], "0007_squirtle")
	var level: TacticsLevel = setup["level"]
	var bulbasaur: TacticsPawn = setup["attacker"]
	var squirtle: TacticsPawn = setup["defender"]
	var resolver := BattleActionResolver.new()
	_assert_true(resolver.execute(bulbasaur, squirtle, 0, level), "Leech Seed executes")
	_assert_true(squirtle.stats.battle_statuses.has("leech_seed"), "Squirtle is seeded")
	_assert_true(level.message_log.history.has("Squirtle was seeded!"), "seed message shown (%s)" % str(level.message_log.recent(3)))
	bulbasaur.stats.curr_health = 10
	var hp_before: int = squirtle.stats.curr_health
	level._on_turn_started(_unit_for(level, squirtle))
	var expected: int = maxi(1, int(floor(float(squirtle.stats.max_health) / 8.0)))
	_assert_true(hp_before - squirtle.stats.curr_health == expected, "seeded unit loses 1/8 max HP per turn (%d vs %d)" % [hp_before - squirtle.stats.curr_health, expected])
	_assert_true(bulbasaur.stats.curr_health == 10 + expected, "the seeder regains the drained HP (%d)" % bulbasaur.stats.curr_health)
	_assert_true(level.message_log.history.has("Squirtle's health is sapped by Leech Seed!"), "drain message shown")
	var start: int = _execute_until_hit(resolver, bulbasaur, squirtle, 0, level)
	_assert_true(_has_blocked(level, start, "leech_seed", "already_applied") and level.message_log.history.has("Squirtle is already affected by Leech Seed!"), "seeding an already seeded unit fails")
	await _teardown(setup)
	var grass: Dictionary = await _level("0001_bulbasaur", ["leech_seed", "sleep_powder"], "0002_ivysaur")
	var grass_level: TacticsLevel = grass["level"]
	var seed_start: int = _execute_until_hit(resolver, grass["attacker"], grass["defender"], 0, grass_level)
	_assert_true(not (grass["defender"] as TacticsPawn).stats.battle_statuses.has("leech_seed") and _has_blocked(grass_level, seed_start, "leech_seed", "type_immunity"), "Grass types are immune to Leech Seed")
	var powder_start: int = _execute_until_hit(resolver, grass["attacker"], grass["defender"], 1, grass_level)
	_assert_true(not (grass["defender"] as TacticsPawn).stats.battle_statuses.has("sleep") and _has_blocked(grass_level, powder_start, "sleep", "powder_immunity"), "Grass types are immune to Sleep Powder")
	_assert_true(grass_level.message_log.history.has("It doesn't affect Ivysaur..."), "immunity message shown (%s)" % str(grass_level.message_log.recent(2)))
	await _teardown(grass)
	_finish("leech_seed")


func _execute_until_hit(resolver: BattleActionResolver, attacker: TacticsPawn, target: TacticsPawn, slot: int, level: TacticsLevel) -> int:
	for attempt in range(12):
		var start: int = level.battle_log.events.size()
		resolver.execute(attacker, target, slot, level)
		var missed: bool = false
		for i in range(start, level.battle_log.events.size()):
			if String(level.battle_log.events[i].get("kind", "")) == "miss":
				missed = true
		if not missed:
			return start
	return level.battle_log.events.size()


func _has_blocked(level: TacticsLevel, start: int, status_id: String, reason: String) -> bool:
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) == "status_blocked" and String(event.get("status_id", "")) == status_id and String(event.get("reason", "")) == reason:
			return true
	return false


func _level(attacker_slug: String, move_ids: Array, defender_slug: String) -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "seed_%s_%s" % [attacker_slug, defender_slug]
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	definition.player_team = [_instance(attacker_slug, move_ids, PokemonInstanceResource.Team.PLAYER)]
	definition.enemy_team = [_instance(defender_slug, ["tackle"], PokemonInstanceResource.Team.ENEMY)]
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	await process_frame
	await process_frame
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


func _instance(slug: String, move_ids: Array, team: int) -> PokemonInstanceResource:
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
