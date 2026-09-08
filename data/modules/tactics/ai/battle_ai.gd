class_name BattleAI
extends RefCounted

const ESTIMATE_SEED: int = 991
const KO_BONUS: float = 220.0
const FOCUS_BONUS: float = 45.0
const FOCUS_GAIN: float = 1.35
const HAZARD_PENALTY: float = 60.0
const STATUS_SCORE: float = 40.0
const SETUP_SCORE: float = 34.0
const FIELD_SCORE: float = 26.0
const APPROACH_SCALE: float = 12.0
const RETALIATION_WEIGHT: float = 0.45
const INVALID_SCORE: float = -1000000.0
const NEAREST_WEIGHT: float = 2.0
const WEAKEST_WEIGHT: float = 0.25
const SECURE_WEIGHT: float = 0.15
const DANGER_WEIGHT: float = 0.25
const TEMPO_BONUS: float = 70.0
const WINDOW_BONUS: float = 22.0
const CHIP_RISK: float = 60.0
const LETHAL_RISK: float = 120.0
const LETHAL_FLOOR: float = 0.85
const LETHAL_BAND: float = 0.35
const SCHEDULER_LOOKAHEAD: int = 12
const DAMAGE_SAMPLES: int = 11
const VARIANCE_LOW: float = 0.88
const VARIANCE_HIGH: float = 1.14
const CHIP_WEIGHT: float = 0.55
const VALUE_OFFENCE_WEIGHT: float = 1.0
const VALUE_DURABILITY_WEIGHT: float = 0.45
const RETREAT_HP_FRACTION: float = 0.3
const RETREAT_BONUS: float = 55.0
const ZONE_BONUS: float = 6.0
const HEAL_ITEM_IDS: Array[String] = ["berry_oran", "berry_sitrus", "seed_heal"]
const HEAL_HP_NUMERATOR: int = 1
const HEAL_HP_DENOMINATOR: int = 2
const SETUP_STAT_KEYS: Array[String] = ["attack", "defense", "special_attack", "special_defense", "speed", "accuracy", "evasion"]

var profile: AIProfile = AIProfile.for_level(AIProfile.DEFAULT_LEVEL)
var default_level: int = AIProfile.DEFAULT_LEVEL
var team_levels: Dictionary = {}

var _damage := DamageResolver.new()
var _rng := RandomNumberGenerator.new()
var _plans: Dictionary = {}
var _chart: TypeChartResource = null
var _shapes: Dictionary = {}
var _reference_value: float = 1.0
var _level_ref: TacticsLevel = null
var _output_memo: Dictionary = {}
var _focus_cache: Dictionary = {}
var _memo_stamp: int = -9999
var _intrinsics := BattleIntrinsicService.new()
var _specials := BattleMoveSpecials.new()
var _scheduler: BattleScheduler = null
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
	_chart = type_chart
	var memo_stamp: int = _turn_stamp(battle_level)
	if memo_stamp != _memo_stamp:
		_memo_stamp = memo_stamp
		_output_memo.clear()
	_scheduler = battle_level.scheduler if battle_level != null else null
	_level_ref = battle_level
	var plan: Dictionary = {"move_index": -1, "target": null, "tile": null, "intent": null}
	var foes: Array[TacticsPawn] = _living(enemies)
	var friends: Array[TacticsPawn] = _living(allies)
	if foes.is_empty():
		return plan

	var damage_table: Dictionary = _damage_table(unit, foes, type_chart)
	var retaliation: Dictionary = _retaliation_table(unit, foes, type_chart)
	_shapes = _shape_table(unit, foes, friends, type_chart)
	_reference_value = _mean_value(foes, friends)

	if not _has_lethal(unit, foes, damage_table):
		var heal: Dictionary = _heal_intent(unit)
		if not heal.is_empty():
			plan["intent"] = heal.get("intent", null)
			plan["target"] = unit
			plan["tile"] = unit.get_tile()
			return plan

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
				var aim: Vector3i = key if target == unit else _key_of(target)
				if not Targeting.key_in_range(key, aim, unit, move):
					continue
				var value: float = _action_score(unit, move, i, target, key, damage_table, retaliation, focus, foes, friends)
				if value <= INVALID_SCORE:
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
	elif not support_entry.is_empty() and best_support > best_idle:
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
		var thrown: Dictionary = _throw_intent(unit, foes, friends, battle_level)
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
	if profile.consider_ability_items:
		effectiveness = _intrinsics.adjust_effectiveness(attacker.stats, defender.stats, move, effectiveness, type_chart)
	if effectiveness <= 0.0:
		return 0.0
	var stab: bool = _damage._is_stab(move.type, attacker.stats.types)
	_rng.seed = ESTIMATE_SEED
	var raw: int = _damage.calculate_damage(attacker.stats, defender.stats, move, effectiveness, stab, 1.0, _rng, {}, true)
	var accuracy: float = clampf(float(move.accuracy) / 100.0, 0.0, 1.0) if move.accuracy > 0 else 1.0
	return float(raw) * accuracy


