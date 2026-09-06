extends SceneTree

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE: String = "match seed=7 mode=pvp map=chessboard multiverse=1 p=0483_dialga@100:roar_of_time,dragon_claw:pressure|0251_celebi@100:dimensional_hole,psychic:natural_cure|0474_porygon_z@100:dimensional_glitch,tri_attack:adaptability e=0484_palkia@100:spacial_rend,aqua_tail:pressure|0487_giratina@100:shadow_force,dragon_claw:pressure|0720_hoopa@100:hyperspace_hole,psychic:magician"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(ok, "the multiverse chessboard launches")
	if not ok:
		_finish()
		return
	var level: TacticsLevel = driver.level
	_check_occupancy(level, "on a settled board")
	_check_reachable(level, "on a settled board")
	var board: BoardSnapshot = level.multiverse.capture(false)
	level.multiverse.restore(board)
	_check_occupancy(level, "on the frame a board is rebuilt")
	_check_reachable(level, "on the frame a board is rebuilt")
	await physics_frame
	_check_occupancy(level, "a frame after a board is rebuilt")
	_check_reachable(level, "a frame after a board is rebuilt")
	await _teleport_case(level)
	_finish()


func _teleport_case(level: TacticsLevel) -> void:
	var mover: TacticsPawn = null
	for pawn in level.units_on_map():
		if pawn.stats != null and pawn.is_alive():
			mover = pawn
			break
	if mover == null:
		_assert_true(false, "a living unit is available to teleport")
		return
	var tiles: Dictionary = Targeting.arena_tile_keys(level)
	var standing: Dictionary = _standing(level)
	var destination: TacticsTile = null
	for key in tiles.keys():
		if not standing.has(key):
			destination = tiles[key]
			break
	if destination == null:
		return
	var vacated: TacticsTile = tiles[_pawn_key(mover)]
	mover.global_position = destination.global_position
	mover.sync_physics_body()
	await physics_frame
	_assert_true(destination.is_taken(), "a teleported unit is seen on the tile it lands on")
	_assert_true(not vacated.is_taken(), "a teleported unit is no longer seen on the tile it left")


func _pawn_key(pawn: TacticsPawn) -> Vector3i:
	var pos: Vector3 = pawn.global_position if pawn.is_inside_tree() else pawn.position
	return Vector3i(floori(pos.x + 0.5), 0, floori(pos.z + 0.5))


func _standing(level: TacticsLevel) -> Dictionary:
	var out: Dictionary = {}
	for pawn in level.units_on_map():
		if pawn.stats == null or not pawn.is_alive():
			continue
		out[_pawn_key(pawn)] = pawn
	return out


func _check_occupancy(level: TacticsLevel, label: String) -> void:
	var tiles: Dictionary = Targeting.arena_tile_keys(level)
	var standing: Dictionary = _standing(level)
	var missed: int = 0
	var phantom: int = 0
	for key in tiles.keys():
		var taken: bool = (tiles[key] as TacticsTile).is_taken()
		if standing.has(key) and not taken:
			missed += 1
		elif not standing.has(key) and taken:
			phantom += 1
	_assert_true(missed == 0, "every occupied tile reports itself taken %s (%d missed)" % [label, missed])
	_assert_true(phantom == 0, "no empty tile reports itself taken %s (%d phantom)" % [label, phantom])


func _check_reachable(level: TacticsLevel, label: String) -> void:
	var mover: TacticsPawn = null
	for pawn in level.units_on_map():
		if pawn.stats != null and pawn.is_alive():
			mover = pawn
			break
	if mover == null:
		return
	level.arena.reset_all_tile_markers()
	level.arena.process_surrounding_tiles(mover.get_tile(), mover.stats.movement, mover.get_parent().get_children())
	level.arena.mark_reachable_tiles(mover.get_tile(), mover.stats.movement)
	var own: Vector3i = _pawn_key(mover)
	var standing: Dictionary = _standing(level)
	var offered: int = 0
	var tiles: Dictionary = Targeting.arena_tile_keys(level)
	for key in tiles.keys():
		if key == own or not (tiles[key] as TacticsTile).reachable:
			continue
		if standing.has(key):
			offered += 1
	_assert_true(offered == 0, "no occupied tile is offered as a destination %s (%d offered)" % [label, offered])


func _finish() -> void:
	if failures > 0:
		push_error("smoke: tile_occupancy failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: tile_occupancy clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
