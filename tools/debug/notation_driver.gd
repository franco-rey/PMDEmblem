class_name NotationDriver
extends RefCounted

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const MAX_WAIT_FRAMES: int = 900

var tree: SceneTree = null
var main: Node = null
var level: TacticsLevel = null
var log_lines: Array[String] = []
var failures: int = 0
var current_unit: TacticsPawn = null


func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree


func run_script(lines: Array) -> Dictionary:
	var code: String = ""
	var commands: Array[String] = []
	for raw in lines:
		var line: String = String(raw).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("code "):
			code = line.substr(5).strip_edges()
			continue
		var parsed: Dictionary = NotationParser.parse(line)
		match String(parsed.get("kind", "")):
			NotationParser.KIND_TAG:
				if String(parsed.get("key", "")) == "Code":
					code = String(parsed.get("value", ""))
			NotationParser.KIND_TERRAIN, NotationParser.KIND_UNIT, NotationParser.KIND_RESULT, NotationParser.KIND_FINAL, NotationParser.KIND_COMMENT:
				pass
			_:
				commands.append(line)
	if code.is_empty():
		_fail("script needs a 'code ...' line or a [Code] tag")
		return _result()
	if not await _launch(code):
		return _result()
	for command in commands:
		await _run_command(command)
		if not _level_alive() or level.battle_finished:
			break
	if _level_alive():
		level.notation.save()
	return _result()


func _level_alive() -> bool:
	return level != null and is_instance_valid(level)


func _launch(code: String) -> bool:
	main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	main.get_node("UI/MapSelector/SkirmishMenu/CustomToggleButton").emit_signal("pressed")
	await tree.process_frame
	await tree.process_frame
	var lobby: SkirmishLobby = main.get_node("UI/SkirmishLobby")
	var seed_input: LineEdit = lobby.find_child("SeedInput", true, false)
	seed_input.text = code
	seed_input.text_changed.emit(code)
	await tree.process_frame
	var launch: Button = lobby.find_child("LaunchButton", true, false)
	if launch.disabled:
		_fail("launch disabled for code: %s" % String(lobby.status_label.text))
		return false
	launch.emit_signal("pressed")
	await tree.process_frame
	await tree.process_frame
	level = main.level_instance
	if level == null:
		_fail("level did not launch: %s" % String(lobby.status_label.text))
		return false
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	var frames: int = 0
	while not level._scheduler_started and frames < MAX_WAIT_FRAMES:
		await tree.physics_frame
		frames += 1
	if not level._scheduler_started:
		_fail("scheduler did not start")
		return false
	_log("launched %s (%d vs %d) grid %dx%d" % [level.battle_label, level.player.get_child_count(), level.opponent.get_child_count(), level.notation.columns, level.notation.rows])
	return true


func _run_command(command: String) -> void:
	var parsed: Dictionary = NotationParser.parse(command)
	if String(parsed.get("kind", "")) == NotationParser.KIND_TURN:
		current_unit = _unit_for_ref(String(parsed.get("unit", "")))
		if current_unit == null:
			_fail("unknown unit in turn header: %s" % command)
		return
	if String(parsed.get("kind", "")) != NotationParser.KIND_ACTION:
		return
	var verb: String = String(parsed.get("verb", ""))
	var args: PackedStringArray = parsed.get("args", PackedStringArray())
	match verb:
		"mv":
			var pawn: TacticsPawn = _require_current(command)
			if pawn == null or args.is_empty():
				return
			var hops: PackedStringArray = NotationParser.split_move(args[0])
			if not await _wait_for_turn(pawn):
				return
			await _move(pawn, hops[hops.size() - 1])
		"atk":
			var pawn: TacticsPawn = _require_current(command)
			if pawn == null or args.size() < 3:
				return
			var slot_index: int = int(args[0]) - 1 if args[0].is_valid_int() else _slot_for_move(pawn, args[1])
			var target: TacticsPawn = pawn if args[2] == "self" or args[2] == "-" else _unit_for_ref(args[2])
			if target == null:
				_fail("unknown target in %s" % command)
				return
			if not await _wait_for_turn(pawn):
				return
			await _attack(pawn, slot_index, target)
		"item":
			var pawn: TacticsPawn = _require_current(command)
			if pawn == null or args.size() < 3:
				return
			if args[0] == "use":
				if not await _wait_for_turn(pawn):
					return
				await _use_item(pawn, args[2])
			elif args[0] == "throw":
				var direction: Vector3i = Vector3i.ZERO
				if args.size() > 3:
					var parts: PackedStringArray = args[3].split(",")
					if parts.size() >= 2:
						direction = Vector3i(int(parts[0]), 0, int(parts[1]))
				if not await _wait_for_turn(pawn):
					return
				await _throw_item(pawn, args[2], direction)
		"end":
			var pawn: TacticsPawn = current_unit if args.is_empty() else _unit_for_ref(args[0])
			if pawn == null:
				_fail("end needs a current unit: %s" % command)
				return
			await _end_turn(pawn)
		"move":
			var pawn: TacticsPawn = _unit_for_ref(args[0]) if not args.is_empty() else null
			if pawn == null or args.size() < 2:
				_fail("move needs a unit and a tile: %s" % command)
				return
			if not await _wait_for_turn(pawn):
				return
			await _move(pawn, args[1])
		"attack":
			var pawn: TacticsPawn = _unit_for_ref(args[0]) if not args.is_empty() else null
			if pawn == null or args.size() < 3:
				_fail("attack needs unit, slot and target: %s" % command)
				return
			var target: TacticsPawn = pawn if args[2].to_lower() == "self" else _unit_for_ref(args[2])
			if target == null:
				_fail("unknown target in %s" % command)
				return
			var slot_index: int = int(args[1]) - 1
			var move: PokemonMoveResource = pawn.stats.move_slots[slot_index] if pawn.stats != null and slot_index >= 0 and slot_index < pawn.stats.move_slots.size() else null
			if move != null and not move.can_target_foes() and move.can_target_self():
				target = pawn
			if not await _wait_for_turn(pawn):
				return
			await _attack(pawn, slot_index, target)
		"wait":
			var pawn: TacticsPawn = _unit_for_ref(args[0]) if not args.is_empty() else null
			if pawn == null:
				_fail("wait needs a unit: %s" % command)
				return
			await _end_turn(pawn)
		"rounds":
			var count: int = int(args[0]) if not args.is_empty() else 1
			for i in range(count):
				level._on_round_started()
			_log("advanced %d round(s)" % count)
		_:
			if not ["hit", "miss", "nfx", "st", "tick", "stat", "heal", "wx", "fld", "hz", "push", "ko", "skip", "rej", "held"].has(verb):
				_fail("unknown command: %s" % command)


