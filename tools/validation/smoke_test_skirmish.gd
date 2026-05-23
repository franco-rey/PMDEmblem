extends SceneTree
## Headless smoke test for M4 manual skirmishes.
##
##   godot --headless --path <project> --script tools/validation/smoke_test_skirmish.gd -- --skirmish=single_1v1

const MANUAL_IDS: Array[String] = [
	"demo_3v3",
	"single_1v1",
	"team_3v3",
	"type_effectiveness_test",
]
const MANUAL_PATH: String = "res://data/models/skirmish/manual/%s.tres"
const FRAMES_TO_RUN: int = 10
const SPAWN_TOLERANCE: float = 0.2

var failures: int = 0


func _init() -> void:
	var ids: Array[String] = _requested_skirmishes()
	for id in ids:
		await _check_skirmish(id)
	if ids.has("single_1v1"):
		await _check_single_1v1_determinism()

	if failures > 0:
		push_error("smoke: skirmish failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: skirmish clean (%s)" % ", ".join(ids))
		quit(0)


func _requested_skirmishes() -> Array[String]:
	var out: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--skirmish="):
			out.append(arg.get_slice("=", 1))
	if out.is_empty():
		return MANUAL_IDS.duplicate()
	return out


func _check_skirmish(id: String) -> void:
	var definition: SkirmishDefinitionResource = _load_definition(id)
	if definition == null:
		return
	var loaded: Dictionary = _load_level(definition)
	var loader: SkirmishLoader = loaded.get("loader") as SkirmishLoader
	var level: TacticsLevel = loaded.get("level") as TacticsLevel
	if level == null:
		_cleanup(loader)
		return

	var expected_count: int = definition.player_team.size() + definition.enemy_team.size()
	_assert_true(_count_pawns(level) == expected_count, "%s spawned %d pawn(s)" % [id, expected_count])
	_assert_true(level.battle_seed == definition.seed, "%s injected seed %d" % [id, definition.seed])
	_audit_team(level.get_node("TacticsParticipant/TacticsPlayer"), definition.player_team, "%s player" % id)
	_audit_team(level.get_node("TacticsParticipant/TacticsOpponent"), definition.enemy_team, "%s enemy" % id)
	_audit_spawn_positions(level, "SpawnPlayer", level.get_node("TacticsParticipant/TacticsPlayer"), definition.player_team.size(), id)
	_audit_spawn_positions(level, "SpawnEnemy", level.get_node("TacticsParticipant/TacticsOpponent"), definition.enemy_team.size(), id)

	var first_positions: Array[String] = _position_signature(level)
	await _run_frames(FRAMES_TO_RUN)
	_assert_true(level.battle_units.size() == expected_count, "%s built %d battle unit(s)" % [id, expected_count])
	_cleanup(loader)

	var reloaded: Dictionary = _load_level(definition)
	var reloaded_loader: SkirmishLoader = reloaded.get("loader") as SkirmishLoader
	var reloaded_level: TacticsLevel = reloaded.get("level") as TacticsLevel
	if reloaded_level != null:
		_assert_true(first_positions == _position_signature(reloaded_level), "%s repeats starting positions with the same seed" % id)
	_cleanup(reloaded_loader)


func _check_single_1v1_determinism() -> void:
	var definition: SkirmishDefinitionResource = _load_definition("single_1v1")
	if definition == null:
		return
	var first: Array[String] = await _drive_single_1v1_to_win(definition)
	var second: Array[String] = await _drive_single_1v1_to_win(definition)
	_assert_true(first == second, "single_1v1 fixed action sequence repeats the same battle log")


func _drive_single_1v1_to_win(definition: SkirmishDefinitionResource) -> Array[String]:
	var loaded: Dictionary = _load_level(definition)
	var loader: SkirmishLoader = loaded.get("loader") as SkirmishLoader
	var level: TacticsLevel = loaded.get("level") as TacticsLevel
	var result_events: Array[int] = []
	if loader != null:
		loader.skirmish_ended.connect(func(result: int, _definition: SkirmishDefinitionResource) -> void:
			result_events.append(result)
		)
	if level == null:
		_cleanup(loader)
		return []

	var lucario: TacticsPawn = _find_pawn_by_species(level.get_node("TacticsParticipant/TacticsPlayer"), "Lucario")
	var magmortar: TacticsPawn = _find_pawn_by_species(level.get_node("TacticsParticipant/TacticsOpponent"), "Magmortar")
	if lucario == null or magmortar == null:
		_fail("single_1v1 could not find Lucario and Magmortar")
		_cleanup(loader)
		return []

	magmortar.stats.curr_health = 10
	lucario.reset_turn()
	lucario.res.selected_move_index = 0
	for _i in range(12):
		var done: bool = lucario.attack_target_pawn(magmortar, 0.3)
		await physics_frame
		if done:
			break
	await _run_frames(6)

	_assert_true(result_events.size() == 1, "single_1v1 emits skirmish_ended once")
	if result_events.size() == 1:
		_assert_true(result_events[0] == TacticsLevel.RESULT_PLAYER_WIN, "single_1v1 returns player win")

	var signature: Array[String] = _battle_log_signature(level)
	_cleanup(loader)
	return signature


func _load_definition(id: String) -> SkirmishDefinitionResource:
	if not MANUAL_IDS.has(id):
		_fail("unknown manual skirmish id %s" % id)
		return null
	var path: String = MANUAL_PATH % id
	var definition: SkirmishDefinitionResource = load(path) as SkirmishDefinitionResource
	if definition == null:
		_fail("could not load %s" % path)
	return definition


func _load_level(definition: SkirmishDefinitionResource) -> Dictionary:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	if level == null:
		_fail("%s did not load" % definition.skirmish_id)
		return {"loader": loader, "level": null}
	return {"loader": loader, "level": level}


