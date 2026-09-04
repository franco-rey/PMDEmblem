class_name NotationDriver
extends RefCounted

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const MAX_WAIT_FRAMES: int = 900

var tree: SceneTree = null
var main: Node = null
var level: TacticsLevel = null
var log_lines: Array[String] = []
var failures: int = 0


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
		else:
			commands.append(line)
	if code.is_empty():
		_fail("script needs a 'code ...' line")
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
	var parts: PackedStringArray = command.split(" ", false)
	var verb: String = String(parts[0]).to_lower()
	var pawn: TacticsPawn = _unit_for_ref(String(parts[1])) if parts.size() > 1 else null
	match verb:
		"move":
			if pawn == null or parts.size() < 3:
				_fail("move needs a unit and a tile: %s" % command)
				return
			if not await _wait_for_turn(pawn):
				return
			await _move(pawn, String(parts[2]))
		"attack":
			if pawn == null or parts.size() < 4:
				_fail("attack needs unit, slot and target: %s" % command)
				return
			var target: TacticsPawn = pawn if String(parts[3]).to_lower() == "self" else _unit_for_ref(String(parts[3]))
			if target == null:
				_fail("unknown target in %s" % command)
				return
			var slot_index: int = int(String(parts[2])) - 1
			var move: PokemonMoveResource = pawn.stats.move_slots[slot_index] if pawn.stats != null and slot_index >= 0 and slot_index < pawn.stats.move_slots.size() else null
			if move != null and not move.can_target_foes() and move.can_target_self():
				target = pawn
			if not await _wait_for_turn(pawn):
				return
			await _attack(pawn, slot_index, target)
		"wait", "end":
			if pawn == null:
				_fail("%s needs a unit: %s" % [verb, command])
				return
			if not await _wait_for_turn(pawn):
				return
			pawn.end_pawn_turn()
			level.participant.res.stage = level.participant.res.STAGE_SELECT_PAWN
			_log("%s ends turn" % level.notation.unit_ref(pawn))
			await _wait_turn_change(pawn)
		"rounds":
			var count: int = int(String(parts[1])) if parts.size() > 1 else 1
			for i in range(count):
				level._on_round_started()
			_log("advanced %d round(s)" % count)
		_:
			_fail("unknown command: %s" % command)


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
	if key.length() >= 2 and (key.begins_with("P") or key.begins_with("E")) and key.substr(1).is_valid_int():
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
	var letters: String = ""
	var digits: String = ""
	for i in range(label.length()):
		var ch: String = label.substr(i, 1)
		if ch.to_upper() >= "A" and ch.to_upper() <= "Z":
			letters += ch.to_upper()
		else:
			digits += ch
	if letters.is_empty() or not digits.is_valid_int():
		return null
	var col: int = 0
	for i in range(letters.length()):
		col = col * 26 + (letters.unicode_at(i) - 64)
	col -= 1
	var key: Vector3i = level.notation.origin + Vector3i(col, 0, int(digits) - 1)
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
