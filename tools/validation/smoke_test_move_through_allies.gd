extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")


func _run() -> void:
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch("match seed=3 mode=pvp team=16 map=chessboard")
	_assert_true(ok, "16v16 chessboard launches")
	if not ok:
		_finish("move_through_allies")
		return
	var level: TacticsLevel = driver.level
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var boxed: TacticsPawn = null
	for pawn in level.player.get_children():
		if not (pawn is TacticsPawn):
			continue
		var key: Vector3i = Targeting._tile_key(pawn.get_tile())
		var free_neighbors: int = 0
		for direction in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var neighbor: Vector3i = key + direction
			if keys.has(neighbor) and (keys[neighbor] as TacticsTile).get_tile_occupier() == null:
				free_neighbors += 1
		if free_neighbors == 0:
			boxed = pawn
			break
	_assert_true(boxed != null, "a player unit starts boxed in by teammates and the board edge")
	if boxed == null:
		_finish("move_through_allies")
		return
	var participant: TacticsParticipantResource = level.participant.res
	participant.curr_pawn = boxed
	participant.stage = participant.STAGE_SHOW_MOVEMENTS
	await physics_frame
	await physics_frame
	var reachable: int = 0
	var reachable_occupied: int = 0
	var own_key: Vector3i = Targeting._tile_key(boxed.get_tile())
	for key in keys.keys():
		var tile: TacticsTile = keys[key]
		if key == own_key or not tile.reachable:
			continue
		reachable += 1
		if tile.get_tile_occupier() != null:
			reachable_occupied += 1
	_assert_true(reachable > 0, "%s can reach %d tiles by passing through teammates" % [level.notation.unit_ref(boxed), reachable])
	_assert_true(reachable_occupied == 0, "no occupied tile is offered as a destination")
	var enemy_side_reached: bool = false
	for key in keys.keys():
		var tile: TacticsTile = keys[key]
		if tile.reachable and tile.get_tile_occupier() == null and abs(int((key as Vector3i).z) - own_key.z) >= 2:
			enemy_side_reached = true
			break
	_assert_true(enemy_side_reached, "reachable tiles include squares past the front row")
	participant.stage = participant.STAGE_SHOW_ACTIONS
	_finish("move_through_allies")
