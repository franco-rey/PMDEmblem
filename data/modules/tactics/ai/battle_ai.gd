class_name BattleAI
extends RefCounted

const ESTIMATE_SEED: int = 991
const KO_BONUS: float = 220.0
const FOCUS_BONUS: float = 45.0
const HAZARD_PENALTY: float = 60.0
const STATUS_SCORE: float = 40.0
const SETUP_SCORE: float = 34.0
const FIELD_SCORE: float = 26.0
const APPROACH_SCALE: float = 12.0
const RETALIATION_WEIGHT: float = 0.45
const RETREAT_HP_FRACTION: float = 0.3
const RETREAT_BONUS: float = 55.0
const ZONE_BONUS: float = 6.0
const HEAL_ITEM_IDS: Array[String] = ["berry_oran", "berry_sitrus", "seed_heal"]
const HEAL_HP_NUMERATOR: int = 1
const HEAL_HP_DENOMINATOR: int = 2
const SETUP_STAT_KEYS: Array[String] = ["atk", "def", "spa", "spd", "spe", "eva", "acc"]

var profile: AIProfile = AIProfile.for_level(AIProfile.DEFAULT_LEVEL)
var default_level: int = AIProfile.DEFAULT_LEVEL
var team_levels: Dictionary = {}

var _damage := DamageResolver.new()
var _rng := RandomNumberGenerator.new()
var _plans: Dictionary = {}
var _focus: Dictionary = {}
var _profiles: Dictionary = {}


func set_level(value: int) -> void:
	default_level = AIProfile.clamp_level(value)
	_reset()


func set_team_levels(levels: Dictionary) -> void:
	team_levels = levels.duplicate()
	_reset()


func level_for_team(team: int) -> int:
	return AIProfile.clamp_level(int(team_levels.get(team, default_level)))


func _reset() -> void:
	profile = AIProfile.for_level(default_level)
	_profiles.clear()
	_plans.clear()
	_focus.clear()


func _use_profile(unit: TacticsPawn) -> void:
	var wanted: int = level_for_team(_team_of(unit))
	if not _profiles.has(wanted):
		_profiles[wanted] = AIProfile.for_level(wanted)
	profile = _profiles[wanted]


func choose_action(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel = null
) -> AIAction:
	var action := AIAction.new()
	if unit == null or unit.stats == null:
		return action
	var plan: Dictionary = _plan_for(unit, allies, enemies, type_chart, battle_level)
	action.move_index = int(plan.get("move_index", -1))
	action.target_unit = plan.get("target", null)
	action.move_to_tile = plan.get("tile", null)
	action.intent = plan.get("intent", null)
	if action.intent == null and action.move_index >= 0 and action.target_unit != null:
		action.intent = BattleActionIntent.move(unit, action.move_index, action.target_unit)
	return action


func choose_destination(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel = null
) -> TacticsTile:
	var plan: Dictionary = _plan_for(unit, allies, enemies, type_chart, battle_level)
	return plan.get("tile", null)


func forget(unit: TacticsPawn) -> void:
	if unit != null:
		_plans.erase(unit.get_instance_id())


func _plan_for(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel
) -> Dictionary:
	var stamp: int = _turn_stamp(battle_level)
	var slot: int = unit.get_instance_id()
	var cached: Dictionary = _plans.get(slot, {})
	if not cached.is_empty() and int(cached.get("stamp", -1)) == stamp and _plan_is_live(cached):
		return cached
	var plan: Dictionary = _build_plan(unit, allies, enemies, type_chart, battle_level)
	plan["stamp"] = stamp
	_plans[slot] = plan
	return plan


func _plan_is_live(plan: Dictionary) -> bool:
	var target: Variant = plan.get("target", null)
	if target != null and not is_instance_valid(target):
		return false
	var tile: Variant = plan.get("tile", null)
	if tile != null and not is_instance_valid(tile):
		return false
	return true


func _turn_stamp(battle_level: TacticsLevel) -> int:
	if battle_level == null or battle_level.notation == null:
		return -1
	return battle_level.notation.turn_index


