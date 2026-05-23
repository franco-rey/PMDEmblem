extends SceneTree
## Headless smoke test for the M4 R2 random NvN skirmish builder.
##
## Validates that `CustomSkirmishBuilder.build_random` produces a loader-ready
## `SkirmishDefinitionResource` for every supported team size (1v1..5v5), that
## team picks reroll across calls with no seed, and that a fixed seed makes
## both team rolls and spawn placement reproducible.
##
## Recipe:
##   godot --headless --path . --script tools/validation/smoke_test_random_skirmish.gd

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/test_arena.tres"
const SUPPORTED_TEAM_SIZES: Array[int] = [1, 2, 3, 4, 5]
const FIXED_SEED_TEXT: String = "777777"

var failures: int = 0


func _init() -> void:
	_check_each_team_size_builds()
	_check_fixed_seed_is_deterministic()
	_check_empty_seed_rerolls()
	_check_invalid_team_size_rejected()

	if failures > 0:
		push_error("smoke: random_skirmish failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: random_skirmish clean")
		quit(0)


func _check_each_team_size_builds() -> void:
	for team_size in SUPPORTED_TEAM_SIZES:
		var result: Dictionary = CustomSkirmishBuilder.build_random(team_size, TEST_ARENA_MAP_PATH, "")
		_assert_true(result.get("ok", false), "build_random(%d) succeeds" % team_size)
		if not result.get("ok", false):
			continue
		var definition: SkirmishDefinitionResource = result["definition"]
		_assert_true(definition != null, "build_random(%d) returns a definition" % team_size)
		_assert_true(definition.player_team.size() == team_size, "player team has %d members" % team_size)
		_assert_true(definition.enemy_team.size() == team_size, "enemy team has %d members" % team_size)
		_assert_true(String(definition.generation_metadata.get("source", "")) == "random_builder",
			"metadata marked as random_builder for %dv%d" % [team_size, team_size])


func _check_fixed_seed_is_deterministic() -> void:
	var a: Dictionary = CustomSkirmishBuilder.build_random(3, TEST_ARENA_MAP_PATH, FIXED_SEED_TEXT)
	var b: Dictionary = CustomSkirmishBuilder.build_random(3, TEST_ARENA_MAP_PATH, FIXED_SEED_TEXT)
	_assert_true(a.get("ok", false) and b.get("ok", false), "fixed-seed builds both succeed")
	if not (a.get("ok", false) and b.get("ok", false)):
		return
	var da: SkirmishDefinitionResource = a["definition"]
	var db: SkirmishDefinitionResource = b["definition"]
	_assert_true(int(a["seed"]) == int(b["seed"]), "fixed seed echoed identically")
	_assert_true(_species_slugs(da.player_team) == _species_slugs(db.player_team),
		"fixed seed -> identical player team composition")
	_assert_true(_species_slugs(da.enemy_team) == _species_slugs(db.enemy_team),
		"fixed seed -> identical enemy team composition")
	_assert_true(da.generation_metadata.get("player_spawn_order", []) == db.generation_metadata.get("player_spawn_order", []),
		"fixed seed -> identical player spawn order")
	_assert_true(da.generation_metadata.get("enemy_spawn_order", []) == db.generation_metadata.get("enemy_spawn_order", []),
		"fixed seed -> identical enemy spawn order")


func _check_empty_seed_rerolls() -> void:
	# Empty-seed rolls use a randomized generator so consecutive calls should
	# produce different seeds; over 8 attempts at least one should differ.
	var first: Dictionary = CustomSkirmishBuilder.build_random(3, TEST_ARENA_MAP_PATH, "")
	if not first.get("ok", false):
		_assert_true(false, "initial empty-seed build succeeds")
		return
	var first_seed: int = int(first["seed"])
	var saw_different: bool = false
	for i in range(8):
		var next: Dictionary = CustomSkirmishBuilder.build_random(3, TEST_ARENA_MAP_PATH, "")
		if not next.get("ok", false):
			continue
		if int(next["seed"]) != first_seed:
			saw_different = true
			break
	_assert_true(saw_different, "empty seed rerolls across calls")


func _check_invalid_team_size_rejected() -> void:
	var zero: Dictionary = CustomSkirmishBuilder.build_random(0, TEST_ARENA_MAP_PATH, "")
	_assert_true(not zero.get("ok", false), "team size 0 is rejected")
	var too_many: Dictionary = CustomSkirmishBuilder.build_random(CustomSkirmishBuilder.MAX_TEAM_SIZE + 1, TEST_ARENA_MAP_PATH, "")
	_assert_true(not too_many.get("ok", false), "team size > %d is rejected" % CustomSkirmishBuilder.MAX_TEAM_SIZE)


func _species_slugs(team: Array[PokemonInstanceResource]) -> Array[String]:
	var out: Array[String] = []
	for instance in team:
		if instance == null or instance.species == null:
			out.append("?")
		else:
			out.append(instance.species.species_id)
	return out


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
