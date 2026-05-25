class_name Targeting
extends RefCounted


static func compute_range(unit: TacticsPawn, move: PokemonMoveResource) -> Array[Vector3i]:
	var tiles: Array[Vector3i] = []
	if unit == null or move == null:
		return tiles

	var origin: Vector3i = _tile_key(unit.get_tile())
	var kind: int = move.tactical_range_kind
	var distance: int = maxi(1, move.tactical_range_value)
	if kind in [
			PokemonMoveResource.TacticalRangeKind.UNSUPPORTED,
			PokemonMoveResource.TacticalRangeKind.ALLY,
			PokemonMoveResource.TacticalRangeKind.ROOM,
			PokemonMoveResource.TacticalRangeKind.MAP,
			PokemonMoveResource.TacticalRangeKind.CONE,
	]:
		kind = PokemonMoveResource.TacticalRangeKind.MELEE

	match kind:
		PokemonMoveResource.TacticalRangeKind.MELEE:
			tiles.append(origin + Vector3i(1, 0, 0))
			tiles.append(origin + Vector3i(-1, 0, 0))
			tiles.append(origin + Vector3i(0, 0, 1))
			tiles.append(origin + Vector3i(0, 0, -1))
		PokemonMoveResource.TacticalRangeKind.LINE:
			var dir: Vector3i = _facing_direction(unit)
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
		return move.can_target_self()
	var same_team: bool = _team_key(unit) == _team_key(target)
	if same_team:
		if move.is_damaging():
			return false
		return move.can_target_allies()
	return move.can_target_foes()


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
	return Vector3i(roundi(pos.x), 0, roundi(pos.z))


static func _facing_direction(unit: TacticsPawn) -> Vector3i:
	var basis: Basis = unit.global_basis if unit.is_inside_tree() else unit.basis
	var forward: Vector3 = -basis.z
	if absf(forward.x) > absf(forward.z):
		return Vector3i(1 if forward.x > 0.0 else -1, 0, 0)
	return Vector3i(0, 0, 1 if forward.z > 0.0 else -1)
