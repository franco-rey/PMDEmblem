class_name AIReferenceOracle
extends RefCounted

const ESTIMATE_SEED: int = 991
const VARIANCE_MEAN: float = 95.0
const SCHEDULER_LOOKAHEAD: int = 16
const MULTI_HIT_FIVE_EXPECTED: float = 3.1
const CRIT_DAMAGE_GAIN: float = 0.5
const CONFUSION_HIT_CHANCE: float = 0.75
const BLINDED_HIT_CHANCE: float = 0.6
const HIDDEN_STATUSES: Array[String] = ["airborne", "underground", "underwater", "vanished"]

const VALUE_HEALTH_WEIGHT: float = 1.0
const VALUE_PRIMARY_OFFENSE_WEIGHT: float = 2.2
const VALUE_SECOND_OFFENSE_WEIGHT: float = 0.6
const VALUE_DEFENSE_WEIGHT: float = 0.9
const VALUE_SPEED_WEIGHT: float = 0.8
const VALUE_HEALTH_SHARE: float = 0.35
const VALUE_NORMAL: float = 100.0

const KO_PREMIUM: float = 0.9
const TEMPO_FLOOR: float = 0.45
const REPLY_WEIGHT: float = 0.85
const REPLY_TAIL_WEIGHT: float = 0.30
const FUTURE_WEIGHT: float = 0.45
const APPROACH_WEIGHT: float = 0.8
const HAZARD_PENALTY: float = 8.0
const HOLD_BONUS: float = 0.25

const CHARGE_TEMPO: float = 0.5
const RECHARGE_TEMPO: float = 0.7

const STATUS_DENIAL: float = 0.18
const DEBUFF_DENIAL: float = 0.10
const SETUP_GAIN: float = 0.45
const FIELD_VALUE: float = 3.0
const HEAL_SHARE: float = 0.5
const HEAL_ITEM_FRACTION: float = 0.35
const HEAL_ITEM_IDS: Array[String] = ["berry_oran", "berry_sitrus", "seed_heal"]
const SETUP_STAT_KEYS: Array[String] = ["attack", "defense", "special_attack", "special_defense", "speed", "accuracy", "evasion"]
const SETUP_STAGE_BUDGET: float = 12.0

const KIND_ATTACK: String = "attack"
const KIND_SUPPORT: String = "support"
const KIND_IDLE: String = "idle"
const KIND_ITEM: String = "item"

var _damage := DamageResolver.new()
var _intrinsics := BattleIntrinsicService.new()
var _rng := RandomNumberGenerator.new()
var _cache: Dictionary = {}


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
	var ranked: Array = rank_actions(unit, allies, enemies, type_chart, battle_level)
	if ranked.is_empty():
		action.move_to_tile = unit.get_tile()
		action.target_unit = _nearest(unit, _living(enemies))
		return action
	var best: Dictionary = ranked[0]
	action.move_index = int(best.get("move_index", -1))
	action.target_unit = best.get("target", null)
	action.move_to_tile = best.get("tile", null)
	action.intent = best.get("intent", null)
	if action.target_unit == null:
		action.target_unit = _nearest(unit, _living(enemies))
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
	return choose_action(unit, allies, enemies, type_chart, battle_level).move_to_tile


func rank_actions(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel = null
) -> Array:
	var bundle: Dictionary = _bundle_for(unit, allies, enemies, type_chart, battle_level)
	return bundle.get("ranked", [])


func score_for_action(
		unit: TacticsPawn,
		action: AIAction,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel = null
) -> Dictionary:
	var out: Dictionary = {"score": 0.0, "rank": -1, "matched": false, "legal": false, "id": ""}
	if unit == null or action == null:
		return out
	var bundle: Dictionary = _bundle_for(unit, allies, enemies, type_chart, battle_level)
	var ranked: Array = bundle.get("ranked", [])
	var ctx: Dictionary = bundle.get("ctx", {})
	if ctx.is_empty():
		return out
	var key: Vector3i = Targeting._tile_key(action.move_to_tile) if action.move_to_tile != null else _key_of(unit)
	var wanted: String = _entry_id(_kind_of_action(unit, action), action.move_index, action.target_unit, key)
	out["id"] = wanted
	for i in range(ranked.size()):
		var entry: Dictionary = ranked[i]
		if String(entry.get("id", "")) == wanted:
			out["score"] = float(entry.get("score", 0.0))
			out["rank"] = i
			out["matched"] = true
			out["legal"] = true
			return out
	var direct: Dictionary = _score_free_action(ctx, action, key)
	out["score"] = float(direct.get("score", 0.0))
	out["legal"] = bool(direct.get("legal", false))
	return out


