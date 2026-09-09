class_name BattleSearch
extends BattleAI

const DEFAULT_NODE_BUDGET: int = 400
const ROOT_WIDTH: int = 12
const INNER_WIDTH: int = 6
const DEEP_WIDTH: int = 4
const MIN_PLIES: int = 1
const MAX_PLIES: int = 6
const WIN_SCORE: float = 1000000.0
const TEMPO_WEIGHT: float = 10.0
const SUPPORT_PRIOR: float = 18.0
const ALLY_PRIOR: float = 9.0
const QUIET_WIDTH: int = 3
const QUIET_EVENTS: int = 2
const STAB_MULTIPLIER: float = 1.5
const VARIANCE_MEAN: float = 0.95
const SEED_STEP: int = 2654435761
const QUEUE_PEEK: int = 24
const SEARCH_NOISE: float = 60.0
const UNSET: float = -1.0

var node_budget: int = DEFAULT_NODE_BUDGET
var max_plies: int = MAX_PLIES
var root_width: int = ROOT_WIDTH
var inner_width: int = INNER_WIDTH
var deep_width: int = DEEP_WIDTH
var use_quiescence: bool = true
var deviation_margin: float = 0.0
var search_teams: PackedInt32Array = PackedInt32Array()
var search_min_level: int = AIProfile.MAX_LEVEL
var profile_driven: bool = true
var nodes_searched: int = 0
var plies_reached: int = 0
var last_usec: int = 0
var decisions: int = 0
var total_nodes: int = 0
var total_usec: int = 0
var deviations: int = 0
var fallbacks: int = 0
var peak_usec: int = 0

var _sim: BattleSim = null
var _sim_owner: int = -1
var _pawns: Array[TacticsPawn] = []
var _index: Dictionary = {}
var _share: PackedFloat32Array = PackedFloat32Array()
var _root_team: int = 0
var _stop: bool = false
var _seed: int = 0
var _approach: float = 12.0
var _best_value: float = 0.0
var _greedy_value: float = 0.0
var _est_cache: PackedFloat32Array = PackedFloat32Array()
var _pick_code: PackedInt32Array = PackedInt32Array()
var _pick_score: PackedFloat32Array = PackedFloat32Array()
var _ex: PackedInt32Array = PackedInt32Array()
var _ez: PackedInt32Array = PackedInt32Array()
var _ecount: int = 0
var _ax: PackedInt32Array = PackedInt32Array()
var _az: PackedInt32Array = PackedInt32Array()
var _bx: PackedInt32Array = PackedInt32Array()
var _bz: PackedInt32Array = PackedInt32Array()
var _nb: PackedInt32Array = PackedInt32Array()


func choose_action(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel = null
) -> AIAction:
	return super.choose_action(unit, allies, enemies, type_chart, battle_level)


func set_node_budget(value: int) -> void:
	node_budget = maxi(1, value)
	_plans.clear()


func search_stats() -> Dictionary:
	return {
		"decisions": decisions,
		"nodes": total_nodes,
		"nodes_per_decision": float(total_nodes) / float(maxi(1, decisions)),
		"usec": total_usec,
		"ms_per_decision": float(total_usec) / float(maxi(1, decisions)) / 1000.0,
		"peak_ms": float(peak_usec) / 1000.0,
		"deviations": deviations,
		"deviation_rate": float(deviations) / float(maxi(1, decisions)),
		"fallbacks": fallbacks,
		"last_nodes": nodes_searched,
		"last_plies": plies_reached,
	}


func reset_stats() -> void:
	decisions = 0
	total_nodes = 0
	total_usec = 0
	peak_usec = 0
	deviations = 0
	fallbacks = 0


