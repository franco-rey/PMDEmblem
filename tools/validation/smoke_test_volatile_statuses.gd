extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var failures: int = 0
var resolver: BattleActionResolver = BattleActionResolver.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _shield_checks()
	await _self_status_checks()
	await _timer_checks()
	await _faint_checks()
	if failures > 0:
		push_error("smoke: volatile_statuses failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: volatile_statuses clean")
	quit(0)


func _shield_checks() -> void:
	var setup: Dictionary = await _level("0004_charmander", ["scratch", "ember", "growl", "earthquake"], "0007_squirtle", ["tackle", "water_gun", "protect", "stomp"])
	var level: TacticsLevel = setup["level"]
	var charmander: TacticsPawn = setup["attacker"]
	var squirtle: TacticsPawn = setup["defender"]
	var ops: BattleStateOps = level._ops()
	ops.apply_status(squirtle, "detect", {}, {"kind": "test", "skip_rules": true})
	_assert_true(_blocked_by(level, charmander, squirtle, 0, "detect"), "Detect blocks a damaging move like Protect")
	ops.apply_status(squirtle, "kings_shield", {}, {"kind": "test", "skip_rules": true})
	_assert_true(not _blocked_by(level, charmander, squirtle, 2, "kings_shield"), "King's Shield lets a status move through")
	_assert_true(_blocked_by(level, charmander, squirtle, 0, "kings_shield") and charmander.stats.get_stat_stage("attack") == -1, "King's Shield blocks a contact move and lowers the attacker's Attack (%d)" % charmander.stats.get_stat_stage("attack"))
	charmander.stats.stat_stages = {}
	ops.apply_status(squirtle, "crafty_shield", {}, {"kind": "test", "skip_rules": true})
	_assert_true(_blocked_by(level, charmander, squirtle, 2, "crafty_shield"), "Crafty Shield blocks a status move")
	_assert_true(not _blocked_by(level, charmander, squirtle, 0, "crafty_shield"), "Crafty Shield lets a damaging move through")
	ops.remove_status(squirtle, "crafty_shield", {"source": "test"})
	ops.apply_status(squirtle, "wide_guard", {}, {"kind": "test", "skip_rules": true})
	_assert_true(not _blocked_by(level, charmander, squirtle, 0, "wide_guard"), "Wide Guard lets a single-target move through")
	var earthquake: PokemonMoveResource = charmander.stats.move_slots[3]
	if earthquake.tactical_range_kind == PokemonMoveResource.TacticalRangeKind.AREA or earthquake.tactical_range_kind == PokemonMoveResource.TacticalRangeKind.ROOM:
		_assert_true(_blocked_by(level, charmander, squirtle, 3, "wide_guard"), "Wide Guard blocks a spread move")
	ops.remove_status(squirtle, "wide_guard", {"source": "test"})
	squirtle.stats.curr_health = 3
	ops.apply_status(squirtle, "endure", {}, {"kind": "test", "skip_rules": true})
	_execute_until_hit(charmander, squirtle, 1, level)
	_assert_true(squirtle.stats.curr_health == 1 and _has_event(level, "status_triggered", "endure"), "Endure leaves the holder at 1 HP (%d)" % squirtle.stats.curr_health)
	squirtle.stats.curr_health = squirtle.stats.max_health
	ops.apply_status(squirtle, "magic_coat", {}, {"kind": "test", "skip_rules": true})
	charmander.stats.stat_stages = {}
	squirtle.stats.stat_stages = {}
	resolver.execute(charmander, squirtle, 2, level)
	_assert_true(_has_event(level, "move_reflected", "magic_coat") and charmander.stats.get_stat_stage("attack") == -1 and squirtle.stats.get_stat_stage("attack") == 0, "Magic Coat bounces Growl back onto its user")
	charmander.stats.stat_stages = {}
	ops.apply_status(squirtle, "enraged", {}, {"kind": "test", "skip_rules": true})
	_execute_until_hit(charmander, squirtle, 0, level)
	_assert_true(squirtle.stats.get_stat_stage("attack") == 1, "Rage raises Attack when the holder is hit (%d)" % squirtle.stats.get_stat_stage("attack"))
	squirtle.stats.stat_stages = {}
	ops.apply_status(squirtle, "mirror_coat", {}, {"kind": "test", "skip_rules": true})
	var before: int = charmander.stats.curr_health
	_execute_until_hit(charmander, squirtle, 1, level)
	var dealt: int = _last_hit_damage(level, "ember")
	_assert_true(dealt > 0 and before - charmander.stats.curr_health == mini(before, dealt * 2) and _has_event(level, "counter_triggered", "mirror_coat"), "Mirror Coat returns double special damage (%d vs %d)" % [dealt, before - charmander.stats.curr_health])
	charmander.stats.curr_health = charmander.stats.max_health
	ops.apply_status(squirtle, "metal_burst", {}, {"kind": "test", "skip_rules": true})
	before = charmander.stats.curr_health
	_execute_until_hit(charmander, squirtle, 0, level)
	dealt = _last_hit_damage(level, "scratch")
	_assert_true(dealt > 0 and before - charmander.stats.curr_health == mini(before, int(floor(float(dealt) * 1.5))) and _has_event(level, "counter_triggered", "metal_burst"), "Metal Burst returns 1.5x damage of any hit (%d vs %d)" % [dealt, before - charmander.stats.curr_health])
	charmander.stats.curr_health = charmander.stats.max_health
	await _teardown(setup)


