extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/test_arena.tres"
const RandomSkirmishGenerator = preload("res://data/modules/skirmish/random_skirmish_generator.gd")
const SUPPORTED_TEAM_SIZES: Array[int] = [1, 2, 3, 4, 5]
const FIXED_SEED_TEXT: String = "777777"
const FIXED_SEED: int = 777777

var failures: int = 0


func _init() -> void:
	_check_generator_directly()
	_check_fixed_seed_is_deterministic()
	_check_different_seeds_vary()
	_check_explicit_player_vs_random_enemy()
	_check_build_random_compatibility()
	_check_invalid_inputs_rejected()

	if failures > 0:
		push_error("smoke: random_skirmish failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: random_skirmish clean")
		quit(0)


func _check_generator_directly() -> void:
	var map: MapDefinitionResource = _load_map()
	var player_team: Array[PokemonInstanceResource] = _load_team([
		_roster_path("0448_lucario"),
		_roster_path("0282_gardevoir"),
		_roster_path("0475_gallade"),
	])
	var roster: Array[PokemonInstanceResource] = _load_team(CustomSkirmishBuilder.roster_paths())
	var inputs := RandomSkirmishGenerator.GeneratorInputs.new()
	inputs.seed = FIXED_SEED
	inputs.biome = "test"
	inputs.difficulty_tier = 4
	inputs.player_party = player_team
	inputs.enemy_team_size = 3
	inputs.map_pool = [map]
	inputs.roster_templates = roster

	var definition: SkirmishDefinitionResource = RandomSkirmishGenerator.generate(inputs)
	_assert_true(definition != null, "RandomSkirmishGenerator.generate returns a definition")
	if definition == null:
		return
	_attach_spawn_orders(definition, map)
	_assert_true(definition.map == map, "direct generator picks test_arena")
	_assert_true(definition.player_team.size() == 3, "direct generator preserves explicit player party")
	_assert_true(definition.enemy_team.size() == 3, "direct generator creates requested enemy count")
	_assert_true(definition.objective == SkirmishDefinitionResource.OBJECTIVE_DEFEAT_ALL_ENEMIES, "direct generator uses defeat-all objective")
	_assert_true(String(definition.generation_metadata.get("source", "")) == "random_generator", "metadata source is random_generator")
	_assert_true(_is_unique(_species_slugs(definition.enemy_team)), "direct generator avoids duplicate enemies when roster is large enough")
	for enemy in definition.enemy_team:
		_assert_true(enemy.team == PokemonInstanceResource.Team.ENEMY, "generated enemy team is ENEMY")
		_assert_true(enemy.control_type == PokemonInstanceResource.ControlType.AI, "generated enemy control is AI")
		_assert_true(enemy.current_hp == PokemonInstanceResource.CURRENT_HP_AUTO, "generated enemy starts with fresh HP")
		_assert_true(not enemy.recruited, "generated enemy is not recruited")
		_assert_true(enemy.level >= 40 and enemy.level <= 50, "tier 4 enemy level is 40-50")
		_assert_true(not enemy.move_slots.is_empty(), "generated enemy has at least one move")
		_assert_true(enemy.pp_state.size() == enemy.move_slots.size(), "generated enemy pp_state matches moves")
	_assert_true(_loader_accepts(definition), "direct generated definition is loader-ready after spawn orders")


func _check_fixed_seed_is_deterministic() -> void:
	var a: Dictionary = CustomSkirmishBuilder.build_random(3, TEST_ARENA_MAP_PATH, FIXED_SEED_TEXT)
	var b: Dictionary = CustomSkirmishBuilder.build_random(3, TEST_ARENA_MAP_PATH, FIXED_SEED_TEXT)
	_assert_true(a.get("ok", false) and b.get("ok", false), "fixed-seed facade builds both succeed")
	if not (a.get("ok", false) and b.get("ok", false)):
		return
	var da: SkirmishDefinitionResource = a["definition"]
	var db: SkirmishDefinitionResource = b["definition"]
	_assert_true(int(a["seed"]) == int(b["seed"]), "fixed seed echoed identically")
	_assert_true(_definition_signature(da) == _definition_signature(db), "fixed seed -> identical generated definition signature")


