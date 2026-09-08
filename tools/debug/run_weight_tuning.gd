extends SceneTree

const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const OUTPUT_DIR: String = "res://logs/debug/tuning"
const ESTIMATE_SEED: int = 991
const DAMAGE_SAMPLES: int = 11
const VARIANCE_LOW: float = 0.88
const VARIANCE_HIGH: float = 1.14
const SCHEDULER_LOOKAHEAD: int = 12
const INVALID_SCORE: float = -1000000.0
const SETUP_STAT_KEYS: Array[String] = ["attack", "defense", "special_attack", "special_defense", "speed", "accuracy", "evasion"]

const FEATURE_NAMES: Array[String] = [
	"alive",
	"hp",
	"alive_off",
	"alive_bulk",
	"hp_off",
	"hp_bulk",
	"threat",
	"lethal",
	"stages",
	"status",
	"hazard",
	"conc",
	"tempo",
	"formation",
	"speed",
	"dist",
]

const BASE_WEIGHTS: Dictionary = {
	"KO_BONUS": 220.0,
	"FOCUS_BONUS": 45.0,
	"FOCUS_GAIN": 1.35,
	"HAZARD_PENALTY": 60.0,
	"STATUS_SCORE": 40.0,
	"SETUP_SCORE": 34.0,
	"FIELD_SCORE": 26.0,
	"APPROACH_SCALE": 12.0,
	"RETALIATION_WEIGHT": 0.45,
	"NEAREST_WEIGHT": 2.0,
	"WEAKEST_WEIGHT": 0.25,
	"SECURE_WEIGHT": 0.15,
	"TEMPO_BONUS": 70.0,
	"WINDOW_BONUS": 22.0,
	"CHIP_RISK": 60.0,
	"LETHAL_RISK": 120.0,
	"LETHAL_FLOOR": 0.85,
	"LETHAL_BAND": 0.35,
	"CHIP_WEIGHT": 0.55,
	"VALUE_OFFENCE_WEIGHT": 1.0,
	"VALUE_DURABILITY_WEIGHT": 0.45,
	"RETREAT_HP_FRACTION": 0.3,
	"RETREAT_BONUS": 55.0,
	"ZONE_BONUS": 6.0,
	"RISK_1": 0.0,
	"RISK_2": 0.0,
	"RISK_3": 0.30,
	"RISK_4": 0.40,
	"RISK_5": 0.50,
	"APPROACH_1": 1.0,
	"APPROACH_2": 1.0,
	"APPROACH_3": 0.8,
	"APPROACH_4": 0.7,
	"APPROACH_5": 0.6,
}


