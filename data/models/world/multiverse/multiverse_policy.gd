class_name MultiversePolicy
extends RefCounted

const KIND_BRANCH: String = "branch"
const KIND_HOP: String = "hop"
const KIND_NEW: String = "new"
const OFFENCE_WEIGHT: float = 1.0
const DURABILITY_WEIGHT: float = 0.45
const LINEAR_LEVEL: int = 2
const BRANCH_LEVEL: int = 4
const RELUCTANT_LEVEL: int = 4
const RELUCTANT_SCALE: float = 1.5
const OPTION_COST_SCALE: float = 0.35
const TRAVEL_NOISE_SCALE: float = 0.25
const NOISE_STEP: int = 2654435761
const HOP_FLOOR: float = 1.0
const STRIKE_WEIGHT: float = 0.5
const SUSPENSION_WEIGHT: float = 0.05
const SUSPENSION_CAP: int = 6
const SURVIVAL_WEIGHT: float = 0.35
const SURVIVAL_CAP: float = 2.0
const MARGIN_EPSILON: float = 8.0
const TIE_BAND: float = 4.0
const UNSCORED: float = -1.0e30

var mv: MultiverseController = null
var level_override: int = 0


func setup(controller: MultiverseController) -> void:
	mv = controller


func choose(options: Array, pending: Dictionary) -> int:
	if mv == null or mv.level == null or options.is_empty():
		return -1
	return decide(options, context_for(pending))


func context_for(pending: Dictionary) -> Dictionary:
	var state: MultiverseState = mv.state
	var side: int = int(pending.get("side", MultiverseState.SIDE_PLAYER))
	var mine: int = state.created_by_player if side == MultiverseState.SIDE_PLAYER else state.created_by_enemy
	var theirs: int = state.created_by_enemy if side == MultiverseState.SIDE_PLAYER else state.created_by_player
	var move_id: String = String(pending.get("move_id", ""))
	var leaving: Dictionary = {}
	for pawn in mv.travellers_for(move_id, pending.get("user", null), pending.get("target", null)):
		leaving[pawn] = true
	var origin_pre: Array[Dictionary] = []
	var origin_post: Array[Dictionary] = []
	var travellers: Array[Dictionary] = []
	for team_node in [mv.level.player, mv.level.opponent]:
		var team: int = PokemonInstanceResource.Team.PLAYER if team_node == mv.level.player else PokemonInstanceResource.Team.ENEMY
		for child in team_node.get_children():
			if not (child is TacticsPawn):
				continue
			var record: Dictionary = pawn_record(child, team)
			origin_pre.append(record)
			if leaving.has(child):
				travellers.append(record)
			else:
				origin_post.append(record)
	var focus: int = state.focus.x
	var global_records: Array[Dictionary] = []
	var standing_records: Array[Dictionary] = []
	global_records.append_array(origin_pre)
	standing_records.append_array(origin_post)
	for l in state.active_timelines():
		if l != focus:
			global_records.append_array(board_records(state.latest(l)))
			standing_records.append_array(board_records(state.latest(l)))
	return {
		"level": _level_for(side),
		"noise": AIProfile.for_level(_level_for(side)).value_noise * TRAVEL_NOISE_SCALE,
		"seed": int(mv.level.battle_rng.state) if mv.level.battle_rng != null else 0,
		"side": side,
		"mine": mine,
		"theirs": theirs,
		"turn": mv.level.round_index,
		"strike": bool(mv.travel_rule(move_id).get("strike", false)),
		"origin_pre": origin_pre,
		"origin_post": origin_post,
		"travellers": travellers,
		"origin_board": origin_pre,
		"global_margin": margin(global_records, side),
		"standing_mine": standing(standing_records, team_of(side)),
		"unfreeze_margin": _unfreeze_margin(side, mine, theirs),
		"option_cost": _option_cost(origin_pre, side),
	}


func _level_for(side: int) -> int:
	if level_override > 0:
		return AIProfile.clamp_level(level_override)
	var team: int = team_of(side)
	return AIProfile.clamp_level(int(mv.level.ai_team_levels.get(team, mv.level.ai_level)))


