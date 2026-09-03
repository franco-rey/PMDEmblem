extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/test_arena.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var failures: int = 0
var resolver: BattleActionResolver = BattleActionResolver.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var baseline: Dictionary = await _hit_pair("", "")
	var band: Dictionary = await _hit_pair("held_choice_band", "", false, [0, 1])
	_assert_true(int(band["slash"]) > int(baseline["slash"]) and int(band["flamethrower"]) == 0 and bool(band.get("locked", false)), "Choice Band boosts physical and locks the user into its first move (%d vs %d)" % [int(band["slash"]), int(baseline["slash"])])
	var specs: Dictionary = await _hit_pair("held_choice_specs", "", false, [1, 0])
	_assert_true(int(specs["flamethrower"]) > int(baseline["flamethrower"]) and int(specs["slash"]) == 0 and bool(specs.get("locked", false)), "Choice Specs boosts special and locks the user")
	var vest: Dictionary = await _hit_pair("", "held_assault_vest")
	_assert_true(int(vest["flamethrower"]) < int(baseline["flamethrower"]) and int(vest["slash"]) == int(baseline["slash"]), "Assault Vest cuts special damage taken")
	_assert_true(bool(vest.get("defender_status_blocked", false)), "Assault Vest blocks the holder's status moves")
	var belt: Dictionary = await _hit_pair("held_expert_belt", "")
	_assert_true(int(belt["thunder_punch"]) > int(baseline["thunder_punch"]) and int(belt["slash"]) == int(baseline["slash"]), "Expert Belt boosts super-effective hits only")
	var plate: Dictionary = await _hit_pair("held_flame_plate", "")
	_assert_true(int(plate["flamethrower"]) > int(baseline["flamethrower"]), "plates boost their type like other type items")
	var bell: Dictionary = await _hit_pair("held_shell_bell", "", false, [0, 1, 2], 0.5)
	_assert_true(int(bell["attacker_hp_after"]) > int(bell["attacker_hp_before"]), "Shell Bell heals the attacker from damage dealt")
	var jaboca: Dictionary = await _hit_pair("", "berry_jaboca")
	_assert_true(int(jaboca["attacker_hp_after"]) < int(jaboca["attacker_hp_before"]) and String(jaboca["defender_item_after"]).is_empty(), "Jaboca Berry hurts a physical attacker and is eaten")
	var occa: Dictionary = await _hit_pair("", "berry_wacan")
	_assert_true(int(occa["thunder_punch"]) < int(baseline["thunder_punch"]) and String(occa["defender_item_after"]).is_empty(), "Wacan Berry halves a super-effective Electric hit once")
	var chilan: Dictionary = await _hit_pair("", "berry_chilan")
	_assert_true(int(chilan["slash"]) < int(baseline["slash"]), "Chilan Berry halves a Normal hit")
	var enigma: Dictionary = await _hit_pair("", "berry_enigma")
	_assert_true(bool(enigma.get("defender_healed", false)) and String(enigma["defender_item_after"]).is_empty(), "Enigma Berry heals after a super-effective hit")
	var metronome: Dictionary = await _hit_pair("held_metronome", "", true)
	_assert_true(int(metronome["slash_repeat"]) > int(metronome["slash"]), "Metronome boosts a repeated move (%d -> %d)" % [int(metronome["slash"]), int(metronome["slash_repeat"])])
	await _turn_item_checks()
	if failures > 0:
		push_error("smoke: held_items_mainline failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: held_items_mainline clean")
	quit(0)


