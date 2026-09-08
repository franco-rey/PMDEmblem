extends SceneTree

const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const OUTPUT_DIR: String = "res://logs/debug/validation"
const MAX_FRAMES: int = 24000
const ADVANTAGE_THRESHOLD: float = 0.5
const ADVANTAGE_CAP: int = 25
const ELO_ITERATIONS: int = 500
const METRIC_ORDER: Array[String] = [
	"win",
	"mdi_round",
	"mdi_turn",
	"lead_share",
	"final_margin",
	"damage_share",
	"damage_ratio_log",
	"damage_per_turn",
	"ko_diff",
	"ko_share",
	"advantage_round",
	"attack_rate",
	"waste_rate",
	"idle_rate",
	"effectiveness",
	"focus",
]
const LOWER_IS_BETTER: Array[String] = ["waste_rate", "idle_rate", "advantage_round"]

var battles: Array[Dictionary] = []
var samples: Dictionary = {}
var games: Array[Dictionary] = []
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _arg(key: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		var text: String = String(argument)
		if text.begins_with("--%s=" % key):
			return text.split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var seeds: int = int(_arg("seeds", "8"))
	var seed_start: int = int(_arg("seed-start", "1"))
	var team_size: int = int(_arg("team", "4"))
	var mode: String = _arg("mode", "gauntlet")
	var anchor: int = AIProfile.clamp_level(int(_arg("anchor", "3")))
	var out_name: String = _arg("out", "ai_benchmark")
	var levels: Array[int] = []
	for token in _arg("levels", "1,2,3,4,5").split(",", false):
		var value: int = AIProfile.clamp_level(int(token))
		if not levels.has(value):
			levels.append(value)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for level in levels:
		samples[level] = []
	var started: int = Time.get_ticks_msec()
	for seed in range(seed_start, seed_start + seeds):
		if mode == "roundrobin":
			for i in range(levels.size()):
				for j in range(levels.size()):
					if i >= j:
						continue
					for swap in [false, true]:
						var first: int = levels[j] if swap else levels[i]
						var second: int = levels[i] if swap else levels[j]
						await _play(seed, team_size, first, second, [PokemonInstanceResource.Team.PLAYER, PokemonInstanceResource.Team.ENEMY])
		else:
			for level in levels:
				for swap in [false, true]:
					var tested: int = PokemonInstanceResource.Team.ENEMY if swap else PokemonInstanceResource.Team.PLAYER
					await _play(seed, team_size, anchor if swap else level, level if swap else anchor, [tested])
	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	var aggregates: Dictionary = _aggregate(levels)
	var ratings: Dictionary = _ratings(levels)
	var paired: bool = mode != "roundrobin"
	var analysis: Array[Dictionary] = _analysis(levels, aggregates, paired)
	_print_report(levels, aggregates, ratings, analysis, paired, mode, anchor, elapsed)
	var file := FileAccess.open("%s/%s.json" % [OUTPUT_DIR, out_name], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"generated": Time.get_datetime_string_from_system(),
			"mode": mode,
			"anchor": anchor,
			"seeds": seeds,
			"seed_start": seed_start,
			"team_size": team_size,
			"levels": levels,
			"seconds": elapsed,
			"aggregates": _json_safe(aggregates),
			"ratings": _json_safe(ratings),
			"analysis": analysis,
			"samples": _json_safe(samples),
			"battles": battles,
		}, "\t"))
		file.close()
	quit(1 if battles.is_empty() else 0)