func regret_for(
		unit: TacticsPawn,
		action: AIAction,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel = null
) -> Dictionary:
	var ranked: Array = rank_actions(unit, allies, enemies, type_chart, battle_level)
	var scored: Dictionary = score_for_action(unit, action, allies, enemies, type_chart, battle_level)
	var best: float = float((ranked[0] as Dictionary).get("score", 0.0)) if not ranked.is_empty() else 0.0
	var worst: float = float((ranked[ranked.size() - 1] as Dictionary).get("score", 0.0)) if not ranked.is_empty() else 0.0
	if not bool(scored.get("legal", false)):
		scored["score"] = worst
	return {
		"regret": maxf(0.0, best - float(scored.get("score", 0.0))),
		"best": best,
		"worst": worst,
		"span": maxf(0.0, best - worst),
		"chosen": float(scored.get("score", 0.0)),
		"rank": int(scored.get("rank", -1)),
		"agree": int(scored.get("rank", -1)) == 0,
		"matched": bool(scored.get("matched", false)),
		"legal": bool(scored.get("legal", false)),
		"options": ranked.size(),
	}


func forget(unit: TacticsPawn) -> void:
	if unit != null:
		_cache.erase(unit.get_instance_id())


func clear() -> void:
	_cache.clear()


func _bundle_for(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel
) -> Dictionary:
	if unit == null or unit.stats == null:
		return {}
	var slot: int = unit.get_instance_id()
	var stamp: int = _turn_stamp(battle_level)
	var cached: Dictionary = _cache.get(slot, {})
	if not cached.is_empty() and int(cached.get("stamp", -1)) == stamp and _bundle_is_live(cached):
		return cached
	var ctx: Dictionary = _build_context(unit, allies, enemies, type_chart, battle_level)
	var ranked: Array = _enumerate(ctx)
	var bundle: Dictionary = {"stamp": stamp, "ctx": ctx, "ranked": ranked}
	_cache[slot] = bundle
	return bundle


func _bundle_is_live(bundle: Dictionary) -> bool:
	for entry in bundle.get("ranked", []):
		var tile: Variant = (entry as Dictionary).get("tile", null)
		if tile != null and not is_instance_valid(tile):
			return false
		var target: Variant = (entry as Dictionary).get("target", null)
		if target != null and not is_instance_valid(target):
			return false
	return true


func _turn_stamp(battle_level: TacticsLevel) -> int:
	if battle_level == null or battle_level.notation == null:
		return -1
	return battle_level.notation.turn_index


func _build_context(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel
) -> Dictionary:
	var foes: Array[TacticsPawn] = _living(enemies)
	var friends: Array[TacticsPawn] = _living(allies)
	var ctx: Dictionary = {
		"unit": unit,
		"foes": foes,
		"friends": friends,
		"chart": type_chart,
		"level": battle_level,
		"origin": _key_of(unit),
		"keys": {},
		"value": {},
		"queue": {},
		"my_damage": {},
		"my_hit": {},
		"my_blocked": {},
		"my_tempo": {},
		"foe_options": {},
		"victims": [],
	}
	var roster: Array[TacticsPawn] = []
	for pawn in friends:
		roster.append(pawn)
	for pawn in foes:
		if not roster.has(pawn):
			roster.append(pawn)
	if not roster.has(unit):
		roster.append(unit)
	var total: float = 0.0
	for pawn in roster:
		total += _raw_value(pawn)
	var scale: float = VALUE_NORMAL / maxf(1.0, total / float(maxi(1, roster.size())))
	for pawn in roster:
		(ctx["keys"] as Dictionary)[pawn] = _key_of(pawn)
		(ctx["value"] as Dictionary)[pawn] = _raw_value(pawn) * scale * _health_factor(pawn)
	_fill_queue(ctx, battle_level)

	var victims: Array[TacticsPawn] = []
	victims.append(unit)
	for pawn in friends:
		if pawn != unit:
			victims.append(pawn)
	ctx["victims"] = victims

	for i in range(unit.stats.move_slots.size()):
		var move: PokemonMoveResource = unit.stats.move_slots[i]
		if move == null or not unit.stats.has_pp(i) or not move.is_damaging():
			continue
		var row: Dictionary = {}
		var hits: Dictionary = {}
		var blocked: Dictionary = {}
		for foe in foes:
			row[foe] = _expected_damage(ctx, unit, foe, move)
			hits[foe] = _hit_chance(unit, foe, move)
			blocked[foe] = _survives_lethal(foe, move)
		(ctx["my_damage"] as Dictionary)[i] = row
		(ctx["my_hit"] as Dictionary)[i] = hits
		(ctx["my_blocked"] as Dictionary)[i] = blocked
		(ctx["my_tempo"] as Dictionary)[i] = _move_tempo(unit, move)

	for foe in foes:
		var options: Array = []
		if foe.stats == null:
			(ctx["foe_options"] as Dictionary)[foe] = options
			continue
		for i in range(foe.stats.move_slots.size()):
			var move: PokemonMoveResource = foe.stats.move_slots[i]
			if move == null or not foe.stats.has_pp(i) or not move.is_damaging():
				continue
			var reach: int = foe.stats.movement + Targeting.range_distance(foe, move)
			var tempo: float = _move_tempo(foe, move)
			for victim in victims:
				if not Targeting.alignment_allows(foe, victim, move):
					continue
				var raw: float = _expected_damage(ctx, foe, victim, move)
				if raw <= 0.0:
					continue
				options.append({
					"victim": victim,
					"reach": reach,
					"damage": raw,
					"accuracy": _hit_chance(foe, victim, move),
					"tempo": tempo,
					"blocked": _survives_lethal(victim, move),
				})
		(ctx["foe_options"] as Dictionary)[foe] = options
	return ctx