func _damage_profile(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource, type_chart: TypeChartResource) -> Dictionary:
	var empty: Dictionary = {"mean": 0.0, "samples": PackedInt32Array()}
	if attacker == null or defender == null or move == null:
		return empty
	if attacker.stats == null or defender.stats == null or not move.is_damaging():
		return empty
	var effectiveness: float = _damage._effectiveness(move, defender.stats, type_chart)
	if profile.consider_ability_items:
		effectiveness = _intrinsics.adjust_effectiveness(attacker.stats, defender.stats, move, effectiveness, type_chart)
	if effectiveness <= 0.0:
		return empty
	if _move_unusable(attacker, move):
		return empty
	if _target_shielded(defender, move):
		return empty
	var stab: bool = _damage._is_stab(move.type, attacker.stats.types)
	var accuracy: float = _hit_chance(attacker, defender, move)
	var hits: float = _expected_hits(attacker, move)
	if _is_charging_move(move) and not _charge_pending(attacker):
		hits *= 0.5
	_rng.seed = ESTIMATE_SEED
	var probe: int = int(round(float(_damage.calculate_damage(attacker.stats, defender.stats, move, effectiveness, stab, 1.0, _rng, {}, true)) * hits))
	var remaining: float = maxf(1.0, float(defender.stats.curr_health))
	var lower: float = remaining * VARIANCE_LOW
	var upper: float = remaining * VARIANCE_HIGH
	if float(probe) < lower:
		return {"mean": float(probe), "certain": 0.0, "accuracy": accuracy}
	if float(probe) > upper:
		return {"mean": float(probe), "certain": 1.0, "accuracy": accuracy}
	var samples: PackedInt32Array = PackedInt32Array()
	var total: float = 0.0
	for i in range(DAMAGE_SAMPLES):
		_rng.seed = ESTIMATE_SEED + i * 7919
		var rolled: int = int(round(float(_damage.calculate_damage(attacker.stats, defender.stats, move, effectiveness, stab, 1.0, _rng, {}, true)) * hits))
		samples.append(rolled)
		total += float(rolled)
	return {"mean": total / float(DAMAGE_SAMPLES), "samples": samples, "accuracy": accuracy}


func _shape_table(unit: TacticsPawn, foes: Array[TacticsPawn], friends: Array[TacticsPawn], type_chart: TypeChartResource) -> Dictionary:
	var table: Dictionary = {}
	if not profile.use_ko_probability:
		return table
	for i in range(unit.stats.move_slots.size()):
		var move: PokemonMoveResource = unit.stats.move_slots[i]
		if move == null or not move.is_damaging() or not unit.stats.has_pp(i):
			continue
		var row: Dictionary = {}
		for foe in foes:
			row[foe] = _damage_profile(unit, foe, move, type_chart)
		table[i] = row
	return table


func _mean_value(foes: Array[TacticsPawn], friends: Array[TacticsPawn]) -> float:
	var total: float = 0.0
	var count: int = 0
	for pawn in foes:
		total += _unit_value(pawn)
		count += 1
	for pawn in friends:
		total += _unit_value(pawn)
		count += 1
	return maxf(1.0, total / float(maxi(1, count)))


