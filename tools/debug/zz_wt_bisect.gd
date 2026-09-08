extends SceneTree

const MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const TUNING = preload("res://tools/debug/run_weight_tuning.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DebugLog.set_debug_enabled(false)
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var chart: TypeChartResource = load("res://data/models/pokemon/generated/types/type_chart.tres")
	var total: int = 0
	var same: int = 0
	for seed in range(1, 5):
		var built: Dictionary = CustomSkirmishBuilder.build_random(4, MAP_PATH, str(seed), SkirmishDefinitionResource.CONTROL_MODE_CPU_VS_CPU)
		if not bool(built.get("ok", false)):
			continue
		var definition: SkirmishDefinitionResource = built["definition"]
		var copies: Array[PokemonInstanceResource] = []
		for source in definition.player_team:
			var clone: PokemonInstanceResource = source.duplicate(true)
			clone.team = PokemonInstanceResource.Team.ENEMY
			clone.control_type = PokemonInstanceResource.ControlType.AI
			copies.append(clone)
		definition.enemy_team = copies
		definition.skirmish_id = "zz_bisect_%d" % seed
		var level: TacticsLevel = loader.load_skirmish(definition, root)
		if level == null:
			continue
		level.ai_team_levels = {
			PokemonInstanceResource.Team.PLAYER: 5,
			PokemonInstanceResource.Team.ENEMY: 5,
		}
		level.presentation_runner.immediate_mode = true
		level.process_mode = Node.PROCESS_MODE_ALWAYS
		var frames: int = 0
		while frames < 400 and not level._scheduler_started:
			await physics_frame
			frames += 1
		level.process_mode = Node.PROCESS_MODE_DISABLED
		var stock := BattleAI.new()
		stock.set_team_levels(level.ai_team_levels)
		var tuned = TUNING.TunedAI.new()
		tuned.team_weights = {
			PokemonInstanceResource.Team.PLAYER: TUNING.BASE_WEIGHTS.duplicate(),
			PokemonInstanceResource.Team.ENEMY: TUNING.BASE_WEIGHTS.duplicate(),
		}
		tuned.set_team_levels(level.ai_team_levels)
		var pawns: Array[TacticsPawn] = []
		for node in [level.player, level.opponent]:
			for child in node.get_children():
				if child is TacticsPawn:
					pawns.append(child)
		for index in range(pawns.size()):
			var pawn: TacticsPawn = pawns[index]
			var allies: Array = []
			var enemies: Array = []
			for other in pawns:
				if level.pawn_team(other) == level.pawn_team(pawn):
					allies.append(other)
				else:
					enemies.append(other)
			level.arena.reset_all_tile_markers()
			level.arena.process_surrounding_tiles(pawn.get_tile(), pawn.stats.movement, allies)
			level.arena.mark_reachable_tiles(pawn.get_tile(), pawn.stats.movement)
			stock.forget(pawn)
			var a: AIAction = stock.choose_action(pawn, allies, enemies, chart, level)
			level.arena.reset_all_tile_markers()
			level.arena.process_surrounding_tiles(pawn.get_tile(), pawn.stats.movement, allies)
			level.arena.mark_reachable_tiles(pawn.get_tile(), pawn.stats.movement)
			tuned.forget(pawn)
			var b: AIAction = tuned.choose_action(pawn, allies, enemies, chart, level)
			total += 1
			var equal: bool = a.move_index == b.move_index and a.target_unit == b.target_unit and a.move_to_tile == b.move_to_tile
			if equal:
				same += 1
			else:
				print("zz: seed=%d unit=%d stock=(%s,%d,%s) tuned=(%s,%d,%s)" % [
					seed, index,
					str(Targeting._tile_key(a.move_to_tile)) if a.move_to_tile != null else "-",
					a.move_index,
					str(a.target_unit.name) if a.target_unit != null else "-",
					str(Targeting._tile_key(b.move_to_tile)) if b.move_to_tile != null else "-",
					b.move_index,
					str(b.target_unit.name) if b.target_unit != null else "-",
				])
		level.queue_free()
		await process_frame
	print("zz: agree=%d/%d" % [same, total])
	quit(0)
