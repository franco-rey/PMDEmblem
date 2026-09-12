extends SmokeCase

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"


func _run() -> void:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "charge_release_smoke"
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 41
	definition.player_team = [_instance("0006_charizard", ["fly", "dig", "flamethrower", "slash"], PokemonInstanceResource.Team.PLAYER)]
	definition.enemy_team = [_instance("0009_blastoise", ["tackle", "withdraw"], PokemonInstanceResource.Team.ENEMY)]
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	_assert_true(level._scheduler_started, "scheduler started")
	var attacker: TacticsPawn = level.player.get_child(0)
	var defender: TacticsPawn = level.opponent.get_child(0)
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var attacker_key: Vector3i = Targeting._tile_key(attacker.get_tile())
	var placed: bool = false
	for direction in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		if keys.has(attacker_key + direction):
			_settle_on_tile(defender, keys[attacker_key + direction])
			attacker.serv.movement.look_at_direction_8(attacker, Vector3(float(direction.x), 0.0, float(direction.z)))
			placed = true
			break
	_assert_true(placed, "defender placed adjacent")
	var sprite: TacticsPawnSprite = attacker.get_node("Character")
	var base_offset: float = sprite.offset.y
	var visuals: PawnStateVisuals = attacker.get_node("StateVisuals")
	_assert_true(visuals != null, "pawn carries a state visuals node")
	var unit: BattleUnit = _unit_for(level, attacker)
	var resolver := BattleActionResolver.new()

	level._on_turn_started(unit)
	resolver.execute(attacker, defender, 0, level)
	_assert_true(attacker.stats.battle_statuses.has("charging") and attacker.stats.battle_statuses.has("airborne"), "Fly charges and lifts the user into the airborne state")
	_assert_true(level.charging_slot(attacker) == 0 and level.charging_release_target(attacker) == defender, "release plan points at Fly and the adjacent target")
	await create_timer(0.6).timeout
	_assert_true(sprite.lift_world > 0.5 and sprite.offset.y > base_offset + 10.0 and visuals.state == "airborne", "airborne sprite lifts off the ground (offset %.1f -> %.1f px, lift %.2f)" % [base_offset, sprite.offset.y, sprite.lift_world])
	var hp_before: int = defender.stats.curr_health
	var released: bool = level.release_charge(attacker)
	_assert_true(released and level.participant.res.stage == level.participant.res.STAGE_ATTACK and attacker.res.selected_move_index == 0, "ending the turn while airborne forces the Fly release")
	frames = 0
	while frames < 600 and (level.participant.res.stage == level.participant.res.STAGE_ATTACK or level.is_presentation_busy()):
		await physics_frame
		frames += 1
	_assert_true(defender.stats.curr_health < hp_before, "forced release hits the target (%d -> %d)" % [hp_before, defender.stats.curr_health])
	_assert_true(not attacker.stats.battle_statuses.has("charging") and not attacker.stats.battle_statuses.has("airborne"), "release clears the charging and airborne states")
	await create_timer(0.6).timeout
	_assert_true(is_zero_approx(sprite.lift_world) and is_equal_approx(sprite.offset.y, base_offset) and visuals.state == "", "sprite lands back on its base height after release")
	level._on_turn_completed(unit)

	level._on_turn_started(unit)
	resolver.execute(attacker, defender, 1, level)
	_assert_true(attacker.stats.battle_statuses.has("underground"), "Dig puts the user underground")
	for i in range(10):
		await process_frame
	var marker: Node = level.vfx_player.get_node_or_null("VFX_state_underground_Dig")
	_assert_true(not sprite.visible and marker != null and visuals.state == "underground", "underground hides the sprite and shows the dig mound marker")
	var far_tile: TacticsTile = null
	var far_distance: int = 0
	for key in keys.keys():
		var distance: int = (key as Vector3i).distance_squared_to(attacker_key)
		if distance > far_distance and keys[key].get_tile_occupier() == null:
			far_distance = distance
			far_tile = keys[key]
	_settle_on_tile(defender, far_tile)
	var before_lines: int = level.notation.lines.size()
	released = level.release_charge(attacker)
	_assert_true(not released and not attacker.stats.battle_statuses.has("charging") and not attacker.stats.battle_statuses.has("underground"), "release with no target in reach fails and clears the states")
	var joined: String = "\n".join(level.notation.lines.slice(before_lines))
	_assert_true(joined.contains("rej P1 dig charge_no_target"), "failed release is recorded in the transcript (%s)" % joined.replace("\n", " | "))
	for i in range(10):
		await process_frame
	_assert_true(sprite.visible and level.vfx_player.get_node_or_null("VFX_state_underground_Dig") == null, "sprite returns and the mound marker is freed")
	level._on_turn_completed(unit)
	loader.unload_current()
	loader.queue_free()
	await process_frame
	_finish("charge_release")


func _unit_for(level: TacticsLevel, pawn: TacticsPawn) -> BattleUnit:
	for candidate in level.battle_units:
		if candidate.pawn == pawn:
			return candidate
	return null


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


func _settle_on_tile(pawn: TacticsPawn, tile: TacticsTile) -> void:
	var ray: RayCast3D = pawn.get_node("Tile") as RayCast3D
	pawn.global_position = tile.global_position + Vector3.UP * 0.05
	ray.force_raycast_update()
	pawn.center()
	ray.force_raycast_update()
