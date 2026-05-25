class_name TacticsArenaService
extends RefCounted

const TILE_SERVICE = preload("res://data/models/world/combat/arena/tile_service/service.gd")

var res: TacticsArenaResource


func _init(_res: TacticsArenaResource) -> void:
	res = _res


func setup(arena: TacticsArena) -> void:
	if not res:
		push_error("TacticsArena needs an ArenaResource from /data/models/world/combat/arena/")
	else:
		res.connect("called_reset_all_tile_markers", arena.reset_all_tile_markers)
		res.connect("called_get_pathfinding_tilestack", arena.get_pathfinding_tilestack)
		res.connect("called_mark_hover_tile", arena.mark_hover_tile)


func reset_all_tile_markers(arena: TacticsArena) -> void:
	for _t: TacticsTile in arena.get_node("Tiles").get_children():
		_t.reset_markers()


func configure_tiles(arena: TacticsArena) -> void:
	arena.get_node("Tiles").visible = true
	var _tiles: Node3D = arena.get_node("Tiles")
	TILE_SERVICE.tiles_into_staticbodies(_tiles)


func process_surrounding_tiles(root_tile: TacticsTile, height: float, allies_on_map: Array = []) -> void:
	var _tiles_process_q: Array = [root_tile]

	while not _tiles_process_q.is_empty():
		var _curr_tile: TacticsTile = _tiles_process_q.pop_front()

		var _add_to_tiles_list: Callable = func _add(_neighbor: TacticsTile) -> void:
			_neighbor.pf_root = _curr_tile
			_neighbor.pf_distance = _curr_tile.pf_distance + 1
			_tiles_process_q.push_back(_neighbor)

		for _neighbor: TacticsTile in _curr_tile.get_neighbors(height):
			if not _neighbor.pf_root and _neighbor != root_tile:
				if not _neighbor.is_taken():
					_add_to_tiles_list.call(_neighbor)
				elif not (allies_on_map.size() > 0):
					if not (_neighbor.get_tile_occupier() in allies_on_map):
						_add_to_tiles_list.call(_neighbor)


func get_pathfinding_tilestack(to: TacticsTile) -> Array:
	var _path_tiles_stack: Array = []

	while to:
		to.hover = true
		_path_tiles_stack.push_front(to.global_position)
		to = to.pf_root

	res.path_tiles_stack = _path_tiles_stack
	return _path_tiles_stack


func get_nearest_target_adjacent_tile(pawn: TacticsPawn, target_pawns: Array) -> TacticsTile:
	var _nearest_target: Node3D = null

	for _p: TacticsPawn in target_pawns:
		if not _p.is_alive(): continue
		for _n: TacticsTile in _p.get_tile().get_neighbors(pawn.stats.jump):
			if not _nearest_target or _n.pf_distance < _nearest_target.pf_distance:
				if _n.pf_distance > 0 and not _n.is_taken():
					_nearest_target = _n

	while _nearest_target and not _nearest_target.reachable:
		_nearest_target = _nearest_target.pf_root

	if _nearest_target:
		return _nearest_target
	else:
		DebugLog.debug_nospam("nearest_target", pawn)
		return pawn.get_tile()


func get_weakest_attackable_pawn(pawn_arr: Array) -> TacticsPawn:
	var _weakest: TacticsPawn = null

	for _p: TacticsPawn in pawn_arr:
		if not _weakest or _p.stats.curr_health < _weakest.stats.curr_health:
			if _p.is_alive() and _p.get_tile().attackable:
				_weakest = _p

	return _weakest


func mark_hover_tile(arena: TacticsArena, tile: TacticsTile) -> void:
	for _t: TacticsTile in arena.get_node("Tiles").get_children():
		_t.hover = false

	if tile:
		tile.hover = true


func mark_reachable_tiles(arena: TacticsArena, root: TacticsTile, distance: float) -> void:
	for _t: TacticsTile in arena.get_node("Tiles").get_children():
		var _has_dist: bool = _t.pf_distance > 0
		var _reachable: bool = _t.pf_distance <= distance
		var _not_taken: bool = not _t.is_taken()
		var _is_root: bool = _t == root

		_t.reachable = (_has_dist and _reachable and _not_taken) or _is_root


func mark_attackable_tiles(arena: TacticsArena, root: TacticsTile, distance: float) -> void:
	for _t: TacticsTile in arena.get_node("Tiles").get_children():
		var _has_dist: bool = _t.pf_distance > 0
		var _reachable: bool = _t.pf_distance <= distance
		var _is_root: bool = _t == root

		_t.attackable = _has_dist and _reachable or _is_root


func mark_unit_tiles_attackable(units: Array[TacticsPawn]) -> void:
	for unit: TacticsPawn in units:
		if unit == null or not unit.is_alive():
			continue
		var tile: TacticsTile = unit.get_tile()
		if tile != null:
			tile.attackable = true


func mark_move_range_preview(arena: TacticsArena, unit: TacticsPawn, move: PokemonMoveResource) -> void:
	if arena == null or unit == null or move == null:
		return
	var range_keys: Dictionary = {}
	for key: Vector3i in Targeting.compute_range(unit, move):
		range_keys[key] = true
	for tile: TacticsTile in _tiles(arena):
		if range_keys.has(_tile_grid_key(tile)):
			tile.attackable = true


func mark_movement_preview(arena: TacticsArena, unit: TacticsPawn) -> void:
	if arena == null or unit == null or unit.stats == null or unit.get_tile() == null:
		return
	var allies: Array = unit.get_parent().get_children() if unit.get_parent() != null else []
	process_surrounding_tiles(unit.get_tile(), unit.stats.movement, allies)
	mark_reachable_tiles(arena, unit.get_tile(), unit.stats.movement)


func _tiles(arena: TacticsArena) -> Array:
	var tiles_node: Node = arena.get_node_or_null("Tiles")
	return tiles_node.get_children() if tiles_node != null else []


func _tile_grid_key(tile: TacticsTile) -> Vector3i:
	if tile == null:
		return Vector3i.ZERO
	var pos: Vector3 = tile.global_position if tile.is_inside_tree() else tile.position
	return Vector3i(roundi(pos.x), 0, roundi(pos.z))
