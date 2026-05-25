class_name MinimumViableAI
extends RefCounted
## Naive M6 AI: first legal usable move, nearest legal target, deterministic order.


func choose_action(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		_type_chart: TypeChartResource
) -> AIAction:
	var action := AIAction.new()
	if unit == null or unit.stats == null:
		return action

	var all_units: Array[TacticsPawn] = []
	for ally in allies:
		if ally is TacticsPawn:
			all_units.append(ally)
	for enemy in enemies:
		if enemy is TacticsPawn:
			all_units.append(enemy)

	for i in range(unit.stats.move_slots.size()):
		var move: PokemonMoveResource = unit.stats.move_slots[i]
		if move == null:
			continue
		if not unit.stats.has_pp(i):
			continue
		var targets: Array[TacticsPawn] = Targeting.filter_by_alignment(
			Targeting.compute_range(unit, move),
			unit,
			move,
			all_units
		)
		var nearest: TacticsPawn = _nearest_unit(unit, targets)
		if nearest != null:
			action.move_index = i
			action.target_unit = nearest
			return action

	action.target_unit = _nearest_unit(unit, _active_enemies(enemies))
	return action


func _active_enemies(enemies: Array) -> Array[TacticsPawn]:
	var active: Array[TacticsPawn] = []
	for enemy in enemies:
		if enemy is TacticsPawn and enemy.is_alive():
			active.append(enemy)
	return active


func _nearest_unit(unit: TacticsPawn, targets: Array[TacticsPawn]) -> TacticsPawn:
	var nearest: TacticsPawn = null
	var nearest_distance: float = INF
	for target: TacticsPawn in targets:
		if target == null or not target.is_alive():
			continue
		var dist: float = unit.global_position.distance_squared_to(target.global_position)
		if dist < nearest_distance:
			nearest = target
			nearest_distance = dist
	return nearest