func _unfreeze_margin(side: int, mine: int, theirs: int) -> float:
	var band: int = mini(mine, theirs) + 1
	var after: int = mini(mine + 1, theirs) + 1
	if after <= band:
		return 0.0
	var records: Array[Dictionary] = []
	for l in mv.state.timeline_ids():
		if absi(l) > band and absi(l) <= after:
			records.append_array(board_records(mv.state.latest(l)))
	return margin(records, side)


func _option_cost(records: Array, side: int) -> float:
	var strongest: float = 0.0
	for record in records:
		if bool(record.get("alive", false)):
			strongest = maxf(strongest, unit_value(record))
	var standing: int = mv.state.standing_total(PokemonInstanceResource.Team.PLAYER) + mv.state.standing_total(PokemonInstanceResource.Team.ENEMY)
	var scale: float = clampf(float(standing) / float(_initial_total()), 0.0, 1.0)
	return strongest * scale * OPTION_COST_SCALE


func _initial_total() -> int:
	var list: Array = mv.state.boards(0)
	if list.is_empty():
		return 1
	var root: BoardSnapshot = list.front()
	return maxi(1, root.standing(PokemonInstanceResource.Team.PLAYER) + root.standing(PokemonInstanceResource.Team.ENEMY))


static func judgement(context: Dictionary, index: int) -> float:
	var noise: float = float(context.get("noise", 0.0))
	if noise <= 0.0:
		return 0.0
	var h: int = (int(context.get("seed", 0)) ^ ((index + 1) * NOISE_STEP)) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	h = (h ^ (h >> 16)) & 0x7fffffff
	return (float(h) / 2147483647.0 * 2.0 - 1.0) * noise


static func decide(options: Array, context: Dictionary) -> int:
	var hop: int = best_hop(options, context)
	if hop >= 0:
		return hop
	return best_branch(options, context)


static func best_hop(options: Array, context: Dictionary) -> int:
	var side: int = int(context.get("side", MultiverseState.SIDE_PLAYER))
	var origin_pre: Array = context.get("origin_pre", [])
	var origin_post: Array = context.get("origin_post", [])
	var travellers: Array = context.get("travellers", [])
	var strike: bool = bool(context.get("strike", false))
	var origin_swing: float = risk(origin_pre, side) - risk(origin_post, side)
	var best: int = -1
	var best_score: float = HOP_FLOOR
	for i in range(options.size()):
		var option: Dictionary = options[i]
		if String(option.get("kind", "")) != KIND_HOP:
			continue
		var dest: Array[Dictionary] = board_records(option.get("board", null))
		var arrived: Array[Dictionary] = []
		arrived.append_array(dest)
		arrived.append_array(travellers)
		var score: float = origin_swing + risk(dest, side) - risk(arrived, side) + judgement(context, i)
		if strike:
			score += STRIKE_WEIGHT * (strike_value(dest, side) - strike_value(origin_post, side))
		if score > best_score:
			best_score = score
			best = i
	return best


