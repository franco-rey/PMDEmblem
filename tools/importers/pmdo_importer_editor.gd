@tool
class_name PMDOImporterEditor
extends EditorScript
## Editor entry point for the PMDODump importer.
##
## Open this file in the Godot script editor and choose File -> Run
## (Ctrl+Shift+X) to import. The actual logic lives in `PMDOImporter` as a
## `RefCounted` so the same code can run headlessly via `pmdo_run.gd`.


func _run() -> void:
	var importer := PMDOImporter.new()
	importer.run()
