extends SceneTree

const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const OUTPUT_DIR: String = "res://logs/debug/validation"
const MAX_FRAMES: int = 24000


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


func _map_path() -> String:
	var name: String = _arg("map", "chessboard")
	return "res://data/models/maps/definitions/%s.tres" % name


func _run() -> void:
	DebugLog.set_debug_enabled(false)
	var seeds: int = int(_arg("seeds", "12"))
	var seed_start: int = int(_arg("seed-start", "1"))
	var team_size: int = int(_arg("team", "4"))
	var level_value: int = AIProfile.clamp_level(int(_arg("level", "5")))
	var mirror: bool = _arg("mirror", "1") == "1"
	var quiescence: bool = _arg("quiescence", "1") == "1"
	var widths: PackedInt32Array = PackedInt32Array()
	for token in _arg("widths", "12,6,4").split(",", false):
		widths.append(int(token))
	var budgets: Array[int] = []
	for token in _arg("budgets", "0,25,50,100,200,400,800,1600,3200").split(",", false):
		budgets.append(int(token))
	var out_name: String = _arg("out", "search_eval")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var rows: Array[Dictionary] = []
	var started: int = Time.get_ticks_msec()
	for budget in budgets:
		var row: Dictionary = await _sweep(budget, seeds, seed_start, team_size, level_value, mirror, quiescence, widths)
		rows.append(row)
		print("eval: budget=%d n=%d win=%.3f +/-%.3f dmg=%.3f +/-%.3f ko=%.3f mdi=%+.3f ms=%.2f peak=%.1f nodes=%.0f plies=%.2f dev=%.2f" % [
			budget,
			int(row["battles"]),
			float(row["win"]),
			float(row["win_err"]),
			float(row["damage_share"]),
			float(row["damage_share_err"]),
			float(row["ko_share"]),
			float(row["mdi_turn"]),
			float(row["ms_per_decision"]),
			float(row["peak_ms"]),
			float(row["nodes_per_decision"]),
			float(row["plies"]),
			float(row["deviation_rate"]),
		])
	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	print("eval: ---")
	print("eval: budget  battles  win     dmg_share  ko_share  mdi_turn  ms/dec  nodes/dec")
	for row in rows:
		print("eval: %6d  %7d  %.3f   %.3f      %.3f     %+.3f    %6.2f  %8.0f" % [
			int(row["budget"]),
			int(row["battles"]),
			float(row["win"]),
			float(row["damage_share"]),
			float(row["ko_share"]),
			float(row["mdi_turn"]),
			float(row["ms_per_decision"]),
			float(row["nodes_per_decision"]),
		])
	print("eval: elapsed %.1fs" % elapsed)
	var file := FileAccess.open("%s/%s.json" % [OUTPUT_DIR, out_name], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"generated": Time.get_datetime_string_from_system(),
			"seeds": seeds,
			"seed_start": seed_start,
			"team_size": team_size,
			"level": level_value,
			"mirror": mirror,
			"quiescence": quiescence,
			"widths": widths,
			"rows": rows,
		}, "\t"))
		file.close()
	quit(0)