func _play(seed: int, team_size: int, player_level: int, enemy_level: int, sides: Array) -> void:
	var outcome: Dictionary = await _battle(seed, team_size, player_level, enemy_level)
	battles.append(outcome)
	var result: String = String(outcome.get("result", "draw"))
	if result == "build_failed" or result == "load_failed":
		failures += 1
		print("bench: seed=%d p=L%d e=L%d %s" % [seed, player_level, enemy_level, result])
		return
	var score: float = 1.0 if result == "player" else (0.0 if result == "enemy" else 0.5)
	games.append({"a": player_level, "b": enemy_level, "score_a": score})
	var by_side: Dictionary = outcome.get("sides", {})
	for side in sides:
		var level: int = player_level if side == PokemonInstanceResource.Team.PLAYER else enemy_level
		var metrics: Dictionary = by_side.get(side, {})
		if metrics.is_empty():
			continue
		var record: Dictionary = metrics.duplicate()
		record["key"] = "%d:%s" % [seed, "p" if side == PokemonInstanceResource.Team.PLAYER else "e"]
		(samples[level] as Array).append(record)
	var tested: int = int(sides[0])
	var shown: Dictionary = by_side.get(tested, {})
	print("bench: seed=%d p=L%d e=L%d result=%s rounds=%d frames=%d side=%s win=%.1f mdi=%+.3f dmg=%.3f ko=%+.0f waste=%.3f attack=%.3f" % [
		seed,
		player_level,
		enemy_level,
		result,
		int(outcome.get("rounds", 0)),
		int(outcome.get("frames", 0)),
		"p" if tested == PokemonInstanceResource.Team.PLAYER else "e",
		float(shown.get("win", 0.5)),
		float(shown.get("mdi_round", 0.0)),
		float(shown.get("damage_share", 0.5)),
		float(shown.get("ko_diff", 0.0)),
		float(shown.get("waste_rate", 0.0)),
		float(shown.get("attack_rate", 0.0)),
	])


