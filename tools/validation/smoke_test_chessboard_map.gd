extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE: String = "match seed=1 mode=pvp team=16 map=chessboard"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var paths: Array[String] = CustomSkirmishBuilder.map_paths()
	_assert_true(paths.any(func(p: String) -> bool: return p.ends_with("chessboard.tres")), "chessboard definition is listed for the lobby (%d maps)" % paths.size())
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(CustomSkirmishBuilder.max_team_size_for("res://data/models/maps/definitions/chessboard.tres") == 16 and CustomSkirmishBuilder.max_team_size_for("res://data/models/maps/definitions/test_arena.tres") == 8, "team cap is 16 on the chessboard and 8 on the test arena")
	_assert_true(ok, "16v16 launches on the chessboard")
	if not ok:
		_finish()
		return
	var level: TacticsLevel = driver.level
	var tiles: Array = level.arena.get_node("Tiles").get_children()
	_assert_true(tiles.size() == 64, "board has 64 tiles (%d)" % tiles.size())
	_assert_true(level.notation.columns == 8 and level.notation.rows == 8, "notation sees an 8x8 grid (%dx%d)" % [level.notation.columns, level.notation.rows])
	var player_rows: int = 0
	var enemy_rows: int = 0
	for pawn in level.player.get_children():
		var key: Vector3i = Targeting._tile_key(pawn.get_tile())
		if key.z <= -3:
			player_rows += 1
	for pawn in level.opponent.get_children():
		var key: Vector3i = Targeting._tile_key(pawn.get_tile())
		if key.z >= 2:
			enemy_rows += 1
	_assert_true(player_rows == 16, "all sixteen player Pokemon fill their two rows (%d)" % player_rows)
	_assert_true(enemy_rows == 16, "all sixteen CPU Pokemon fill their two rows (%d)" % enemy_rows)
	var spawns: Node = level.arena.get_node("SpawnPoints")
	var light_first: int = 0
	var dark_first: int = 0
	for i in range(8):
		var player_anchor: Node3D = spawns.get_node("SpawnPlayer" if i == 0 else "SpawnPlayer%d" % (i + 1))
		var enemy_anchor: Node3D = spawns.get_node("SpawnEnemy" if i == 0 else "SpawnEnemy%d" % (i + 1))
		var pk: Vector3i = Vector3i(floori(player_anchor.position.x + 0.5), 0, floori(player_anchor.position.z + 0.5))
		var ek: Vector3i = Vector3i(floori(enemy_anchor.position.x + 0.5), 0, floori(enemy_anchor.position.z + 0.5))
		if posmod(pk.x + pk.z, 2) == 1 and pk.z <= -3:
			light_first += 1
		if posmod(ek.x + ek.z, 2) == 0 and ek.z >= 2:
			dark_first += 1
	_assert_true(light_first == 8 and dark_first == 8, "an 8v8 checkerboards within the two rows: player light squares, CPU dark squares (%d, %d)" % [light_first, dark_first])
	_assert_true(level.player.get_child(0).name == "Pkmn" and level.player.get_child(1).name == "Pkmn2", "pawn nodes are named Pkmn, Pkmn2, ...")
	var facing_ok: int = 0
	var movement := TacticsPawnMovementService.new()
	for pawn in level.player.get_children():
		if movement.facing_direction_8(pawn).z > 0:
			facing_ok += 1
	for pawn in level.opponent.get_children():
		if movement.facing_direction_8(pawn).z < 0:
			facing_ok += 1
	_assert_true(facing_ok == 32, "every Pokemon starts facing the opposing team (%d of 32)" % facing_ok)
	var terrain: Node = level.arena.get_node_or_null("Terrain")
	_assert_true(terrain != null and terrain.get_child_count() == 65, "visible board has 64 squares on a slab")
	var hud_label: Label = level.hud.get_node("HudRoot/QueueColumn/QueueStrip/Inner/RoundLabel")
	_assert_true(hud_label.text.begins_with("Turn "), "HUD counts turns (%s)" % hud_label.text)
	_finish()


func _finish() -> void:
	if failures > 0:
		push_error("smoke: chessboard_map failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: chessboard_map clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