func _sweep(
		budget: int,
		seeds: int,
		seed_start: int,
		team_size: int,
		level_value: int,
		mirror: bool,
		quiescence: bool,
		widths: PackedInt32Array
) -> Dictionary:
	var wins: Array[float] = []
	var damage: Array[float] = []
	var kos: Array[float] = []
	var mdi: Array[float] = []
	var rounds: float = 0.0
	var stats_total: Dictionary = {"decisions": 0, "nodes": 0, "usec": 0, "deviations": 0, "fallbacks": 0, "plies": 0.0, "peak": 0.0}
	for seed in range(seed_start, seed_start + seeds):
		for swap in [false, true]:
			var side: int = PokemonInstanceResource.Team.ENEMY if swap else PokemonInstanceResource.Team.PLAYER
			var outcome: Dictionary = await _battle(seed, team_size, level_value, side, budget, quiescence, widths)
			if not bool(outcome.get("ok", false)):
				continue
			var metrics: Dictionary = outcome["metrics"]
			wins.append(float(metrics.get("win", 0.5)))
			damage.append(float(metrics.get("damage_share", 0.5)))
			kos.append(float(metrics.get("ko_share", 0.5)))
			mdi.append(float(metrics.get("mdi_turn", 0.0)))
			rounds += float(outcome.get("rounds", 0))
			var stats: Dictionary = outcome.get("search", {})
			stats_total["decisions"] = int(stats_total["decisions"]) + int(stats.get("decisions", 0))
			stats_total["nodes"] = int(stats_total["nodes"]) + int(stats.get("nodes", 0))
			stats_total["usec"] = int(stats_total["usec"]) + int(stats.get("usec", 0))
			stats_total["deviations"] = int(stats_total["deviations"]) + int(stats.get("deviations", 0))
			stats_total["fallbacks"] = int(stats_total["fallbacks"]) + int(stats.get("fallbacks", 0))
			stats_total["plies"] = float(stats_total["plies"]) + float(outcome.get("plies", 0.0))
			stats_total["peak"] = maxf(float(stats_total["peak"]), float(stats.get("peak_ms", 0.0)))
	var count: int = wins.size()
	var decisions: int = int(stats_total["decisions"])
	return {
		"budget": budget,
		"battles": count,
		"win": _mean(wins),
		"win_err": _stderr(wins),
		"damage_share": _mean(damage),
		"damage_share_err": _stderr(damage),
		"ko_share": _mean(kos),
		"ko_share_err": _stderr(kos),
		"mdi_turn": _mean(mdi),
		"mdi_turn_err": _stderr(mdi),
		"rounds": rounds / float(maxi(1, count)),
		"decisions": decisions,
		"nodes_per_decision": float(stats_total["nodes"]) / float(maxi(1, decisions)),
		"ms_per_decision": float(stats_total["usec"]) / float(maxi(1, decisions)) / 1000.0,
		"peak_ms": float(stats_total["peak"]),
		"plies": float(stats_total["plies"]) / float(maxi(1, count)),
		"deviation_rate": float(stats_total["deviations"]) / float(maxi(1, decisions)),
		"fallbacks": int(stats_total["fallbacks"]),
	}