func _ko_chance(sample: Dictionary, remaining: float) -> float:
	var accuracy: float = float(sample.get("accuracy", 1.0))
	if sample.has("certain"):
		return float(sample["certain"]) * accuracy
	var samples: PackedInt32Array = sample.get("samples", PackedInt32Array())
	if samples.is_empty():
		return 0.0
	var hits: int = 0
	for value in samples:
		if float(value) >= remaining:
			hits += 1
	return accuracy * float(hits) / float(samples.size())


func _unit_value(pawn: TacticsPawn) -> float:
	if pawn == null or pawn.stats == null:
		return 0.0
	var offence: float = float(maxi(pawn.stats.attack, pawn.stats.special_attack))
	var durability: float = float(pawn.stats.max_health)
	return VALUE_OFFENCE_WEIGHT * offence + VALUE_DURABILITY_WEIGHT * durability


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
	if attacker == null or attacker.stats == null or defender == null:
		return best
	var memo_row: Dictionary = _output_memo.get(attacker.get_instance_id(), {})
	if memo_row.has(defender.get_instance_id()):
		return float(memo_row[defender.get_instance_id()])
	for i in range(attacker.stats.move_slots.size()):
		var move: PokemonMoveResource = attacker.stats.move_slots[i]
		if move == null or not attacker.stats.has_pp(i):
			continue
		best = maxf(best, _expected_damage(attacker, defender, move, type_chart))
	memo_row[defender.get_instance_id()] = best
	_output_memo[attacker.get_instance_id()] = memo_row
	return best


func _reach_of(pawn: TacticsPawn) -> Dictionary:
	if pawn == null or pawn.stats == null:
		return {"reach": 1, "wide": false}
	var longest: int = 1
	var wide: bool = false
	for i in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[i]
		if move == null or not pawn.stats.has_pp(i):
			continue
		var span: int = Targeting.range_distance(pawn, move)
		if span >= longest:
			longest = span
			wide = Targeting.effective_range_kind(move) == PokemonMoveResource.TacticalRangeKind.PROJECTILE
	return {"reach": pawn.stats.movement + longest, "wide": wide}


func _threat_sources(unit: TacticsPawn, foes: Array[TacticsPawn], type_chart: TypeChartResource) -> Array:
	var sources: Array = []
	if not profile.threat_aware:
		return sources
	var allies: Array = unit.get_parent().get_children() if unit.get_parent() != null else []
	for foe in foes:
		var span: Dictionary = _reach_of(foe)
		var probe: Dictionary = {"key": _key_of(foe), "reach": int(span["reach"]), "wide": bool(span["wide"])}
		var covered: int = 0
		for ally in allies:
			if not (ally is TacticsPawn) or not (ally as TacticsPawn).is_alive():
				continue
			if _covers(_key_of(ally), probe):
				covered += 1
		sources.append({
			"key": probe["key"],
			"reach": int(probe["reach"]),
			"wide": bool(probe["wide"]),
			"damage": _best_output(foe, unit, type_chart),
			"share": 1.0 / float(maxi(1, covered)),
		})
	return sources


func _threat_at(key: Vector3i, sources: Array) -> float:
	var total: float = 0.0
	for source in sources:
		if _covers(key, source):
			total += float(source["damage"]) * float(source.get("share", 1.0))
	return total


func _worst_single(key: Vector3i, sources: Array) -> float:
	var worst: float = 0.0
	for source in sources:
		if _covers(key, source):
			worst = maxf(worst, float(source["damage"]))
	return worst


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
	var rooted: bool = unit.res != null and not unit.res.can_move
	for key in keys:
		var tile: TacticsTile = tiles[key]
		if key == origin or (tile.reachable and not rooted):
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
		var entry: Dictionary = record
		var family: String = String(entry.get("family", ""))
		var target: String = String(entry.get("target", ""))
		if family == "stat_stage":
			var stages: Dictionary = entry.get("stages", {})
			var rises: bool = false
			var falls: bool = false
			for stat in stages.keys():
				if int(stages[stat]) > 0:
					rises = true
				elif int(stages[stat]) < 0:
					falls = true
			if int(entry.get("delta", 0)) > 0:
				rises = true
			elif int(entry.get("delta", 0)) < 0:
				falls = true
			if rises:
				out["stat_raise:%s" % target] = true
			if falls:
				out["stat_drop:%s" % target] = true
			if not rises and not falls:
				out["stat_drop:%s" % target] = true
		out["%s:%s" % [family, target]] = true
		out[family] = true
	return out