func _battle(seed: int, team_size: int, player_level: int, enemy_level: int) -> Dictionary:
	var out: Dictionary = {"seed": seed, "player_level": player_level, "enemy_level": enemy_level}
	var built: Dictionary = CustomSkirmishBuilder.build_random(team_size, MAP_PATH, str(seed), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
	if not bool(built.get("ok", false)):
		out["result"] = "build_failed"
		out["error"] = String(built.get("error", ""))
		return out
	var definition: SkirmishDefinitionResource = built["definition"]
	definition.skirmish_id = "ai_bench_%d_%d_%d" % [seed, player_level, enemy_level]
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	if level == null:
		out["result"] = "load_failed"
		loader.queue_free()
		return out
	level.ai_team_levels = {
		PokemonInstanceResource.Team.PLAYER: player_level,
		PokemonInstanceResource.Team.ENEMY: enemy_level,
	}
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var bucket: Dictionary = _new_bucket()
	level.battle_log.event_appended.connect(_on_battle_event.bind(level, bucket))
	if level.scheduler != null:
		level.scheduler.round_started.connect(_on_round_started.bind(level, bucket))
	var ended: Array = [false, -1]
	level.battle_ended.connect(func(value: int) -> void:
		ended[0] = true
		ended[1] = value)
	var frames: int = 0
	while frames < MAX_FRAMES and not ended[0]:
		await physics_frame
		frames += 1
	if is_instance_valid(level):
		_close_turn(bucket, level)
		bucket["final"] = _material(level)
	out["frames"] = frames
	out["rounds"] = int(bucket["rounds"])
	out["stalled"] = not ended[0]
	if not ended[0]:
		out["result"] = "draw"
	elif ended[1] == TacticsLevel.RESULT_PLAYER_WIN:
		out["result"] = "player"
	elif ended[1] == TacticsLevel.RESULT_PLAYER_LOSS:
		out["result"] = "enemy"
	else:
		out["result"] = "draw"
	out["sides"] = {
		PokemonInstanceResource.Team.PLAYER: _side_metrics(bucket, PokemonInstanceResource.Team.PLAYER, String(out["result"])),
		PokemonInstanceResource.Team.ENEMY: _side_metrics(bucket, PokemonInstanceResource.Team.ENEMY, String(out["result"])),
	}
	if is_instance_valid(level):
		level.queue_free()
	loader.queue_free()
	await process_frame
	await process_frame
	return out


func _new_bucket() -> Dictionary:
	return {
		"round_samples": [],
		"turn_samples": [],
		"rounds": 0,
		"final": 0.0,
		"advantage": {PokemonInstanceResource.Team.PLAYER: -1, PokemonInstanceResource.Team.ENEMY: -1},
		"dealt": {},
		"taken": {},
		"self_damage": {},
		"losses": {},
		"turns": {},
		"skipped": {},
		"wasted": {},
		"attacked": {},
		"idle": {},
		"eff_sum": {},
		"eff_count": {},
		"focus": {PokemonInstanceResource.Team.PLAYER: {}, PokemonInstanceResource.Team.ENEMY: {}},
		"turn": {},
	}


func _on_round_started(level: TacticsLevel, bucket: Dictionary) -> void:
	if not is_instance_valid(level):
		return
	bucket["rounds"] = int(bucket["rounds"]) + 1
	var value: float = _material(level)
	(bucket["round_samples"] as Array).append(value)
	var advantage: Dictionary = bucket["advantage"]
	if int(advantage[PokemonInstanceResource.Team.PLAYER]) < 0 and value >= ADVANTAGE_THRESHOLD:
		advantage[PokemonInstanceResource.Team.PLAYER] = int(bucket["rounds"])
	if int(advantage[PokemonInstanceResource.Team.ENEMY]) < 0 and -value >= ADVANTAGE_THRESHOLD:
		advantage[PokemonInstanceResource.Team.ENEMY] = int(bucket["rounds"])


func _on_battle_event(event: Dictionary, level: TacticsLevel, bucket: Dictionary) -> void:
	if not is_instance_valid(level):
		return
	var kind: String = String(event.get("kind", ""))
	var turn: Dictionary = bucket["turn"]
	match kind:
		"turn_started":
			var actor: TacticsPawn = event.get("unit", null) as TacticsPawn
			if actor != null and is_instance_valid(actor):
				_open_turn(bucket, level, actor)
				(bucket["turn_samples"] as Array).append(_material(level))
		"turn_skipped":
			if not turn.is_empty():
				turn["skipped"] = true
		"damage_dealt":
			var defender: TacticsPawn = event.get("defender", null) as TacticsPawn
			var amount: int = int(event.get("amount", 0))
			if defender == null or not is_instance_valid(defender) or amount <= 0:
				return
			var defender_team: int = level.pawn_team(defender)
			_bump(bucket["taken"], defender_team, amount)
			var attacker: TacticsPawn = event.get("attacker", null) as TacticsPawn
			if attacker == null or not is_instance_valid(attacker):
				return
			var attacker_team: int = level.pawn_team(attacker)
			if attacker_team == defender_team:
				_bump(bucket["self_damage"], attacker_team, amount)
				return
			_bump(bucket["dealt"], attacker_team, amount)
			var focus: Dictionary = (bucket["focus"] as Dictionary)[attacker_team]
			var target_id: int = defender.get_instance_id()
			focus[target_id] = int(focus.get(target_id, 0)) + amount
			if event.has("multiplier"):
				bucket["eff_sum"][attacker_team] = float(bucket["eff_sum"].get(attacker_team, 0.0)) + float(event["multiplier"])
				_bump(bucket["eff_count"], attacker_team, 1)
			if not turn.is_empty() and turn["pawn"] == attacker:
				turn["damage"] = int(turn["damage"]) + amount
		"unit_fainted":
			var fallen: TacticsPawn = event.get("unit", null) as TacticsPawn
			if fallen != null and is_instance_valid(fallen):
				_bump(bucket["losses"], level.pawn_team(fallen), 1)
		"move_used":
			if not turn.is_empty() and turn["pawn"] == event.get("attacker", null):
				turn["acted"] = true
		"item_action_selected", "item_thrown":
			if not turn.is_empty() and turn["pawn"] == event.get("attacker", null):
				turn["item"] = true
		"item_used":
			if not turn.is_empty() and turn["pawn"] == event.get("target", null):
				turn["item"] = true
		"status_applied", "stat_stage_changed", "healed", "field_condition_applied", "hazard_placed", "weather_started":
			if not turn.is_empty() and not String(event.get("move_id", "")).is_empty():
				turn["effect"] = true


func _open_turn(bucket: Dictionary, level: TacticsLevel, actor: TacticsPawn) -> void:
	_close_turn(bucket, level)
	var team: int = level.pawn_team(actor)
	var start: Vector3i = _grid_key(actor)
	var foe: Vector3i = start
	var foe_distance: int = -1
	for other in level.units_on_map():
		if level.pawn_team(other) == team:
			continue
		var key: Vector3i = _grid_key(other)
		var distance: int = _grid_distance(start, key)
		if foe_distance < 0 or distance < foe_distance:
			foe_distance = distance
			foe = key
	bucket["turn"] = {
		"pawn": actor,
		"team": team,
		"start": start,
		"foe": foe,
		"foe_distance": foe_distance,
		"damage": 0,
		"item": false,
		"effect": false,
		"acted": false,
		"skipped": false,
	}


func _close_turn(bucket: Dictionary, _level: TacticsLevel) -> void:
	var turn: Dictionary = bucket["turn"]
	if turn.is_empty():
		return
	bucket["turn"] = {}
	var team: int = int(turn["team"])
	_bump(bucket["turns"], team, 1)
	if bool(turn["skipped"]):
		_bump(bucket["skipped"], team, 1)
		return
	var start: Vector3i = turn["start"]
	var finish: Vector3i = start
	var actor: TacticsPawn = turn["pawn"]
	if is_instance_valid(actor) and actor.is_inside_tree():
		finish = _grid_key(actor)
	var approach: int = 0
	if int(turn["foe_distance"]) >= 0:
		approach = int(turn["foe_distance"]) - _grid_distance(finish, turn["foe"])
	var damage: int = int(turn["damage"])
	if damage > 0:
		_bump(bucket["attacked"], team, 1)
	if damage <= 0 and not bool(turn["item"]) and not bool(turn["effect"]) and approach < 1:
		_bump(bucket["wasted"], team, 1)
	if not bool(turn["acted"]) and not bool(turn["item"]) and finish == start:
		_bump(bucket["idle"], team, 1)


func _material(level: TacticsLevel) -> float:
	var player_total: float = 0.0
	var enemy_total: float = 0.0
	for pawn in level.units_on_map():
		if pawn.stats == null or pawn.stats.max_health <= 0:
			continue
		var fraction: float = clampf(float(pawn.stats.curr_health) / float(pawn.stats.max_health), 0.0, 1.0)
		if level.pawn_team(pawn) == PokemonInstanceResource.Team.PLAYER:
			player_total += fraction
		else:
			enemy_total += fraction
	return player_total - enemy_total


func _grid_key(pawn: TacticsPawn) -> Vector3i:
	var pos: Vector3 = pawn.global_position if pawn.is_inside_tree() else pawn.position
	return Vector3i(floori(pos.x + 0.5), 0, floori(pos.z + 0.5))


func _grid_distance(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), absi(a.z - b.z))


