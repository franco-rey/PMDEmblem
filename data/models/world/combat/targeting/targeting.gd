class_name Targeting
extends RefCounted


static func effective_range_kind(move: PokemonMoveResource) -> int:
	if move == null:
		return PokemonMoveResource.TacticalRangeKind.MELEE
	var kind: int = move.tactical_range_kind
	if kind in [
			PokemonMoveResource.TacticalRangeKind.UNSUPPORTED,
			PokemonMoveResource.TacticalRangeKind.ALLY,
			PokemonMoveResource.TacticalRangeKind.ROOM,
			PokemonMoveResource.TacticalRangeKind.MAP,
			PokemonMoveResource.TacticalRangeKind.CONE,
	]:
		return PokemonMoveResource.TacticalRangeKind.MELEE
	return kind


static func range_distance(unit: TacticsPawn, move: PokemonMoveResource) -> int:
	if move == null:
		return 1
	var bonus: int = BattleIntrinsicService.range_bonus_for(unit.stats, move) if unit != null else 0
	return maxi(1, move.tactical_range_value + bonus)


static func compute_range(unit: TacticsPawn, move: PokemonMoveResource) -> Array[Vector3i]:
	if unit == null or move == null:
		var empty: Array[Vector3i] = []
		return empty
	return range_from(_tile_key(unit.get_tile()), unit, move)


static func range_from(origin: Vector3i, unit: TacticsPawn, move: PokemonMoveResource) -> Array[Vector3i]:
	var tiles: Array[Vector3i] = []
	if move == null:
		return tiles

	var kind: int = effective_range_kind(move)
	var distance: int = range_distance(unit, move)

	match kind:
		PokemonMoveResource.TacticalRangeKind.MELEE:
			tiles.append(origin + Vector3i(1, 0, 0))
			tiles.append(origin + Vector3i(-1, 0, 0))
			tiles.append(origin + Vector3i(0, 0, 1))
			tiles.append(origin + Vector3i(0, 0, -1))
		PokemonMoveResource.TacticalRangeKind.LINE:
			for dir in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				for i in range(1, distance + 1):
					tiles.append(origin + dir * i)
		PokemonMoveResource.TacticalRangeKind.PROJECTILE:
			for x in range(-distance, distance + 1):
				for z in range(-distance, distance + 1):
					if x == 0 and z == 0:
						continue
					if maxi(absi(x), absi(z)) <= distance:
						tiles.append(origin + Vector3i(x, 0, z))
		PokemonMoveResource.TacticalRangeKind.AREA:
			for x in range(-distance, distance + 1):
				for z in range(-distance, distance + 1):
					if absi(x) + absi(z) <= distance:
						tiles.append(origin + Vector3i(x, 0, z))
		PokemonMoveResource.TacticalRangeKind.SELF:
			tiles.append(origin)

	return tiles


static func key_in_range(origin: Vector3i, key: Vector3i, unit: TacticsPawn, move: PokemonMoveResource) -> bool:
	if move == null:
		return false
	var kind: int = effective_range_kind(move)
	var distance: int = range_distance(unit, move)
	var dx: int = absi(key.x - origin.x)
	var dz: int = absi(key.z - origin.z)
	match kind:
		PokemonMoveResource.TacticalRangeKind.MELEE:
			return dx + dz == 1
		PokemonMoveResource.TacticalRangeKind.LINE:
			if dx != 0 and dz != 0:
				return false
			return dx + dz >= 1 and dx + dz <= distance
		PokemonMoveResource.TacticalRangeKind.PROJECTILE:
			return (dx != 0 or dz != 0) and maxi(dx, dz) <= distance
		PokemonMoveResource.TacticalRangeKind.AREA:
			return dx + dz <= distance
		PokemonMoveResource.TacticalRangeKind.SELF:
			return dx == 0 and dz == 0
	return false


