extends SceneTree

const DRIVER: GDScript = preload("res://tools/debug/notation_driver.gd")
const OUTPUT_DIR: String = "res://logs/debug/validation"
const MAX_FRAMES: int = 36000
const MAX_TURNS: int = 320
const TRAVELLERS: Array[String] = [
	"0483_dialga@100:roar_of_time,dragon_claw,flash_cannon,earth_power:pressure",
	"0484_palkia@100:spacial_rend,aqua_tail,dragon_claw,earth_power:pressure",
	"0487_giratina@100:shadow_force,dragon_claw,shadow_sneak,will_o_wisp:pressure",
	"0720_hoopa@100:hyperspace_hole,hyperspace_fury,psychic,shadow_ball:magician",
	"0251_celebi@100:dimensional_hole,psychic,giga_drain,recover:natural_cure",
	"0253_grovyle@100:dimensional_hole,leaf_blade,quick_attack,pursuit:overgrow",
	"0477_dusknoir@100:dimensional_hole,shadow_punch,ice_punch,will_o_wisp:pressure",
	"0474_porygon_z@100:dimensional_glitch,tri_attack,thunderbolt,ice_beam:adaptability",
	"0493_arceus@100:judgment,recover,extreme_speed,earth_power:multitype",
]
const FILLERS: Array[String] = [
	"0025_pikachu@100:thunderbolt,quick_attack,iron_tail,thunder_wave:static",
	"0006_charizard@100:flamethrower,air_slash,dragon_claw,roost:blaze",
	"0009_blastoise@100:hydro_pump,ice_beam,rapid_spin,protect:torrent",
	"0003_venusaur@100:giga_drain,sludge_bomb,leech_seed,synthesis:overgrow",
]

