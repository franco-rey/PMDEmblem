extends SceneTree

const TEST_ARENA_MAP_PATH: String = "res://data/models/maps/definitions/test_arena.tres"
const GENERATED_MOVES_DIR: String = "res://data/models/pokemon/generated/moves/"
const OUTPUT_DIR: String = "res://logs/debug/move_verification"
const PILOT: Array[Dictionary] = [
	{"slug": "0001_bulbasaur", "defender": "0007_squirtle"},
	{"slug": "0002_ivysaur", "defender": "0007_squirtle"},
	{"slug": "0003_venusaur", "defender": "0008_wartortle"},
	{"slug": "0004_charmander", "defender": "0001_bulbasaur"},
	{"slug": "0005_charmeleon", "defender": "0002_ivysaur"},
	{"slug": "0006_charizard", "defender": "0003_venusaur"},
	{"slug": "0007_squirtle", "defender": "0004_charmander"},
	{"slug": "0008_wartortle", "defender": "0005_charmeleon"},
	{"slug": "0009_blastoise", "defender": "0006_charizard"},
]
const DAMAGE_FAMILIES: Array[String] = ["damage", "multi_hit", "fixed_damage", "level_damage", "percent_damage", "hp_to_1"]
const SHOT_TIMES: Array[float] = [0.35, 0.9]

var results: Array[Dictionary] = []
var windowed: bool = false
var frames_written: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	windowed = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR + "/frames"))
	var only: String = _arg("only")
	var move_filter: PackedStringArray = _arg("moves").split(",", false)
	var all_moves: bool = _arg("all-moves") == "1"
	var roster: Array[Dictionary] = _roster_entries(only)
	for entry in roster:
		var slug: String = String(entry["slug"])
		var template: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/%s.tres" % slug) as PokemonInstanceResource
		var pool: Array[PokemonMoveResource] = _all_generated_moves() if all_moves else SkirmishMoveLoadout.move_pool_for_instance(template)
		for move in pool:
			if not move_filter.is_empty() and not move_filter.has(move.move_id):
				continue
			await _verify(slug, String(entry["defender"]), move.move_id)
	var counts: Dictionary = {}
	for result in results:
		var verdict: String = String(result["verdict"])
		counts[verdict] = int(counts.get(verdict, 0)) + 1
	var report_name: String = _arg("report") if not _arg("report").is_empty() else "pilot_moves_report.json"
	var file := FileAccess.open(OUTPUT_DIR + "/" + report_name, FileAccess.WRITE)
	file.store_string(JSON.stringify({"generated": Time.get_datetime_string_from_system(), "windowed": windowed, "counts": counts, "results": results}, "\t"))
	file.close()
	print("verify: done %d moves %s frames %d -> %s/%s" % [results.size(), JSON.stringify(counts), frames_written, OUTPUT_DIR, report_name])
	quit(0)


func _all_generated_moves() -> Array[PokemonMoveResource]:
	var out: Array[PokemonMoveResource] = []
	var dir := DirAccess.open(GENERATED_MOVES_DIR)
	if dir == null:
		return out
	var files: Array[String] = []
	for file in dir.get_files():
		if file.ends_with(".tres"):
			files.append(file)
	files.sort()
	for file in files:
		var move: PokemonMoveResource = load(GENERATED_MOVES_DIR + file) as PokemonMoveResource
		if move != null:
			out.append(move)
	return out


