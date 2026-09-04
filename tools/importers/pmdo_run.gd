extends SceneTree


func _init() -> void:
	var importer := PMDOImporter.new()
	importer.run()
	quit(0)