func _support_score(unit: TacticsPawn, move: PokemonMoveResource, target: TacticsPawn) -> float:
	var families: Dictionary = _families(move)
	var score: float = 0.0
	if families.has("status:hit_target") and target != unit and profile.consider_status_moves:
		if target.stats != null and target.stats.battle_statuses.is_empty():
			score += STATUS_SCORE
	if families.has("stat_raise:self") or (families.has("stat_stage") and target == unit and not families.has("stat_drop:self")):
		if profile.consider_setup_moves:
			score += SETUP_SCORE * _setup_headroom(unit)
	elif families.has("stat_drop:hit_target") and target != unit and profile.consider_status_moves:
		score += STATUS_SCORE * 0.6 * _setup_headroom(target)
	if (families.has("field_condition") or families.has("weather_stat_stage")) and profile.consider_field_moves and not _field_already_set(move):
		score += FIELD_SCORE
	if families.has("heal") or families.has("cure_statuses") or families.has("status_remove"):
		if target != null and target.stats != null and target.stats.max_health > 0:
			var missing: float = 1.0 - float(target.stats.curr_health) / float(target.stats.max_health)
			score += STATUS_SCORE * missing
	return score


func _setup_headroom(pawn: TacticsPawn) -> float:
	if pawn == null or pawn.stats == null:
		return 0.0
	var highest: int = 0
	for key in SETUP_STAT_KEYS:
		highest = maxi(highest, absi(int(pawn.stats.stat_stages.get(key, 0))))
	return clampf(1.0 - float(highest) / 6.0, 0.0, 1.0)


func _action_score(
		unit: TacticsPawn,
		move: PokemonMoveResource,
		index: int,
		target: TacticsPawn,
		key: Vector3i,
		damage_table: Dictionary,
		retaliation: Dictionary,
		focus: TacticsPawn,
		foes: Array[TacticsPawn],
		friends: Array[TacticsPawn]
) -> float:
	var hostile: bool = foes.has(target)
	var base: float = 0.0
	var modifiers: float = 0.0
	if move.is_damaging():
		if not hostile:
			return INVALID_SCORE
		match profile.move_mode:
			AIProfile.MoveMode.SLOT_ORDER:
				base = 60.0 - float(index)
			AIProfile.MoveMode.RAW_POWER:
				var chart_gain: float = _damage._effectiveness(move, target.stats, _chart) if target.stats != null else 1.0
				if chart_gain <= 0.0:
					return INVALID_SCORE
				base = float(move.base_power) * _accuracy_of(move) * chart_gain
			AIProfile.MoveMode.EXPECTED_DAMAGE:
				base = _damage_value(unit, move, index, target, key, damage_table, foes, friends, focus)
		if base <= 0.0:
			return INVALID_SCORE
		if profile.target_mode >= AIProfile.TargetMode.EXPECTED_VALUE and not _is_lethal(unit, move, index, target, damage_table):
			var pool: float = maxf(1.0, float(unit.stats.max_health))
			modifiers -= RETALIATION_WEIGHT * 100.0 * minf(float(retaliation.get(target, 0.0)) / pool, 1.0)
	else:
		base = _support_score(unit, move, target)
		if base <= 0.0:
			return INVALID_SCORE
	if hostile:
		modifiers += _target_preference(unit, target, retaliation)
		if not move.is_damaging() and profile.shared_focus and focus != null and target == focus:
			modifiers += FOCUS_BONUS
	return base + modifiers


func _accuracy_of(move: PokemonMoveResource) -> float:
	return clampf(float(move.accuracy) / 100.0, 0.0, 1.0) if move.accuracy > 0 else 1.0