func _build_plan(
		unit: TacticsPawn,
		allies: Array,
		enemies: Array,
		type_chart: TypeChartResource,
		battle_level: TacticsLevel
) -> Dictionary:
	var greedy: Dictionary = super._build_plan(unit, allies, enemies, type_chart, battle_level)
	if battle_level == null or unit == null or unit.stats == null:
		return greedy
	if greedy.get("intent", null) != null:
		return greedy
	if not search_teams.is_empty() and search_teams.find(_team_of(unit)) < 0:
		return greedy
	if profile_driven:
		if profile.plan_depth <= 0 or profile.node_budget <= 0:
			return greedy
		max_plies = profile.plan_depth
		node_budget = profile.node_budget
		var reach: float = profile.competence if perception_enabled else 1.0
		root_width = maxi(2, int(round(float(ROOT_WIDTH) * reach)))
		inner_width = maxi(2, int(round(float(INNER_WIDTH) * reach)))
		deep_width = maxi(1, int(round(float(DEEP_WIDTH) * reach)))
	if not _ensure_sim(battle_level):
		fallbacks += 1
		return greedy
	var me: int = int(_index.get(unit.get_instance_id(), -1))
	if me < 0 or not unit.is_alive():
		fallbacks += 1
		return greedy
	var started: int = Time.get_ticks_usec()
	var d: PackedInt32Array = _root_state(battle_level, me)
	if d.is_empty():
		fallbacks += 1
		return greedy
	var allowed: Dictionary = {}
	for entry in _destinations(unit, _key_of(unit), battle_level):
		var slot: int = int(_sim.tile_index.get(entry["key"], -1))
		if slot >= 0:
			allowed[slot] = entry["tile"]
	if allowed.is_empty():
		fallbacks += 1
		return greedy
	var greedy_code: int = _encode_plan(greedy)
	var best: int = _run_search(d, me, greedy_code, allowed)
	last_usec = Time.get_ticks_usec() - started
	decisions += 1
	total_nodes += nodes_searched
	total_usec += last_usec
	peak_usec = maxi(peak_usec, last_usec)
	if best < 0:
		fallbacks += 1
		return greedy
	if best == greedy_code:
		return greedy
	if deviation_margin > 0.0 and greedy_code >= 0 and _greedy_value > -INF and _best_value < _greedy_value + deviation_margin:
		return greedy
	var plan: Dictionary = _decode_plan(unit, best, allowed, enemies, allies)
	if plan.is_empty():
		fallbacks += 1
		return greedy
	deviations += 1
	plan["intent"] = null
	return plan


func _ensure_sim(battle_level: TacticsLevel) -> bool:
	var owner: int = battle_level.get_instance_id()
	if _sim != null and _sim_owner == owner and _roster_live(battle_level):
		return true
	_sim = BattleSim.new()
	var probe: PackedInt32Array = _sim.setup_from_level(battle_level)
	if probe.is_empty():
		_sim = null
		_sim_owner = -1
		return false
	_pawns.clear()
	_index.clear()
	for node in [battle_level.player, battle_level.opponent]:
		if node == null:
			continue
		for child in node.get_children():
			if child is TacticsPawn:
				_pawns.append(child as TacticsPawn)
	for i in range(_pawns.size()):
		_index[_pawns[i].get_instance_id()] = i
	if _pawns.size() != _sim.unit_count:
		_sim = null
		_sim_owner = -1
		return false
	_est_cache.resize(BattleSim.SLOT_COUNT * _sim.unit_count)
	_share.resize(_sim.unit_count)
	_ex.resize(_sim.unit_count)
	_ez.resize(_sim.unit_count)
	_ax.resize(_sim.unit_count)
	_az.resize(_sim.unit_count)
	_bx.resize(_sim.unit_count)
	_bz.resize(_sim.unit_count)
	_nb.resize(_sim.unit_count)
	_sim_owner = owner
	return true


func _roster_live(battle_level: TacticsLevel) -> bool:
	var count: int = 0
	for node in [battle_level.player, battle_level.opponent]:
		if node == null:
			continue
		for child in node.get_children():
			if child is TacticsPawn:
				count += 1
	if count != _pawns.size():
		return false
	for pawn in _pawns:
		if not is_instance_valid(pawn):
			return false
	return true


func _root_state(battle_level: TacticsLevel, me: int) -> PackedInt32Array:
	var d: PackedInt32Array = _sim.capture(battle_level)
	if d.is_empty():
		return d
	var fo: int = _sim.field_off
	var order: PackedInt32Array = PackedInt32Array()
	order.append(me)
	if battle_level.scheduler != null:
		for entry in battle_level.scheduler.peek_upcoming(QUEUE_PEEK):
			if entry == null or entry.pawn == null:
				continue
			var idx: int = int(_index.get((entry.pawn as TacticsPawn).get_instance_id(), -1))
			if idx < 0 or idx == me or order.has(idx):
				continue
			if d[idx * BattleSim.U_STRIDE + BattleSim.U_ALIVE] != 1:
				continue
			order.append(idx)
	var length: int = mini(order.size(), _sim.unit_count)
	for i in range(length):
		d[fo + BattleSim.F_QUEUE + i] = order[i]
	d[fo + BattleSim.F_QLEN] = length
	d[fo + BattleSim.F_QPOS] = 1
	d[fo + BattleSim.F_ACTIVE] = me
	d[fo + BattleSim.F_RESULT] = BattleSim.RESULT_ONGOING
	_seed = int(battle_level.battle_rng.state) ^ (me * SEED_STEP)
	return d