func _require_current(command: String) -> TacticsPawn:
	if current_unit == null or not is_instance_valid(current_unit):
		_fail("no turn header before: %s" % command)
		return null
	return current_unit


func _slot_for_move(pawn: TacticsPawn, move_id: String) -> int:
	if pawn.stats == null:
		return -1
	for i in range(pawn.stats.move_slots.size()):
		var move: PokemonMoveResource = pawn.stats.move_slots[i]
		if move != null and move.move_id == move_id:
			return i
	return -1


func _end_turn(pawn: TacticsPawn) -> void:
	var settle: int = 0
	while settle < 30 and _level_alive() and level.is_presentation_busy():
		await tree.physics_frame
		settle += 1
	var active: BattleUnit = level.scheduler.get_active_unit() if _level_alive() else null
	if active == null or active.pawn != pawn:
		_log("%s turn already over" % level.notation.unit_ref(pawn))
		return
	if not await _wait_for_turn(pawn):
		return
	pawn.end_pawn_turn()
	level.participant.res.stage = level.participant.res.STAGE_SELECT_PAWN
	_log("%s ends turn" % level.notation.unit_ref(pawn))
	await _wait_turn_change(pawn)


func _move(pawn: TacticsPawn, tile_label: String) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	participant.curr_pawn = pawn
	participant.stage = participant.STAGE_SHOW_MOVEMENTS
	await tree.physics_frame
	await tree.physics_frame
	var tile: TacticsTile = _tile_for_label(tile_label)
	if tile == null:
		_fail("no tile %s" % tile_label)
		return
	if not tile.reachable:
		_fail("%s cannot reach %s" % [level.notation.unit_ref(pawn), tile_label])
		participant.stage = participant.STAGE_SHOW_ACTIONS
		return
	pawn.res.pathfinding_tilestack = level.arena.get_pathfinding_tilestack(tile)
	participant.stage = participant.STAGE_MOVE_PAWN
	var frames: int = 0
	while frames < MAX_WAIT_FRAMES and (participant.stage == participant.STAGE_MOVE_PAWN or pawn.res.is_moving or not pawn.res.pathfinding_tilestack.is_empty()):
		await tree.physics_frame
		frames += 1
	if _level_alive() and is_instance_valid(pawn):
		_log("%s moved to %s in %d frames" % [level.notation.unit_name(pawn), level.notation.label_for_pawn(pawn), frames])


func _attack(pawn: TacticsPawn, slot: int, target: TacticsPawn) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	var hp_before: int = target.stats.curr_health
	pawn.res.selected_move_index = slot
	participant.curr_pawn = pawn
	participant.attackable_pawn = target
	participant.display_opponent_stats = true
	participant.stage = participant.STAGE_ATTACK
	await tree.physics_frame
	var frames: int = 0
	while frames < MAX_WAIT_FRAMES and _level_alive() and is_instance_valid(pawn) and (participant.stage == participant.STAGE_ATTACK or level.is_presentation_busy() or pawn.res.presentation_locked):
		await tree.physics_frame
		frames += 1
	for i in range(3):
		await tree.physics_frame
	if _level_alive() and is_instance_valid(target) and target.stats != null:
		_log("%s used slot %d on %s: HP %d -> %d (%d frames)" % [level.notation.unit_name(pawn), slot + 1, level.notation.unit_name(target), hp_before, target.stats.curr_health, frames])
	else:
		_log("slot %d used; the battle ended (%d frames)" % [slot + 1, frames])


