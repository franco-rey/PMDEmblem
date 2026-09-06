extends SceneTree

const SkirmishCode = preload("res://data/modules/skirmish/skirmish_code.gd")

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"

var failures: int = 0


func _init() -> void:
	_check_legacy_seed()
	_check_bots_seed()
	_check_series_expansion()
	_check_explicit_teams_and_moves()
	_check_ability_item_fields()
	_check_semicolon_matches()
	_check_invalid_inputs()

	if failures > 0:
		push_error("smoke: skirmish_code failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: skirmish_code clean")
		quit(0)


func _check_legacy_seed() -> void:
	var parsed: Dictionary = SkirmishCode.parse("12345")
	_assert_true(parsed.get("ok", false), "legacy integer seed parses")
	var built: Dictionary = SkirmishCode.build_definitions("12345", {"map_path": TEST_ARENA_MAP_PATH, "team_size": 3})
	_assert_true(built.get("ok", false), "legacy integer seed builds")
	if not built.get("ok", false):
		return
	var definitions: Array = built["definitions"]
	_assert_true(definitions.size() == 1, "legacy integer seed builds one match")
	var definition: SkirmishDefinitionResource = definitions[0]
	_assert_true(definition.seed == 12345, "legacy integer seed is preserved")
	_assert_true(definition.control_mode == SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU, "legacy integer seed defaults to pvc")


func _check_bots_seed() -> void:
	var built: Dictionary = SkirmishCode.build_definitions("12345 -bots", {"map_path": TEST_ARENA_MAP_PATH, "team_size": 3})
	_assert_true(built.get("ok", false), "integer seed with -bots builds")
	if not built.get("ok", false):
		return
	var definition: SkirmishDefinitionResource = (built["definitions"] as Array)[0]
	_assert_true(definition.control_mode == SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU, "-bots sets bots control mode")
	_assert_true(_all_controlled_by(definition.player_team, PokemonInstanceResource.ControlType.AI), "-bots player side is AI")
	_assert_true(_all_controlled_by(definition.enemy_team, PokemonInstanceResource.ControlType.AI), "-bots enemy side is AI")


func _check_series_expansion() -> void:
	var built: Dictionary = SkirmishCode.build_definitions("series seed=700 team=6 matches=5 -bots", {"map_path": TEST_ARENA_MAP_PATH})
	_assert_true(built.get("ok", false), "series 6v6 bots builds")
	if not built.get("ok", false):
		return
	var definitions: Array = built["definitions"]
	_assert_true(definitions.size() == 5, "series expands to five matches")
	for i in range(definitions.size()):
		var definition: SkirmishDefinitionResource = definitions[i]
		_assert_true(definition.seed == 700 + i, "series seed %d is %d" % [i + 1, 700 + i])
		_assert_true(definition.player_team.size() == 6 and definition.enemy_team.size() == 6, "series match %d is 6v6" % (i + 1))
		_assert_true(definition.control_mode == SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU, "series match %d is bots" % (i + 1))


func _check_explicit_teams_and_moves() -> void:
	var code: String = "match seed=42 -bots p=0448_lucario@50:aura_sphere,quick_attack e=0094_gengar@50:shadow_ball,hypnosis"
	var built: Dictionary = SkirmishCode.build_definitions(code, {"map_path": TEST_ARENA_MAP_PATH})
	_assert_true(built.get("ok", false), "explicit teams and moves build")
	if not built.get("ok", false):
		return
	var definition: SkirmishDefinitionResource = (built["definitions"] as Array)[0]
	_assert_true(_species_slugs(definition.player_team) == ["0448_lucario"], "explicit player species is Lucario")
	_assert_true(_species_slugs(definition.enemy_team) == ["0094_gengar"], "explicit enemy species is Gengar")
	_assert_true(definition.player_team[0].level == 50, "explicit player level is applied")
	_assert_true(definition.enemy_team[0].level == 50, "explicit enemy level is applied")
	_assert_true(_move_slugs(definition.player_team[0]) == ["aura_sphere", "quick_attack"], "explicit player moves are applied")
	_assert_true(_move_slugs(definition.enemy_team[0]) == ["shadow_ball", "hypnosis"], "explicit enemy moves are applied")
	_assert_true(_all_controlled_by(definition.player_team, PokemonInstanceResource.ControlType.AI), "explicit bots player side is AI")
	_assert_true(_all_controlled_by(definition.enemy_team, PokemonInstanceResource.ControlType.AI), "explicit bots enemy side is AI")


func _check_semicolon_matches() -> void:
	var code: String = "match seed=1 -bots team=6; match seed=2 mode=pvp p=0448_lucario e=0094_gengar"
	var built: Dictionary = SkirmishCode.build_definitions(code, {"map_path": TEST_ARENA_MAP_PATH})
	_assert_true(built.get("ok", false), "semicolon-separated matches build")
	if not built.get("ok", false):
		return
	var definitions: Array = built["definitions"]
	_assert_true(definitions.size() == 2, "semicolon code builds two matches")
	_assert_true((definitions[0] as SkirmishDefinitionResource).control_mode == SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU, "first semicolon match is bots")
	_assert_true((definitions[1] as SkirmishDefinitionResource).control_mode == SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER, "second semicolon match is pvp")


func _check_invalid_inputs() -> void:
	_assert_build_fails("match seed=1 nope", "unknown token fails")
	_assert_build_fails("match seed=1 mode=banana", "invalid mode fails")
	_assert_build_fails("match seed=abc", "invalid seed fails")
	_assert_build_fails("series seed=1 team=0", "team=0 fails")
	_assert_build_fails("series seed=1 team=17", "team=17 fails past the chessboard cap")
	_assert_build_fails("series seed=1 team=21", "team=21 fails past the absolute cap")
	_assert_build_fails("series seed=1 matches=0", "matches=0 fails")
	_assert_build_fails("series seed=1 matches=11", "matches=11 fails")
	_assert_build_fails("match seed=1 p=missingno e=0094_gengar", "unknown Pokemon slug fails")
	_assert_build_fails("match seed=1 p=0448_lucario:not_a_move e=0094_gengar", "unknown move slug fails")


