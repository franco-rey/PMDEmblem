extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var failures: int = 0
var resolver := BattleActionResolver.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _damage_pairs()
	await _reactions()
	await _turn_hooks()
	await _stat_and_status_rules()
	await _field_rules()
	if failures > 0:
		push_error("smoke: abilities_batch1 failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: abilities_batch1 clean")
	quit(0)


func _damage_pairs() -> void:
	var base: int = await _damage("0004_charmander", "ember", "0007_squirtle", "", "")
	var lens: int = await _damage("0004_charmander", "ember", "0007_squirtle", "tinted_lens", "")
	_assert_true(lens >= base * 2 - 2 and lens <= base * 2 + 2, "Tinted Lens doubles resisted damage (%d -> %d)" % [base, lens])
	var tackle: int = await _damage("0007_squirtle", "tackle", "0004_charmander", "", "")
	var huge: int = await _damage("0007_squirtle", "tackle", "0004_charmander", "huge_power", "")
	_assert_true(huge >= tackle * 2 - 2 and huge <= tackle * 2 + 2, "Huge Power doubles physical damage (%d -> %d)" % [tackle, huge])
	var water: int = await _damage("0007_squirtle", "water_gun", "0004_charmander", "", "")
	var filtered: int = await _damage("0007_squirtle", "water_gun", "0004_charmander", "", "filter")
	_assert_true(filtered < water and filtered >= int(water * 0.75) - 2 and filtered <= int(water * 0.75) + 2, "Filter cuts super-effective damage to 3/4 (%d -> %d)" % [water, filtered])
	var scaled: int = await _damage("0007_squirtle", "water_gun", "0004_charmander", "", "multiscale")
	_assert_true(scaled >= int(water * 0.5) - 2 and scaled <= int(water * 0.5) + 2, "Multiscale halves damage at full HP (%d -> %d)" % [water, scaled])
	var ghost_plain: int = await _damage("0007_squirtle", "tackle", "0094_gengar", "", "")
	var ghost_scrappy: int = await _damage("0007_squirtle", "tackle", "0094_gengar", "scrappy", "")
	_assert_true(ghost_plain == 0 and ghost_scrappy > 0, "Scrappy lets Tackle hit Gengar (%d -> %d)" % [ghost_plain, ghost_scrappy])
	var reckless_base: int = await _damage("0001_bulbasaur", "take_down", "0007_squirtle", "", "")
	var reckless: int = await _damage("0001_bulbasaur", "take_down", "0007_squirtle", "reckless", "")
	_assert_true(reckless > reckless_base, "Reckless boosts recoil moves (%d -> %d)" % [reckless_base, reckless])


func _reactions() -> void:
	var setup: Dictionary = await _level("0007_squirtle", ["tackle", "bite", "growl"], "0004_charmander", "", "weak_armor")
	var charmander: TacticsPawn = setup["defender"]
	_execute(setup, 0)
	_assert_true(charmander.stats.get_stat_stage("defense") == -1 and charmander.stats.get_stat_stage("speed") == 2, "Weak Armor drops Defense and raises Speed on a physical hit (%d/%d)" % [charmander.stats.get_stat_stage("defense"), charmander.stats.get_stat_stage("speed")])
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["bite"], "0004_charmander", "", "rattled")
	_execute(setup, 0)
	_assert_true((setup["defender"] as TacticsPawn).stats.get_stat_stage("speed") == 1, "Rattled raises Speed when hit by a Dark move")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "", "rough_skin")
	var squirtle: TacticsPawn = setup["attacker"]
	var before: int = squirtle.stats.curr_health
	_execute(setup, 0)
	_assert_true(before - squirtle.stats.curr_health == maxi(1, int(floor(float(squirtle.stats.max_health) / 8.0))), "Rough Skin hurts a contact attacker by 1/8 (%d)" % (before - squirtle.stats.curr_health))
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["water_gun"], "0004_charmander", "", "rough_skin")
	squirtle = setup["attacker"]
	before = squirtle.stats.curr_health
	_execute(setup, 0)
	_assert_true(squirtle.stats.curr_health == before, "Rough Skin ignores non-contact moves")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "moxie", "")
	(setup["defender"] as TacticsPawn).stats.curr_health = 1
	_execute(setup, 0)
	_assert_true((setup["attacker"] as TacticsPawn).stats.get_stat_stage("attack") == 1, "Moxie raises Attack after a knockout")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "", "aftermath")
	squirtle = setup["attacker"]
	(setup["defender"] as TacticsPawn).stats.curr_health = 1
	before = squirtle.stats.curr_health
	_execute(setup, 0)
	_assert_true(before - squirtle.stats.curr_health == maxi(1, int(floor(float(squirtle.stats.max_health) / 4.0))), "Aftermath costs a contact attacker 1/4 on the knockout (%d)" % (before - squirtle.stats.curr_health))
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["growl"], "0004_charmander", "", "soundproof")
	var start: int = (setup["level"] as TacticsLevel).battle_log.events.size()
	_execute(setup, 0)
	_assert_true((setup["defender"] as TacticsPawn).stats.get_stat_stage("attack") == 0 and _has_event(setup["level"], start, "damage_prevented", "intrinsic_id", "soundproof"), "Soundproof ignores sound moves")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["growl"], "0004_charmander", "", "defiant")
	_execute(setup, 0)
	_assert_true((setup["defender"] as TacticsPawn).stats.get_stat_stage("attack") == 1, "Defiant answers a foe's Attack drop with +2 (%d)" % (setup["defender"] as TacticsPawn).stats.get_stat_stage("attack"))
	await _teardown(setup)