func _bump(table: Dictionary, key: int, amount: int) -> void:
	table[key] = int(table.get(key, 0)) + amount


func _count(table: Dictionary, key: int) -> int:
	return int(table.get(key, 0))


func _side_metrics(bucket: Dictionary, team: int, result: String) -> Dictionary:
	var other: int = PokemonInstanceResource.Team.ENEMY if team == PokemonInstanceResource.Team.PLAYER else PokemonInstanceResource.Team.PLAYER
	var orientation: float = 1.0 if team == PokemonInstanceResource.Team.PLAYER else -1.0
	var out: Dictionary = {}
	if result == "player":
		out["win"] = 1.0 if team == PokemonInstanceResource.Team.PLAYER else 0.0
	elif result == "enemy":
		out["win"] = 0.0 if team == PokemonInstanceResource.Team.PLAYER else 1.0
	else:
		out["win"] = 0.5
	var round_samples: Array = bucket["round_samples"]
	if not round_samples.is_empty():
		var round_total: float = 0.0
		var lead: float = 0.0
		for value in round_samples:
			var signed: float = orientation * float(value)
			round_total += signed
			lead += 1.0 if signed > 0.0 else 0.0
		out["mdi_round"] = round_total / float(round_samples.size())
		out["lead_share"] = lead / float(round_samples.size())
	var turn_samples: Array = bucket["turn_samples"]
	if not turn_samples.is_empty():
		var turn_total: float = 0.0
		for value in turn_samples:
			turn_total += orientation * float(value)
		out["mdi_turn"] = turn_total / float(turn_samples.size())
	out["final_margin"] = orientation * float(bucket["final"])
	var dealt: float = float(_count(bucket["dealt"], team))
	var received: float = float(_count(bucket["dealt"], other))
	if dealt + received > 0.0:
		out["damage_share"] = dealt / (dealt + received)
	out["damage_ratio_log"] = log((dealt + 1.0) / (received + 1.0))
	var kos: float = float(_count(bucket["losses"], other))
	var lost: float = float(_count(bucket["losses"], team))
	out["ko_diff"] = kos - lost
	out["ko_share"] = (kos + 0.5) / (kos + lost + 1.0)
	var advantage: int = int((bucket["advantage"] as Dictionary)[team])
	out["advantage_round"] = float(mini(ADVANTAGE_CAP, advantage if advantage > 0 else int(bucket["rounds"]) + 1))
	var turns: int = _count(bucket["turns"], team) - _count(bucket["skipped"], team)
	if turns > 0:
		out["attack_rate"] = float(_count(bucket["attacked"], team)) / float(turns)
		out["waste_rate"] = float(_count(bucket["wasted"], team)) / float(turns)
		out["idle_rate"] = float(_count(bucket["idle"], team)) / float(turns)
		out["damage_per_turn"] = dealt / float(turns)
	if _count(bucket["eff_count"], team) > 0:
		out["effectiveness"] = float(bucket["eff_sum"].get(team, 0.0)) / float(_count(bucket["eff_count"], team))
	var focus: Dictionary = (bucket["focus"] as Dictionary)[team]
	if dealt > 0.0 and not focus.is_empty():
		var concentration: float = 0.0
		for key in focus.keys():
			concentration += pow(float(focus[key]) / dealt, 2.0)
		out["focus"] = concentration
	return out


