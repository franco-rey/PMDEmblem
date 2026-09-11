extends SceneTree

const MAIN_SCENE_PATH: String = "res://assets/scene/main.tscn"
const OUTPUT_DIR: String = "res://logs/debug/live_captures"

var captured: Array[String] = []
var label_prefix: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var size_arg: PackedStringArray = _arg("size").split("x", false)
	var window_size: Vector2i = Vector2i(int(size_arg[0]), int(size_arg[1])) if size_arg.size() == 2 else Vector2i(1920, 1080)
	DisplayServer.window_set_size(window_size)
	var hidpi: float = 2.0 if _arg("hidpi") == "1" else 1.0
	UiScale.override_factor = UiScale.compute(Vector2(window_size), hidpi)
	label_prefix = _arg("label")
	root.content_scale_size = Vector2i(0, 0)
	await process_frame
	GameSettings.remember_window_size = false
	var main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var border_arg: String = _arg("border")
	if border_arg.is_valid_int():
		PmdStyle.set_border_style(int(border_arg))
	var color_arg: String = _arg("color")
	if color_arg.is_valid_int():
		PmdStyle.set_border_color(int(color_arg))
	main.get_node("UI/MapSelector/SkirmishMenu/CustomToggleButton").emit_signal("pressed")
	await process_frame
	await process_frame
	var lobby: SkirmishLobby = main.get_node("UI/SkirmishLobby")
	lobby.activate_player_team()
	var map_arg: String = _arg("map")
	if not map_arg.is_empty():
		for i in range(lobby.map_picker.item_count):
			if lobby.map_picker.get_item_text(i).to_lower().contains(map_arg.to_lower()):
				lobby.map_picker.select(i)
				lobby._on_map_changed(i)
				break
	var teams_arg: String = _arg("teams")
	if teams_arg.is_valid_int():
		lobby.player_size_slider.value = int(teams_arg)
		lobby.enemy_size_spin.value = int(teams_arg)
	var entries: Array[Dictionary] = lobby.get_roster_entries()
	var idx: Dictionary = {}
	for i in range(entries.size()):
		idx[String(entries[i].get("slug", ""))] = i
	lobby.add_roster_index(int(idx["0001_bulbasaur"]))
	lobby.add_roster_index(int(idx["0007_squirtle"]))
	lobby.set_held_item(SkirmishLobby.SIDE_PLAYER, 0, "seed_blast")
	lobby._on_team_slot_pressed(SkirmishLobby.SIDE_PLAYER, 0)
	for i in range(4):
		await process_frame
	print("lobby: cell scale %.2f, columns %d, roster width %.0f" % [lobby.roster_cell_scale, lobby.roster_grid.columns, lobby.roster_scroll.size.x])
	print("lobby: size %s viewport %s" % [lobby.size, root.get_viewport().get_visible_rect().size])
	for node_name in ["LobbyLayout", "PlayerTeamTray", "MiddleLayout", "SetupPanel", "RosterPanel", "RosterScroll", "DetailsPanel", "EnemyTeamTray"]:
		var control: Control = lobby.find_child(node_name, true, false) as Control
		if control != null:
			print("lobby: %s min %s size %s pos %s" % [node_name, control.get_combined_minimum_size(), control.size, control.global_position])
	var first_cell: Button = lobby.roster_grid.get_child(0) as Button
	if first_cell != null:
		var portrait: TextureRect = first_cell.find_child("Portrait", true, false) as TextureRect
		print("lobby: cell size %s portrait size %s tooltip '%s'" % [first_cell.size, portrait.size, first_cell.tooltip_text])
	await _snap("lobby_00_scaled_grid")
	if teams_arg.is_valid_int():
		lobby.activate_enemy_team()
		await process_frame
		await process_frame
		await _snap("lobby_00b_full_trays")
	lobby._open_chooser(SkirmishLobby.CHOOSER_ITEM)
	for i in range(3):
		await process_frame
	await _snap("lobby_01_choose_item")
	lobby._close_chooser()
	lobby.random_moves_check.button_pressed = false
	for i in range(3):
		await process_frame
	await _snap("lobby_02_choose_moves")
	lobby._on_chooser_row_pressed("razor_leaf")
	lobby._on_chooser_row_pressed("tackle")
	lobby._close_chooser()
	for i in range(3):
		await process_frame
	await _snap("lobby_03_slot_section")
	for path in captured:
		print("capture: %s" % path)
	quit(0)


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		return
	var path: String = "%s/%s%s.png" % [OUTPUT_DIR, label_prefix, label]
	image.save_png(ProjectSettings.globalize_path(path))
	captured.append(path)


func _arg(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = String(arg)
		if text.begins_with("--%s=" % name):
			return text.substr(name.length() + 3)
	return ""
