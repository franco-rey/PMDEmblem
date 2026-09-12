extends SmokeCase

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var resolver: BattleActionResolver = BattleActionResolver.new()


func _run() -> void:
	await _charging_and_damage_checks()
	await _utility_checks()
	await _knockout_checks()
	_finish("move_specials")


func _charging_and_damage_checks() -> void:
	var setup: Dictionary = await _level("0004_charmander", ["fly", "scratch", "solar_beam", "skull_bash"], "0007_squirtle", ["tackle", "water_gun", "protect", "withdraw"])
	var level: TacticsLevel = setup["level"]
	var charmander: TacticsPawn = setup["attacker"]
	var squirtle: TacticsPawn = setup["defender"]
	var ops: BattleStateOps = level._ops()
	resolver.execute(charmander, squirtle, 0, level)
	_assert_true(charmander.stats.battle_statuses.has("charging") and charmander.stats.battle_statuses.has("airborne") and _has_event(level, "move_charging"), "Fly charges on the first turn and lifts the user")
	var start: int = level.battle_log.events.size()
	resolver.execute(squirtle, charmander, 0, level)
	_assert_true(_has_event_since(level, start, "miss", "", "airborne"), "an airborne target cannot be hit by Tackle")
	start = level.battle_log.events.size()
	resolver.execute(charmander, squirtle, 1, level)
	_assert_true(_has_event_since(level, start, "move_blocked", "charging", "charging_locked"), "a charging user cannot switch to another move")
	squirtle.stats.curr_health = squirtle.stats.max_health
	start = level.battle_log.events.size()
	_execute_until_hit(charmander, squirtle, 0, level)
	_assert_true(not charmander.stats.battle_statuses.has("charging") and not charmander.stats.battle_statuses.has("airborne") and squirtle.stats.curr_health < squirtle.stats.max_health, "Fly lands on the second turn")
	level.set_battle_condition("sunny", {"rounds": 5})
	squirtle.stats.curr_health = squirtle.stats.max_health
	_execute_until_hit(charmander, squirtle, 2, level)
	_assert_true(not charmander.stats.battle_statuses.has("charging") and squirtle.stats.curr_health < squirtle.stats.max_health, "Solar Beam skips the charge in sunlight")
	level.clear_weather("test")
	charmander.stats.stat_stages = {}
	resolver.execute(charmander, squirtle, 3, level)
	_assert_true(charmander.stats.battle_statuses.has("charging") and charmander.stats.get_stat_stage("defense") == 1, "Skull Bash raises Defense while charging")
	ops.remove_status(charmander, "charging", {"source": "test"})
	_set_moves(charmander, ["seismic_toss", "sonic_boom", "super_fang", "endeavor"])
	squirtle.stats.curr_health = squirtle.stats.max_health
	_execute_until_hit(charmander, squirtle, 0, level)
	_assert_true(squirtle.stats.max_health - squirtle.stats.curr_health == charmander.stats.level, "Seismic Toss deals damage equal to the user's level (%d)" % (squirtle.stats.max_health - squirtle.stats.curr_health))
	squirtle.stats.curr_health = squirtle.stats.max_health
	_execute_until_hit(charmander, squirtle, 1, level)
	_assert_true(squirtle.stats.max_health - squirtle.stats.curr_health == 20, "Sonic Boom deals 20 (%d)" % (squirtle.stats.max_health - squirtle.stats.curr_health))
	squirtle.stats.curr_health = squirtle.stats.max_health
	_execute_until_hit(charmander, squirtle, 2, level)
	_assert_true(squirtle.stats.curr_health == squirtle.stats.max_health - int(floor(float(squirtle.stats.max_health) / 2.0)), "Super Fang halves the target's HP (%d)" % squirtle.stats.curr_health)
	squirtle.stats.curr_health = squirtle.stats.max_health
	charmander.stats.curr_health = 10
	_execute_until_hit(charmander, squirtle, 3, level)
	_assert_true(squirtle.stats.curr_health == 10, "Endeavor brings the target down to the user's HP (%d)" % squirtle.stats.curr_health)
	charmander.stats.curr_health = charmander.stats.max_health
	squirtle.stats.curr_health = squirtle.stats.max_health
	_set_moves(charmander, ["hyper_beam", "high_jump_kick", "fury_attack", "mud_sport"])
	_execute_until_hit(charmander, squirtle, 0, level)
	_assert_true(charmander.stats.battle_statuses.has("recharge") and int(charmander.stats.battle_statuses["recharge"].get("counter", 0)) == 2, "Hyper Beam needs a recharge turn")
	ops.remove_status(charmander, "recharge", {"source": "test"})
	ops.apply_status(squirtle, "underground", {}, {"kind": "test", "skip_rules": true})
	var before: int = charmander.stats.curr_health
	resolver.execute(charmander, squirtle, 1, level)
	_assert_true(before - charmander.stats.curr_health == int(floor(float(charmander.stats.max_health) / 2.0)) and _has_event(level, "crash_damage"), "High Jump Kick crashes for half max HP when it misses (%d)" % (before - charmander.stats.curr_health))
	ops.remove_status(squirtle, "underground", {"source": "test"})
	charmander.stats.curr_health = charmander.stats.max_health
	var counts: Dictionary = {}
	var fury: PokemonMoveResource = charmander.stats.move_slots[2]
	for i in range(300):
		var n: int = resolver.move_specials.hit_count(resolver.intrinsic_service, charmander, fury, level.battle_rng)
		counts[n] = int(counts.get(n, 0)) + 1
	_assert_true(counts.keys().size() == 4 and not counts.has(1) and int(counts.get(2, 0)) > int(counts.get(5, 0)) and int(counts.get(3, 0)) > int(counts.get(4, 0)), "Fury Attack hits 2 to 5 times with the mainline weights (%s)" % str(counts))
	resolver.execute(charmander, charmander, 3, level)
	var shock: PokemonMoveResource = load(GENERATED_MOVES_DIR + "thunder_shock.tres")
	_assert_true(level.has_battle_condition("mud_sport") and is_equal_approx(resolver.move_specials.sport_multiplier(shock, level), 1.0 / 3.0), "Mud Sport weakens Electric moves to a third")
	for i in range(5):
		level._tick_battle_conditions()
	_assert_true(not level.has_battle_condition("mud_sport"), "Mud Sport ends after five rounds")
	_set_moves(charmander, ["rollout", "scratch", "defense_curl", "scratch"])
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var charmander_key: Vector3i = resolver._unit_key(charmander)
	var dash_direction: Vector3i = Vector3i.ZERO
	for direction in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		if keys.has(charmander_key + direction) and keys.has(charmander_key + direction * 2) and keys.has(charmander_key + direction * 3):
			dash_direction = direction
			break
	_settle_on_tile(squirtle, keys[charmander_key + dash_direction * 3])
	squirtle.stats.curr_health = squirtle.stats.max_health
	var dash_start: int = level.battle_log.events.size()
	resolver.execute(charmander, squirtle, 0, level)
	var dashed: bool = _has_event_since(level, dash_start, "forced_movement")
	var landed_adjacent: bool = resolver._unit_key(charmander) == charmander_key + dash_direction * 2
	var tip_hit: int = 0
	for i in range(dash_start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) == "damage_dealt" and String(event.get("move_id", "")) == "rollout":
			tip_hit = int(event.get("amount", 0))
	_assert_true(dashed and landed_adjacent, "Rollout dashes along the line and stops next to the first unit it meets")
	_assert_true(tip_hit > 0 or _has_event_since(level, dash_start, "miss"), "Rollout hits the unit it reaches with distance-scaled tip power (%d)" % tip_hit)
	_settle_on_tile(charmander, keys[charmander_key])
	squirtle.stats.curr_health = squirtle.stats.max_health
	_settle_on_tile(squirtle, keys[charmander_key + dash_direction])
	var adjacent_start: int = level.battle_log.events.size()
	_execute_until_hit(charmander, squirtle, 0, level)
	var adjacent_hit: int = 0
	for i in range(adjacent_start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) == "damage_dealt" and String(event.get("move_id", "")) == "rollout":
			adjacent_hit = int(event.get("amount", 0))
	_assert_true(adjacent_hit > 0 and (tip_hit == 0 or tip_hit > adjacent_hit), "a longer Rollout dash hits harder than an adjacent one (%d vs %d)" % [tip_hit, adjacent_hit])
	await _teardown(setup)


