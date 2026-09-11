extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const ROSTER_DIR: String = "res://data/models/pokemon/overrides/instances/"
const EXPECTED_ROSTER: Array[String] = [
	"0475_gallade",
	"0448_lucario",
	"0282_gardevoir",
	"0454_toxicroak",
	"0467_magmortar",
	"0094_gengar",
	"0356_dusclops",
]
const FIXED_SEED: int = 424242
const ANCHOR_POOL_SIZE: int = 16

var failures: int = 0


func _init() -> void:
	await _check_main_scene_controls()
	_check_builder_static_listings()
	_check_chessboard_anchor_count()
	await _check_build_1v1()
	_check_control_modes()
	await _check_build_8v8_with_duplicates()
	await _check_determinism_same_seed()
	_check_empty_seed_resolves()
	_check_invalid_seed_rejected()

	if failures > 0:
		push_error("smoke: custom_skirmish failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: custom_skirmish clean")
		quit(0)


func _check_main_scene_controls() -> void:
	var scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	_assert_true(scene != null, "main scene loads")
	if scene == null:
		return
	var instance: Node = scene.instantiate()
	if instance == null:
		_fail("main scene instantiates")
		return
	root.add_child(instance)
	await process_frame

	_assert_true(instance.get_node_or_null("UI/MapSelector/SkirmishMenu/SkirmishPicker") != null, "main scene keeps premade SkirmishPicker")
	_assert_true(instance.get_node_or_null("UI/MapSelector/SkirmishMenu/LaunchButton") != null, "main scene keeps premade LaunchButton")

	var toggle: Button = instance.get_node_or_null("UI/MapSelector/SkirmishMenu/CustomToggleButton") as Button
	var lobby: Control = instance.get_node_or_null("UI/SkirmishLobby") as Control
	var map_selector: Control = instance.get_node_or_null("UI/MapSelector") as Control
	_assert_true(toggle != null, "main scene has CustomToggleButton")
	_assert_true(lobby != null, "main scene has dedicated SkirmishLobby")
	_assert_true(lobby != null and not lobby.visible, "SkirmishLobby is hidden by default")
	if toggle != null and lobby != null and map_selector != null:
		toggle.emit_signal("pressed")
		await process_frame
		_assert_true(lobby.visible, "CustomToggleButton press opens SkirmishLobby")
		_assert_true(not map_selector.visible, "opening SkirmishLobby hides the compact menu")
		_assert_true(lobby.get_roster_entries().size() >= EXPECTED_ROSTER.size(), "SkirmishLobby sees at least %d roster entries" % EXPECTED_ROSTER.size())

	instance.queue_free()
	await process_frame


func _check_builder_static_listings() -> void:
	var roster: Array[String] = CustomSkirmishBuilder.roster_paths()
	_assert_true(roster.size() >= EXPECTED_ROSTER.size(), "roster_paths returns at least %d entries" % EXPECTED_ROSTER.size())
	for i in range(EXPECTED_ROSTER.size()):
		var slug: String = EXPECTED_ROSTER[i]
		var expected_path: String = "%s%s.tres" % [ROSTER_DIR, slug]
		_assert_true(roster.has(expected_path), "roster_paths includes %s" % slug)
		_assert_true(i < roster.size() and roster[i] == expected_path, "roster_paths keeps %s in canonical display order" % slug)
		var instance: PokemonInstanceResource = load(expected_path) as PokemonInstanceResource
		_assert_true(instance != null, "%s.tres loads as PokemonInstanceResource" % slug)

	var maps: Array[String] = CustomSkirmishBuilder.map_paths()
	_assert_true(maps.has(TEST_ARENA_MAP_PATH), "map_paths includes the chessboard")


func _check_chessboard_anchor_count() -> void:
	var map: MapDefinitionResource = load(TEST_ARENA_MAP_PATH) as MapDefinitionResource
	if map == null:
		_fail("chessboard MapDefinitionResource loads")
		return
	var scene: PackedScene = load(map.scene_path) as PackedScene
	if scene == null:
		_fail("chessboard scene loads")
		return
	var arena: Node = scene.instantiate()
	if arena == null:
		_fail("chessboard scene instantiates")
		return
	var spawn_points: Node = arena.get_node_or_null("SpawnPoints")
	var player_count: int = 0
	var enemy_count: int = 0
	if spawn_points != null:
		for child in spawn_points.get_children():
			if not (child is Node3D):
				continue
			if _is_anchor(child.name, "SpawnPlayer"):
				player_count += 1
			elif _is_anchor(child.name, "SpawnEnemy"):
				enemy_count += 1
	arena.free()
	_assert_true(player_count >= ANCHOR_POOL_SIZE, "chessboard has >= %d SpawnPlayer anchors (got %d)" % [ANCHOR_POOL_SIZE, player_count])
	_assert_true(enemy_count >= ANCHOR_POOL_SIZE, "chessboard has >= %d SpawnEnemy anchors (got %d)" % [ANCHOR_POOL_SIZE, enemy_count])