func _expected_for(unit: TacticsPawn, move: PokemonMoveResource, index: int, target: TacticsPawn, damage_table: Dictionary) -> float:
	var row: Dictionary = damage_table.get(index, {})
	if row.has(target):
		return float(row[target])
	return _expected_damage(unit, target, move, _chart)


func _is_lethal(unit: TacticsPawn, move: PokemonMoveResource, index: int, target: TacticsPawn, damage_table: Dictionary) -> bool:
	if target == null or target.stats == null:
		return false
	if _survives_lethal(target, move):
		return false
	return _expected_for(unit, move, index, target, damage_table) >= maxf(1.0, float(target.stats.curr_health))


func _has_lethal(unit: TacticsPawn, foes: Array[TacticsPawn], damage_table: Dictionary) -> bool:
	for i in range(unit.stats.move_slots.size()):
		var move: PokemonMoveResource = unit.stats.move_slots[i]
		if move == null or not move.is_damaging() or not unit.stats.has_pp(i):
			continue
		for foe in foes:
			if _is_lethal(unit, move, i, foe, damage_table):
				return true
	return false


func _targets_hit(
		unit: TacticsPawn,
		move: PokemonMoveResource,
		key: Vector3i,
		declared: TacticsPawn,
		foes: Array[TacticsPawn],
		friends: Array[TacticsPawn]
) -> Array[TacticsPawn]:
	var out: Array[TacticsPawn] = []
	if Targeting.effective_range_kind(move) != PokemonMoveResource.TacticalRangeKind.AREA:
		out.append(declared)
		return out
	for candidate in foes:
		if Targeting.key_in_range(key, _key_of(candidate), unit, move) and Targeting.alignment_allows(unit, candidate, move):
			out.append(candidate)
	if out.is_empty():
		out.append(declared)
	return out


func _damage_value(
		unit: TacticsPawn,
		move: PokemonMoveResource,
		index: int,
		target: TacticsPawn,
		key: Vector3i,
		damage_table: Dictionary,
		foes: Array[TacticsPawn],
		friends: Array[TacticsPawn],
		focus: TacticsPawn
) -> float:
	var total: float = 0.0
	for hit in _targets_hit(unit, move, key, target, foes, friends):
		if hit == null or hit.stats == null:
			continue
		var remaining: float = maxf(1.0, float(hit.stats.curr_health))
		var value: float = 0.0
		var shape: Dictionary = (_shapes.get(index, {}) as Dictionary).get(hit, {})
		if profile.use_ko_probability and not shape.is_empty():
			var chance: float = 0.0 if _survives_lethal(hit, move) else _ko_chance(shape, remaining)
			var mean: float = float(shape.get("mean", 0.0))
			if mean <= 0.0:
				continue
			var share: float = _unit_value(hit) / _reference_value if profile.value_weighted else 1.0
			var chip: float = minf(mean / remaining, 1.0)
			value = 100.0 * share * (chance + (1.0 - chance) * CHIP_WEIGHT * chip)
			if chance > 0.0 and profile.turn_order_aware and _acts_before(unit, hit):
				value += TEMPO_BONUS * chance
		else:
			var expected: float = _expected_for(unit, move, index, hit, damage_table)
			if expected <= 0.0:
				continue
			value = 100.0 * minf(expected / remaining, 1.0)
			if expected >= remaining and profile.target_mode >= AIProfile.TargetMode.SECURE_KO:
				value += KO_BONUS
				if profile.turn_order_aware and _acts_before(unit, hit):
					value += TEMPO_BONUS
		if profile.shared_focus and focus != null and hit == focus:
			value *= FOCUS_GAIN
		total += value
	return total


func _acts_before(unit: TacticsPawn, target: TacticsPawn) -> bool:
	if _scheduler == null or target == null:
		return false
	for upcoming in _scheduler.peek_upcoming(SCHEDULER_LOOKAHEAD):
		if upcoming == null or upcoming.pawn == null:
			continue
		if upcoming.pawn == target:
			return true
		if upcoming.pawn == unit:
			return false
	return false