func _utility_checks() -> void:
	var setup: Dictionary = await _level("0004_charmander", ["metronome", "mirror_move", "sketch", "rest"], "0007_squirtle", ["tackle", "water_gun", "protect", "withdraw"])
	var level: TacticsLevel = setup["level"]
	var charmander: TacticsPawn = setup["attacker"]
	var squirtle: TacticsPawn = setup["defender"]
	var ops: BattleStateOps = level._ops()
	var start: int = level.battle_log.events.size()
	var metronome_target: TacticsPawn = charmander if charmander.stats.move_slots[0].can_target_self() else squirtle
	resolver.execute(charmander, metronome_target, 0, level)
	_assert_true(_has_event_since(level, start, "move_copied"), "Metronome calls another move")
	resolver.execute(squirtle, charmander, 0, level)
	start = level.battle_log.events.size()
	resolver.execute(charmander, squirtle, 1, level)
	var mirrored: Dictionary = _event_since(level, start, "move_copied")
	_assert_true(String(mirrored.get("copied_move_id", "")) == "tackle", "Mirror Move repeats the target's last move (%s)" % str(mirrored.get("copied_move_id", "")))
	resolver.execute(charmander, squirtle, 2, level)
	_assert_true(charmander.stats.move_slots[2].move_id == "tackle", "Sketch learns the target's last move into the slot")
	charmander.stats.curr_health = 10
	ops.apply_status(charmander, "burn", {}, {"kind": "test", "skip_rules": true})
	resolver.execute(charmander, charmander, 3, level)
	_assert_true(charmander.stats.curr_health == charmander.stats.max_health and charmander.stats.battle_statuses.has("sleep") and not charmander.stats.battle_statuses.has("burn"), "Rest heals fully, cures the burn and sleeps")
	ops.remove_status(charmander, "sleep", {"source": "test"})
	_set_moves(charmander, ["belly_drum", "psych_up", "power_swap", "guard_split"])
	charmander.stats.stat_stages = {}
	resolver.execute(charmander, charmander, 0, level)
	_assert_true(charmander.stats.curr_health == charmander.stats.max_health - int(floor(float(charmander.stats.max_health) / 2.0)) and charmander.stats.get_stat_stage("attack") == 6, "Belly Drum halves HP for +6 Attack (%d)" % charmander.stats.get_stat_stage("attack"))
	charmander.stats.curr_health = charmander.stats.max_health
	charmander.stats.stat_stages = {}
	squirtle.stats.stat_stages = {"defense": 2, "speed": -1}
	resolver.execute(charmander, squirtle, 1, level)
	_assert_true(charmander.stats.get_stat_stage("defense") == 2 and charmander.stats.get_stat_stage("speed") == -1, "Psych Up copies the target's stat stages")
	charmander.stats.stat_stages = {"attack": 3}
	squirtle.stats.stat_stages = {"special_attack": -2}
	resolver.execute(charmander, squirtle, 2, level)
	_assert_true(charmander.stats.get_stat_stage("attack") == 0 and charmander.stats.get_stat_stage("special_attack") == -2 and squirtle.stats.get_stat_stage("attack") == 3, "Power Swap trades offensive stages")
	charmander.stats.stat_stages = {}
	squirtle.stats.stat_stages = {}
	var average: int = int(floor(float(charmander.stats.raw_battle_stat("defense") + squirtle.stats.raw_battle_stat("defense")) / 2.0))
	resolver.execute(charmander, squirtle, 3, level)
	_assert_true(charmander.stats.raw_battle_stat("defense") == average and squirtle.stats.raw_battle_stat("defense") == average, "Guard Split averages Defense")
	charmander.stats.proxy_stats = {}
	squirtle.stats.proxy_stats = {}
	_set_moves(charmander, ["power_trick", "skill_swap", "roar", "soak"])
	var attack_value: int = charmander.stats.raw_battle_stat("attack")
	var defense_value: int = charmander.stats.raw_battle_stat("defense")
	resolver.execute(charmander, charmander, 0, level)
	_assert_true(charmander.stats.raw_battle_stat("attack") == defense_value and charmander.stats.raw_battle_stat("defense") == attack_value, "Power Trick swaps Attack and Defense")
	charmander.stats.proxy_stats = {}
	var mine: Array = Array(resolver.intrinsic_service.intrinsic_slugs_for(charmander.stats))
	var theirs: Array = Array(resolver.intrinsic_service.intrinsic_slugs_for(squirtle.stats))
	resolver.execute(charmander, squirtle, 1, level)
	_assert_true(Array(resolver.intrinsic_service.intrinsic_slugs_for(charmander.stats)) == theirs and Array(resolver.intrinsic_service.intrinsic_slugs_for(squirtle.stats)) == mine and mine != theirs, "Skill Swap exchanges abilities (%s <-> %s)" % [str(mine), str(theirs)])
	var key_before: Vector3i = resolver._unit_key(squirtle)
	start = level.battle_log.events.size()
	for attempt in range(10):
		resolver.execute(charmander, squirtle, 2, level)
		if _has_event_since(level, start, "forced_movement"):
			break
	_assert_true(_has_event_since(level, start, "forced_movement") and resolver._unit_key(squirtle) != key_before, "Roar knocks the target back")
	_execute_until_hit(charmander, squirtle, 3, level)
	_assert_true(squirtle.stats.types == (["water"] as Array[String]), "Soak keeps the target pure Water (%s)" % str(squirtle.stats.types))
	_set_moves(charmander, ["trick_or_treat", "reflect_type", "camouflage", "splash"])
	_execute_until_hit(charmander, squirtle, 0, level)
	_assert_true(squirtle.stats.types.has("ghost") and squirtle.stats.types.has("water"), "Trick-or-Treat adds Ghost (%s)" % str(squirtle.stats.types))
	resolver.execute(charmander, squirtle, 1, level)
	_assert_true(charmander.stats.types == squirtle.stats.types, "Reflect Type copies the target's types")
	resolver.execute(charmander, charmander, 2, level)
	_assert_true(charmander.stats.types == (["normal"] as Array[String]), "Camouflage turns the user Normal here")
	start = level.battle_log.events.size()
	resolver.execute(charmander, charmander, 3, level)
	_assert_true(not _has_event_since(level, start, "effect_unsupported"), "Splash resolves without an unsupported effect")
	await _teardown(setup)


