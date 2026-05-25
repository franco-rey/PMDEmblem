class_name CustomSkirmishBuilder
extends RefCounted
## M4 R1 builder for transient `SkirmishDefinitionResource`s.
##
## The main-menu inline UI and the M4 R1 smoke test share this helper so the
## player path and the headless validation path produce byte-identical results
## for the same seed + team + map inputs. The class is intentionally pure
## (no scene-tree access): it lists roster / map paths, validates user input,
## and shuffles spawn anchors with a seeded RNG.

const ROSTER_DIR: String = "res://data/models/pokemon/overrides/instances/"
const GENERATED_ROSTER_DIR: String = "res://data/models/pokemon/generated/instances/"
const MAP_DIR: String = "res://data/models/maps/definitions/"
const RandomSkirmishGenerator = preload("res://data/modules/skirmish/random_skirmish_generator.gd")
const MIN_TEAM_SIZE: int = 1
const MAX_TEAM_SIZE: int = 8
## Each side draws its placement candidates from the first N anchors after the
## loader's sort. M4 R1 hard-caps this at 8 per side so 8v8 customs can lay out.
const ANCHOR_POOL_SIZE: int = 8
const ROSTER_SLUGS: Array[String] = [
	"0475_gallade",
	"0448_lucario",
	"0282_gardevoir",
	"0454_toxicroak",
	"0467_magmortar",
	"0094_gengar",
	"0356_dusclops",
]
const DEFAULT_RANDOM_DIFFICULTY_TIER: int = 4


## Returns the canonical roster path list in the order the picker should display.
static func roster_paths() -> Array[String]:
	var by_slug: Dictionary = {}
	for path in _discover_roster_paths(GENERATED_ROSTER_DIR):
		by_slug[path.get_file().get_basename()] = path
	for path in _discover_roster_paths(ROSTER_DIR):
		# Hand-authored overrides shadow generated templates with the same slug.
		by_slug[path.get_file().get_basename()] = path

	var out: Array[String] = []
	for slug in ROSTER_SLUGS:
		if by_slug.has(slug):
			var path: String = String(by_slug[slug])
			out.append(path)
			by_slug.erase(slug)
	var remaining: Array[String] = []
	for slug in by_slug.keys():
		remaining.append(String(slug))
	remaining.sort()
	for slug in remaining:
		out.append(String(by_slug[slug]))
	return out


static func battle_ready_roster_paths() -> Array[String]:
	var out: Array[String] = []
	for path in roster_paths():
		if _is_battle_ready_path(path):
			out.append(path)
	return out


## Returns every `MapDefinitionResource` file currently under `MAP_DIR`,
## sorted by file name so the picker is deterministic across milestones.
static func map_paths() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(MAP_DIR)
	if dir == null:
		push_error("CustomSkirmishBuilder: cannot open %s" % MAP_DIR)
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			out.append("%s%s" % [MAP_DIR, name])
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


## Parses the user-supplied seed text.
##
## Empty input means "generate a fresh random seed". `Time.get_ticks_usec()`
## is good enough for non-cryptographic determinism + replay needs in M4 R1;
## the resolved seed is echoed back to the caller so it can be displayed and
## reused for replay.
static func resolve_seed(text: String) -> int:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return _generate_seed()
	if not trimmed.is_valid_int():
		return 0
	return int(trimmed)


static func _generate_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	# Constrain to a positive 31-bit range so the seed prints cleanly and so
	# `SkirmishDefinitionResource.seed`'s int stays well away from any negative
	# sentinels callers might introduce later.
	return int(rng.randi() & 0x7FFFFFFF)


## Builds the index permutation used to assign team members to spawn anchors.
##
## Given an integer `seed`, the same `(seed, team_size, pool_size)` always
## produces the same `Array[int]` of unique anchor indices in `[0, pool_size)`.
## `team_size` must be <= `pool_size`.
static func build_spawn_order(seed: int, team_size: int, pool_size: int) -> Array[int]:
	return RandomSkirmishGenerator.build_spawn_order(seed, team_size, pool_size)


