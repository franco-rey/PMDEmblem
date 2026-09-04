@tool
class_name PMDOImporterEditor
extends EditorScript


func _run() -> void:
	var importer := PMDOImporter.new()
	importer.run()
