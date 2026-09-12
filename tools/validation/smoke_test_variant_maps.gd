extends SmokeCase

const DRIVER: GDScript = preload("res://tools/debug/notation_driver.gd")
const EXPECTED: Dictionary = {
	"chessboard": {"tiles": 64, "cap": 16, "cols": 8, "rows": 8},
	"xiangqi": {"tiles": 90, "cap": 16, "cols": 9, "rows": 10},
	"shogi": {"tiles": 81, "cap": 20, "cols": 9, "rows": 9},
	"janggi": {"tiles": 90, "cap": 16, "cols": 9, "rows": 10},
	"makruk": {"tiles": 64, "cap": 16, "cols": 8, "rows": 8},
	"sittuyin": {"tiles": 64, "cap": 16, "cols": 8, "rows": 8},
	"circular": {"tiles": 132, "cap": 16, "cols": 14, "rows": 14},
	"grids": {"tiles": 297, "cap": 15, "cols": 21, "rows": 21, "wedges": 36},
}

var driver: RefCounted = null


func _run() -> void:
	var paths: Array[String] = CustomSkirmishBuilder.map_paths()
	_assert_true(paths.size() == EXPECTED.size() and not paths.any(func(p: String) -> bool: return p.find("test_arena") >= 0), "the lobby lists the chessboard and the seven variant boards and the test arena is gone (%d maps)" % paths.size())
	_assert_true(SkirmishCode.DEFAULT_MAP_PATH.ends_with("chessboard.tres"), "the chessboard is the default map")
	for map_id in EXPECTED:
		_check_map(map_id, EXPECTED[map_id])
	_check_setups()
	driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=4 mode=pvp map=grids team=15")
	_assert_true(ok, "a 15v15 hot-seat skirmish launches on Grids")
	if ok:
		var level: TacticsLevel = driver.level
		_assert_true(level.notation.columns == 21 and level.notation.rows == 21, "the notation sees the 21 by 21 Grids frame (%dx%d)" % [level.notation.columns, level.notation.rows])
		var corner_ok: bool = true
		for pawn in level.player.get_children():
			var key: Vector3i = Targeting._tile_key(pawn.get_tile())
			if key.x > -7 or key.z > -7:
				corner_ok = false
		for pawn in level.opponent.get_children():
			var key: Vector3i = Targeting._tile_key(pawn.get_tile())
			if key.x < 6 or key.z < 6:
				corner_ok = false
		_assert_true(corner_ok and level.player.get_child_count() == 15 and level.opponent.get_child_count() == 15, "both teams start inside their corner blocks on Grids")
		_assert_true(level.camera_boundary_radius >= 13.0, "the camera boundary grows with the board (%.1f)" % level.camera_boundary_radius)
		var first: TacticsPawn = level.player.get_child(0) as TacticsPawn
		var arena: TacticsArena = level.arena
		arena.reset_all_tile_markers()
		arena.process_surrounding_tiles(first.get_tile(), 40.0, level.player.get_children())
		arena.mark_reachable_tiles(first.get_tile(), 40.0)
		var reachable: int = 0
		for key in Targeting.arena_tile_keys(level):
			if (Targeting.arena_tile_keys(level)[key] as TacticsTile).reachable:
				reachable += 1
		_assert_true(reachable >= 297 - 30, "every walkable square of Grids is connected through the bridges, only the thirty occupied ones excepted (%d reachable)" % reachable)
	var ring_ok: bool = await driver._launch("match seed=5 mode=bots map=circular team=16")
	_assert_true(ring_ok, "a 16v16 bot skirmish launches on the Circular ring")
	if ring_ok:
		var level: TacticsLevel = driver.level
		var keys: Dictionary = Targeting.arena_tile_keys(level)
		_assert_true(keys.size() == 132 and not keys.has(Vector3i(-1, 0, -1)) and not keys.has(Vector3i(0, 0, 0)), "the ring has no squares in its hollow centre")
		var first: TacticsPawn = level.player.get_child(0) as TacticsPawn
		level.arena.reset_all_tile_markers()
		level.arena.process_surrounding_tiles(first.get_tile(), 40.0, level.player.get_children())
		level.arena.mark_reachable_tiles(first.get_tile(), 40.0)
		var reachable: int = 0
		for key in keys:
			if (keys[key] as TacticsTile).reachable:
				reachable += 1
		_assert_true(reachable >= 100, "the ring is walkable all the way round (%d reachable)" % reachable)
	var shogi_ok: bool = await driver._launch("match seed=6 mode=bots map=shogi team=20")
	_assert_true(shogi_ok and driver.level.player.get_child_count() == 20 and driver.level.opponent.get_child_count() == 20, "a 20v20 bot skirmish launches on Shogi")
	var xiangqi_ok: bool = await driver._launch("match seed=7 mode=pvp map=xiangqi team=16")
	_assert_true(xiangqi_ok, "a 16v16 hot-seat skirmish launches on Xiangqi")
	if xiangqi_ok:
		var level: TacticsLevel = driver.level
		var on_setup: int = 0
		var setup: Dictionary = _anchor_keys(level.arena, "SpawnPlayer")
		for pawn in level.player.get_children():
			if setup.has(Targeting._tile_key(pawn.get_tile())):
				on_setup += 1
		_assert_true(on_setup == 16 and level.notation.columns == 9 and level.notation.rows == 10, "on Xiangqi all sixteen player Pokemon stand on the game's starting squares of a 9 by 10 board (%d)" % on_setup)
		var lobby: SkirmishLobby = driver.main.get_node("UI/SkirmishLobby")
		var index: int = -1
		for i in range(lobby.map_paths.size()):
			if String(lobby.map_paths[i]).ends_with("sittuyin.tres"):
				index = i
		var seed_box: LineEdit = lobby.find_child("SeedInput", true, false)
		seed_box.text = ""
		seed_box.text_changed.emit("")
		lobby.map_picker.select(index)
		lobby._on_map_changed(index)
		lobby.activate_player_team()
		lobby.add_roster_index(0)
		lobby.activate_enemy_team()
		lobby.add_roster_index(1)
		var built: Dictionary = lobby.build_current_definition()
		_assert_true(index >= 0 and bool(built.get("ok", false)) and (built["definition"] as SkirmishDefinitionResource).map.map_id == "sittuyin", "picking Sittuyin in the lobby's map picker builds a Sittuyin skirmish (%s)" % String(built.get("error", "")))
	_finish("variant_maps")


