extends SceneTree
## Headless smoke test for the M5.5 skirmish setup lobby.
##
## Recipe:
##   godot --headless --path . --script tools/validation/smoke_test_skirmish_lobby.gd

const LOBBY_SCENE_PATH: String = "res://assets/scene/skirmish_lobby.tscn"
const EXTERNAL_PATH_MARKERS: Array[String] = [
	"/Users/",
	"SpriteCollab",
	"RawAsset",
]

var failures: int = 0
var lobby: Control = null


func _init() -> void:
	await _setup_lobby()
	_check_roster_portraits()
	_check_button_mouse_routing()
	await _check_active_side_and_direct_adds()
	_check_duplicate_cap()
	_check_explicit_build()
	_check_random_enemy_build()
	await _cleanup()

	if failures > 0:
		push_error("smoke: skirmish_lobby failed %d check(s)" % failures)
		quit(1)
	else:
		print("smoke: skirmish_lobby clean")
		quit(0)


func _setup_lobby() -> void:
	var scene: PackedScene = load(LOBBY_SCENE_PATH) as PackedScene
	_assert_true(scene != null, "SkirmishLobby scene loads")
	if scene == null:
		return
	lobby = scene.instantiate() as Control
	_assert_true(lobby != null, "SkirmishLobby scene instantiates")
	if lobby == null:
		return
	root.add_child(lobby)
	await process_frame
	_assert_true(lobby.get_node_or_null("LayoutMargin/LobbyLayout/PlayerTeamTray") != null, "player tray exists on the top border")
	_assert_true(lobby.get_node_or_null("LayoutMargin/LobbyLayout/EnemyTeamTray") != null, "enemy tray exists on the bottom border")
	_assert_true(lobby.get_node_or_null("LayoutMargin/LobbyLayout/MiddleLayout/RosterPanel") != null, "roster panel exists between trays")
	_assert_true(lobby.find_child("PlayAgainButton", true, false) != null, "summary exposes Play Again")
	_assert_true(lobby.find_child("BackToLobbyButton", true, false) != null, "summary exposes Back to Lobby")


func _check_roster_portraits() -> void:
	if lobby == null:
		return
	var entries: Array[Dictionary] = lobby.get_roster_entries()
	_assert_true(entries.size() >= 7, "lobby exposes current roster")
	for entry in entries:
		var portrait_path: String = String(entry.get("portrait_path", ""))
		_assert_true(portrait_path.begins_with("res://"), "%s portrait uses project-owned res path" % entry.get("label", "?"))
		_assert_true(FileAccess.file_exists(portrait_path), "%s portrait file exists" % entry.get("label", "?"))
		for marker in EXTERNAL_PATH_MARKERS:
			_assert_true(not portrait_path.contains(marker), "%s portrait path does not contain %s" % [entry.get("label", "?"), marker])


func _check_button_mouse_routing() -> void:
	if lobby == null:
		return
	var roster_grid := lobby.find_child("RosterGrid", true, false) as GridContainer
	_assert_true(roster_grid != null and roster_grid.get_child_count() > 0, "roster grid exposes pressable cells")
	if roster_grid != null and roster_grid.get_child_count() > 0:
		_assert_true(_non_button_children_ignore_mouse(roster_grid.get_child(0)), "roster cell contents do not steal mouse input")
	var player_slot := lobby.find_child("PlayerSlot1", true, false) as Button
	var enemy_slot := lobby.find_child("EnemySlot1", true, false) as Button
	_assert_true(player_slot != null, "player slot button exists")
	_assert_true(enemy_slot != null, "enemy slot button exists")
	if player_slot != null:
		_assert_true(_non_button_children_ignore_mouse(player_slot), "player slot contents do not steal mouse input")
	if enemy_slot != null:
		_assert_true(_non_button_children_ignore_mouse(enemy_slot), "enemy slot contents do not steal mouse input")


