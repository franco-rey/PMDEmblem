extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/test_arena.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_rain_dance_and_multipliers()
	await _check_duration_and_messages()
	await _check_chip_damage_and_immunities()
	await _check_sun_rules()
	if failures > 0:
		push_error("smoke: weather failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: weather clean")
	quit(0)


func _check_rain_dance_and_multipliers() -> void:
	var dry: Dictionary = await _damage_sample("0007_squirtle", "water_gun", "0004_charmander", "")
	var wet: Dictionary = await _damage_sample("0007_squirtle", "water_gun", "0004_charmander", "rain")
	_assert_true(int(wet["damage"]) > int(dry["damage"]), "rain boosts Water Gun (%d -> %d)" % [dry["damage"], wet["damage"]])
	_assert_true(is_equal_approx(float(wet["weather_multiplier"]), 1.5), "rain reports a 1.5 weather multiplier (%s)" % wet["weather_multiplier"])
	var ember_dry: Dictionary = await _damage_sample("0004_charmander", "ember", "0001_bulbasaur", "")
	var ember_wet: Dictionary = await _damage_sample("0004_charmander", "ember", "0001_bulbasaur", "rain")
	_assert_true(int(ember_wet["damage"]) < int(ember_dry["damage"]) and is_equal_approx(float(ember_wet["weather_multiplier"]), 0.5), "rain halves Ember (%d -> %d)" % [ember_dry["damage"], ember_wet["damage"]])
	var ember_sun: Dictionary = await _damage_sample("0004_charmander", "ember", "0001_bulbasaur", "sunny")
	_assert_true(int(ember_sun["damage"]) > int(ember_dry["damage"]) and is_equal_approx(float(ember_sun["weather_multiplier"]), 1.5), "sun boosts Ember (%d -> %d)" % [ember_dry["damage"], ember_sun["damage"]])


func _check_duration_and_messages() -> void:
	var setup: Dictionary = await _level("0007_squirtle", ["rain_dance", "water_gun"], "0004_charmander")
	var level: TacticsLevel = setup["level"]
	var attacker: TacticsPawn = setup["attacker"]
	var resolver := BattleActionResolver.new()
	_assert_true(resolver.execute(attacker, attacker, 0, level), "Rain Dance executes on self")
	_assert_true(level.current_weather() == "rain" and level.weather_rounds_left() == BattleWeatherService.DEFAULT_ROUNDS, "Rain Dance starts rain for %d rounds (%s, %d)" % [BattleWeatherService.DEFAULT_ROUNDS, level.current_weather(), level.weather_rounds_left()])
	_assert_true(level.message_log.history.has("It started to rain!"), "message log shows the rain start message")
	_assert_true(level.message_log.history.has("Squirtle used Rain Dance!"), "message log shows the move use line (%s)" % str(level.message_log.recent(3)))
	var before_fail: int = level.battle_log.events.size()
	resolver.execute(attacker, attacker, 0, level)
	var failed: bool = false
	for i in range(before_fail, level.battle_log.events.size()):
		if String(level.battle_log.events[i].get("kind", "")) == "weather_failed":
			failed = true
	_assert_true(failed and level.weather_rounds_left() == BattleWeatherService.DEFAULT_ROUNDS and level.message_log.history.has("But it failed!"), "Rain Dance during rain fails without resetting the counter")
	for i in range(BattleWeatherService.DEFAULT_ROUNDS - 1):
		level._on_round_started()
	_assert_true(level.current_weather() == "rain" and level.weather_rounds_left() == 1, "rain persists through four round starts (%d left)" % level.weather_rounds_left())
	level._on_round_started()
	_assert_true(level.current_weather().is_empty() and level.message_log.history.has("The rain stopped."), "rain expires at the fifth round start with the end message")
	level.set_battle_condition("sunny", {})
	level.set_battle_condition("sandstorm", {})
	_assert_true(level.current_weather() == "sandstorm" and not level.has_battle_condition("sunny"), "a new weather replaces the previous one")
	_assert_true(level.weather_overlay != null and level.weather_overlay.weather_id == "sandstorm", "weather overlay follows the active weather")
	await _teardown(setup)