func _anchor_keys(arena: Node, prefix: String) -> Dictionary:
	var out: Dictionary = {}
	var spawns: Node = arena.get_node_or_null("SpawnPoints")
	if spawns == null:
		return out
	for child in spawns.get_children():
		if child is Node3D and child.name.begins_with(prefix):
			out[Vector3i(roundi((child as Node3D).position.x), 0, roundi((child as Node3D).position.z))] = true
	return out


func _check_setups() -> void:
	var boards: Dictionary = {}
	for map_id in ["xiangqi", "janggi", "shogi", "makruk", "sittuyin"]:
		var map: MapDefinitionResource = load("res://data/models/maps/definitions/%s.tres" % map_id) as MapDefinitionResource
		var arena: Node = (load(map.scene_path) as PackedScene).instantiate()
		boards[map_id] = {"player": _anchor_keys(arena, "SpawnPlayer"), "enemy": _anchor_keys(arena, "SpawnEnemy")}
		arena.free()
	var xq: Dictionary = boards["xiangqi"]["player"]
	_assert_true(_row_count(xq, -5) == 9 and _row_count(xq, -4) == 0 and xq.has(Vector3i(-3, 0, -3)) and xq.has(Vector3i(3, 0, -3)) and _row_count(xq, -3) == 2 and _row_count(xq, -2) == 5 and xq.has(Vector3i(-4, 0, -2)) and xq.has(Vector3i(0, 0, -2)), "Xiangqi starts nine on the back rank, cannons at b3 and h3, soldiers on a c e g i of the fourth rank")
	var xe: Dictionary = boards["xiangqi"]["enemy"]
	_assert_true(_row_count(xe, 4) == 9 and _row_count(xe, 2) == 2 and _row_count(xe, 1) == 5, "the Xiangqi enemy mirrors the setup on its own side")
	var jg: Dictionary = boards["janggi"]["player"]
	_assert_true(_row_count(jg, -5) == 8 and not jg.has(Vector3i(0, 0, -5)) and jg.has(Vector3i(0, 0, -4)) and _row_count(jg, -4) == 1 and _row_count(jg, -3) == 2 and _row_count(jg, -2) == 5, "Janggi leaves the centre of the back rank empty and seats the general in the palace")
	var sh: Dictionary = boards["shogi"]["player"]
	_assert_true(_row_count(sh, -4) == 9 and _row_count(sh, -3) == 2 and sh.has(Vector3i(-3, 0, -3)) and sh.has(Vector3i(3, 0, -3)) and _row_count(sh, -2) == 9, "Shogi starts nine, then the bishop and rook, then nine pawns")
	var mk: Dictionary = boards["makruk"]["player"]
	_assert_true(_row_count(mk, -4) == 8 and _row_count(mk, -3) == 0 and _row_count(mk, -2) == 8, "Makruk starts eight on the back rank and eight pawns on the third rank")
	var st: Dictionary = boards["sittuyin"]["player"]
	var st_enemy: Dictionary = boards["sittuyin"]["enemy"]
	var diagonal: bool = st.has(Vector3i(-4, 0, -2)) and st.has(Vector3i(-1, 0, -2)) and st.has(Vector3i(0, 0, -1)) and st.has(Vector3i(3, 0, -1)) and not st.has(Vector3i(-4, 0, -1)) and not st.has(Vector3i(3, 0, -2))
	_assert_true(diagonal and st.size() == 16 and st_enemy.has(Vector3i(-1, 0, 3)) and st_enemy.has(Vector3i(1, 0, 3)) and st_enemy.has(Vector3i(-4, 0, 0)) and st_enemy.has(Vector3i(3, 0, 1)), "Sittuyin pawns sit on the a3 to d3 and e4 to h4 diagonal with the pieces behind them, and the black side follows the reference diagram")


