extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var path: String = _arg("script")
	if path.is_empty() or not FileAccess.file_exists(path):
		push_error("play_notation: pass -- --script=<res:// or absolute path to a command script>")
		quit(1)
		return
	var lines: Array = Array(FileAccess.get_file_as_string(path).split("\n"))
	var driver := NotationDriver.new(self)
	var result: Dictionary = await driver.run_script(lines)
	print("notation:\n%s" % String(result.get("notation", "")))
	print("play_notation: %d command failure(s)" % int(result.get("failures", 0)))
	quit(0 if int(result.get("failures", 0)) == 0 else 1)


func _arg(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = String(arg)
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return ""