func _turn_item_checks() -> void:
	var setup: Dictionary = await _level("0006_charizard", ["slash", "flamethrower", "giga_drain", "growl"], "0009_blastoise", ["tackle", "water_gun", "withdraw", "toxic"], "held_sticky_barb", "held_flame_orb")
	var level: TacticsLevel = setup["level"]
	var charizard: TacticsPawn = setup["attacker"]
	var blastoise: TacticsPawn = setup["defender"]
	var before: int = charizard.stats.curr_health
	level._on_turn_started(_unit_for(level, charizard))
	_assert_true(before - charizard.stats.curr_health == maxi(1, int(floor(float(charizard.stats.max_health) / 8.0))), "Sticky Barb costs its holder 1/8 each turn")
	level._on_turn_started(_unit_for(level, blastoise))
	_assert_true(blastoise.stats.battle_statuses.has("burn"), "Flame Orb burns its holder at its turn")
	_execute_until_hit(blastoise, charizard, 0, level)
	_assert_true(PokemonItemService.held_item_for(blastoise.stats) != null and PokemonItemService.held_item_for(blastoise.stats).item_id == "held_flame_orb", "Sticky Barb does not move onto an attacker that already holds an item")
	PokemonItemService.take_held_item(blastoise, level.battle_log, "test")
	_execute_until_hit(blastoise, charizard, 0, level)
	_assert_true(PokemonItemService.held_item_for(blastoise.stats) != null and PokemonItemService.held_item_for(blastoise.stats).item_id == "held_sticky_barb" and PokemonItemService.held_item_for(charizard.stats) == null, "Sticky Barb jumps to a bare-handed contact attacker")
	var ops: BattleStateOps = level._ops()
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("held_toxic_orb")
	level._on_turn_started(_unit_for(level, charizard))
	_assert_true(charizard.stats.battle_statuses.has("poison_toxic"), "Toxic Orb badly poisons its holder")
	ops.remove_status(charizard, "poison_toxic", {"source": "test"})
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("berry_leppa")
	charizard.stats.current_pp[0] = 0
	level._on_turn_started(_unit_for(level, charizard))
	_assert_true(charizard.stats.current_pp[0] == 10 and PokemonItemService.held_item_for(charizard.stats) == null, "Leppa Berry restores 10 PP to an empty move")
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("berry_lum")
	var paralyzed: Dictionary = ops.apply_status(charizard, "paralyze", {}, {"kind": "status"})
	_assert_true(bool(paralyzed.get("applied", false)) and not charizard.stats.battle_statuses.has("paralyze") and PokemonItemService.held_item_for(charizard.stats) == null, "Lum Berry cures a status the moment it lands")
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("berry_cheri")
	ops.apply_status(charizard, "poison", {}, {"kind": "status"})
	_assert_true(charizard.stats.battle_statuses.has("poison") and PokemonItemService.held_item_for(charizard.stats) != null, "Cheri Berry ignores poison")
	ops.remove_status(charizard, "poison", {"source": "test"})
	ops.apply_status(charizard, "paralyze", {}, {"kind": "status"})
	_assert_true(not charizard.stats.battle_statuses.has("paralyze") and PokemonItemService.held_item_for(charizard.stats) == null, "Cheri Berry cures paralysis")
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("berry_sitrus")
	charizard.stats.curr_health = int(floor(float(charizard.stats.max_health) * 0.55))
	var hp_before: int = charizard.stats.curr_health
	ops.damage(charizard, int(floor(float(charizard.stats.max_health) * 0.1)), {"kind": "hit", "attacker": blastoise})
	_assert_true(charizard.stats.curr_health > hp_before - int(floor(float(charizard.stats.max_health) * 0.1)) and PokemonItemService.held_item_for(charizard.stats) == null, "Sitrus Berry triggers at half HP")
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("berry_oran")
	charizard.stats.curr_health = int(floor(float(charizard.stats.max_health) * 0.55))
	hp_before = charizard.stats.curr_health
	ops.damage(charizard, int(floor(float(charizard.stats.max_health) * 0.1)), {"kind": "hit", "attacker": blastoise})
	_assert_true(charizard.stats.curr_health == hp_before - int(floor(float(charizard.stats.max_health) * 0.1)) + 10, "Oran Berry heals 10 at half HP")
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("held_ring_target")
	var chart: TypeChartResource = level.get_type_chart()
	charizard.stats.types = ["ghost"] as Array[String]
	var tackle: PokemonMoveResource = blastoise.stats.move_slots[0]
	_assert_true(resolver._status_adjusted_effectiveness(charizard, tackle, 0.0, chart) > 0.0, "Ring Target removes type immunity")
	charizard.stats.types = ["fire", "flying"] as Array[String]
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("held_choice_scarf")
	var speed_before: int = charizard.stats.battle_stat("speed")
	PokemonItemService.apply_held_effects_to_stats(charizard.stats, level.battle_log)
	_assert_true(charizard.stats.battle_stat("speed") > speed_before, "Choice Scarf raises Speed")
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("held_iron_ball")
	PokemonItemService.apply_held_effects_to_stats(charizard.stats, level.battle_log)
	_assert_true(charizard.stats.battle_stat("speed") < speed_before and not level.hazards()._is_grounded(charizard) == false, "Iron Ball halves Speed and grounds the holder")
	_assert_true(PokemonItemService.crit_stage_bonus(charizard.stats) == 0 and PokemonItemService.accuracy_multiplier(charizard.stats) == 1.0, "no crit or accuracy bonus without the lens items")
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("held_scope_lens")
	_assert_true(PokemonItemService.crit_stage_bonus(charizard.stats) == 1, "Scope Lens adds a critical stage")
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("held_wide_lens")
	_assert_true(is_equal_approx(PokemonItemService.accuracy_multiplier(charizard.stats), 1.1), "Wide Lens raises accuracy by 10 percent")
	charizard.stats.pokemon_instance.held_item = PokemonItemService.load_item("held_big_root")
	_assert_true(is_equal_approx(PokemonItemService.drain_multiplier(charizard.stats), 1.3), "Big Root boosts drains")
	_assert_true(not BattleItemCatalog.is_selectable("held_power_band") and BattleItemCatalog.is_selectable("held_life_orb"), "PMD-only held items are not selectable")
	await _teardown(setup)


