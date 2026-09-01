extends SceneTree

const REPORT_PATH: String = "res://data/models/pokemon/import_reports/move_vfx_report.json"
const STARTER_MOVES: Array[String] = [
	"water_gun",
	"mud_slap",
	"lava_plume",
	"thunder_punch",
	"psycho_cut",
	"confusion",
	"protect",
	"smokescreen",
	"aura_sphere",
	"hyper_beam",
]

var failures: int = 0


func _init() -> void:
	var player := MoveVFXPlayer.new()
	var source := Node3D.new()
	var target := Node3D.new()
	var log := BattleLog.new()
	root.add_child(player)
	root.add_child(source)
	root.add_child(target)
	source.position = Vector3.ZERO
	target.position = Vector3(2, 0, 0)

	for move_id in STARTER_MOVES:
		var node: Node3D = player.play_for_move(_move(move_id), source, target, log)
		_assert_true(node != null, "%s VFX spawns" % move_id)
		if node != null:
			_assert_true(node.get_parent() == player, "%s VFX is parented to player" % move_id)
			_assert_true(node.get_meta("asset_path", "") != "", "%s VFX records asset path" % move_id)
			player.release_vfx(node)
	var missing: Node3D = player.play_for_move(_move("splash"), source, target, log)
	_assert_true(missing == null, "unmapped move safely skips VFX")
	_assert_true(_log_has(log, "move_vfx_skipped"), "unmapped VFX skip is logged")

	var report: Dictionary = player.coverage_report()
	_assert_true(int(report.get("mapped_move_count", 0)) >= STARTER_MOVES.size(), "VFX coverage report includes starter set")
	_assert_true(_write_text(REPORT_PATH, JSON.stringify(report, "\t") + "\n"), "move VFX report written")
	player.queue_free()
	source.queue_free()
	target.queue_free()

	if failures > 0:
		push_error("smoke: move_vfx failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: move_vfx clean")
		quit(0)


func _move(move_id: String) -> PokemonMoveResource:
	var move := PokemonMoveResource.new()
	move.move_id = move_id
	return move


func _log_has(log: BattleLog, kind: String) -> bool:
	for event in log.events:
		if event.get("kind", "") == kind:
			return true
	return false


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("smoke: failed to open %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true


func _assert_true(value: bool, label: String) -> void:
	if value:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: fail - %s" % label)