func _turn_hooks() -> void:
	var setup: Dictionary = await _level("0007_squirtle", ["tackle"], "0004_charmander", "speed_boost", "")
	var level: TacticsLevel = setup["level"]
	var squirtle: TacticsPawn = setup["attacker"]
	level._on_turn_started(_unit_for(level, squirtle))
	_assert_true(squirtle.stats.get_stat_stage("speed") == 1, "Speed Boost raises Speed each turn")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "hydration", "")
	level = setup["level"]
	squirtle = setup["attacker"]
	level.set_battle_condition("rain", {})
	squirtle.stats.apply_battle_status("burn")
	level._on_turn_started(_unit_for(level, squirtle))
	_assert_true(not squirtle.stats.battle_statuses.has("burn"), "Hydration cures a major status in rain")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "shed_skin", "")
	level = setup["level"]
	squirtle = setup["attacker"]
	squirtle.stats.apply_battle_status("burn")
	var turns: int = 0
	while squirtle.stats.battle_statuses.has("burn") and turns < 30:
		level._on_turn_started(_unit_for(level, squirtle))
		turns += 1
	_assert_true(not squirtle.stats.battle_statuses.has("burn"), "Shed Skin eventually cures a major status (%d turns)" % turns)
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "ice_body", "")
	level = setup["level"]
	squirtle = setup["attacker"]
	level.set_battle_condition("hail", {})
	squirtle.stats.curr_health = 1
	level._on_turn_started(_unit_for(level, squirtle))
	_assert_true(squirtle.stats.curr_health == 1 + maxi(1, int(floor(float(squirtle.stats.max_health) / 16.0))), "Ice Body heals 1/16 in hail and ignores the chip (%d)" % squirtle.stats.curr_health)
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "magic_guard", "")
	level = setup["level"]
	squirtle = setup["attacker"]
	squirtle.stats.apply_battle_status("burn")
	var hp: int = squirtle.stats.curr_health
	level._on_turn_started(_unit_for(level, squirtle))
	_assert_true(squirtle.stats.curr_health == hp, "Magic Guard blocks burn damage")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "poison_heal", "")
	level = setup["level"]
	squirtle = setup["attacker"]
	squirtle.stats.apply_battle_status("poison")
	squirtle.stats.curr_health = 10
	level._on_turn_started(_unit_for(level, squirtle))
	_assert_true(squirtle.stats.curr_health == 10 + maxi(1, int(floor(float(squirtle.stats.max_health) / 8.0))), "Poison Heal turns poison into 1/8 healing (%d)" % squirtle.stats.curr_health)
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "truant", "")
	level = setup["level"]
	squirtle = setup["attacker"]
	level._on_turn_completed(_unit_for(level, squirtle))
	_assert_true(squirtle.stats.battle_statuses.has("paused") and String(squirtle.stats.consume_turn_skip_status().get("status_id", "")) == "paused", "Truant loafs on the turn after acting")
	await _teardown(setup)


