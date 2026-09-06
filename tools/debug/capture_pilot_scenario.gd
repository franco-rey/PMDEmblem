extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/chessboard.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"
const OUTPUT_DIR: String = "res://logs/debug/pilot_captures"
const SCENARIOS: Array[Dictionary] = [
	{"id": "bulbasaur_razor_leaf", "attacker": "0001_bulbasaur", "defender": "0004_charmander", "moves": ["razor_leaf", "tackle", "vine_whip", "growl"], "action": "move", "slot": 0, "distance": 3, "shots": [0.05, 0.35, 0.7, 1.1, 1.6]},
	{"id": "bulbasaur_tackle", "attacker": "0001_bulbasaur", "defender": "0004_charmander", "moves": ["tackle", "razor_leaf"], "action": "move", "slot": 0, "distance": 1, "shots": [0.05, 0.2, 0.35, 0.55, 0.9]},
	{"id": "charmander_ember", "attacker": "0004_charmander", "defender": "0007_squirtle", "moves": ["ember", "scratch"], "action": "move", "slot": 0, "distance": 2, "shots": [0.05, 0.3, 0.6, 0.9, 1.3]},
	{"id": "squirtle_water_gun", "attacker": "0007_squirtle", "defender": "0004_charmander", "moves": ["water_gun", "tackle"], "action": "move", "slot": 0, "distance": 4, "shots": [0.05, 0.3, 0.6, 0.9, 1.4]},
	{"id": "charizard_flamethrower", "attacker": "0006_charizard", "defender": "0003_venusaur", "moves": ["flamethrower", "slash"], "action": "move", "slot": 0, "distance": 4, "shots": [0.05, 0.3, 0.6, 0.9, 1.4]},
	{"id": "blastoise_withdraw", "attacker": "0009_blastoise", "defender": "0002_ivysaur", "moves": ["withdraw", "tackle"], "action": "move", "slot": 0, "distance": 2, "shots": [0.05, 0.3, 0.6, 0.9]},
	{"id": "wartortle_bite", "attacker": "0008_wartortle", "defender": "0005_charmeleon", "moves": ["bite", "tackle"], "action": "move", "slot": 0, "distance": 1, "shots": [0.05, 0.2, 0.4, 0.6, 0.9]},
	{"id": "charmeleon_slash", "attacker": "0005_charmeleon", "defender": "0002_ivysaur", "moves": ["slash", "ember"], "action": "move", "slot": 0, "distance": 1, "shots": [0.05, 0.2, 0.4, 0.6, 0.9]},
	{"id": "ivysaur_blast_seed_throw", "attacker": "0002_ivysaur", "defender": "0005_charmeleon", "moves": ["tackle"], "action": "throw", "item": "seed_blast", "distance": 3, "shots": [0.05, 0.3, 0.5, 0.75, 1.0, 1.4]},
	{"id": "venusaur_blast_seed_use", "attacker": "0003_venusaur", "defender": "0006_charizard", "moves": ["tackle"], "action": "use", "item": "seed_blast", "distance": 1, "shots": [0.05, 0.3, 0.6, 0.9, 1.3]},
	{"id": "squirtle_faint", "attacker": "0006_charizard", "defender": "0007_squirtle", "moves": ["flamethrower"], "action": "move", "slot": 0, "distance": 2, "defender_hp": 1, "shots": [0.05, 0.5, 0.9, 1.3, 1.8]},
]

var captured: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var only: String = _arg("only")
	for scenario in SCENARIOS:
		if not only.is_empty() and String(scenario["id"]) != only:
			continue
		await _capture_scenario(scenario)
	print("captures: %d files written under %s" % [captured.size(), OUTPUT_DIR])
	for path in captured:
		print("capture: %s" % path)
	quit(0)