func _roster_entries(only: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if only.is_empty():
		return PILOT.duplicate()
	for token in only.split(",", false):
		var wanted: String = String(token).strip_edges().to_lower()
		var matched: bool = false
		for entry in PILOT:
			var slug: String = String(entry["slug"])
			if slug == wanted or slug.ends_with(wanted):
				out.append(entry)
				matched = true
		if matched:
			continue
		var slug_match: String = _slug_for_token(wanted)
		if slug_match.is_empty():
			print("verify: unknown species %s" % wanted)
			continue
		out.append({"slug": slug_match, "defender": _default_defender(slug_match)})
	return out


func _slug_for_token(token: String) -> String:
	var dir := DirAccess.open("res://data/models/pokemon/generated/instances/")
	if dir == null:
		return ""
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var slug: String = file.get_basename()
		if slug == token or slug.ends_with("_" + token) or (token.is_valid_int() and slug.begins_with("%04d_" % int(token))):
			return slug
	return ""


func _default_defender(slug: String) -> String:
	var template: PokemonInstanceResource = load("res://data/models/pokemon/generated/instances/%s.tres" % slug) as PokemonInstanceResource
	var types: Array = template.resolved_form().types() if template != null and template.resolved_form() != null else []
	if types.has("water") or types.has("ground") or types.has("rock"):
		return "0001_bulbasaur"
	if types.has("grass") or types.has("bug") or types.has("ice") or types.has("steel"):
		return "0004_charmander"
	return "0007_squirtle"


func _verify(slug: String, defender_slug: String, move_id: String) -> void:
	print("verify: begin %s %s" % [slug, move_id])
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var attacker_instance: PokemonInstanceResource = _instance(slug, [move_id], PokemonInstanceResource.Team.PLAYER)
	var defender_instance: PokemonInstanceResource = _instance(defender_slug, ["tackle"], PokemonInstanceResource.Team.ENEMY)
	var definition := SkirmishDefinitionResource.new()
	definition.skirmish_id = "verify_%s_%s" % [slug, move_id]
	definition.map = load(TEST_ARENA_MAP_PATH)
	definition.seed = 31
	definition.player_team = [attacker_instance]
	definition.enemy_team = [defender_instance]
	definition.control_mode = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER
	definition.generation_metadata = {"player_spawn_order": [0], "enemy_spawn_order": [0]}
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	level.presentation_runner.immediate_mode = not windowed
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	await process_frame
	await process_frame
	var attacker: TacticsPawn = level.player.get_child(0)
	var defender: TacticsPawn = level.opponent.get_child(0)
	var move: PokemonMoveResource = attacker.stats.move_slots[0]
	var distance: int = 2 if (move.tactical_range_kind in [PokemonMoveResource.TacticalRangeKind.LINE, PokemonMoveResource.TacticalRangeKind.PROJECTILE] and move.tactical_range_value >= 2) else 1
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	var attacker_key: Vector3i = Targeting._tile_key(attacker.get_tile())
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
	var result: Dictionary = {
		"species": slug,
		"move": move_id,
		"type": move.type,
		"category": move.category,
		"range_kind": move.tactical_range_kind,
		"range_value": move.tactical_range_value,
		"accuracy": move.accuracy,
		"families": _families(move),
		"distance": distance,
	}
	if target_tile == null:
		result["verdict"] = "no_lane"
		results.append(result)
		loader.unload_current()
		loader.queue_free()
		return
	_settle_on_tile(defender, target_tile)
	attacker.serv.movement.look_at_direction_8(attacker, Vector3(float(facing.x), 0.0, float(facing.z)))
	defender.serv.movement.look_at_direction_8(defender, Vector3(float(-facing.x), 0.0, float(-facing.z)))
	var camera: Camera3D = null
	var light: DirectionalLight3D = null
	if windowed:
		camera = Camera3D.new()
		root.add_child(camera)
		var mid: Vector3 = (attacker.global_position + defender.global_position) * 0.5
		var span: float = maxf(2.5, attacker.global_position.distance_to(defender.global_position) + 2.5)
		var side: Vector3 = Vector3(float(facing.z), 0.0, float(-facing.x))
		camera.global_position = mid + side * span * 1.1 + Vector3.UP * (span * 0.7)
		camera.look_at(mid + Vector3.UP * 0.5, Vector3.UP)
		camera.current = true
		light = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
		root.add_child(light)
		await process_frame
	var units: Array[TacticsPawn] = [attacker, defender]
	var legal: Array[TacticsPawn] = Targeting.legal_targets_for_move(attacker, move, units)
	var target: TacticsPawn = defender if legal.has(defender) else (attacker if legal.has(attacker) or move.can_target_self() else defender)
	result["declared_target"] = "self" if target == attacker else "foe"
	var start: int = level.battle_log.events.size()
	var defender_hp_before: int = defender.stats.curr_health
	var attacker_hp_before: int = attacker.stats.curr_health
	var resolver := BattleActionResolver.new()
	var executed: bool = resolver.execute(attacker, target, 0, level)
	result["executed"] = executed
	var frames: int = 0
	var elapsed: float = 0.0
	var shot_index: int = 0
	while (level.presentation_runner.is_busy() or (windowed and shot_index < SHOT_TIMES.size())) and frames < 600:
		await process_frame
		frames += 1
		elapsed += 1.0 / 60.0
		if windowed and shot_index < SHOT_TIMES.size() and elapsed >= SHOT_TIMES[shot_index]:
			await _snap("%s_%s_t%02d" % [slug.substr(5), move_id, int(SHOT_TIMES[shot_index] * 100.0)])
			shot_index += 1
		if not level.presentation_runner.is_busy() and (not windowed or shot_index >= SHOT_TIMES.size()):
			break
	await process_frame
	var after_move: int = level.battle_log.events.size()
	result["frames"] = frames
	result["vfx_active_after"] = level.vfx_player.active_count()
	result["weather_after_move"] = level.current_weather()
	level._on_turn_started(_unit_for(level, defender))
	level._on_turn_started(_unit_for(level, attacker))
	level._on_round_started()
	level._on_turn_started(_unit_for(level, defender))
	await process_frame
	var events: Array[Dictionary] = []
	for i in range(start, level.battle_log.events.size()):
		events.append(_sanitize(level.battle_log.events[i], attacker, defender, i < after_move))
	result["defender_hp"] = [defender_hp_before, defender.stats.curr_health]
	result["attacker_pos"] = str(attacker.global_position)
	result["defender_pos"] = str(defender.global_position)
	result["attacker_hp"] = [attacker_hp_before, attacker.stats.curr_health]
	result["defender_statuses"] = defender.stats.battle_statuses.keys()
	result["attacker_statuses"] = attacker.stats.battle_statuses.keys()
	result["weather_after_ticks"] = level.current_weather()
	result["events"] = events
	_assess(result, events)
	results.append(result)
	print("verify: %s %s verdict=%s hp=%s->%s events=%s" % [slug, move_id, result["verdict"], defender_hp_before, defender.stats.curr_health, JSON.stringify(result["event_counts"])])
	if camera != null:
		camera.queue_free()
	if light != null:
		light.queue_free()
	loader.unload_current()
	loader.queue_free()
	await process_frame


func _assess(result: Dictionary, events: Array[Dictionary]) -> void:
	var counts: Dictionary = {}
	var kinds: Dictionary = {}
	for event in events:
		var kind: String = String(event.get("kind", ""))
		counts[kind] = int(counts.get(kind, 0)) + 1
		kinds[kind] = true
	result["event_counts"] = counts
	var families: Array = result["families"]
	var expected: Array[String] = []
	var achieved: Array[String] = []
	var missing: Array[String] = []
	var damaging: bool = int(result["category"]) != PokemonMoveResource.CATEGORY_STATUS
	if damaging:
		expected.append("damage")
	for family in families:
		var f: String = String(family)
		if f == "tactical_noop":
			continue
		if DAMAGE_FAMILIES.has(f):
			if not expected.has("damage"):
				expected.append("damage")
		elif not expected.has(f):
			expected.append(f)
	var hp_pair: Array = result["defender_hp"]
	var self_pair: Array = result["attacker_hp"]
	for f in expected:
		var ok: bool = false
		match f:
			"damage":
				ok = kinds.has("damage_dealt") or kinds.has("damage_prevented")
			"status":
				ok = kinds.has("status_applied") or kinds.has("status_blocked") or kinds.has("effect_blocked") or kinds.has("effect_missed")
			"stat_stage", "weather_stat_stage":
				ok = kinds.has("stat_stage_changed") or kinds.has("stat_stage_blocked") or kinds.has("effect_missed")
			"heal", "drain":
				ok = kinds.has("healed") or kinds.has("heal_blocked") or int(self_pair[1]) > int(self_pair[0])
			"recoil":
				ok = int(self_pair[1]) < int(self_pair[0])
			"field_condition":
				ok = kinds.has("field_condition_applied")
			"status_remove", "cure_statuses":
				ok = true
			"ability_change":
				for kind in kinds.keys():
					if String(kind).contains("ability") or String(kind).contains("intrinsic"):
						ok = true
			"pp_damage":
				ok = kinds.has("pp_reduced")
			_:
				ok = false
		if ok:
			achieved.append(f)
		else:
			missing.append(f)
	result["expected"] = expected
	result["achieved"] = achieved
	result["missing"] = missing
	var verdict: String = "ok"
	if not bool(result.get("executed", false)) or kinds.has("move_rejected") or kinds.has("no_usable_move"):
		verdict = "rejected"
	elif (kinds.has("effect_unsupported") or kinds.has("effect_deferred")) and not (families.has("tactical_noop") and missing.is_empty()):
		verdict = "unsupported"
	elif kinds.has("miss") and achieved.is_empty():
		verdict = "miss"
	elif expected.is_empty():
		verdict = "unverified"
	elif missing.is_empty():
		verdict = "ok"
	elif achieved.is_empty():
		verdict = "no_effect"
	else:
		verdict = "partial"
	result["verdict"] = verdict


func _sanitize(event: Dictionary, attacker: TacticsPawn, defender: TacticsPawn, during_move: bool) -> Dictionary:
	var out: Dictionary = {"phase": "move" if during_move else "ticks"}
	for key in event.keys():
		var value: Variant = event[key]
		if value is TacticsPawn:
			out[key] = "attacker" if value == attacker else ("defender" if value == defender else String(value.name))
		elif value is Object:
			out[key] = String(value.get("name")) if value.get("name") != null else "<object>"
		elif value is Array or value is Dictionary:
			out[key] = JSON.stringify(value).left(200)
		else:
			out[key] = value
	return out


func _families(move: PokemonMoveResource) -> Array:
	var out: Array = []
	for record in move.effect_records:
		var family: String = String(record.get("family", ""))
		if not family.is_empty() and not out.has(family):
			out.append(family)
	return out


func _unit_for(level: TacticsLevel, pawn: TacticsPawn) -> BattleUnit:
	for unit in level.battle_units:
		if unit.pawn == pawn:
			return unit
	return null


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		return
	image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	image.save_png(ProjectSettings.globalize_path("%s/frames/%s.png" % [OUTPUT_DIR, label]))
	frames_written += 1


func _instance(slug: String, move_ids: Array, team: int) -> PokemonInstanceResource:
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
	instance.loadout_locked = true
	return instance


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
