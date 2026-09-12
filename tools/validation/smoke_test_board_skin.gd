extends SmokeCase

const DRIVER := preload("res://tools/debug/notation_driver.gd")
const CODE: String = "match seed=9 mode=pvp p=0006_charizard@50:flamethrower,slash e=0009_blastoise@50:water_gun,tackle map=chessboard"


func _run() -> void:
	GameSettings.load_settings()
	GameSettings.remember_window_size = false
	var saved: Array = [GameSettings.board_floor, GameSettings.board_frame, GameSettings.board_decor]
	_assert_true(BoardSkin.skin_ids().size() == 24 and BoardSkin.floor_options().size() == 25, "24 board floors plus Default are listed (%d)" % BoardSkin.skin_ids().size())
	_assert_true(BoardSkin.is_floor("default") and BoardSkin.is_floor("temporal_tower") and not BoardSkin.is_floor("nope"), "floor ids validate")
	_assert_true(BoardSkin.is_frame("default") and BoardSkin.is_frame("dungeon") and BoardSkin.is_decor("off") and BoardSkin.is_decor("camp"), "frame and decoration ids validate")
	_assert_true(BoardSkin.floor_label("temporal_tower") == "Temporal Tower" and BoardSkin.floor_label("default") == "Default", "floor labels read the shortlist names")
	var available: bool = BoardSkin.available()
	print("smoke: board skins %s" % ("available" if available else "missing, skin checks skipped"))
	if available:
		var missing: Array[String] = []
		for id in BoardSkin.skin_ids():
			if not BoardSkin.has_skin(id) or BoardSkin.wall_texture(id) == null:
				missing.append(id)
		_assert_true(missing.is_empty(), "every listed skin has floor and wall tiles (%s)" % ", ".join(missing))
		_assert_true(BoardSkin.floor_variants("amp_plains") == 3 and BoardSkin.floor_variants("temporal_tower") >= 1, "floor variants come from the manifest (%d)" % BoardSkin.floor_variants("amp_plains"))
		_assert_true(BoardSkin.tint("snow_path", true).r < BoardSkin.tint("dark_wasteland", true).r and BoardSkin.tint("dark_wasteland", false).r > BoardSkin.tint("snow_path", false).r, "bright floors take a darker dark tint and dark floors a brighter light tint")
		_assert_true(BoardSkin.object_texture("Campfire") != null and BoardSkin.object_texture("Tree_Town") != null, "decoration sheets are packaged")
	GameSettings.board_floor = "default"
	GameSettings.board_frame = "default"
	GameSettings.board_decor = "off"
	var driver = DRIVER.new(self)
	var ok: bool = await driver._launch(CODE)
	_assert_true(ok, "board launches on the default look")
	if not ok:
		_wrap_up(saved)
		return
	var level: TacticsLevel = driver.level
	var terrain: Node3D = level.arena.get_node("Terrain")
	var square: MeshInstance3D = terrain.get_node("Square_0_0")
	var original: Material = square.get_surface_override_material(0)
	_assert_true(original != null and (original as StandardMaterial3D).albedo_texture == null, "default board keeps the flat chessboard materials")
	_assert_true(terrain.get_node_or_null(BoardSkin.SURROUND_NAME) == null and terrain.get_node_or_null(BoardSkin.DECOR_NAME) == null, "default board has no surround or decorations")
	if available:
		PmdStyle.set_board_floor("temporal_tower")
		await process_frame
		var skinned: StandardMaterial3D = square.get_surface_override_material(0) as StandardMaterial3D
		_assert_true(skinned != null and skinned.albedo_texture != null and skinned.uv1_triplanar, "picking a floor gives every square a tiled floor material")
		var dark_count: int = 0
		var light_count: int = 0
		for child in terrain.get_children():
			if String(child.name).begins_with("Square_"):
				var material: StandardMaterial3D = (child as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
				if material == null or material.albedo_texture == null:
					continue
				if material.albedo_color.r < 1.0:
					dark_count += 1
				else:
					light_count += 1
		_assert_true(dark_count > 0 and light_count > 0 and absi(dark_count - light_count) <= 1, "squares alternate light and dark tints (%d light, %d dark)" % [light_count, dark_count])
		var slab: MeshInstance3D = terrain.get_node("Slab")
		_assert_true((slab.get_surface_override_material(0) as StandardMaterial3D).albedo_texture == null, "the frame stays flat until a frame style is chosen")
		PmdStyle.set_board_frame("dungeon")
		await process_frame
		_assert_true((slab.get_surface_override_material(0) as StandardMaterial3D).albedo_texture != null, "the dungeon frame textures the slab with the wall tile")
		var surround: Node3D = terrain.get_node_or_null(BoardSkin.SURROUND_NAME)
		_assert_true(surround != null and surround.get_node_or_null("Ground") != null and surround.get_child_count() > 40, "the dungeon frame adds a ground plane and a wall ring (%d nodes)" % (surround.get_child_count() if surround != null else 0))
		PmdStyle.set_board_decor("camp")
		await process_frame
		var decor: Node3D = terrain.get_node_or_null(BoardSkin.DECOR_NAME)
		_assert_true(decor != null and decor.get_child_count() == 8 and decor.get_child(0) is BoardProp, "the camp set places eight props (%d)" % (decor.get_child_count() if decor != null else 0))
		PmdStyle.set_board_decor("garden")
		await process_frame
		decor = terrain.get_node_or_null(BoardSkin.DECOR_NAME)
		_assert_true(decor != null and decor.get_child_count() == 8, "switching sets rebuilds the props")
		PmdStyle.set_board_floor("default")
		await process_frame
		_assert_true(square.get_surface_override_material(0) == original, "returning to Default restores the original square material")
		_assert_true((slab.get_surface_override_material(0) as StandardMaterial3D).albedo_texture == null and terrain.get_node_or_null(BoardSkin.SURROUND_NAME) == null, "the frame follows the floor back to flat and the surround goes")
		PmdStyle.set_board_decor("off")
		await process_frame
		_assert_true(terrain.get_node_or_null(BoardSkin.DECOR_NAME) == null, "turning decorations off removes the props")
		GameSettings.board_floor = "amp_plains"
		GameSettings.board_frame = "dungeon"
		GameSettings.board_decor = "ruins"
		GameSettings.save_settings()
		GameSettings.board_floor = "default"
		GameSettings.load_settings()
		_assert_true(GameSettings.board_floor == "amp_plains" and GameSettings.board_frame == "dungeon" and GameSettings.board_decor == "ruins", "board choices round-trip through the config")
		GameSettings.board_floor = "bogus"
		GameSettings.board_frame = "bogus"
		GameSettings.board_decor = "bogus"
		GameSettings.save_settings()
		GameSettings.load_settings()
		_assert_true(GameSettings.board_floor == "default" and GameSettings.board_frame == "default" and GameSettings.board_decor == "off", "unknown board choices fall back")
	var panel := CustomizePanel.new()
	root.add_child(panel)
	await process_frame
	var floor_picker: OptionButton = panel.find_child("BoardFloorPicker", true, false) as OptionButton
	var frame_picker: OptionButton = panel.find_child("BoardFramePicker", true, false) as OptionButton
	var decor_picker: OptionButton = panel.find_child("BoardDecorPicker", true, false) as OptionButton
	_assert_true(floor_picker != null and floor_picker.item_count == 25 and frame_picker != null and frame_picker.item_count == 2 and decor_picker != null and decor_picker.item_count == 4, "Customize lists the board floor, frame and decoration choices")
	_assert_true(floor_picker.disabled == not available and decor_picker.disabled == not available, "board pickers follow the packaged skins")
	panel.queue_free()
	_wrap_up(saved)


func _wrap_up(saved: Array) -> void:
	GameSettings.board_floor = String(saved[0])
	GameSettings.board_frame = String(saved[1])
	GameSettings.board_decor = String(saved[2])
	GameSettings.save_settings()
	_finish("board_skin")
