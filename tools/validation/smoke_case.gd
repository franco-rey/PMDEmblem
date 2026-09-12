class_name SmokeCase
extends SceneTree

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	pass


func _fail(label: String) -> void:
	failures += 1
	push_error("smoke: FAIL - %s" % label)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		_fail(label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (got %s expected %s)" % [label, actual, expected])


func _finish(name: String, detail: String = "") -> void:
	if failures > 0:
		push_error("smoke: %s failed %d check(s)" % [name, failures])
		quit(1)
		return
	if detail.is_empty():
		print("smoke: %s clean" % name)
	else:
		print("smoke: %s clean - %s" % [name, detail])
	quit(0)