func _use_item(pawn: TacticsPawn, item_id: String) -> void:
	await _run_intent(pawn, BattleActionIntent.use_item(pawn, item_id), "use %s" % item_id)


func _throw_item(pawn: TacticsPawn, item_id: String, direction: Vector3i) -> void:
	await _run_intent(pawn, BattleActionIntent.throw_item(pawn, item_id, direction), "throw %s %s" % [item_id, str(direction)])


func _run_intent(pawn: TacticsPawn, intent: BattleActionIntent, label: String) -> void:
	var participant: TacticsParticipantResource = level.participant.res
	participant.curr_pawn = pawn
	participant.pending_intent = intent
	participant.stage = participant.STAGE_ITEM_ACTION
	await tree.physics_frame
	var frames: int = 0
	while frames < MAX_WAIT_FRAMES and _level_alive() and is_instance_valid(pawn) and (participant.stage == participant.STAGE_ITEM_ACTION or level.is_presentation_busy() or pawn.res.presentation_locked):
		await tree.physics_frame
		frames += 1
	for i in range(3):
		await tree.physics_frame
	_log("%s item %s (%d frames)" % [level.notation.unit_name(pawn), label, frames])


func _wait_for_turn(pawn: TacticsPawn) -> bool:
	var frames: int = 0
	var auto_ended: Dictionary = {}
	while frames < MAX_WAIT_FRAMES:
		if not _level_alive():
			_fail("battle ended before %s could act" % str(pawn))
			return false
		var active: BattleUnit = level.scheduler.get_active_unit()
		if active != null and active.pawn == pawn and not level.is_presentation_busy():
			return true
		if level.battle_finished:
			_fail("battle ended before %s could act" % level.notation.unit_name(pawn))
			return false
		if active != null and active.pawn != pawn and not level.is_presentation_busy() and active.control_type == PokemonInstanceResource.ControlType.PLAYER and not auto_ended.has(active.pawn) and frames > 5:
			auto_ended[active.pawn] = true
			_log("auto-end %s (waiting for %s)" % [level.notation.unit_ref(active.pawn), level.notation.unit_name(pawn)])
			active.pawn.end_pawn_turn()
			level.participant.res.stage = level.participant.res.STAGE_SELECT_PAWN
			await _wait_turn_change(active.pawn)
			auto_ended.clear()
		await tree.physics_frame
		frames += 1
	if _level_alive():
		_fail("timed out waiting for %s's turn (active: %s)" % [level.notation.unit_name(pawn), level.notation.unit_name(level.scheduler.get_active_unit().pawn) if level.scheduler.get_active_unit() != null else "none"])
	else:
		_fail("timed out waiting for a turn after the battle ended")
	return false


func _wait_turn_change(pawn: TacticsPawn) -> void:
	var frames: int = 0
	while frames < 240 and _level_alive() and level.scheduler.get_active_unit() != null and level.scheduler.get_active_unit().pawn == pawn:
		await tree.physics_frame
		frames += 1


func _unit_for_ref(ref: String) -> TacticsPawn:
	var key: String = ref.strip_edges()
	if NotationParser.is_unit_id(key):
		var by_id: TacticsPawn = level.notation.pawn_for_id(key)
		if by_id != null:
			return by_id
		var team: Node = level.player if key.begins_with("P") else level.opponent
		var index: int = int(key.substr(1)) - 1
		var pawns: Array[TacticsPawn] = []
		for child in team.get_children():
			if child is TacticsPawn:
				pawns.append(child)
		return pawns[index] if index >= 0 and index < pawns.size() else null
	for pawn in level.units_on_map():
		if level.notation.unit_name(pawn).to_lower() == key.to_lower():
			return pawn
	return null


func _tile_for_label(label: String) -> TacticsTile:
	var key: Vector3i = level.notation.grid.key_for_label(label)
	if key.x < 0 and key.y < 0 and key.z < 0:
		return null
	var keys: Dictionary = Targeting.arena_tile_keys(level)
	return keys.get(key, null)


func _log(text: String) -> void:
	log_lines.append(text)
	print("driver: %s" % text)


func _fail(text: String) -> void:
	failures += 1
	log_lines.append("FAIL " + text)
	push_error("driver: %s" % text)


func _result() -> Dictionary:
	return {"failures": failures, "log": log_lines, "notation": level.notation.text() if _level_alive() else "", "level": level if _level_alive() else null}