func _fill_queue(ctx: Dictionary, battle_level: TacticsLevel) -> void:
	if battle_level == null or battle_level.scheduler == null:
		return
	var upcoming: Array[BattleUnit] = battle_level.scheduler.peek_upcoming(SCHEDULER_LOOKAHEAD)
	for i in range(upcoming.size()):
		var entry: BattleUnit = upcoming[i]
		if entry == null or entry.pawn == null:
			continue
		(ctx["queue"] as Dictionary)[entry.pawn] = i


func _tempo_weight(ctx: Dictionary, pawn: TacticsPawn) -> float:
	var queue: Dictionary = ctx["queue"]
	if not queue.has(pawn):
		return TEMPO_FLOOR
	var position: float = clampf(float(int(queue[pawn])) / float(maxi(1, SCHEDULER_LOOKAHEAD)), 0.0, 1.0)
	return lerpf(1.0, TEMPO_FLOOR, position)


func _raw_value(pawn: TacticsPawn) -> float:
	if pawn == null or pawn.stats == null:
		return 1.0
	var stats: Stats = pawn.stats
	var health: float = float(maxi(1, stats.max_health))
	var physical: float = float(stats.attack)
	var special: float = float(stats.special_attack)
	var raw: float = VALUE_HEALTH_WEIGHT * health
	raw += VALUE_PRIMARY_OFFENSE_WEIGHT * maxf(physical, special)
	raw += VALUE_SECOND_OFFENSE_WEIGHT * minf(physical, special)
	raw += VALUE_DEFENSE_WEIGHT * float(stats.defense + stats.special_defense)
	raw += VALUE_SPEED_WEIGHT * float(stats.speed)
	return maxf(1.0, raw)


func _health_factor(pawn: TacticsPawn) -> float:
	if pawn == null or pawn.stats == null or pawn.stats.max_health <= 0:
		return 1.0
	var fraction: float = clampf(float(pawn.stats.curr_health) / float(pawn.stats.max_health), 0.0, 1.0)
	return 1.0 - VALUE_HEALTH_SHARE + VALUE_HEALTH_SHARE * fraction


func _value_of(ctx: Dictionary, pawn: TacticsPawn) -> float:
	return float((ctx["value"] as Dictionary).get(pawn, VALUE_NORMAL))


func _key_for(ctx: Dictionary, pawn: TacticsPawn) -> Vector3i:
	var keys: Dictionary = ctx["keys"]
	if keys.has(pawn):
		return keys[pawn]
	return _key_of(pawn)


func _hit_value(ctx: Dictionary, victim: TacticsPawn, damage: float, blocked_ko: bool = false) -> float:
	if victim == null or victim.stats == null or damage <= 0.0:
		return 0.0
	var pool: float = float(maxi(1, victim.stats.max_health))
	var remaining: float = maxf(1.0, float(victim.stats.curr_health))
	var value: float = _value_of(ctx, victim)
	if blocked_ko and damage >= remaining:
		return value * maxf(0.0, remaining - 1.0) / pool
	var applied: float = minf(damage, remaining)
	var total: float = value * applied / pool
	if damage >= remaining:
		total += value * KO_PREMIUM * _tempo_weight(ctx, victim)
	return total