func _hit_pair(attacker_item: String, defender_item: String, repeat: bool = false, slots: Array = [0, 1, 2], attacker_hp_fraction: float = 1.0) -> Dictionary:
	var setup: Dictionary = await _level("0006_charizard", ["slash", "flamethrower", "thunder_punch", "growl"], "0009_blastoise", ["tackle", "water_gun", "withdraw", "toxic"], attacker_item, defender_item)
	var level: TacticsLevel = setup["level"]
	var charizard: TacticsPawn = setup["attacker"]
	var blastoise: TacticsPawn = setup["defender"]
	if attacker_hp_fraction < 1.0:
		charizard.stats.curr_health = int(floor(float(charizard.stats.max_health) * attacker_hp_fraction))
	var out: Dictionary = {"attacker_hp_before": charizard.stats.curr_health, "slash": 0, "flamethrower": 0, "thunder_punch": 0}
	for slot in slots:
		blastoise.stats.curr_health = blastoise.stats.max_health
		var start: int = level.battle_log.events.size()
		_execute_until_hit(charizard, blastoise, slot, level)
		out[charizard.stats.move_slots[slot].move_id] = _damage_since(level, start, charizard.stats.move_slots[slot].move_id)
		if _blocked_since(level, start, "choice_locked"):
			out["locked"] = true
		for i in range(start, level.battle_log.events.size()):
			if String(level.battle_log.events[i].get("kind", "")) == "healed" and level.battle_log.events[i].get("unit") == blastoise:
				out["defender_healed"] = true
		if repeat and slot == 0:
			blastoise.stats.curr_health = blastoise.stats.max_health
			var again: int = level.battle_log.events.size()
			_execute_until_hit(charizard, blastoise, 0, level)
			out["slash_repeat"] = _damage_since(level, again, "slash")
	out["attacker_hp_after"] = charizard.stats.curr_health
	var status_start: int = level.battle_log.events.size()
	resolver.execute(blastoise, blastoise, 2, level)
	out["defender_status_blocked"] = _blocked_since(level, status_start, "assault_vest")
	out["defender_item_after"] = PokemonItemService.held_item_for(blastoise.stats).item_id if PokemonItemService.held_item_for(blastoise.stats) != null else ""
	await _teardown(setup)
	return out


func _damage_since(level: TacticsLevel, start: int, move_id: String) -> int:
	var total: int = 0
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) == "damage_dealt" and String(event.get("move_id", "")) == move_id and String(event.get("source", "")).is_empty():
			total += int(event.get("amount", 0))
	return total


func _blocked_since(level: TacticsLevel, start: int, reason: String) -> bool:
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) == "move_blocked" and String(event.get("reason", "")) == reason:
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
	definition.skirmish_id = "held_%s" % attacker_slug
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