func _battle(
		seed: int,
		team_size: int,
		level_value: int,
		side: int,
		budget: int,
		quiescence: bool,
		widths: PackedInt32Array
) -> Dictionary:
	var out: Dictionary = {"ok": false, "seed": seed, "side": side, "budget": budget}
	var built: Dictionary = CustomSkirmishBuilder.build_random(team_size, _map_path(), str(seed), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
	if not bool(built.get("ok", false)):
		return out
	var definition: SkirmishDefinitionResource = built["definition"]
	_mirror_rosters(definition)
	definition.skirmish_id = "search_eval_%d_%d_%d" % [seed, side, budget]
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	if level == null:
		loader.queue_free()
		return out
	level.ai_team_levels = {
		PokemonInstanceResource.Team.PLAYER: level_value,
		PokemonInstanceResource.Team.ENEMY: level_value,
	}
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var brain: BattleSearch = null
	if budget > 0 and level.opponent != null and level.opponent.opponent_serv != null:
		brain = BattleSearch.new()
		brain.profile_driven = false
		brain.node_budget = budget
		brain.use_quiescence = quiescence
		if widths.size() >= 3:
			brain.root_width = widths[0]
			brain.inner_width = widths[1]
			brain.deep_width = widths[2]
		brain.search_teams = PackedInt32Array([side])
		level.opponent.opponent_serv.battle_ai = brain
	var bucket: Dictionary = _new_bucket()
	level.battle_log.event_appended.connect(_on_event.bind(level, bucket))
	var ended: Array = [false, -1]
	level.battle_ended.connect(func(value: int) -> void:
		ended[0] = true
		ended[1] = value)
	var plies_total: float = 0.0
	var plies_count: int = 0
	var frames: int = 0
	while frames < MAX_FRAMES and not ended[0]:
		await physics_frame
		frames += 1
		if brain != null and brain.plies_reached > 0:
			plies_total += float(brain.plies_reached)
			plies_count += 1
			brain.plies_reached = 0
	var result: String = "draw"
	if ended[0] and ended[1] == TacticsLevel.RESULT_PLAYER_WIN:
		result = "player"
	elif ended[0] and ended[1] == TacticsLevel.RESULT_PLAYER_LOSS:
		result = "enemy"
	if is_instance_valid(level):
		_close_turn(bucket, level)
	out["ok"] = true
	out["rounds"] = int(bucket["rounds"])
	out["result"] = result
	out["metrics"] = _side_metrics(bucket, side, result)
	out["search"] = brain.search_stats() if brain != null else {}
	out["plies"] = plies_total / float(maxi(1, plies_count))
	if is_instance_valid(level):
		level.queue_free()
	loader.queue_free()
	await process_frame
	await process_frame
	return out


func _mirror_rosters(definition: SkirmishDefinitionResource) -> void:
	var copies: Array[PokemonInstanceResource] = []
	for source in definition.player_team:
		if source == null:
			continue
		var clone: PokemonInstanceResource = source.duplicate(true)
		clone.team = PokemonInstanceResource.Team.ENEMY
		clone.control_type = PokemonInstanceResource.ControlType.AI
		copies.append(clone)
	definition.enemy_team = copies


func _new_bucket() -> Dictionary:
	return {
		"turn_samples": [],
		"rounds": 0,
		"dealt": {},
		"losses": {},
		"turn": {},
	}


func _on_event(event: Dictionary, level: TacticsLevel, bucket: Dictionary) -> void:
	if not is_instance_valid(level):
		return
	var kind: String = String(event.get("kind", ""))
	match kind:
		"turn_started":
			var actor: TacticsPawn = event.get("unit", null) as TacticsPawn
			if actor != null and is_instance_valid(actor):
				_close_turn(bucket, level)
				bucket["turn"] = {"pawn": actor}
				(bucket["turn_samples"] as Array).append(_material(level))
				bucket["rounds"] = level.round_index
		"damage_dealt":
			var defender: TacticsPawn = event.get("defender", null) as TacticsPawn
			var amount: int = int(event.get("amount", 0))
			if defender == null or not is_instance_valid(defender) or amount <= 0:
				return
			var attacker: TacticsPawn = event.get("attacker", null) as TacticsPawn
			if attacker == null or not is_instance_valid(attacker):
				return
			var attacker_team: int = level.pawn_team(attacker)
			if attacker_team == level.pawn_team(defender):
				return
			bucket["dealt"][attacker_team] = int((bucket["dealt"] as Dictionary).get(attacker_team, 0)) + amount
		"unit_fainted":
			var fallen: TacticsPawn = event.get("unit", null) as TacticsPawn
			if fallen != null and is_instance_valid(fallen):
				var team: int = level.pawn_team(fallen)
				bucket["losses"][team] = int((bucket["losses"] as Dictionary).get(team, 0)) + 1


func _close_turn(bucket: Dictionary, _level: TacticsLevel) -> void:
	bucket["turn"] = {}


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
	var turn_samples: Array = bucket["turn_samples"]
	if not turn_samples.is_empty():
		var total: float = 0.0
		for value in turn_samples:
			total += orientation * float(value)
		out["mdi_turn"] = total / float(turn_samples.size())
	var dealt: float = float(int((bucket["dealt"] as Dictionary).get(team, 0)))
	var received: float = float(int((bucket["dealt"] as Dictionary).get(other, 0)))
	if dealt + received > 0.0:
		out["damage_share"] = dealt / (dealt + received)
	var kos: float = float(int((bucket["losses"] as Dictionary).get(other, 0)))
	var lost: float = float(int((bucket["losses"] as Dictionary).get(team, 0)))
	out["ko_share"] = (kos + 0.5) / (kos + lost + 1.0)
	out["ko_diff"] = kos - lost
	return out


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _stderr(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var average: float = _mean(values)
	var total: float = 0.0
	for value in values:
		total += pow(value - average, 2.0)
	return sqrt(total / float(values.size() - 1)) / sqrt(float(values.size()))