class Brain:
	extends RefCounted

	const ESTIMATE_SEED: int = 991
	const DAMAGE_SAMPLES: int = 11
	const VARIANCE_LOW: float = 0.88
	const VARIANCE_HIGH: float = 1.14
	const SCHEDULER_LOOKAHEAD: int = 12
	const INVALID_SCORE: float = -1000000.0

	var sim: BattleSim = null
	var w: Dictionary = {}
	var level: int = 5
	var profile: AIProfile = null
	var _rng := RandomNumberGenerator.new()
	var _out_memo: Dictionary = {}
	var _focus_round: int = -9999
	var _focus_team: Dictionary = {}
	var _chart: TypeChartResource = null
	var _damage: DamageResolver = null
	var _intrinsics: BattleIntrinsicService = null

	func setup(source: BattleSim, weights: Dictionary, tier: int) -> void:
		sim = source
		w = weights
		level = tier
		profile = AIProfile.for_level(tier)
		profile.risk_weight = float(w["RISK_%d" % tier])
		profile.approach_weight = float(w["APPROACH_%d" % tier])
		_chart = sim.type_chart
		_damage = sim._damage
		_intrinsics = sim._intrinsics
		_out_memo.clear()
		_focus_team.clear()
		_focus_round = -9999

	func reset() -> void:
		_out_memo.clear()
		_focus_team.clear()
		_focus_round = -9999

	func clear_memo() -> void:
		_out_memo.clear()

	func _stage_sig(d: PackedInt32Array, unit: int) -> int:
		var base: int = unit * BattleSim.U_STRIDE
		var sig: int = 0
		for s in range(7):
			sig = sig * 13 + (d[base + BattleSim.U_STAGE + s] + 6)
		sig = sig * 3 + d[base + BattleSim.U_SCOUNT]
		return sig

	func expected_damage(d: PackedInt32Array, attacker: int, defender: int, mi: int) -> float:
		if mi < 0:
			return 0.0
		var info: int = mi * BattleSim.M_STRIDE
		if sim.move_info[info + BattleSim.M_DAMAGING] != 1:
			return 0.0
		var key: int = ((attacker * 64 + defender) * 512 + mi) * 9973 + _stage_sig(d, attacker) * 71 + _stage_sig(d, defender)
		if _out_memo.has(key):
			return float(_out_memo[key])
		var abase: int = attacker * BattleSim.U_STRIDE
		var tbase: int = defender * BattleSim.U_STRIDE
		var eff: float = sim._effectiveness(sim.move_info[info + BattleSim.M_TYPE], d[tbase + BattleSim.U_TYPE1], d[tbase + BattleSim.U_TYPE2])
		var move: PokemonMoveResource = sim.move_res[mi]
		sim._hydrate(d, attacker, defender, mi)
		if profile.consider_ability_items:
			eff = _intrinsics.adjust_effectiveness(sim._sa, sim._sb, move, eff, _chart)
		if eff <= 0.0:
			_out_memo[key] = 0.0
			return 0.0
		var stab: bool = sim.move_info[info + BattleSim.M_TYPE] == d[abase + BattleSim.U_TYPE1] or sim.move_info[info + BattleSim.M_TYPE] == d[abase + BattleSim.U_TYPE2]
		_rng.seed = ESTIMATE_SEED
		var raw: int = _damage.calculate_damage(sim._sa, sim._sb, move, eff, stab, 1.0, _rng, {}, true)
		var accuracy: float = clampf(float(sim.move_info[info + BattleSim.M_ACC]) / 100.0, 0.0, 1.0) if sim.move_info[info + BattleSim.M_ACC] > 0 else 1.0
		var value: float = float(raw) * accuracy
		_out_memo[key] = value
		return value

	func best_output(d: PackedInt32Array, attacker: int, defender: int) -> float:
		var abase: int = attacker * BattleSim.U_STRIDE
		var best: float = 0.0
		for slot in range(BattleSim.SLOT_COUNT):
			var mi: int = d[abase + BattleSim.U_MOVE + slot]
			if mi < 0 or d[abase + BattleSim.U_PP + slot] <= 0:
				continue
			best = maxf(best, expected_damage(d, attacker, defender, mi))
		return best

	func unit_value(d: PackedInt32Array, unit: int) -> float:
		var base: int = unit * BattleSim.U_STRIDE
		var offence: float = float(maxi(d[base + BattleSim.U_ATK], d[base + BattleSim.U_SPA]))
		var durability: float = float(d[base + BattleSim.U_MAXHP])
		return float(w["VALUE_OFFENCE_WEIGHT"]) * offence + float(w["VALUE_DURABILITY_WEIGHT"]) * durability

	func expected_hits(d: PackedInt32Array, unit: int, mi: int) -> float:
		var count: int = sim.move_info[mi * BattleSim.M_STRIDE + BattleSim.M_STRIKE]
		if count <= 1:
			return 1.0
		if count >= 5:
			return 5.0 if sim._abc(d, unit) == BattleSim.AB_SKILL_LINK else 3.1
		return float(count)

	func hit_chance(d: PackedInt32Array, attacker: int, defender: int, mi: int) -> float:
		var info: int = mi * BattleSim.M_STRIDE
		if sim.move_info[info + BattleSim.M_ACC] <= 0:
			return 1.0
		var base: float = clampf(float(sim.move_info[info + BattleSim.M_ACC]) / 100.0, 0.0, 1.0)
		var accuracy_stage: int = d[attacker * BattleSim.U_STRIDE + BattleSim.U_STAGE + 5]
		var evasion_stage: int = d[defender * BattleSim.U_STRIDE + BattleSim.U_STAGE + 6]
		var combined: int = clampi(accuracy_stage - evasion_stage, -6, 6)
		var scaled: float = base * BattleActionResolver.STAGE_ACCURACY_TABLE[combined + 6]
		if sim._hs(d, attacker, BattleSim.S_CONFUSE):
			scaled *= 0.5
		return clampf(scaled, 0.0, 1.0)

	func target_shielded(d: PackedInt32Array, defender: int, mi: int) -> bool:
		var base: int = defender * BattleSim.U_STRIDE
		if d[base + BattleSim.U_SCOUNT] > 0:
			if sim._hs(d, defender, BattleSim.S_PROTECT):
				return true
			for i in range(4):
				if d[base + BattleSim.U_STATUS + BattleSim.S_INVULNERABLE_FIRST + i] != 0:
					return true
		if sim._abc(d, defender) == BattleSim.AB_WONDER_GUARD:
			var eff: float = sim._effectiveness(sim.move_info[mi * BattleSim.M_STRIDE + BattleSim.M_TYPE], d[base + BattleSim.U_TYPE1], d[base + BattleSim.U_TYPE2])
			if eff <= 1.0:
				return true
		return false

	func survives_lethal(d: PackedInt32Array, defender: int, mi: int) -> bool:
		var base: int = defender * BattleSim.U_STRIDE
		if d[base + BattleSim.U_HP] < d[base + BattleSim.U_MAXHP]:
			return false
		if expected_hits(d, defender, mi) > 1.0:
			return false
		return sim._abc(d, defender) == BattleSim.AB_STURDY

	func damage_profile(d: PackedInt32Array, attacker: int, defender: int, slot: int, mi: int) -> Dictionary:
		var info: int = mi * BattleSim.M_STRIDE
		if sim.move_info[info + BattleSim.M_DAMAGING] != 1:
			return {}
		var abase: int = attacker * BattleSim.U_STRIDE
		var tbase: int = defender * BattleSim.U_STRIDE
		var eff: float = sim._effectiveness(sim.move_info[info + BattleSim.M_TYPE], d[tbase + BattleSim.U_TYPE1], d[tbase + BattleSim.U_TYPE2])
		var move: PokemonMoveResource = sim.move_res[mi]
		sim._hydrate(d, attacker, defender, mi)
		if profile.consider_ability_items:
			eff = _intrinsics.adjust_effectiveness(sim._sa, sim._sb, move, eff, _chart)
		if eff <= 0.0:
			return {}
		if sim._move_blocked(d, attacker, mi, slot):
			return {}
		if target_shielded(d, defender, mi):
			return {}
		var stab: bool = sim.move_info[info + BattleSim.M_TYPE] == d[abase + BattleSim.U_TYPE1] or sim.move_info[info + BattleSim.M_TYPE] == d[abase + BattleSim.U_TYPE2]
		var accuracy: float = hit_chance(d, attacker, defender, mi)
		var hits: float = expected_hits(d, attacker, mi)
		if sim.move_info[info + BattleSim.M_CHARGE] == 1 and not sim._hs(d, attacker, BattleSim.S_CHARGING):
			hits *= 0.5
		_rng.seed = ESTIMATE_SEED
		var probe: int = int(round(float(_damage.calculate_damage(sim._sa, sim._sb, move, eff, stab, 1.0, _rng, {}, true)) * hits))
		var remaining: float = maxf(1.0, float(d[tbase + BattleSim.U_HP]))
		if float(probe) < remaining * VARIANCE_LOW:
			return {"mean": float(probe), "certain": 0.0, "accuracy": accuracy}
		if float(probe) > remaining * VARIANCE_HIGH:
			return {"mean": float(probe), "certain": 1.0, "accuracy": accuracy}
		var samples: PackedInt32Array = PackedInt32Array()
		var total: float = 0.0
		for i in range(DAMAGE_SAMPLES):
			_rng.seed = ESTIMATE_SEED + i * 7919
			var rolled: int = int(round(float(_damage.calculate_damage(sim._sa, sim._sb, move, eff, stab, 1.0, _rng, {}, true)) * hits))
			samples.append(rolled)
			total += float(rolled)
		return {"mean": total / float(DAMAGE_SAMPLES), "samples": samples, "accuracy": accuracy}

	func ko_chance(sample: Dictionary, remaining: float) -> float:
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

	func reach_of(d: PackedInt32Array, unit: int) -> Array:
		var base: int = unit * BattleSim.U_STRIDE
		var longest: int = 1
		var wide: bool = false
		for slot in range(BattleSim.SLOT_COUNT):
			var mi: int = d[base + BattleSim.U_MOVE + slot]
			if mi < 0 or d[base + BattleSim.U_PP + slot] <= 0:
				continue
			var span: int = sim._range_distance(d, unit, mi)
			if span >= longest:
				longest = span
				wide = sim.move_info[mi * BattleSim.M_STRIDE + BattleSim.M_KIND] == PokemonMoveResource.TacticalRangeKind.PROJECTILE
		return [d[base + BattleSim.U_MOVEMENT] + longest, wide]

	func covers(kx: int, kz: int, ox: int, oz: int, reach: int, wide: bool) -> bool:
		var dx: int = absi(kx - ox)
		var dz: int = absi(kz - oz)
		if wide:
			return maxi(dx, dz) <= reach
		return dx + dz <= reach

	func setup_headroom(d: PackedInt32Array, unit: int) -> float:
		var base: int = unit * BattleSim.U_STRIDE
		var highest: int = 0
		for s in range(7):
			highest = maxi(highest, absi(d[base + BattleSim.U_STAGE + s]))
		return clampf(1.0 - float(highest) / 6.0, 0.0, 1.0)

	func acts_before(d: PackedInt32Array, unit: int, target: int) -> bool:
		var seen: int = 0
		var pos: int = d[sim.field_off + BattleSim.F_QPOS]
		var length: int = d[sim.field_off + BattleSim.F_QLEN]
		while pos < length and seen < SCHEDULER_LOOKAHEAD:
			var upcoming: int = d[sim.field_off + BattleSim.F_QUEUE + pos]
			if upcoming == target:
				return true
			if upcoming == unit:
				return false
			pos += 1
			seen += 1
		return false

	func hazard_threat(d: PackedInt32Array, tile: int, team: int) -> bool:
		for hazard in range(BattleSim.HAZARD_COUNT):
			var packed: int = d[sim.hazard_off + tile * BattleSim.HAZARD_COUNT + hazard]
			if packed == 0:
				continue
			if ((packed >> 4) - 1) != team:
				return true
		return false

	func families(mi: int) -> Dictionary:
		var out: Dictionary = {}
		var move: PokemonMoveResource = sim.move_res[mi]
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

	func field_already_set(d: PackedInt32Array, mi: int) -> bool:
		var move: PokemonMoveResource = sim.move_res[mi]
		var wanted: String = ""
		for record in move.effect_records:
			var entry: Dictionary = record
			if String(entry.get("family", "")) in ["field_condition", "weather_stat_stage"]:
				wanted = String(entry.get("condition_id", entry.get("weather", entry.get("terrain", ""))))
		if wanted.is_empty():
			return false
		var weather: int = d[sim.field_off + BattleSim.F_WEATHER]
		var terrain: int = d[sim.field_off + BattleSim.F_TERRAIN]
		if weather >= 0 and (String(sim._weather_ids[weather]).findn(wanted) >= 0 or wanted.findn(String(sim._weather_ids[weather])) >= 0):
			return true
		if terrain >= 0 and (String(sim._terrain_ids[terrain]).findn(wanted) >= 0 or wanted.findn(String(sim._terrain_ids[terrain])) >= 0):
			return true
		return false

	func support_score(d: PackedInt32Array, unit: int, mi: int, target: int) -> float:
		var fam: Dictionary = families(mi)
		var score: float = 0.0
		if fam.has("status:hit_target") and target != unit and profile.consider_status_moves:
			if d[target * BattleSim.U_STRIDE + BattleSim.U_SCOUNT] == 0:
				score += float(w["STATUS_SCORE"])
		if fam.has("stat_raise:self") or (fam.has("stat_stage") and target == unit and not fam.has("stat_drop:self")):
			if profile.consider_setup_moves:
				score += float(w["SETUP_SCORE"]) * setup_headroom(d, unit)
		elif fam.has("stat_drop:hit_target") and target != unit and profile.consider_status_moves:
			score += float(w["STATUS_SCORE"]) * 0.6 * setup_headroom(d, target)
		if (fam.has("field_condition") or fam.has("weather_stat_stage")) and profile.consider_field_moves and not field_already_set(d, mi):
			score += float(w["FIELD_SCORE"])
		if fam.has("heal") or fam.has("cure_statuses") or fam.has("status_remove"):
			var base: int = target * BattleSim.U_STRIDE
			if d[base + BattleSim.U_MAXHP] > 0:
				var missing: float = 1.0 - float(d[base + BattleSim.U_HP]) / float(d[base + BattleSim.U_MAXHP])
				score += float(w["STATUS_SCORE"]) * missing
		return score

	func target_preference(d: PackedInt32Array, unit: int, target: int) -> float:
		var base: int = target * BattleSim.U_STRIDE
		if d[base + BattleSim.U_MAXHP] <= 0:
			return 0.0
		var hp_fraction: float = float(d[base + BattleSim.U_HP]) / float(d[base + BattleSim.U_MAXHP])
		match profile.target_mode:
			AIProfile.TargetMode.NEAREST:
				var ubase: int = unit * BattleSim.U_STRIDE
				var distance: int = absi(d[ubase + BattleSim.U_X] - d[base + BattleSim.U_X]) + absi(d[ubase + BattleSim.U_Z] - d[base + BattleSim.U_Z])
				return -float(distance) * float(w["NEAREST_WEIGHT"])
			AIProfile.TargetMode.WEAKEST:
				return -100.0 * hp_fraction * float(w["WEAKEST_WEIGHT"])
			AIProfile.TargetMode.MATCHUP:
				return 0.0
			AIProfile.TargetMode.SECURE_KO:
				return -100.0 * hp_fraction * float(w["SECURE_WEIGHT"])
			AIProfile.TargetMode.EXPECTED_VALUE:
				return -100.0 * hp_fraction * float(w["SECURE_WEIGHT"])
		return 0.0

	func focus_target(d: PackedInt32Array, unit: int, friends: PackedInt32Array, foes: PackedInt32Array, reference: float) -> int:
		if not profile.shared_focus or foes.is_empty():
			return -1
		var team: int = sim.unit_team(d, unit)
		var round_key: int = sim.round_index(d)
		if _focus_round == round_key and _focus_team.has(team):
			var kept: int = int(_focus_team[team])
			if kept >= 0 and sim.unit_alive(d, kept) and foes.has(kept):
				return kept
		if _focus_round != round_key:
			_focus_round = round_key
			_focus_team.clear()
		var best: int = -1
		var best_score: float = -INF
		for foe in foes:
			var score: float = 0.0
			if profile.team_assignment:
				var incoming: float = 0.0
				var hands: int = 0
				for friend in friends:
					if not sim.unit_alive(d, friend):
						continue
					if not within_window(d, friend, foe):
						continue
					hands += 1
					incoming += best_output(d, friend, foe)
				var remaining: float = maxf(1.0, float(d[foe * BattleSim.U_STRIDE + BattleSim.U_HP]))
				score = 100.0 * minf(incoming / remaining, 1.5)
				score += float(w["WINDOW_BONUS"]) * float(hands)
				score += 100.0 * (unit_value(d, foe) / reference) * 0.15
			else:
				score = -float(d[foe * BattleSim.U_STRIDE + BattleSim.U_HP])
			if score > best_score:
				best_score = score
				best = foe
		_focus_team[team] = best
		return best

	func within_window(d: PackedInt32Array, ally: int, foe: int) -> bool:
		if d[ally * BattleSim.U_STRIDE + BattleSim.U_ACTED] != 0:
			return false
		var span: Array = reach_of(d, ally)
		return covers(
			d[foe * BattleSim.U_STRIDE + BattleSim.U_X],
			d[foe * BattleSim.U_STRIDE + BattleSim.U_Z],
			d[ally * BattleSim.U_STRIDE + BattleSim.U_X],
			d[ally * BattleSim.U_STRIDE + BattleSim.U_Z],
			int(span[0]),
			bool(span[1])
		)

	func choose(d: PackedInt32Array, unit: int) -> int:
		var base: int = unit * BattleSim.U_STRIDE
		var team: int = d[base + BattleSim.U_TEAM]
		var origin_tile: int = int(sim.tile_index.get(Vector3i(d[base + BattleSim.U_X], 0, d[base + BattleSim.U_Z]), 0))
		var foes: PackedInt32Array = PackedInt32Array()
		var friends: PackedInt32Array = PackedInt32Array()
		for i in range(sim.unit_count):
			if not sim.unit_alive(d, i):
				continue
			if d[i * BattleSim.U_STRIDE + BattleSim.U_TEAM] == team:
				friends.append(i)
			else:
				foes.append(i)
		if foes.is_empty():
			return origin_tile << 12
		var damage_table: Dictionary = {}
		if profile.move_mode == AIProfile.MoveMode.EXPECTED_DAMAGE:
			for slot in range(BattleSim.SLOT_COUNT):
				var mi: int = d[base + BattleSim.U_MOVE + slot]
				if mi < 0 or sim.move_info[mi * BattleSim.M_STRIDE + BattleSim.M_DAMAGING] != 1:
					continue
				var row: Dictionary = {}
				for foe in foes:
					row[foe] = expected_damage(d, unit, foe, mi)
				damage_table[slot] = row
		var retaliation: Dictionary = {}
		if profile.target_mode >= AIProfile.TargetMode.EXPECTED_VALUE:
			for foe in foes:
				retaliation[foe] = best_output(d, foe, unit)
		var shapes: Dictionary = {}
		if profile.use_ko_probability:
			for slot in range(BattleSim.SLOT_COUNT):
				var mi2: int = d[base + BattleSim.U_MOVE + slot]
				if mi2 < 0 or d[base + BattleSim.U_PP + slot] <= 0:
					continue
				if sim.move_info[mi2 * BattleSim.M_STRIDE + BattleSim.M_DAMAGING] != 1:
					continue
				var row2: Dictionary = {}
				for foe in foes:
					row2[foe] = damage_profile(d, unit, foe, slot, mi2)
				shapes[slot] = row2
		var reference: float = 0.0
		var counted: int = 0
		for i in range(sim.unit_count):
			if sim.unit_alive(d, i):
				reference += unit_value(d, i)
				counted += 1
		reference = maxf(1.0, reference / float(maxi(1, counted)))
		var focus: int = focus_target(d, unit, friends, foes, reference)
		var threat: Array = []
		if profile.threat_aware:
			for foe in foes:
				var span: Array = reach_of(d, foe)
				var fx: int = d[foe * BattleSim.U_STRIDE + BattleSim.U_X]
				var fz: int = d[foe * BattleSim.U_STRIDE + BattleSim.U_Z]
				var covered: int = 0
				for friend in friends:
					if covers(d[friend * BattleSim.U_STRIDE + BattleSim.U_X], d[friend * BattleSim.U_STRIDE + BattleSim.U_Z], fx, fz, int(span[0]), bool(span[1])):
						covered += 1
				threat.append([
					fx,
					fz,
					int(span[0]),
					bool(span[1]),
					best_output(d, foe, unit),
					1.0 / float(maxi(1, covered)),
				])
		var destinations: PackedInt32Array = sim.reachable_tiles(d, unit)
		var ordered: Array = []
		for tile in destinations:
			ordered.append(tile)
		ordered.sort_custom(func(a: int, b: int) -> bool:
			if sim.tile_z[a] != sim.tile_z[b]:
				return sim.tile_z[a] < sim.tile_z[b]
			return sim.tile_x[a] < sim.tile_x[b])
		var engaging: bool = _can_engage(d, unit, foes, ordered)
		var best_attack: float = -INF
		var best_support: float = -INF
		var best_idle: float = -INF
		var attack_entry: int = -1
		var support_entry: int = -1
		var idle_entry: int = -1
		for tile in ordered:
			var kx: int = sim.tile_x[tile]
			var kz: int = sim.tile_z[tile]
			var positional: float = _positional_score(d, unit, tile, kx, kz, origin_tile, foes, friends, focus, threat, engaging)
			for slot in range(BattleSim.SLOT_COUNT):
				var mi: int = d[base + BattleSim.U_MOVE + slot]
				if mi < 0 or d[base + BattleSim.U_PP + slot] <= 0:
					continue
				var info: int = mi * BattleSim.M_STRIDE
				var kind: int = sim.move_info[info + BattleSim.M_KIND]
				var reach: int = sim._range_distance(d, unit, mi)
				var damaging: int = sim.move_info[info + BattleSim.M_DAMAGING]
				var align: int = sim.move_info[info + BattleSim.M_ALIGN]
				for target in _candidate_targets(d, unit, team, foes, friends, align, damaging):
					var ax: int = kx if target == unit else d[target * BattleSim.U_STRIDE + BattleSim.U_X]
					var az: int = kz if target == unit else d[target * BattleSim.U_STRIDE + BattleSim.U_Z]
					if not sim.key_in_range(Vector3i(kx, 0, kz), Vector3i(ax, 0, az), kind, reach):
						continue
					var value: float = _action_score(d, unit, slot, mi, target, kx, kz, damage_table, shapes, retaliation, focus, foes, reference)
					if value <= INVALID_SCORE:
						continue
					var total: float = value + positional
					if damaging == 1:
						if total > best_attack:
							best_attack = total
							attack_entry = (tile << 12) | ((slot + 1) << 6) | (target + 1)
					elif total > best_support:
						best_support = total
						support_entry = (tile << 12) | ((slot + 1) << 6) | (target + 1)
			if positional > best_idle:
				best_idle = positional
				idle_entry = tile << 12
		if attack_entry >= 0:
			return attack_entry
		if support_entry >= 0 and best_support > best_idle:
			return support_entry
		if idle_entry >= 0:
			return idle_entry
		return origin_tile << 12

	func _candidate_targets(d: PackedInt32Array, unit: int, team: int, foes: PackedInt32Array, friends: PackedInt32Array, align: int, damaging: int) -> PackedInt32Array:
		var out: PackedInt32Array = PackedInt32Array()
		for foe in foes:
			if sim._alignment_allows(unit, foe, team, d[foe * BattleSim.U_STRIDE + BattleSim.U_TEAM], align, damaging):
				out.append(foe)
		if damaging == 1:
			return out
		if sim._alignment_allows(unit, unit, team, team, align, damaging):
			out.append(unit)
		for friend in friends:
			if friend != unit and sim._alignment_allows(unit, friend, team, team, align, damaging):
				out.append(friend)
		return out

	func _can_engage(d: PackedInt32Array, unit: int, foes: PackedInt32Array, tiles: Array) -> bool:
		var base: int = unit * BattleSim.U_STRIDE
		for tile in tiles:
			var kx: int = sim.tile_x[tile]
			var kz: int = sim.tile_z[tile]
			for slot in range(BattleSim.SLOT_COUNT):
				var mi: int = d[base + BattleSim.U_MOVE + slot]
				if mi < 0 or d[base + BattleSim.U_PP + slot] <= 0:
					continue
				var info: int = mi * BattleSim.M_STRIDE
				if sim.move_info[info + BattleSim.M_DAMAGING] != 1:
					continue
				var kind: int = sim.move_info[info + BattleSim.M_KIND]
				var reach: int = sim._range_distance(d, unit, mi)
				for foe in foes:
					if sim.key_in_range(Vector3i(kx, 0, kz), Vector3i(d[foe * BattleSim.U_STRIDE + BattleSim.U_X], 0, d[foe * BattleSim.U_STRIDE + BattleSim.U_Z]), kind, reach):
						return true
		return false

	func _targets_hit(d: PackedInt32Array, unit: int, mi: int, kx: int, kz: int, declared: int, foes: PackedInt32Array) -> PackedInt32Array:
		var out: PackedInt32Array = PackedInt32Array()
		var info: int = mi * BattleSim.M_STRIDE
		if sim.move_info[info + BattleSim.M_KIND] != PokemonMoveResource.TacticalRangeKind.AREA:
			out.append(declared)
			return out
		var reach: int = sim._range_distance(d, unit, mi)
		var align: int = sim.move_info[info + BattleSim.M_ALIGN]
		var damaging: int = sim.move_info[info + BattleSim.M_DAMAGING]
		var team: int = d[unit * BattleSim.U_STRIDE + BattleSim.U_TEAM]
		for foe in foes:
			var fx: int = d[foe * BattleSim.U_STRIDE + BattleSim.U_X]
			var fz: int = d[foe * BattleSim.U_STRIDE + BattleSim.U_Z]
			if absi(fx - kx) + absi(fz - kz) <= reach and sim._alignment_allows(unit, foe, team, d[foe * BattleSim.U_STRIDE + BattleSim.U_TEAM], align, damaging):
				out.append(foe)
		if out.is_empty():
			out.append(declared)
		return out

	func _is_lethal(d: PackedInt32Array, unit: int, slot: int, mi: int, target: int, damage_table: Dictionary) -> bool:
		if survives_lethal(d, target, mi):
			return false
		var row: Dictionary = damage_table.get(slot, {})
		var expected: float = float(row[target]) if row.has(target) else expected_damage(d, unit, target, mi)
		return expected >= maxf(1.0, float(d[target * BattleSim.U_STRIDE + BattleSim.U_HP]))

	func _damage_value(d: PackedInt32Array, unit: int, slot: int, mi: int, target: int, kx: int, kz: int, damage_table: Dictionary, shapes: Dictionary, focus: int, foes: PackedInt32Array, reference: float) -> float:
		var total: float = 0.0
		for hit in _targets_hit(d, unit, mi, kx, kz, target, foes):
			var hbase: int = hit * BattleSim.U_STRIDE
			var remaining: float = maxf(1.0, float(d[hbase + BattleSim.U_HP]))
			var value: float = 0.0
			var shape: Dictionary = (shapes.get(slot, {}) as Dictionary).get(hit, {})
			if profile.use_ko_probability and not shape.is_empty():
				var chance: float = 0.0 if survives_lethal(d, hit, mi) else ko_chance(shape, remaining)
				var mean: float = float(shape.get("mean", 0.0))
				if mean <= 0.0:
					continue
				var share: float = unit_value(d, hit) / reference if profile.value_weighted else 1.0
				var chip: float = minf(mean / remaining, 1.0)
				value = 100.0 * share * (chance + (1.0 - chance) * float(w["CHIP_WEIGHT"]) * chip)
				if chance > 0.0 and profile.turn_order_aware and acts_before(d, unit, hit):
					value += float(w["TEMPO_BONUS"]) * chance
			else:
				var row: Dictionary = damage_table.get(slot, {})
				var expected: float = float(row[hit]) if row.has(hit) else expected_damage(d, unit, hit, mi)
				if expected <= 0.0:
					continue
				value = 100.0 * minf(expected / remaining, 1.0)
				if expected >= remaining and profile.target_mode >= AIProfile.TargetMode.SECURE_KO:
					value += float(w["KO_BONUS"])
					if profile.turn_order_aware and acts_before(d, unit, hit):
						value += float(w["TEMPO_BONUS"])
			if profile.shared_focus and focus >= 0 and hit == focus:
				value *= float(w["FOCUS_GAIN"])
			total += value
		return total

	func _action_score(d: PackedInt32Array, unit: int, slot: int, mi: int, target: int, kx: int, kz: int, damage_table: Dictionary, shapes: Dictionary, retaliation: Dictionary, focus: int, foes: PackedInt32Array, reference: float) -> float:
		var hostile: bool = foes.has(target)
		var base: float = 0.0
		var modifiers: float = 0.0
		var info: int = mi * BattleSim.M_STRIDE
		if sim.move_info[info + BattleSim.M_DAMAGING] == 1:
			if not hostile:
				return INVALID_SCORE
			match profile.move_mode:
				AIProfile.MoveMode.SLOT_ORDER:
					base = 60.0 - float(slot)
				AIProfile.MoveMode.RAW_POWER:
					var tbase: int = target * BattleSim.U_STRIDE
					var chart_gain: float = sim._effectiveness(sim.move_info[info + BattleSim.M_TYPE], d[tbase + BattleSim.U_TYPE1], d[tbase + BattleSim.U_TYPE2])
					if chart_gain <= 0.0:
						return INVALID_SCORE
					var accuracy: float = clampf(float(sim.move_info[info + BattleSim.M_ACC]) / 100.0, 0.0, 1.0) if sim.move_info[info + BattleSim.M_ACC] > 0 else 1.0
					base = float(sim.move_info[info + BattleSim.M_POWER]) * accuracy * chart_gain
				AIProfile.MoveMode.EXPECTED_DAMAGE:
					base = _damage_value(d, unit, slot, mi, target, kx, kz, damage_table, shapes, focus, foes, reference)
			if base <= 0.0:
				return INVALID_SCORE
			if profile.target_mode >= AIProfile.TargetMode.EXPECTED_VALUE and not _is_lethal(d, unit, slot, mi, target, damage_table):
				var pool: float = maxf(1.0, float(d[unit * BattleSim.U_STRIDE + BattleSim.U_MAXHP]))
				modifiers -= float(w["RETALIATION_WEIGHT"]) * 100.0 * minf(float(retaliation.get(target, 0.0)) / pool, 1.0)
		else:
			base = support_score(d, unit, mi, target)
			if base <= 0.0:
				return INVALID_SCORE
		if hostile:
			modifiers += target_preference(d, unit, target)
			if sim.move_info[info + BattleSim.M_DAMAGING] != 1 and profile.shared_focus and focus >= 0 and target == focus:
				modifiers += float(w["FOCUS_BONUS"])
		return base + modifiers

	func _positional_score(d: PackedInt32Array, unit: int, tile: int, kx: int, kz: int, origin_tile: int, foes: PackedInt32Array, friends: PackedInt32Array, focus: int, threat: Array, engaging: bool) -> float:
		var base: int = unit * BattleSim.U_STRIDE
		var team: int = d[base + BattleSim.U_TEAM]
		var score: float = 0.0
		if profile.avoid_hazards and hazard_threat(d, tile, team):
			score -= float(w["HAZARD_PENALTY"])
		var retreating: bool = false
		if profile.retreat_when_losing and not engaging and d[base + BattleSim.U_MAXHP] > 0:
			retreating = float(d[base + BattleSim.U_HP]) / float(d[base + BattleSim.U_MAXHP]) < float(w["RETREAT_HP_FRACTION"])
		if profile.threat_aware and engaging:
			var pool: float = maxf(1.0, float(d[base + BattleSim.U_HP]))
			var spread: float = 0.0
			var worst: float = 0.0
			var raw: float = 0.0
			for source in threat:
				if covers(kx, kz, int(source[0]), int(source[1]), int(source[2]), bool(source[3])):
					spread += float(source[4]) * float(source[5])
					raw += float(source[4])
					worst = maxf(worst, float(source[4]))
			var chip: float = minf(spread / pool, 1.0)
			var combined: float = maxf(worst, raw)
			var band: float = maxf(0.0001, float(w["LETHAL_BAND"]))
			var lethal: float = clampf(combined / pool - float(w["LETHAL_FLOOR"]), 0.0, band) / band
			score -= profile.risk_weight * (float(w["CHIP_RISK"]) * chip + float(w["LETHAL_RISK"]) * lethal)
			if retreating and spread <= 0.0:
				score += float(w["RETREAT_BONUS"])
		var anchor: int = focus if (profile.focus_fire_staging and focus >= 0 and not engaging) else _nearest(d, unit, foes)
		if anchor >= 0:
			var distance: int = absi(kx - d[anchor * BattleSim.U_STRIDE + BattleSim.U_X]) + absi(kz - d[anchor * BattleSim.U_STRIDE + BattleSim.U_Z])
			if retreating:
				score += profile.approach_weight * float(w["APPROACH_SCALE"]) * float(distance) * 0.5
			else:
				score -= profile.approach_weight * float(w["APPROACH_SCALE"]) * float(distance)
		if profile.zone_control:
			var nearby: int = 0
			for friend in friends:
				if friend == unit:
					continue
				if absi(kx - d[friend * BattleSim.U_STRIDE + BattleSim.U_X]) + absi(kz - d[friend * BattleSim.U_STRIDE + BattleSim.U_Z]) <= 2:
					nearby += 1
			score += float(w["ZONE_BONUS"]) * minf(float(nearby), 2.0)
		if tile == origin_tile:
			score += 0.5
		return score

	func _nearest(d: PackedInt32Array, unit: int, foes: PackedInt32Array) -> int:
		var base: int = unit * BattleSim.U_STRIDE
		var best: int = -1
		var best_distance: int = 1 << 30
		for foe in foes:
			var distance: int = absi(d[base + BattleSim.U_X] - d[foe * BattleSim.U_STRIDE + BattleSim.U_X]) + absi(d[base + BattleSim.U_Z] - d[foe * BattleSim.U_STRIDE + BattleSim.U_Z])
			if distance < best_distance:
				best_distance = distance
				best = foe
		return best