static func filter_by_alignment(
		tiles: Array[Vector3i],
		unit: TacticsPawn,
		move: PokemonMoveResource,
		units_on_map: Array[TacticsPawn]
) -> Array[TacticsPawn]:
	var targets: Array[TacticsPawn] = []
	if unit == null or move == null:
		return targets

	var legal_tiles: Dictionary = {}
	for tile in tiles:
		legal_tiles[tile] = true

	for other: TacticsPawn in units_on_map:
		if other == null or not other.is_alive():
			continue
		if not legal_tiles.has(_tile_key(other.get_tile())):
			continue
		if alignment_allows(unit, other, move):
			targets.append(other)
	return targets


static func legal_targets_for_move(unit: TacticsPawn, move: PokemonMoveResource, units_on_map: Array[TacticsPawn]) -> Array[TacticsPawn]:
	return filter_by_alignment(compute_range(unit, move), unit, move, units_on_map)


static func line_direction_to(unit: TacticsPawn, target: TacticsPawn) -> Vector3i:
	if unit == null or target == null or unit.get_tile() == null or target.get_tile() == null:
		return Vector3i.ZERO
	var delta: Vector3i = _tile_key(target.get_tile()) - _tile_key(unit.get_tile())
	if delta.x != 0 and delta.z != 0:
		return Vector3i.ZERO
	if delta.x != 0:
		return Vector3i(signi(delta.x), 0, 0)
	if delta.z != 0:
		return Vector3i(0, 0, signi(delta.z))
	return Vector3i.ZERO


static func targets_on_line(unit: TacticsPawn, move: PokemonMoveResource, units_on_map: Array[TacticsPawn], direction: Vector3i) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	if direction == Vector3i.ZERO:
		return out
	var origin: Vector3i = _tile_key(unit.get_tile())
	var distance: int = maxi(1, move.tactical_range_value + BattleIntrinsicService.range_bonus_for(unit.stats, move))
	var line: Array[Vector3i] = []
	for i in range(1, distance + 1):
		line.append(origin + direction * i)
	return filter_by_alignment(line, unit, move, units_on_map)


static func has_legal_target(unit: TacticsPawn, move: PokemonMoveResource, units_on_map: Array[TacticsPawn]) -> bool:
	return not legal_targets_for_move(unit, move, units_on_map).is_empty()


static func is_target_legal(unit: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource) -> bool:
	if unit == null or target == null or move == null or not target.is_alive():
		return false
	var tile: TacticsTile = target.get_tile()
	if tile == null or not tile.attackable:
		return false
	return alignment_allows(unit, target, move)


static func alignment_allows(unit: TacticsPawn, target: TacticsPawn, move: PokemonMoveResource) -> bool:
	if unit == target:
		if move.is_damaging():
			return false
		return move.can_target_self()
	var same_team: bool = _team_key(unit) == _team_key(target)
	if same_team:
		if move.is_damaging():
			return false
		return move.can_target_allies()
	return move.can_target_foes()


const DIRECTIONS_8: Array[Vector3i] = [
	Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 0, 0), Vector3i(1, 0, -1),
	Vector3i(0, 0, -1), Vector3i(-1, 0, -1), Vector3i(-1, 0, 0), Vector3i(-1, 0, 1),
]


static func arena_tile_keys(battle_level: TacticsLevel) -> Dictionary:
	var out: Dictionary = {}
	if battle_level == null or battle_level.arena == null:
		return out
	var tiles: Node = battle_level.arena.get_node_or_null("Tiles")
	if tiles == null:
		return out
	for child in tiles.get_children():
		if child is TacticsTile:
			out[_tile_key(child as TacticsTile)] = child
	return out


static func unit_at_key(key: Vector3i, units_on_map: Array[TacticsPawn]) -> TacticsPawn:
	for other: TacticsPawn in units_on_map:
		if other == null or not other.is_alive():
			continue
		if _tile_key(other.get_tile()) == key:
			return other
	return null


