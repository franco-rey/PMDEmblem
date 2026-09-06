extends SceneTree

const LOBBY_SCENE_PATH: String = "res://assets/scene/skirmish_lobby.tscn"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pair: Array = LoopbackLink.pair()
	var host_session := NetSession.new()
	var guest_session := NetSession.new()
	host_session.local_name = "host"
	guest_session.local_name = "guest"
	root.add_child(host_session)
	root.add_child(guest_session)
	host_session.use_test_link(pair[0], true)
	guest_session.use_test_link(pair[1], false)
	var host_lobby: SkirmishLobby = _lobby()
	var guest_lobby: SkirmishLobby = _lobby()
	for i in range(4):
		await process_frame
	host_lobby.set_session(host_session)
	guest_lobby.set_session(guest_session)
	for i in range(8):
		await process_frame
	_assert_true(host_session.state == NetSession.LOBBY and guest_session.state == NetSession.LOBBY, "both lobbies are connected")
	_assert_true(host_lobby.network_mode() and guest_lobby.network_mode(), "both lobbies switch into network mode")
	_assert_true(host_lobby.local_side_key() == SkirmishLobby.SIDE_PLAYER and guest_lobby.local_side_key() == SkirmishLobby.SIDE_ENEMY, "the host owns team 1 and the guest team 2")
	_assert_true(not host_lobby.map_picker.disabled and guest_lobby.map_picker.disabled, "only the host picks the map")
	_assert_true(host_lobby.seed_input.editable and not guest_lobby.seed_input.editable, "only the host sets the seed")
	_assert_true(host_lobby.control_mode_picker.disabled and guest_lobby.control_mode_picker.disabled, "the control mode is pinned in network mode")
	_assert_true(String(host_lobby.control_mode_picker.get_item_metadata(host_lobby.control_mode_picker.selected)) == SkirmishDefinitionResource.CONTROL_MODE_PLAYER_VS_PLAYER, "network matches are player versus player")
	_assert_true(host_lobby.net_ready_check.visible and guest_lobby.net_ready_check.visible, "both lobbies show a ready toggle")
	_assert_true(guest_lobby.launch_button.disabled and guest_lobby.launch_button.text.contains("host"), "the guest cannot launch and is told the host will")
	var roster: Array[Dictionary] = host_lobby.get_roster_entries()
	_assert_true(roster.size() > 3, "the roster is available for both sides")
	var host_paths: Array[String] = [String(roster[0]["path"]), String(roster[1]["path"])]
	var guest_paths: Array[String] = [String(roster[2]["path"]), String(roster[3]["path"])]
	host_lobby.player_team_paths = host_paths.duplicate()
	host_lobby._refresh_team_trays()
	guest_lobby.enemy_team_paths = guest_paths.duplicate()
	guest_lobby._refresh_team_trays()
	host_lobby.seed_input.text = "4242"
	host_lobby.player_size_slider.value = 2
	host_lobby.enemy_size_spin.value = 2
	await _settle(20)
	_assert_true(host_lobby.enemy_team_paths == guest_paths, "the guest's team appears in the host's enemy tray")
	_assert_true(guest_lobby.player_team_paths == host_paths, "the host's team appears in the guest's player tray")
	_assert_true(guest_lobby.seed_input.text == "4242", "the host's seed mirrors to the guest")
	_assert_true(int(guest_lobby.player_size_slider.value) == 2 and int(guest_lobby.enemy_size_spin.value) == 2, "the host's team sizes mirror to the guest")
	_assert_true(host_lobby.launch_button.disabled, "the host cannot launch before both players are ready")
	host_lobby.net_ready_check.button_pressed = true
	guest_lobby.net_ready_check.button_pressed = true
	await _settle(20)
	_assert_true(host_session.both_ready() and guest_session.both_ready(), "both ready flags cross the link")
	_assert_true(not host_lobby.launch_button.disabled, "the host can launch once both are ready")
	var code: String = host_lobby.network_launch_code()
	_assert_true(code.contains("mode=pvp"), "the launch code is a player versus player match")
	_assert_true(code.contains("p=") and code.contains("e="), "the launch code carries both teams explicitly")
	var built: Dictionary = SkirmishCode.build_definitions(code)
	_assert_true(bool(built.get("ok", false)), "the launch code rebuilds into a definition")
	if bool(built.get("ok", false)):
		var definition: SkirmishDefinitionResource = (built["definitions"] as Array)[0]
		_assert_true(definition.player_team.size() == host_paths.size() and definition.enemy_team.size() == guest_paths.size(), "each side of the built match came from its own player")
		for instance in definition.player_team + definition.enemy_team:
			_assert_true(instance.control_type == PokemonInstanceResource.ControlType.PLAYER, "every unit in a network match is human controlled")
			break
	var started: Array[String] = []
	guest_session.start_requested.connect(func(c: String, _id: String) -> void: started.append(c))
	host_lobby._on_launch_pressed()
	await _settle(10)
	_assert_true(started.size() == 1 and started[0] == code, "pressing Launch starts the same match on both peers")
	host_session.leave("test")
	guest_session.leave("test")
	await _settle(4)
	_assert_true(not host_lobby.network_mode(), "leaving returns the lobby to normal mode")
	host_lobby.queue_free()
	guest_lobby.queue_free()
	host_session.queue_free()
	guest_session.queue_free()
	await _settle(4)
	await _check_menu_path()
	_finish()