class Recorder:
	extends BattleAI

	var probe: Callable

	func choose_action(
			unit: TacticsPawn,
			allies: Array,
			enemies: Array,
			type_chart: TypeChartResource,
			battle_level: TacticsLevel = null
	) -> AIAction:
		var action: AIAction = super(unit, allies, enemies, type_chart, battle_level)
		if probe.is_valid():
			probe.call(unit, action, battle_level)
		return action


class Position:
	extends RefCounted

	const FEATURE_COUNT: int = 16

	var sim: BattleSim = null
	var brain: Brain = null

	func setup(source: BattleSim, helper: Brain) -> void:
		sim = source
		brain = helper

	func features(d: PackedInt32Array) -> PackedFloat64Array:
		var out: PackedFloat64Array = PackedFloat64Array()
		out.resize(FEATURE_COUNT)
		out.fill(0.0)
		var alive: Array[int] = []
		var mean_off: float = 0.0
		var mean_bulk: float = 0.0
		for i in range(sim.unit_count):
			if sim.unit_alive(d, i):
				alive.append(i)
			var b: int = i * BattleSim.U_STRIDE
			mean_off += float(maxi(d[b + BattleSim.U_ATK], d[b + BattleSim.U_SPA]))
			mean_bulk += float(d[b + BattleSim.U_MAXHP])
		mean_off = maxf(1.0, mean_off / float(maxi(1, sim.unit_count)))
		mean_bulk = maxf(1.0, mean_bulk / float(maxi(1, sim.unit_count)))
		var standing: Array[int] = [0, 0]
		for i in alive:
			standing[d[i * BattleSim.U_STRIDE + BattleSim.U_TEAM]] += 1
		var scale: float = 1.0 / float(maxi(1, sim.unit_count / 2))
		for i in alive:
			var b: int = i * BattleSim.U_STRIDE
			var team: int = d[b + BattleSim.U_TEAM]
			var sign: float = 1.0 if team == 0 else -1.0
			var hpf: float = float(d[b + BattleSim.U_HP]) / maxf(1.0, float(d[b + BattleSim.U_MAXHP]))
			var offn: float = float(maxi(d[b + BattleSim.U_ATK], d[b + BattleSim.U_SPA])) / mean_off
			var bulkn: float = float(d[b + BattleSim.U_MAXHP]) / mean_bulk
			out[0] += sign * scale
			out[1] += sign * hpf * scale
			out[2] += sign * offn * scale
			out[3] += sign * bulkn * scale
			out[4] += sign * hpf * offn * scale
			out[5] += sign * hpf * bulkn * scale
			var spread: float = 0.0
			var worst: float = 0.0
			for j in alive:
				if d[j * BattleSim.U_STRIDE + BattleSim.U_TEAM] == team:
					continue
				var span: Array = brain.reach_of(d, j)
				if not brain.covers(d[b + BattleSim.U_X], d[b + BattleSim.U_Z], d[j * BattleSim.U_STRIDE + BattleSim.U_X], d[j * BattleSim.U_STRIDE + BattleSim.U_Z], int(span[0]), bool(span[1])):
					continue
				var output: float = brain.best_output(d, j, i)
				spread += output / float(maxi(1, standing[team]))
				worst = maxf(worst, output)
			var pool: float = maxf(1.0, float(d[b + BattleSim.U_HP]))
			var chip: float = minf(spread / pool, 1.0)
			var combined: float = maxf(worst, spread)
			var lethal: float = clampf(combined / pool - 0.85, 0.0, 0.35) / 0.35
			out[6] += -sign * chip * scale
			out[7] += -sign * lethal * scale
			var stages: int = 0
			for s in range(7):
				stages += d[b + BattleSim.U_STAGE + s]
			out[8] += sign * float(stages) * scale
			out[9] += -sign * (1.0 if d[b + BattleSim.U_SCOUNT] > 0 else 0.0) * scale
			var tile: int = int(sim.tile_index.get(Vector3i(d[b + BattleSim.U_X], 0, d[b + BattleSim.U_Z]), -1))
			if tile >= 0 and brain.hazard_threat(d, tile, team):
				out[10] += -sign * scale
			out[11] += -sign * (1.0 - hpf) * (1.0 - hpf) * scale
			var nearby: int = 0
			var nearest: int = 1 << 20
			for j2 in alive:
				if j2 == i:
					continue
				var distance: int = absi(d[b + BattleSim.U_X] - d[j2 * BattleSim.U_STRIDE + BattleSim.U_X]) + absi(d[b + BattleSim.U_Z] - d[j2 * BattleSim.U_STRIDE + BattleSim.U_Z])
				if d[j2 * BattleSim.U_STRIDE + BattleSim.U_TEAM] == team:
					if distance <= 2:
						nearby += 1
				else:
					nearest = mini(nearest, distance)
			out[13] += sign * minf(float(nearby), 2.0) * scale
			out[14] += sign * float(d[b + BattleSim.U_SPE]) * scale / 100.0
			if nearest < (1 << 20):
				out[15] += -sign * float(nearest) * scale
		var pos: int = d[sim.field_off + BattleSim.F_QPOS]
		var length: int = d[sim.field_off + BattleSim.F_QLEN]
		var tempo: float = 0.0
		while pos < length:
			var upcoming: int = d[sim.field_off + BattleSim.F_QUEUE + pos]
			if sim.unit_alive(d, upcoming):
				tempo += 1.0 if d[upcoming * BattleSim.U_STRIDE + BattleSim.U_TEAM] == 0 else -1.0
			pos += 1
		out[12] = tempo * scale
		return out