func _knockout_checks() -> void:
	var setup: Dictionary = await _level("0004_charmander", ["fissure", "fell_stinger", "explosion", "scratch"], "0007_squirtle", ["tackle", "water_gun", "protect", "withdraw"])
	var level: TacticsLevel = setup["level"]
	var charmander: TacticsPawn = setup["attacker"]
	var squirtle: TacticsPawn = setup["defender"]
	squirtle.stats.temporary_intrinsic_slugs = ["sturdy"] as Array[String]
	squirtle.stats.intrinsic_override_active = true
	var start: int = level.battle_log.events.size()
	resolver.execute(charmander, squirtle, 0, level)
	_assert_true(_has_event_since(level, start, "damage_prevented", "", "intrinsic") and squirtle.stats.is_active(), "Sturdy blocks Fissure")
	squirtle.stats.curr_health = squirtle.stats.max_health
	squirtle.stats.temporary_intrinsic_slugs = [] as Array[String]
	squirtle.stats.intrinsic_override_active = false
	squirtle.stats.level = charmander.stats.level + 5
	start = level.battle_log.events.size()
	for attempt in range(60):
		resolver.execute(charmander, squirtle, 0, level)
		if _has_event_since(level, start, "move_rejected", "", "target_level_higher"):
			break
	_assert_true(_has_event_since(level, start, "move_rejected", "", "target_level_higher") and squirtle.stats.is_active(), "Fissure fails against a higher-level target")
	squirtle.stats.level = charmander.stats.level
	squirtle.stats.curr_health = 1
	charmander.stats.stat_stages = {}
	_execute_until_hit(charmander, squirtle, 1, level)
	_assert_true(not squirtle.stats.is_active() and charmander.stats.get_stat_stage("attack") == 3, "Fell Stinger raises Attack by three on a knockout (%d)" % charmander.stats.get_stat_stage("attack"))
	await _teardown(setup)
	var boom: Dictionary = await _level("0004_charmander", ["explosion", "scratch", "scratch", "scratch"], "0007_squirtle", ["tackle", "water_gun", "protect", "withdraw"])
	var boom_level: TacticsLevel = boom["level"]
	var user: TacticsPawn = boom["attacker"]
	var victim: TacticsPawn = boom["defender"]
	_execute_until_hit(user, victim, 0, boom_level)
	_assert_true(not user.stats.is_active() and victim.stats.curr_health < victim.stats.max_health, "Explosion damages the target and faints the user")
	await _teardown(boom)