func _cleanup(loader: SkirmishLoader) -> void:
	if loader != null:
		loader.unload_current()
		loader.queue_free()
	await process_frame


func _run_frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _audit_team(parent: Node, expected: Array[PokemonInstanceResource], label: String) -> void:
	var pawns: Array = []
	for child in parent.get_children():
		if child is TacticsPawn:
			pawns.append(child)
	_assert_true(pawns.size() == expected.size(), "%s pawn count matches definition" % label)
	for i in range(mini(pawns.size(), expected.size())):
		var pawn: TacticsPawn = pawns[i]
		var expected_name: String = expected[i].display_name()
		_assert_true(_pawn_species_name(pawn) == expected_name, "%s slot %d is %s" % [label, i + 1, expected_name])


func _audit_spawn_positions(level: TacticsLevel, prefix: String, parent: Node, count: int, id: String) -> void:
	var anchors: Array[Node3D] = _collect_spawn_anchors(level.get_node("TacticsArena"), prefix)
	for i in range(count):
		var pawn: TacticsPawn = parent.get_child(i) as TacticsPawn
		if pawn == null or i >= anchors.size():
			_fail("%s missing %s anchor or pawn at slot %d" % [id, prefix, i + 1])
			continue
		var pawn_position: Vector3 = _local_transform_to(pawn, level).origin
		var anchor_position: Vector3 = _local_transform_to(anchors[i], level).origin
		var distance: float = pawn_position.distance_to(anchor_position)
		_assert_true(distance <= SPAWN_TOLERANCE, "%s %s slot %d honors spawn anchor" % [id, prefix, i + 1])


func _collect_spawn_anchors(arena: TacticsArena, prefix: String) -> Array[Node3D]:
	var anchors: Array[Node3D] = []
	var spawn_points: Node = arena.get_node_or_null("SpawnPoints")
	if spawn_points == null:
		_fail("%s missing SpawnPoints" % arena.name)
		return anchors
	for child in spawn_points.get_children():
		if child is Node3D and _matches_spawn_name(child.name, prefix):
			anchors.append(child as Node3D)
	anchors.sort_custom(_is_spawn_anchor_less_than)
	return anchors


func _matches_spawn_name(anchor_name: String, prefix: String) -> bool:
	if anchor_name == prefix:
		return true
	if not anchor_name.begins_with(prefix):
		return false
	var suffix: String = anchor_name.substr(prefix.length())
	return suffix.is_valid_int()


func _is_spawn_anchor_less_than(a: Node3D, b: Node3D) -> bool:
	var order_a: int = _spawn_anchor_order(a.name)
	var order_b: int = _spawn_anchor_order(b.name)
	if order_a != order_b:
		return order_a < order_b
	return a.name < b.name


func _spawn_anchor_order(anchor_name: String) -> int:
	var digits: String = ""
	for i in range(anchor_name.length()):
		var ch: String = anchor_name.substr(i, 1)
		if ch.is_valid_int():
			digits += ch
	return int(digits) if not digits.is_empty() else 0


func _count_pawns(level: TacticsLevel) -> int:
	var n: int = 0
	var participant: Node = level.get_node("TacticsParticipant")
	for team_node in participant.get_children():
		for child in team_node.get_children():
			if child is TacticsPawn:
				n += 1
	return n


func _position_signature(level: TacticsLevel) -> Array[String]:
	var out: Array[String] = []
	for team_path in ["TacticsParticipant/TacticsPlayer", "TacticsParticipant/TacticsOpponent"]:
		var parent: Node = level.get_node(team_path)
		for child in parent.get_children():
			if child is TacticsPawn:
				var p: TacticsPawn = child
				var pos: Vector3 = _local_transform_to(p, level).origin
				out.append("%s@%.3f,%.3f,%.3f" % [
					_pawn_species_name(p),
					pos.x,
					pos.y,
					pos.z,
				])
	return out


func _battle_log_signature(level: TacticsLevel) -> Array[String]:
	var out: Array[String] = []
	for event in level.battle_log.events:
		out.append("%s|%s|%s|%s|%s|%s|%s|%s" % [
			event.get("kind", ""),
			_pawn_label(event.get("attacker", null)),
			_pawn_label(event.get("defender", null)),
			_pawn_label(event.get("unit", null)),
			event.get("move_id", ""),
			event.get("amount", ""),
			event.get("remaining", ""),
			event.get("winner", ""),
		])
	return out


func _find_pawn_by_species(parent: Node, species_name: String) -> TacticsPawn:
	for child in parent.get_children():
		if child is TacticsPawn and child.stats.species_name == species_name:
			return child
	return null


func _pawn_label(value: Variant) -> String:
	if value is TacticsPawn:
		var pawn: TacticsPawn = value as TacticsPawn
		return _pawn_species_name(pawn)
	if value is Node:
		return (value as Node).name
	return str(value)


func _pawn_species_name(pawn: TacticsPawn) -> String:
	if pawn == null:
		return ""
	if pawn.stats != null and not pawn.stats.species_name.is_empty():
		return pawn.stats.species_name
	var expertise: Expertise = pawn.get_node_or_null("Expertise") as Expertise
	if expertise != null and expertise.pokemon_instance != null:
		return expertise.pokemon_instance.display_name()
	return ""


func _local_transform_to(node: Node3D, ancestor: Node) -> Transform3D:
	var out: Transform3D = node.transform
	var current: Node = node.get_parent()
	while current != null and current != ancestor:
		if current is Node3D:
			out = (current as Node3D).transform * out
		current = current.get_parent()
	return out


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	push_error("smoke: fail - %s" % label)