func _build_plan(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel
) -> Dictionary:
	_use_profile(unit)
	var plan: Dictionary = {"move_index": -1, "target": null, "tile": null, "intent": null}
	var foes: Array[TacticsPawn] = _living(enemies)
	var friends: Array[TacticsPawn] = _living(allies)
	if foes.is_empty():
		return plan

	var heal: Dictionary = _heal_intent(unit)
	if not heal.is_empty():
		plan["intent"] = heal.get("intent", null)
		plan["target"] = unit
		plan["tile"] = unit.get_tile()
		return plan

	var damage_table: Dictionary = _damage_table(unit, foes, type_chart)
	var retaliation: Dictionary = _retaliation_table(unit, foes, type_chart)
	var focus: TacticsPawn = _focus_target(unit, friends, foes, damage_table, type_chart)
	var origin: Vector3i = _key_of(unit)
	var threat: Array = _threat_sources(unit, foes, type_chart)
	var candidates: Array = _destinations(unit, origin, battle_level)

	var engaging: bool = _can_engage(unit, foes, candidates)
	var best_attack: float = -INF
	var best_support: float = -INF
	var best_idle: float = -INF
	var attack_entry: Dictionary = {}
	var support_entry: Dictionary = {}
	var idle_entry: Dictionary = {}
	for entry in candidates:
		var key: Vector3i = entry["key"]
		var tile: TacticsTile = entry["tile"]
		var positional: float = _positional_score(unit, key, origin, foes, focus, threat, battle_level, engaging)
		for i in range(unit.stats.move_slots.size()):
			var move: PokemonMoveResource = unit.stats.move_slots[i]
			if move == null or not unit.stats.has_pp(i):
				continue
			for target in _candidate_targets(unit, move, foes, friends):
				if not Targeting.key_in_range(key, _key_of(target), unit, move):
					continue
				var value: float = _action_score(unit, move, i, target, damage_table, retaliation, focus, foes)
				if value <= 0.0:
					continue
				var total: float = value + positional
				if move.is_damaging():
					if total > best_attack:
						best_attack = total
						attack_entry = {"move_index": i, "target": target, "tile": tile, "key": key}
				elif total > best_support:
					best_support = total
					support_entry = {"move_index": i, "target": target, "tile": tile, "key": key}
		if positional > best_idle:
			best_idle = positional
			idle_entry = {"move_index": -1, "target": null, "tile": tile, "key": key}

	var best: Dictionary = {}
	if not attack_entry.is_empty():
		best = attack_entry
	elif not support_entry.is_empty():
		best = support_entry
	else:
		best = idle_entry

	if best.is_empty():
		plan["tile"] = unit.get_tile()
		plan["target"] = _nearest(unit, foes)
		return plan

	plan["move_index"] = int(best.get("move_index", -1))
	plan["target"] = best.get("target", null)
	plan["tile"] = best.get("tile", null)
	if plan["target"] == null:
		plan["target"] = _nearest(unit, foes)
	if int(plan["move_index"]) < 0 and profile.use_throwables:
		var thrown: Dictionary = _throw_intent(unit, foes, battle_level)
		if not thrown.is_empty():
			plan["intent"] = thrown.get("intent", null)
			plan["target"] = thrown.get("target", null)
	return plan


func _living(source: Array) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	for entry in source:
		if entry is TacticsPawn and (entry as TacticsPawn).is_alive():
			out.append(entry)
	return out


func _key_of(pawn: TacticsPawn) -> Vector3i:
	if pawn == null:
		return Vector3i.ZERO
	var pos: Vector3 = pawn.global_position if pawn.is_inside_tree() else pawn.position
	return Vector3i(floori(pos.x + 0.5), 0, floori(pos.z + 0.5))


func _manhattan(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.z - b.z)


func _nearest(unit: TacticsPawn, targets: Array[TacticsPawn]) -> TacticsPawn:
	var best: TacticsPawn = null
	var best_distance: int = 1 << 30
	var origin: Vector3i = _key_of(unit)
	for target in targets:
		var distance: int = _manhattan(origin, _key_of(target))
		if distance < best_distance:
			best_distance = distance
			best = target
	return best