func _check_different_seeds_vary() -> void:
	var a: Dictionary = CustomSkirmishBuilder.build_random(3, TEST_ARENA_MAP_PATH, "1001")
	var b: Dictionary = CustomSkirmishBuilder.build_random(3, TEST_ARENA_MAP_PATH, "1002")
	_assert_true(a.get("ok", false) and b.get("ok", false), "different-seed facade builds both succeed")
	if not (a.get("ok", false) and b.get("ok", false)):
		return
	var da: SkirmishDefinitionResource = a["definition"]
	var db: SkirmishDefinitionResource = b["definition"]
	_assert_true(_definition_signature(da) != _definition_signature(db), "different seeds vary species, levels, or spawn order")


func _check_explicit_player_vs_random_enemy() -> void:
	var player_team: Array[String] = [
		_roster_path("0448_lucario"),
		_roster_path("0282_gardevoir"),
	]
	var result: Dictionary = CustomSkirmishBuilder.build_with_random_enemy(
		player_team,
		TEST_ARENA_MAP_PATH,
		FIXED_SEED_TEXT,
		3,
		2
	)
	_assert_true(result.get("ok", false), "explicit player vs random enemy succeeds")
	if not result.get("ok", false):
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	_assert_true(_species_slugs(definition.player_team) == ["0448_lucario", "0282_gardevoir"], "explicit player team is preserved")
	_assert_true(definition.enemy_team.size() == 3, "random enemy helper creates requested enemy count")
	for enemy in definition.enemy_team:
		_assert_true(enemy.level >= 15 and enemy.level <= 25, "tier 2 enemy level is 15-25")
	_assert_true(_loader_accepts(definition), "explicit-vs-random definition is loader-ready")


func _check_build_random_compatibility() -> void:
	for team_size in SUPPORTED_TEAM_SIZES:
		var result: Dictionary = CustomSkirmishBuilder.build_random(team_size, TEST_ARENA_MAP_PATH, "")
		_assert_true(result.get("ok", false), "build_random(%d) succeeds" % team_size)
		if not result.get("ok", false):
			continue
		var definition: SkirmishDefinitionResource = result["definition"]
		_assert_true(definition != null, "build_random(%d) returns a definition" % team_size)
		_assert_true(definition.player_team.size() == team_size, "player team has %d members" % team_size)
		_assert_true(definition.enemy_team.size() == team_size, "enemy team has %d members" % team_size)
		_assert_true(String(definition.generation_metadata.get("source", "")) == "random_generator", "metadata marked as random_generator for %dv%d" % [team_size, team_size])
		_assert_true(String(definition.generation_metadata.get("facade_source", "")) == "build_random", "compatibility metadata marks build_random facade")


func _check_invalid_inputs_rejected() -> void:
	var zero: Dictionary = CustomSkirmishBuilder.build_random(0, TEST_ARENA_MAP_PATH, "")
	_assert_true(not zero.get("ok", false), "team size 0 is rejected")
	var too_many: Dictionary = CustomSkirmishBuilder.build_random(CustomSkirmishBuilder.MAX_TEAM_SIZE + 1, TEST_ARENA_MAP_PATH, "")
	_assert_true(not too_many.get("ok", false), "team size > %d is rejected" % CustomSkirmishBuilder.MAX_TEAM_SIZE)
	var bad_map: Dictionary = CustomSkirmishBuilder.build_random(3, "res://missing_map.tres", FIXED_SEED_TEXT)
	_assert_true(not bad_map.get("ok", false), "missing map is rejected")
	var bad_seed: Dictionary = CustomSkirmishBuilder.build_random(3, TEST_ARENA_MAP_PATH, "not a number")
	_assert_true(not bad_seed.get("ok", false), "non-numeric seed is rejected")