func _is_lethal(victim: TacticsPawn, damage: float) -> bool:
	if victim == null or victim.stats == null:
		return false
	return damage >= maxf(1.0, float(victim.stats.curr_health))


func _expected_hits(move: PokemonMoveResource) -> float:
	var base: int = maxi(1, move.strike_count)
	if base >= 5:
		return MULTI_HIT_FIVE_EXPECTED
	return float(base)


func _accuracy_of(move: PokemonMoveResource) -> float:
	if move == null:
		return 1.0
	return clampf(float(move.accuracy) / 100.0, 0.0, 1.0) if move.accuracy > 0 else 1.0


func _hit_chance(attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource) -> float:
	var base: float = _accuracy_of(move)
	if attacker == null or attacker.stats == null or defender == null or defender.stats == null:
		return base
	var accuracy_stage: int = int(attacker.stats.stat_stages.get("accuracy", 0))
	var evasion_stage: int = int(defender.stats.stat_stages.get("evasion", 0))
	var combined: int = clampi(accuracy_stage - evasion_stage, -6, 6)
	var scaled: float = base * BattleActionResolver.STAGE_ACCURACY_TABLE[combined + 6]
	if attacker.stats.battle_statuses.has("confuse"):
		scaled *= CONFUSION_HIT_CHANCE
	if attacker.stats.battle_statuses.has("blinker"):
		scaled *= BLINDED_HIT_CHANCE
	return clampf(scaled, 0.0, 1.0)


func _move_unusable(attacker: TacticsPawn, move: PokemonMoveResource) -> bool:
	if attacker == null or attacker.stats == null:
		return false
	var statuses: Dictionary = attacker.stats.battle_statuses
	if statuses.has("disable") and String((statuses["disable"] as Dictionary).get("move_id", "")) == move.move_id:
		return true
	if statuses.has("encore") and String((statuses["encore"] as Dictionary).get("move_id", "")) != move.move_id:
		return true
	if statuses.has("taunted") and not move.is_damaging():
		return true
	return false


func _target_shielded(defender: TacticsPawn, move: PokemonMoveResource) -> bool:
	if defender == null or defender.stats == null:
		return false
	for guard in BattleActionResolver.PROTECTION_STATUSES:
		if defender.stats.battle_statuses.has(guard):
			return true
	for hidden in HIDDEN_STATUSES:
		if defender.stats.battle_statuses.has(hidden):
			return true
	return false


func _survives_lethal(defender: TacticsPawn, move: PokemonMoveResource) -> bool:
	if defender == null or defender.stats == null:
		return false
	if defender.stats.curr_health < defender.stats.max_health:
		return false
	if _expected_hits(move) > 1.0:
		return false
	if _intrinsics.intrinsic_slugs_for(defender.stats).has("sturdy"):
		return true
	var held: PokemonItemResource = PokemonItemService.held_item_for(defender.stats)
	return held != null and held.item_id == "held_focus_sash"


func _move_tempo(pawn: TacticsPawn, move: PokemonMoveResource) -> float:
	var factor: float = 1.0
	if BattleMoveSpecials.CHARGING.has(move.move_id):
		if pawn == null or pawn.stats == null or not pawn.stats.battle_statuses.has("charging"):
			factor *= CHARGE_TEMPO
	if BattleMoveSpecials.RECHARGE_MOVES.has(move.move_id):
		factor *= RECHARGE_TEMPO
	return factor


func _extra_multiplier(ctx: Dictionary, attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource) -> float:
	var multiplier: float = 1.0
	if attacker.stats.battle_statuses.has("burn") and move.category == PokemonMoveResource.CATEGORY_PHYSICAL:
		multiplier *= 2.0 / 3.0
	if attacker.stats.battle_statuses.has("charge") and move.type == "electric":
		multiplier *= 2.0
	var level: TacticsLevel = ctx["level"]
	if level != null:
		multiplier *= level.weather_damage_multiplier(move, defender)
		if move.category == PokemonMoveResource.CATEGORY_PHYSICAL and _has_screen(level, defender, "reflect"):
			multiplier *= 0.5
		elif move.category == PokemonMoveResource.CATEGORY_SPECIAL and _has_screen(level, defender, "light_screen"):
			multiplier *= 0.5
	return multiplier


func _has_screen(level: TacticsLevel, defender: TacticsPawn, condition_id: String) -> bool:
	if defender == null:
		return false
	if defender.stats != null and defender.stats.battle_statuses.has(condition_id):
		return true
	return level.has_team_battle_condition(condition_id, defender)


