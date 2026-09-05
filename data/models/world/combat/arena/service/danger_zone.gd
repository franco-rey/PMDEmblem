class_name DangerZoneService
extends RefCounted


static func compute(level: TacticsLevel, viewer_team: int) -> Dictionary:
	var keys: Dictionary = {}
	if level == null or level.arena == null:
		return keys
	var tiles: Dictionary = _tiles_by_key(level)
	for pawn in level.units_on_map():
		if pawn == null or not pawn.is_alive() or pawn.stats == null or pawn.stats.pokemon_instance == null:
			continue
		if pawn.stats.pokemon_instance.team == viewer_team:
			continue
		var origins: Dictionary = _reachable_keys(level, pawn, tiles)
		var moves: Array[PokemonMoveResource] = _threat_moves(pawn)
		for origin in origins.keys():
			for move in moves:
				for key in _range_from(origin, pawn, move):
					if tiles.has(key):
						keys[key] = true
	return keys


static func apply(level: TacticsLevel, keys: Dictionary) -> int:
	var count: int = 0
	if level == null or level.arena == null:
		return 0
	for tile in level.arena.get_node("Tiles").get_children():
		if not (tile is TacticsTile):
			continue
		var flagged: bool = keys.has(_grid_key(tile))
		(tile as TacticsTile).danger = flagged
		if flagged:
			count += 1
	return count


static func clear(level: TacticsLevel) -> void:
	apply(level, {})


static func _tiles_by_key(level: TacticsLevel) -> Dictionary:
	var out: Dictionary = {}
	for tile in level.arena.get_node("Tiles").get_children():
		if tile is TacticsTile:
			out[_grid_key(tile)] = tile
	return out


static func _reachable_keys(level: TacticsLevel, pawn: TacticsPawn, tiles: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var start: TacticsTile = pawn.get_tile()
	if start == null:
		return out
	var movement: int = int(pawn.stats.movement)
	var allies: Array = pawn.get_parent().get_children() if pawn.get_parent() != null else []
	var distances: Dictionary = {start: 0}
	var queue: Array = [start]
	out[_grid_key(start)] = true
	while not queue.is_empty():
		var current: TacticsTile = queue.pop_front()
		var distance: int = int(distances[current])
		if distance >= movement:
			continue
		for neighbor in current.get_neighbors(pawn.stats.jump):
			if not (neighbor is TacticsTile) or distances.has(neighbor):
				continue
			var occupier: Object = (neighbor as TacticsTile).get_tile_occupier()
			var passable: bool = occupier == null or occupier == pawn or allies.has(occupier)
			if not passable:
				continue
			distances[neighbor] = distance + 1
			queue.push_back(neighbor)
			if occupier == null or occupier == pawn:
				out[_grid_key(neighbor)] = true
	return out


static func _threat_moves(pawn: TacticsPawn) -> Array[PokemonMoveResource]:
	var out: Array[PokemonMoveResource] = []
	for i in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[i]
		if move == null or not move.is_damaging():
			continue
		if i < pawn.stats.current_pp.size() and pawn.stats.current_pp[i] <= 0:
			continue
		out.append(move)
	return out


static func _range_from(origin: Vector3i, pawn: TacticsPawn, move: PokemonMoveResource) -> Array[Vector3i]:
	var tiles: Array[Vector3i] = []
	var kind: int = move.tactical_range_kind
	var distance: int = maxi(1, move.tactical_range_value + BattleIntrinsicService.range_bonus_for(pawn.stats, move))
	if kind in [PokemonMoveResource.TacticalRangeKind.UNSUPPORTED, PokemonMoveResource.TacticalRangeKind.ALLY, PokemonMoveResource.TacticalRangeKind.ROOM, PokemonMoveResource.TacticalRangeKind.MAP, PokemonMoveResource.TacticalRangeKind.CONE]:
		kind = PokemonMoveResource.TacticalRangeKind.MELEE
	match kind:
		PokemonMoveResource.TacticalRangeKind.MELEE:
			for dir in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				tiles.append(origin + dir)
		PokemonMoveResource.TacticalRangeKind.LINE:
			for dir in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				for i in range(1, distance + 1):
					tiles.append(origin + dir * i)
		PokemonMoveResource.TacticalRangeKind.PROJECTILE:
			for x in range(-distance, distance + 1):
				for z in range(-distance, distance + 1):
					if (x != 0 or z != 0) and maxi(absi(x), absi(z)) <= distance:
						tiles.append(origin + Vector3i(x, 0, z))
		PokemonMoveResource.TacticalRangeKind.AREA:
			for x in range(-distance, distance + 1):
				for z in range(-distance, distance + 1):
					if absi(x) + absi(z) <= distance:
						tiles.append(origin + Vector3i(x, 0, z))
	return tiles


static func _grid_key(tile: Node3D) -> Vector3i:
	var pos: Vector3 = tile.global_position if tile.is_inside_tree() else tile.position
	return Vector3i(floori(pos.x + 0.5), 0, floori(pos.z + 0.5))