const OWNER_TEST_CODE: String = "match seed=7 mode=pvp p=0007_squirtle@50:rain_dance,water_gun,withdraw,bite:torrent:berry_sitrus|0001_bulbasaur@50:leech_seed,growl,synthesis,razor_leaf:chlorophyll:berry_oran|0004_charmander@50:ember,smokescreen,scary_face,fire_spin:blaze e=0005_charmeleon@50:ember,slash,dragon_rage,growl:blaze|0008_wartortle@50:water_gun,bite,rapid_spin,protect:torrent|0002_ivysaur@50:vine_whip,poison_powder,sleep_powder,growth:overgrow:berry_oran"
const COMPLETION_TEST_CODE: String = "match seed=11 mode=pvp p=0003_venusaur@50:leech_seed,toxic_spikes,solar_beam,sunny_day:chlorophyll:berry_sitrus|0006_charizard@50:fly,roar,stealth_rock,flamethrower:blaze:held_life_orb|0009_blastoise@50:rain_dance,hydro_pump,rapid_spin,protect:torrent:berry_lum e=0009_blastoise@50:water_pulse,yawn,spikes,ice_beam:torrent:berry_oran|0003_venusaur@50:sludge_bomb,giga_drain,stockpile,swallow:overgrow:berry_sitrus|0006_charizard@50:hyper_beam,dragon_claw,defog,earthquake:blaze"


func _check_ability_item_fields() -> void:
	var built: Dictionary = SkirmishCode.build_definitions(OWNER_TEST_CODE, {"map_path": TEST_ARENA_MAP_PATH})
	_assert_true(bool(built.get("ok", false)), "owner test code builds (%s)" % String(built.get("error", "")))
	if not bool(built.get("ok", false)):
		return
	var definition: SkirmishDefinitionResource = built["definitions"][0]
	_assert_true(definition.player_team.size() == 3 and definition.enemy_team.size() == 3, "owner test code builds 3v3")
	_assert_true(definition.player_team[0].ability_override == "torrent" and definition.player_team[0].held_item != null and definition.player_team[0].held_item.item_id == "berry_sitrus", "code sets Squirtle's ability and Sitrus Berry")
	_assert_true(definition.player_team[2].held_item == null and definition.player_team[2].ability_override == "blaze", "code leaves Charmander itemless with Blaze")
	_assert_true(definition.enemy_team[2].held_item != null and definition.enemy_team[2].held_item.item_id == "berry_oran" and _move_slugs(definition.enemy_team[2]) == ["vine_whip", "poison_powder", "sleep_powder", "growth"], "code sets the enemy Ivysaur moves and Oran Berry")
	_assert_true(definition.player_team[0].loadout_locked and definition.control_mode == SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER, "code locks loadouts and sets PvP")
	var encoded: String = SkirmishCode.encode_definition(definition)
	var rebuilt: Dictionary = SkirmishCode.build_definitions(encoded, {"map_path": TEST_ARENA_MAP_PATH})
	_assert_true(bool(rebuilt.get("ok", false)) and SkirmishCode.encode_definition(rebuilt["definitions"][0]) == encoded, "encoded code round-trips (%s)" % encoded)
	var showcase: Dictionary = SkirmishCode.build_definitions(COMPLETION_TEST_CODE, {"map_path": TEST_ARENA_MAP_PATH})
	_assert_true(bool(showcase.get("ok", false)) and showcase["definitions"][0].player_team.size() == 3, "completion-pass showcase code builds (%s)" % String(showcase.get("error", "")))
	_assert_build_fails("match seed=1 p=0001_bulbasaur@50:tackle::seed_blast e=0007_squirtle", "PMD seeds are rejected as held items")
	_assert_build_fails("match seed=1 p=0001_bulbasaur@50:tackle:blaze e=0007_squirtle", "ability not owned by the species fails")
	_assert_build_fails("match seed=1 p=0001_bulbasaur@50:tackle::not_an_item e=0007_squirtle", "unknown item fails")
	var random_built: Dictionary = SkirmishCode.build_definitions("match seed=3 p=0001_bulbasaur@50::random:random e=0007_squirtle", {"map_path": TEST_ARENA_MAP_PATH})
	_assert_true(bool(random_built.get("ok", false)) and ["overgrow", "chlorophyll"].has(random_built["definitions"][0].player_team[0].ability_override) and random_built["definitions"][0].player_team[0].held_item != null, "random ability and item fields resolve")


func _assert_build_fails(code: String, label: String) -> void:
	var built: Dictionary = SkirmishCode.build_definitions(code, {"map_path": TEST_ARENA_MAP_PATH})
	_assert_true(not built.get("ok", false), label)


func _all_controlled_by(team: Array[PokemonInstanceResource], control_type: int) -> bool:
	for instance in team:
		if instance == null or instance.control_type != control_type:
			return false
	return true


func _species_slugs(team: Array[PokemonInstanceResource]) -> Array[String]:
	var out: Array[String] = []
	for instance in team:
		out.append(instance.species.species_id if instance != null and instance.species != null else "?")
	return out


func _move_slugs(instance: PokemonInstanceResource) -> Array[String]:
	var out: Array[String] = []
	if instance == null:
		return out
	for move in instance.move_slots:
		out.append(move.move_id if move != null else "?")
	return out


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