func _expected_damage(ctx: Dictionary, attacker: TacticsPawn, defender: TacticsPawn, move: PokemonMoveResource) -> float:
	if attacker == null or defender == null or move == null:
		return 0.0
	if attacker.stats == null or defender.stats == null or not move.is_damaging():
		return 0.0
	if _move_unusable(attacker, move) or _target_shielded(defender, move):
		return 0.0
	var chart: TypeChartResource = ctx["chart"]
	var effectiveness: float = _damage._effectiveness(move, defender.stats, chart)
	effectiveness = _intrinsics.adjust_effectiveness(attacker.stats, defender.stats, move, effectiveness, chart)
	if effectiveness <= 0.0:
		return 0.0
	var stab: bool = _damage._is_stab(move.type, attacker.stats.types)
	var outcome: Dictionary = {}
	_rng.seed = ESTIMATE_SEED
	var raw: int = _damage.calculate_damage(
		attacker.stats,
		defender.stats,
		move,
		effectiveness,
		stab,
		_extra_multiplier(ctx, attacker, defender, move),
		_rng,
		outcome,
		true
	)
	if raw <= 0:
		return 0.0
	var variance: float = maxf(1.0, float(int(outcome.get("variance", int(VARIANCE_MEAN)))))
	var centred: float = float(raw) * VARIANCE_MEAN / variance
	var crit_level: int = clampi(_damage._crit_level_for(move), 0, DamageResolver.CRIT_CHANCES.size() - 1)
	var crit_chance: float = float(DamageResolver.CRIT_CHANCES[crit_level]) / float(DamageResolver.CRIT_ROLL_SIDES)
	return centred * _expected_hits(move) * (1.0 + crit_chance * CRIT_DAMAGE_GAIN)


func _enumerate(ctx: Dictionary) -> Array:
	var unit: TacticsPawn = ctx["unit"]
	var foes: Array[TacticsPawn] = ctx["foes"]
	var friends: Array[TacticsPawn] = ctx["friends"]
	var entries: Array = []
	if unit == null or unit.stats == null or foes.is_empty():
		return entries
	var destinations: Array = _destinations(ctx)
	for destination in destinations:
		var key: Vector3i = destination["key"]
		var tile: TacticsTile = destination["tile"]
		var positional: float = _positional_score(ctx, key)
		var idle: Dictionary = _reply_loss(ctx, key, {})
		var idle_future: float = _future_gain(ctx, key, {}) * float(idle["survives"])
		entries.append(_make_entry(KIND_IDLE, -1, null, tile, key, 0.0, float(idle["loss"]), idle_future, positional, null))
		for i in range(unit.stats.move_slots.size()):
			var move: PokemonMoveResource = unit.stats.move_slots[i]
			if move == null or not unit.stats.has_pp(i) or _move_unusable(unit, move):
				continue
			for target in _candidate_targets(unit, move, foes, friends):
				if not Targeting.key_in_range(key, _key_for(ctx, target), unit, move):
					continue
				var outcome: Dictionary = _score_triple(ctx, key, i, move, target)
				if not bool(outcome.get("legal", false)):
					continue
				var kind: String = KIND_ATTACK if move.is_damaging() else KIND_SUPPORT
				entries.append(_make_entry(
					kind,
					i,
					target,
					tile,
					key,
					float(outcome["gain"]),
					float(outcome["reply"]),
					float(outcome["future"]),
					positional,
					null
				))
	var item: Dictionary = _item_entry(ctx)
	if not item.is_empty():
		entries.append(item)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["score"]), float(b["score"])):
			return float(a["score"]) > float(b["score"])
		return String(a["id"]) < String(b["id"]))
	for i in range(entries.size()):
		(entries[i] as Dictionary)["rank"] = i
	return entries


func _empty_outcome() -> Dictionary:
	return {"gain": 0.0, "reply": 0.0, "future": 0.0, "legal": true}


func _make_entry(
		kind: String,
		move_index: int,
		target: TacticsPawn,
		tile: TacticsTile,
		key: Vector3i,
		gain: float,
		reply: float,
		future: float,
		positional: float,
		intent: BattleActionIntent
) -> Dictionary:
	var score: float = gain - REPLY_WEIGHT * reply + FUTURE_WEIGHT * future + positional
	return {
		"id": _entry_id(kind, move_index, target, key),
		"kind": kind,
		"move_index": move_index,
		"target": target,
		"tile": tile,
		"key": key,
		"gain": gain,
		"reply": reply,
		"future": future,
		"positional": positional,
		"score": score,
		"intent": intent,
		"rank": -1,
	}