func _check_build_1v1() -> void:
	var player_team: Array[String] = [_roster_path("0448_lucario")]
	var enemy_team: Array[String] = [_roster_path("0467_magmortar")]
	var result: Dictionary = CustomSkirmishBuilder.build(player_team, enemy_team, TEST_ARENA_MAP_PATH, str(FIXED_SEED))
	_assert_true(result.get("ok", false), "1v1 build returns ok=true (error=%s)" % result.get("error", ""))
	if not result.get("ok", false):
		return
	var definition: SkirmishDefinitionResource = result["definition"] as SkirmishDefinitionResource
	_assert_true(definition != null, "1v1 build returns a SkirmishDefinitionResource")
	_assert_true(definition.skirmish_id == "custom_%d" % FIXED_SEED, "1v1 skirmish_id is custom_<seed>")
	_assert_true(definition.seed == FIXED_SEED, "1v1 seed matches input")
	_assert_true(definition.player_team.size() == 1, "1v1 player_team size is 1")
	_assert_true(definition.enemy_team.size() == 1, "1v1 enemy_team size is 1")
	_assert_true(definition.objective == SkirmishDefinitionResource.OBJECTIVE_DEFEAT_ALL_ENEMIES, "1v1 objective is defeat-all")
	_assert_true(definition.generation_metadata.get("source", "") == "custom_builder", "1v1 generation_metadata.source is custom_builder")

	var loaded: Dictionary = _load_into_scene(definition)
	var loader: SkirmishLoader = loaded.get("loader") as SkirmishLoader
	var level: TacticsLevel = loaded.get("level") as TacticsLevel
	_assert_true(level != null, "1v1 SkirmishLoader accepts the transient definition")
	if level != null:
		_assert_true(_count_pawns(level) == 2, "1v1 spawns 2 pawns")
		var player_anchors: Array[int] = _anchors_used(level, "TacticsParticipant/TacticsPlayer", "SpawnPlayer")
		var enemy_anchors: Array[int] = _anchors_used(level, "TacticsParticipant/TacticsOpponent", "SpawnEnemy")
		_assert_true(player_anchors.size() == 1, "1v1 player pawn lands on exactly one anchor")
		_assert_true(enemy_anchors.size() == 1, "1v1 enemy pawn lands on exactly one anchor")
		_assert_true(player_anchors.is_empty() or player_anchors[0] < ANCHOR_POOL_SIZE, "1v1 player anchor is inside the first %d" % ANCHOR_POOL_SIZE)
		_assert_true(enemy_anchors.is_empty() or enemy_anchors[0] < ANCHOR_POOL_SIZE, "1v1 enemy anchor is inside the first %d" % ANCHOR_POOL_SIZE)
		_cleanup(loader)


func _check_control_modes() -> void:
	var player_team: Array[String] = [_roster_path("0448_lucario")]
	var enemy_team: Array[String] = [_roster_path("0467_magmortar")]
	var expectations: Dictionary = {
		SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU: [PokemonInstanceResource.ControlType.PLAYER, PokemonInstanceResource.ControlType.AI],
		SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER: [PokemonInstanceResource.ControlType.PLAYER, PokemonInstanceResource.ControlType.PLAYER],
		SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU: [PokemonInstanceResource.ControlType.AI, PokemonInstanceResource.ControlType.AI],
	}
	for mode in expectations.keys():
		var result: Dictionary = CustomSkirmishBuilder.build(player_team, enemy_team, TEST_ARENA_MAP_PATH, str(FIXED_SEED), String(mode))
		_assert_true(result.get("ok", false), "custom build supports control mode %s" % mode)
		if not result.get("ok", false):
			continue
		var definition: SkirmishDefinitionResource = result["definition"]
		var expected: Array = expectations[mode]
		_assert_true(definition.control_mode == String(mode), "custom definition records control mode %s" % mode)
		_assert_true(String(definition.generation_metadata.get("control_mode", "")) == String(mode), "custom metadata records control mode %s" % mode)
		_assert_true(_all_controlled_by(definition.player_team, int(expected[0])), "custom player team control for %s" % mode)
		_assert_true(_all_controlled_by(definition.enemy_team, int(expected[1])), "custom enemy team control for %s" % mode)


