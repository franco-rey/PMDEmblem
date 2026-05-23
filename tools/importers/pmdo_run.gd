extends SceneTree
## Headless runner for the PMDO importer. Invoke with:
##
##   godot --headless --path <project> --script tools/importers/pmdo_run.gd
##
## The importer itself is a `RefCounted` so it can be instantiated from any
## context. The editor entry point (`pmdo_importer_editor.gd`) calls the same
## `run()` method.


func _init() -> void:
	var importer := PMDOImporter.new()
	importer.run()
	quit(0)