static func best_branch(options: Array, context: Dictionary) -> int:
	var side: int = int(context.get("side", MultiverseState.SIDE_PLAYER))
	if int(context.get("mine", 0)) > int(context.get("theirs", 0)):
		return -1
	var origin_pre: Array = context.get("origin_pre", [])
	var origin_post: Array = context.get("origin_post", [])
	var travellers: Array = context.get("travellers", [])
	var turn: int = int(context.get("turn", 0))
	var margin_origin: float = margin(origin_post, side)
	if standing(origin_post, team_of(side)) == 0 and margin(origin_pre, side) >= 0.0:
		return -1
	var global_margin: float = float(context.get("global_margin", 0.0))
	var unfreeze: float = float(context.get("unfreeze_margin", 0.0))
	var option_cost: float = float(context.get("option_cost", 0.0))
	var defensive: bool = margin_origin < 0.0
	var scores: Array[float] = []
	var turns: Array[int] = []
	var best_score: float = 0.0
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var kind: String = String(option.get("kind", ""))
		scores.append(UNSCORED)
		turns.append(turn)
		if kind != KIND_BRANCH and kind != KIND_NEW:
			continue
		var dest: Array = board_records(option.get("board", null)) if kind == KIND_BRANCH else context.get("origin_board", [])
		var arrived: Array[Dictionary] = []
		arrived.append_array(dest)
		arrived.append_array(travellers)
		if margin(arrived, side) < margin_origin - MARGIN_EPSILON and not defensive:
			continue
		var dest_turn: int = int((option.get("from", Vector2i(0, turn)) as Vector2i).y)
		var distance: float = float(clampi(turn - dest_turn, 0, SUSPENSION_CAP))
		var relief: float = SUSPENSION_WEIGHT * distance * maxf(0.0, -margin_origin)
		var share: float = clampf(float(standing(arrived, team_of(side))) / float(maxi(1, int(context.get("standing_mine", 0)))), 0.0, SURVIVAL_CAP)
		var survival: float = SURVIVAL_WEIGHT * maxf(0.0, -global_margin) * share
		var score: float = margin(arrived, side) + unfreeze - global_margin + relief + survival - option_cost + judgement(context, i)
		scores[i] = score
		turns[i] = dest_turn
		best_score = maxf(best_score, score)
	if best_score <= 0.0:
		return -1
	var chosen: int = -1
	var chosen_turn: int = 0
	for i in range(options.size()):
		if scores[i] <= 0.0 or scores[i] < best_score - TIE_BAND:
			continue
		if chosen < 0 or (turns[i] < chosen_turn if defensive else turns[i] > chosen_turn):
			chosen = i
			chosen_turn = turns[i]
	return chosen


static func lands_frozen(kind: String, mine: int, theirs: int) -> bool:
	return kind != KIND_HOP and mine > theirs


static func unit_value(record: Dictionary) -> float:
	return OFFENCE_WEIGHT * float(record.get("offence", 0.0)) + DURABILITY_WEIGHT * float(record.get("max_health", 0.0))


static func health_fraction(record: Dictionary) -> float:
	return clampf(float(record.get("curr_health", 0.0)) / maxf(1.0, float(record.get("max_health", 0.0))), 0.0, 1.0)


static func strength(records: Array, team: int) -> float:
	var total: float = 0.0
	for record in records:
		if int(record.get("team", -1)) == team and bool(record.get("alive", false)):
			total += unit_value(record) * health_fraction(record)
	return total


static func standing(records: Array, team: int) -> int:
	var count: int = 0
	for record in records:
		if int(record.get("team", -1)) == team and bool(record.get("alive", false)):
			count += 1
	return count


static func margin(records: Array, side: int) -> float:
	return strength(records, team_of(side)) - strength(records, other_team(side))


static func risk(records: Array, side: int) -> float:
	return maxf(0.0, -margin(records, side))


static func strike_value(records: Array, side: int) -> float:
	var best: float = 0.0
	for record in records:
		if int(record.get("team", -1)) == other_team(side) and bool(record.get("alive", false)):
			best = maxf(best, unit_value(record) * (1.0 - health_fraction(record)))
	return best


static func team_of(side: int) -> int:
	return PokemonInstanceResource.Team.PLAYER if side == MultiverseState.SIDE_PLAYER else PokemonInstanceResource.Team.ENEMY


static func other_team(side: int) -> int:
	return PokemonInstanceResource.Team.ENEMY if side == MultiverseState.SIDE_PLAYER else PokemonInstanceResource.Team.PLAYER


static func board_records(board: BoardSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if board == null:
		return out
	for entry in board.units:
		var stats: Dictionary = entry.get("stats", {})
		out.append({
			"team": int(entry.get("team", -1)),
			"alive": bool(entry.get("alive", false)),
			"offence": float(maxi(int(stats.get("attack", 0)), int(stats.get("special_attack", 0)))),
			"curr_health": float(stats.get("curr_health", 0)),
			"max_health": float(stats.get("max_health", 1)),
		})
	return out


static func pawn_record(pawn: TacticsPawn, team: int) -> Dictionary:
	var stats: Stats = pawn.stats
	if stats == null:
		return {"team": team, "alive": false, "offence": 0.0, "curr_health": 0.0, "max_health": 1.0}
	return {
		"team": team,
		"alive": pawn.is_alive(),
		"offence": float(maxi(stats.attack, stats.special_attack)),
		"curr_health": float(stats.curr_health),
		"max_health": float(stats.max_health),
	}