func _check_chip_damage_and_immunities() -> void:
	var setup: Dictionary = await _level("0007_squirtle", ["tackle"], "0074_geodude")
	var level: TacticsLevel = setup["level"]
	var squirtle: TacticsPawn = setup["attacker"]
	var geodude: TacticsPawn = setup["defender"]
	level.set_battle_condition("sandstorm", {})
	var hp_before: int = squirtle.stats.curr_health
	level._on_turn_started(_unit_for(level, squirtle))
	var expected: int = maxi(1, int(floor(float(squirtle.stats.max_health) / 16.0)))
	_assert_true(hp_before - squirtle.stats.curr_health == expected, "sandstorm chips 1/16 max HP per turn (%d)" % (hp_before - squirtle.stats.curr_health))
	_assert_true(level.message_log.history.has("Squirtle is buffeted by the sandstorm!"), "sandstorm chip shows its message")
	var rock_before: int = geodude.stats.curr_health
	level._on_turn_started(_unit_for(level, geodude))
	_assert_true(geodude.stats.curr_health == rock_before, "Rock types ignore sandstorm damage")
	var chip: int = BattleWeatherService.chip_fraction("hail", ["ice"], [])
	_assert_true(chip == 0 and BattleWeatherService.chip_fraction("hail", ["water"], ["ice_body"]) == 0 and BattleWeatherService.chip_fraction("hail", ["water"], []) == 16, "hail immunities cover Ice types and Ice Body")
	var rock_special: float = BattleWeatherService.damage_multiplier("sandstorm", load(GENERATED_MOVES_DIR + "water_gun.tres"), ["rock", "ground"])
	_assert_true(is_equal_approx(rock_special, 1.0 / 1.5), "sandstorm raises Rock Sp. Def against special moves (%.3f)" % rock_special)
	await _teardown(setup)


func _check_sun_rules() -> void:
	var setup: Dictionary = await _level("0001_bulbasaur", ["growth", "synthesis"], "0007_squirtle")
	var level: TacticsLevel = setup["level"]
	var bulbasaur: TacticsPawn = setup["attacker"]
	var resolver := BattleActionResolver.new()
	level.set_battle_condition("sunny", {})
	resolver.execute(bulbasaur, bulbasaur, 0, level)
	_assert_true(bulbasaur.stats.get_stat_stage("attack") == 2 and bulbasaur.stats.get_stat_stage("special_attack") == 2, "Growth gives +2 in sun (%d/%d)" % [bulbasaur.stats.get_stat_stage("attack"), bulbasaur.stats.get_stat_stage("special_attack")])
	bulbasaur.stats.curr_health = 1
	resolver.execute(bulbasaur, bulbasaur, 1, level)
	var expected_sun: int = 1 + int(floor(float(bulbasaur.stats.max_health) * 2.0 / 3.0))
	_assert_true(bulbasaur.stats.curr_health == expected_sun, "Synthesis heals 2/3 in sun (%d vs %d)" % [bulbasaur.stats.curr_health, expected_sun])
	level.clear_weather()
	level.set_battle_condition("rain", {})
	bulbasaur.stats.curr_health = 1
	resolver.execute(bulbasaur, bulbasaur, 1, level)
	var expected_rain: int = 1 + int(floor(float(bulbasaur.stats.max_health) / 4.0))
	_assert_true(bulbasaur.stats.curr_health == expected_rain, "Synthesis heals 1/4 in rain (%d vs %d)" % [bulbasaur.stats.curr_health, expected_rain])
	_assert_true(BattleWeatherService.blocks_status("sunny", "freeze") and not BattleWeatherService.blocks_status("rain", "freeze"), "harsh sunlight blocks freezing")
	_assert_true(BattleWeatherService.accuracy_override("rain", load(GENERATED_MOVES_DIR + "thunder.tres")) == 100 and BattleWeatherService.accuracy_override("sunny", load(GENERATED_MOVES_DIR + "thunder.tres")) == 50, "Thunder accuracy follows rain and sun")
	await _teardown(setup)


func _damage_sample(attacker_slug: String, move_id: String, defender_slug: String, weather: String) -> Dictionary:
	var setup: Dictionary = await _level(attacker_slug, [move_id], defender_slug)
	var level: TacticsLevel = setup["level"]
	if not weather.is_empty():
		level.set_battle_condition(weather, {})
	var resolver := BattleActionResolver.new()
	var start: int = level.battle_log.events.size()
	resolver.execute(setup["attacker"], setup["defender"], 0, level)
	var out: Dictionary = {"damage": 0, "weather_multiplier": 1.0}
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		if String(event.get("kind", "")) == "damage_dealt":
			out["damage"] = int(out["damage"]) + int(event.get("amount", event.get("damage", 0)))
			out["weather_multiplier"] = float(event.get("weather_multiplier", 1.0))
	if int(out["damage"]) == 0:
		out["damage"] = int(setup["defender_hp"]) - int((setup["defender"] as TacticsPawn).stats.curr_health)
	await _teardown(setup)
	return out


func _level(attacker_slug: String, move_ids: Array, defender_slug: String) -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "weather_%s_%s" % [attacker_slug, defender_slug]
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
	return {"loader": loader, "level": level, "attacker": attacker, "defender": defender, "defender_hp": defender.stats.curr_health}


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


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