## Constructs a transient `SkirmishDefinitionResource` ready for the loader.
##
## Returns a `Dictionary` with one of:
##   - `{"ok": true, "definition": SkirmishDefinitionResource, "seed": int}`
##   - `{"ok": false, "error": String}`
##
## The caller is responsible for showing the error and for passing
## `definition` to `SkirmishLoader.load_skirmish()`. The builder does not
## touch the scene tree.
static func build(player_paths: Array[String], enemy_paths: Array[String], map_path: String, seed_text: String) -> Dictionary:
	if player_paths.size() < MIN_TEAM_SIZE or player_paths.size() > MAX_TEAM_SIZE:
		return {"ok": false, "error": "Player team must be %d-%d Pokemon" % [MIN_TEAM_SIZE, MAX_TEAM_SIZE]}
	if enemy_paths.size() < MIN_TEAM_SIZE or enemy_paths.size() > MAX_TEAM_SIZE:
		return {"ok": false, "error": "Enemy team must be %d-%d Pokemon" % [MIN_TEAM_SIZE, MAX_TEAM_SIZE]}
	if map_path.is_empty():
		return {"ok": false, "error": "Select a map"}
	if not seed_text.strip_edges().is_empty() and not seed_text.strip_edges().is_valid_int():
		return {"ok": false, "error": "Seed must be an integer or empty"}
	if not ResourceLoader.exists(map_path):
		return {"ok": false, "error": "Could not load map %s" % map_path}

	var map: MapDefinitionResource = load(map_path) as MapDefinitionResource
	if map == null:
		return {"ok": false, "error": "Could not load map %s" % map_path}

	var anchor_counts: Dictionary = _count_map_anchors(map)
	if anchor_counts.get("player", 0) < player_paths.size():
		return {"ok": false, "error": "Map has %d player anchors; need %d" % [anchor_counts.get("player", 0), player_paths.size()]}
	if anchor_counts.get("enemy", 0) < enemy_paths.size():
		return {"ok": false, "error": "Map has %d enemy anchors; need %d" % [anchor_counts.get("enemy", 0), enemy_paths.size()]}

	var player_pool: int = mini(anchor_counts.get("player", 0), ANCHOR_POOL_SIZE)
	var enemy_pool: int = mini(anchor_counts.get("enemy", 0), ANCHOR_POOL_SIZE)
	if player_pool < player_paths.size() or enemy_pool < enemy_paths.size():
		return {"ok": false, "error": "Map needs %d anchors per side for an %dv%d setup" % [ANCHOR_POOL_SIZE, player_paths.size(), enemy_paths.size()]}

	var seed: int = resolve_seed(seed_text)
	var player_team: Array[PokemonInstanceResource] = _load_team_for_side(player_paths, PokemonInstanceResource.Team.PLAYER, PokemonInstanceResource.ControlType.PLAYER, seed, "player")
	var enemy_team: Array[PokemonInstanceResource] = _load_team_for_side(enemy_paths, PokemonInstanceResource.Team.ENEMY, PokemonInstanceResource.ControlType.AI, seed, "enemy")
	if player_team.size() != player_paths.size() or enemy_team.size() != enemy_paths.size():
		return {"ok": false, "error": "One or more instance files could not load"}

	var player_order: Array[int] = build_spawn_order(seed, player_team.size(), player_pool)
	var enemy_order: Array[int] = build_spawn_order(seed ^ 0x5A5A5A5A, enemy_team.size(), enemy_pool)

	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "custom_%d" % seed
	definition.display_name = "Custom Skirmish"
	definition.map = map
	definition.seed = seed
	definition.player_team = player_team
	definition.enemy_team = enemy_team
	definition.objective = SkirmishDefinitionResource.OBJECTIVE_DEFEAT_ALL_ENEMIES
	definition.generation_metadata = {
		"source": "custom_builder",
		"player_spawn_order": player_order,
		"enemy_spawn_order": enemy_order,
		"player_roster": player_paths,
		"enemy_roster": enemy_paths,
		"map_path": map_path,
	}
	return {"ok": true, "definition": definition, "seed": seed}


## Picks `count` roster Pokemon at random (with replacement, matching the
## explicit-builder's duplicate-allowed contract). `seed` drives the choice
## deterministically; pass `0` to draw a fresh non-deterministic sample.
static func random_roster_paths(count: int, seed: int = 0) -> Array[String]:
	var out: Array[String] = []
	var pool: Array[String] = battle_ready_roster_paths()
	if count <= 0 or pool.is_empty():
		return out
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	var allow_duplicates: bool = count > pool.size()
	var available: Array[String] = pool.duplicate()
	for i in range(count):
		if available.is_empty():
			if not allow_duplicates:
				break
			available = pool.duplicate()
		var pick_index: int = int(rng.randi_range(0, available.size() - 1))
		out.append(available[pick_index])
		if not allow_duplicates:
			available.remove_at(pick_index)
	return out