func _definition_signature(definition: SkirmishDefinitionResource) -> Array[String]:
	var out: Array[String] = []
	out.append(definition.map.map_id if definition.map != null else "?")
	out.append(str(definition.seed))
	out.append(",".join(_species_slugs(definition.player_team)))
	out.append(",".join(_species_slugs(definition.enemy_team)))
	out.append(",".join(_levels(definition.enemy_team)))
	out.append(",".join(_move_slugs(definition.enemy_team)))
	out.append(str(definition.generation_metadata.get("player_spawn_order", [])))
	out.append(str(definition.generation_metadata.get("enemy_spawn_order", [])))
	return out


func _attach_spawn_orders(definition: SkirmishDefinitionResource, map: MapDefinitionResource) -> void:
	var counts: Dictionary = _anchor_counts(map)
	var ok: bool = RandomSkirmishGenerator.attach_spawn_orders(
		definition,
		int(counts.get("player", 0)),
		int(counts.get("enemy", 0))
	)
	_assert_true(ok, "spawn orders attach to generated definition")


func _loader_accepts(definition: SkirmishDefinitionResource) -> bool:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	var ok: bool = level != null
	if is_instance_valid(loader):
		loader.unload_current()
		loader.queue_free()
	return ok


func _load_map() -> MapDefinitionResource:
	var map: MapDefinitionResource = load(TEST_ARENA_MAP_PATH) as MapDefinitionResource
	_assert_true(map != null, "test_arena map definition loads")
	return map


func _load_team(paths: Array[String]) -> Array[PokemonInstanceResource]:
	var out: Array[PokemonInstanceResource] = []
	for path in paths:
		var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
		if instance != null:
			out.append(instance)
	return out


func _anchor_counts(map: MapDefinitionResource) -> Dictionary:
	var counts: Dictionary = {"player": 0, "enemy": 0}
	if map == null:
		return counts
	var scene: PackedScene = load(map.scene_path) as PackedScene
	if scene == null:
		return counts
	var arena: Node = scene.instantiate()
	var spawn_points: Node = arena.get_node_or_null("SpawnPoints") if arena != null else null
	if spawn_points != null:
		for child in spawn_points.get_children():
			if not (child is Node3D):
				continue
			if _is_anchor(child.name, "SpawnPlayer"):
				counts["player"] = int(counts["player"]) + 1
			elif _is_anchor(child.name, "SpawnEnemy"):
				counts["enemy"] = int(counts["enemy"]) + 1
	if arena != null:
		arena.free()
	return counts


func _is_anchor(name: String, prefix: String) -> bool:
	if name == prefix:
		return true
	if not name.begins_with(prefix):
		return false
	var suffix: String = name.substr(prefix.length())
	return suffix.is_valid_int()


func _species_slugs(team: Array[PokemonInstanceResource]) -> Array[String]:
	var out: Array[String] = []
	for instance in team:
		out.append(instance.species.species_id if instance != null and instance.species != null else "?")
	return out


func _levels(team: Array[PokemonInstanceResource]) -> Array[String]:
	var out: Array[String] = []
	for instance in team:
		out.append(str(instance.level if instance != null else 0))
	return out


func _move_slugs(team: Array[PokemonInstanceResource]) -> Array[String]:
	var out: Array[String] = []
	for instance in team:
		var unit_moves: Array[String] = []
		if instance != null:
			for move in instance.move_slots:
				unit_moves.append(move.move_id if move != null else "?")
		out.append("|".join(unit_moves))
	return out


func _roster_path(slug: String) -> String:
	return "%s%s.tres" % [CustomSkirmishBuilder.ROSTER_DIR, slug]


func _is_unique(values: Array) -> bool:
	var seen: Dictionary = {}
	for value in values:
		if seen.has(value):
			return false
		seen[value] = true
	return true


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