func _expected_damage(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource, type_chart: TypeChartResource) -> float:
	if attacker == null or defender == null or move == null:
		return 0.0
	if attacker.stats == null or defender.stats == null:
		return 0.0
	if not move.is_damaging():
		return 0.0
	var effectiveness: float = _damage._effectiveness(move, defender.stats, type_chart)
	if effectiveness <= 0.0:
		return 0.0
	var stab: bool = _damage._is_stab(move.type, attacker.stats.types)
	_rng.seed = ESTIMATE_SEED
	var raw: int = _damage.calculate_damage(attacker.stats, defender.stats, move, effectiveness, stab, 1.0, _rng, {}, true)
	var accuracy: float = clampf(float(move.accuracy) / 100.0, 0.0, 1.0) if move.accuracy > 0 else 1.0
	return float(raw) * accuracy


func _damage_table(unit: TacticsPawn, foes: Array[TacticsPawn], type_chart: TypeChartResource) -> Dictionary:
	var table: Dictionary = {}
	if profile.move_mode != AIProfile.MoveMode.EXPECTED_DAMAGE:
		return table
	for i in range(unit.stats.move_slots.size()):
		var move: PokemonMoveResource = unit.stats.move_slots[i]
		if move == null or not move.is_damaging():
			continue
		var row: Dictionary = {}
		for foe in foes:
			row[foe] = _expected_damage(unit, foe, move, type_chart)
		table[i] = row
	return table


func _best_output(attacker: TacticsPawn, defender: TacticsPawn, type_chart: TypeChartResource) -> float:
	var best: float = 0.0
	if attacker == null or attacker.stats == null:
		return best
	for i in range(attacker.stats.move_slots.size()):
		var move: PokemonMoveResource = attacker.stats.move_slots[i]
		if move == null or not attacker.stats.has_pp(i):
			continue
		best = maxf(best, _expected_damage(attacker, defender, move, type_chart))
	return best


func _reach_of(pawn: TacticsPawn) -> int:
	if pawn == null or pawn.stats == null:
		return 1
	var longest: int = 1
	for i in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[i]
		if move == null or not pawn.stats.has_pp(i):
			continue
		longest = maxi(longest, Targeting.range_distance(pawn, move))
	return pawn.stats.movement + longest


func _threat_sources(unit: TacticsPawn, foes: Array[TacticsPawn], type_chart: TypeChartResource) -> Array:
	var sources: Array = []
	if not profile.threat_aware:
		return sources
	for foe in foes:
		sources.append({
			"key": _key_of(foe),
			"reach": _reach_of(foe),
			"damage": _best_output(foe, unit, type_chart),
		})
	return sources


func _threat_at(key: Vector3i, sources: Array) -> float:
	var total: float = 0.0
	for source in sources:
		if _manhattan(key, source["key"]) <= int(source["reach"]):
			total += float(source["damage"])
	return total


func _destinations(unit: TacticsPawn, origin: Vector3i, battle_level: TacticsLevel) -> Array:
	var out: Array = []
	var own_tile: TacticsTile = unit.get_tile()
	if battle_level == null:
		if own_tile != null:
			out.append({"key": origin, "tile": own_tile})
		return out
	var tiles: Dictionary = Targeting.arena_tile_keys(battle_level)
	_ensure_reachable(unit, own_tile, tiles, battle_level)
	var keys: Array = tiles.keys()
	keys.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	for key in keys:
		var tile: TacticsTile = tiles[key]
		if key == origin or tile.reachable:
			out.append({"key": key, "tile": tile})
	if out.is_empty() and own_tile != null:
		out.append({"key": origin, "tile": own_tile})
	return out