var _sim_cache: Array = []
var _loader: SkirmishLoader = null


func _init() -> void:
	call_deferred("_run")


func _arg(key: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		var text: String = String(argument)
		if text.begins_with("--%s=" % key):
			return text.split("=", true, 1)[1]
		if text == "--%s" % key:
			return "1"
	return fallback


func _run() -> void:
	DebugLog.set_debug_enabled(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var mode: String = _arg("mode", "speed")
	var code: int = 1
	match mode:
		"speed":
			code = await _mode_speed()
		"fidelity":
			code = await _mode_fidelity()
		"selfplay":
			code = await _mode_selfplay()
		"fit":
			code = _mode_fit()
		"match":
			code = await _mode_match()
		"search":
			code = await _mode_search()
		"real":
			code = await _mode_real()
		"verify":
			code = await _mode_verify()
		"pipeline":
			code = await _mode_pipeline()
		"probe":
			code = await _mode_probe()
		"ladder":
			code = await _mode_ladder()
		_:
			print("tuning: unknown mode %s" % mode)
	quit(code)


func _weights_from(path: String) -> Dictionary:
	var out: Dictionary = BASE_WEIGHTS.duplicate()
	if path.is_empty() or path == "base":
		return out
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("tuning: cannot read weights %s" % path)
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var source: Dictionary = parsed
		if source.has("weights"):
			source = source["weights"]
		for key in source.keys():
			if out.has(String(key)):
				out[String(key)] = float(source[key])
	return out


func _build_level(seed: int, team_size: int) -> TacticsLevel:
	var built: Dictionary = CustomSkirmishBuilder.build_random(team_size, MAP_PATH, str(seed), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
	if not bool(built.get("ok", false)):
		return null
	var definition: SkirmishDefinitionResource = built["definition"]
	if _arg("mirror", "1") == "1":
		var copies: Array[PokemonInstanceResource] = []
		for source in definition.player_team:
			if source == null:
				continue
			var clone: PokemonInstanceResource = source.duplicate(true)
			clone.team = PokemonInstanceResource.Team.ENEMY
			clone.control_type = PokemonInstanceResource.ControlType.AI
			copies.append(clone)
		definition.enemy_team = copies
	definition.skirmish_id = "weight_tuning_%d" % seed
	if _loader == null:
		_loader = SkirmishLoader.new()
		root.add_child(_loader)
	var level: TacticsLevel = _loader.load_skirmish(definition, root)
	if level == null:
		return null
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var frames: int = 0
	while frames < 400 and not level._scheduler_started:
		await physics_frame
		frames += 1
	level.process_mode = Node.PROCESS_MODE_DISABLED
	if not level._scheduler_started:
		level.queue_free()
		return null
	return level


func _book(seed_start: int, seeds: int, team_size: int) -> Array:
	var out: Array = []
	for seed in range(seed_start, seed_start + seeds):
		var level: TacticsLevel = await _build_level(seed, team_size)
		if level == null:
			continue
		var sim := BattleSim.new()
		sim.max_rounds = int(_arg("rounds", "60"))
		var state: PackedInt32Array = sim.setup_from_level(level)
		out.append({"seed": seed, "sim": sim, "state": state})
		level.queue_free()
		await process_frame
		await process_frame
	return out


func _play(sim: BattleSim, state: PackedInt32Array, brain0: Brain, brain1: Brain, rng_state: int, record: Variant, feature_source: Variant, min_round: int) -> Dictionary:
	var d: PackedInt32Array = state.duplicate()
	sim.set_rng_state(d, rng_state)
	brain0.reset()
	brain1.reset()
	var guard: int = 0
	var turns: int = 0
	var damage: Array[float] = [0.0, 0.0]
	var kos: Array[int] = [0, 0]
	var marks: Array = []
	var mdi_total: float = 0.0
	var mdi_count: int = 0
	var previous: PackedInt32Array = PackedInt32Array()
	while not sim.is_over(d) and guard < 4096:
		var unit: int = sim.active_unit(d)
		if unit < 0:
			break
		var team: int = sim.unit_team(d, unit)
		var material: float = 0.0
		for i in range(sim.unit_count):
			if not sim.unit_alive(d, i):
				continue
			var fraction: float = clampf(float(d[i * BattleSim.U_STRIDE + BattleSim.U_HP]) / maxf(1.0, float(d[i * BattleSim.U_STRIDE + BattleSim.U_MAXHP])), 0.0, 1.0)
			material += fraction if sim.unit_team(d, i) == 0 else -fraction
		mdi_total += material
		mdi_count += 1
		if record != null and sim.round_index(d) >= min_round:
			marks.append([feature_source.features(d), sim.round_index(d)])
		previous = d.duplicate()
		var action: int = (brain0 if team == 0 else brain1).choose(d, unit)
		sim.apply_packed(d, action)
		for i in range(sim.unit_count):
			var before: int = previous[i * BattleSim.U_STRIDE + BattleSim.U_HP]
			var after: int = d[i * BattleSim.U_STRIDE + BattleSim.U_HP]
			if after < before and sim.unit_team(d, i) != team:
				damage[team] += float(before - after)
			if previous[i * BattleSim.U_STRIDE + BattleSim.U_ALIVE] == 1 and d[i * BattleSim.U_STRIDE + BattleSim.U_ALIVE] != 1 and sim.unit_team(d, i) != team:
				kos[team] += 1
		guard += 1
		turns += 1
	var outcome: int = sim.result(d)
	var score: float = 0.5
	if outcome == BattleSim.RESULT_TEAM0:
		score = 1.0
	elif outcome == BattleSim.RESULT_TEAM1:
		score = 0.0
	if record != null:
		for mark in marks:
			record.append([mark[0], score, int(mark[1])])
	var left: Array[float] = [0.0, 0.0]
	for i in range(sim.unit_count):
		left[sim.unit_team(d, i)] += float(sim.unit_hp(d, i))
	var total_damage: float = damage[0] + damage[1]
	return {
		"score": score,
		"turns": turns,
		"rounds": sim.round_index(d),
		"damage_share": damage[0] / maxf(1.0, total_damage),
		"ko_share": (float(kos[0]) + 0.5) / (float(kos[0]) + float(kos[1]) + 1.0),
		"mdi_turn": mdi_total / float(maxi(1, mdi_count)),
		"hp_share": left[0] / maxf(1.0, left[0] + left[1]),
		"result": outcome,
	}


func _mode_ladder() -> int:
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "24"))
	var seed_start: int = int(_arg("seed-start", "401"))
	var games: int = int(_arg("games", "8"))
	var levels: Array[int] = []
	for token in _arg("levels", "1,2,3,4,5").split(",", false):
		levels.append(AIProfile.clamp_level(int(token)))
	var book: Array = await _book(seed_start, seeds, team_size)
	if book.is_empty():
		return 1
	var out: Array = []
	for label in _arg("list", "base").split(",", false):
		var weights: Dictionary = _weights_from(String(label).strip_edges())
		var table: Dictionary = _ladder(book, weights, levels, games)
		out.append({"label": label, "table": table})
		var line: PackedStringArray = PackedStringArray()
		var monotonic: bool = true
		var previous: float = -1.0
		for level in levels:
			var row: Dictionary = table[level]
			line.append("L%d=%.3f+/-%.3f" % [level, float(row["rate"]), float(row["error"])])
			if float(row["rate"]) + 2.0 * float(row["error"]) < previous:
				monotonic = false
			previous = float(row["rate"])
		print("tuning: ladder %-42s %s monotonic=%s" % [label, " ".join(line), str(monotonic)])
	var file := FileAccess.open("%s/%s.json" % [OUTPUT_DIR, _arg("out", "ladder")], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"seed_start": seed_start, "seeds": seeds, "games": games, "runs": out}, "\t"))
		file.close()
	return 0


func _ladder(book: Array, weights: Dictionary, levels: Array[int], games: int) -> Dictionary:
	var wins: Dictionary = {}
	for level in levels:
		wins[level] = {"played": 0, "score": 0.0}
	for entry in book:
		var sim: BattleSim = entry["sim"]
		var brains: Dictionary = {}
		for level in levels:
			var brain := Brain.new()
			brain.setup(sim, weights, level)
			brains[level] = brain
		for i in range(levels.size()):
			for j in range(levels.size()):
				if i >= j:
					continue
				var a: int = levels[i]
				var b: int = levels[j]
				for g in range(games):
					var rng_state: int = 7919 * (g + 1) + int(entry["seed"])
					var first: Dictionary = _play(sim, entry["state"], brains[a], brains[b], rng_state, null, null, 0)
					var second: Dictionary = _play(sim, entry["state"], brains[b], brains[a], rng_state, null, null, 0)
					(wins[a] as Dictionary)["score"] = float((wins[a] as Dictionary)["score"]) + float(first["score"]) + (1.0 - float(second["score"]))
					(wins[b] as Dictionary)["score"] = float((wins[b] as Dictionary)["score"]) + (1.0 - float(first["score"])) + float(second["score"])
					(wins[a] as Dictionary)["played"] = int((wins[a] as Dictionary)["played"]) + 2
					(wins[b] as Dictionary)["played"] = int((wins[b] as Dictionary)["played"]) + 2
	var table: Dictionary = {}
	for level in levels:
		var row: Dictionary = wins[level]
		var played: int = int(row["played"])
		var rate: float = float(row["score"]) / float(maxi(1, played))
		table[level] = {"played": played, "rate": rate, "error": sqrt(maxf(rate * (1.0 - rate), 0.01) / float(maxi(1, played)))}
	return table