func _prepare(d: PackedInt32Array) -> void:
	var total: float = 0.0
	for i in range(_sim.unit_count):
		var base: int = i * BattleSim.U_STRIDE
		var offence: float = float(maxi(d[base + BattleSim.U_ATK], d[base + BattleSim.U_SPA]))
		var value: float = VALUE_OFFENCE_WEIGHT * offence + VALUE_DURABILITY_WEIGHT * float(d[base + BattleSim.U_MAXHP])
		_share[i] = value
		total += value
	var reference: float = maxf(1.0, total / float(maxi(1, _sim.unit_count)))
	for i in range(_sim.unit_count):
		_share[i] = _share[i] / reference
	_approach = profile.approach_weight * APPROACH_SCALE


func _run_search(d: PackedInt32Array, me: int, greedy_code: int, allowed: Dictionary) -> int:
	_root_team = _sim.unit_team(d, me)
	_prepare(d)
	nodes_searched = 0
	plies_reached = 0
	var root: PackedInt32Array = _candidates(d, me, root_width, allowed, false)
	if greedy_code >= 0 and root.find(greedy_code) < 0 and _legal_here(d, me, greedy_code):
		root.append(greedy_code)
	if root.is_empty():
		return -1
	var best: int = greedy_code if root.find(greedy_code) >= 0 else root[0]
	_best_value = -INF
	_greedy_value = -INF
	for plies in range(MIN_PLIES, max_plies + 1):
		_stop = false
		var alpha: float = -INF
		var local_best: int = -1
		var local_value: float = -INF
		var local_greedy: float = -INF
		var ordered: PackedInt32Array = _promote(root, best)
		for i in range(ordered.size()):
			var code: int = ordered[i]
			var child: PackedInt32Array = d.duplicate()
			_sim.set_rng_state(child, _node_seed(0))
			_sim.apply_packed(child, code)
			nodes_searched += 1
			var value: float = _value(child, plies - 1, alpha, INF, 1)
			if _stop:
				break
			if code == greedy_code:
				local_greedy = value
			if value > local_value:
				local_value = value
				local_best = code
			if value > alpha:
				alpha = value
		if local_best >= 0:
			best = local_best
			_best_value = local_value
			_greedy_value = local_greedy
			plies_reached = plies
		if _stop or nodes_searched >= node_budget:
			break
	return best