var driver: RefCounted = null
var level: TacticsLevel = null
var level_text: String = "@50"
var summary: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed_range: PackedStringArray = _arg("seeds", "1-60").split("-")
	var first: int = int(seed_range[0])
	var last: int = int(seed_range[seed_range.size() - 1])
	var travel_chance: float = float(_arg("travel", "0.7"))
	var replay_every: int = int(_arg("replay", "10"))
	var team_min: int = int(_arg("team_min", "3"))
	var team_max: int = int(_arg("team_max", "4"))
	level_text = "@%d" % int(_arg("level", "50"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/multiverse" % OUTPUT_DIR))
	driver = DRIVER.new(self)
	for seed in range(first, last + 1):
		var result: Dictionary = await _trial(seed, travel_chance, replay_every > 0 and seed % replay_every == 0, team_min, team_max)
		summary.append(result)
		print("trial: seed=%d result=%s turns=%d rounds=%d timelines=%d travels=%d hops=%d switches=%d frozen=%d frames=%d invariants=%s replay=%s" % [seed, String(result.get("result", "")), int(result.get("turns", 0)), int(result.get("max_turn", 0)), int(result.get("timelines", 0)), int(result.get("travels", 0)), int(result.get("hops", 0)), int(result.get("switches", 0)), int(result.get("frozen", 0)), int(result.get("frames", 0)), str(result.get("invariant_failures", [])), String(result.get("replay", "skipped"))])
	var aggregate: Dictionary = _aggregate()
	var file := FileAccess.open("%s/multiverse_trials_%d_%d.json" % [OUTPUT_DIR, first, last], FileAccess.WRITE)
	file.store_string(JSON.stringify({"generated": Time.get_datetime_string_from_system(), "travel_chance": travel_chance, "aggregate": aggregate, "trials": summary}, "\t"))
	file.close()
	print("trial: done %d trials -> %s" % [summary.size(), JSON.stringify(aggregate)])
	quit(0)


func _roster(rng: RandomNumberGenerator, size: int) -> Array[String]:
	var pool: Array[String] = []
	pool.append_array(TRAVELLERS)
	pool.append_array(FILLERS)
	var picks: Array[String] = []
	picks.append(TRAVELLERS[rng.randi_range(0, TRAVELLERS.size() - 1)])
	var guard: int = 0
	while picks.size() < size and guard < 100:
		guard += 1
		var candidate: String = pool[rng.randi_range(0, pool.size() - 1)]
		if not picks.has(candidate):
			picks.append(candidate)
	var out: Array[String] = []
	for pick in picks:
		out.append(pick.replace("@100", level_text))
	return out


func _trial(seed: int, travel_chance: float, replay: bool, team_min: int, team_max: int) -> Dictionary:
	var out: Dictionary = {"seed": seed, "invariant_failures": [], "travels": 0, "hops": 0, "switches": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("multiverse:%d" % seed)
	var player: Array[String] = _roster(rng, rng.randi_range(team_min, team_max))
	var enemy: Array[String] = _roster(rng, rng.randi_range(team_min, team_max))
	var code: String = "match seed=%d mode=bots map=chessboard multiverse=1 p=%s e=%s" % [seed, "|".join(player), "|".join(enemy)]
	var forced: String = _arg("code", "")
	if not forced.is_empty():
		var parts: PackedStringArray = forced.split(" ", false)
		for i in range(parts.size()):
			if parts[i].begins_with("seed="):
				parts[i] = "seed=%d" % seed
			elif parts[i].begins_with("mode="):
				parts[i] = "mode=bots"
		code = " ".join(parts)
	out["code"] = code
	print("trial: start seed=%d %s" % [seed, code])
	var ok: bool = await driver._launch(code)
	if not ok:
		out["result"] = "launch_failed"
		return out
	level = driver.level
	level.presentation_runner.immediate_mode = _arg("immediate", "1") == "1"
	Engine.time_scale = maxf(0.1, float(_arg("speed", "1")))
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var policy_rng := RandomNumberGenerator.new()
	policy_rng.seed = hash("policy:%d" % seed)
	level.multiverse.cpu_policy = func(options: Array, _pending: Dictionary) -> int:
		if options.is_empty() or policy_rng.randf() >= travel_chance:
			return -1
		return policy_rng.randi_range(0, options.size() - 1)
	var frames: int = 0
	var ended: Array = [false, -1]
	var latest: Array = [{}]
	var seen_failures: Dictionary = {}
	var gather: Callable = func() -> void:
		if is_instance_valid(level) and level.multiverse != null:
			latest[0] = _gather(level)
			for failure in (latest[0] as Dictionary).get("invariant_failures", []):
				seen_failures[String(failure)] = true
	level.battle_ended.connect(func(result: int) -> void:
		ended[0] = true
		ended[1] = result
		gather.call())
	var last_switches: int = 0
	while frames < MAX_FRAMES and not ended[0] and is_instance_valid(level):
		await physics_frame
		frames += 1
		if frames % 30 == 0:
			gather.call()
			if int((latest[0] as Dictionary).get("turns", 0)) >= MAX_TURNS:
				break
			if int((latest[0] as Dictionary).get("switches", 0)) != last_switches:
				last_switches = int((latest[0] as Dictionary).get("switches", 0))
	if is_instance_valid(level):
		gather.call()
	out["frames"] = frames
	for key in (latest[0] as Dictionary):
		out[key] = latest[0][key]
	var merged: Array = []
	for failure in seen_failures.keys():
		merged.append(String(failure))
	merged.sort()
	out["invariant_failures"] = merged
	if not ended[0] and frames >= MAX_FRAMES:
		print("trial: STALL seed=%d %s" % [seed, JSON.stringify(out.get("stall", {}))])
	out["result"] = ("player" if ended[1] == TacticsLevel.RESULT_PLAYER_WIN else ("enemy" if ended[1] == TacticsLevel.RESULT_PLAYER_LOSS else "result_%d" % ended[1])) if ended[0] else ("turn_cap" if int(out.get("turns", 0)) >= MAX_TURNS else "frame_cap")
	var transcript: String = String(out.get("transcript_text", ""))
	out.erase("transcript_text")
	var keep_path: String = "%s/multiverse/trial_%d.log" % [OUTPUT_DIR, seed]
	var keep_file := FileAccess.open(keep_path, FileAccess.WRITE)
	if keep_file != null:
		keep_file.store_string(transcript)
		keep_file.close()
		out["transcript"] = keep_path
	if replay and ended[0] and int(out.get("travels", 0)) > 0:
		out["replay"] = await _replay(transcript)
	elif replay:
		out["replay"] = "skipped_no_travel" if ended[0] else "skipped_unfinished"
	return out


func _gather(battle_level: TacticsLevel) -> Dictionary:
	var out: Dictionary = {"invariant_failures": []}
	_check_state(battle_level, out)
	_check_units(battle_level, out)
	var mv: MultiverseController = battle_level.multiverse
	out["travels"] = mv.travels
	out["switches"] = mv.switches
	out["timelines"] = mv.state.timeline_ids().size()
	out["max_turn"] = mv.state.max_turn()
	out["present"] = mv.state.present()
	var frozen: int = 0
	for l in mv.state.timeline_ids():
		if not mv.state.is_active(l):
			frozen += 1
	out["frozen"] = frozen
	var kinds: Dictionary = {}
	var moves: Dictionary = {}
	var hops: int = 0
	var travel_events: int = 0
	for event in battle_level.battle_log.events:
		var kind: String = String(event.get("kind", ""))
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		if kind == "move_used":
			var move_id: String = String(event.get("move_id", ""))
			moves[move_id] = int(moves.get(move_id, 0)) + 1
		if kind == "travel":
			travel_events += 1
			if String(event.get("kind_of", "")) == "hop":
				hops += 1
	out["turns"] = int(kinds.get("turn_started", 0))
	out["hops"] = hops
	out["moves"] = moves
	out["travel_kinds"] = {"branch": travel_events - hops, "hop": hops, "pending": int(kinds.get("travel_pending", 0)), "cancelled": int(kinds.get("travel_cancelled", 0))}
	if travel_events != mv.travels:
		(out["invariant_failures"] as Array).append("travel events %d vs travels %d" % [travel_events, mv.travels])
	var transcript: String = battle_level.notation.text()
	var travel_lines: int = 0
	var branch_lines: int = 0
	for raw in transcript.split("\n"):
		var line: String = String(raw).strip_edges()
		if line.begins_with("travel ") or line.begins_with("hop "):
			travel_lines += 1
		if line.begins_with("branch "):
			branch_lines += 1
	if transcript.find("[Multiverse \"1\"]") < 0:
		(out["invariant_failures"] as Array).append("transcript lacks the multiverse header")
	if travel_lines != mv.travels:
		(out["invariant_failures"] as Array).append("transcript travel lines %d vs travels %d" % [travel_lines, mv.travels])
	if branch_lines != mv.state.timeline_ids().size() - 1:
		(out["invariant_failures"] as Array).append("transcript branch lines %d vs timelines %d" % [branch_lines, mv.state.timeline_ids().size()])
	out["transcript_text"] = transcript
	var active: BattleUnit = battle_level.scheduler.get_active_unit()
	var participant: TacticsParticipantResource = battle_level.participant.res
	out["stall"] = {
		"active": battle_level.notation.unit_ref(active.pawn) if active != null and active.pawn != null else "none",
		"stage": participant.stage,
		"presentation_busy": battle_level.is_presentation_busy(),
		"pending_travel": not mv.pending_travel.is_empty(),
		"focus": str(mv.state.focus),
		"owed": str(mv.state.owed_boards()),
		"tail": battle_level.notation.lines.slice(maxi(0, battle_level.notation.lines.size() - 10)),
	}
	return out


func _replay(transcript: String) -> String:
	var lines: Array = []
	for line in transcript.split("\n"):
		lines.append(String(line).replace("mode=bots", "mode=pvp"))
	var original: Array = _body(transcript)
	var result: Dictionary = await driver.run_script(lines)
	if int(result.get("failures", 0)) > 0:
		return "failed: %s" % str(result.get("log", [])).substr(0, 300)
	var replayed: Array = _body(String(result.get("notation", "")))
	if replayed.size() < original.size():
		return "diverged_size %d vs %d" % [replayed.size(), original.size()]
	for i in range(original.size()):
		if replayed[i] != original[i]:
			return "diverged_line %d: %s | %s" % [i, original[i], replayed[i]]
	return "ok"


func _body(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		var trimmed: String = String(line).strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("["):
			continue
		out.append(trimmed.replace("ctl=cpu", "ctl=player"))
	return out


func _check_state(battle_level: TacticsLevel, out: Dictionary) -> void:
	var failures: Array = out["invariant_failures"]
	var state: MultiverseState = battle_level.multiverse.state
	if state.timelines.is_empty():
		return
	var band: int = state.active_band()
	for l in state.timeline_ids():
		var boards: Array = state.boards(l)
		var first: int = state.first_turn(l)
		for i in range(boards.size()):
			var board: BoardSnapshot = boards[i]
			if board.timeline != l or board.turn != first + i:
				failures.append("board order L%d index %d is L%d T%d" % [l, i, board.timeline, board.turn])
			var seen: Dictionary = {}
			for unit in board.units:
				var id: String = String(unit["id"])
				if seen.has(id):
					failures.append("duplicate unit %s on L%d T%d" % [id, l, board.turn])
				seen[id] = true
		if state.is_active(l) != (absi(l) <= band):
			failures.append("active band mismatch for L%d (band %d)" % [l, band])
	var now: int = state.present()
	for coords in state.owed_boards():
		if coords.y != now:
			failures.append("owed board %s is not at the present T%d" % [str(coords), now])
		var latest: BoardSnapshot = state.latest(coords.x)
		if latest == null or latest.coords() != coords:
			failures.append("owed board %s is not the latest of its timeline" % str(coords))
	var focus_latest: BoardSnapshot = state.latest(state.focus.x)
	if focus_latest == null or focus_latest.coords() != state.focus:
		failures.append("focus %s is not a latest board" % str(state.focus))
	for l in state.timeline_ids():
		if state.is_active(l) and state.latest(l).turn < now:
			failures.append("active timeline L%d sits behind the present (T%d < T%d)" % [l, state.latest(l).turn, now])


func _check_units(battle_level: TacticsLevel, out: Dictionary) -> void:
	var failures: Array = out["invariant_failures"]
	for pawn in battle_level.units_on_map():
		if pawn.stats == null:
			continue
		if pawn.stats.curr_health < 0 or pawn.stats.curr_health > pawn.stats.max_health:
			failures.append("hp out of range %s %d/%d" % [pawn.name, pawn.stats.curr_health, pawn.stats.max_health])
		for pp in pawn.stats.current_pp:
			if int(pp) < 0:
				failures.append("negative pp %s" % pawn.name)
		for stat in pawn.stats.stat_stages.keys():
			var stage: int = int(pawn.stats.stat_stages[stat])
			if stage < -6 or stage > 6:
				failures.append("stage out of range %s %s %d" % [pawn.name, String(stat), stage])
		if pawn.stats.curr_health == 0 and pawn.stats.is_active():
			failures.append("zero hp but active %s" % pawn.name)
	var settled: bool = true
	for pawn in battle_level.units_on_map():
		if pawn.res != null and (pawn.res.is_moving or not pawn.res.pathfinding_tilestack.is_empty()):
			settled = false
			break
	var occupied: Dictionary = {}
	for pawn in (battle_level.units_on_map() if settled else []):
		if pawn.stats == null or not pawn.is_alive():
			continue
		var ray: RayCast3D = pawn.get_node_or_null("Tile") as RayCast3D
		if ray != null:
			ray.force_raycast_update()
		var tile: TacticsTile = pawn.get_tile()
		if tile == null:
			continue
		var key: Vector3i = Targeting._tile_key(tile)
		if occupied.has(key):
			failures.append("two living units share %s: %s and %s" % [battle_level.notation.tile_label(key), String(occupied[key]), battle_level.notation.unit_id(pawn)])
		else:
			occupied[key] = battle_level.notation.unit_id(pawn)
	for l in battle_level.multiverse.state.timeline_ids():
		for board in battle_level.multiverse.state.boards(l):
			var seen: Dictionary = {}
			for entry in board.units:
				if not bool(entry.get("alive", false)):
					continue
				var board_key: Vector3i = entry["tile"]
				if seen.has(board_key):
					failures.append("board L%dT%d records %s and %s on the same tile" % [board.timeline, board.turn, String(seen[board_key]), String(entry["id"])])
				else:
					seen[board_key] = String(entry["id"])


func _aggregate() -> Dictionary:
	var results: Dictionary = {}
	var travels: int = 0
	var hops: int = 0
	var timelines: int = 0
	var frozen: int = 0
	var invariant_failures: int = 0
	var replays: Dictionary = {}
	var moves: Dictionary = {}
	var max_timelines: int = 0
	for trial in summary:
		var key: String = String(trial.get("result", ""))
		results[key] = int(results.get(key, 0)) + 1
		travels += int(trial.get("travels", 0))
		hops += int(trial.get("hops", 0))
		timelines += int(trial.get("timelines", 0))
		max_timelines = maxi(max_timelines, int(trial.get("timelines", 0)))
		frozen += int(trial.get("frozen", 0))
		invariant_failures += (trial.get("invariant_failures", []) as Array).size()
		var replay: String = String(trial.get("replay", "skipped"))
		var replay_key: String = replay if replay == "ok" or replay.begins_with("skipped") else "diverged"
		replays[replay_key] = int(replays.get(replay_key, 0)) + 1
		for move_id in trial.get("moves", {}):
			moves[move_id] = int(moves.get(move_id, 0)) + int(trial["moves"][move_id])
	return {"results": results, "travels": travels, "hops": hops, "timelines": timelines, "max_timelines": max_timelines, "frozen": frozen, "invariant_failures": invariant_failures, "replays": replays, "distinct_moves": moves.size()}


func _arg(name: String, fallback: String = "") -> String:
	for text in OS.get_cmdline_user_args():
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return fallback