func _mode_probe() -> int:
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "24"))
	var seed_start: int = int(_arg("seed-start", "201"))
	var games: int = int(_arg("games", "32"))
	var tier: int = int(_arg("level", "5"))
	var base: Dictionary = _weights_from(_arg("b", "base"))
	var book: Array = await _book(seed_start, seeds, team_size)
	if book.is_empty():
		return 1
	var rows: Array = []
	for token in _arg("list", "").split(",", false):
		var label: String = String(token).strip_edges()
		if label.is_empty():
			continue
		var trial: Dictionary = base.duplicate()
		if label.contains("="):
			for assignment in label.split(";", false):
				var parts: PackedStringArray = String(assignment).split("=", true, 1)
				if parts.size() == 2 and BASE_WEIGHTS.has(parts[0]):
					trial[parts[0]] = float(parts[1])
		else:
			trial = _weights_from(label)
		var report: Dictionary = _duel(book, trial, base, tier, games)
		var changed: Array = []
		for key in BASE_WEIGHTS.keys():
			if not is_equal_approx(float(trial[key]), float(base[key])):
				changed.append("%s=%.4f" % [key, float(trial[key])])
		rows.append({"label": label, "changed": changed, "report": report})
		print("tuning: probe %-46s games=%d score=%.4f +/-%.4f z=%+.2f mdi_z=%+.2f damage_z=%+.2f ko_z=%+.2f draws=%.3f turns=%.1f" % [
			label,
			int(report["games"]),
			float(report["score"]),
			float(report["error"]),
			float(report["z"]),
			float(report["mdi_z"]),
			float(report["damage_z"]),
			float(report["ko_z"]),
			float(report["draw_rate"]),
			float(report["mean_turns"]),
		])
	var file := FileAccess.open("%s/%s.json" % [OUTPUT_DIR, _arg("out", "probe")], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"seed_start": seed_start, "seeds": seeds, "games": games, "rows": rows}, "\t"))
		file.close()
	return 0


func _mode_pipeline() -> int:
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "48"))
	var seed_start: int = int(_arg("seed-start", "1"))
	var holdout: int = int(_arg("holdout", "16"))
	var games: int = int(_arg("games", "24"))
	var match_games: int = int(_arg("match-games", "24"))
	var tier: int = int(_arg("level", "5"))
	var min_round: int = int(_arg("min-round", "2"))
	var started: int = Time.get_ticks_msec()
	var book: Array = await _book(seed_start, seeds + holdout, team_size)
	if book.size() < seeds + 1:
		print("tuning: pipeline book too small (%d)" % book.size())
		return 1
	print("tuning: pipeline book=%d in %.1f s" % [book.size(), float(Time.get_ticks_msec() - started) / 1000.0])
	var train: Array = book.slice(0, seeds)
	var test: Array = book.slice(seeds, book.size())
	var base: Dictionary = _weights_from("base")
	started = Time.get_ticks_msec()
	var record: Array = []
	var played: int = 0
	for entry in train:
		var sim: BattleSim = entry["sim"]
		var brain0 := Brain.new()
		var brain1 := Brain.new()
		brain0.setup(sim, base, tier)
		brain1.setup(sim, base, tier)
		var pos := Position.new()
		pos.setup(sim, brain0)
		for g in range(games):
			_play(sim, entry["state"], brain0, brain1, 7919 * (g + 1) + int(entry["seed"]), record, pos, min_round)
			played += 1
	print("tuning: pipeline selfplay games=%d positions=%d in %.1f s" % [played, record.size(), float(Time.get_ticks_msec() - started) / 1000.0])
	var lines: PackedStringArray = PackedStringArray()
	for row in record:
		var values: PackedFloat64Array = row[0]
		var parts: PackedStringArray = PackedStringArray()
		for value in values:
			parts.append("%.6f" % value)
		lines.append("%s|%.1f|%d" % [",".join(parts), float(row[1]), int(row[2])])
	var csv := FileAccess.open("%s/%s.csv" % [OUTPUT_DIR, _arg("out", "pipeline")], FileAccess.WRITE)
	if csv != null:
		csv.store_string(",".join(FEATURE_NAMES) + "|result|round\n")
		csv.store_string("\n".join(lines))
		csv.close()
	var rows: Array = []
	for row in record:
		rows.append([row[0], float(row[1])])
	var report: Dictionary = _fit_rows(rows, float(_arg("l2", "0.0005")), int(_arg("steps", "25")), float(_arg("rate", "1.0")))
	_print_fit(report)
	var candidate: Dictionary = base.duplicate()
	var mapped: Dictionary = report["mapped"]
	for key in mapped.keys():
		candidate[key] = float(mapped[key])
	var fitted := FileAccess.open("%s/candidate.json" % OUTPUT_DIR, FileAccess.WRITE)
	if fitted != null:
		fitted.store_string(JSON.stringify({"weights": candidate}, "\t"))
		fitted.close()
	started = Time.get_ticks_msec()
	var duel_train: Dictionary = _duel(train, candidate, base, tier, maxi(1, match_games / 2))
	var duel_test: Dictionary = _duel(test, candidate, base, tier, match_games)
	print("tuning: pipeline duel(train) games=%d score=%.4f z=%.2f mdi_z=%.2f" % [int(duel_train["games"]), float(duel_train["score"]), float(duel_train["z"]), float(duel_train["mdi_z"])])
	print("tuning: pipeline duel(holdout) games=%d score=%.4f z=%.2f damage_z=%.2f ko_z=%.2f mdi_z=%.2f draws=%.3f turns=%.1f" % [
		int(duel_test["games"]),
		float(duel_test["score"]),
		float(duel_test["z"]),
		float(duel_test["damage_z"]),
		float(duel_test["ko_z"]),
		float(duel_test["mdi_z"]),
		float(duel_test["draw_rate"]),
		float(duel_test["mean_turns"]),
	])
	print("tuning: pipeline duel seconds=%.1f" % (float(Time.get_ticks_msec() - started) / 1000.0))
	var ablation: Array = []
	if _arg("ablate", "1") == "1":
		for key in mapped.keys():
			var single: Dictionary = base.duplicate()
			single[key] = float(mapped[key])
			var solo: Dictionary = _duel(test, single, base, tier, match_games)
			var drop: Dictionary = candidate.duplicate()
			drop[key] = float(base[key])
			var without: Dictionary = _duel(test, drop, candidate, tier, match_games)
			ablation.append({"key": key, "value": float(mapped[key]), "base": float(base[key]), "solo": solo, "without": without})
			print("tuning: ablate %-22s %.4f (base %.4f) solo score=%.4f z=%+.2f mdi_z=%+.2f draws=%.3f | revert score=%.4f z=%+.2f" % [
				key,
				float(mapped[key]),
				float(base[key]),
				float(solo["score"]),
				float(solo["z"]),
				float(solo["mdi_z"]),
				float(solo["draw_rate"]),
				float(without["score"]),
				float(without["z"]),
			])
	var search_iterations: int = int(_arg("iterations", "0"))
	var searched: Dictionary = candidate.duplicate()
	var history: Array = []
	if search_iterations > 0:
		var origin: Dictionary = base.duplicate() if _arg("descent-from", "base") == "base" else candidate.duplicate()
		searched = await _coordinate_descent(train, origin, tier, int(_arg("search-games", "8")), search_iterations, history)
		var duel_search: Dictionary = _duel(test, searched, base, tier, match_games)
		print("tuning: pipeline search(holdout vs base) games=%d score=%.4f z=%.2f mdi_z=%.2f" % [int(duel_search["games"]), float(duel_search["score"]), float(duel_search["z"]), float(duel_search["mdi_z"])])
		var duel_pair: Dictionary = _duel(test, searched, candidate, tier, match_games)
		print("tuning: pipeline search(holdout vs fit) games=%d score=%.4f z=%.2f" % [int(duel_pair["games"]), float(duel_pair["score"]), float(duel_pair["z"])])
		var tuned := FileAccess.open("%s/searched.json" % OUTPUT_DIR, FileAccess.WRITE)
		if tuned != null:
			tuned.store_string(JSON.stringify({"weights": searched, "history": history}, "\t"))
			tuned.close()
	var summary := FileAccess.open("%s/pipeline.json" % OUTPUT_DIR, FileAccess.WRITE)
	if summary != null:
		summary.store_string(JSON.stringify({
			"seeds": seeds,
			"holdout": book.size() - seeds,
			"games": played,
			"fit": report,
			"candidate": candidate,
			"searched": searched,
			"duel_train": duel_train,
			"duel_holdout": duel_test,
			"ablation": ablation,
			"search_history": history,
			"battle_ai_sha": _script_sha("res://data/modules/tactics/ai/battle_ai.gd"),
			"ai_profile_sha": _script_sha("res://data/modules/tactics/ai/ai_profile.gd"),
		}, "\t"))
		summary.close()
	return 0


func _script_sha(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text.sha256_text()


func _coordinate_descent(book: Array, start: Dictionary, tier: int, games: int, iterations: int, history: Array) -> Dictionary:
	var keys: Array[String] = []
	for token in _arg("keys", "CHIP_WEIGHT,CHIP_RISK,APPROACH_SCALE,TEMPO_BONUS,FOCUS_GAIN,RETALIATION_WEIGHT,LETHAL_RISK,SECURE_WEIGHT,VALUE_DURABILITY_WEIGHT").split(",", false):
		if BASE_WEIGHTS.has(String(token)):
			keys.append(String(token))
	var current: Dictionary = start.duplicate()
	var step: float = float(_arg("step", "0.35"))
	for iteration in range(iterations):
		var improved: bool = false
		for key in keys:
			var base_value: float = float(current[key])
			for direction in [1.0, -1.0]:
				var moved: float = base_value * (1.0 + direction * step)
				if absf(base_value) < 1e-6:
					moved = direction * step
				var trial: Dictionary = current.duplicate()
				trial[key] = moved
				var report: Dictionary = _duel(book, trial, current, tier, games)
				history.append({"iteration": iteration, "key": key, "value": moved, "score": report["score"], "z": report["z"], "mdi_z": report["mdi_z"]})
				print("tuning: descent it=%d %s %.4f -> %.4f score=%.4f z=%.2f mdi_z=%.2f" % [iteration, key, base_value, moved, float(report["score"]), float(report["z"]), float(report["mdi_z"])])
				if float(report["mdi_z"]) > 2.0 and float(report["score"]) >= 0.5:
					current[key] = moved
					improved = true
					break
		if not improved:
			step *= 0.6
			if step < 0.06:
				break
	return current


func _mode_speed() -> int:
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "2"))
	var started: int = Time.get_ticks_msec()
	var book: Array = await _book(int(_arg("seed-start", "1")), seeds, team_size)
	print("tuning: book %d entries in %d ms" % [book.size(), Time.get_ticks_msec() - started])
	if book.is_empty():
		return 1
	var weights: Dictionary = _weights_from(_arg("weights", "base"))
	var level: int = int(_arg("level", "5"))
	var games: int = int(_arg("games", "8"))
	var total_turns: int = 0
	started = Time.get_ticks_msec()
	for entry in book:
		var sim: BattleSim = entry["sim"]
		var brain0 := Brain.new()
		var brain1 := Brain.new()
		brain0.setup(sim, weights, level)
		brain1.setup(sim, weights, level)
		for g in range(games):
			var outcome: Dictionary = _play(sim, entry["state"], brain0, brain1, 1000 + g, null, null, 0)
			total_turns += int(outcome["turns"])
	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	var played: int = book.size() * games
	print("tuning: %d battles in %.2f s = %.2f battles/s, %.1f turns each" % [played, elapsed, float(played) / maxf(0.001, elapsed), float(total_turns) / float(maxi(1, played))])
	var pos := Position.new()
	var probe := Brain.new()
	probe.setup(book[0]["sim"], weights, level)
	pos.setup(book[0]["sim"], probe)
	started = Time.get_ticks_usec()
	for i in range(200):
		pos.features(book[0]["state"])
	print("tuning: feature extraction %.1f us" % (float(Time.get_ticks_usec() - started) / 200.0))
	return 0


