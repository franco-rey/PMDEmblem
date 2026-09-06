extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var failures: int = 0
var resolver: BattleActionResolver = BattleActionResolver.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var setup: Dictionary = await _level("0004_charmander", ["spikes", "toxic_spikes", "stealth_rock", "sticky_web"], "0007_squirtle", ["tackle", "rapid_spin", "defog", "spikes"])
	var level: TacticsLevel = setup["level"]
	var charmander: TacticsPawn = setup["attacker"]
	var squirtle: TacticsPawn = setup["defender"]
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var facing: Vector3i = charmander.serv.movement.facing_direction_8(charmander)
	_assert_true(facing != Vector3i.ZERO and keys.has(Targeting._tile_key(charmander.get_tile()) + facing), "facing is recovered from the pawn rotation (%s)" % str(facing))
	var spikes: PokemonMoveResource = charmander.stats.move_slots[0]
	_assert_true(spikes.tactical_range_kind == PokemonMoveResource.TacticalRangeKind.SELF and spikes.can_target_self(), "hazard moves are self-targeted")
	resolver.execute(charmander, charmander, 0, level)
	var strip: Array[Vector3i] = level.hazards().strip_keys(charmander, keys)
	_assert_true(strip.size() == 3, "the strip covers three tiles in front of the user (%d)" % strip.size())
	var all_placed: bool = true
	for key in strip:
		all_placed = all_placed and level.hazards().layers_at(key, "spikes") == 1 and (keys[key] as Node).has_node("Hazard_spikes")
	_assert_true(all_placed, "Spikes lays one layer on every strip tile with a visible marker")
	_assert_true(level.message_log.history.has("Spikes were scattered in front of Charmander!"), "hazard message shown")
	resolver.execute(charmander, charmander, 0, level)
	_assert_true(level.hazards().layers_at(strip[0], "spikes") == 2, "a second Spikes adds a layer")
	var entry: Vector3i = strip[1]
	var tile: TacticsTile = keys[entry]
	squirtle.stats.curr_health = squirtle.stats.max_health
	_settle_on_tile(squirtle, tile)
	level.on_pawn_reached_tile(squirtle, tile.global_position)
	var expected: int = maxi(1, int(floor(float(squirtle.stats.max_health) / 6.0)))
	_assert_true(squirtle.stats.max_health - squirtle.stats.curr_health == expected, "two spike layers cost 1/6 max HP on entry (%d)" % (squirtle.stats.max_health - squirtle.stats.curr_health))
	_assert_true(level.message_log.history.has("Squirtle is hurt by the spikes!"), "spike damage message shown")
	squirtle.stats.curr_health = squirtle.stats.max_health
	squirtle.stats.types = ["water", "flying"] as Array[String]
	level.on_pawn_reached_tile(squirtle, tile.global_position)
	_assert_true(squirtle.stats.curr_health == squirtle.stats.max_health, "a Flying type ignores Spikes")
	squirtle.stats.types = ["water"] as Array[String]
	charmander.stats.curr_health = charmander.stats.max_health
	level.on_pawn_reached_tile(charmander, tile.global_position)
	_assert_true(charmander.stats.curr_health == charmander.stats.max_health, "the user's own side walks over its hazards")
	resolver.execute(charmander, charmander, 1, level)
	level.on_pawn_reached_tile(squirtle, tile.global_position)
	_assert_true(squirtle.stats.battle_statuses.has("poison"), "one Toxic Spikes layer poisons on entry")
	level._ops().remove_status(squirtle, "poison", {"source": "test"})
	resolver.execute(charmander, charmander, 1, level)
	level.on_pawn_reached_tile(squirtle, tile.global_position)
	_assert_true(squirtle.stats.battle_statuses.has("poison_toxic"), "two Toxic Spikes layers badly poison on entry")
	level._ops().remove_status(squirtle, "poison_toxic", {"source": "test"})
	squirtle.stats.types = ["poison"] as Array[String]
	level.on_pawn_reached_tile(squirtle, tile.global_position)
	_assert_true(level.hazards().layers_at(entry, "toxic_spikes") == 0 and not squirtle.stats.battle_statuses.has("poison"), "a grounded Poison type absorbs Toxic Spikes")
	squirtle.stats.types = ["water"] as Array[String]
	resolver.execute(charmander, charmander, 2, level)
	charmander.stats.types = ["fire", "flying"] as Array[String]
	squirtle.stats.curr_health = squirtle.stats.max_health
	squirtle.stats.types = ["fire", "flying"] as Array[String]
	level.on_pawn_reached_tile(squirtle, tile.global_position)
	var rock_expected: int = maxi(1, int(floor(float(squirtle.stats.max_health) * 4.0 / 8.0)))
	_assert_true(squirtle.stats.max_health - squirtle.stats.curr_health == rock_expected, "Stealth Rock scales with Rock effectiveness and hits Flying types (%d)" % (squirtle.stats.max_health - squirtle.stats.curr_health))
	squirtle.stats.types = ["water"] as Array[String]
	squirtle.stats.curr_health = squirtle.stats.max_health
	squirtle.stats.stat_stages = {}
	resolver.execute(charmander, charmander, 3, level)
	level.on_pawn_reached_tile(squirtle, tile.global_position)
	_assert_true(squirtle.stats.get_stat_stage("speed") == -1, "Sticky Web lowers Speed on entry (%d)" % squirtle.stats.get_stat_stage("speed"))
	resolver.execute(squirtle, squirtle, 3, level)
	var squirtle_strip: Array[Vector3i] = level.hazards().strip_keys(squirtle, keys)
	_assert_true(not squirtle_strip.is_empty() and level.hazards().layers_at(squirtle_strip[0], "spikes") == 1, "the foe can lay its own strip")
	_execute_until_hit(squirtle, charmander, 1, level)
	_assert_true(level.hazards().layers_at(entry, "spikes") == 0 and level.hazards().layers_at(entry, "stealth_rock") == 0 and not (keys[entry] as Node).has_node("Hazard_spikes"), "Rapid Spin clears the hazards laid by foes and their markers")
	_assert_true(level.hazards().layers_at(squirtle_strip[0], "spikes") == 1, "Rapid Spin keeps the user's own hazards")
	resolver.execute(squirtle, charmander, 2, level)
	_assert_true(level.hazards().tiles.is_empty(), "Defog clears every hazard")
	var notation: String = level.notation.text()
	_assert_true(notation.contains("hz +spikes") and notation.contains("hz clear"), "notation records hazard placement and clearing")
	await _teardown(setup)
	if failures > 0:
		push_error("smoke: hazards failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: hazards clean")
	quit(0)


func _execute_until_hit(attacker: TacticsPawn, target: TacticsPawn, slot: int, level: TacticsLevel) -> void:
	for attempt in range(12):
		var start: int = level.battle_log.events.size()
		resolver.execute(attacker, target, slot, level)
		var missed: bool = false
		for i in range(start, level.battle_log.events.size()):
			if String(level.battle_log.events[i].get("kind", "")) == "miss":
				missed = true
		if not missed:
			return


func _level(attacker_slug: String, attacker_moves: Array, defender_slug: String, defender_moves: Array) -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "hazards_%s" % attacker_slug
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	definition.player_team = [_instance(attacker_slug, attacker_moves, PokemonInstanceResource.Team.PLAYER)]
	definition.enemy_team = [_instance(defender_slug, defender_moves, PokemonInstanceResource.Team.ENEMY)]
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
		if keys.has(attacker_key + direction * 2) and keys.has(attacker_key + direction):
			_settle_on_tile(defender, keys[attacker_key + direction * 2])
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