func _promote(source: PackedInt32Array, first: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if source.find(first) >= 0:
		out.append(first)
	for code in source:
		if code != first:
			out.append(code)
	return out


func _value(d: PackedInt32Array, plies: int, alpha: float, beta: float, depth: int) -> float:
	if _sim.is_over(d):
		return _terminal(d)
	if nodes_searched >= node_budget:
		_stop = true
		return _eval(d)
	if plies <= 0:
		if use_quiescence:
			return _quiesce(d, alpha, beta, depth, QUIET_EVENTS)
		return _eval(d)
	var unit: int = _sim.active_unit(d)
	if unit < 0:
		return _eval(d)
	var width: int = inner_width if depth <= 1 else deep_width
	var candidates: PackedInt32Array = _candidates(d, unit, width, {}, false)
	if candidates.is_empty():
		return _eval(d)
	var maximizing: bool = _sim.unit_team(d, unit) == _root_team
	var value: float = -INF if maximizing else INF
	var local_alpha: float = alpha
	var local_beta: float = beta
	for i in range(candidates.size()):
		var child: PackedInt32Array = d.duplicate()
		_sim.set_rng_state(child, _node_seed(depth))
		_sim.apply_packed(child, candidates[i])
		nodes_searched += 1
		var score: float = _value(child, plies - 1, local_alpha, local_beta, depth + 1)
		if _stop:
			return _eval(d)
		if maximizing:
			if score > value:
				value = score
			if value > local_alpha:
				local_alpha = value
		else:
			if score < value:
				value = score
			if value < local_beta:
				local_beta = value
		if local_beta <= local_alpha:
			break
	return value


func _quiesce(d: PackedInt32Array, alpha: float, beta: float, depth: int, left: int) -> float:
	if _sim.is_over(d):
		return _terminal(d)
	var standing: float = _eval(d)
	if left <= 0:
		return standing
	if nodes_searched >= node_budget:
		_stop = true
		return standing
	var unit: int = _sim.active_unit(d)
	if unit < 0:
		return standing
	if not _knockout_pending(d, unit):
		return standing
	var candidates: PackedInt32Array = _candidates(d, unit, QUIET_WIDTH, {}, true)
	if candidates.is_empty():
		return standing
	var maximizing: bool = _sim.unit_team(d, unit) == _root_team
	var value: float = standing
	var local_alpha: float = alpha
	var local_beta: float = beta
	if maximizing:
		if value > local_alpha:
			local_alpha = value
	elif value < local_beta:
		local_beta = value
	for i in range(candidates.size()):
		var child: PackedInt32Array = d.duplicate()
		_sim.set_rng_state(child, _node_seed(depth))
		_sim.apply_packed(child, candidates[i])
		nodes_searched += 1
		var score: float = _quiesce(child, local_alpha, local_beta, depth + 1, left - 1)
		if _stop:
			return standing
		if maximizing:
			if score > value:
				value = score
			if value > local_alpha:
				local_alpha = value
		else:
			if score < value:
				value = score
			if value < local_beta:
				local_beta = value
		if local_beta <= local_alpha:
			break
	return value


func _knockout_pending(d: PackedInt32Array, unit: int) -> bool:
	var base: int = unit * BattleSim.U_STRIDE
	var team: int = d[base + BattleSim.U_TEAM]
	var reach: int = d[base + BattleSim.U_MOVEMENT]
	var ux: int = d[base + BattleSim.U_X]
	var uz: int = d[base + BattleSim.U_Z]
	_est_cache.fill(UNSET)
	for slot in range(BattleSim.SLOT_COUNT):
		var mi: int = d[base + BattleSim.U_MOVE + slot]
		if mi < 0 or d[base + BattleSim.U_PP + slot] <= 0:
			continue
		var info: int = mi * BattleSim.M_STRIDE
		if _sim.move_info[info + BattleSim.M_DAMAGING] != 1:
			continue
		var span: int = reach + maxi(1, _sim.move_info[info + BattleSim.M_RANGE])
		for target in range(_sim.unit_count):
			var tbase: int = target * BattleSim.U_STRIDE
			if d[tbase + BattleSim.U_ALIVE] != 1 or d[tbase + BattleSim.U_TEAM] == team:
				continue
			if absi(ux - d[tbase + BattleSim.U_X]) + absi(uz - d[tbase + BattleSim.U_Z]) > span:
				continue
			if _estimate(d, unit, target, slot, mi) >= float(d[tbase + BattleSim.U_HP]):
				return true
	return false


func _terminal(d: PackedInt32Array) -> float:
	var outcome: int = _sim.result(d)
	if outcome == BattleSim.RESULT_DRAW or outcome == BattleSim.RESULT_ONGOING:
		return 0.0
	var winner: int = 0 if outcome == BattleSim.RESULT_TEAM0 else 1
	return WIN_SCORE if winner == _root_team else -WIN_SCORE


func _shake() -> float:
	if not perception_enabled or profile.competence >= 1.0:
		return 0.0
	return (_hash01(nodes_searched) * 2.0 - 1.0) * SEARCH_NOISE * profile.shortfall


func _eval(d: PackedInt32Array) -> float:
	var total: float = 0.0
	var count: int = _sim.unit_count
	var home: int = 0
	var away: int = 0
	for i in range(count):
		var base: int = i * BattleSim.U_STRIDE
		var team: int = d[base + BattleSim.U_TEAM]
		var sign: float = 1.0 if team == _root_team else -1.0
		if d[base + BattleSim.U_ALIVE] != 1:
			total -= sign * KO_BONUS * _share[i]
			continue
		total += sign * 100.0 * _share[i] * float(d[base + BattleSim.U_HP]) / float(maxi(1, d[base + BattleSim.U_MAXHP]))
		if team == 0:
			_ax[home] = d[base + BattleSim.U_X]
			_az[home] = d[base + BattleSim.U_Z]
			home += 1
		else:
			_bx[away] = d[base + BattleSim.U_X]
			_bz[away] = d[base + BattleSim.U_Z]
			_nb[away] = 1 << 30
			away += 1
	if home > 0 and away > 0:
		var home_sign: float = _approach if _root_team == 0 else -_approach
		for a in range(home):
			var ax: int = _ax[a]
			var az: int = _az[a]
			var nearest: int = 1 << 30
			for b in range(away):
				var span: int = absi(ax - _bx[b]) + absi(az - _bz[b])
				if span < nearest:
					nearest = span
				if span < _nb[b]:
					_nb[b] = span
			total -= home_sign * float(nearest)
		for b in range(away):
			total += home_sign * float(_nb[b])
	var fo: int = _sim.field_off
	for q in range(d[fo + BattleSim.F_QPOS], d[fo + BattleSim.F_QLEN]):
		var queued: int = d[fo + BattleSim.F_QUEUE + q] * BattleSim.U_STRIDE
		if d[queued + BattleSim.U_ALIVE] != 1:
			continue
		total += TEMPO_WEIGHT if d[queued + BattleSim.U_TEAM] == _root_team else -TEMPO_WEIGHT
	return total + _shake()


func _candidates(d: PackedInt32Array, unit: int, width: int, allowed: Dictionary, killers: bool) -> PackedInt32Array:
	var actions: PackedInt32Array = _sim.legal_actions_packed(d, unit)
	if actions.is_empty():
		return actions
	var base: int = unit * BattleSim.U_STRIDE
	var team: int = d[base + BattleSim.U_TEAM]
	_collect_foes(d, team)
	_est_cache.fill(UNSET)
	if _pick_code.size() < width:
		_pick_code.resize(width)
		_pick_score.resize(width)
	var held: int = 0
	var last_dest: int = -1
	var last_pen: float = 0.0
	var filtered: bool = not allowed.is_empty()
	var stride: int = BattleSim.U_STRIDE
	var move_base: int = base + BattleSim.U_MOVE
	var info_table: PackedInt32Array = _sim.move_info
	var unit_total: int = _sim.unit_count
	for code in actions:
		var dest: int = code >> 12
		if filtered and not allowed.has(dest):
			continue
		var slot: int = ((code >> 6) & 63) - 1
		var target: int = (code & 63) - 1
		if dest != last_dest:
			last_dest = dest
			last_pen = _dest_penalty(dest)
		var score: float = last_pen
		var lethal: bool = false
		if slot >= 0 and target >= 0:
			var tbase: int = target * stride
			if d[tbase + BattleSim.U_TEAM] != team:
				var mi: int = d[move_base + slot]
				if mi >= 0 and info_table[mi * BattleSim.M_STRIDE + BattleSim.M_DAMAGING] == 1:
					var key: int = slot * unit_total + target
					var estimate: float = _est_cache[key]
					if estimate == UNSET:
						estimate = _estimate(d, unit, target, slot, mi)
					var remaining: float = maxf(1.0, float(d[tbase + BattleSim.U_HP]))
					score += 100.0 * minf(estimate / remaining, 1.0)
					if estimate >= remaining:
						score += KO_BONUS
						lethal = true
				else:
					score += SUPPORT_PRIOR
			else:
				score += ALLY_PRIOR
		if killers and not lethal:
			continue
		if held >= width:
			if score <= _pick_score[width - 1]:
				continue
			var slide: int = width - 1
			while slide > 0 and _pick_score[slide - 1] < score:
				_pick_score[slide] = _pick_score[slide - 1]
				_pick_code[slide] = _pick_code[slide - 1]
				slide -= 1
			_pick_score[slide] = score
			_pick_code[slide] = code
			continue
		var at: int = held
		while at > 0 and _pick_score[at - 1] < score:
			_pick_score[at] = _pick_score[at - 1]
			_pick_code[at] = _pick_code[at - 1]
			at -= 1
		_pick_score[at] = score
		_pick_code[at] = code
		held += 1
	var out: PackedInt32Array = PackedInt32Array()
	for i in range(held):
		out.append(_pick_code[i])
	return out


func _collect_foes(d: PackedInt32Array, team: int) -> void:
	_ecount = 0
	for i in range(_sim.unit_count):
		var base: int = i * BattleSim.U_STRIDE
		if d[base + BattleSim.U_ALIVE] != 1 or d[base + BattleSim.U_TEAM] == team:
			continue
		_ex[_ecount] = d[base + BattleSim.U_X]
		_ez[_ecount] = d[base + BattleSim.U_Z]
		_ecount += 1


func _dest_penalty(dest: int) -> float:
	if _ecount == 0:
		return 0.0
	var tx: int = _sim.tile_x[dest]
	var tz: int = _sim.tile_z[dest]
	var nearest: int = 1 << 30
	for e in range(_ecount):
		var span: int = absi(tx - _ex[e]) + absi(tz - _ez[e])
		if span < nearest:
			nearest = span
	return -_approach * float(nearest)


func _estimate(d: PackedInt32Array, attacker: int, target: int, slot: int, mi: int) -> float:
	var key: int = slot * _sim.unit_count + target
	if _est_cache[key] != UNSET:
		return _est_cache[key]
	var info: int = mi * BattleSim.M_STRIDE
	var power: int = _sim.move_info[info + BattleSim.M_POWER]
	if power <= 0:
		_est_cache[key] = 0.0
		return 0.0
	var abase: int = attacker * BattleSim.U_STRIDE
	var tbase: int = target * BattleSim.U_STRIDE
	var move_type: int = _sim.move_info[info + BattleSim.M_TYPE]
	var types: int = _sim.type_count
	var effect: float = _sim.eff_table[(move_type * types + d[tbase + BattleSim.U_TYPE1]) * types + d[tbase + BattleSim.U_TYPE2]]
	if effect <= 0.0:
		_est_cache[key] = 0.0
		return 0.0
	var physical: bool = _sim.move_info[info + BattleSim.M_CAT] == PokemonMoveResource.CATEGORY_PHYSICAL
	var attack: int = d[abase + (BattleSim.U_ATK if physical else BattleSim.U_SPA)]
	var defence: int = d[tbase + (BattleSim.U_DEF if physical else BattleSim.U_SPD)]
	var level_term: int = int(d[abase + BattleSim.U_LEVEL] / 3) + 6
	var raw: float = float(level_term * maxi(attack, 1) * power)
	if move_type == d[abase + BattleSim.U_TYPE1] or move_type == d[abase + BattleSim.U_TYPE2]:
		raw *= STAB_MULTIPLIER
	raw *= effect
	raw = raw / float(maxi(defence, 1)) / 50.0 * VARIANCE_MEAN
	raw *= float(maxi(1, _sim.move_info[info + BattleSim.M_STRIKE]))
	var accuracy: int = _sim.move_info[info + BattleSim.M_ACC]
	if accuracy > 0 and accuracy < 100:
		raw *= float(accuracy) / 100.0
	_est_cache[key] = raw
	return raw


func _node_seed(depth: int) -> int:
	return _seed ^ ((depth + 1) * SEED_STEP)


func _legal_here(d: PackedInt32Array, unit: int, code: int) -> bool:
	return _sim.legal_actions_packed(d, unit).find(code) >= 0


func _encode_plan(plan: Dictionary) -> int:
	var tile: Variant = plan.get("tile", null)
	if tile == null or not is_instance_valid(tile):
		return -1
	var dest: int = int(_sim.tile_index.get(Targeting._tile_key(tile as TacticsTile), -1))
	if dest < 0:
		return -1
	var slot: int = int(plan.get("move_index", -1))
	var target: Variant = plan.get("target", null)
	var index: int = -1
	if target != null and is_instance_valid(target):
		index = int(_index.get((target as TacticsPawn).get_instance_id(), -1))
	if slot < 0 or index < 0:
		return dest << 12
	return (dest << 12) | ((slot + 1) << 6) | (index + 1)


func _decode_plan(unit: TacticsPawn, code: int, allowed: Dictionary, enemies: Array, _allies: Array) -> Dictionary:
	var dest: int = code >> 12
	if not allowed.has(dest):
		return {}
	var tile: TacticsTile = allowed[dest]
	if tile == null or not is_instance_valid(tile):
		return {}
	var slot: int = ((code >> 6) & 63) - 1
	var index: int = (code & 63) - 1
	var plan: Dictionary = {"move_index": -1, "target": null, "tile": tile, "intent": null}
	if slot < 0 or index < 0 or index >= _pawns.size():
		plan["target"] = _nearest(unit, _living(enemies))
		return plan
	var target: TacticsPawn = _pawns[index]
	if not is_instance_valid(target) or not target.is_alive():
		return {}
	if slot >= unit.stats.move_slots.size():
		return {}
	var move: PokemonMoveResource = unit.stats.move_slots[slot]
	if move == null or not unit.stats.has_pp(slot):
		return {}
	var key: Vector3i = Targeting._tile_key(tile)
	var aim: Vector3i = key if target == unit else _key_of(target)
	if not Targeting.key_in_range(key, aim, unit, move):
		return {}
	if not Targeting.alignment_allows(unit, target, move):
		return {}
	plan["move_index"] = slot
	plan["target"] = target
	return plan