func _candidate_targets(unit: TacticsPawn, move: PokemonMoveResource, foes: Array[TacticsPawn], friends: Array[TacticsPawn]) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	for foe in foes:
		if Targeting.alignment_allows(unit, foe, move):
			out.append(foe)
	if move.is_damaging():
		return out
	if Targeting.alignment_allows(unit, unit, move):
		out.append(unit)
	for friend in friends:
		if friend != unit and Targeting.alignment_allows(unit, friend, move):
			out.append(friend)
	return out


func _families(move: PokemonMoveResource) -> Dictionary:
	var out: Dictionary = {}
	if move == null:
		return out
	for record in move.effect_records:
		var family: String = String((record as Dictionary).get("family", ""))
		var target: String = String((record as Dictionary).get("target", ""))
		out["%s:%s" % [family, target]] = true
		out[family] = true
	return out


func _support_score(unit: TacticsPawn, move: PokemonMoveResource, target: TacticsPawn) -> float:
	var families: Dictionary = _families(move)
	var score: float = 0.0
	if families.has("status:hit_target") and target != unit:
		if not profile.consider_status_moves:
			return 0.0
		if target.stats != null and target.stats.battle_statuses.is_empty():
			score += STATUS_SCORE
	if families.has("stat_stage:self") or (families.has("stat_stage") and target == unit):
		if not profile.consider_setup_moves:
			return 0.0
		score += SETUP_SCORE * _setup_headroom(unit)
	elif families.has("stat_stage:hit_target") and target != unit:
		if not profile.consider_status_moves:
			return 0.0
		score += STATUS_SCORE * 0.6 * _setup_headroom(target)
	if families.has("field_condition") or families.has("weather_stat_stage"):
		if not profile.consider_field_moves:
			return 0.0
		score += FIELD_SCORE
	if families.has("heal") or families.has("cure_statuses") or families.has("status_remove"):
		if target != null and target.stats != null and target.stats.max_health > 0:
			var missing: float = 1.0 - float(target.stats.curr_health) / float(target.stats.max_health)
			score += STATUS_SCORE * missing
	return score


func _setup_headroom(pawn: TacticsPawn) -> float:
	if pawn == null or pawn.stats == null:
		return 0.0
	var used: int = 0
	for key in SETUP_STAT_KEYS:
		used += absi(int(pawn.stats.stat_stages.get(key, 0)))
	return clampf(1.0 - float(used) / 12.0, 0.0, 1.0)


func _target_preference(unit: TacticsPawn, target: TacticsPawn, foes: Array[TacticsPawn]) -> float:
	if target == null or target.stats == null:
		return 0.0
	match profile.target_mode:
		AIProfile.TargetMode.NEAREST:
			return -float(_manhattan(_key_of(unit), _key_of(target)))
		AIProfile.TargetMode.WEAKEST:
			return -float(target.stats.curr_health) * 0.1
		AIProfile.TargetMode.MATCHUP:
			return 0.0
		AIProfile.TargetMode.SECURE_KO:
			return -float(target.stats.curr_health) * 0.05
		AIProfile.TargetMode.EXPECTED_VALUE:
			var danger: float = 0.0
			for foe in foes:
				if foe == target:
					danger = float(foe.stats.attack + foe.stats.special_attack + foe.stats.speed) * 0.02
			return danger - float(target.stats.curr_health) * 0.05
	return 0.0


func _action_score(
		unit: TacticsPawn,
		move: PokemonMoveResource,
		index: int,
		target: TacticsPawn,
		damage_table: Dictionary,
		retaliation: Dictionary,
		focus: TacticsPawn,
		foes: Array[TacticsPawn]
) -> float:
	var hostile: bool = foes.has(target)
	var score: float = 0.0
	if move.is_damaging():
		if not hostile:
			return 0.0
		match profile.move_mode:
			AIProfile.MoveMode.SLOT_ORDER:
				score = 60.0 - float(index)
			AIProfile.MoveMode.RAW_POWER:
				score = float(move.base_power) * (clampf(float(move.accuracy) / 100.0, 0.0, 1.0) if move.accuracy > 0 else 1.0)
			AIProfile.MoveMode.EXPECTED_DAMAGE:
				var expected: float = float((damage_table.get(index, {}) as Dictionary).get(target, 0.0))
				if expected <= 0.0:
					return 0.0
				var remaining: float = maxf(1.0, float(target.stats.curr_health))
				score = 100.0 * minf(expected / remaining, 1.0)
				if expected >= remaining and profile.target_mode >= AIProfile.TargetMode.SECURE_KO:
					score += KO_BONUS
				elif profile.target_mode >= AIProfile.TargetMode.EXPECTED_VALUE:
					var pool: float = maxf(1.0, float(unit.stats.max_health))
					var back: float = float(retaliation.get(target, 0.0))
					score -= RETALIATION_WEIGHT * 100.0 * minf(back / pool, 1.0)
	else:
		score = _support_score(unit, move, target)
		if score <= 0.0:
			return 0.0
	score += _target_preference(unit, target, foes)
	if profile.shared_focus and focus != null and target == focus:
		score += FOCUS_BONUS
	return score