func _values(level: int, metric: String) -> Array[float]:
	var out: Array[float] = []
	for record in (samples[level] as Array):
		if (record as Dictionary).has(metric):
			out.append(float((record as Dictionary)[metric]))
	return out


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _std_error(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var mean: float = _mean(values)
	var acc: float = 0.0
	for value in values:
		acc += pow(value - mean, 2.0)
	return sqrt(acc / float(values.size() - 1) / float(values.size()))


func _aggregate(levels: Array[int]) -> Dictionary:
	var out: Dictionary = {}
	for level in levels:
		var row: Dictionary = {}
		for metric in METRIC_ORDER:
			var values: Array[float] = _values(level, metric)
			row[metric] = {"n": values.size(), "mean": _mean(values), "se": _std_error(values)}
		row["battles"] = (samples[level] as Array).size()
		out[level] = row
	return out


func _paired(low: int, high: int, metric: String) -> Dictionary:
	var by_key: Dictionary = {}
	for record in (samples[low] as Array):
		var entry: Dictionary = record
		if entry.has(metric):
			by_key[String(entry["key"])] = float(entry[metric])
	var diffs: Array[float] = []
	for record in (samples[high] as Array):
		var entry: Dictionary = record
		if not entry.has(metric):
			continue
		var key: String = String(entry["key"])
		if by_key.has(key):
			diffs.append(float(entry[metric]) - float(by_key[key]))
	return {"n": diffs.size(), "mean": _mean(diffs), "se": _std_error(diffs)}


func _analysis(levels: Array[int], aggregates: Dictionary, paired: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if levels.size() < 2:
		return out
	var low: int = levels[0]
	var high: int = levels[levels.size() - 1]
	var win_z: float = 0.0
	for metric in METRIC_ORDER:
		var direction: float = -1.0 if LOWER_IS_BETTER.has(metric) else 1.0
		var low_row: Dictionary = (aggregates[low] as Dictionary)[metric]
		var high_row: Dictionary = (aggregates[high] as Dictionary)[metric]
		if int(low_row["n"]) < 2 or int(high_row["n"]) < 2:
			continue
		var span: float = direction * (float(high_row["mean"]) - float(low_row["mean"]))
		var span_se: float = sqrt(pow(float(low_row["se"]), 2.0) + pow(float(high_row["se"]), 2.0))
		var span_z: float = span / span_se if span_se > 0.0 else 0.0
		var pair: Dictionary = _paired(low, high, metric) if paired else {"n": 0, "mean": 0.0, "se": 0.0}
		var paired_z: float = 0.0
		if int(pair["n"]) > 1 and float(pair["se"]) > 0.0:
			paired_z = direction * float(pair["mean"]) / float(pair["se"])
		var ordered: int = 0
		var steps: int = 0
		for i in range(levels.size() - 1):
			var a: Dictionary = (aggregates[levels[i]] as Dictionary)[metric]
			var b: Dictionary = (aggregates[levels[i + 1]] as Dictionary)[metric]
			if int(a["n"]) < 1 or int(b["n"]) < 1:
				continue
			steps += 1
			if direction * (float(b["mean"]) - float(a["mean"])) >= 0.0:
				ordered += 1
		var best_z: float = maxf(absf(span_z), absf(paired_z)) if paired else absf(span_z)
		if metric == "win":
			win_z = best_z
		out.append({
			"metric": metric,
			"span": span,
			"span_se": span_se,
			"span_z": span_z,
			"paired_n": int(pair["n"]),
			"paired_mean": float(pair["mean"]),
			"paired_se": float(pair["se"]),
			"paired_z": paired_z,
			"ordered": ordered,
			"steps": steps,
			"score": best_z,
		})
	for row in out:
		row["games_equivalent"] = pow(float(row["score"]) / win_z, 2.0) if win_z > 0.01 else -1.0
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]))
	return out