func _check_build_8v8_with_duplicates() -> void:
	var player_team: Array[String] = [
		_roster_path("0448_lucario"),
		_roster_path("0448_lucario"),
		_roster_path("0282_gardevoir"),
		_roster_path("0282_gardevoir"),
		_roster_path("0475_gallade"),
		_roster_path("0475_gallade"),
		_roster_path("0454_toxicroak"),
		_roster_path("0454_toxicroak"),
	]
	var enemy_team: Array[String] = [
		_roster_path("0467_magmortar"),
		_roster_path("0467_magmortar"),
		_roster_path("0094_gengar"),
		_roster_path("0094_gengar"),
		_roster_path("0356_dusclops"),
		_roster_path("0356_dusclops"),
		_roster_path("0448_lucario"),
		_roster_path("0282_gardevoir"),
	]
	var result: Dictionary = CustomSkirmishBuilder.build(player_team, enemy_team, TEST_ARENA_MAP_PATH, str(FIXED_SEED))
	_assert_true(result.get("ok", false), "8v8 build returns ok=true (error=%s)" % result.get("error", ""))
	if not result.get("ok", false):
		return
	var definition: SkirmishDefinitionResource = result["definition"] as SkirmishDefinitionResource
	_assert_true(definition.player_team.size() == 8, "8v8 player_team size is 8 (duplicates kept)")
	_assert_true(definition.enemy_team.size() == 8, "8v8 enemy_team size is 8 (duplicates kept)")

	var player_order: Array = definition.generation_metadata.get("player_spawn_order", [])
	var enemy_order: Array = definition.generation_metadata.get("enemy_spawn_order", [])
	_assert_true(_is_unique(player_order) and player_order.size() == 8, "8v8 player_spawn_order has 8 unique anchor indices")
	_assert_true(_is_unique(enemy_order) and enemy_order.size() == 8, "8v8 enemy_spawn_order has 8 unique anchor indices")
	_assert_true(_max_index(player_order) < ANCHOR_POOL_SIZE, "8v8 player anchors stay inside the first %d" % ANCHOR_POOL_SIZE)
	_assert_true(_max_index(enemy_order) < ANCHOR_POOL_SIZE, "8v8 enemy anchors stay inside the first %d" % ANCHOR_POOL_SIZE)

	var loaded: Dictionary = _load_into_scene(definition)
	var loader: SkirmishLoader = loaded.get("loader") as SkirmishLoader
	var level: TacticsLevel = loaded.get("level") as TacticsLevel
	_assert_true(level != null, "8v8 SkirmishLoader accepts the transient definition")
	if level != null:
		_assert_true(_count_pawns(level) == 16, "8v8 spawns 16 pawns")
		var player_anchors: Array[int] = _anchors_used(level, "TacticsParticipant/TacticsPlayer", "SpawnPlayer")
		var enemy_anchors: Array[int] = _anchors_used(level, "TacticsParticipant/TacticsOpponent", "SpawnEnemy")
		_assert_true(player_anchors.size() == 8 and _is_unique(player_anchors), "8v8 player pawns occupy 8 unique SpawnPlayer anchors")
		_assert_true(enemy_anchors.size() == 8 and _is_unique(enemy_anchors), "8v8 enemy pawns occupy 8 unique SpawnEnemy anchors")
	_cleanup(loader)


