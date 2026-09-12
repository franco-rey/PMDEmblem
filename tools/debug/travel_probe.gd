extends SceneTree

const DRIVER: GDScript = preload("res://tools/debug/notation_driver.gd")
const MAX_FRAMES: int = 36000
const TRAVELLERS: Array[String] = [
	"0483_dialga@50:roar_of_time,dragon_claw,flash_cannon,earth_power:pressure",
	"0484_palkia@50:spacial_rend,aqua_tail,dragon_claw,earth_power:pressure",
	"0487_giratina@50:shadow_force,dragon_claw,shadow_sneak,will_o_wisp:pressure",
	"0720_hoopa@50:hyperspace_hole,hyperspace_fury,psychic,shadow_ball:magician",
	"0251_celebi@50:dimensional_hole,psychic,giga_drain,recover:natural_cure",
	"0477_dusknoir@50:dimensional_hole,shadow_punch,ice_punch,will_o_wisp:pressure",
]
const FILLERS: Array[String] = [
	"0025_pikachu@50:thunderbolt,quick_attack,iron_tail,thunder_wave:static",
	"0006_charizard@50:flamethrower,air_slash,dragon_claw,roost:blaze",
	"0009_blastoise@50:hydro_pump,ice_beam,rapid_spin,protect:torrent",
]

var driver: RefCounted = null
var rows: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var first: int = int(_arg("first", "1"))
	var last: int = int(_arg("last", "20"))
	var ai: int = int(_arg("ai", "3"))
	var travel_side: String = _arg("travel_side", "both")
	driver = DRIVER.new(self)
	for seed in range(first, last + 1):
		await _trial(seed, ai, travel_side)
	_report(ai, travel_side)
	quit(0)


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--%s=" % key):
			return String(a).split("=")[1]
	return fallback


func _roster(rng: RandomNumberGenerator, size: int) -> String:
	var picks: Array[String] = [TRAVELLERS[rng.randi_range(0, TRAVELLERS.size() - 1)]]
	var pool: Array[String] = []
	pool.append_array(TRAVELLERS)
	pool.append_array(FILLERS)
	var guard: int = 0
	while picks.size() < size and guard < 60:
		guard += 1
		var c: String = pool[rng.randi_range(0, pool.size() - 1)]
		if not picks.has(c):
			picks.append(c)
	return "|".join(picks)


func _live_records(level: TacticsLevel) -> Array[Dictionary]:
	var mv: MultiverseController = level.multiverse
	var out: Array[Dictionary] = []
	for team_node in [level.player, level.opponent]:
		var team: int = PokemonInstanceResource.Team.PLAYER if team_node == level.player else PokemonInstanceResource.Team.ENEMY
		for child in team_node.get_children():
			if child is TacticsPawn:
				out.append(MultiversePolicy.pawn_record(child, team))
	for l in mv.state.active_timelines():
		if l != mv.state.focus.x:
			out.append_array(MultiversePolicy.board_records(mv.state.latest(l)))
	return out


func _sample(level: TacticsLevel) -> Dictionary:
	var mv: MultiverseController = level.multiverse
	var records: Array[Dictionary] = _live_records(level)
	return {
		"units": mv.state.standing_total(PokemonInstanceResource.Team.PLAYER) - mv.state.standing_total(PokemonInstanceResource.Team.ENEMY),
		"strength": MultiversePolicy.margin(records, MultiverseState.SIDE_PLAYER),
	}


