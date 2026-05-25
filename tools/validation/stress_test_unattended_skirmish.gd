extends SceneTree

const CustomSkirmishBuilder = preload("res://data/modules/skirmish/custom_skirmish_builder.gd")
const SkirmishCode = preload("res://data/modules/skirmish/skirmish_code.gd")
const SkirmishControlMode = preload("res://data/modules/skirmish/skirmish_control_mode.gd")

const MANUAL_IDS: Array[String] = [
	"demo_3v3",
	"single_1v1",
	"team_3v3",
	"type_effectiveness_test",
]
const MANUAL_PATH: String = "res://data/models/skirmish/manual/%s.tres"
const DEFAULT_MAP_PATH: String = "res://data/models/maps/definitions/test_arena.tres"
const HEARTBEAT_FRAMES: int = 60
const TRACE_FRAMES: int = 30

var mode: String = "idle"
var skirmish: String = "demo_3v3"
var seed: int = 101
var team_size: int = 3
var control_mode: String = SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_CPU
var code: String = ""
var max_frames: int = 900
var stall_frames: int = 240
var trace_path: String = ""
var failures: Array[String] = []
var trace_file: FileAccess = null

var loader: SkirmishLoader = null
var level: TacticsLevel = null
var frame_index: int = 0
var series_index: int = 0
var last_progress_frame: int = 0
var last_signature: String = ""
var last_event_count: int = 0
var result_events: Array[int] = []


func _init() -> void:
	_parse_args()
	if not ["idle", "auto_skip"].has(mode):
		_fail("mode must be idle or auto_skip; got %s" % mode)
		_finish()
		return
	if team_size < 1 or team_size > 8:
		_fail("team-size must be 1-8; got %d" % team_size)
		_finish()
		return
	if not SkirmishControlMode.is_valid(control_mode):
		_fail("control-mode must be pvc, pvp, or bots; got %s" % control_mode)
		_finish()
		return
	if max_frames <= 0:
		_fail("max-frames must be > 0; got %d" % max_frames)
		_finish()
		return
	if stall_frames <= 0:
		_fail("stall-frames must be > 0; got %d" % stall_frames)
		_finish()
		return

	_open_trace()
	var definitions: Array[SkirmishDefinitionResource] = _build_definitions()
	if definitions.is_empty():
		_finish()
		return

	loader = SkirmishLoader.new()
	root.add_child(loader)
	loader.skirmish_ended.connect(func(result: int, _definition: SkirmishDefinitionResource) -> void:
		result_events.append(result)
	)
	print("stress: start mode=%s skirmish=%s seed=%d team_size=%d control_mode=%s series=%d max_frames=%d stall_frames=%d" % [
		mode,
		skirmish,
		seed,
		team_size,
		control_mode,
		definitions.size(),
		max_frames,
		stall_frames,
	])
	for i in range(definitions.size()):
		if not failures.is_empty() or frame_index >= max_frames:
			break
		series_index = i
		_load_definition(definitions[i])
		if level == null:
			break
		_trace("start")
		await _run()
		if loader != null:
			loader.unload_current()
		level = null
	_finish()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.get_slice("=", 1)
		elif arg.begins_with("--skirmish="):
			skirmish = arg.get_slice("=", 1)
		elif arg.begins_with("--seed="):
			seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--team-size="):
			team_size = int(arg.get_slice("=", 1))
		elif arg.begins_with("--control-mode="):
			control_mode = SkirmishControlMode.normalize(arg.get_slice("=", 1))
		elif arg.begins_with("--code="):
			code = arg.substr("--code=".length())
		elif arg.begins_with("--max-frames="):
			max_frames = int(arg.get_slice("=", 1))
		elif arg.begins_with("--stall-frames="):
			stall_frames = int(arg.get_slice("=", 1))
		elif arg.begins_with("--trace="):
			trace_path = arg.get_slice("=", 1)