func _mode_fidelity_live() -> int:
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "8"))
	var seed_start: int = int(_arg("seed-start", "1"))
	var tier: int = int(_arg("level", "5"))
	var base: Dictionary = _weights_from("base")
	var totals: Dictionary = {"decisions": 0, "exact": 0, "tile": 0, "slot": 0, "target": 0}
	var mismatches: Array = []
	for seed in range(seed_start, seed_start + seeds):
		var node: TacticsLevel = await _real_level(seed, team_size, tier)
		if node == null:
			continue
		var sim := BattleSim.new()
		sim.setup_from_level(node)
		var brain := Brain.new()
		brain.setup(sim, base, tier)
		var seen: Dictionary = {}
		var recorder := Recorder.new()
		recorder.set_team_levels(node.ai_team_levels)
		recorder.probe = func(unit: TacticsPawn, action: AIAction, battle_level: TacticsLevel) -> void:
			if not is_instance_valid(node) or not is_instance_valid(unit):
				return
			var stamp: int = battle_level.notation.turn_index if battle_level != null and battle_level.notation != null else -1
			var key: int = unit.get_instance_id()
			if int(seen.get(key, -12345)) == stamp:
				return
			seen[key] = stamp
			var pawns: Array[TacticsPawn] = sim._ordered_pawns(node)
			var index_of: Dictionary = {}
			for i in range(pawns.size()):
				index_of[pawns[i]] = i
			if not index_of.has(unit):
				return
			var idx: int = int(index_of[unit])
			var d: PackedInt32Array = sim.capture(node)
			var slot: int = 0
			if node.scheduler != null:
				for upcoming in node.scheduler.peek_upcoming(32):
					if upcoming == null or upcoming.pawn == null:
						continue
					if not index_of.has(upcoming.pawn):
						continue
					d[sim.field_off + BattleSim.F_QUEUE + slot] = int(index_of[upcoming.pawn])
					slot += 1
			d[sim.field_off + BattleSim.F_QLEN] = slot
			d[sim.field_off + BattleSim.F_QPOS] = 0
			d[sim.field_off + BattleSim.F_ACTIVE] = idx
			for i in range(pawns.size()):
				d[i * BattleSim.U_STRIDE + BattleSim.U_ACTED] = 1 if (pawns[i].res != null and pawns[i].res.has_acted_this_round) else 0
			brain.clear_memo()
			var packed: int = brain.choose(d, idx)
			var decoded: Vector3i = sim.decode_action(packed)
			var real_tile: Vector3i = Targeting._tile_key(action.move_to_tile) if action.move_to_tile != null else Vector3i(-99, 0, -99)
			var sim_tile: Vector3i = sim.tile_keys[decoded.x]
			var real_target: int = int(index_of.get(action.target_unit, -1)) if action.target_unit != null else -1
			var same_tile: bool = real_tile == sim_tile
			var same_slot: bool = action.move_index == decoded.y
			var same_target: bool = real_target == decoded.z
			totals["decisions"] = int(totals["decisions"]) + 1
			if same_tile:
				totals["tile"] = int(totals["tile"]) + 1
			if same_slot:
				totals["slot"] = int(totals["slot"]) + 1
			if same_target:
				totals["target"] = int(totals["target"]) + 1
			if same_tile and same_slot and same_target:
				totals["exact"] = int(totals["exact"]) + 1
			elif mismatches.size() < 200:
				mismatches.append({
					"seed": seed,
					"turn": stamp,
					"unit": idx,
					"real": [real_tile.x, real_tile.z, action.move_index, real_target],
					"sim": [sim_tile.x, sim_tile.z, decoded.y, decoded.z],
				})
		node.opponent.opponent_serv.battle_ai = recorder
		var ended: Array = [false]
		node.battle_ended.connect(func(_value: int) -> void:
			ended[0] = true)
		node.process_mode = Node.PROCESS_MODE_ALWAYS
		var frames: int = 0
		while frames < 24000 and not ended[0]:
			await physics_frame
			frames += 1
		if is_instance_valid(node):
			node.queue_free()
		await process_frame
		await process_frame
		print("tuning: live seed=%d decisions=%d exact=%d" % [seed, int(totals["decisions"]), int(totals["exact"])])
	var n: int = maxi(1, int(totals["decisions"]))
	print("tuning: live fidelity decisions=%d exact=%.3f tile=%.3f slot=%.3f target=%.3f" % [
		int(totals["decisions"]),
		float(totals["exact"]) / float(n),
		float(totals["tile"]) / float(n),
		float(totals["slot"]) / float(n),
		float(totals["target"]) / float(n),
	])
	var file := FileAccess.open("%s/fidelity_live.json" % OUTPUT_DIR, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"totals": totals, "mismatches": mismatches}, "\t"))
		file.close()
	return 0


func _mode_fidelity() -> int:
	if _arg("live", "0") == "1":
		return await _mode_fidelity_live()
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "12"))
	var level: int = int(_arg("level", "5"))
	var weights: Dictionary = _weights_from("base")
	var agree: int = 0
	var total: int = 0
	var tile_agree: int = 0
	var slot_agree: int = 0
	var target_agree: int = 0
	var rows: Array = []
	for seed in range(int(_arg("seed-start", "1")), int(_arg("seed-start", "1")) + seeds):
		var level_node: TacticsLevel = await _build_level(seed, team_size)
		if level_node == null:
			continue
		level_node.ai_team_levels = {
			PokemonInstanceResource.Team.PLAYER: level,
			PokemonInstanceResource.Team.ENEMY: level,
		}
		var sim := BattleSim.new()
		var state: PackedInt32Array = sim.setup_from_level(level_node)
		var brain := Brain.new()
		brain.setup(sim, weights, level)
		var pawns: Array[TacticsPawn] = sim._ordered_pawns(level_node)
		var ai := BattleAI.new()
		ai.set_level(level)
		for index in range(pawns.size()):
			var pawn: TacticsPawn = pawns[index]
			if pawn.stats == null or not pawn.stats.is_active():
				continue
			var allies: Array = []
			var enemies: Array = []
			for other in range(pawns.size()):
				if sim.unit_team(state, other) == sim.unit_team(state, index):
					allies.append(pawns[other])
				else:
					enemies.append(pawns[other])
			level_node.arena.reset_all_tile_markers()
			level_node.arena.process_surrounding_tiles(pawn.get_tile(), pawn.stats.movement, allies)
			level_node.arena.mark_reachable_tiles(pawn.get_tile(), pawn.stats.movement)
			ai.forget(pawn)
			var real: AIAction = ai.choose_action(pawn, allies, enemies, sim.type_chart, level_node)
			var packed: int = brain.choose(state, index)
			var sim_action: Vector3i = sim.decode_action(packed)
			var real_tile: Vector3i = Targeting._tile_key(real.move_to_tile) if real.move_to_tile != null else Vector3i(-1, 0, -1)
			var sim_tile: Vector3i = sim.tile_keys[sim_action.x]
			var real_target: int = pawns.find(real.target_unit) if real.target_unit != null else -1
			var same_tile: bool = real_tile == sim_tile
			var same_slot: bool = real.move_index == sim_action.y
			var same_target: bool = real_target == sim_action.z
			total += 1
			if same_tile:
				tile_agree += 1
			if same_slot:
				slot_agree += 1
			if same_target:
				target_agree += 1
			if same_tile and same_slot and same_target:
				agree += 1
			else:
				rows.append({
					"seed": seed,
					"unit": index,
					"real": [real_tile.x, real_tile.z, real.move_index, real_target],
					"sim": [sim_tile.x, sim_tile.z, sim_action.y, sim_action.z],
				})
		level_node.queue_free()
		await process_frame
	print("tuning: fidelity decisions=%d exact=%.3f tile=%.3f slot=%.3f target=%.3f" % [
		total,
		float(agree) / float(maxi(1, total)),
		float(tile_agree) / float(maxi(1, total)),
		float(slot_agree) / float(maxi(1, total)),
		float(target_agree) / float(maxi(1, total)),
	])
	var file := FileAccess.open("%s/fidelity.json" % OUTPUT_DIR, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"total": total, "exact": agree, "tile": tile_agree, "slot": slot_agree, "target": target_agree, "mismatches": rows}, "\t"))
		file.close()
	return 0