func _stat_and_status_rules() -> void:
	var setup: Dictionary = await _level("0007_squirtle", ["growl", "sleep_powder"], "0004_charmander", "", "contrary")
	_execute(setup, 0)
	_assert_true((setup["defender"] as TacticsPawn).stats.get_stat_stage("attack") == 1, "Contrary inverts Growl into +1 Attack")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["growl"], "0004_charmander", "", "simple")
	_execute(setup, 0)
	_assert_true((setup["defender"] as TacticsPawn).stats.get_stat_stage("attack") == -2, "Simple doubles Growl to -2 Attack")
	await _teardown(setup)
	setup = await _level("0001_bulbasaur", ["sleep_powder"], "0004_charmander", "", "early_bird")
	_execute_until_hit(setup, 0)
	var sleep: Dictionary = (setup["defender"] as TacticsPawn).stats.battle_statuses.get("sleep", {})
	_assert_true(int(sleep.get("counter", 0)) == 3, "Early Bird halves the sleep counter (%s)" % str(sleep))
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["growl"], "0004_charmander", "no_guard", "")
	var level: TacticsLevel = setup["level"]
	var attacker: TacticsPawn = setup["attacker"]
	var blind: PokemonMoveResource = (attacker.stats.move_slots[0] as PokemonMoveResource).duplicate()
	blind.accuracy = 1
	attacker.stats.move_slots[0] = blind
	var start: int = level.battle_log.events.size()
	resolver.execute(attacker, setup["defender"], 0, level)
	_assert_true(not _has_event(level, start, "miss", "", "") and (setup["defender"] as TacticsPawn).stats.get_stat_stage("attack") == -1, "No Guard makes a 1% move hit")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["growl"], "0004_charmander", "compound_eyes", "sand_veil")
	level = setup["level"]
	level.set_battle_condition("sandstorm", {})
	var multiplier: float = level.intrinsic_service.accuracy_multiplier(setup["attacker"], setup["defender"], (setup["attacker"] as TacticsPawn).stats.move_slots[0], level)
	_assert_true(is_equal_approx(multiplier, 1.3 * 0.8), "Compound Eyes and Sand Veil combine on accuracy (%.2f)" % multiplier)
	_assert_true(is_equal_approx(level.intrinsic_service.effect_chance_multiplier((setup["attacker"] as TacticsPawn).stats), 1.0), "Serene Grace absent leaves effect chance alone")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["growl"], "0004_charmander", "serene_grace", "")
	_assert_true(is_equal_approx((setup["level"] as TacticsLevel).intrinsic_service.effect_chance_multiplier((setup["attacker"] as TacticsPawn).stats), 2.0), "Serene Grace doubles effect chances")
	await _teardown(setup)


func _field_rules() -> void:
	var setup: Dictionary = await _level("0007_squirtle", ["self_destruct"], "0004_charmander", "", "damp")
	var level: TacticsLevel = setup["level"]
	var start: int = level.battle_log.events.size()
	resolver.execute(setup["attacker"], setup["defender"], 0, level)
	_assert_true(_has_event(level, start, "move_rejected", "reason", "damp"), "Damp rejects Self-Destruct")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "drizzle", "")
	level = setup["level"]
	_assert_true(level.current_weather() == "rain" and level.weather_rounds_left() == 5, "Drizzle starts rain for five rounds (%s %d)" % [level.current_weather(), level.weather_rounds_left()])
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "drizzle", "cloud_nine")
	level = setup["level"]
	_assert_true(level.current_weather() == "rain" and level.effective_weather().is_empty(), "Cloud Nine suppresses weather effects while it lasts")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "gluttony", "", "berry_sitrus")
	var squirtle: TacticsPawn = setup["attacker"]
	squirtle.stats.curr_health = int(floor(float(squirtle.stats.max_health) * 0.45))
	var triggered: bool = PokemonItemService.try_trigger_held_threshold(squirtle, (setup["level"] as TacticsLevel).battle_log)
	_assert_true(triggered and squirtle.stats.pokemon_instance.held_item == null, "Gluttony eats the pinch berry at half HP")
	await _teardown(setup)
	setup = await _level("0007_squirtle", ["tackle"], "0004_charmander", "", "unnerve", "berry_sitrus")
	squirtle = setup["attacker"]
	squirtle.stats.curr_health = 5
	triggered = PokemonItemService.try_trigger_held_threshold(squirtle, (setup["level"] as TacticsLevel).battle_log)
	_assert_true(not triggered and squirtle.stats.pokemon_instance.held_item != null, "Unnerve stops the foe from eating berries")
	await _teardown(setup)


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
		if not _has_event(level, start, "miss", "", ""):
			return


func _has_event(level: TacticsLevel, start: int, kind: String, key: String, value: String) -> bool:
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) != kind:
			continue
		if key.is_empty() or String(event.get(key, "")) == value:
			return true
	return false


func _level(attacker_slug: String, move_ids: Array, defender_slug: String, attacker_ability: String, defender_ability: String, attacker_item: String = "") -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "ability_%s" % attacker_slug
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


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
