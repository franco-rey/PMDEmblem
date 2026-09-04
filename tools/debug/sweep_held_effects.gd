extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/test_arena.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"
const OUTPUT_DIR: String = "res://logs/debug/validation"
const ATTACKER: String = "0006_charizard"
const DEFENDER: String = "0009_blastoise"
const ATTACKER_MOVES: Array[String] = ["slash", "flamethrower", "growl", "toxic"]
const DEFENDER_MOVES: Array[String] = ["tackle", "water_gun", "tail_whip", "poison_powder"]

var results: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var mode: String = _arg("mode")
	var subjects: Array[String] = []
	if mode == "items":
		for entry in BattleItemCatalog.entries():
			subjects.append(String(entry["item_id"]))
	else:
		subjects = BattleIntrinsicService.SUPPORTED_INTRINSICS.duplicate()
		subjects.sort()
	var only: String = _arg("only")
	if not only.is_empty():
		subjects = []
		for token in only.split(","):
			subjects.append(String(token))
	var baseline: Dictionary = await _exchange("", "", "", "")
	print("sweep: baseline %s" % JSON.stringify(baseline["summary"]))
	for subject in subjects:
		var as_attacker: Dictionary = await _exchange(subject if mode == "items" else "", "", subject if mode != "items" else "", "")
		var as_defender: Dictionary = await _exchange("", subject if mode == "items" else "", "", subject if mode != "items" else "")
		var row: Dictionary = {
			"subject": subject,
			"attacker": _diff(baseline, as_attacker, subject),
			"defender": _diff(baseline, as_defender, subject),
		}
		row["observed"] = not (row["attacker"]["differences"] as Array).is_empty() or not (row["defender"]["differences"] as Array).is_empty()
		row["errors"] = int(as_attacker.get("errors", 0)) + int(as_defender.get("errors", 0))
		results.append(row)
		print("sweep: %s observed=%s attacker=%s defender=%s" % [subject, str(row["observed"]), JSON.stringify(row["attacker"]["differences"]), JSON.stringify(row["defender"]["differences"])])
	var observed: int = 0
	for row in results:
		if bool(row["observed"]):
			observed += 1
	var file := FileAccess.open("%s/sweep_%s.json" % [OUTPUT_DIR, "items" if mode == "items" else "abilities"], FileAccess.WRITE)
	file.store_string(JSON.stringify({"generated": Time.get_datetime_string_from_system(), "mode": mode, "baseline": baseline["summary"], "observed": observed, "total": results.size(), "results": results}, "\t"))
	file.close()
	print("sweep: done %s observed=%d/%d" % [mode, observed, results.size()])
	quit(0)