func _capture_scenario(scenario: Dictionary) -> void:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var attacker_instance: PokemonInstanceResource = _instance(String(scenario["attacker"]), scenario.get("moves", []), PokemonInstanceResource.Team.PLAYER, String(scenario.get("item", "")))
	var defender_instance: PokemonInstanceResource = _instance(String(scenario["defender"]), ["tackle"], PokemonInstanceResource.Team.ENEMY, "")
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "capture_%s" % String(scenario["id"])
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	definition.player_team = [attacker_instance]
	definition.enemy_team = [defender_instance]
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	level.presentation_runner.immediate_mode = false
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	await process_frame
	await process_frame
	var attacker: TacticsPawn = level.player.get_child(0)
	var defender: TacticsPawn = level.opponent.get_child(0)
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var attacker_key: Vector3i = Targeting._tile_key(attacker.get_tile())
	var distance: int = int(scenario.get("distance", 1))
	var facing: Vector3i = Vector3i.ZERO
	var target_tile: TacticsTile = null
	for direction in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		var ok: bool = true
		for step in range(1, distance + 1):
			if not keys.has(attacker_key + direction * step):
				ok = false
		if ok:
			facing = direction
			target_tile = keys[attacker_key + direction * distance]
			break
	if target_tile == null:
		print("capture: no straight lane for %s" % String(scenario["id"]))
		loader.unload_current()
		loader.queue_free()
		return
	_settle_on_tile(defender, target_tile)
	attacker.serv.movement.look_at_direction_8(attacker, Vector3(float(facing.x), 0.0, float(facing.z)))
	defender.serv.movement.look_at_direction_8(defender, Vector3(float(-facing.x), 0.0, float(-facing.z)))
	if scenario.has("defender_hp"):
		defender.stats.curr_health = int(scenario["defender_hp"])
	var camera := Camera3D.new()
	camera.name = "CaptureCamera"
	root.add_child(camera)
	var mid: Vector3 = (attacker.global_position + defender.global_position) * 0.5
	var span: float = maxf(2.5, attacker.global_position.distance_to(defender.global_position) + 2.5)
	var side: Vector3 = Vector3(float(facing.z), 0.0, float(-facing.x))
	camera.global_position = mid + side * span * 1.1 + Vector3.UP * (span * 0.7)
	camera.look_at(mid + Vector3.UP * 0.5, Vector3.UP)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	root.add_child(light)
	await process_frame
	await process_frame
	await _snap("%s_00_idle" % String(scenario["id"]))
	var resolver := BattleActionResolver.new()
	match String(scenario.get("action", "move")):
		"throw":
			resolver.execute_intent(BattleActionIntent.throw_item(attacker, String(scenario["item"]), facing, defender), level)
		"use":
			resolver.execute_intent(BattleActionIntent.use_item(attacker, String(scenario["item"])), level)
		_:
			resolver.execute(attacker, defender, int(scenario.get("slot", 0)), level)
	var shots: Array = scenario.get("shots", [])
	var elapsed: float = 0.0
	var shot_index: int = 0
	var frames: int = 0
	while (level.presentation_runner.is_busy() or shot_index < shots.size()) and frames < 600:
		await process_frame
		frames += 1
		elapsed += get_root().get_process_delta_time() if get_root() != null else 1.0 / 60.0
		if shot_index < shots.size() and elapsed >= float(shots[shot_index]):
			await _snap("%s_%02d_t%.2f" % [String(scenario["id"]), shot_index + 1, elapsed])
			shot_index += 1
		if not level.presentation_runner.is_busy() and shot_index >= shots.size():
			break
	var cleanup: int = 0
	while level.vfx_player.active_count() > 0 and cleanup < 300:
		await process_frame
		cleanup += 1
	await _snap("%s_99_end" % String(scenario["id"]))
	print("capture: %s finished in %d frames, vfx remaining %d, runner stats %s" % [String(scenario["id"]), frames, level.vfx_player.active_count(), str(level.presentation_runner.stats())])
	camera.queue_free()
	light.queue_free()
	loader.unload_current()
	loader.queue_free()
	await process_frame


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		return
	var path: String = "%s/%s.png" % [OUTPUT_DIR, label]
	image.save_png(ProjectSettings.globalize_path(path))
	captured.append(path)


func _settle_on_tile(pawn: TacticsPawn, tile: TacticsTile) -> void:
	var ray: RayCast3D = pawn.get_node("Tile") as RayCast3D
	pawn.global_position = tile.global_position + Vector3.UP * 0.05
	ray.force_raycast_update()
	pawn.center()
	ray.force_raycast_update()


func _instance(slug: String, move_ids: Array, team: int, item_id: String) -> PokemonInstanceResource:
	var template: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/%s.tres" % slug) as PokemonInstanceResource
	var instance: PokemonInstanceResource = SkirmishMoveLoadout.clone_for_side(template, team, PokemonInstanceResource.ControlType.PLAYER)
	var slots: Array[PokemonMoveResource] = []
	var pp: Array[int] = []
	for move_id in move_ids:
		var move: PokemonMoveResource = load("%s%s.tres" % [GENERATED_MOVES_DIR, String(move_id)]) as PokemonMoveResource
		if move != null:
			slots.append(move)
			pp.append(move.pp)
	while not slots.is_empty() and slots.size() < PokemonInstanceResource.MAX_MOVE_SLOTS:
		slots.append(slots[0])
		pp.append(slots[0].pp)
	instance.move_slots = slots
	instance.pp_state = pp
	instance.held_item = PokemonItemService.load_item(item_id) if not item_id.is_empty() else null
	return instance


func _arg(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = String(arg)
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return ""
