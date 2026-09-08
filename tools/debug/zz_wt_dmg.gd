extends SceneTree

const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DebugLog.set_debug_enabled(false)
	var chart: TypeChartResource = load("res://data/models/pokemon/generated/types/type_chart.tres")
	print("typelist0=%s size=%d" % [chart.type_list[0], chart.type_list.size()])
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var worst: Array = []
	var total: int = 0
	var mismatch: int = 0
	var slug_mismatch: int = 0
	for seed in range(1, 7):
		var built: Dictionary = CustomSkirmishBuilder.build_random(4, MAP_PATH, str(seed), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
		if not bool(built.get("ok", false)):
			continue
		var definition: SkirmishDefinitionResource = built["definition"]
		definition.skirmish_id = "zz_dmg_%d" % seed
		var level: TacticsLevel = loader.load_skirmish(definition, root)
		if level == null:
			continue
		level.presentation_runner.immediate_mode = true
		level.process_mode = Node.PROCESS_MODE_ALWAYS
		var frames: int = 0
		while frames < 400 and not level._scheduler_started:
			await physics_frame
			frames += 1
		level.process_mode = Node.PROCESS_MODE_DISABLED
		var sim := BattleSim.new()
		var state: PackedInt32Array = sim.setup_from_level(level)
		var pawns: Array[TacticsPawn] = sim._ordered_pawns(level)
		var ai := BattleAI.new()
		ai.set_level(5)
		ai.profile = AIProfile.for_level(5)
		ai._chart = chart
		var rng := RandomNumberGenerator.new()
		for a in range(pawns.size()):
			var slugs: Array[String] = BattleIntrinsicService.natural_slugs_static(pawns[a].stats)
			if slugs.size() > 1:
				slug_mismatch += 1
			for b in range(pawns.size()):
				if a == b:
					continue
				for s in range(pawns[a].stats.move_slots.size()):
					var move: PokemonMoveResource = pawns[a].stats.move_slots[s]
					if move == null or not move.is_damaging():
						continue
					var real: float = ai._expected_damage(pawns[a], pawns[b], move, chart)
					var mi: int = state[a * BattleSim.U_STRIDE + BattleSim.U_MOVE + s]
					var eff: float = sim._effectiveness(sim.move_info[mi * BattleSim.M_STRIDE + BattleSim.M_TYPE], state[b * BattleSim.U_STRIDE + BattleSim.U_TYPE1], state[b * BattleSim.U_STRIDE + BattleSim.U_TYPE2])
					sim._hydrate(state, a, b, mi)
					eff = sim._intrinsics.adjust_effectiveness(sim._sa, sim._sb, move, eff, chart)
					var sim_value: float = 0.0
					if eff > 0.0:
						var stab: bool = sim.move_info[mi * BattleSim.M_STRIDE + BattleSim.M_TYPE] == state[a * BattleSim.U_STRIDE + BattleSim.U_TYPE1] or sim.move_info[mi * BattleSim.M_STRIDE + BattleSim.M_TYPE] == state[a * BattleSim.U_STRIDE + BattleSim.U_TYPE2]
						rng.seed = 991
						var raw: int = sim._damage.calculate_damage(sim._sa, sim._sb, move, eff, stab, 1.0, rng, {}, true)
						var acc: float = clampf(float(move.accuracy) / 100.0, 0.0, 1.0) if move.accuracy > 0 else 1.0
						sim_value = float(raw) * acc
					total += 1
					if absf(real - sim_value) > 0.51:
						mismatch += 1
						if worst.size() < 14:
							worst.append("%s(%s) -> %s move=%s real=%.1f sim=%.1f types=%s/%s ability=%s" % [
								pawns[a].name, ",".join(pawns[a].stats.types), pawns[b].name, move.move_id, real, sim_value,
								",".join(pawns[b].stats.types), sim.type_names[state[b * BattleSim.U_STRIDE + BattleSim.U_TYPE2]],
								",".join(BattleIntrinsicService.natural_slugs_static(pawns[b].stats))])
		level.queue_free()
		await process_frame
	print("zz: damage pairs=%d mismatch=%d (%.3f) multi_ability_units=%d" % [total, mismatch, float(mismatch) / float(maxi(1, total)), slug_mismatch])
	for line in worst:
		print("zz:   %s" % line)
	quit(0)
