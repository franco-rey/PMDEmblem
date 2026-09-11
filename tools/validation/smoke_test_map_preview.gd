extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._on_custom_toggle_pressed()
	await _settle()
	var lobby: SkirmishLobby = main.skirmish_lobby
	var picker: OptionButton = lobby.map_picker
	var count: int = lobby.map_paths.size()
	_assert_true(count >= 2, "the lobby lists at least two maps (%d)" % count)
	_assert_true(picker.item_count == count + 1 and picker.get_item_text(count) == SkirmishLobby.MAP_PREVIEW_LABEL, "the map picker ends with the Preview item")
	var before: int = picker.selected
	picker.select(count)
	picker.item_selected.emit(count)
	await _settle()
	var preview: MapPreviewScreen = lobby.map_preview
	_assert_true(preview != null and preview.visible, "choosing Preview opens the map preview")
	_assert_true(picker.selected == before, "the map picker keeps its previous map (%d)" % picker.selected)
	var layout: Control = lobby.get_node("LayoutMargin")
	_assert_true(not layout.visible, "the lobby layout hides behind the preview")
	if preview == null:
		_finish()
		return
	_assert_true(preview.carousel.entries.size() == count, "the rolodex lists every map (%d)" % preview.carousel.entries.size())
	_assert_true(preview.selected_index() == before, "the rolodex starts on the current map")
	_assert_true(preview.stage.map_path == lobby.map_paths[before], "the stage shows the current map")
	await _check_spawns(preview, lobby.map_paths[before])
	var other: int = (before + 1) % count
	preview.carousel.select_index(other, false)
	await _settle()
	_assert_true(preview.stage.map_path == lobby.map_paths[other], "moving the rolodex swaps the 3D preview")
	await _check_spawns(preview, lobby.map_paths[other])
	var rect: Rect2 = preview.stage.get_global_rect()
	_assert_true(rect.size.x >= 1900.0 and rect.size.y >= 1070.0, "the preview stage fills the screen %s" % str(rect.size))
	preview.back_button.pressed.emit()
	await _settle()
	_assert_true(not preview.visible and layout.visible and picker.selected == before, "Back restores the lobby with the map unchanged")
	picker.select(count)
	picker.item_selected.emit(count)
	await _settle()
	preview.carousel.select_index(other, false)
	await _settle()
	preview.select_button.pressed.emit()
	await _settle()
	_assert_true(not preview.visible and picker.selected == other and lobby._map_index == other, "Select Map applies the rolodex choice to the lobby (%d)" % picker.selected)
	main.queue_free()
	await process_frame
	_finish()


func _check_spawns(preview: MapPreviewScreen, path: String) -> void:
	var map: MapDefinitionResource = load(path) as MapDefinitionResource
	var scene: PackedScene = load(map.scene_path) as PackedScene
	var arena: Node = scene.instantiate()
	var players: int = 0
	var enemies: int = 0
	var spawns: Node = arena.get_node_or_null("SpawnPoints")
	if spawns != null:
		for child in spawns.get_children():
			if child.name.begins_with("SpawnPlayer"):
				players += 1
			elif child.name.begins_with("SpawnEnemy"):
				enemies += 1
	arena.free()
	_assert_true(preview.stage.player_tiles == players and preview.stage.enemy_tiles == enemies, "%s paints %d blue and %d red start squares (%d/%d)" % [map.map_id, players, enemies, preview.stage.player_tiles, preview.stage.enemy_tiles])
	var blue: int = 0
	var red: int = 0
	var tiles: Node = preview.stage._arena.get_node("Tiles")
	for tile in tiles.get_children():
		if tile is MeshInstance3D and (tile as MeshInstance3D).visible:
			if (tile as MeshInstance3D).material_override == TacticsConfig.mat_color.reachable:
				blue += 1
			elif (tile as MeshInstance3D).material_override == TacticsConfig.mat_color.attackable:
				red += 1
	_assert_true(blue == players and red == enemies, "%s uses the movement blue and attack red materials (%d/%d)" % [map.map_id, blue, red])
	_assert_true(preview.stage._arena.get_node_or_null("Sun") == null, "%s preview drops the arena's own sun" % map.map_id)


func _settle() -> void:
	for i in range(4):
		await process_frame


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)


func _finish() -> void:
	if failures > 0:
		push_error("smoke: map_preview failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: map_preview clean")
	quit(0)