func _row_count(keys: Dictionary, z: int) -> int:
	var count: int = 0
	for key in keys:
		if (key as Vector3i).z == z:
			count += 1
	return count


func _check_map(map_id: String, expected: Dictionary) -> void:
	var path: String = "res://data/models/maps/definitions/%s.tres" % map_id
	var map: MapDefinitionResource = load(path) as MapDefinitionResource
	if map == null:
		_assert_true(false, "%s definition loads" % map_id)
		return
	var scene: PackedScene = load(map.scene_path) as PackedScene
	if scene == null:
		_assert_true(false, "%s scene loads" % map_id)
		return
	var arena: Node = scene.instantiate()
	var tiles: Node = arena.get_node_or_null("Tiles")
	var terrain: Node = arena.get_node_or_null("Terrain")
	var spawns: Node = arena.get_node_or_null("SpawnPoints")
	var tile_count: int = tiles.get_child_count() if tiles != null else 0
	var keys: Dictionary = {}
	var min_x: int = 999
	var max_x: int = -999
	var min_z: int = 999
	var max_z: int = -999
	if tiles != null:
		for tile in tiles.get_children():
			var key: Vector3i = Vector3i(roundi((tile as Node3D).position.x), 0, roundi((tile as Node3D).position.z))
			keys[key] = true
			min_x = mini(min_x, key.x)
			max_x = maxi(max_x, key.x)
			min_z = mini(min_z, key.z)
			max_z = maxi(max_z, key.z)
	var players: int = 0
	var enemies: int = 0
	var off_tile: int = 0
	if spawns != null:
		for child in spawns.get_children():
			if not (child is Node3D):
				continue
			var key: Vector3i = Vector3i(roundi((child as Node3D).position.x), 0, roundi((child as Node3D).position.z))
			if not keys.has(key):
				off_tile += 1
			if child.name.begins_with("SpawnPlayer"):
				players += 1
			elif child.name.begins_with("SpawnEnemy"):
				enemies += 1
	var squares: int = 0
	var frames: int = 0
	var lights: int = 0
	var darks: int = 0
	var wedges: int = 0
	if terrain != null:
		for child in terrain.get_children():
			if child.name.begins_with("Wedge_"):
				wedges += 1
				var wedge_key: Vector3i = Vector3i(roundi((child as Node3D).position.x), 0, roundi((child as Node3D).position.z))
				if keys.has(wedge_key):
					off_tile += 1
			if child.name.begins_with("Square_"):
				squares += 1
				var material: Material = (child as MeshInstance3D).get_surface_override_material(0)
				if material is StandardMaterial3D:
					if (material as StandardMaterial3D).albedo_color.r > 0.5:
						lights += 1
					else:
						darks += 1
			elif child.name == "Slab" or child.name.begins_with("Under_"):
				frames += 1
	arena.free()
	_assert_true(tile_count == int(expected["tiles"]) and keys.size() == tile_count, "%s has %d walkable squares (%d)" % [map_id, int(expected["tiles"]), tile_count])
	_assert_true(max_x - min_x + 1 == int(expected["cols"]) and max_z - min_z + 1 == int(expected["rows"]), "%s spans %dx%d (%dx%d)" % [map_id, int(expected["cols"]), int(expected["rows"]), max_x - min_x + 1, max_z - min_z + 1])
	_assert_true(map.max_team_size == int(expected["cap"]) and CustomSkirmishBuilder.max_team_size_for(path) == int(expected["cap"]), "%s caps teams at %d (%d)" % [map_id, int(expected["cap"]), map.max_team_size])
	_assert_true(players >= int(expected["cap"]) and enemies >= int(expected["cap"]) and off_tile == 0, "%s has %d anchors a side on walkable squares (%d/%d, %d off)" % [map_id, int(expected["cap"]), players, enemies, off_tile])
	_assert_true(squares == tile_count and frames >= 1 and absi(lights - darks) <= maxi(2, tile_count / 12), "%s keeps the chessboard look: a light or dark block per square and the brown foundation (%d squares, %d light, %d dark, %d frame pieces)" % [map_id, squares, lights, darks, frames])
	_assert_true(wedges == int(expected.get("wedges", 0)), "%s draws %d chamfer wedges on squares nobody can stand on (%d)" % [map_id, int(expected.get("wedges", 0)), wedges])
