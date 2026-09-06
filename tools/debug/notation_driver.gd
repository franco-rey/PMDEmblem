class_name NotationDriver
extends RefCounted

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const MAX_WAIT_FRAMES: int = 900

var tree: SceneTree = null
var main: Node = null
var level: TacticsLevel = null
var log_lines: Array[String] = []
var own_failures: int = 0
var applier: BattleCommandApplier = null
var last_notation: String = ""

var failures: int:
	get:
		return own_failures + (applier.failures if applier != null else 0)

var current_unit: TacticsPawn:
	get:
		return applier.current_unit if applier != null else null
	set(value):
		if applier != null:
			applier.current_unit = value


func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree
	applier = BattleCommandApplier.new(tree, null, log_lines)


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
			NotationParser.KIND_TERRAIN, NotationParser.KIND_UNIT, NotationParser.KIND_RESULT, NotationParser.KIND_FINAL, NotationParser.KIND_COMMENT, NotationParser.KIND_BOARD, NotationParser.KIND_BRANCH, NotationParser.KIND_PRESENT:
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


func _run_command(command: String) -> void:
	await applier.apply(command)


func _launch(code: String) -> bool:
	var stale: bool = false
	for child in tree.root.get_children():
		if child.has_method("unload_level"):
			child.unload_level()
			tree.root.remove_child(child)
			child.queue_free()
			stale = true
	if stale:
		await tree.physics_frame
		await tree.physics_frame
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
	applier.level = level
	if level == null:
		_fail("level did not launch: %s" % String(lobby.status_label.text))
		return false
	level.process_mode = Node.PROCESS_MODE_ALWAYS
	last_notation = ""
	var launched: TacticsLevel = level
	launched.battle_ended.connect(func(_result_code: int) -> void:
		if is_instance_valid(launched):
			last_notation = launched.notation.text())
	var frames: int = 0
	while not level._scheduler_started and frames < MAX_WAIT_FRAMES:
		await tree.physics_frame
		frames += 1
	if not level._scheduler_started:
		_fail("scheduler did not start")
		return false
	_log("launched %s (%d vs %d) grid %dx%d" % [level.battle_label, level.player.get_child_count(), level.opponent.get_child_count(), level.notation.columns, level.notation.rows])
	return true


func _move(pawn: TacticsPawn, tile_label: String) -> void:
	await applier.apply_move(pawn, tile_label)


func _attack(pawn: TacticsPawn, slot: int, target: TacticsPawn) -> void:
	await applier.apply_attack(pawn, slot, target)


func _end_turn(pawn: TacticsPawn) -> void:
	await applier.apply_end_turn(pawn)


func _use_item(pawn: TacticsPawn, item_id: String) -> void:
	await applier.apply_use_item(pawn, item_id)


func _throw_item(pawn: TacticsPawn, item_id: String, direction: Vector3i) -> void:
	await applier.apply_throw_item(pawn, item_id, direction)


func _run_intent(pawn: TacticsPawn, intent: BattleActionIntent, label: String) -> void:
	await applier.apply_intent(pawn, intent, label)


func _replay_travel(verb: String, args: PackedStringArray, command: String) -> void:
	await applier.apply_travel(verb, args, command)


func _wait_for_turn(pawn: TacticsPawn) -> bool:
	return await applier.wait_for_turn(pawn)


func _wait_turn_change(pawn: TacticsPawn) -> void:
	await applier.wait_turn_change(pawn)


func _settle(pawn: TacticsPawn) -> void:
	await applier.settle(pawn)


func _slot_for_move(pawn: TacticsPawn, move_id: String) -> int:
	return applier.slot_for_move(pawn, move_id)


func _unit_for_ref(ref: String) -> TacticsPawn:
	return applier.unit_for_ref(ref)


func _tile_for_label(label: String) -> TacticsTile:
	return applier.tile_for_label(label)


func _log(text: String) -> void:
	applier.log_line(text)


func _fail(text: String) -> void:
	own_failures += 1
	log_lines.append("FAIL " + text)
	push_error("driver: %s" % text)


func _result() -> Dictionary:
	return {"failures": failures, "log": log_lines, "notation": level.notation.text() if _level_alive() else last_notation, "level": level if _level_alive() else null}