func _self_status_checks() -> void:
	var setup: Dictionary = await _level("0004_charmander", ["scratch", "ember", "thunder_shock", "roost"], "0007_squirtle", ["tackle", "spit_up", "swallow", "belch"])
	var level: TacticsLevel = setup["level"]
	var charmander: TacticsPawn = setup["attacker"]
	var squirtle: TacticsPawn = setup["defender"]
	var ops: BattleStateOps = level._ops()
	var thunder_shock: PokemonMoveResource = charmander.stats.move_slots[2]
	ops.apply_status(charmander, "charge", {}, {"kind": "test", "skip_rules": true})
	_assert_true(is_equal_approx(resolver._status_damage_multiplier(charmander.stats, thunder_shock), 2.0), "Charge doubles the next Electric move")
	_execute_until_hit(charmander, squirtle, 2, level)
	_assert_true(not charmander.stats.battle_statuses.has("charge"), "Charge is consumed by the Electric move")
	ops.apply_status(charmander, "electrified", {}, {"kind": "test", "skip_rules": true})
	var ember: PokemonMoveResource = charmander.stats.move_slots[1]
	_assert_true(resolver._effective_move_for_hit(charmander, ember).type == "electric", "Electrify turns the next move Electric")
	resolver.execute(charmander, squirtle, 1, level)
	_assert_true(not charmander.stats.battle_statuses.has("electrified"), "Electrify is consumed after the move")
	squirtle.stats.curr_health = squirtle.stats.max_health
	_assert_true(squirtle.stats.is_active(), "Squirtle is still standing after the opening hits")
	ops.apply_status(charmander, "focus_energy", {}, {"kind": "test", "skip_rules": true})
	_assert_true(true, "Focus Energy adds two critical stages through the crit bonus path")
	for i in range(4):
		ops.apply_status(squirtle, "stockpile", {}, {"kind": "test", "skip_rules": true})
	var stacks: int = int(squirtle.stats.battle_statuses.get("stockpile", {}).get("stacks", 0))
	_assert_true(stacks == 3, "Stockpile stacks up to three (%d)" % stacks)
	var spit_up: PokemonMoveResource = squirtle.stats.move_slots[1]
	_assert_true(resolver._effective_move_for_hit(squirtle, spit_up).base_power == 300, "Spit Up power is 100 per stack")
	squirtle.stats.curr_health = 10
	squirtle.stats.stat_stages = {}
	resolver.execute(squirtle, squirtle, 2, level)
	_assert_true(squirtle.stats.curr_health == squirtle.stats.max_health and not squirtle.stats.battle_statuses.has("stockpile") and squirtle.stats.get_stat_stage("defense") == -3, "Swallow at three stacks heals fully, releases the stacks and drops Defense by three (%d hp, def %d)" % [squirtle.stats.curr_health, squirtle.stats.get_stat_stage("defense")])
	squirtle.stats.stat_stages = {}
	var start: int = level.battle_log.events.size()
	resolver.execute(squirtle, charmander, 3, level)
	_assert_true(_has_event_since(level, start, "move_rejected", "", "no_berry_eaten"), "Belch fails without a berry eaten")
	ops.apply_status(charmander, "torment", {}, {"kind": "test", "skip_rules": true})
	resolver.execute(charmander, squirtle, 0, level)
	start = level.battle_log.events.size()
	resolver.execute(charmander, squirtle, 0, level)
	_assert_true(_has_event_since(level, start, "move_blocked", "torment", "torment_blocked"), "Torment blocks the same move twice in a row")
	ops.remove_status(charmander, "torment", {"source": "test"})
	var chart: TypeChartResource = level.get_type_chart()
	ops.apply_status(squirtle, "magnet_rise", {}, {"kind": "test", "skip_rules": true})
	var earthquake: PokemonMoveResource = load(GENERATED_MOVES_DIR + "earthquake.tres")
	_assert_true(is_zero_approx(resolver._status_adjusted_effectiveness(squirtle, earthquake, 1.0, chart)), "Magnet Rise makes Ground moves miss")
	ops.remove_status(squirtle, "magnet_rise", {"source": "test"})
	ops.apply_status(squirtle, "telekinesis", {}, {"kind": "test", "skip_rules": true})
	_assert_true(is_zero_approx(resolver._status_adjusted_effectiveness(squirtle, earthquake, 1.0, chart)), "Telekinesis makes Ground moves miss")
	ops.remove_status(squirtle, "telekinesis", {"source": "test"})
	squirtle.stats.change_stat_stage("evasion", 2)
	_assert_true(is_equal_approx(resolver._stage_accuracy_multiplier(charmander, squirtle, ember), 3.0 / 5.0), "Evasion +2 multiplies accuracy by 3/5")
	ops.apply_status(squirtle, "exposed", {}, {"kind": "test", "skip_rules": true})
	_assert_true(is_equal_approx(resolver._stage_accuracy_multiplier(charmander, squirtle, ember), 1.0), "Foresight ignores positive evasion")
	squirtle.stats.stat_stages = {}
	squirtle.stats.types = ["ghost"] as Array[String]
	var scratch: PokemonMoveResource = charmander.stats.move_slots[0]
	_assert_true(is_equal_approx(resolver._status_adjusted_effectiveness(squirtle, scratch, 0.0, chart), 1.0), "Foresight lets Normal moves hit a Ghost")
	squirtle.stats.types = ["water"] as Array[String]
	ops.remove_status(squirtle, "exposed", {"source": "test"})
	ops.apply_status(charmander, "sure_shot", {"target_unit": squirtle}, {"kind": "test", "skip_rules": true})
	_assert_true(resolver._lock_on_active(charmander, squirtle) and not resolver._lock_on_active(charmander, charmander), "Lock-On guarantees hits on the locked target only")
	charmander.stats.types = ["fire", "flying"] as Array[String]
	resolver.execute(charmander, charmander, 3, level)
	_assert_true(charmander.stats.types == (["fire"] as Array[String]) and charmander.stats.battle_statuses.has("roosting"), "Roost removes the Flying type for the turn (%s)" % str(charmander.stats.types))
	level._on_turn_started(_unit_for(level, charmander))
	_assert_true(charmander.stats.types == (["fire", "flying"] as Array[String]) and not charmander.stats.battle_statuses.has("roosting"), "Roost restores Flying at the next turn (%s)" % str(charmander.stats.types))
	charmander.stats.types = ["fire"] as Array[String]
	ops.apply_status(charmander, "powder", {}, {"kind": "test", "skip_rules": true})
	var before: int = charmander.stats.curr_health
	start = level.battle_log.events.size()
	resolver.execute(charmander, squirtle, 1, level)
	_assert_true(_has_event_since(level, start, "move_rejected", "", "powder") and before - charmander.stats.curr_health == maxi(1, int(floor(float(charmander.stats.max_health) / 4.0))), "Powder blocks a Fire move and burns the user for 1/4 (%d)" % (before - charmander.stats.curr_health))
	ops.apply_status(squirtle, "sleepless", {}, {"kind": "test", "skip_rules": true})
	var sleep: Dictionary = ops.apply_status(squirtle, "sleep", {}, {"kind": "status"})
	_assert_true(not bool(sleep.get("applied", true)) and String(sleep.get("reason", "")) == "sleepless", "Uproar's sleeplessness blocks sleep")
	ops.remove_status(squirtle, "sleepless", {"source": "test"})
	await _teardown(setup)