func _focus_target(
		unit: TacticsPawn,
		friends: Array[TacticsPawn],
		foes: Array[TacticsPawn],
		damage_table: Dictionary,
		type_chart: TypeChartResource
) -> TacticsPawn:
	if not profile.shared_focus or foes.is_empty():
		return null
	var team: int = _team_of(unit)
	var stamp: int = foes.size() * 1000 + _round_key(foes)
	var cached: Dictionary = _focus.get(team, {})
	if not cached.is_empty() and int(cached.get("stamp", -1)) == stamp:
		var kept: Variant = cached.get("target", null)
		if kept != null and is_instance_valid(kept) and (kept as TacticsPawn).is_alive():
			return kept
	var best: TacticsPawn = null
	var best_score: float = -INF
	for foe in foes:
		var score: float = 0.0
		if profile.team_assignment:
			var incoming: float = 0.0
			for friend in friends:
				incoming += _best_output(friend, foe, type_chart)
			var remaining: float = maxf(1.0, float(foe.stats.curr_health))
			score = 100.0 * minf(incoming / remaining, 1.5)
			score += float(foe.stats.attack + foe.stats.special_attack) * 0.05
		else:
			score = -float(foe.stats.curr_health)
		if score > best_score:
			best_score = score
			best = foe
	_focus[team] = {"stamp": stamp, "target": best}
	return best


func _round_key(foes: Array[TacticsPawn]) -> int:
	var total: int = 0
	for foe in foes:
		total += foe.stats.curr_health
	return total


func _team_of(unit: TacticsPawn) -> int:
	if unit == null or unit.stats == null or unit.stats.pokemon_instance == null:
		return 0
	return unit.stats.pokemon_instance.team


func _positional_score(
		unit: TacticsPawn,
		key: Vector3i,
		origin: Vector3i,
		foes: Array[TacticsPawn],
		focus: TacticsPawn,
		threat: Array,
		battle_level: TacticsLevel,
		engaging: bool
) -> float:
	var score: float = 0.0
	if profile.avoid_hazards and battle_level != null and battle_level.hazard_service != null:
		if battle_level.hazard_service.threatens(unit, key):
			score -= HAZARD_PENALTY
	var retreating: bool = false
	if profile.retreat_when_losing and not engaging and unit.stats != null and unit.stats.max_health > 0:
		retreating = float(unit.stats.curr_health) / float(unit.stats.max_health) < RETREAT_HP_FRACTION
	var incoming: float = _threat_at(key, threat)
	if profile.threat_aware:
		var pool: float = maxf(1.0, float(unit.stats.max_health)) if unit.stats != null else 1.0
		score -= profile.risk_weight * 100.0 * minf(incoming / pool, 1.5)
		if retreating and incoming <= 0.0:
			score += RETREAT_BONUS
	var anchor: TacticsPawn = focus if (profile.focus_fire_staging and focus != null) else _nearest(unit, foes)
	if anchor != null:
		var distance: int = _manhattan(key, _key_of(anchor))
		if retreating:
			score += profile.approach_weight * APPROACH_SCALE * float(distance) * 0.5
		else:
			score -= profile.approach_weight * APPROACH_SCALE * float(distance)
	if profile.zone_control:
		score += _formation_bonus(unit, key)
	if key == origin:
		score += 0.5
	return score