func _trial(seed: int, ai: int, travel_side: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("probe:%d" % seed)
	var code: String = "match seed=%d mode=bots map=chessboard multiverse=1 ai=%d p=%s e=%s" % [seed, ai, _roster(rng, 4), _roster(rng, 4)]
	if not await driver._launch(code):
		print("probe: seed=%d launch failed" % seed)
		return
	var level: TacticsLevel = driver.level
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	level.opponent.opponent_serv._sync_ai_level(level)
	var mv: MultiverseController = level.multiverse
	var real: Callable = mv.cpu_policy
	var counts: Array = [0, 0]
	mv.cpu_policy = func(options: Array, pending: Dictionary) -> int:
		counts[0] += 1
		var side: int = int(pending.get("side", MultiverseState.SIDE_PLAYER))
		var allowed: bool = travel_side == "both" \
			or (travel_side == "player" and side == MultiverseState.SIDE_PLAYER) \
			or (travel_side == "enemy" and side == MultiverseState.SIDE_ENEMY)
		if not allowed:
			return -1
		var choice: int = int(real.call(options, pending)) if real.is_valid() else -1
		if choice >= 0:
			counts[1] += 1
		return choice
	var frames: int = 0
	var round_seen: int = -1
	var active_seen: Object = null
	var integral_units: float = 0.0
	var integral_strength: float = 0.0
	var samples: int = 0
	var done: Array = [false, {}]
	level.battle_ended.connect(func(_r: int) -> void:
		var frozen: int = 0
		for l in mv.state.timeline_ids():
			if not mv.state.is_active(l):
				frozen += 1
		done[0] = true
		done[1] = {"travels": mv.travels, "timelines": mv.state.timeline_ids().size(), "frozen": frozen})
	while frames < MAX_FRAMES and not done[0] and is_instance_valid(level):
		await physics_frame
		frames += 1
		if not is_instance_valid(level) or done[0]:
			break
		if mv.state.timelines.is_empty():
			continue
		var active: Object = level.scheduler.get_active_unit()
		if level.round_index == round_seen and (active == null or active == active_seen):
			continue
		round_seen = level.round_index
		active_seen = active
		var s: Dictionary = _sample(level)
		integral_units += float(s["units"])
		integral_strength += float(s["strength"])
		samples += 1
	var r: Dictionary = done[1]
	var row: Dictionary = {
		"seed": seed, "finished": done[0], "turns": samples,
		"offers": counts[0], "accepted": counts[1],
		"travels": int(r.get("travels", 0)), "frozen": int(r.get("frozen", 0)),
		"integral_units": integral_units, "integral_strength": integral_strength,
		"mean_units": integral_units / maxf(1.0, float(samples)),
		"mean_strength": integral_strength / maxf(1.0, float(samples)),
	}
	rows.append(row)
	print("probe: seed=%d turns=%d offers=%d accepted=%d travels=%d frozen=%d mean_units=%+.2f mean_strength=%+.1f" % [
		seed, samples, counts[0], counts[1], int(r.get("travels", 0)), int(r.get("frozen", 0)), row["mean_units"], row["mean_strength"]])


func _report(ai: int, travel_side: String) -> void:
	if rows.is_empty():
		print("PROBE: no rows")
		return
	var offers: int = 0
	var accepted: int = 0
	var travels: int = 0
	var frozen: int = 0
	var finished: int = 0
	var mu: Array[float] = []
	var ms: Array[float] = []
	for row in rows:
		offers += int(row["offers"])
		accepted += int(row["accepted"])
		travels += int(row["travels"])
		frozen += int(row["frozen"])
		finished += 1 if bool(row["finished"]) else 0
		mu.append(float(row["mean_units"]))
		ms.append(float(row["mean_strength"]))
	print("PROBE ai=%d travel_side=%s seeds=%d finished=%d offers=%d accepted=%d travels=%d frozen=%d" % [ai, travel_side, rows.size(), finished, offers, accepted, travels, frozen])
	print("PROBE margin-integral (player perspective, per turn): units mean=%+.3f sd=%.3f | strength mean=%+.2f sd=%.2f" % [_mean(mu), _sd(mu), _mean(ms), _sd(ms)])


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v in values:
		total += v
	return total / float(values.size())


func _sd(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var m: float = _mean(values)
	var acc: float = 0.0
	for v in values:
		acc += (v - m) * (v - m)
	return sqrt(acc / float(values.size() - 1))