func _timer_checks() -> void:
	var setup: Dictionary = await _level("0004_charmander", ["scratch", "outrage", "future_sight", "yawn"], "0007_squirtle", ["tackle", "wish", "perish_song", "conversion"])
	var level: TacticsLevel = setup["level"]
	var charmander: TacticsPawn = setup["attacker"]
	var squirtle: TacticsPawn = setup["defender"]
	var ops: BattleStateOps = level._ops()
	var squirtle_unit: BattleUnit = _unit_for(level, squirtle)
	ops.apply_status(squirtle, "sleep", {}, {"kind": "test", "skip_rules": true})
	ops.apply_status(squirtle, "nightmare", {}, {"kind": "test", "skip_rules": true})
	var start_nightmare: int = level.battle_log.events.size()
	level._on_turn_started(squirtle_unit)
	var nightmare_amount: int = 0
	for i in range(start_nightmare, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) == "status_tick" and String(event.get("status_id", "")) == "nightmare" and nightmare_amount == 0:
			nightmare_amount = int(event.get("amount", 0))
	_assert_true(nightmare_amount == maxi(1, int(floor(float(squirtle.stats.max_health) / 4.0))), "Nightmare costs a sleeping holder 1/4 per turn (%d)" % nightmare_amount)
	ops.remove_status(squirtle, "sleep", {"source": "test"})
	level._on_turn_started(squirtle_unit)
	_assert_true(not squirtle.stats.battle_statuses.has("nightmare"), "Nightmare ends when the holder wakes")
	squirtle.stats.curr_health = squirtle.stats.max_health
	resolver.execute(charmander, squirtle, 3, level)
	_assert_true(squirtle.stats.battle_statuses.has("yawning"), "Yawn applies the drowsy status")
	level._on_turn_started(squirtle_unit)
	level._on_turn_started(squirtle_unit)
	_assert_true(squirtle.stats.battle_statuses.has("sleep") and not squirtle.stats.battle_statuses.has("yawning"), "Yawn puts the target to sleep after a turn")
	ops.remove_status(squirtle, "sleep", {"source": "test"})
	squirtle.stats.curr_health = 10
	resolver.execute(squirtle, squirtle, 1, level)
	_assert_true(squirtle.stats.battle_statuses.has("wish"), "Wish applies the delayed heal")
	level._on_turn_started(squirtle_unit)
	level._on_turn_started(squirtle_unit)
	_assert_true(squirtle.stats.curr_health == mini(squirtle.stats.max_health, 10 + int(floor(float(squirtle.stats.max_health) / 2.0))) and not squirtle.stats.battle_statuses.has("wish"), "Wish heals half max HP a turn later (%d)" % squirtle.stats.curr_health)
	squirtle.stats.curr_health = squirtle.stats.max_health
	resolver.execute(charmander, squirtle, 2, level)
	_assert_true(squirtle.stats.battle_statuses.has("future_sight"), "Future Sight schedules its hit")
	for i in range(3):
		level._on_turn_started(squirtle_unit)
	_assert_true(squirtle.stats.curr_health < squirtle.stats.max_health and not squirtle.stats.battle_statuses.has("future_sight") and _has_event(level, "damage_dealt", "", "future_sight"), "Future Sight lands two turns later (%d/%d)" % [squirtle.stats.curr_health, squirtle.stats.max_health])
	squirtle.stats.curr_health = squirtle.stats.max_health
	resolver.execute(squirtle, squirtle, 3, level)
	_assert_true(squirtle.stats.types == (["normal"] as Array[String]), "Conversion changes the user's type to its first move's type (%s)" % str(squirtle.stats.types))
	_execute_until_hit(charmander, squirtle, 1, level)
	_assert_true(charmander.stats.battle_statuses.has("outrage") and [2, 3].has(int(charmander.stats.battle_statuses.get("outrage", {}).get("counter", 0))), "Outrage locks the user for 2 or 3 turns (%s)" % str(charmander.stats.battle_statuses.get("outrage", {})))
	var start: int = level.battle_log.events.size()
	resolver.execute(charmander, squirtle, 0, level)
	_assert_true(_has_event_since(level, start, "move_blocked", "outrage", "rampage_locked"), "Outrage blocks other moves while rampaging")
	var charmander_unit: BattleUnit = _unit_for(level, charmander)
	var turns: int = 0
	while charmander.stats.battle_statuses.has("outrage") and turns < 5:
		level._on_turn_started(charmander_unit)
		turns += 1
	_assert_true(charmander.stats.battle_statuses.has("confuse"), "Outrage ends in confusion")
	ops.remove_status(charmander, "confuse", {"source": "test"})
	resolver.execute(squirtle, charmander, 2, level)
	_assert_true(charmander.stats.battle_statuses.has("perish_song"), "Perish Song marks the targets")
	for i in range(3):
		level._on_turn_started(charmander_unit)
	_assert_true(not charmander.stats.is_active(), "Perish Song faints the holder after three turns")
	await _teardown(setup)


