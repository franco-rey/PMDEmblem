extends SceneTree

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver := NotationDriver.new(self)
	var lines: Array = Array(FileAccess.get_file_as_string("res://tools/validation/fixtures/notation_smoke.txt").split("\n"))
	var result: Dictionary = await driver.run_script(lines)
	_assert_true(int(result.get("failures", 0)) == 0, "driver script ran without command failures (%s)" % str(result.get("log", [])))
	var notation: String = String(result.get("notation", ""))
	_assert_true(notation.contains("  atk 1 rain_dance") and notation.contains("  wx rain start 5"), "notation records Rain Dance and the weather line")
	_assert_true(notation.contains("  atk 2 water_gun E1") and notation.contains("  hit E1 -") and notation.contains(" wx1.5"), "notation records the boosted Water Gun hit")
	_assert_true(notation.contains("T1 E1 @") and notation.contains("T3 E1 @"), "enemy turns recorded in order (%s)" % notation.substr(0, 400).replace("\n", " | "))
	_assert_true(notation.contains("[Code \"match seed=7 mode=pvp") and notation.contains("[Mode pvp]"), "header carries the skirmish code and mode")
	var level: TacticsLevel = result.get("level")
	_assert_true(level != null and FileAccess.file_exists(level.notation.output_path()), "notation file saved")
	if failures > 0:
		push_error("smoke: play_notation failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: play_notation clean")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