func _exchange(attacker_item: String, defender_item: String, attacker_ability: String, defender_ability: String) -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var attacker_instance: PokemonInstanceResource = _instance(ATTACKER, ATTACKER_MOVES, PokemonInstanceResource.Team.PLAYER)
	var defender_instance: PokemonInstanceResource = _instance(DEFENDER, DEFENDER_MOVES, PokemonInstanceResource.Team.ENEMY)
	if not attacker_item.is_empty():
		attacker_instance.held_item = PokemonItemService.load_item(attacker_item)
	if not defender_item.is_empty():
		defender_instance.held_item = PokemonItemService.load_item(defender_item)
	if not attacker_ability.is_empty():
		attacker_instance.ability_override = attacker_ability
	if not defender_ability.is_empty():
		defender_instance.ability_override = defender_ability
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "sweep"
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	definition.player_team = [attacker_instance]
	definition.enemy_team = [defender_instance]
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	level.presentation_runner.immediate_mode = true
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var frames: int = 0
	while not level._scheduler_started and frames < 300:
		await physics_frame
		frames += 1
	var attacker: TacticsPawn = level.player.get_child(0)
	var defender: TacticsPawn = level.opponent.get_child(0)
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var attacker_key: Vector3i = Targeting._tile_key(attacker.get_tile())
	for direction in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		if keys.has(attacker_key + direction):
			_settle_on_tile(defender, keys[attacker_key + direction])
			attacker.serv.movement.look_at_direction_8(attacker, Vector3(float(direction.x), 0.0, float(direction.z)))
			defender.serv.movement.look_at_direction_8(defender, Vector3(-float(direction.x), 0.0, -float(direction.z)))
			break
	var resolver := BattleActionResolver.new()
	var rng := RandomNumberGenerator.new()
	level.battle_rng.seed = 4242
	var start: int = level.battle_log.events.size()
	var script: Array = [[attacker, defender, 0], [defender, attacker, 0], [attacker, defender, 1], [defender, attacker, 1], [attacker, defender, 2], [defender, attacker, 2], [attacker, defender, 3], [defender, attacker, 3]]
	for step in script:
		var user: TacticsPawn = step[0]
		var target: TacticsPawn = step[1]
		if user.stats.is_active() and target.stats.is_active():
			resolver.execute(user, target, int(step[2]), level)
		level._on_turn_started(_unit_for(level, target))
	level._on_round_started()
	level._on_turn_started(_unit_for(level, attacker))
	level._on_turn_started(_unit_for(level, defender))
	var damage: Dictionary = {}
	var kinds: Dictionary = {}
	var tagged: Array[String] = []
	var errors: int = 0
	for i in range(start, level.battle_log.events.size()):
		var event: Dictionary = level.battle_log.events[i]
		var kind: String = String(event.get("kind", ""))
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		if kind == "damage_dealt":
			var key: String = "%s:%s" % [String(event.get("move_id", "")), String(event.get("source", ""))]
			damage[key] = int(damage.get(key, 0)) + int(event.get("amount", 0))
		if event.has("item_id") or event.has("intrinsic_id"):
			var tag: String = "%s:%s" % [kind, String(event.get("item_id", event.get("intrinsic_id", "")))]
			if not tagged.has(tag):
				tagged.append(tag)
	var summary: Dictionary = {
		"attacker_hp": attacker.stats.curr_health,
		"defender_hp": defender.stats.curr_health,
		"attacker_statuses": attacker.stats.battle_statuses.keys(),
		"defender_statuses": defender.stats.battle_statuses.keys(),
		"attacker_stages": attacker.stats.stat_stages.duplicate(),
		"defender_stages": defender.stats.stat_stages.duplicate(),
		"damage": damage,
		"kinds": kinds,
		"tagged": tagged,
		"weather": level.current_weather(),
		"attacker_item": PokemonItemService.held_item_for(attacker.stats).item_id if PokemonItemService.held_item_for(attacker.stats) != null else "",
		"defender_item": PokemonItemService.held_item_for(defender.stats).item_id if PokemonItemService.held_item_for(defender.stats) != null else "",
	}
	loader.unload_current()
	loader.queue_free()
	await process_frame
	return {"summary": summary, "errors": errors}


func _diff(baseline: Dictionary, run: Dictionary, subject: String) -> Dictionary:
	var a: Dictionary = baseline["summary"]
	var b: Dictionary = run["summary"]
	var differences: Array[String] = []
	for key in ["attacker_hp", "defender_hp", "weather"]:
		if str(a[key]) != str(b[key]):
			differences.append("%s %s->%s" % [key, str(a[key]), str(b[key])])
	for key in ["attacker_statuses", "defender_statuses", "attacker_stages", "defender_stages"]:
		if str(a[key]) != str(b[key]):
			differences.append("%s %s->%s" % [key, str(a[key]), str(b[key])])
	var damage_a: Dictionary = a["damage"]
	var damage_b: Dictionary = b["damage"]
	for key in damage_b.keys():
		if int(damage_a.get(key, 0)) != int(damage_b[key]):
			differences.append("damage %s %d->%d" % [String(key), int(damage_a.get(key, 0)), int(damage_b[key])])
	for key in damage_a.keys():
		if not damage_b.has(key):
			differences.append("damage %s gone" % String(key))
	for tag in b["tagged"]:
		if not (a["tagged"] as Array).has(tag):
			differences.append("event %s" % String(tag))
	return {"differences": differences, "summary": b}


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


func _unit_for(level: TacticsLevel, pawn: TacticsPawn) -> BattleUnit:
	for unit in level.battle_units:
		if unit.pawn == pawn:
			return unit
	return null


func _settle_on_tile(pawn: TacticsPawn, tile: TacticsTile) -> void:
	var ray: RayCast3D = pawn.get_node("Tile") as RayCast3D
	pawn.global_position = tile.global_position + Vector3.UP * 0.05
	ray.force_raycast_update()
	pawn.center()
	ray.force_raycast_update()


func _arg(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = String(arg)
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return ""
