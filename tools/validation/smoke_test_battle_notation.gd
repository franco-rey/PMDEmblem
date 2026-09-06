extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "notation_smoke"
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	definition.player_team = [_instance("0004_charmander", ["ember", "growl"], PokemonInstanceResource.Team.PLAYER)]
	definition.enemy_team = [_instance("0001_bulbasaur", ["tackle"], PokemonInstanceResource.Team.ENEMY)]
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	_assert_true(level._scheduler_started, "scheduler started for the notation smoke")
	var attacker: TacticsPawn = level.player.get_child(0)
	var defender: TacticsPawn = level.opponent.get_child(0)
	var notation: BattleNotation = level.notation
	_assert_true(notation.lines.size() >= 4 and notation.lines[0] == "[Notation \"pmdn/1\"]" and notation.lines[1] == "[Battle \"notation_smoke\"]" and notation.lines[2] == "[Seed 31]", "notation header tags written (%s)" % (notation.lines[0] if not notation.lines.is_empty() else ""))
	var terrain_lines: int = 0
	for line in notation.lines:
		if String(line).begins_with("terrain "):
			terrain_lines += 1
	_assert_true(terrain_lines == notation.rows, "one terrain line per row (%d rows)" % notation.rows)
	_assert_true(notation.columns > 0 and notation.rows > 0 and notation.tile_label(notation.origin) == "A1", "grid origin labels as A1 (%dx%d)" % [notation.columns, notation.rows])
	_assert_true(notation.tile_label(notation.origin + Vector3i(2, 0, 3)) == "C4", "tile labels use letter columns and numbered rows")
	var setup_lines: int = 0
	for line in notation.lines:
		if String(line).begins_with("unit P1 0004_charmander L") or String(line).begins_with("unit E1 0001_bulbasaur L"):
			setup_lines += 1
	_assert_true(setup_lines == 2, "both units recorded as unit lines with id, species, level, HP, tile and moves")
	_assert_true(notation.unit_id(attacker) == "P1" and notation.unit_id(defender) == "E1" and notation.pawn_for_id("E1") == defender, "unit ids resolve both ways")
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var attacker_key: Vector3i = Targeting._tile_key(attacker.get_tile())
	for direction in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		if keys.has(attacker_key + direction):
			_settle_on_tile(defender, keys[attacker_key + direction])
			attacker.serv.movement.look_at_direction_8(attacker, Vector3(float(direction.x), 0.0, float(direction.z)))
			break
	var unit: BattleUnit = null
	for candidate in level.battle_units:
		if candidate.pawn == attacker:
			unit = candidate
	var before_lines: int = notation.lines.size()
	level._on_turn_started(unit)
	var resolver := BattleActionResolver.new()
	resolver.execute(attacker, defender, 0, level)
	level._on_turn_completed(unit)
	var joined: String = "\n".join(notation.lines.slice(before_lines))
	_assert_true(joined.begins_with("T") and joined.split("\n")[0].contains(" P1 @") and joined.contains("\n  atk 1 ember E1"), "turn header and atk line recorded (%s)" % joined.replace("\n", " | "))
	_assert_true(joined.contains("\n  hit E1 -") and joined.contains("/%d" % defender.stats.max_health) and joined.ends_with("  end"), "hit line carries the defender id, damage and HP and the turn closes with end")
	for line in notation.lines:
		var parsed: Dictionary = NotationParser.parse(String(line))
		_assert_true(String(parsed.get("kind", "")) != "", "every line parses (%s)" % String(line))
	var start_tile: String = notation.label_for_pawn(attacker)
	level._on_turn_started(unit)
	var moved: bool = false
	for key in keys.keys():
		var tile: TacticsTile = keys[key]
		if tile.get_tile_occupier() == null and (key as Vector3i).distance_squared_to(attacker_key) <= 4 and key != attacker_key:
			_settle_on_tile(attacker, tile)
			moved = true
			break
	level._on_turn_completed(unit)
	var end_tile: String = notation.label_for_pawn(attacker)
	_assert_true(moved and notation.lines[notation.lines.size() - 2] == "  mv %s>%s" % [start_tile, end_tile] and notation.lines[notation.lines.size() - 1] == "  end", "movement recorded as mv from>to before end (%s)" % notation.lines[notation.lines.size() - 2])
	notation.finish(1)
	var path: String = notation.save()
	_assert_true(not path.is_empty() and path.ends_with(".pmdn") and FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).contains("result player turns="), "notation saved to %s" % path)
	loader.unload_current()
	loader.queue_free()
	await process_frame
	if failures > 0:
		push_error("smoke: battle_notation failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: battle_notation clean")
	quit(0)


func _instance(slug: String, move_ids: Array, team: int) -> PokemonInstanceResource:
	var template: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/%s.tres" % slug) as PokemonInstanceResource
	var instance: PokemonInstanceResource = SkirmishMoveLoadout.clone_for_side(template, team, PokemonInstanceResource.ControlType.PLAYER)
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for move_id in move_ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(move_id)]) as PokemonMoveResource
		slots.append(move)
		pp.append(move.pp)
	while slots.size() < PokemonInstanceResource.MAX_MOVE_SLOTS:
		slots.append(slots[0])
		pp.append(slots[0].pp)
	instance.move_slots = slots
	instance.pp_state = pp
	instance.loadout_locked = true
	return instance


func _settle_on_tile(pawn: TacticsPawn, tile: TacticsTile) -> void:
	var ray: RayCast3D = pawn.get_node("Tile") as RayCast3D
	pawn.global_position = tile.global_position + Vector3.UP * 0.05
	ray.force_raycast_update()
	pawn.center()
	ray.force_raycast_update()


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
