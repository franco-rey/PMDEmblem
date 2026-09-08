extends SceneTree

const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DebugLog.set_debug_enabled(false)
	var t0: int = Time.get_ticks_msec()
	var built: Dictionary = CustomSkirmishBuilder.build_random(4, MAP_PATH, "1", SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
	print("build ok=%s ms=%d" % [built.get("ok", false), Time.get_ticks_msec() - t0])
	if not bool(built.get("ok", false)):
		quit(1)
		return
	var definition: SkirmishDefinitionResource = built["definition"]
	definition.skirmish_id = "zz_probe"
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	t0 = Time.get_ticks_msec()
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	print("load ms=%d level=%s" % [Time.get_ticks_msec() - t0, level != null])
	if level == null:
		quit(1)
		return
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	await physics_frame
	await physics_frame
	var sim := BattleSim.new()
	t0 = Time.get_ticks_usec()
	var state: PackedInt32Array = sim.setup_from_level(level)
	print("setup us=%d size=%d units=%d tiles=%d" % [Time.get_ticks_usec() - t0, state.size(), sim.unit_count, sim.tile_count])
	var counts: Array[int] = []
	var probe: PackedInt32Array = state.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var turns: int = 0
	t0 = Time.get_ticks_usec()
	while not sim.is_over(probe) and turns < 200:
		var unit: int = sim.active_unit(probe)
		if unit < 0:
			break
		var actions: PackedInt32Array = sim.legal_actions_packed(probe, unit)
		counts.append(actions.size())
		sim.apply_packed(probe, actions[rng.randi_range(0, actions.size() - 1)])
		turns += 1
	var span: int = Time.get_ticks_usec() - t0
	var total: int = 0
	var most: int = 0
	for c in counts:
		total += c
		most = maxi(most, c)
	print("playout turns=%d us=%d result=%d mean_actions=%.1f max_actions=%d" % [turns, span, sim.result(probe), float(total) / float(maxi(1, counts.size())), most])
	var reps: int = 50
	t0 = Time.get_ticks_usec()
	for i in range(reps):
		var d: PackedInt32Array = state.duplicate()
		var prng := RandomNumberGenerator.new()
		prng.seed = i
		sim.random_playout(d, prng)
	span = Time.get_ticks_usec() - t0
	print("random_playout x%d us=%d per_battle_ms=%.2f rate=%.1f/s" % [reps, span, float(span) / float(reps) / 1000.0, float(reps) * 1000000.0 / float(span)])
	t0 = Time.get_ticks_usec()
	var clones: int = 20000
	for i in range(clones):
		var d2: PackedInt32Array = state.duplicate()
	span = Time.get_ticks_usec() - t0
	print("clone x%d us=%d" % [clones, span])
	t0 = Time.get_ticks_usec()
	var la_reps: int = 2000
	for i in range(la_reps):
		sim.legal_actions_packed(state, sim.active_unit(state))
	span = Time.get_ticks_usec() - t0
	print("legal_actions x%d us=%d per_call_us=%.1f" % [la_reps, span, float(span) / float(la_reps)])
	quit(0)
