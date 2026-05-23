extends SceneTree
## Headless smoke test: load and instantiate `test_level.tscn`, run a handful
## of physics frames, and confirm every spawned `Stats` node received its
## Pokemon-derived values. Intended for the M1 acceptance check, runs via:
##
##   godot --headless --path <project> --script tools/validation/smoke_test_level.gd
##
## Exits 0 on success, 1 on any failure. Prints a short per-pawn report.

const SCENE_PATH: String = "res://assets/maps/level/test_level.tscn"
const FRAMES_TO_RUN: int = 6


func _init() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("smoke: could not load %s" % SCENE_PATH)
		quit(1)
		return

	var level: Node = scene.instantiate()
	if level == null:
		push_error("smoke: could not instantiate test_level scene")
		quit(1)
		return

	root.add_child(level)
	# Let _ready propagate through the tree, then iterate a few physics frames.
	for i in range(FRAMES_TO_RUN):
		await physics_frame

	var failures: int = _audit_pawns(level)
	level.queue_free()
	if failures > 0:
		push_error("smoke: %d pawn(s) failed audit" % failures)
		quit(1)
	else:
		print("smoke: test_level booted cleanly with %d pawns" % _count_pawns(level))
		quit(0)


func _audit_pawns(level: Node) -> int:
	var failures: int = 0
	var participant: Node = level.get_node_or_null("TacticsParticipant")
	if participant == null:
		push_error("smoke: TacticsParticipant missing")
		return 1
	for team_node in participant.get_children():
		for pawn in team_node.get_children():
			if not pawn.has_node("Expertise/Stats"):
				push_error("smoke: pawn %s missing Expertise/Stats" % pawn.name)
				failures += 1
				continue
			var stats: Node = pawn.get_node("Expertise/Stats")
			var ok: bool = _audit_stats(pawn, stats)
			if not ok:
				failures += 1
	return failures


func _audit_stats(pawn: Node, stats: Node) -> bool:
	var species_name: String = String(stats.get("species_name"))
	var hp_max: int = int(stats.get("hp_max"))
	var attack: int = int(stats.get("attack"))
	var speed: int = int(stats.get("speed"))
	var move_slots: Array = stats.get("move_slots") as Array
	var types_array: Array = stats.get("types") as Array
	var moves_count: int = move_slots.size() if move_slots != null else 0
	var types_str: String = ", ".join(types_array) if types_array != null else ""

	if species_name.is_empty():
		push_error("smoke: %s has empty species_name (compat layer didn't fire?)" % pawn.name)
		return false
	if hp_max <= 0:
		push_error("smoke: %s has hp_max <= 0" % pawn.name)
		return false
	if moves_count == 0:
		push_error("smoke: %s has no move slots" % pawn.name)
		return false

	print("smoke: %s -> %s [types=%s] hp_max=%d atk=%d spe=%d moves=%d" % [
		pawn.name, species_name, types_str, hp_max, attack, speed, moves_count
	])
	return true


func _count_pawns(level: Node) -> int:
	var n: int = 0
	var participant: Node = level.get_node_or_null("TacticsParticipant")
	if participant == null:
		return 0
	for team_node in participant.get_children():
		for _pawn in team_node.get_children():
			n += 1
	return n