static func ray_from(unit: TacticsPawn, direction: Vector3i, max_range: int, units_on_map: Array[TacticsPawn], tile_keys: Dictionary, stop_at_hit: bool = true, stop_at_wall: bool = true) -> Dictionary:
	var origin: Vector3i = _tile_key(unit.get_tile())
	var path: Array[Vector3i] = []
	var hit_unit: TacticsPawn = null
	var landing: Vector3i = origin
	var blocked_by_wall: bool = false
	if direction == Vector3i.ZERO:
		return {"direction": direction, "path": path, "hit_unit": null, "landing": origin, "blocked_by_wall": false, "distance": 0}
	for step in range(1, maxi(1, max_range) + 1):
		var key: Vector3i = origin + direction * step
		if stop_at_wall and not tile_keys.is_empty() and not tile_keys.has(key):
			blocked_by_wall = true
			break
		path.append(key)
		landing = key
		var occupant: TacticsPawn = unit_at_key(key, units_on_map)
		if occupant != null and occupant != unit:
			hit_unit = occupant
			if stop_at_hit:
				break
	return {"direction": direction, "path": path, "hit_unit": hit_unit, "landing": landing, "blocked_by_wall": blocked_by_wall, "distance": path.size()}


static func throw_options(unit: TacticsPawn, max_range: int, units_on_map: Array[TacticsPawn], tile_keys: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if unit == null:
		return out
	for direction in DIRECTIONS_8:
		var ray: Dictionary = ray_from(unit, direction, max_range, units_on_map, tile_keys, true, true)
		if (ray.get("path", []) as Array).is_empty():
			continue
		out.append(ray)
	return out


static func direction_between_keys(from: Vector3i, to: Vector3i) -> Vector3i:
	var delta: Vector3i = to - from
	if delta == Vector3i.ZERO:
		return Vector3i.ZERO
	if delta.x == 0 or delta.z == 0 or absi(delta.x) == absi(delta.z):
		return Vector3i(signi(delta.x), 0, signi(delta.z))
	return Vector3i.ZERO


static func _team_key(unit: TacticsPawn) -> String:
	if unit == null:
		return ""
	var parent := unit.get_parent()
	if parent != null and (parent is TacticsPlayer or parent is TacticsOpponent):
		if parent.is_inside_tree():
			return str(parent.get_path())
		return str(parent.get_instance_id())
	if unit.stats != null and unit.stats.pokemon_instance != null:
		return str(unit.stats.pokemon_instance.team)
	if parent != null:
		if parent.is_inside_tree():
			return str(parent.get_path())
		return str(parent.get_instance_id())
	return ""


static func _tile_key(tile: TacticsTile) -> Vector3i:
	if tile == null:
		return Vector3i.ZERO
	var pos: Vector3 = tile.global_position if tile.is_inside_tree() else tile.position
	return Vector3i(floori(pos.x + 0.5), 0, floori(pos.z + 0.5))


static func _facing_direction(unit: TacticsPawn) -> Vector3i:
	var basis: Basis = unit.global_basis if unit.is_inside_tree() else unit.basis
	var forward: Vector3 = basis.z
	if absf(forward.x) > absf(forward.z):
		return Vector3i(1 if forward.x > 0.0 else -1, 0, 0)
	return Vector3i(0, 0, 1 if forward.z > 0.0 else -1)


static func facing_direction_8(unit: TacticsPawn) -> Vector3i:
	var basis: Basis = unit.global_basis if unit.is_inside_tree() else unit.basis
	var forward: Vector3 = basis.z
	forward.y = 0.0
	if forward.length() < 0.0001:
		return Vector3i(0, 0, 1)
	var angle: float = Vector2(forward.x, forward.z).angle()
	var octant: int = int(round(angle / (PI / 4.0)))
	var snapped: Vector2 = Vector2.RIGHT.rotated(float(octant) * PI / 4.0)
	return Vector3i(int(round(snapped.x)), 0, int(round(snapped.y)))