func _set_moves(pawn: TacticsPawn, ids: Array) -> void:
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for id in ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(id)]) as PokemonMoveResource
		slots.append(move)
		pp.append(move.pp)
	pawn.stats.move_slots = slots
	pawn.stats.current_pp = pp


func _has_event(level: TacticsLevel, kind: String, status_id: String = "", source: String = "") -> bool:
	return _has_event_since(level, 0, kind, status_id, source)


func _has_event_since(level: TacticsLevel, start: int, kind: String, status_id: String = "", source: String = "") -> bool:
	return not _event_since(level, start, kind, status_id, source).is_empty()


func _event_since(level: TacticsLevel, start: int, kind: String, status_id: String = "", source: String = "") -> Dictionary:
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) != kind:
			continue
		if not status_id.is_empty() and String(event.get("status_id", "")) != status_id:
			continue
		if not source.is_empty() and String(event.get("source", "")) != source and String(event.get("reason", "")) != source:
			continue
		return event
	return {}


func _count_since(level: TacticsLevel, start: int, kind: String) -> int:
	var n: int = 0
	for i in range(start, level.battle_log.events.size()):
		if String(level.battle_log.events[i].get("kind", "")) == kind:
			n += 1
	return n


func _execute_until_hit(attacker: TacticsPawn, target: TacticsPawn, slot: int, level: TacticsLevel) -> void:
	for attempt in range(40):
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
	definition.skirmish_id = "specials_%s" % attacker_slug
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


func _settle_on_tile(pawn: TacticsPawn, tile: TacticsTile) -> void:
	var ray: RayCast3D = pawn.get_node("Tile") as RayCast3D
	pawn.global_position = tile.global_position + Vector3.UP * 0.05
	ray.force_raycast_update()
	pawn.center()
	ray.force_raycast_update()