func _ratings(levels: Array[int]) -> Dictionary:
	var strength: Dictionary = {}
	var score: Dictionary = {}
	var played: Dictionary = {}
	var counts: Dictionary = {}
	for level in levels:
		strength[level] = 1.0
		score[level] = 0.0
		played[level] = 0.0
		counts[level] = {}
	for game in games:
		var a: int = int(game["a"])
		var b: int = int(game["b"])
		if a == b or not strength.has(a) or not strength.has(b):
			continue
		var value: float = float(game["score_a"])
		score[a] = float(score[a]) + value
		score[b] = float(score[b]) + 1.0 - value
		played[a] = float(played[a]) + 1.0
		played[b] = float(played[b]) + 1.0
		(counts[a] as Dictionary)[b] = int((counts[a] as Dictionary).get(b, 0)) + 1
		(counts[b] as Dictionary)[a] = int((counts[b] as Dictionary).get(a, 0)) + 1
	var prior_score: Dictionary = {}
	var prior_counts: Dictionary = {}
	for level in levels:
		prior_score[level] = float(score[level])
		prior_counts[level] = (counts[level] as Dictionary).duplicate()
	for level in levels:
		for foe in (counts[level] as Dictionary).keys():
			prior_score[level] = float(prior_score[level]) + 0.5
			(prior_counts[level] as Dictionary)[foe] = int((prior_counts[level] as Dictionary)[foe]) + 1
	for _iteration in range(ELO_ITERATIONS):
		var updated: Dictionary = {}
		for level in levels:
			var denominator: float = 0.0
			for foe in (prior_counts[level] as Dictionary).keys():
				denominator += float((prior_counts[level] as Dictionary)[foe]) / (float(strength[level]) + float(strength[foe]))
			updated[level] = float(prior_score[level]) / denominator if denominator > 0.0 else float(strength[level])
		var log_total: float = 0.0
		for level in levels:
			log_total += log(maxf(0.000001, float(updated[level])))
		var norm: float = exp(log_total / float(levels.size()))
		for level in levels:
			strength[level] = maxf(0.000001, float(updated[level]) / norm)
	var out: Dictionary = {}
	for level in levels:
		var rating: float = 1500.0 + 400.0 * log(float(strength[level])) / log(10.0)
		var n: float = maxf(1.0, float(played[level]))
		var rate: float = clampf(float(score[level]) / n, 0.001, 0.999)
		var rate_se: float = sqrt(rate * (1.0 - rate) / n)
		var elo_se: float = 400.0 / log(10.0) * rate_se / maxf(0.01, rate * (1.0 - rate))
		out[level] = {"elo": rating, "elo_se": elo_se, "games": int(played[level]), "score": float(score[level])}
	return out


