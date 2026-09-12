extends SmokeCase

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"


func _run() -> void:
	var main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	_assert_true(root.theme != null and root.theme.get_stylebox("panel", "PanelContainer") is PmdWindowStyle and root.theme.default_font == PmdStyle.font_body() and PmdStyle.font_body().base_font == PmdStyle.font_file_for(GameSettings.ui_font), "root theme is the PMD skin with the PMD font")
	_assert_true(main.get_node_or_null("UI/Backdrop") is PmdBackdrop and main.get_node_or_null("UI/MapSelector/RosterShowcase/RosterCarousel") is RosterCarousel, "main menu has the sky backdrop and the roster carousel")
	main.get_node("UI/MapSelector/SkirmishMenu/CustomToggleButton").emit_signal("pressed")
	await process_frame
	await process_frame
	var lobby: SkirmishLobby = main.get_node("UI/SkirmishLobby")
	lobby.activate_player_team()
	var cell: Button = lobby.find_child("Roster_0006_charizard", true, false)
	_assert_true(cell != null, "roster has a Charizard cell")
	if cell == null:
		_finish("lobby_portraits")
		return
	var portrait: TextureRect = cell.get_node("Portrait")
	var normal: Texture2D = portrait.texture
	cell.pressed.emit()
	await process_frame
	_assert_true(portrait.texture == PortraitLibrary.texture_for("0006_charizard", "Happy") and portrait.texture != normal, "clicking a roster cell flashes the happy portrait")
	_assert_true(lobby.selected_expression == "Happy" and lobby.selected_portrait.texture == PortraitLibrary.texture_for("0006_charizard", "Happy"), "details panel shows the selected Pokemon smiling")
	_assert_true(lobby.selected_name_label.text == "Charizard" and lobby.selected_types_label.text == "Fire / Flying", "details panel names the selection with its types (%s, %s)" % [lobby.selected_name_label.text, lobby.selected_types_label.text])
	_assert_true(lobby.get_player_team_paths().size() == 1, "the click still adds the Pokemon to the team")
	await create_timer(SkirmishLobby.PORTRAIT_FLASH_SECONDS * 1.6).timeout
	await process_frame
	_assert_true(portrait.texture == normal, "roster cell returns to the normal portrait after the flash")
	_assert_true(lobby.selected_expression == PortraitLibrary.NORMAL, "details portrait settles back to normal (%s)" % lobby.selected_expression)
	var slot: Button = lobby.find_child("PlayerSlot1", true, false)
	_assert_true(slot != null, "team tray has the filled slot")
	if slot != null:
		slot.pressed.emit()
		await process_frame
		_assert_true(lobby.selected_expression == "Happy", "clicking a team slot smiles too")
	_assert_true(lobby.find_child("Backdrop", true, false) is PmdBackdrop, "lobby carries the sky backdrop")
	_finish("lobby_portraits")
