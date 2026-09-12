extends SmokeCase

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"


func _run() -> void:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "badges"
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	definition.player_team = [_instance("0004_charmander", ["scratch"], PokemonInstanceResource.Team.PLAYER)]
	definition.enemy_team = [_instance("0007_squirtle", ["tackle"], PokemonInstanceResource.Team.ENEMY)]
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var squirtle: TacticsPawn = level.opponent.get_child(0)
	var row: StatusBadgeRow = squirtle.get_node_or_null("Character/StatusBadges") as StatusBadgeRow
	_assert_true(row != null, "each pawn carries a status badge row")
	await process_frame
	_assert_true(row.badge_texts().is_empty(), "no badges while healthy")
	var ops: BattleStateOps = level._ops()
	ops.apply_status(squirtle, "burn", {}, {"kind": "test", "skip_rules": true})
	ops.apply_status(squirtle, "leech_seed", {}, {"kind": "test", "skip_rules": true})
	ops.apply_status(squirtle, "protect", {}, {"kind": "test", "skip_rules": true})
	await process_frame
	await process_frame
	var texts: Array[String] = row.badge_texts()
	_assert_true(texts.size() == 3 and texts.has("burn") and texts.has("SEED") and texts.has("protect"), "PMD emoticons show for burn and protect, a text badge for leech seed (%s)" % str(texts))
	ops.remove_status(squirtle, "burn", {"source": "test"})
	await process_frame
	await process_frame
	texts = row.badge_texts()
	_assert_true(texts.size() == 2 and not texts.has("burn"), "badges drop a cured status (%s)" % str(texts))
	_assert_true(row.has_icon("sleep") and row.has_icon("poison") and not row.has_icon("leech_seed"), "emoticon sheets resolve for sleep and poison; leech seed has none")
	ops.apply_status(squirtle, "sure_shot", {}, {"kind": "test", "skip_rules": true})
	await process_frame
	await process_frame
	_assert_true(row.badge_texts().size() == 2, "hidden bookkeeping statuses show no badge")
	ops.apply_status(squirtle, "freeze", {}, {"kind": "test", "skip_rules": true})
	_assert_true(squirtle.serv.ui.status_draw_tint(squirtle) == TacticsPawnHudService.FREEZE_TINT, "a frozen unit is tinted like PMDO's freeze draw effect")
	ops.remove_status(squirtle, "freeze", {"source": "test"})
	ops.apply_status(squirtle, "paralyze", {}, {"kind": "test", "skip_rules": true})
	var tints: Dictionary = {}
	for i in range(60):
		tints[squirtle.serv.ui.status_draw_tint(squirtle)] = true
		await process_frame
	_assert_true(tints.size() == 2, "a paralyzed unit flickers between two tints (%d)" % tints.size())
	loader.unload_current()
	loader.queue_free()
	await process_frame
	_finish("status_badges")


func _instance(slug: String, move_ids: Array, team: int) -> PokemonInstanceResource:
	var template: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/%s.tres" % slug) as PokemonInstanceResource
	var instance: PokemonInstanceResource = SkirmishMoveLoadout.clone_for_side(template, team, PokemonInstanceResource.ControlType.PLAYER)
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for move_id in move_ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(move_id)]) as PokemonMoveResource
		slots.append(move)
		pp.append(move.pp)
	instance.move_slots = slots
	instance.pp_state = pp
	instance.loadout_locked = true
	return instance