func _entry_id(kind: String, move_index: int, target: TacticsPawn, key: Vector3i) -> String:
	if kind == KIND_IDLE:
		return "%s|-1|0|%d.%d" % [kind, key.x, key.z]
	var target_id: int = target.get_instance_id() if target != null else 0
	return "%s|%d|%d|%d.%d" % [kind, move_index, target_id, key.x, key.z]


func _kind_of_action(unit: TacticsPawn, action: AIAction) -> String:
	if action.intent != null and action.intent.is_item_action():
		return KIND_ITEM
	if action.move_index < 0:
		return KIND_IDLE
	if unit == null or unit.stats == null or action.move_index >= unit.stats.move_slots.size():
		return KIND_IDLE
	var move: PokemonMoveResource = unit.stats.move_slots[action.move_index]
	if move == null:
		return KIND_IDLE
	return KIND_ATTACK if move.is_damaging() else KIND_SUPPORT


func _score_triple(
		ctx: Dictionary,
		key: Vector3i,
		move_index: int,
		move: PokemonMoveResource,
		target: TacticsPawn,
		strict: bool = true
) -> Dictionary:
	var out: Dictionary = _empty_outcome()
	var unit: TacticsPawn = ctx["unit"]
	var foes: Array[TacticsPawn] = ctx["foes"]
	var friends: Array[TacticsPawn] = ctx["friends"]
	var accuracy: float = _hit_chance(unit, target, move)
	var dead: Dictionary = {}
	var gain: float = 0.0
	if move.is_damaging():
		if not foes.has(target):
			out["legal"] = false
			return out
		var tempo: float = float((ctx["my_tempo"] as Dictionary).get(move_index, _move_tempo(unit, move)))
		var any: bool = false
		for hit in _targets_hit(ctx, move, key, target, foes, friends):
			if hit == null or hit.stats == null:
				continue
			var damage: float = _damage_for(ctx, move_index, move, hit)
			if damage <= 0.0:
				continue
			any = true
			var blocked: bool = _survives_lethal(hit, move)
			var contribution: float = _hit_value(ctx, hit, damage, blocked)
			if _is_lethal(hit, damage) and not blocked:
				dead[hit] = true
			if foes.has(hit):
				gain += contribution
			else:
				gain -= contribution
		if not any and strict:
			out["legal"] = false
			return out
		gain *= tempo
	else:
		gain = _support_value(ctx, move, target)
		if gain <= 0.0 and strict:
			out["legal"] = false
			return out
	var reply_hit: Dictionary = _reply_loss(ctx, key, dead)
	var reply_miss: Dictionary = _reply_loss(ctx, key, {}) if not dead.is_empty() else reply_hit
	var future_hit: float = _future_gain(ctx, key, dead) * float(reply_hit["survives"])
	var future_miss: float = _future_gain(ctx, key, {}) * float(reply_miss["survives"]) if not dead.is_empty() else future_hit
	out["gain"] = accuracy * gain
	out["reply"] = accuracy * float(reply_hit["loss"]) + (1.0 - accuracy) * float(reply_miss["loss"])
	out["future"] = accuracy * future_hit + (1.0 - accuracy) * future_miss
	return out


func _damage_for(ctx: Dictionary, move_index: int, move: PokemonMoveResource, hit: TacticsPawn) -> float:
	var table: Dictionary = ctx["my_damage"]
	if table.has(move_index):
		var row: Dictionary = table[move_index]
		if row.has(hit):
			return float(row[hit])
	return _expected_damage(ctx, ctx["unit"], hit, move)


func _reply_loss(ctx: Dictionary, key: Vector3i, dead: Dictionary) -> Dictionary:
	var unit: TacticsPawn = ctx["unit"]
	var foes: Array[TacticsPawn] = ctx["foes"]
	var options: Dictionary = ctx["foe_options"]
	var best: float = 0.0
	var total: float = 0.0
	var survives: float = 1.0
	for foe in foes:
		if dead.has(foe):
			continue
		var origin: Vector3i = _key_for(ctx, foe)
		var strongest: float = 0.0
		var lethal: float = 0.0
		for option in options.get(foe, []):
			var victim: TacticsPawn = (option as Dictionary)["victim"]
			if victim == null or dead.has(victim):
				continue
			var victim_key: Vector3i = key if victim == unit else _key_for(ctx, victim)
			if _manhattan(origin, victim_key) > int((option as Dictionary)["reach"]):
				continue
			var damage: float = float((option as Dictionary)["damage"])
			var accuracy: float = float((option as Dictionary)["accuracy"])
			var blocked: bool = bool((option as Dictionary)["blocked"])
			var loss: float = _hit_value(ctx, victim, damage, blocked) * accuracy * float((option as Dictionary)["tempo"])
			strongest = maxf(strongest, loss)
			if victim == unit and not blocked and _is_lethal(victim, damage):
				lethal = maxf(lethal, accuracy)
		total += strongest
		best = maxf(best, strongest)
		survives *= 1.0 - lethal
	return {"loss": best + REPLY_TAIL_WEIGHT * (total - best), "survives": clampf(survives, 0.0, 1.0)}