func _check_menu_path() -> void:
	var main: Node = (load("res://assets/scene/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var multiplayer_button: Button = main.find_child("MultiplayerButton", true, false) as Button
	_assert_true(multiplayer_button != null, "the main menu offers Multiplayer")
	if multiplayer_button == null:
		main.queue_free()
		return
	multiplayer_button.emit_signal("pressed")
	await process_frame
	var menu: MultiplayerMenu = main.find_child("MultiplayerMenu", true, false) as MultiplayerMenu
	_assert_true(menu != null and menu.visible, "pressing Multiplayer opens the direct connect screen")
	if menu == null:
		main.queue_free()
		return
	_assert_true(menu.find_child("HostButton", true, false) != null and menu.find_child("JoinButton", true, false) != null and menu.find_child("AddressInput", true, false) != null, "the screen offers hosting, joining and an address")
	var port_input: LineEdit = menu.find_child("PortInput", true, false) as LineEdit
	port_input.text = "24596"
	(menu.find_child("HostButton", true, false) as Button).emit_signal("pressed")
	await _settle(6)
	var session: NetSession = main.net_session
	_assert_true(session.state == NetSession.HOSTING, "Host Game opens a session that listens")
	var lobby: SkirmishLobby = main.get_node_or_null("UI/SkirmishLobby") as SkirmishLobby
	_assert_true(lobby != null and lobby.visible and lobby.network_mode(), "hosting opens the lobby in network mode")
	_assert_true(lobby != null and not lobby.net_status_label.text.is_empty(), "the lobby tells the host it is waiting for a player")
	var guest_link := EnetLink.new()
	_assert_true(guest_link.join("127.0.0.1", 24596) == "", "a second peer can reach the hosted port")
	var frames: int = 0
	while frames < 600 and guest_link.remote_id == 0:
		guest_link.poll(0.016)
		await physics_frame
		frames += 1
	_assert_true(guest_link.remote_id != 0, "the hosted port accepts a real connection")
	guest_link.close("test")
	session.leave("test")
	await _settle(4)
	main.queue_free()
	await process_frame


func _lobby() -> SkirmishLobby:
	var lobby: SkirmishLobby = (load(LOBBY_SCENE_PATH) as PackedScene).instantiate() as SkirmishLobby
	root.add_child(lobby)
	lobby.visible = true
	return lobby


func _settle(frames: int) -> void:
	for i in range(frames):
		await process_frame
		await physics_frame


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("smoke: ok - %s" % label)
	else:
		failures += 1
		push_error("smoke: FAIL - %s" % label)


func _finish() -> void:
	if failures > 0:
		push_error("smoke: net_lobby failed %d check(s)" % failures)
		quit(1)
		return
	print("smoke: net_lobby clean")
	quit(0)