func _target_preference(unit: TacticsPawn, target: TacticsPawn, retaliation: Dictionary) -> float:
	if target == null or target.stats == null or target.stats.max_health <= 0:
		return 0.0
	var hp_fraction: float = float(target.stats.curr_health) / float(target.stats.max_health)
	match profile.target_mode:
		AIProfile.TargetMode.NEAREST:
			return -float(_manhattan(_key_of(unit), _key_of(target))) * NEAREST_WEIGHT
		AIProfile.TargetMode.WEAKEST:
			return -100.0 * hp_fraction * WEAKEST_WEIGHT
		AIProfile.TargetMode.MATCHUP:
			return 0.0
		AIProfile.TargetMode.SECURE_KO:
			return -100.0 * hp_fraction * SECURE_WEIGHT
		AIProfile.TargetMode.EXPECTED_VALUE:
			return -100.0 * hp_fraction * SECURE_WEIGHT
	return 0.0


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
	var round_key: int = _level_ref.round_index if _level_ref != null else -1
	var held: Dictionary = _focus_cache.get(team, {})
	if int(held.get("round", -9999)) == round_key:
		var kept: Variant = held.get("target", null)
		if kept != null and is_instance_valid(kept) and (kept as TacticsPawn).is_alive() and foes.has(kept):
			return kept
	var best: TacticsPawn = null
	var best_score: float = -INF
	for foe in foes:
		var score: float = 0.0
		if profile.team_assignment:
			var incoming: float = 0.0
			var hands: int = 0
			for friend in friends:
				if friend == null or not friend.is_alive():
					continue
				if not _within_window(friend, foe):
					continue
				hands += 1
				incoming += _best_output(friend, foe, type_chart)
			var remaining: float = maxf(1.0, float(foe.stats.curr_health))
			score = 100.0 * minf(incoming / remaining, 1.5)
			score += WINDOW_BONUS * float(hands)
			score += 100.0 * (_unit_value(foe) / _reference_value) * 0.15
		else:
			score = -float(foe.stats.curr_health)
		if score > best_score:
			best_score = score
			best = foe
	_focus_cache[team] = {"round": round_key, "target": best}
	return best


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
	if profile.threat_aware and engaging:
		var pool: float = maxf(1.0, float(unit.stats.curr_health)) if unit.stats != null else 1.0
		var spread: float = _threat_at(key, threat)
		var worst: float = _worst_single(key, threat)
		var chip: float = minf(spread / pool, 1.0)
		var combined: float = maxf(worst, _raw_threat_at(key, threat))
		var lethal: float = clampf(combined / pool - LETHAL_FLOOR, 0.0, LETHAL_BAND) / LETHAL_BAND
		score -= profile.risk_weight * (CHIP_RISK * chip + LETHAL_RISK * lethal)
		if retreating and spread <= 0.0:
			score += RETREAT_BONUS
	var anchor: TacticsPawn = focus if (profile.focus_fire_staging and focus != null and not engaging) else _nearest(unit, foes)
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


func _throw_intent(unit: TacticsPawn, foes: Array[TacticsPawn], friends: Array[TacticsPawn], battle_level: TacticsLevel) -> Dictionary:
	if battle_level == null:
		return {}
	if unit.res != null and not unit.res.pathfinding_tilestack.is_empty():
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
	for friend in friends:
		if friend != unit:
			all_units.append(friend)
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
	if unit.res != null and not unit.res.can_move:
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


func _expected_hits(attacker: TacticsPawn, move: PokemonMoveResource) -> float:
	var count: int = move.strike_count if "strike_count" in move else 1
	if count <= 1:
		return 1.0
	if count >= 5:
		return 5.0 if _intrinsics.intrinsic_slugs_for(attacker.stats).has("skill_link") else 3.1
	return float(count)


func _is_charging_move(move: PokemonMoveResource) -> bool:
	return BattleMoveSpecials.CHARGING.has(move.move_id)


func _charge_pending(attacker: TacticsPawn) -> bool:
	return attacker.stats != null and attacker.stats.battle_statuses.has("charging")