func _future_gain(ctx: Dictionary, key: Vector3i, dead: Dictionary) -> float:
	var unit: TacticsPawn = ctx["unit"]
	var foes: Array[TacticsPawn] = ctx["foes"]
	var table: Dictionary = ctx["my_damage"]
	var best: float = 0.0
	for move_index in table:
		var move: PokemonMoveResource = unit.stats.move_slots[move_index]
		if move == null:
			continue
		var reach: int = unit.stats.movement + Targeting.range_distance(unit, move)
		var tempo: float = float((ctx["my_tempo"] as Dictionary).get(move_index, 1.0))
		var hits: Dictionary = (ctx["my_hit"] as Dictionary).get(move_index, {})
		var blocks: Dictionary = (ctx["my_blocked"] as Dictionary).get(move_index, {})
		for foe in foes:
			if dead.has(foe):
				continue
			if _manhattan(key, _key_for(ctx, foe)) > reach:
				continue
			var damage: float = float((table[move_index] as Dictionary).get(foe, 0.0))
			if damage <= 0.0:
				continue
			var value: float = _hit_value(ctx, foe, damage, bool(blocks.get(foe, false)))
			best = maxf(best, value * float(hits.get(foe, 1.0)) * tempo)
	return best


func _positional_score(ctx: Dictionary, key: Vector3i) -> float:
	var unit: TacticsPawn = ctx["unit"]
	var foes: Array[TacticsPawn] = ctx["foes"]
	var level: TacticsLevel = ctx["level"]
	var score: float = 0.0
	if level != null and level.hazard_service != null and level.hazard_service.threatens(unit, key):
		score -= HAZARD_PENALTY
	var closest: int = 1 << 20
	for foe in foes:
		closest = mini(closest, _manhattan(key, _key_for(ctx, foe)))
	if closest < (1 << 20):
		score -= APPROACH_WEIGHT * float(closest)
	var origin: Vector3i = ctx["origin"]
	if key == origin:
		score += HOLD_BONUS
	return score


func _support_value(ctx: Dictionary, move: PokemonMoveResource, target: TacticsPawn) -> float:
	var unit: TacticsPawn = ctx["unit"]
	var foes: Array[TacticsPawn] = ctx["foes"]
	var families: Dictionary = _families(move)
	var score: float = 0.0
	var hostile: bool = foes.has(target)
	if families.has("status:hit_target") and hostile and target.stats != null and target.stats.battle_statuses.is_empty():
		score += _value_of(ctx, target) * STATUS_DENIAL * _tempo_weight(ctx, target)
	if families.has("stat_stage:self") or (families.has("stat_stage") and target == unit):
		score += _best_output_value(ctx) * SETUP_GAIN * _setup_headroom(unit)
	elif families.has("stat_stage:hit_target") and hostile:
		score += _value_of(ctx, target) * DEBUFF_DENIAL * _setup_headroom(target)
	if families.has("field_condition") or families.has("weather_stat_stage"):
		score += FIELD_VALUE
	if families.has("heal") or families.has("cure_statuses") or families.has("status_remove"):
		if not hostile and target != null and target.stats != null and target.stats.max_health > 0:
			var missing: float = 1.0 - float(target.stats.curr_health) / float(target.stats.max_health)
			score += _value_of(ctx, target) * missing * HEAL_SHARE
	return score


func _best_output_value(ctx: Dictionary) -> float:
	var foes: Array[TacticsPawn] = ctx["foes"]
	var table: Dictionary = ctx["my_damage"]
	var best: float = 0.0
	for move_index in table:
		var hits: Dictionary = (ctx["my_hit"] as Dictionary).get(move_index, {})
		var blocks: Dictionary = (ctx["my_blocked"] as Dictionary).get(move_index, {})
		for foe in foes:
			var damage: float = float((table[move_index] as Dictionary).get(foe, 0.0))
			if damage <= 0.0:
				continue
			var value: float = _hit_value(ctx, foe, damage, bool(blocks.get(foe, false)))
			best = maxf(best, value * float(hits.get(foe, 1.0)))
	return best