## Builds an NvN skirmish whose teams are rolled fresh each call.
##
## A non-empty `seed_text` makes both team picks AND spawn placement
## reproducible (different XOR masks keep player/enemy rolls independent).
## Returns the same `{"ok"/"error" + definition + seed}` shape as `build`.
static func build_random(team_size: int, map_path: String, seed_text: String = "") -> Dictionary:
	if team_size < MIN_TEAM_SIZE or team_size > MAX_TEAM_SIZE:
		return {"ok": false, "error": "Team size must be %d-%d" % [MIN_TEAM_SIZE, MAX_TEAM_SIZE]}
	if not seed_text.strip_edges().is_empty() and not seed_text.strip_edges().is_valid_int():
		return {"ok": false, "error": "Seed must be an integer or empty"}
	var seed: int = resolve_seed(seed_text)
	var player_paths: Array[String] = random_roster_paths(team_size, seed ^ 0x1234ABCD)
	var result: Dictionary = build_with_random_enemy(
		player_paths,
		map_path,
		String.num_int64(seed),
		team_size,
		DEFAULT_RANDOM_DIFFICULTY_TIER
	)
	if result.get("ok", false):
		var definition: SkirmishDefinitionResource = result["definition"]
		definition.skirmish_id = "random_%dv%d_%d" % [team_size, team_size, seed]
		definition.display_name = "Random %dv%d" % [team_size, team_size]
		var meta: Dictionary = definition.generation_metadata.duplicate(true)
		meta["facade_source"] = "build_random"
		meta["team_size"] = team_size
		meta["player_roster"] = player_paths
		definition.generation_metadata = meta
	return result


## Builds a skirmish with an explicit player team and generated enemy team.
##
## This is the M5 compatibility surface that M5.5 and M7 can reuse without
## depending on main-menu controls. The explicit player team keeps the same
## duplicate-allowed contract as `build`; generated enemies avoid duplicates
## while the requested size fits the roster.
static func build_with_random_enemy(
	player_paths: Array[String],
	map_path: String,
	seed_text: String = "",
	enemy_team_size: int = 0,
	difficulty_tier: int = DEFAULT_RANDOM_DIFFICULTY_TIER,
	biome: String = "",
	reward_profile: String = ""
) -> Dictionary:
	if player_paths.size() < MIN_TEAM_SIZE or player_paths.size() > MAX_TEAM_SIZE:
		return {"ok": false, "error": "Player team must be %d-%d Pokemon" % [MIN_TEAM_SIZE, MAX_TEAM_SIZE]}
	var resolved_enemy_size: int = enemy_team_size if enemy_team_size > 0 else player_paths.size()
	if resolved_enemy_size < MIN_TEAM_SIZE or resolved_enemy_size > MAX_TEAM_SIZE:
		return {"ok": false, "error": "Enemy team size must be %d-%d" % [MIN_TEAM_SIZE, MAX_TEAM_SIZE]}
	if map_path.is_empty():
		return {"ok": false, "error": "Select a map"}
	if not seed_text.strip_edges().is_empty() and not seed_text.strip_edges().is_valid_int():
		return {"ok": false, "error": "Seed must be an integer or empty"}
	if not ResourceLoader.exists(map_path):
		return {"ok": false, "error": "Could not load map %s" % map_path}

	var map: MapDefinitionResource = load(map_path) as MapDefinitionResource
	if map == null:
		return {"ok": false, "error": "Could not load map %s" % map_path}

	var anchor_counts: Dictionary = _count_map_anchors(map)
	if anchor_counts.get("player", 0) < player_paths.size():
		return {"ok": false, "error": "Map has %d player anchors; need %d" % [anchor_counts.get("player", 0), player_paths.size()]}
	if anchor_counts.get("enemy", 0) < resolved_enemy_size:
		return {"ok": false, "error": "Map has %d enemy anchors; need %d" % [anchor_counts.get("enemy", 0), resolved_enemy_size]}

	var seed: int = resolve_seed(seed_text)
	var player_team: Array[PokemonInstanceResource] = _load_team_for_side(player_paths, PokemonInstanceResource.Team.PLAYER, PokemonInstanceResource.ControlType.PLAYER, seed, "player")
	if player_team.size() != player_paths.size():
		return {"ok": false, "error": "One or more player instance files could not load"}

	var roster_templates: Array[PokemonInstanceResource] = _load_team(battle_ready_roster_paths())
	if roster_templates.is_empty():
		return {"ok": false, "error": "No roster Pokemon available"}

	var inputs := RandomSkirmishGenerator.GeneratorInputs.new()
	inputs.seed = seed
	inputs.biome = biome
	inputs.difficulty_tier = difficulty_tier
	inputs.player_party = player_team
	inputs.enemy_team_size = resolved_enemy_size
	inputs.enemy_budget = 0
	inputs.map_pool = [map]
	inputs.roster_templates = roster_templates
	inputs.reward_profile = reward_profile

	var definition: SkirmishDefinitionResource = RandomSkirmishGenerator.generate(inputs)
	if definition == null:
		return {"ok": false, "error": "Random skirmish generation failed"}

	var player_pool: int = mini(anchor_counts.get("player", 0), ANCHOR_POOL_SIZE)
	var enemy_pool: int = mini(anchor_counts.get("enemy", 0), ANCHOR_POOL_SIZE)
	if not RandomSkirmishGenerator.attach_spawn_orders(definition, player_pool, enemy_pool, ANCHOR_POOL_SIZE):
		return {"ok": false, "error": "Could not assign spawn anchors for generated skirmish"}

	var meta: Dictionary = definition.generation_metadata.duplicate(true)
	meta["player_roster"] = player_paths
	meta["map_path"] = map_path
	definition.generation_metadata = meta
	return {"ok": true, "definition": definition, "seed": seed}