func _move_unusable(attacker: TacticsPawn, move: PokemonMoveResource) -> bool:
	if attacker.stats == null:
		return false
	var statuses: Dictionary = attacker.stats.battle_statuses
	if statuses.has("disable") and String((statuses["disable"] as Dictionary).get("move_id", "")) == move.move_id:
		return true
	if statuses.has("encore") and String((statuses["encore"] as Dictionary).get("move_id", "")) != move.move_id:
		return true
	if statuses.has("taunted") and not move.is_damaging():
		return true
	if statuses.has("charging") and String(attacker.stats.last_used_move_id) != move.move_id:
		return true
	return false


func _target_shielded(defender: TacticsPawn, move: PokemonMoveResource) -> bool:
	if defender.stats == null:
		return false
	for guard in BattleActionResolver.PROTECTION_STATUSES:
		if defender.stats.battle_statuses.has(guard):
			return true
	for hidden in ["airborne", "underground", "underwater", "vanished"]:
		if defender.stats.battle_statuses.has(hidden):
			return true
	if _intrinsics.intrinsic_slugs_for(defender.stats).has("wonder_guard"):
		var chart_value: float = _damage._effectiveness(move, defender.stats, _chart)
		if chart_value <= 1.0:
			return true
	return false


func _hit_chance(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource) -> float:
	if move.accuracy <= 0:
		return 1.0
	var base: float = clampf(float(move.accuracy) / 100.0, 0.0, 1.0)
	var accuracy_stage: int = int(attacker.stats.stat_stages.get("accuracy", 0)) if attacker.stats != null else 0
	var evasion_stage: int = int(defender.stats.stat_stages.get("evasion", 0)) if defender.stats != null else 0
	var combined: int = clampi(accuracy_stage - evasion_stage, -6, 6)
	var scaled: float = base * BattleActionResolver.STAGE_ACCURACY_TABLE[combined + 6]
	if attacker.stats != null and attacker.stats.battle_statuses.has("confuse"):
		scaled *= 0.5
	return clampf(scaled, 0.0, 1.0)


func _survives_lethal(defender: TacticsPawn, move: PokemonMoveResource) -> bool:
	if defender.stats == null or defender.stats.curr_health < defender.stats.max_health:
		return false
	if _expected_hits(defender, move) > 1.0:
		return false
	if _intrinsics.intrinsic_slugs_for(defender.stats).has("sturdy"):
		return true
	var held: PokemonItemResource = PokemonItemService.held_item_for(defender.stats)
	return held != null and held.item_id == "held_focus_sash"


func _field_already_set(move: PokemonMoveResource) -> bool:
	if _level_ref == null or _level_ref.battle_conditions == null:
		return false
	var wanted: String = ""
	for record in move.effect_records:
		var entry: Dictionary = record
		if String(entry.get("family", "")) in ["field_condition", "weather_stat_stage"]:
			wanted = String(entry.get("condition_id", entry.get("weather", entry.get("terrain", ""))))
	if wanted.is_empty():
		return false
	var live: Variant = _level_ref.battle_conditions
	if live is Dictionary:
		for key in (live as Dictionary).keys():
			if String(key).findn(wanted) >= 0 or wanted.findn(String(key)) >= 0:
				return true
	return false


func _covers(key: Vector3i, source: Dictionary) -> bool:
	var origin: Vector3i = source["key"]
	var reach: int = int(source["reach"])
	if bool(source.get("wide", false)):
		return maxi(absi(key.x - origin.x), absi(key.z - origin.z)) <= reach
	return _manhattan(key, origin) <= reach


func _within_window(ally: TacticsPawn, foe: TacticsPawn) -> bool:
	if ally == null or ally.stats == null or foe == null:
		return false
	if ally.res != null and ally.res.has_acted_this_round:
		return false
	var span: Dictionary = _reach_of(ally)
	return _covers(_key_of(foe), {"key": _key_of(ally), "reach": int(span["reach"]), "wide": bool(span["wide"])})


func _raw_threat_at(key: Vector3i, sources: Array) -> float:
	var total: float = 0.0
	for source in sources:
		if _covers(key, source):
			total += float(source["damage"])
	return total