func _build_definitions() -> Array[SkirmishDefinitionResource]:
	if not code.strip_edges().is_empty():
		var built: Dictionary = SkirmishCode.build_definitions(code, {
			"map_path": DEFAULT_MAP_PATH,
			"team_size": team_size,
			"enemy_team_size": team_size,
			"control_mode": control_mode,
		})
		if not bool(built.get("ok", false)):
			_fail("code build failed: %s" % String(built.get("error", "")))
			var empty: Array[SkirmishDefinitionResource] = []
			return empty
		var out: Array[SkirmishDefinitionResource] = []
		for entry in built.get("definitions", []):
			if entry is SkirmishDefinitionResource:
				out.append(entry as SkirmishDefinitionResource)
		return out
	var definition: SkirmishDefinitionResource = _build_definition()
	var single: Array[SkirmishDefinitionResource] = []
	if definition != null:
		single.append(definition)
	return single


func _build_definition() -> SkirmishDefinitionResource:
	if skirmish == "random":
		return _build_random_definition()
	if skirmish == "custom":
		return _build_custom_definition()
	if skirmish.begins_with("res://"):
		var definition: SkirmishDefinitionResource = load(skirmish) as SkirmishDefinitionResource
		if definition == null:
			_fail("could not load skirmish definition path %s" % skirmish)
		else:
			definition.seed = seed
			SkirmishControlMode.apply_to_definition(definition, control_mode)
		return definition
	if MANUAL_IDS.has(skirmish):
		var path: String = MANUAL_PATH % skirmish
		var definition: SkirmishDefinitionResource = load(path) as SkirmishDefinitionResource
		if definition == null:
			_fail("could not load manual skirmish %s" % path)
		else:
			definition.seed = seed
			SkirmishControlMode.apply_to_definition(definition, control_mode)
		return definition
	_fail("unknown skirmish '%s'; use a manual id, random, custom, or res:// path" % skirmish)
	return null


func _build_random_definition() -> SkirmishDefinitionResource:
	var map_path: String = _first_map_path()
	var result: Dictionary = CustomSkirmishBuilder.build_random(team_size, map_path, str(seed), control_mode)
	if not bool(result.get("ok", false)):
		_fail("random build failed: %s" % String(result.get("error", "")))
		return null
	return result.get("definition") as SkirmishDefinitionResource


func _build_custom_definition() -> SkirmishDefinitionResource:
	var roster: Array[String] = CustomSkirmishBuilder.battle_ready_roster_paths()
	if roster.size() < team_size * 2:
		_fail("custom build needs at least %d roster entries, found %d" % [team_size * 2, roster.size()])
		return null
	var players: Array[String] = []
	var enemies: Array[String] = []
	for i in range(team_size):
		players.append(roster[i])
		enemies.append(roster[i + team_size])
	var result: Dictionary = CustomSkirmishBuilder.build(players, enemies, _first_map_path(), str(seed), control_mode)
	if not bool(result.get("ok", false)):
		_fail("custom build failed: %s" % String(result.get("error", "")))
		return null
	return result.get("definition") as SkirmishDefinitionResource


func _first_map_path() -> String:
	var maps: Array[String] = CustomSkirmishBuilder.map_paths()
	if maps.has(DEFAULT_MAP_PATH):
		return DEFAULT_MAP_PATH
	if maps.is_empty():
		_fail("no map definitions available")
		return ""
	return maps[0]


func _load_definition(definition: SkirmishDefinitionResource) -> void:
	last_progress_frame = frame_index
	last_signature = ""
	last_event_count = 0
	result_events.clear()
	control_mode = definition.control_mode if definition != null else control_mode
	level = loader.load_skirmish(definition, root)
	if level == null:
		_fail("loader returned null level for %s" % definition.skirmish_id)