func _mode_selfplay() -> int:
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "16"))
	var seed_start: int = int(_arg("seed-start", "1"))
	var games: int = int(_arg("games", "16"))
	var level: int = int(_arg("level", "5"))
	var min_round: int = int(_arg("min-round", "2"))
	var weights: Dictionary = _weights_from(_arg("weights", "base"))
	var out_name: String = _arg("out", "selfplay")
	var book: Array = await _book(seed_start, seeds, team_size)
	if book.is_empty():
		return 1
	var record: Array = []
	var started: int = Time.get_ticks_msec()
	var played: int = 0
	var wins: float = 0.0
	for entry in book:
		var sim: BattleSim = entry["sim"]
		var brain0 := Brain.new()
		var brain1 := Brain.new()
		brain0.setup(sim, weights, level)
		brain1.setup(sim, weights, level)
		var pos := Position.new()
		pos.setup(sim, brain0)
		for g in range(games):
			var outcome: Dictionary = _play(sim, entry["state"], brain0, brain1, 7919 * (g + 1) + entry["seed"], record, pos, min_round)
			wins += float(outcome["score"])
			played += 1
	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	var lines: PackedStringArray = PackedStringArray()
	for row in record:
		var values: PackedFloat64Array = row[0]
		var parts: PackedStringArray = PackedStringArray()
		for value in values:
			parts.append("%.6f" % value)
		lines.append("%s|%.1f|%d" % [",".join(parts), float(row[1]), int(row[2])])
	var path: String = "%s/%s.csv" % [OUTPUT_DIR, out_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(",".join(FEATURE_NAMES) + "|result|round\n")
		file.store_string("\n".join(lines))
		file.close()
	print("tuning: selfplay games=%d positions=%d team0_score=%.3f seconds=%.1f rate=%.2f/s wrote %s" % [played, record.size(), wins / float(maxi(1, played)), elapsed, float(played) / maxf(0.001, elapsed), path])
	return 0


func _mode_fit() -> int:
	var path: String = _arg("data", "%s/selfplay.csv" % OUTPUT_DIR)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("tuning: cannot read %s" % path)
		return 1
	var text: String = file.get_as_text()
	file.close()
	var lines: PackedStringArray = text.split("\n", false)
	var rows: Array = []
	var min_round: int = int(_arg("min-round", "0"))
	for i in range(1, lines.size()):
		var parts: PackedStringArray = lines[i].split("|", false)
		if parts.size() < 3:
			continue
		if int(parts[2]) < min_round:
			continue
		var raw: PackedStringArray = parts[0].split(",", false)
		var values: PackedFloat64Array = PackedFloat64Array()
		for token in raw:
			values.append(float(token))
		rows.append([values, float(parts[1])])
	if rows.is_empty():
		print("tuning: no rows")
		return 1
	var report: Dictionary = _fit_rows(rows, float(_arg("l2", "0.0005")), int(_arg("steps", "25")), float(_arg("rate", "1.0")))
	_print_fit(report)
	var out := FileAccess.open("%s/fit.json" % OUTPUT_DIR, FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(report, "\t"))
		out.close()
	var merged: Dictionary = BASE_WEIGHTS.duplicate()
	var mapped: Dictionary = report["mapped"]
	for key in mapped.keys():
		merged[key] = mapped[key]
	var candidate := FileAccess.open("%s/candidate.json" % OUTPUT_DIR, FileAccess.WRITE)
	if candidate != null:
		candidate.store_string(JSON.stringify({"weights": merged}, "\t"))
		candidate.close()
	return 0


func _print_fit(report: Dictionary) -> void:
	print("tuning: fit rows=%d log_loss=%.4f brier=%.4f baseline_loss=%.4f" % [int(report["rows"]), float(report["log_loss"]), float(report["brier"]), float(report["baseline_loss"])])
	var features: Dictionary = report["features"]
	var sigma: Dictionary = report.get("std_error", {})
	for key in features.keys():
		var error: float = float(sigma.get(key, 0.0))
		print("tuning:   %-10s %+9.4f +/-%.4f  t=%+.1f" % [key, float(features[key]), error, float(features[key]) / maxf(1e-9, error)])
	var mapped: Dictionary = report["mapped"]
	for key in mapped.keys():
		print("tuning:   -> %-22s %.4f (base %.4f)" % [key, float(mapped[key]), float(BASE_WEIGHTS[key])])


func _fit_rows(rows: Array, lambda: float, steps: int, rate: float) -> Dictionary:
	var mask: PackedInt32Array = _feature_mask()
	var n: int = FEATURE_NAMES.size()
	var m: int = n + 1
	var weights: PackedFloat64Array = PackedFloat64Array()
	weights.resize(m)
	weights.fill(0.0)
	var count: float = float(rows.size())
	var iterations: int = maxi(1, steps)
	var hessian: PackedFloat64Array = PackedFloat64Array()
	hessian.resize(m * m)
	var gradient: PackedFloat64Array = PackedFloat64Array()
	gradient.resize(m)
	var x: PackedFloat64Array = PackedFloat64Array()
	x.resize(m)
	for iteration in range(iterations):
		hessian.fill(0.0)
		gradient.fill(0.0)
		for row in rows:
			var values: PackedFloat64Array = row[0]
			for k in range(n):
				x[k] = values[k]
			x[n] = 1.0
			var z: float = 0.0
			for k in range(m):
				z += weights[k] * x[k]
			var p: float = 1.0 / (1.0 + exp(-z))
			var err: float = p - float(row[1])
			var weight: float = maxf(p * (1.0 - p), 1e-6)
			for a in range(m):
				gradient[a] += err * x[a]
				var xa: float = weight * x[a]
				for b in range(a, m):
					hessian[a * m + b] += xa * x[b]
		for a in range(m):
			gradient[a] = gradient[a] / count
			for b in range(a, m):
				var value: float = hessian[a * m + b] / count
				hessian[a * m + b] = value
				hessian[b * m + a] = value
		for a in range(n):
			gradient[a] += lambda * weights[a]
			hessian[a * m + a] += lambda
			if mask[a] == 0:
				gradient[a] += 1e6 * weights[a]
				hessian[a * m + a] += 1e6
		hessian[n * m + n] += 1e-9
		var delta: PackedFloat64Array = _solve(hessian, gradient, m)
		var moved: float = 0.0
		for a in range(m):
			weights[a] -= rate * delta[a]
			moved = maxf(moved, absf(delta[a]))
		if moved < 1e-9:
			break
	var errors: PackedFloat64Array = _diagonal_inverse(hessian, m)
	var loss: float = 0.0
	var brier: float = 0.0
	var mean_label: float = 0.0
	for row in rows:
		mean_label += float(row[1])
	mean_label /= count
	var baseline: float = -(mean_label * log(maxf(mean_label, 1e-9)) + (1.0 - mean_label) * log(maxf(1.0 - mean_label, 1e-9)))
	for row in rows:
		var values: PackedFloat64Array = row[0]
		var z: float = weights[n]
		for k in range(n):
			z += weights[k] * values[k]
		var p: float = 1.0 / (1.0 + exp(-z))
		var label: float = float(row[1])
		loss += -(label * log(maxf(p, 1e-9)) + (1.0 - label) * log(maxf(1.0 - p, 1e-9)))
		brier += (label - p) * (label - p)
	loss /= count
	brier /= count
	var features: Dictionary = {}
	var sigma: Dictionary = {}
	for k in range(n):
		if mask[k] == 0:
			continue
		features[FEATURE_NAMES[k]] = weights[k]
		sigma[FEATURE_NAMES[k]] = sqrt(maxf(errors[k], 0.0) / count)
	return {
		"rows": rows.size(),
		"log_loss": loss,
		"brier": brier,
		"baseline_loss": baseline,
		"bias": weights[n],
		"features": features,
		"std_error": sigma,
		"raw": weights,
		"mask": mask,
		"mapped": _map_weights(weights, mask),
	}


func _feature_mask() -> PackedInt32Array:
	var mask: PackedInt32Array = PackedInt32Array()
	mask.resize(FEATURE_NAMES.size())
	var wanted: String = _arg("features", "alive,hp,threat,stages,status,dist,formation,tempo")
	if wanted == "all":
		mask.fill(1)
		return mask
	mask.fill(0)
	for token in wanted.split(",", false):
		var index: int = FEATURE_NAMES.find(String(token).strip_edges())
		if index >= 0:
			mask[index] = 1
	return mask


func _solve(matrix: PackedFloat64Array, vector: PackedFloat64Array, m: int) -> PackedFloat64Array:
	var a: PackedFloat64Array = matrix.duplicate()
	var b: PackedFloat64Array = vector.duplicate()
	for col in range(m):
		var pivot: int = col
		var best: float = absf(a[col * m + col])
		for row in range(col + 1, m):
			if absf(a[row * m + col]) > best:
				best = absf(a[row * m + col])
				pivot = row
		if best < 1e-14:
			continue
		if pivot != col:
			for k in range(m):
				var swap: float = a[col * m + k]
				a[col * m + k] = a[pivot * m + k]
				a[pivot * m + k] = swap
			var swap_b: float = b[col]
			b[col] = b[pivot]
			b[pivot] = swap_b
		var diagonal: float = a[col * m + col]
		for row in range(m):
			if row == col:
				continue
			var factor: float = a[row * m + col] / diagonal
			if factor == 0.0:
				continue
			for k in range(col, m):
				a[row * m + k] -= factor * a[col * m + k]
			b[row] -= factor * b[col]
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(m)
	for col in range(m):
		var diagonal: float = a[col * m + col]
		out[col] = b[col] / diagonal if absf(diagonal) > 1e-14 else 0.0
	return out


func _diagonal_inverse(matrix: PackedFloat64Array, m: int) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(m)
	for i in range(m):
		var unit: PackedFloat64Array = PackedFloat64Array()
		unit.resize(m)
		unit.fill(0.0)
		unit[i] = 1.0
		var column: PackedFloat64Array = _solve(matrix, unit, m)
		out[i] = column[i]
	return out


func _map_weights(v: PackedFloat64Array, mask: PackedInt32Array) -> Dictionary:
	var out: Dictionary = {}
	var alive_index: int = FEATURE_NAMES.find("alive")
	var hp_index: int = FEATURE_NAMES.find("hp")
	if mask[alive_index] == 0 or mask[hp_index] == 0:
		return out
	var ko_value: float = v[alive_index] + v[hp_index]
	if ko_value <= 0.0001:
		return out
	var scale: float = 100.0 / ko_value
	var risk: float = float(BASE_WEIGHTS["RISK_5"])
	var approach: float = float(BASE_WEIGHTS["APPROACH_5"])
	out["CHIP_WEIGHT"] = clampf(v[hp_index] / ko_value, 0.05, 1.5)
	var pairs: Array = [
		["threat", "CHIP_RISK", 1.0 / risk, 0.0, 400.0],
		["lethal", "LETHAL_RISK", 1.0 / risk, 0.0, 600.0],
		["hazard", "HAZARD_PENALTY", 1.0, 0.0, 400.0],
		["formation", "ZONE_BONUS", 1.0, 0.0, 100.0],
		["status", "STATUS_SCORE", 1.0, 0.0, 300.0],
		["stages", "SETUP_SCORE", 1.0, 0.0, 300.0],
		["dist", "APPROACH_SCALE", 1.0 / approach, 0.0, 120.0],
	]
	for entry in pairs:
		var index: int = FEATURE_NAMES.find(String(entry[0]))
		if index < 0 or mask[index] == 0:
			continue
		out[String(entry[1])] = clampf(scale * v[index] * float(entry[2]), float(entry[3]), float(entry[4]))
	return out


func _mode_match() -> int:
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "16"))
	var seed_start: int = int(_arg("seed-start", "1"))
	var games: int = int(_arg("games", "16"))
	var level: int = int(_arg("level", "5"))
	var a: Dictionary = _weights_from(_arg("a", "base"))
	var b: Dictionary = _weights_from(_arg("b", "base"))
	var book: Array = await _book(seed_start, seeds, team_size)
	if book.is_empty():
		return 1
	var report: Dictionary = _duel(book, a, b, level, games)
	print("tuning: match games=%d score=%.4f +/-%.4f z=%.2f" % [int(report["games"]), float(report["score"]), float(report["error"]), float(report["z"])])
	print("tuning: paired damage_share=%.4f +/-%.4f z=%.2f" % [float(report["damage_share"]), float(report["damage_error"]), float(report["damage_z"])])
	print("tuning: paired ko_share=%.4f +/-%.4f z=%.2f" % [float(report["ko_share"]), float(report["ko_error"]), float(report["ko_z"])])
	print("tuning: paired hp_share=%.4f +/-%.4f z=%.2f" % [float(report["hp_share"]), float(report["hp_error"]), float(report["hp_z"])])
	print("tuning: paired mdi_turn=%+.4f +/-%.4f z=%.2f" % [float(report["mdi_turn"]), float(report["mdi_error"]), float(report["mdi_z"])])
	print("tuning: paired draw_rate=%.4f mean_turns=%.1f" % [float(report["draw_rate"]), float(report["mean_turns"])])
	var file := FileAccess.open("%s/%s.json" % [OUTPUT_DIR, _arg("out", "match")], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	return 0


func _duel(book: Array, a: Dictionary, b: Dictionary, level: int, games: int) -> Dictionary:
	var pair_scores: Array[float] = []
	var pair_damage: Array[float] = []
	var pair_ko: Array[float] = []
	var pair_hp: Array[float] = []
	var pair_mdi: Array[float] = []
	var draws: int = 0
	var battles: int = 0
	var turn_total: float = 0.0
	for entry in book:
		var sim: BattleSim = entry["sim"]
		var brain_a := Brain.new()
		var brain_b := Brain.new()
		brain_a.setup(sim, a, level)
		brain_b.setup(sim, b, level)
		for g in range(games):
			var rng_state: int = 7919 * (g + 1) + int(entry["seed"])
			var first: Dictionary = _play(sim, entry["state"], brain_a, brain_b, rng_state, null, null, 0)
			var second: Dictionary = _play(sim, entry["state"], brain_b, brain_a, rng_state, null, null, 0)
			pair_scores.append((float(first["score"]) + (1.0 - float(second["score"]))) * 0.5)
			pair_damage.append((float(first["damage_share"]) + (1.0 - float(second["damage_share"]))) * 0.5)
			pair_ko.append((float(first["ko_share"]) + (1.0 - float(second["ko_share"]))) * 0.5)
			pair_hp.append((float(first["hp_share"]) + (1.0 - float(second["hp_share"]))) * 0.5)
			pair_mdi.append((float(first["mdi_turn"]) - float(second["mdi_turn"])) * 0.5)
			battles += 2
			turn_total += float(first["turns"]) + float(second["turns"])
			if int(first["result"]) == BattleSim.RESULT_DRAW:
				draws += 1
			if int(second["result"]) == BattleSim.RESULT_DRAW:
				draws += 1
	var stats_score: Array = _summary(pair_scores)
	var stats_damage: Array = _summary(pair_damage)
	var stats_ko: Array = _summary(pair_ko)
	var stats_hp: Array = _summary(pair_hp)
	var stats_mdi: Array = _summary_zero(pair_mdi)
	return {
		"games": pair_scores.size() * 2,
		"pairs": pair_scores.size(),
		"score": stats_score[0],
		"error": stats_score[1],
		"z": stats_score[2],
		"damage_share": stats_damage[0],
		"damage_error": stats_damage[1],
		"damage_z": stats_damage[2],
		"ko_share": stats_ko[0],
		"ko_error": stats_ko[1],
		"ko_z": stats_ko[2],
		"hp_share": stats_hp[0],
		"hp_error": stats_hp[1],
		"hp_z": stats_hp[2],
		"mdi_turn": stats_mdi[0],
		"mdi_error": stats_mdi[1],
		"mdi_z": stats_mdi[2],
		"draw_rate": float(draws) / float(maxi(1, battles)),
		"mean_turns": turn_total / float(maxi(1, battles)),
	}


func _summary(values: Array[float]) -> Array:
	var n: int = values.size()
	if n == 0:
		return [0.5, 0.0, 0.0]
	var mean: float = 0.0
	for value in values:
		mean += value
	mean /= float(n)
	var variance: float = 0.0
	for value in values:
		variance += (value - mean) * (value - mean)
	variance = variance / float(maxi(1, n - 1))
	var error: float = sqrt(variance / float(n))
	var z: float = (mean - 0.5) / maxf(1e-9, error)
	return [mean, error, z]


func _mode_search() -> int:
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "24"))
	var seed_start: int = int(_arg("seed-start", "1"))
	var games: int = int(_arg("games", "8"))
	var level: int = int(_arg("level", "5"))
	var iterations: int = int(_arg("iterations", "8"))
	var book: Array = await _book(seed_start, seeds, team_size)
	if book.is_empty():
		return 1
	var history: Array = []
	var current: Dictionary = await _coordinate_descent(book, _weights_from(_arg("start", "base")), level, games, iterations, history)
	var file := FileAccess.open("%s/%s.json" % [OUTPUT_DIR, _arg("out", "search")], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"weights": current, "history": history}, "\t"))
		file.close()
	var changed: Array = []
	for key in BASE_WEIGHTS.keys():
		if not is_equal_approx(float(current[key]), float(BASE_WEIGHTS[key])):
			changed.append("%s=%.4f" % [key, float(current[key])])
	print("tuning: search done, changed %s" % ", ".join(changed))
	return 0


func _real_level(seed: int, team_size: int, level: int) -> TacticsLevel:
	var node: TacticsLevel = await _build_level(seed, team_size)
	if node == null:
		return null
	node.ai_team_levels = {
		PokemonInstanceResource.Team.PLAYER: level,
		PokemonInstanceResource.Team.ENEMY: level,
	}
	return node


