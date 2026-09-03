class_name MinimumViableAI
extends RefCounted

const HEAL_ITEM_IDS: Array[String] = ["berry_oran", "berry_sitrus", "seed_heal"]
const HEAL_THRESHOLD_NUMERATOR: int = 1
const HEAL_THRESHOLD_DENOMINATOR: int = 2


func choose_action(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		_type_chart: TypeChartResource,
		battle_level: TacticsLevel = null
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

	var held: PokemonItemResource = PokemonItemService.held_item_for(unit.stats)
	var held_entry: Dictionary = BattleItemCatalog.entry_for(held.item_id) if held != null else {}
	if held != null and bool(held_entry.get("can_use", false)) and HEAL_ITEM_IDS.has(held.item_id):
		if unit.stats.curr_health * HEAL_THRESHOLD_DENOMINATOR < unit.stats.max_health * HEAL_THRESHOLD_NUMERATOR:
			action.intent = BattleActionIntent.use_item(unit, held.item_id)
			action.target_unit = unit
			return action

	var best_score: float = -1.0
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
		if nearest == null:
			continue
		var score: float = _score_move(unit, move, nearest, _type_chart, enemies)
		if score > best_score:
			best_score = score
			action.move_index = i
			action.target_unit = nearest
			action.intent = BattleActionIntent.move(unit, i, nearest)
	if action.move_index >= 0:
		return action

	if held != null and battle_level != null and _is_offensive_throwable(held_entry):
		var throw_range: int = _throw_range(held)
		for option in Targeting.throw_options(unit, throw_range, all_units, Targeting.arena_tile_keys(battle_level)):
			var hit: TacticsPawn = option.get("hit_unit", null) as TacticsPawn
			if hit != null and hit.is_alive() and enemies.has(hit):
				action.intent = BattleActionIntent.throw_item(unit, held.item_id, option.get("direction", Vector3i.ZERO), hit)
				action.target_unit = hit
				return action

	action.target_unit = _nearest_unit(unit, _active_enemies(enemies))
	return action


func _is_offensive_throwable(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if bool(entry.get("ammo", false)):
		return true
	if bool(entry.get("edible", false)) and String(entry.get("category", "")) == "seed":
		return true
	return false


func _throw_range(item: PokemonItemResource) -> int:
	var presentation: ActionPresentationCatalog = ActionPresentationCatalog.shared()
	var entry: Dictionary = presentation.item(item.item_id)
	var throw_spec: Dictionary = entry.get("throw", {}) if entry.get("throw", null) is Dictionary else {}
	var params: Dictionary = throw_spec.get("params", {}) if throw_spec.get("params", null) is Dictionary else {}
	return int(params.get("range", 8))


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


func _score_move(unit: TacticsPawn, move: PokemonMoveResource, target: TacticsPawn, type_chart: TypeChartResource, enemies: Array) -> float:
	var foe: bool = enemies.has(target)
	if move.is_damaging() and move.base_power > 0 and foe:
		var effectiveness: float = 1.0
		if type_chart != null and target.stats != null:
			var type_a: String = target.stats.types[0] if target.stats.types.size() > 0 else "none"
			var type_b: String = target.stats.types[1] if target.stats.types.size() > 1 else "none"
			effectiveness = type_chart.get_effectiveness_dual(move.type, type_a, type_b)
		var stab: float = 1.5 if unit.stats != null and unit.stats.types.has(move.type) else 1.0
		var accuracy: float = float(move.accuracy) / 100.0 if move.accuracy > 0 else 1.0
		return float(move.base_power) * effectiveness * stab * accuracy
	if move.is_damaging() and foe:
		return 30.0
	if not foe and unit.stats != null and unit.stats.curr_health * 2 < unit.stats.max_health and not move.is_damaging():
		return 25.0
	return 12.0 if foe else 6.0