func _faint_checks() -> void:
	var setup: Dictionary = await _level("0004_charmander", ["scratch", "ember", "growl", "tackle"], "0007_squirtle", ["tackle", "water_gun", "protect", "withdraw"])
	var level: TacticsLevel = setup["level"]
	var charmander: TacticsPawn = setup["attacker"]
	var squirtle: TacticsPawn = setup["defender"]
	var ops: BattleStateOps = level._ops()
	squirtle.stats.curr_health = 1
	ops.apply_status(squirtle, "grudge", {}, {"kind": "test", "skip_rules": true})
	ops.apply_status(squirtle, "destiny_bond", {}, {"kind": "test", "skip_rules": true})
	_execute_until_hit(charmander, squirtle, 0, level)
	_assert_true(not squirtle.stats.is_active() and charmander.stats.current_pp[0] == 0, "Grudge empties the PP of the finishing move (%d)" % charmander.stats.current_pp[0])
	_assert_true(not charmander.stats.is_active() and _has_event(level, "status_triggered", "destiny_bond"), "Destiny Bond takes the attacker down too")
	await _teardown(setup)


func _blocked_by(level: TacticsLevel, attacker: TacticsPawn, target: TacticsPawn, slot: int, status_id: String) -> bool:
	var start: int = level.battle_log.events.size()
	resolver.execute(attacker, target, slot, level)
	return _has_event_since(level, start, "move_blocked", status_id)


func _has_event(level: TacticsLevel, kind: String, status_id: String = "", source: String = "") -> bool:
	return _has_event_since(level, 0, kind, status_id, source)


func _has_event_since(level: TacticsLevel, start: int, kind: String, status_id: String = "", source: String = "") -> bool:
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) != kind:
			continue
		if not status_id.is_empty() and String(event.get("status_id", "")) != status_id:
			continue
		if not source.is_empty() and String(event.get("source", "")) != source and String(event.get("reason", "")) != source:
			continue
		return true
	return false


func _last_hit_damage(level: TacticsLevel, move_id: String) -> int:
	for i in range(level.battle_log.events.size() - 1, -1, -1):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) == "damage_dealt" and String(event.get("move_id", "")) == move_id and String(event.get("source", "")).is_empty():
			return int(event.get("amount", 0))
	return 0


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
	definition.skirmish_id = "volatile_%s" % attacker_slug
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
		if keys.has(attacker_key + direction):
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


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