func _run() -> void:
	while frame_index < max_frames and failures.is_empty():
		await physics_frame
		frame_index += 1
		if level == null or not is_instance_valid(level):
			_fail("level became invalid")
			break
		if mode == "auto_skip":
			_auto_skip_player_turn()
		_record_progress()
		if frame_index % TRACE_FRAMES == 0:
			_trace("frame")
		if frame_index % HEARTBEAT_FRAMES == 0:
			_print_heartbeat()
		if _should_fail_for_stall():
			_fail("stall detected: no progress for %d frames; snapshot=%s" % [
				frame_index - last_progress_frame,
				_snapshot_summary(),
			])
			_trace("stall")
			break
		if level.battle_finished:
			print("stress: battle_finished at frame=%d results=%s" % [frame_index, str(result_events)])
			_trace("battle_finished")
			break
	if failures.is_empty() and frame_index >= max_frames:
		print("stress: reached max_frames=%d without stall" % max_frames)
		_trace("max_frames")


func _auto_skip_player_turn() -> void:
	if level == null or level.scheduler == null:
		return
	var unit: BattleUnit = level.scheduler.get_active_unit()
	if unit == null:
		return
	if unit.control_type != PokemonInstanceResource.ControlType.PLAYER:
		return
	if unit.pawn == null or not unit.pawn.is_alive():
		level.scheduler.complete_active_unit()
		return
	unit.pawn.end_pawn_turn()
	level.participant.res.stage = level.participant.res.STAGE_SELECT_PAWN
	level.scheduler.complete_active_unit()


func _record_progress() -> void:
	var event_count: int = level.battle_log.events.size() if level != null and level.battle_log != null else 0
	var signature: String = _progress_signature()
	if signature != last_signature or event_count != last_event_count:
		last_signature = signature
		last_event_count = event_count
		last_progress_frame = frame_index


func _should_fail_for_stall() -> bool:
	if level == null or level.battle_finished:
		return false
	if frame_index - last_progress_frame < stall_frames:
		return false
	if mode == "idle":
		var unit: BattleUnit = level.scheduler.get_active_unit() if level.scheduler != null else null
		if unit != null and unit.control_type == PokemonInstanceResource.ControlType.PLAYER:
			return false
	return true


func _progress_signature() -> String:
	if level == null:
		return "no-level"
	var unit: BattleUnit = level.scheduler.get_active_unit() if level.scheduler != null else null
	var active_name: String = _unit_label(unit)
	var stage: int = level.participant.res.stage if level.participant != null else -1
	var current: TacticsPawn = level.participant.res.curr_pawn if level.participant != null else null
	var current_name: String = _pawn_label(current)
	var path_size: int = current.res.pathfinding_tilestack.size() if current != null else -1
	var pos: Vector3 = current.global_position if current != null else Vector3.ZERO
	var hp: String = _hp_signature()
	return "%s|stage=%d|curr=%s|path=%d|pos=%.3f,%.3f,%.3f|hp=%s|finished=%s" % [
		active_name,
		stage,
		current_name,
		path_size,
		pos.x,
		pos.y,
		pos.z,
		hp,
		str(level.battle_finished),
	]


func _hp_signature() -> String:
	if level == null:
		return ""
	var out: Array[String] = []
	for parent in [level.player, level.opponent]:
		if parent == null:
			continue
		for child in parent.get_children():
			if child is TacticsPawn:
				var pawn: TacticsPawn = child as TacticsPawn
				var hp: int = pawn.stats.curr_health if pawn.stats != null else -1
				out.append("%s:%d" % [_pawn_label(pawn), hp])
	return ",".join(out)