func _formation_bonus(unit: TacticsPawn, key: Vector3i) -> float:
	var parent: Node = unit.get_parent()
	if parent == null:
		return 0.0
	var nearby: int = 0
	for child in parent.get_children():
		if not (child is TacticsPawn) or child == unit:
			continue
		var ally: TacticsPawn = child
		if not ally.is_alive():
			continue
		if _manhattan(key, _key_of(ally)) <= 2:
			nearby += 1
	return ZONE_BONUS * minf(float(nearby), 2.0)


func _heal_intent(unit: TacticsPawn) -> Dictionary:
	if not profile.use_heal_items:
		return {}
	var held: PokemonItemResource = PokemonItemService.held_item_for(unit.stats)
	if held == null:
		return {}
	var entry: Dictionary = BattleItemCatalog.entry_for(held.item_id)
	if not bool(entry.get("can_use", false)):
		return {}
	var healing: bool = HEAL_ITEM_IDS.has(held.item_id)
	if not healing and profile.full_item_use:
		healing = bool(entry.get("heals", false))
	if not healing:
		return {}
	if unit.stats.curr_health * HEAL_HP_DENOMINATOR >= unit.stats.max_health * HEAL_HP_NUMERATOR:
		return {}
	return {"intent": BattleActionIntent.use_item(unit, held.item_id)}


func _throw_intent(unit: TacticsPawn, foes: Array[TacticsPawn], battle_level: TacticsLevel) -> Dictionary:
	if battle_level == null:
		return {}
	var held: PokemonItemResource = PokemonItemService.held_item_for(unit.stats)
	if held == null:
		return {}
	var entry: Dictionary = BattleItemCatalog.entry_for(held.item_id)
	if not bool(entry.get("can_throw", false)):
		return {}
	var all_units: Array[TacticsPawn] = []
	for foe in foes:
		all_units.append(foe)
	var reach: int = int(entry.get("throw_range", 1))
	for option in Targeting.throw_options(unit, maxi(1, reach), all_units, Targeting.arena_tile_keys(battle_level)):
		var hit: TacticsPawn = option.get("hit_unit", null) as TacticsPawn
		if hit != null and hit.is_alive() and foes.has(hit):
			return {
				"intent": BattleActionIntent.throw_item(unit, held.item_id, option.get("direction", Vector3i.ZERO), hit),
				"target": hit,
			}
	return {}


func _ensure_reachable(unit: TacticsPawn, own_tile: TacticsTile, tiles: Dictionary, battle_level: TacticsLevel) -> void:
	if own_tile == null or battle_level == null or battle_level.arena == null:
		return
	for key in tiles:
		if (tiles[key] as TacticsTile).reachable:
			return
	var allies: Array = unit.get_parent().get_children() if unit.get_parent() != null else []
	battle_level.arena.reset_all_tile_markers()
	battle_level.arena.process_surrounding_tiles(own_tile, unit.stats.movement, allies)
	battle_level.arena.mark_reachable_tiles(own_tile, unit.stats.movement)


func _can_engage(unit: TacticsPawn, foes: Array[TacticsPawn], candidates: Array) -> bool:
	for entry in candidates:
		var key: Vector3i = entry["key"]
		for i in range(unit.stats.move_slots.size()):
			var move: PokemonMoveResource = unit.stats.move_slots[i]
			if move == null or not move.is_damaging() or not unit.stats.has_pp(i):
				continue
			for foe in foes:
				if Targeting.key_in_range(key, _key_of(foe), unit, move):
					return true
	return false


func _retaliation_table(unit: TacticsPawn, foes: Array[TacticsPawn], type_chart: TypeChartResource) -> Dictionary:
	var table: Dictionary = {}
	if profile.target_mode < AIProfile.TargetMode.EXPECTED_VALUE:
		return table
	for foe in foes:
		table[foe] = _best_output(foe, unit, type_chart)
	return table
