extends SmokeCase

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"


func _run() -> void:
	var setup: Dictionary = await _level("0023_ekans", ["wrap", "bind"], "0007_squirtle", "")
	var level: TacticsLevel = setup["level"]
	var ekans: TacticsPawn = setup["attacker"]
	var squirtle: TacticsPawn = setup["defender"]
	var resolver := BattleActionResolver.new()
	_execute_until_hit(resolver, ekans, squirtle, 0, level)
	_assert_true(squirtle.stats.battle_statuses.has("wrap"), "Wrap applies the wrap status after damage")
	var payload: Dictionary = squirtle.stats.battle_statuses.get("wrap", {})
	_assert_true([4, 5].has(int(payload.get("counter", 0))) and int(payload.get("hp_fraction", 0)) == 8, "wrap lasts 4 or 5 turns at 1/8 per turn (%s)" % str(payload))
	_assert_true(level.message_log.history.has("Squirtle was wrapped!"), "wrap message shown")
	var unit: BattleUnit = _unit_for(level, squirtle)
	var hp_before: int = squirtle.stats.curr_health
	level._on_turn_started(unit)
	_assert_true(hp_before - squirtle.stats.curr_health == maxi(1, int(floor(float(squirtle.stats.max_health) / 8.0))), "trapped unit loses 1/8 max HP at its turn (%d)" % (hp_before - squirtle.stats.curr_health))
	_assert_true(not squirtle.res.can_move and squirtle.res.can_attack, "trapped unit cannot move but can still attack")
	_assert_true(level.message_log.history.has("Squirtle is hurt by Wrap!"), "trap tick message shown")
	var turns: int = 0
	while squirtle.stats.battle_statuses.has("wrap") and turns < 8:
		level._on_turn_started(unit)
		turns += 1
	_assert_true(not squirtle.stats.battle_statuses.has("wrap") and turns >= 3 and turns <= 5, "wrap expires after its counter (%d more turns)" % turns)
	level._on_turn_started(unit)
	_assert_true(squirtle.res.can_move and level.message_log.history.has("Squirtle was freed from Wrap!"), "movement returns and the freed message shows")
	await _teardown(setup)
	var banded: Dictionary = await _level("0023_ekans", ["wrap"], "0007_squirtle", "held_binding_band")
	var band_level: TacticsLevel = banded["level"]
	_execute_until_hit(resolver, banded["attacker"], banded["defender"], 0, band_level)
	var band_payload: Dictionary = (banded["defender"] as TacticsPawn).stats.battle_statuses.get("wrap", {})
	_assert_true(int(band_payload.get("hp_fraction", 0)) == 6, "Binding Band raises trap damage to 1/6 (%s)" % str(band_payload))
	await _teardown(banded)
	var clawed: Dictionary = await _level("0023_ekans", ["wrap"], "0007_squirtle", "held_grip_claw")
	var claw_level: TacticsLevel = clawed["level"]
	_execute_until_hit(resolver, clawed["attacker"], clawed["defender"], 0, claw_level)
	var claw_payload: Dictionary = (clawed["defender"] as TacticsPawn).stats.battle_statuses.get("wrap", {})
	_assert_true(int(claw_payload.get("counter", 0)) == 7, "Grip Claw extends the trap to 7 turns (%s)" % str(claw_payload))
	await _teardown(clawed)
	_finish("trap_statuses")


func _execute_until_hit(resolver: BattleActionResolver, attacker: TacticsPawn, target: TacticsPawn, slot: int, level: TacticsLevel) -> void:
	for attempt in range(12):
		var start: int = level.battle_log.events.size()
		resolver.execute(attacker, target, slot, level)
		var missed: bool = false
		for i in range(start, level.battle_log.events.size()):
			if String(level.battle_log.events[i].get("kind", "")) == "miss":
				missed = true
		if not missed:
			return


func _level(attacker_slug: String, move_ids: Array, defender_slug: String, item_id: String) -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "trap_%s" % attacker_slug
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	var attacker_instance: PokemonInstanceResource = _instance(attacker_slug, move_ids, PokemonInstanceResource.Team.PLAYER)
	if not item_id.is_empty():
		attacker_instance.held_item = PokemonItemService.load_item(item_id)
	definition.player_team = [attacker_instance]
	definition.enemy_team = [_instance(defender_slug, ["tackle"], PokemonInstanceResource.Team.ENEMY)]
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