static func _load_team(paths: Array[String]) -> Array[PokemonInstanceResource]:
	var out: Array[PokemonInstanceResource] = []
	for path in paths:
		var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
		if instance == null:
			push_error("CustomSkirmishBuilder: could not load instance %s" % path)
			continue
		out.append(instance)
	return out


static func _load_team_for_side(paths: Array[String], team: int, control_type: int, seed: int = 0, side_key: String = "team") -> Array[PokemonInstanceResource]:
	var out: Array[PokemonInstanceResource] = []
	var slot_index: int = 0
	for path in paths:
		var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
		if instance == null:
			push_error("CustomSkirmishBuilder: could not load instance %s" % path)
			continue
		out.append(SkirmishMoveLoadout.clone_with_loadout(instance, team, control_type, seed, side_key, slot_index))
		slot_index += 1
	return out


static func _clone_instance_for_side(template: PokemonInstanceResource, team: int, control_type: int) -> PokemonInstanceResource:
	return SkirmishMoveLoadout.clone_for_side(template, team, control_type)


static func _discover_roster_paths(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			out.append("%s%s" % [dir_path, name])
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func _is_battle_ready_path(path: String) -> bool:
	var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
	if instance == null or instance.species == null:
		return false
	var form: PokemonFormResource = instance.resolved_form()
	if form == null or form.sprite_set == null or not form.sprite_set.is_complete():
		return false
	if instance.move_slots.is_empty():
		return false
	for move in instance.move_slots:
		if move != null:
			return true
	return false


## Walks the map's scene and counts `SpawnPlayer*` / `SpawnEnemy*` anchors
## using the same `prefix + optional integer suffix` rule the loader applies
## at spawn time. Instantiating the scene is the most reliable read across
## inherited / packed scenes; the temporary instance is freed before returning.
static func _count_map_anchors(map: MapDefinitionResource) -> Dictionary:
	var counts: Dictionary = {"player": 0, "enemy": 0}
	if map == null or map.scene_path.is_empty():
		return counts
	var scene: PackedScene = load(map.scene_path) as PackedScene
	if scene == null:
		push_error("CustomSkirmishBuilder: cannot load map scene %s" % map.scene_path)
		return counts
	var arena: Node = scene.instantiate()
	if arena == null:
		push_error("CustomSkirmishBuilder: cannot instantiate map scene %s" % map.scene_path)
		return counts
	var spawn_points: Node = arena.get_node_or_null("SpawnPoints")
	if spawn_points != null:
		for child in spawn_points.get_children():
			if not (child is Node3D):
				continue
			if _is_anchor(child.name, "SpawnPlayer"):
				counts["player"] = int(counts["player"]) + 1
			elif _is_anchor(child.name, "SpawnEnemy"):
				counts["enemy"] = int(counts["enemy"]) + 1
	arena.free()
	return counts


static func _is_anchor(name: String, prefix: String) -> bool:
	if name == prefix:
		return true
	if not name.begins_with(prefix):
		return false
	var suffix: String = name.substr(prefix.length())
	return suffix.is_valid_int()