func _check_determinism_same_seed() -> void:
	var player_team: Array[String] = [
		_roster_path("0448_lucario"),
		_roster_path("0282_gardevoir"),
		_roster_path("0475_gallade"),
	]
	var enemy_team: Array[String] = [
		_roster_path("0467_magmortar"),
		_roster_path("0094_gengar"),
		_roster_path("0356_dusclops"),
	]
	var first: Dictionary = CustomSkirmishBuilder.build(player_team, enemy_team, TEST_ARENA_MAP_PATH, str(FIXED_SEED))
	var second: Dictionary = CustomSkirmishBuilder.build(player_team, enemy_team, TEST_ARENA_MAP_PATH, str(FIXED_SEED))
	if not (first.get("ok", false) and second.get("ok", false)):
		_fail("determinism builds both succeed")
		return
	var first_def: SkirmishDefinitionResource = first["definition"]
	var second_def: SkirmishDefinitionResource = second["definition"]
	var first_player_order: Array = first_def.generation_metadata.get("player_spawn_order", [])
	var second_player_order: Array = second_def.generation_metadata.get("player_spawn_order", [])
	var first_enemy_order: Array = first_def.generation_metadata.get("enemy_spawn_order", [])
	var second_enemy_order: Array = second_def.generation_metadata.get("enemy_spawn_order", [])
	_assert_true(first_player_order == second_player_order, "same seed -> same player_spawn_order")
	_assert_true(first_enemy_order == second_enemy_order, "same seed -> same enemy_spawn_order")
	_assert_true(_team_species(first_def.player_team) == _team_species(second_def.player_team), "same seed -> same player team composition")
	_assert_true(_team_species(first_def.enemy_team) == _team_species(second_def.enemy_team), "same seed -> same enemy team composition")

	var first_signature: Array[String] = await _signature_for(first_def)
	var second_signature: Array[String] = await _signature_for(second_def)
	_assert_true(first_signature == second_signature, "same seed -> same loader spawn positions")

	var other: Dictionary = CustomSkirmishBuilder.build(player_team, enemy_team, TEST_ARENA_MAP_PATH, str(FIXED_SEED + 1))
	if other.get("ok", false):
		var other_def: SkirmishDefinitionResource = other["definition"]
		var other_player_order: Array = other_def.generation_metadata.get("player_spawn_order", [])
		var other_enemy_order: Array = other_def.generation_metadata.get("enemy_spawn_order", [])
		_assert_true(other_player_order != first_player_order or other_enemy_order != first_enemy_order, "different seed -> different spawn-anchor assignment")


func _check_empty_seed_resolves() -> void:
	var seed: int = CustomSkirmishBuilder.resolve_seed("")
	_assert_true(seed > 0, "empty seed resolves to a positive integer")
	var seed_again: int = CustomSkirmishBuilder.resolve_seed("")
	_assert_true(seed != seed_again or seed > 0, "empty seed resolves repeatedly without crashing")

	var player_team: Array[String] = [_roster_path("0448_lucario")]
	var enemy_team: Array[String] = [_roster_path("0467_magmortar")]
	var result: Dictionary = CustomSkirmishBuilder.build(player_team, enemy_team, TEST_ARENA_MAP_PATH, "")
	_assert_true(result.get("ok", false), "empty seed build returns ok=true")
	if result.get("ok", false):
		_assert_true(int(result.get("seed", 0)) > 0, "empty seed build echoes a positive integer seed back to caller")


func _check_invalid_seed_rejected() -> void:
	var player_team: Array[String] = [_roster_path("0448_lucario")]
	var enemy_team: Array[String] = [_roster_path("0467_magmortar")]
	var bad: Dictionary = CustomSkirmishBuilder.build(player_team, enemy_team, TEST_ARENA_MAP_PATH, "not a number")
	_assert_true(not bad.get("ok", true), "non-numeric seed text is rejected")

	var too_few: Dictionary = CustomSkirmishBuilder.build([], enemy_team, TEST_ARENA_MAP_PATH, str(FIXED_SEED))
	_assert_true(not too_few.get("ok", true), "empty player team is rejected")

	var too_many_player: Array[String] = []
	for i in range(CustomSkirmishBuilder.max_team_size_for(TEST_ARENA_MAP_PATH) + 1):
		too_many_player.append(_roster_path("0448_lucario"))
	var too_many: Dictionary = CustomSkirmishBuilder.build(too_many_player, enemy_team, TEST_ARENA_MAP_PATH, str(FIXED_SEED))
	_assert_true(not too_many.get("ok", true), "player team past the map cap is rejected")


func _signature_for(definition: SkirmishDefinitionResource) -> Array[String]:
	var loaded: Dictionary = _load_into_scene(definition)
	var loader: SkirmishLoader = loaded.get("loader") as SkirmishLoader
	var level: TacticsLevel = loaded.get("level") as TacticsLevel
	var out: Array[String] = []
	if level != null:
		out = _position_signature(level)
	_cleanup(loader)
	return out


func _load_into_scene(definition: SkirmishDefinitionResource) -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	return {"loader": loader, "level": level}


func _cleanup(loader: SkirmishLoader) -> void:
	if loader != null:
		loader.unload_current()
		loader.queue_free()
	await process_frame


func _count_pawns(level: TacticsLevel) -> int:
	var n: int = 0
	var participant: Node = level.get_node("TacticsParticipant")
	for team_node in participant.get_children():
		for child in team_node.get_children():
			if child is TacticsPawn:
				n += 1
	return n