func _real_battle(seed: int, team_size: int, level: int, player: Dictionary, enemy: Dictionary, stock: bool) -> Dictionary:
	var out: Dictionary = {"ok": false}
	var node: TacticsLevel = await _real_level(seed, team_size, level)
	if node == null:
		return out
	if not stock:
		var tuned := TunedAI.new()
		tuned.team_weights = {
			PokemonInstanceResource.Team.PLAYER: player,
			PokemonInstanceResource.Team.ENEMY: enemy,
		}
		tuned.set_team_levels(node.ai_team_levels)
		node.opponent.opponent_serv.battle_ai = tuned
	var bucket: Dictionary = {"turns": [], "dealt": {0: 0.0, 1: 0.0}, "losses": {0: 0.0, 1: 0.0}}
	node.battle_log.event_appended.connect(func(event: Dictionary) -> void:
		if not is_instance_valid(node):
			return
		var kind: String = String(event.get("kind", ""))
		if kind == "turn_started":
			var total: float = 0.0
			for pawn in node.units_on_map():
				if pawn.stats == null or pawn.stats.max_health <= 0:
					continue
				var fraction: float = clampf(float(pawn.stats.curr_health) / float(pawn.stats.max_health), 0.0, 1.0)
				total += fraction if node.pawn_team(pawn) == PokemonInstanceResource.Team.PLAYER else -fraction
			(bucket["turns"] as Array).append(total)
		elif kind == "damage_dealt":
			var defender: TacticsPawn = event.get("defender", null) as TacticsPawn
			var attacker: TacticsPawn = event.get("attacker", null) as TacticsPawn
			var amount: int = int(event.get("amount", 0))
			if defender == null or attacker == null or amount <= 0:
				return
			if not is_instance_valid(defender) or not is_instance_valid(attacker):
				return
			var attacker_team: int = node.pawn_team(attacker)
			if attacker_team == node.pawn_team(defender):
				return
			bucket["dealt"][attacker_team] = float(bucket["dealt"][attacker_team]) + float(amount)
		elif kind == "unit_fainted":
			var fallen: TacticsPawn = event.get("unit", null) as TacticsPawn
			if fallen != null and is_instance_valid(fallen):
				bucket["losses"][node.pawn_team(fallen)] = float(bucket["losses"][node.pawn_team(fallen)]) + 1.0)
	var ended: Array = [false, -1]
	node.battle_ended.connect(func(value: int) -> void:
		ended[0] = true
		ended[1] = value)
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	var frames: int = 0
	while frames < 24000 and not ended[0]:
		await physics_frame
		frames += 1
	var transcript: String = ""
	if is_instance_valid(node) and node.notation != null:
		transcript = "\n".join(node.notation.lines)
	var score: float = 0.5
	if ended[0] and ended[1] == TacticsLevel.RESULT_PLAYER_WIN:
		score = 1.0
	elif ended[0] and ended[1] == TacticsLevel.RESULT_PLAYER_LOSS:
		score = 0.0
	var dealt: float = float(bucket["dealt"][0])
	var received: float = float(bucket["dealt"][1])
	var kos: float = float(bucket["losses"][1])
	var lost: float = float(bucket["losses"][0])
	var samples: Array = bucket["turns"]
	var mdi: float = 0.0
	for value in samples:
		mdi += float(value)
	mdi = mdi / float(maxi(1, samples.size()))
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
	await process_frame
	return {
		"ok": true,
		"score": score,
		"stalled": not ended[0],
		"damage_share": dealt / maxf(1.0, dealt + received),
		"ko_share": (kos + 0.5) / (kos + lost + 1.0),
		"mdi_turn": mdi,
		"frames": frames,
		"hash": transcript.sha256_text(),
	}


func _mode_real() -> int:
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "24"))
	var seed_start: int = int(_arg("seed-start", "1"))
	var level: int = int(_arg("level", "5"))
	var a: Dictionary = _weights_from(_arg("a", "base"))
	var b: Dictionary = _weights_from(_arg("b", "base"))
	var scores: Array[float] = []
	var damage: Array[float] = []
	var ko: Array[float] = []
	var mdi: Array[float] = []
	var stalls: int = 0
	var rows: Array = []
	var started: int = Time.get_ticks_msec()
	for seed in range(seed_start, seed_start + seeds):
		var first: Dictionary = await _real_battle(seed, team_size, level, a, b, false)
		if not bool(first.get("ok", false)):
			continue
		var second: Dictionary = await _real_battle(seed, team_size, level, b, a, false)
		if not bool(second.get("ok", false)):
			continue
		if bool(first.get("stalled", false)):
			stalls += 1
		if bool(second.get("stalled", false)):
			stalls += 1
		scores.append((float(first["score"]) + (1.0 - float(second["score"]))) * 0.5)
		damage.append((float(first["damage_share"]) + (1.0 - float(second["damage_share"]))) * 0.5)
		ko.append((float(first["ko_share"]) + (1.0 - float(second["ko_share"]))) * 0.5)
		mdi.append((float(first["mdi_turn"]) - float(second["mdi_turn"])) * 0.5)
		rows.append({"seed": seed, "first": first, "second": second})
		print("tuning: real seed=%d pair_score=%.2f pair_damage=%.3f pair_mdi=%+.3f" % [seed, scores[scores.size() - 1], damage[damage.size() - 1], mdi[mdi.size() - 1]])
	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	var s_score: Array = _summary(scores)
	var s_damage: Array = _summary(damage)
	var s_ko: Array = _summary(ko)
	var s_mdi: Array = _summary_zero(mdi)
	print("tuning: real pairs=%d battles=%d stalls=%d seconds=%.1f" % [scores.size(), scores.size() * 2, stalls, elapsed])
	print("tuning: real score=%.4f +/-%.4f z=%.2f" % [s_score[0], s_score[1], s_score[2]])
	print("tuning: real damage_share=%.4f +/-%.4f z=%.2f" % [s_damage[0], s_damage[1], s_damage[2]])
	print("tuning: real ko_share=%.4f +/-%.4f z=%.2f" % [s_ko[0], s_ko[1], s_ko[2]])
	print("tuning: real mdi_turn=%+.4f +/-%.4f z=%.2f" % [s_mdi[0], s_mdi[1], s_mdi[2]])
	var file := FileAccess.open("%s/%s.json" % [OUTPUT_DIR, _arg("out", "real")], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"pairs": scores.size(),
			"stalls": stalls,
			"score": s_score,
			"damage_share": s_damage,
			"ko_share": s_ko,
			"mdi_turn": s_mdi,
			"battles": rows,
		}, "\t"))
		file.close()
	return 0


func _summary_zero(values: Array[float]) -> Array:
	var n: int = values.size()
	if n == 0:
		return [0.0, 0.0, 0.0]
	var mean: float = 0.0
	for value in values:
		mean += value
	mean /= float(n)
	var variance: float = 0.0
	for value in values:
		variance += (value - mean) * (value - mean)
	variance = variance / float(maxi(1, n - 1))
	var error: float = sqrt(variance / float(n))
	return [mean, error, mean / maxf(1e-9, error)]


func _mode_verify() -> int:
	var team_size: int = int(_arg("team", "4"))
	var seeds: int = int(_arg("seeds", "6"))
	var seed_start: int = int(_arg("seed-start", "1"))
	var level: int = int(_arg("level", "5"))
	var base: Dictionary = _weights_from("base")
	var equal: int = 0
	var repeatable: int = 0
	var total: int = 0
	for seed in range(seed_start, seed_start + seeds):
		var stock: Dictionary = await _real_battle(seed, team_size, level, base, base, true)
		var again: Dictionary = await _real_battle(seed, team_size, level, base, base, true)
		var tuned: Dictionary = await _real_battle(seed, team_size, level, base, base, false)
		if not bool(stock.get("ok", false)) or not bool(tuned.get("ok", false)) or not bool(again.get("ok", false)):
			continue
		total += 1
		if String(stock["hash"]) == String(again["hash"]):
			repeatable += 1
		if String(stock["hash"]) == String(tuned["hash"]):
			equal += 1
		print("tuning: verify seed=%d stock_repeat=%s tuned_equal=%s score=%.1f/%.1f" % [
			seed,
			str(String(stock["hash"]) == String(again["hash"])),
			str(String(stock["hash"]) == String(tuned["hash"])),
			float(stock["score"]),
			float(tuned["score"]),
		])
	print("tuning: verify stock_repeatable=%d/%d tuned_identical=%d/%d" % [repeatable, total, equal, total])
	return 0 if equal == total and total > 0 else 1


class TunedAI:
	extends BattleAI

	var team_weights: Dictionary = {}
	var w: Dictionary = {}

	func _use_profile(unit: TacticsPawn) -> void:
		var team: int = _team_of(unit)
		var wanted: int = level_for_team(team)
		if not _profiles.has(wanted):
			_profiles[wanted] = AIProfile.for_level(wanted)
		profile = _profiles[wanted]
		w = team_weights.get(team, {})
		profile.risk_weight = float(w["RISK_%d" % wanted])
		profile.approach_weight = float(w["APPROACH_%d" % wanted])

	func _unit_value(pawn: TacticsPawn) -> float:
		if pawn == null or pawn.stats == null:
			return 0.0
		var offence: float = float(maxi(pawn.stats.attack, pawn.stats.special_attack))
		var durability: float = float(pawn.stats.max_health)
		return float(w["VALUE_OFFENCE_WEIGHT"]) * offence + float(w["VALUE_DURABILITY_WEIGHT"]) * durability

	func _support_score(unit: TacticsPawn, move: PokemonMoveResource, target: TacticsPawn) -> float:
		var fam: Dictionary = _families(move)
		var score: float = 0.0
		if fam.has("status:hit_target") and target != unit and profile.consider_status_moves:
			if target.stats != null and target.stats.battle_statuses.is_empty():
				score += float(w["STATUS_SCORE"])
		if fam.has("stat_raise:self") or (fam.has("stat_stage") and target == unit and not fam.has("stat_drop:self")):
			if profile.consider_setup_moves:
				score += float(w["SETUP_SCORE"]) * _setup_headroom(unit)
		elif fam.has("stat_drop:hit_target") and target != unit and profile.consider_status_moves:
			score += float(w["STATUS_SCORE"]) * 0.6 * _setup_headroom(target)
		if (fam.has("field_condition") or fam.has("weather_stat_stage")) and profile.consider_field_moves and not _field_already_set(move):
			score += float(w["FIELD_SCORE"])
		if fam.has("heal") or fam.has("cure_statuses") or fam.has("status_remove"):
			if target != null and target.stats != null and target.stats.max_health > 0:
				var missing: float = 1.0 - float(target.stats.curr_health) / float(target.stats.max_health)
				score += float(w["STATUS_SCORE"]) * missing
		return score

	func _target_preference(unit: TacticsPawn, target: TacticsPawn, retaliation: Dictionary) -> float:
		if target == null or target.stats == null or target.stats.max_health <= 0:
			return 0.0
		var hp_fraction: float = float(target.stats.curr_health) / float(target.stats.max_health)
		match profile.target_mode:
			AIProfile.TargetMode.NEAREST:
				return -float(_manhattan(_key_of(unit), _key_of(target))) * float(w["NEAREST_WEIGHT"])
			AIProfile.TargetMode.WEAKEST:
				return -100.0 * hp_fraction * float(w["WEAKEST_WEIGHT"])
			AIProfile.TargetMode.MATCHUP:
				return 0.0
			AIProfile.TargetMode.SECURE_KO:
				return -100.0 * hp_fraction * float(w["SECURE_WEIGHT"])
			AIProfile.TargetMode.EXPECTED_VALUE:
				return -100.0 * hp_fraction * float(w["SECURE_WEIGHT"])
		return 0.0

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
				value = 100.0 * share * (chance + (1.0 - chance) * float(w["CHIP_WEIGHT"]) * chip)
				if chance > 0.0 and profile.turn_order_aware and _acts_before(unit, hit):
					value += float(w["TEMPO_BONUS"]) * chance
			else:
				var expected: float = _expected_for(unit, move, index, hit, damage_table)
				if expected <= 0.0:
					continue
				value = 100.0 * minf(expected / remaining, 1.0)
				if expected >= remaining and profile.target_mode >= AIProfile.TargetMode.SECURE_KO:
					value += float(w["KO_BONUS"])
					if profile.turn_order_aware and _acts_before(unit, hit):
						value += float(w["TEMPO_BONUS"])
			if profile.shared_focus and focus != null and hit == focus:
				value *= float(w["FOCUS_GAIN"])
			total += value
		return total

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
				modifiers -= float(w["RETALIATION_WEIGHT"]) * 100.0 * minf(float(retaliation.get(target, 0.0)) / pool, 1.0)
		else:
			base = _support_score(unit, move, target)
			if base <= 0.0:
				return INVALID_SCORE
		if hostile:
			modifiers += _target_preference(unit, target, retaliation)
			if not move.is_damaging() and profile.shared_focus and focus != null and target == focus:
				modifiers += float(w["FOCUS_BONUS"])
		return base + modifiers

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
				score -= float(w["HAZARD_PENALTY"])
		var retreating: bool = false
		if profile.retreat_when_losing and not engaging and unit.stats != null and unit.stats.max_health > 0:
			retreating = float(unit.stats.curr_health) / float(unit.stats.max_health) < float(w["RETREAT_HP_FRACTION"])
		if profile.threat_aware and engaging:
			var pool: float = maxf(1.0, float(unit.stats.curr_health)) if unit.stats != null else 1.0
			var spread: float = _threat_at(key, threat)
			var worst: float = _worst_single(key, threat)
			var chip: float = minf(spread / pool, 1.0)
			var combined: float = maxf(worst, _raw_threat_at(key, threat))
			var band: float = maxf(0.0001, float(w["LETHAL_BAND"]))
			var lethal: float = clampf(combined / pool - float(w["LETHAL_FLOOR"]), 0.0, band) / band
			score -= profile.risk_weight * (float(w["CHIP_RISK"]) * chip + float(w["LETHAL_RISK"]) * lethal)
			if retreating and spread <= 0.0:
				score += float(w["RETREAT_BONUS"])
		var anchor: TacticsPawn = focus if (profile.focus_fire_staging and focus != null and not engaging) else _nearest(unit, foes)
		if anchor != null:
			var distance: int = _manhattan(key, _key_of(anchor))
			if retreating:
				score += profile.approach_weight * float(w["APPROACH_SCALE"]) * float(distance) * 0.5
			else:
				score -= profile.approach_weight * float(w["APPROACH_SCALE"]) * float(distance)
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
		return float(w["ZONE_BONUS"]) * minf(float(nearby), 2.0)

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
				score += float(w["WINDOW_BONUS"]) * float(hands)
				score += 100.0 * (_unit_value(foe) / _reference_value) * 0.15
			else:
				score = -float(foe.stats.curr_health)
			if score > best_score:
				best_score = score
				best = foe
		_focus_cache[team] = {"round": round_key, "target": best}
		return best