func _snapshot() -> Dictionary:
	var unit: BattleUnit = level.scheduler.get_active_unit() if level != null and level.scheduler != null else null
	var current: TacticsPawn = level.participant.res.curr_pawn if level != null and level.participant != null else null
	var pos: Vector3 = current.global_position if current != null else Vector3.ZERO
	return {
		"frame": frame_index,
		"mode": mode,
		"skirmish": skirmish,
		"seed": seed,
		"team_size": team_size,
		"control_mode": control_mode,
		"series_index": series_index,
		"active_unit": _unit_label(unit),
		"active_team": unit.team if unit != null else null,
		"active_control": unit.control_type if unit != null else null,
		"active_control_type": unit.control_type if unit != null else null,
		"participant_stage": level.participant.res.stage if level != null and level.participant != null else null,
		"current_pawn": _pawn_label(current),
		"path_stack_size": current.res.pathfinding_tilestack.size() if current != null else null,
		"current_position": [pos.x, pos.y, pos.z],
		"battle_finished": level.battle_finished if level != null else null,
		"battle_events": level.battle_log.events.size() if level != null and level.battle_log != null else null,
		"recent_events": _recent_events(6),
		"upcoming": _upcoming_units(),
	}


func _snapshot_summary() -> String:
	var data: Dictionary = _snapshot()
	return "frame=%s active=%s stage=%s current=%s path=%s events=%s finished=%s" % [
		str(data.get("frame")),
		str(data.get("active_unit")),
		str(data.get("participant_stage")),
		str(data.get("current_pawn")),
		str(data.get("path_stack_size")),
		str(data.get("battle_events")),
		str(data.get("battle_finished")),
	]


func _recent_events(limit: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if level == null or level.battle_log == null:
		return out
	var events: Array = level.battle_log.events
	var start: int = maxi(0, events.size() - limit)
	for i in range(start, events.size()):
		if events[i] is Dictionary:
			out.append(_sanitize_event(events[i] as Dictionary))
	return out


func _sanitize_event(event: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in event.keys():
		var value: Variant = event[key]
		if value is TacticsPawn:
			out[key] = _pawn_label(value as TacticsPawn)
		elif value is Node:
			out[key] = (value as Node).name
		else:
			out[key] = value
	return out


func _upcoming_units() -> Array[String]:
	var out: Array[String] = []
	if level == null or level.scheduler == null:
		return out
	for unit in level.scheduler.peek_upcoming(8):
		out.append(_unit_label(unit))
	return out


func _unit_label(unit: BattleUnit) -> String:
	if unit == null:
		return ""
	return "%s#%d/t%d/c%d" % [
		_pawn_label(unit.pawn),
		unit.insertion_order,
		unit.team,
		unit.control_type,
	]


func _pawn_label(pawn: TacticsPawn) -> String:
	if pawn == null:
		return ""
	if pawn.stats != null and not pawn.stats.species_name.is_empty():
		return pawn.stats.species_name
	return pawn.name


func _print_heartbeat() -> void:
	print("stress: heartbeat %s" % _snapshot_summary())


func _open_trace() -> void:
	if trace_path.is_empty():
		return
	_ensure_parent_dir(trace_path)
	trace_file = FileAccess.open(trace_path, FileAccess.WRITE)
	if trace_file == null:
		_fail("could not open trace path %s" % trace_path)


func _ensure_parent_dir(path: String) -> void:
	var dir_path: String = path.get_base_dir()
	if dir_path.is_empty():
		return
	if dir_path.begins_with("res://") or dir_path.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	elif dir_path.begins_with("/"):
		DirAccess.make_dir_recursive_absolute(dir_path)


func _trace(kind: String) -> void:
	if trace_file == null:
		return
	var data: Dictionary = _snapshot()
	data["kind"] = kind
	trace_file.store_line(JSON.stringify(data))
	trace_file.flush()


func _fail(message: String) -> void:
	failures.append(message)
	push_error("stress: fail - %s" % message)


func _finish() -> void:
	if trace_file != null:
		trace_file.close()
	if loader != null:
		loader.unload_current()
		loader.queue_free()
	if failures.is_empty():
		print("stress: clean")
		quit(0)
	else:
		for failure in failures:
			push_error("stress: failure: %s" % failure)
		quit(1)