func _anchors_used(level: TacticsLevel, team_path: String, prefix: String) -> Array[int]:
	var anchors: Array[Node3D] = _collect_spawn_anchors(level.get_node("TacticsArena"), prefix)
	var parent: Node = level.get_node(team_path)
	var out: Array[int] = []
	for child in parent.get_children():
		if not (child is TacticsPawn):
			continue
		var pawn: TacticsPawn = child as TacticsPawn
		var pawn_pos: Vector3 = _local_transform_to(pawn, level).origin
		var best_idx: int = -1
		var best_dist: float = INF
		for i in range(anchors.size()):
			var anchor_pos: Vector3 = _local_transform_to(anchors[i], level).origin
			var d: float = pawn_pos.distance_to(anchor_pos)
			if d < best_dist:
				best_dist = d
				best_idx = i
		if best_idx >= 0 and best_dist <= 0.2:
			out.append(best_idx)
	return out


func _position_signature(level: TacticsLevel) -> Array[String]:
	var out: Array[String] = []
	for team_path in ["TacticsParticipant/TacticsPlayer", "TacticsParticipant/TacticsOpponent"]:
		var parent: Node = level.get_node(team_path)
		for child in parent.get_children():
			if child is TacticsPawn:
				var pawn: TacticsPawn = child
				var pos: Vector3 = _local_transform_to(pawn, level).origin
				out.append("%s@%.3f,%.3f,%.3f" % [
					_pawn_species_name(pawn),
					pos.x,
					pos.y,
					pos.z,
				])
	return out


func _team_species(team: Array[PokemonInstanceResource]) -> Array[String]:
	var out: Array[String] = []
	for entry in team:
		out.append(entry.display_name() if entry != null else "")
	return out


func _collect_spawn_anchors(arena: Node, prefix: String) -> Array[Node3D]:
	var anchors: Array[Node3D] = []
	var spawn_points: Node = arena.get_node_or_null("SpawnPoints")
	if spawn_points == null:
		return anchors
	for child in spawn_points.get_children():
		if child is Node3D and _is_anchor(child.name, prefix):
			anchors.append(child as Node3D)
	anchors.sort_custom(_is_spawn_anchor_less_than)
	return anchors


func _is_anchor(name: String, prefix: String) -> bool:
	if name == prefix:
		return true
	if not name.begins_with(prefix):
		return false
	var suffix: String = name.substr(prefix.length())
	return suffix.is_valid_int()


func _is_spawn_anchor_less_than(a: Node3D, b: Node3D) -> bool:
	var order_a: int = _spawn_anchor_order(a.name)
	var order_b: int = _spawn_anchor_order(b.name)
	if order_a != order_b:
		return order_a < order_b
	return String(a.name) < String(b.name)


func _spawn_anchor_order(anchor_name: String) -> int:
	var digits: String = ""
	for i in range(anchor_name.length()):
		var ch: String = anchor_name.substr(i, 1)
		if ch.is_valid_int():
			digits += ch
	return int(digits) if not digits.is_empty() else 0


func _local_transform_to(node: Node3D, ancestor: Node) -> Transform3D:
	var out: Transform3D = node.transform
	var current: Node = node.get_parent()
	while current != null and current != ancestor:
		if current is Node3D:
			out = (current as Node3D).transform * out
		current = current.get_parent()
	return out


func _pawn_species_name(pawn: TacticsPawn) -> String:
	if pawn == null:
		return ""
	if pawn.stats != null and not pawn.stats.species_name.is_empty():
		return pawn.stats.species_name
	var expertise: Expertise = pawn.get_node_or_null("Expertise") as Expertise
	if expertise != null and expertise.pokemon_instance != null:
		return expertise.pokemon_instance.display_name()
	return ""


func _roster_path(slug: String) -> String:
	return "%s%s.tres" % [ROSTER_DIR, slug]


func _is_unique(arr: Array) -> bool:
	var seen: Dictionary = {}
	for v in arr:
		if seen.has(v):
			return false
		seen[v] = true
	return true


func _all_controlled_by(team: Array[PokemonInstanceResource], control_type: int) -> bool:
	for instance in team:
		if instance == null or instance.control_type != control_type:
			return false
	return true


func _max_index(arr: Array) -> int:
	var m: int = -1
	for v in arr:
		var n: int = int(v)
		if n > m:
			m = n
	return m


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	push_error("smoke: fail - %s" % label)
