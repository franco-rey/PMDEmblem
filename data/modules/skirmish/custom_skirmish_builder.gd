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
const MAP_DIR: String = "res://data/models/maps/definitions/"
const MIN_TEAM_SIZE: int = 1
const MAX_TEAM_SIZE: int = 8
## Each side draws its placement candidates from the first N anchors after the
## loader's sort. M4 R1 hard-caps this at 8 per side so 8v8 customs can lay out.
const ANCHOR_POOL_SIZE: int = 8
const ROSTER_SLUGS: Array[String] = [
	"gallade",
	"lucario",
	"gardevoir",
	"toxicroak",
	"magmortar",
	"gengar",
	"dusclops",
]


## Returns the canonical roster path list in the order the picker should display.
static func roster_paths() -> Array[String]:
	var out: Array[String] = []
	for slug in ROSTER_SLUGS:
		out.append("%s%s.tres" % [ROSTER_DIR, slug])
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
	var out: Array[int] = []
	if team_size <= 0 or pool_size <= 0:
		return out
	var pool: Array[int] = []
	for i in range(pool_size):
		pool.append(i)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	# Fisher-Yates shuffle so the permutation is uniform and the RNG handle is
	# the only source of randomness (matches `combat_model.md`'s determinism
	# contract: same seed -> same shuffle).
	for i in range(pool.size() - 1, 0, -1):
		var j: int = int(rng.randi_range(0, i))
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for i in range(team_size):
		out.append(pool[i])
	return out


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

	var player_team: Array[PokemonInstanceResource] = _load_team(player_paths)
	var enemy_team: Array[PokemonInstanceResource] = _load_team(enemy_paths)
	if player_team.size() != player_paths.size() or enemy_team.size() != enemy_paths.size():
		return {"ok": false, "error": "One or more instance files could not load"}

	var seed: int = resolve_seed(seed_text)
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


static func _load_team(paths: Array[String]) -> Array[PokemonInstanceResource]:
	var out: Array[PokemonInstanceResource] = []
	for path in paths:
		var instance: PokemonInstanceResource = load(path) as PokemonInstanceResource
		if instance == null:
			push_error("CustomSkirmishBuilder: could not load instance %s" % path)
			continue
		out.append(instance)
	return out


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