func _ratio_text(value: float) -> String:
	return "n/a" if value < 0.0 else "%.1fx" % value


func _print_report(levels: Array[int], aggregates: Dictionary, ratings: Dictionary, analysis: Array[Dictionary], paired: bool, mode: String, anchor: int, elapsed: float) -> void:
	var stalled: int = 0
	for battle in battles:
		if bool(battle.get("stalled", false)):
			stalled += 1
	print("bench: mode=%s anchor=L%d battles=%d stalled=%d failures=%d seconds=%.1f" % [mode, anchor, battles.size(), stalled, failures, elapsed])
	var header: String = "bench: %-18s" % "metric"
	for level in levels:
		header += "%18s" % ("L%d" % level)
	print(header + "   ordered      span_z    paired_z   vs_win_rate")
	for metric in METRIC_ORDER:
		var line: String = "bench: %-18s" % metric
		var present: bool = false
		for level in levels:
			var row: Dictionary = (aggregates[level] as Dictionary)[metric]
			if int(row["n"]) < 1:
				line += "%18s" % "-"
				continue
			present = true
			line += "%18s" % ("%+.3f+-%.3f" % [float(row["mean"]), float(row["se"])])
		if not present:
			continue
		var found: Dictionary = {}
		for row in analysis:
			if String(row["metric"]) == metric:
				found = row
				break
		if found.is_empty():
			print(line)
			continue
		line += "     %d/%d %11.2f %11.2f %13s" % [int(found["ordered"]), int(found["steps"]), float(found["span_z"]), float(found["paired_z"]), _ratio_text(float(found["games_equivalent"]))]
		print(line)
	var elo_line: String = "bench: %-18s" % "elo"
	for level in levels:
		var row: Dictionary = ratings[level]
		elo_line += "%18s" % ("%.0f+-%.0f" % [float(row["elo"]), float(row["elo_se"])])
	print(elo_line)
	var battle_line: String = "bench: %-18s" % "battles"
	for level in levels:
		battle_line += "%18d" % int((aggregates[level] as Dictionary)["battles"])
	print(battle_line)
	print("bench: span is L%d to L%d, paired_z uses the same seed and side for both levels%s" % [levels[0], levels[levels.size() - 1], "" if paired else " (unavailable in roundrobin mode)"])
	var rank: int = 0
	for row in analysis:
		rank += 1
		print("bench: rank %d %-18s z=%.2f ordered=%d/%d games_equivalent=%s" % [rank, String(row["metric"]), float(row["score"]), int(row["ordered"]), int(row["steps"]), _ratio_text(float(row["games_equivalent"]))])
	if analysis.is_empty():
		print("bench: no metric had enough samples to rank")
		return
	var best: Dictionary = analysis[0]
	var win_z: float = 0.0
	for row in analysis:
		if String(row["metric"]) == "win":
			win_z = float(row["score"])
			break
	print("bench: done battles=%d best=%s z=%.2f (win_rate z=%.2f, %s the information per battle) seconds=%.1f" % [
		battles.size(),
		String(best["metric"]),
		float(best["score"]),
		win_z,
		_ratio_text(float(best["games_equivalent"])),
		elapsed,
	])


func _json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key in (value as Dictionary).keys():
			out[str(key)] = _json_safe((value as Dictionary)[key])
		return out
	if value is Array:
		var list: Array = []
		for item in (value as Array):
			list.append(_json_safe(item))
		return list
	return value
