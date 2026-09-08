extends SceneTree

const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const OUTPUT_DIR: String = "res://logs/debug/validation"
const MAX_FRAMES: int = 24000
const TOLERANCE_SIGMA: float = 2.0

var results: Array[Dictionary] = []


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
	var team_size: int = int(_arg("team", "3"))
	var levels: Array[int] = []
	for token in _arg("levels", "1,2,3,4,5").split(",", false):
		levels.append(AIProfile.clamp_level(int(token)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var wins: Dictionary = {}
	for level in levels:
		wins[level] = {"played": 0, "won": 0, "drawn": 0}
	for i in range(levels.size()):
		for j in range(levels.size()):
			if i >= j:
				continue
			var a: int = levels[i]
			var b: int = levels[j]
			for seed in range(1, seeds + 1):
				for swap in [false, true]:
					var outcome: Dictionary = await _battle(seed, team_size, b if swap else a, a if swap else b)
					var player_level: int = b if swap else a
					var enemy_level: int = a if swap else b
					var result: String = String(outcome.get("result", "draw"))
					(wins[player_level] as Dictionary)["played"] += 1
					(wins[enemy_level] as Dictionary)["played"] += 1
					if result == "player":
						(wins[player_level] as Dictionary)["won"] += 1
					elif result == "enemy":
						(wins[enemy_level] as Dictionary)["won"] += 1
					else:
						(wins[player_level] as Dictionary)["drawn"] += 1
						(wins[enemy_level] as Dictionary)["drawn"] += 1
					results.append(outcome)
					print("ladder: seed=%d p=L%d e=L%d result=%s rounds=%d" % [seed, player_level, enemy_level, result, int(outcome.get("rounds", 0))])
	var table: Array[Dictionary] = []
	for level in levels:
		var row: Dictionary = wins[level]
		var played: int = int(row["played"])
		var rate: float = float(row["won"]) / float(maxi(1, played))
		var error: float = sqrt(0.25 / float(maxi(1, played)))
		table.append({"level": level, "played": played, "won": int(row["won"]), "drawn": int(row["drawn"]), "win_rate": rate, "std_error": error})
		print("ladder: L%d played=%d won=%d drawn=%d win_rate=%.3f +/-%.3f" % [level, played, int(row["won"]), int(row["drawn"]), rate, error])
	var monotonic: bool = true
	var regressions: Array[String] = []
	for i in range(table.size() - 1):
		var lower: Dictionary = table[i]
		var upper: Dictionary = table[i + 1]
		var margin: float = TOLERANCE_SIGMA * sqrt(pow(float(lower["std_error"]), 2.0) + pow(float(upper["std_error"]), 2.0))
		if float(lower["win_rate"]) > float(upper["win_rate"]) + margin:
			monotonic = false
			regressions.append("L%d beats L%d by %.3f (tolerance %.3f)" % [int(lower["level"]), int(upper["level"]), float(lower["win_rate"]) - float(upper["win_rate"]), margin])
	print("ladder: monotonic=%s%s" % [str(monotonic), "" if regressions.is_empty() else " " + ", ".join(regressions)])
	print("ladder: note a gap smaller than the tolerance is not measurable at this sample size")
	var separated: bool = true
	if table.size() >= 2:
		var lowest: Dictionary = table[0]
		var highest: Dictionary = table[table.size() - 1]
		var span_margin: float = TOLERANCE_SIGMA * sqrt(pow(float(lowest["std_error"]), 2.0) + pow(float(highest["std_error"]), 2.0))
		separated = float(highest["win_rate"]) > float(lowest["win_rate"]) + span_margin
		print("ladder: span L%d %.3f to L%d %.3f, margin %.3f, separated=%s" % [int(lowest["level"]), float(lowest["win_rate"]), int(highest["level"]), float(highest["win_rate"]), span_margin, str(separated)])
	var file := FileAccess.open("%s/ai_ladder.json" % OUTPUT_DIR, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"generated": Time.get_datetime_string_from_system(), "seeds": seeds, "team_size": team_size, "table": table, "monotonic": monotonic, "separated": separated, "regressions": regressions, "battles": results}, "\t"))
		file.close()
	print("ladder: done %d battles" % results.size())
	quit(0 if monotonic and separated else 1)


func _battle(seed: int, team_size: int, player_level: int, enemy_level: int) -> Dictionary:
	var out: Dictionary = {"seed": seed, "player_level": player_level, "enemy_level": enemy_level}
	var built: Dictionary = CustomSkirmishBuilder.build_random(team_size, MAP_PATH, str(seed), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
	if not bool(built.get("ok", false)):
		out["result"] = "build_failed"
		return out
	var definition: SkirmishDefinitionResource = built["definition"]
	if _arg("mirror", "1") == "1":
		_mirror_rosters(definition)
	definition.skirmish_id = "ai_ladder_%d_%d_%d" % [seed, player_level, enemy_level]
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
	var ended: Array = [false, -1]
	level.battle_ended.connect(func(value: int) -> void:
		ended[0] = true
		ended[1] = value)
	var frames: int = 0
	while frames < MAX_FRAMES and not ended[0]:
		await physics_frame
		frames += 1
	out["rounds"] = level.round_index if is_instance_valid(level) else 0
	out["frames"] = frames
	if not ended[0]:
		out["result"] = "draw"
	elif ended[1] == TacticsLevel.RESULT_PLAYER_WIN:
		out["result"] = "player"
	elif ended[1] == TacticsLevel.RESULT_PLAYER_LOSS:
		out["result"] = "enemy"
	else:
		out["result"] = "draw"
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