func _setup_headroom(pawn: TacticsPawn) -> float:
	if pawn == null or pawn.stats == null:
		return 0.0
	var used: int = 0
	for key in SETUP_STAT_KEYS:
		used += absi(int(pawn.stats.stat_stages.get(key, 0)))
	return clampf(1.0 - float(used) / SETUP_STAGE_BUDGET, 0.0, 1.0)


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


func _item_entry(ctx: Dictionary) -> Dictionary:
	var unit: TacticsPawn = ctx["unit"]
	if unit.stats == null or unit.stats.max_health <= 0:
		return {}
	var held: PokemonItemResource = PokemonItemService.held_item_for(unit.stats)
	if held == null:
		return {}
	var entry: Dictionary = BattleItemCatalog.entry_for(held.item_id)
	if not bool(entry.get("can_use", false)):
		return {}
	if not (HEAL_ITEM_IDS.has(held.item_id) or bool(entry.get("heals", false))):
		return {}
	var missing: float = 1.0 - float(unit.stats.curr_health) / float(unit.stats.max_health)
	if missing <= 0.0:
		return {}
	var restored: float = minf(missing, HEAL_ITEM_FRACTION)
	var gain: float = _value_of(ctx, unit) * restored
	var key: Vector3i = ctx["origin"]
	var reply: Dictionary = _reply_loss(ctx, key, {})
	return _make_entry(
		KIND_ITEM,
		-1,
		unit,
		unit.get_tile(),
		key,
		gain,
		float(reply["loss"]),
		_future_gain(ctx, key, {}) * float(reply["survives"]),
		_positional_score(ctx, key),
		BattleActionIntent.use_item(unit, held.item_id)
	)


func _score_free_action(ctx: Dictionary, action: AIAction, key: Vector3i) -> Dictionary:
	var unit: TacticsPawn = ctx["unit"]
	if unit.stats == null:
		return {"score": 0.0, "legal": false}
	if action.move_index < 0 or action.move_index >= unit.stats.move_slots.size():
		var idle: Dictionary = _reply_loss(ctx, key, {})
		var future: float = _future_gain(ctx, key, {}) * float(idle["survives"])
		var idle_score: float = -REPLY_WEIGHT * float(idle["loss"]) + FUTURE_WEIGHT * future + _positional_score(ctx, key)
		return {"score": idle_score, "legal": true}
	var move: PokemonMoveResource = unit.stats.move_slots[action.move_index]
	var target: TacticsPawn = action.target_unit
	if move == null or target == null or not is_instance_valid(target):
		return {"score": 0.0, "legal": false}
	if not Targeting.key_in_range(key, _key_for(ctx, target), unit, move):
		return {"score": 0.0, "legal": false}
	var outcome: Dictionary = _score_triple(ctx, key, action.move_index, move, target, false)
	if not bool(outcome.get("legal", false)):
		return {"score": 0.0, "legal": false}
	var positional: float = _positional_score(ctx, key)
	var score: float = float(outcome["gain"]) - REPLY_WEIGHT * float(outcome["reply"]) + FUTURE_WEIGHT * float(outcome["future"]) + positional
	return {"score": score, "legal": true}


func _destinations(ctx: Dictionary) -> Array:
	var unit: TacticsPawn = ctx["unit"]
	var battle_level: TacticsLevel = ctx["level"]
	var origin: Vector3i = ctx["origin"]
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


func _candidate_targets(
		unit: TacticsPawn,
		move: PokemonMoveResource,
		foes: Array[TacticsPawn],
		friends: Array[TacticsPawn]
) -> Array[TacticsPawn]:
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


func _targets_hit(
		ctx: Dictionary,
		move: PokemonMoveResource,
		key: Vector3i,
		declared: TacticsPawn,
		foes: Array[TacticsPawn],
		friends: Array[TacticsPawn]
) -> Array[TacticsPawn]:
	var unit: TacticsPawn = ctx["unit"]
	var out: Array[TacticsPawn] = []
	if Targeting.effective_range_kind(move) != PokemonMoveResource.TacticalRangeKind.AREA:
		out.append(declared)
		return out
	for candidate in foes:
		if Targeting.key_in_range(key, _key_for(ctx, candidate), unit, move) and Targeting.alignment_allows(unit, candidate, move):
			out.append(candidate)
	for candidate in friends:
		if candidate == unit:
			continue
		if Targeting.key_in_range(key, _key_for(ctx, candidate), unit, move) and Targeting.alignment_allows(unit, candidate, move):
			out.append(candidate)
	if out.is_empty():
		out.append(declared)
	return out


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