func _check_active_side_and_direct_adds() -> void:
	if lobby == null:
		return
	var roster_grid := lobby.find_child("RosterGrid", true, false) as GridContainer
	var first_roster_button: Button = null
	var second_roster_button: Button = null
	if roster_grid != null and roster_grid.get_child_count() > 0:
		first_roster_button = roster_grid.get_child(0) as Button
	if roster_grid != null and roster_grid.get_child_count() > 1:
		second_roster_button = roster_grid.get_child(1) as Button
	_assert_true(first_roster_button != null, "first roster button is reachable")
	_assert_true(second_roster_button != null, "second roster button is reachable")
	_assert_true(lobby.get_active_side() == "player", "default active side is player")
	if first_roster_button != null:
		first_roster_button.pressed.emit()
	await process_frame
	_assert_true(lobby.get_player_team_paths().size() == 1, "player team has one after player-mode add")

	var enemy_slot := lobby.find_child("EnemySlot1", true, false) as Button
	if enemy_slot != null:
		enemy_slot.pressed.emit()
	await process_frame
	_assert_true(lobby.get_active_side() == "enemy", "enemy tray activates enemy add mode")
	if second_roster_button != null:
		second_roster_button.pressed.emit()
	await process_frame
	_assert_true(lobby.get_enemy_team_paths().size() == 1, "enemy team has one after enemy-mode add")

	lobby.activate_player_team()
	if first_roster_button != null:
		first_roster_button.pressed.emit()
	await process_frame
	_assert_true(lobby.get_player_team_paths().size() == 2, "duplicates are allowed")


func _check_duplicate_cap() -> void:
	if lobby == null:
		return
	lobby.activate_player_team()
	while lobby.get_player_team_paths().size() < CustomSkirmishBuilder.MAX_TEAM_SIZE:
		_assert_true(lobby.add_roster_index(0), "duplicate add fills player cap")
	var overflow_ok: bool = lobby.add_roster_index(0)
	_assert_true(not overflow_ok, "adding past team cap is rejected cleanly")
	_assert_true(lobby.get_player_team_paths().size() == CustomSkirmishBuilder.MAX_TEAM_SIZE, "player team stays at cap after rejected add")


func _check_explicit_build() -> void:
	if lobby == null:
		return
	var result: Dictionary = lobby.build_current_definition()
	_assert_true(result.get("ok", false), "explicit lobby setup builds a definition")
	if not result.get("ok", false):
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	_assert_true(definition != null, "explicit lobby setup returns SkirmishDefinitionResource")
	_assert_true(definition.player_team.size() == CustomSkirmishBuilder.MAX_TEAM_SIZE, "explicit build preserves player tray")
	_assert_true(definition.enemy_team.size() == 1, "explicit build preserves enemy tray")
	_assert_true(_loader_accepts(definition), "explicit lobby definition is loader-ready")


func _check_random_enemy_build() -> void:
	if lobby == null:
		return
	lobby.set_random_enemy_enabled(true)
	var result: Dictionary = lobby.build_current_definition()
	_assert_true(result.get("ok", false), "random enemy lobby setup builds a definition")
	if not result.get("ok", false):
		return
	var definition: SkirmishDefinitionResource = result["definition"]
	_assert_true(definition != null, "random enemy setup returns SkirmishDefinitionResource")
	_assert_true(String(definition.generation_metadata.get("source", "")) == "random_generator", "random enemy setup routes through RandomSkirmishGenerator")
	_assert_true(definition.enemy_team.size() == 3, "random enemy setup honors default enemy size control")
	_assert_true(_loader_accepts(definition), "random enemy lobby definition is loader-ready")


func _loader_accepts(definition: SkirmishDefinitionResource) -> bool:
	var loader := SkirmishLoader.new()
	root.add_child(loader)
	var level: TacticsLevel = loader.load_skirmish(definition, root)
	var ok: bool = level != null
	if is_instance_valid(loader):
		loader.unload_current()
		loader.queue_free()
	return ok


func _cleanup() -> void:
	if is_instance_valid(lobby):
		lobby.queue_free()
	await process_frame


func _non_button_children_ignore_mouse(node: Node) -> bool:
	for child in node.get_children():
		if child is Control and not child is Button and child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
		if not _non_button_children_ignore_mouse(child):
			return false
	return true


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)
